//
//  MapSocialProximityState.swift
//  wander
//

import CoreLocation
import Foundation

enum MapSocialClusterMemberID: Hashable {
    case currentUser
    case friend(String)
    case outing(String)

    var stableKey: String {
        switch self {
        case .currentUser:
            "0:current-user"
        case .friend(let userID):
            "1:friend:\(userID)"
        case .outing(let eventID):
            "2:outing:\(eventID)"
        }
    }
}

/// Owns geographic grouping and temporary focus independently of map rendering.
struct MapSocialProximityState {
    struct Source: Equatable {
        let id: MapSocialClusterMemberID
        let coordinate: CLLocationCoordinate2D

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
                && equalDegrees(lhs.coordinate.latitude, rhs.coordinate.latitude)
                && equalDegrees(lhs.coordinate.longitude, rhs.coordinate.longitude)
        }

        private static func equalDegrees(
            _ first: CLLocationDegrees,
            _ second: CLLocationDegrees
        ) -> Bool {
            first == second || (first.isNaN && second.isNaN)
        }
    }

    struct Group: Equatable {
        let id: String
        let memberIDs: [MapSocialClusterMemberID]
    }

    private(set) var groups: [Group] = []
    private(set) var focusedMemberID: MapSocialClusterMemberID?
    private(set) var revision = 0

    private var sources: [Source]?
    private var distanceByPair: [Pair: CLLocationDistance] = [:]
    private var retainedPairs: Set<Pair> = []

    private static let entryDistance: CLLocationDistance = 20
    private static let exitDistance: CLLocationDistance = 25

    private struct Pair: Hashable {
        let firstKey: String
        let secondKey: String

        init(_ first: MapSocialClusterMemberID, _ second: MapSocialClusterMemberID) {
            firstKey = min(first.stableKey, second.stableKey)
            secondKey = max(first.stableKey, second.stableKey)
        }
    }

    // MARK: - Source and focus transitions

    /// Sources have one entry per member, as supplied by the map's identity table.
    @discardableResult
    mutating func update(sources: [Source]) -> Bool {
        let normalizedSources = sources.sorted { $0.id.stableKey < $1.id.stableKey }
        let nextFocus = validFocus(focusedMemberID, in: normalizedSources)
        guard self.sources != normalizedSources || focusedMemberID != nextFocus else {
            return false
        }

        self.sources = normalizedSources
        distanceByPair = distancesByPair(in: normalizedSources)
        focusedMemberID = nextFocus
        rebuildGroups()
        return true
    }

    @discardableResult
    mutating func focus(_ memberID: MapSocialClusterMemberID?) -> Bool {
        let nextFocus = validFocus(memberID, in: sources ?? [])
        guard focusedMemberID != nextFocus else { return false }
        focusedMemberID = nextFocus
        rebuildGroups()
        return true
    }

    mutating func reset() {
        sources = nil
        distanceByPair.removeAll()
        groups.removeAll()
        retainedPairs.removeAll()
        focusedMemberID = nil
        revision += 1
    }

    private func validFocus(
        _ memberID: MapSocialClusterMemberID?,
        in sources: [Source]
    ) -> MapSocialClusterMemberID? {
        guard let memberID,
              sources.contains(where: {
                  $0.id == memberID && CLLocationCoordinate2DIsValid($0.coordinate)
              }) else {
            return nil
        }
        return memberID
    }

    // MARK: - Geographic groups

    private mutating func rebuildGroups() {
        let sources = sources ?? []
        // Keep a focused member's history so restoration still uses the exit threshold.
        retainedPairs = Set(retainedPairs.filter {
            guard let distance = distanceByPair[$0] else { return false }
            return distance <= Self.exitDistance
        })

        let unfocusedSources = sources.filter { $0.id != focusedMemberID }
        var compositions = makeGroups(
            from: unfocusedSources.filter {
                CLLocationCoordinate2DIsValid($0.coordinate)
            },
            distanceByPair: distanceByPair
        )
        compositions.append(contentsOf: unfocusedSources.filter {
            !CLLocationCoordinate2DIsValid($0.coordinate)
        }.map { [$0] })
        compositions.sort { groupStableKey($0) < groupStableKey($1) }

        var nextGroups: [Group] = []
        var reusedIdentifiers: Set<String> = []
        for composition in compositions {
            let memberIDs = composition.map(\.id)
            guard composition.count > 1 else {
                nextGroups.append(Group(id: memberIDs[0].stableKey, memberIDs: memberIDs))
                continue
            }
            let identifier = reusableGroup(
                for: Set(memberIDs),
                excluding: reusedIdentifiers
            )?.id ?? UUID().uuidString
            reusedIdentifiers.insert(identifier)
            nextGroups.append(Group(id: identifier, memberIDs: memberIDs))
            retainPairs(in: composition)
        }
        groups = nextGroups
        revision += 1
    }

    private func makeGroups(
        from sources: [Source],
        distanceByPair: [Pair: CLLocationDistance]
    ) -> [[Source]] {
        var groups = sources.map { [$0] }
        while groups.count > 1 {
            var bestMerge: (
                first: Int, second: Int, preservesExistingGroup: Bool,
                distance: CLLocationDistance, stableKey: String
            )?

            for firstIndex in groups.indices {
                for secondIndex in groups.indices where secondIndex > firstIndex {
                    guard let compatibility = compatibleMerge(
                        groups[firstIndex], groups[secondIndex],
                        distanceByPair: distanceByPair
                    ) else { continue }
                    let mergeKey = groupStableKey(groups[firstIndex] + groups[secondIndex])
                    if let current = bestMerge,
                       current.preservesExistingGroup && !compatibility.preservesExistingGroup
                        || (current.preservesExistingGroup == compatibility.preservesExistingGroup
                            && current.distance < compatibility.distance)
                        || (current.preservesExistingGroup == compatibility.preservesExistingGroup
                            && current.distance == compatibility.distance
                            && current.stableKey <= mergeKey) {
                        continue
                    }
                    bestMerge = (
                        firstIndex, secondIndex, compatibility.preservesExistingGroup,
                        compatibility.distance, mergeKey
                    )
                }
            }

            guard let bestMerge else { break }
            groups[bestMerge.first].append(contentsOf: groups[bestMerge.second])
            groups[bestMerge.first].sort { $0.id.stableKey < $1.id.stableKey }
            groups.remove(at: bestMerge.second)
        }
        return groups
    }

    /// Every cross-pair must fit its own threshold; a nearby chain is insufficient.
    private func compatibleMerge(
        _ firstGroup: [Source],
        _ secondGroup: [Source],
        distanceByPair: [Pair: CLLocationDistance]
    ) -> (distance: CLLocationDistance, preservesExistingGroup: Bool)? {
        var maximumDistance: CLLocationDistance = 0
        var preservesExistingGroup = true
        for first in firstGroup {
            for second in secondGroup {
                let pair = Pair(first.id, second.id)
                guard let distance = distanceByPair[pair] else { return nil }
                let isRetained = retainedPairs.contains(pair)
                let limit = isRetained ? Self.exitDistance : Self.entryDistance
                guard distance <= limit else { return nil }
                preservesExistingGroup = preservesExistingGroup && isRetained
                maximumDistance = max(maximumDistance, distance)
            }
        }
        return (maximumDistance, preservesExistingGroup)
    }

    private mutating func retainPairs(in sources: [Source]) {
        for firstIndex in sources.indices {
            for secondIndex in sources.indices where secondIndex > firstIndex {
                retainedPairs.insert(Pair(sources[firstIndex].id, sources[secondIndex].id))
            }
        }
    }

    private func distancesByPair(in sources: [Source]) -> [Pair: CLLocationDistance] {
        var result: [Pair: CLLocationDistance] = [:]
        for firstIndex in sources.indices {
            for secondIndex in sources.indices where secondIndex > firstIndex {
                let first = sources[firstIndex]
                let second = sources[secondIndex]
                guard CLLocationCoordinate2DIsValid(first.coordinate),
                      CLLocationCoordinate2DIsValid(second.coordinate) else { continue }
                result[Pair(first.id, second.id)] = CLLocation(
                    latitude: first.coordinate.latitude,
                    longitude: first.coordinate.longitude
                ).distance(from: CLLocation(
                    latitude: second.coordinate.latitude,
                    longitude: second.coordinate.longitude
                ))
            }
        }
        return result
    }

    private func groupStableKey(_ sources: [Source]) -> String {
        sources.map { $0.id.stableKey }.sorted().joined(separator: "|")
    }

    // MARK: - Representative identity

    private func reusableGroup(
        for memberIDs: Set<MapSocialClusterMemberID>,
        excluding reusedIdentifiers: Set<String>
    ) -> Group? {
        groups.filter {
            $0.memberIDs.count > 1
                && !reusedIdentifiers.contains($0.id)
                && !Set($0.memberIDs).isDisjoint(with: memberIDs)
        }.sorted { first, second in
            let firstMembers = Set(first.memberIDs)
            let secondMembers = Set(second.memberIDs)
            let firstIsExact = firstMembers == memberIDs
            let secondIsExact = secondMembers == memberIDs
            if firstIsExact != secondIsExact { return firstIsExact }
            let firstOverlap = firstMembers.intersection(memberIDs).count
            let secondOverlap = secondMembers.intersection(memberIDs).count
            if firstOverlap != secondOverlap { return firstOverlap > secondOverlap }
            return first.id < second.id
        }.first
    }
}
