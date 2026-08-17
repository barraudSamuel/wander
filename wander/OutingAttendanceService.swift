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
    @Published private(set) var ownEventAttendances:
        [String: [OutingAttendance]] = [:]
    @Published private(set) var joinedEventAttendances:
        [String: [OutingAttendance]] = [:]
    @Published private(set) var updatingEventIDs: Set<String> = []

    private let database: Firestore
    private let currentUserID: @MainActor () -> String?
    private var observedCurrentUserID: String?
    private var acceptedFriendUserIDs: Set<String> = []

    private var attendanceListeners: [String: ListenerRegistration] = [:]
    private var attendanceListenerTokens: [String: UUID] = [:]
    private var observedPublicationIDs: [String: String] = [:]

    private var joinedEventListeners: [String: ListenerRegistration] = [:]
    private var joinedEventListenerTokens: [String: UUID] = [:]
    private var joinedEventPublicationIDs: [String: String] = [:]

    private var ownEventListeners: [String: ListenerRegistration] = [:]
    private var ownEventListenerTokens: [String: UUID] = [:]
    private var ownEventPublicationIDs: [String: String] = [:]

    private var updateTokens: [String: UUID] = [:]

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
        joinedEventListeners.values.forEach { $0.remove() }
        ownEventListeners.values.forEach { $0.remove() }
    }

    // MARK: - Observation

    func observe(
        events: [String: OutingPlan],
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

        let friendEvents = events.filter { _, event in
            event.ownerID != authenticatedUserID
                && acceptedFriendUserIDs.contains(event.ownerID)
        }
        reconcileFriendEventListeners(
            with: friendEvents,
            participantID: authenticatedUserID
        )

        let ownEvents = events.filter { _, event in
            event.ownerID == authenticatedUserID
        }
        reconcileOwnEventListeners(
            with: ownEvents,
            ownerID: authenticatedUserID
        )
        filterPublishedState(validEvents: events)
    }

    func stopObserving() {
        resetObservation()
        observedCurrentUserID = nil
        acceptedFriendUserIDs = []
        updateTokens = [:]
        updatingEventIDs = []
    }

    func isAttending(
        eventIDValue: String,
        publicationIDValue: String
    ) -> Bool {
        guard let attendance = currentUserAttendances[eventIDValue] else {
            return false
        }
        return attendance.eventIDValue == eventIDValue
            && attendance.publicationIDValue == publicationIDValue
    }

    func visibleAttendances(for event: OutingPlan) -> [OutingAttendance] {
        let attendances = event.ownerID == currentUserID()
            ? ownEventAttendances[event.eventIDValue] ?? []
            : joinedEventAttendances[event.eventIDValue] ?? []
        return attendances.filter {
            $0.eventID == event.eventID
                && $0.publicationID == event.publicationID
        }
    }

    // MARK: - Mutation

    func setAttending(_ shouldAttend: Bool, event: OutingPlan) async throws {
        let participantID = try authenticatedUserID()
        let eventIDValue = event.eventIDValue
        guard event.ownerID != participantID,
              acceptedFriendUserIDs.contains(event.ownerID) else {
            throw OutingAttendanceServiceError.eventUnavailable
        }
        guard !updatingEventIDs.contains(eventIDValue) else { return }

        let updateToken = UUID()
        updateTokens[eventIDValue] = updateToken
        updatingEventIDs.insert(eventIDValue)
        defer {
            if updateTokens[eventIDValue] == updateToken {
                updateTokens.removeValue(forKey: eventIDValue)
                updatingEventIDs.remove(eventIDValue)
            }
        }

        let reference = try attendanceReference(
            for: event,
            participantID: participantID
        )

        if shouldAttend {
            let profile = try await participantProfile(
                participantID: participantID
            )
            try await reference.setData(
                [
                    "eventId": eventIDValue,
                    "participantId": participantID,
                    "publicationId": event.publicationIDValue,
                    "displayName": profile.displayName,
                    "avatarID": profile.avatarID,
                    "joinedAt": FieldValue.serverTimestamp()
                ]
            )
            let document = try await reference.getDocument(source: .server)
            let attendance = try OutingAttendance(
                document: document,
                ownerID: event.ownerID,
                eventIDValue: eventIDValue,
                expectedParticipantID: participantID
            )
            guard attendance.publicationID == event.publicationID else {
                throw OutingAttendanceServiceError.invalidAttendance
            }
            guard currentUserID() == participantID,
                  observedCurrentUserID == participantID,
                  acceptedFriendUserIDs.contains(event.ownerID),
                  attendanceListeners[eventIDValue] != nil,
                  observedPublicationIDs[eventIDValue]
                    == event.publicationIDValue else {
                return
            }
            currentUserAttendances[eventIDValue] = attendance
            reconcileJoinedEventListener(
                for: event,
                participantID: participantID
            )
        } else {
            removeJoinedEventListener(for: eventIDValue)
            do {
                try await reference.delete()
            } catch {
                reconcileJoinedEventListener(
                    for: event,
                    participantID: participantID
                )
                throw error
            }
            guard currentUserID() == participantID,
                  observedCurrentUserID == participantID else {
                return
            }
            currentUserAttendances.removeValue(forKey: eventIDValue)
        }
    }

    // MARK: - Friend event listeners

    private func reconcileFriendEventListeners(
        with events: [String: OutingPlan],
        participantID: String
    ) {
        let desiredEventIDs = Set(events.keys)
        for eventID in Set(attendanceListeners.keys)
            .subtracting(desiredEventIDs) {
            removeAttendanceListener(for: eventID)
        }

        for eventID in desiredEventIDs.sorted() {
            guard let event = events[eventID] else { continue }
            if observedPublicationIDs[eventID] != event.publicationIDValue {
                removeAttendanceListener(for: eventID)
                addAttendanceListener(
                    for: event,
                    participantID: participantID
                )
            }
            reconcileJoinedEventListener(
                for: event,
                participantID: participantID
            )
        }
    }

    private func addAttendanceListener(
        for event: OutingPlan,
        participantID: String
    ) {
        let eventID = event.eventIDValue
        guard let reference = try? attendanceReference(
            for: event,
            participantID: participantID
        ) else { return }

        let token = UUID()
        attendanceListenerTokens[eventID] = token
        observedPublicationIDs[eventID] = event.publicationIDValue
        attendanceListeners[eventID] = reference.addSnapshotListener {
            [weak self] snapshot, error in
            DispatchQueue.main.async {
                guard let self,
                      self.attendanceListenerTokens[eventID] == token else {
                    return
                }
                self.handleAttendanceSnapshot(
                    snapshot,
                    error: error,
                    event: event,
                    participantID: participantID
                )
            }
        }
    }

    private func handleAttendanceSnapshot(
        _ snapshot: DocumentSnapshot?,
        error: Error?,
        event: OutingPlan,
        participantID: String
    ) {
        let eventID = event.eventIDValue
        guard error == nil,
              let snapshot,
              snapshot.exists,
              let attendance = try? OutingAttendance(
                document: snapshot,
                ownerID: event.ownerID,
                eventIDValue: eventID,
                expectedParticipantID: participantID
              ),
              attendance.publicationID == event.publicationID else {
            currentUserAttendances.removeValue(forKey: eventID)
            removeJoinedEventListener(for: eventID)
            return
        }
        currentUserAttendances[eventID] = attendance
        reconcileJoinedEventListener(
            for: event,
            participantID: participantID
        )
    }

    private func removeAttendanceListener(for eventID: String) {
        attendanceListenerTokens.removeValue(forKey: eventID)
        observedPublicationIDs.removeValue(forKey: eventID)
        attendanceListeners.removeValue(forKey: eventID)?.remove()
        currentUserAttendances.removeValue(forKey: eventID)
        removeJoinedEventListener(for: eventID)
    }

    // MARK: - Joined event listeners

    private func reconcileJoinedEventListener(
        for event: OutingPlan,
        participantID: String
    ) {
        let eventID = event.eventIDValue
        guard event.ownerID != participantID,
              acceptedFriendUserIDs.contains(event.ownerID),
              isAttending(
                eventIDValue: eventID,
                publicationIDValue: event.publicationIDValue
              ) else {
            removeJoinedEventListener(for: eventID)
            return
        }
        guard joinedEventPublicationIDs[eventID]
            != event.publicationIDValue else {
            return
        }

        removeJoinedEventListener(for: eventID)
        let token = UUID()
        joinedEventListenerTokens[eventID] = token
        joinedEventPublicationIDs[eventID] = event.publicationIDValue
        joinedEventListeners[eventID] = attendeesCollection(for: event)
            .whereField("publicationId", isEqualTo: event.publicationIDValue)
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    guard let self,
                          self.joinedEventListenerTokens[eventID] == token else {
                        return
                    }
                    self.handleJoinedEventSnapshot(
                        snapshot,
                        error: error,
                        event: event,
                        participantID: participantID
                    )
                }
            }
    }

    private func handleJoinedEventSnapshot(
        _ snapshot: QuerySnapshot?,
        error: Error?,
        event: OutingPlan,
        participantID: String
    ) {
        let eventID = event.eventIDValue
        guard error == nil, let snapshot else {
            joinedEventAttendances.removeValue(forKey: eventID)
            return
        }

        let attendances = validAttendances(in: snapshot, for: event)
        guard attendances.contains(where: {
            $0.participantID == participantID
        }) else {
            joinedEventAttendances.removeValue(forKey: eventID)
            return
        }
        joinedEventAttendances[eventID] = attendances
    }

    private func removeJoinedEventListener(for eventID: String) {
        joinedEventListenerTokens.removeValue(forKey: eventID)
        joinedEventPublicationIDs.removeValue(forKey: eventID)
        joinedEventListeners.removeValue(forKey: eventID)?.remove()
        joinedEventAttendances.removeValue(forKey: eventID)
    }

    // MARK: - Owned event listeners

    private func reconcileOwnEventListeners(
        with events: [String: OutingPlan],
        ownerID: String
    ) {
        let desiredEventIDs = Set(events.keys)
        for eventID in Set(ownEventListeners.keys)
            .subtracting(desiredEventIDs) {
            removeOwnEventListener(for: eventID)
        }

        for eventID in desiredEventIDs.sorted() {
            guard let event = events[eventID],
                  event.ownerID == ownerID else {
                continue
            }
            guard ownEventPublicationIDs[eventID]
                != event.publicationIDValue else {
                continue
            }

            removeOwnEventListener(for: eventID)
            let token = UUID()
            ownEventListenerTokens[eventID] = token
            ownEventPublicationIDs[eventID] = event.publicationIDValue
            ownEventListeners[eventID] = attendeesCollection(for: event)
                .whereField(
                    "publicationId",
                    isEqualTo: event.publicationIDValue
                )
                .addSnapshotListener { [weak self] snapshot, error in
                    DispatchQueue.main.async {
                        guard let self,
                              self.ownEventListenerTokens[eventID] == token else {
                            return
                        }
                        self.handleOwnEventSnapshot(
                            snapshot,
                            error: error,
                            event: event
                        )
                    }
                }
        }
    }

    private func handleOwnEventSnapshot(
        _ snapshot: QuerySnapshot?,
        error: Error?,
        event: OutingPlan
    ) {
        guard error == nil, let snapshot else {
            ownEventAttendances.removeValue(forKey: event.eventIDValue)
            return
        }
        ownEventAttendances[event.eventIDValue] = validAttendances(
            in: snapshot,
            for: event
        )
    }

    private func removeOwnEventListener(for eventID: String) {
        ownEventListenerTokens.removeValue(forKey: eventID)
        ownEventPublicationIDs.removeValue(forKey: eventID)
        ownEventListeners.removeValue(forKey: eventID)?.remove()
        ownEventAttendances.removeValue(forKey: eventID)
    }

    // MARK: - Shared validation and reset

    private func validAttendances(
        in snapshot: QuerySnapshot,
        for event: OutingPlan
    ) -> [OutingAttendance] {
        snapshot.documents.compactMap { document in
            guard let attendance = try? OutingAttendance(
                document: document,
                ownerID: event.ownerID,
                eventIDValue: event.eventIDValue
            ),
                  attendance.publicationID == event.publicationID else {
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

    private func filterPublishedState(validEvents: [String: OutingPlan]) {
        let validEventIDs = Set(validEvents.keys)
        currentUserAttendances = currentUserAttendances.filter {
            eventID, attendance in
            validEventIDs.contains(eventID)
                && acceptedFriendUserIDs.contains(attendance.ownerID)
                && attendanceListeners[eventID] != nil
        }
        ownEventAttendances = ownEventAttendances.filter {
            eventID, _ in validEventIDs.contains(eventID)
        }
        joinedEventAttendances = joinedEventAttendances.filter {
            eventID, _ in
            validEventIDs.contains(eventID)
                && joinedEventListeners[eventID] != nil
        }
    }

    private func resetObservation() {
        attendanceListenerTokens.removeAll()
        observedPublicationIDs.removeAll()
        attendanceListeners.values.forEach { $0.remove() }
        attendanceListeners.removeAll()

        joinedEventListenerTokens.removeAll()
        joinedEventPublicationIDs.removeAll()
        joinedEventListeners.values.forEach { $0.remove() }
        joinedEventListeners.removeAll()

        ownEventListenerTokens.removeAll()
        ownEventPublicationIDs.removeAll()
        ownEventListeners.values.forEach { $0.remove() }
        ownEventListeners.removeAll()

        joinedEventAttendances = [:]
        ownEventAttendances = [:]
        currentUserAttendances = [:]
        updateTokens = [:]
        updatingEventIDs = []
    }

    // MARK: - Firestore paths

    private func attendanceReference(
        for event: OutingPlan,
        participantID: String
    ) throws -> DocumentReference {
        let documentID = try OutingAttendance.documentID(
            publicationIDValue: event.publicationIDValue,
            participantID: participantID
        )
        return attendeesCollection(for: event).document(documentID)
    }

    private func attendeesCollection(
        for event: OutingPlan
    ) -> CollectionReference {
        database.collection("users")
            .document(event.ownerID)
            .collection("events")
            .document(event.eventIDValue)
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
    case eventUnavailable
    case invalidProfile
    case invalidAttendance

    var errorDescription: String? {
        switch self {
        case .noAuthenticatedUser:
            return "Connecte-toi pour participer à cet événement."
        case .eventUnavailable:
            return "Cet événement n’est plus disponible."
        case .invalidProfile:
            return "Ton profil doit être synchronisé avant de participer."
        case .invalidAttendance:
            return "La participation n’a pas pu être confirmée. Réessaie."
        }
    }
}
