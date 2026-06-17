//
//  ExplorationEngine.swift
//  wander
//
//  Created by Samuel Barraud on 17/06/2026.
//

import Foundation
import CoreLocation
import H3

struct ExplorationEngine {
    let resolution = 10
    let maxAccuracy: CLLocationAccuracy = 150
    let maxGapToConnect: TimeInterval = 10 * 60
    let maxWalkingSpeed: CLLocationSpeed = 3.5
    let maxConnectDistanceMeters: CLLocationDistance = 800

    let maxInterpolationStepMeters: CLLocationDistance = 30

    // MARK: - H3 conversion

    func cellID(for location: CLLocation) -> String? {
        guard location.horizontalAccuracy > 0,
              location.horizontalAccuracy <= maxAccuracy else {
            return nil
        }
        return cellID(at: location.coordinate)
    }

    func cellID(at coordinate: CLLocationCoordinate2D) -> String? {
        let h3Coord = H3Coordinate(lat: coordinate.latitude, lng: coordinate.longitude)
        let index = H3Index(coordinate: h3Coord, resolution: Int32(resolution))
        return index.description
    }

    // MARK: - Boundary for map rendering

    func boundaryCoordinates(for cellID: String) -> [CLLocationCoordinate2D] {
        guard let index = H3Index(string: cellID) else { return [] }
        return index.boundary().map { vertex in
            CLLocationCoordinate2D(latitude: vertex.lat, longitude: vertex.lng)
        }
    }

    // MARK: - Discover cells between two locations

    /// Returns all H3 cells that should be considered "discovered" for a given
    /// location, plus the cells on a plausible line from the previous accepted
    /// location when the movement looks like walking.
    func discoveredCellIDs(from previous: CLLocation?, to current: CLLocation) -> Set<String> {
        guard current.horizontalAccuracy > 0,
              current.horizontalAccuracy <= maxAccuracy,
              let currentID = cellID(for: current) else {
            return []
        }

        var discovered: Set<String> = [currentID]

        guard let previous = previous else {
            return discovered
        }

        guard previous.horizontalAccuracy > 0,
              previous.horizontalAccuracy <= maxAccuracy,
              let previousID = cellID(for: previous) else {
            return discovered
        }

        let timeGap = current.timestamp.timeIntervalSince(previous.timestamp)
        guard timeGap > 0, timeGap <= maxGapToConnect else {
            return discovered
        }

        let distance = current.distance(from: previous)
        guard distance <= maxConnectDistanceMeters else {
            return discovered
        }

        let averageSpeed = distance / timeGap
        guard averageSpeed <= maxWalkingSpeed else {
            return discovered
        }

        // Try the native H3 grid line first.
        if let previousIndex = H3Index(string: previousID),
           let currentIndex = H3Index(string: currentID),
           let line = previousIndex.gridLine(to: currentIndex) {
            for index in line {
                discovered.insert(index.description)
            }
        } else {
            // Fallback: linear interpolation every ~30 m along the segment.
            let interpolated = interpolatedCellIDs(from: previous.coordinate, to: current.coordinate)
            for cellID in interpolated {
                discovered.insert(cellID)
            }
        }

        return discovered
    }

    // MARK: - Interpolation fallback

    private func interpolatedCellIDs(from start: CLLocationCoordinate2D,
                                       to end: CLLocationCoordinate2D) -> [String] {
        let totalDistance = CLLocation(latitude: start.latitude, longitude: start.longitude)
            .distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude))

        guard totalDistance > 0 else { return [] }

        let stepCount = max(1, Int(totalDistance / maxInterpolationStepMeters))
        var result: [String] = []

        for i in 0...stepCount {
            let fraction = Double(i) / Double(stepCount)
            let lat = start.latitude + (end.latitude - start.latitude) * fraction
            let lng = start.longitude + (end.longitude - start.longitude) * fraction

            if let cellID = cellID(at: CLLocationCoordinate2D(latitude: lat, longitude: lng)) {
                result.append(cellID)
            }
        }

        return result
    }
}
