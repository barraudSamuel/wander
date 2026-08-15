//
//  OutingAttendanceService.swift
//  wander
//

import Combine
import FirebaseFirestore
import Foundation

@MainActor
final class OutingAttendanceService: ObservableObject {
    static let shared = OutingAttendanceService()

    @Published private(set) var currentUserAttendances:
        [String: OutingAttendance] = [:]
    @Published private(set) var ownPlanAttendances: [OutingAttendance] = []
    @Published private(set) var joinedPlanAttendances:
        [String: [OutingAttendance]] = [:]
    @Published private(set) var updatingOwnerIDs: Set<String> = []

    private let database: Firestore
    private let currentUserID: @MainActor () -> String?
    private var observedCurrentUserID: String?
    private var acceptedFriendUserIDs: Set<String> = []
    private var attendanceListeners: [String: ListenerRegistration] = [:]
    private var attendanceListenerTokens: [String: UUID] = [:]
    private var observedPublicationIDs: [String: String] = [:]
    private var joinedPlanListeners: [String: ListenerRegistration] = [:]
    private var joinedPlanListenerTokens: [String: UUID] = [:]
    private var joinedPlanPublicationIDs: [String: String] = [:]
    private var updateTokens: [String: UUID] = [:]
    private var ownPlanListener: ListenerRegistration?
    private var ownPlanListenerToken: UUID?
    private var ownPlanPublicationID: String?

    init(
        database: Firestore = Firestore.firestore(),
        currentUserID: @escaping @MainActor () -> String? = {
            FirebaseService.shared.currentUserId
        }
    ) {
        self.database = database
        self.currentUserID = currentUserID
    }

    deinit {
        attendanceListeners.values.forEach { $0.remove() }
        joinedPlanListeners.values.forEach { $0.remove() }
        ownPlanListener?.remove()
    }

    // MARK: - Observation

    func observe(
        plans: [String: OutingPlan],
        acceptedFriendUserIDs: Set<String>
    ) {
        guard let authenticatedUserID = currentUserID(),
              !authenticatedUserID.isEmpty else {
            stopObserving()
            return
        }

        if observedCurrentUserID != authenticatedUserID {
            resetObservation()
            observedCurrentUserID = authenticatedUserID
        }
        self.acceptedFriendUserIDs = acceptedFriendUserIDs

        let friendPlans = plans.filter { ownerID, plan in
            ownerID != authenticatedUserID
                && acceptedFriendUserIDs.contains(ownerID)
                && plan.isActive()
        }
        let desiredOwnerIDs = Set(friendPlans.keys)
        let removedOwnerIDs = Set(attendanceListeners.keys)
            .subtracting(desiredOwnerIDs)

        for ownerID in removedOwnerIDs {
            removeAttendanceListener(for: ownerID)
        }

        for ownerID in desiredOwnerIDs.sorted() {
            guard let plan = friendPlans[ownerID] else { continue }
            if observedPublicationIDs[ownerID] != plan.publicationIDValue {
                removeAttendanceListener(for: ownerID)
                addAttendanceListener(
                    for: plan,
                    participantID: authenticatedUserID
                )
            }
            reconcileJoinedPlanListener(
                for: plan,
                participantID: authenticatedUserID
            )
        }

        reconcileOwnPlanListener(
            with: plans[authenticatedUserID],
            ownerID: authenticatedUserID
        )
        filterPublishedState()
    }

    func stopObserving() {
        resetObservation()
        observedCurrentUserID = nil
        acceptedFriendUserIDs = []
        updateTokens = [:]
        updatingOwnerIDs = []
    }

    func isAttending(
        ownerID: String,
        publicationIDValue: String
    ) -> Bool {
        guard let attendance = currentUserAttendances[ownerID] else {
            return false
        }
        return attendance.publicationIDValue == publicationIDValue
            && attendance.isActive()
    }

    func visibleAttendances(
        ownerID: String,
        publicationIDValue: String
    ) -> [OutingAttendance] {
        let attendances = ownerID == currentUserID()
            ? ownPlanAttendances
            : joinedPlanAttendances[ownerID] ?? []
        return attendances.filter {
            $0.publicationIDValue == publicationIDValue && $0.isActive()
        }
    }

