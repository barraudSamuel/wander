//
//  GroupSyncService.swift
//  wander
//

import Foundation
import Combine
import CoreLocation
import FirebaseFirestore

struct GroupMember: Equatable {
    let userId: String
    var displayName: String
    var location: CLLocationCoordinate2D?
    var currentCellID: String?
    var lastSeenAt: Date

    static func == (lhs: GroupMember, rhs: GroupMember) -> Bool {
        lhs.userId == rhs.userId
            && lhs.displayName == rhs.displayName
            && lhs.currentCellID == rhs.currentCellID
            && lhs.lastSeenAt == rhs.lastSeenAt
            && lhs.location?.latitude == rhs.location?.latitude
            && lhs.location?.longitude == rhs.location?.longitude
    }
}

final class GroupSyncService: ObservableObject {
    @Published var groupMembers: [String: GroupMember] = [:]
    @Published var friendCellIDsByUserID: [String: Set<String>] = [:]

    private let db = Firestore.firestore()
    private let defaultGroupId = "default"
    private var membersListener: ListenerRegistration?
    private var cellsListener: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()

    private var userId: String?
    private var lastPushedLocation: CLLocation?
    private let minLocationPushDistance: CLLocationDistance = 15
    private let minLocationPushInterval: TimeInterval = 10

    init() {
        if let existingUserId = FirebaseService.shared.currentUserId {
            userId = existingUserId
            startSyncing()
            return
        }
        FirebaseService.shared.$currentUserId
            .compactMap { $0 }
            .first()
            .sink { [weak self] userId in
                self?.userId = userId
                self?.startSyncing()
            }
            .store(in: &cancellables)
    }

    deinit {
        stopSyncing()
    }

    func startSyncing() {
        guard userId != nil else { return }
        listenToMembers()
        listenToCells()
        print("[GroupSyncService] started syncing group '\(defaultGroupId)'")
    }

    func stopSyncing() {
        membersListener?.remove()
        membersListener = nil
        cellsListener?.remove()
        cellsListener = nil
    }

    func updateLocation(
        lat: Double,
        lng: Double,
        cellID: String?,
        displayName: String
    ) {
        guard let userId else { return }

        let location = CLLocation(latitude: lat, longitude: lng)

        if let last = lastPushedLocation {
            let distance = location.distance(from: last)
            let timeGap = Date().timeIntervalSince(last.timestamp)
            if distance < minLocationPushDistance && timeGap < minLocationPushInterval {
                return
            }
        }
        lastPushedLocation = location

        let doc = db.collection("groups").document(defaultGroupId)
            .collection("members").document(userId)

        var data: [String: Any] = [
            "location": GeoPoint(latitude: lat, longitude: lng),
            "lastSeenAt": FieldValue.serverTimestamp(),
            "displayName": displayName
        ]
        if let cellID {
            data["currentCellID"] = cellID
        }

        doc.setData(data, merge: true) { error in
            if let error {
                print("[GroupSyncService] location update failed: \(error.localizedDescription)")
            }
        }
    }

    func pushCells(_ cellIDs: Set<String>) {
        guard let userId, !cellIDs.isEmpty else { return }

        let batch = db.batch()
        let groupRef = db.collection("groups").document(defaultGroupId)

        for cellID in cellIDs {
            let docRef = groupRef.collection("cells").document(cellID)
            batch.setData([
                "discoveredByUserIds": FieldValue.arrayUnion([userId]),
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: docRef, merge: true)
        }

        batch.commit { error in
            if let error {
                print("[GroupSyncService] cell push failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Listeners

    private func listenToMembers() {
        membersListener = db.collection("groups").document(defaultGroupId)
            .collection("members")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    print("[GroupSyncService] members listener error: \(error.localizedDescription)")
                    return
                }

                guard let snapshot else { return }

                var members: [String: GroupMember] = [:]
                for doc in snapshot.documents {
                    let data = doc.data()
                    let uid = doc.documentID
                    let displayName = data["displayName"] as? String ?? "Explorer"
                    let location: CLLocationCoordinate2D? = {
                        if let geo = data["location"] as? GeoPoint {
                            return CLLocationCoordinate2D(latitude: geo.latitude, longitude: geo.longitude)
                        }
                        return nil
                    }()
                    let currentCellID = data["currentCellID"] as? String
                    let lastSeenAt = (data["lastSeenAt"] as? Timestamp)?.dateValue() ?? Date()

                    members[uid] = GroupMember(
                        userId: uid,
                        displayName: displayName,
                        location: location,
                        currentCellID: currentCellID,
                        lastSeenAt: lastSeenAt
                    )
                }

                DispatchQueue.main.async {
                    self.groupMembers = members
                }
            }
    }

    private func listenToCells() {
        cellsListener = db.collection("groups").document(defaultGroupId)
            .collection("cells")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    print("[GroupSyncService] cells listener error: \(error.localizedDescription)")
                    return
                }

                guard let snapshot else { return }

                var friendCells: [String: Set<String>] = [:]
                for doc in snapshot.documents {
                    let data = doc.data()
                    let discoveredByUserIds = data["discoveredByUserIds"] as? [String] ?? []

                    for discoveredBy in discoveredByUserIds where discoveredBy != self.userId {
                        friendCells[discoveredBy, default: []].insert(doc.documentID)
                    }
                }

                DispatchQueue.main.async {
                    self.friendCellIDsByUserID = friendCells
                }
            }
    }
}