    // MARK: - Mutation

    func setAttending(_ shouldAttend: Bool, plan: OutingPlan) async throws {
        let participantID = try authenticatedUserID()
        guard plan.ownerID != participantID,
              acceptedFriendUserIDs.contains(plan.ownerID),
              plan.isActive() else {
            throw OutingAttendanceServiceError.planUnavailable
        }
        guard !updatingOwnerIDs.contains(plan.ownerID) else { return }

        let updateToken = UUID()
        updateTokens[plan.ownerID] = updateToken
        updatingOwnerIDs.insert(plan.ownerID)
        defer {
            if updateTokens[plan.ownerID] == updateToken {
                updateTokens.removeValue(forKey: plan.ownerID)
                updatingOwnerIDs.remove(plan.ownerID)
            }
        }

        let reference = try attendanceReference(
            ownerID: plan.ownerID,
            publicationIDValue: plan.publicationIDValue,
            participantID: participantID
        )

        if shouldAttend {
            let profile = try await participantProfile(
                participantID: participantID
            )
            try await reference.setData(
                [
                    "participantId": participantID,
                    "publicationId": plan.publicationIDValue,
                    "displayName": profile.displayName,
                    "avatarID": profile.avatarID,
                    "joinedAt": FieldValue.serverTimestamp(),
                    "expiresAt": Timestamp(date: plan.expiresAt)
                ]
            )
            let document = try await reference.getDocument(source: .server)
            let attendance = try OutingAttendance(
                document: document,
                ownerID: plan.ownerID,
                expectedParticipantID: participantID
            )
            guard attendance.publicationID == plan.publicationID,
                  attendance.publicationIDValue == plan.publicationIDValue,
                  attendance.isActive() else {
                throw OutingAttendanceServiceError.invalidAttendance
            }
            guard currentUserID() == participantID,
                  observedCurrentUserID == participantID else {
                return
            }
            currentUserAttendances[plan.ownerID] = attendance
            reconcileJoinedPlanListener(
                for: plan,
                participantID: participantID
            )
        } else {
            removeJoinedPlanListener(for: plan.ownerID)
            do {
                try await reference.delete()
            } catch {
                reconcileJoinedPlanListener(
                    for: plan,
                    participantID: participantID
                )
                throw error
            }
            guard currentUserID() == participantID,
                  observedCurrentUserID == participantID else {
                return
            }
            currentUserAttendances.removeValue(forKey: plan.ownerID)
        }
    }

    // MARK: - Listener reconciliation

    private func addAttendanceListener(
        for plan: OutingPlan,
        participantID: String
    ) {
        let ownerID = plan.ownerID
        guard let reference = try? attendanceReference(
            ownerID: ownerID,
            publicationIDValue: plan.publicationIDValue,
            participantID: participantID
        ) else { return }

        let token = UUID()
        attendanceListenerTokens[ownerID] = token
        observedPublicationIDs[ownerID] = plan.publicationIDValue
        attendanceListeners[ownerID] = reference.addSnapshotListener {
            [weak self] snapshot, error in
            DispatchQueue.main.async {
                guard let self,
                      self.attendanceListenerTokens[ownerID] == token else {
                    return
                }
                self.handleAttendanceSnapshot(
                    snapshot,
                    error: error,
                    plan: plan,
                    participantID: participantID
                )
            }
        }
    }

    private func handleAttendanceSnapshot(
        _ snapshot: DocumentSnapshot?,
        error: Error?,
        plan: OutingPlan,
        participantID: String
    ) {
        guard error == nil,
              let snapshot,
              snapshot.exists,
              let attendance = try? OutingAttendance(
                document: snapshot,
                ownerID: plan.ownerID,
                expectedParticipantID: participantID
              ),
              attendance.publicationID == plan.publicationID,
              attendance.publicationIDValue == plan.publicationIDValue,
              attendance.expiresAt == plan.expiresAt,
              attendance.isActive() else {
            currentUserAttendances.removeValue(forKey: plan.ownerID)
            removeJoinedPlanListener(for: plan.ownerID)
            return
        }
        currentUserAttendances[plan.ownerID] = attendance
        reconcileJoinedPlanListener(
            for: plan,
            participantID: participantID
        )
    }

    private func reconcileJoinedPlanListener(
        for plan: OutingPlan,
        participantID: String
    ) {
        guard plan.ownerID != participantID,
              acceptedFriendUserIDs.contains(plan.ownerID),
              isAttending(
                ownerID: plan.ownerID,
                publicationIDValue: plan.publicationIDValue
              ) else {
            removeJoinedPlanListener(for: plan.ownerID)
            return
        }
        guard joinedPlanPublicationIDs[plan.ownerID]
            != plan.publicationIDValue else {
            return
        }

        removeJoinedPlanListener(for: plan.ownerID)
        let token = UUID()
        joinedPlanListenerTokens[plan.ownerID] = token
        joinedPlanPublicationIDs[plan.ownerID] = plan.publicationIDValue
        joinedPlanListeners[plan.ownerID] = attendeesCollection(
            ownerID: plan.ownerID
        )
        .whereField("publicationId", isEqualTo: plan.publicationIDValue)
        .addSnapshotListener { [weak self] snapshot, error in
            DispatchQueue.main.async {
                guard let self,
                      self.joinedPlanListenerTokens[plan.ownerID] == token else {
                    return
                }
                self.handleJoinedPlanSnapshot(
                    snapshot,
                    error: error,
                    plan: plan,
                    participantID: participantID
                )
            }
        }
    }

    private func handleJoinedPlanSnapshot(
        _ snapshot: QuerySnapshot?,
        error: Error?,
        plan: OutingPlan,
        participantID: String
    ) {
        guard error == nil, let snapshot else {
            joinedPlanAttendances.removeValue(forKey: plan.ownerID)
            return
        }

        let attendances = validAttendances(in: snapshot, for: plan)
        guard attendances.contains(where: {
            $0.participantID == participantID
        }) else {
            joinedPlanAttendances.removeValue(forKey: plan.ownerID)
            return
        }
        joinedPlanAttendances[plan.ownerID] = attendances
    }

    private func reconcileOwnPlanListener(
        with plan: OutingPlan?,
        ownerID: String
    ) {
        guard let plan,
              plan.ownerID == ownerID,
              plan.isActive() else {
            removeOwnPlanListener()
            return
        }
        guard ownPlanPublicationID != plan.publicationIDValue else { return }

        removeOwnPlanListener()
        let token = UUID()
        ownPlanListenerToken = token
        ownPlanPublicationID = plan.publicationIDValue
        ownPlanListener = attendeesCollection(ownerID: ownerID)
            .whereField("publicationId", isEqualTo: plan.publicationIDValue)
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    guard let self,
                          self.ownPlanListenerToken == token else {
                        return
                    }
                    self.handleOwnPlanSnapshot(
                        snapshot,
                        error: error,
                        plan: plan
                    )
                }
            }
    }

    private func handleOwnPlanSnapshot(
        _ snapshot: QuerySnapshot?,
        error: Error?,
        plan: OutingPlan
    ) {
        guard error == nil, let snapshot else {
            ownPlanAttendances = []
            return
        }

        ownPlanAttendances = validAttendances(in: snapshot, for: plan)
    }

    private func validAttendances(
        in snapshot: QuerySnapshot,
        for plan: OutingPlan
    ) -> [OutingAttendance] {
        snapshot.documents.compactMap { document in
            guard let attendance = try? OutingAttendance(
                document: document,
                ownerID: plan.ownerID
            ),
                  attendance.publicationID == plan.publicationID,
                  attendance.publicationIDValue == plan.publicationIDValue,
                  attendance.expiresAt == plan.expiresAt,
                  attendance.isActive() else {
                return nil
            }
            return attendance
        }
        .sorted { lhs, rhs in
            if lhs.joinedAt != rhs.joinedAt {
                return lhs.joinedAt < rhs.joinedAt
            }
            return lhs.participantID < rhs.participantID
        }
    }

    private func removeAttendanceListener(for ownerID: String) {
        attendanceListenerTokens.removeValue(forKey: ownerID)
        observedPublicationIDs.removeValue(forKey: ownerID)
        attendanceListeners.removeValue(forKey: ownerID)?.remove()
        currentUserAttendances.removeValue(forKey: ownerID)
        removeJoinedPlanListener(for: ownerID)
    }

    private func removeJoinedPlanListener(for ownerID: String) {
        joinedPlanListenerTokens.removeValue(forKey: ownerID)
        joinedPlanPublicationIDs.removeValue(forKey: ownerID)
        joinedPlanListeners.removeValue(forKey: ownerID)?.remove()
        joinedPlanAttendances.removeValue(forKey: ownerID)
    }

    private func removeOwnPlanListener() {
        ownPlanListenerToken = nil
        ownPlanPublicationID = nil
        ownPlanListener?.remove()
        ownPlanListener = nil
        ownPlanAttendances = []
    }

    private func filterPublishedState() {
        let validOwnerIDs = Set(attendanceListeners.keys)
        currentUserAttendances = currentUserAttendances.filter {
            ownerID, attendance in
            validOwnerIDs.contains(ownerID)
                && acceptedFriendUserIDs.contains(ownerID)
                && attendance.isActive()
        }
        ownPlanAttendances = ownPlanAttendances.filter { $0.isActive() }
        joinedPlanAttendances = joinedPlanAttendances.filter {
            ownerID, attendances in
            validOwnerIDs.contains(ownerID)
                && acceptedFriendUserIDs.contains(ownerID)
                && joinedPlanListeners[ownerID] != nil
                && attendances.allSatisfy { $0.isActive() }
        }
    }

    private func resetObservation() {
        attendanceListenerTokens.removeAll()
        observedPublicationIDs.removeAll()
        attendanceListeners.values.forEach { $0.remove() }
        attendanceListeners.removeAll()
        joinedPlanListenerTokens.removeAll()
        joinedPlanPublicationIDs.removeAll()
        joinedPlanListeners.values.forEach { $0.remove() }
        joinedPlanListeners.removeAll()
        joinedPlanAttendances = [:]
        currentUserAttendances = [:]
        removeOwnPlanListener()
    }

    // MARK: - Firestore paths

    private func attendanceReference(
        ownerID: String,
        publicationIDValue: String,
        participantID: String
    ) throws -> DocumentReference {
        let documentID = try OutingAttendance.documentID(
            publicationIDValue: publicationIDValue,
            participantID: participantID
        )
        return attendeesCollection(ownerID: ownerID).document(documentID)
    }

    private func attendeesCollection(ownerID: String) -> CollectionReference {
        database.collection("plans")
            .document(ownerID)
            .collection("attendees")
    }

    private func participantProfile(
        participantID: String
    ) async throws -> (displayName: String, avatarID: String) {
        let snapshot = try await database.collection("users")
            .document(participantID)
            .getDocument(source: .server)
        guard let data = snapshot.data(),
              let displayName = data["displayName"] as? String,
              displayName == displayName.trimmingCharacters(
                in: .whitespacesAndNewlines
              ),
              !displayName.isEmpty,
              displayName.count <= 50,
              let avatarID = data["avatarID"] as? String,
              ProfileAvatar.normalizedID(avatarID) == avatarID else {
            throw OutingAttendanceServiceError.invalidProfile
        }
        return (displayName, avatarID)
    }

    private func authenticatedUserID() throws -> String {
        guard let userID = currentUserID(), !userID.isEmpty else {
            throw OutingAttendanceServiceError.noAuthenticatedUser
        }
        return userID
    }
}

enum OutingAttendanceServiceError: LocalizedError, Equatable {
    case noAuthenticatedUser
    case planUnavailable
    case invalidProfile
    case invalidAttendance

    var errorDescription: String? {
        switch self {
        case .noAuthenticatedUser:
            return "Connecte-toi pour participer à cette sortie."
        case .planUnavailable:
            return "Cette sortie n’est plus disponible."
        case .invalidProfile:
            return "Ton profil doit être synchronisé avant de participer."
        case .invalidAttendance:
            return "La participation n’a pas pu être confirmée. Réessaie."
        }
    }
}
