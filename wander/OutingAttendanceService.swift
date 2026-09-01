//
//  OutingAttendanceService.swift
//  wander
//

import Combine
import FirebaseFirestore
import Foundation

enum OutingAttendanceRosterState: Equatable {
    case notRequested
    case loading
    case available
    case unavailable
}

enum OutingAttendanceParticipationState: Equatable {
    case notRequested
    case loading
    case attending
    case notResponded
    case declined
    case unavailable
}

enum OutingAttendanceResponse: Equatable {
    case attending
    case declined
}

@MainActor
final class OutingAttendanceService: ObservableObject {
    static let shared = OutingAttendanceService()

    @Published private(set) var currentUserAttendances:
        [String: OutingAttendance] = [:]
    @Published private(set) var currentUserDeclines:
        [String: OutingDecline] = [:]
    @Published private(set) var participationStates:
        [String: OutingAttendanceParticipationState] = [:]
    @Published private(set) var ownEventAttendances:
        [String: [OutingAttendance]] = [:]
    @Published private(set) var friendEventAttendances:
        [String: [OutingAttendance]] = [:]
    @Published private(set) var ownEventDeclines:
        [String: [OutingDecline]] = [:]
    @Published private(set) var friendEventDeclines:
        [String: [OutingDecline]] = [:]
    @Published private(set) var rosterStates:
        [String: OutingAttendanceRosterState] = [:]
    @Published private(set) var updatingEventIDs: Set<String> = []

    private let database: Firestore
    private let currentUserID: @MainActor () -> String?
    private var observedCurrentUserID: String?
    private var acceptedFriendUserIDs: Set<String> = []
    private var selectedEventID: String?

    private var attendanceListeners: [String: ListenerRegistration] = [:]
    private var attendanceListenerTokens: [String: UUID] = [:]
    private var declineListeners: [String: ListenerRegistration] = [:]
    private var declineListenerTokens: [String: UUID] = [:]
    private var observedPublicationIDs: [String: String] = [:]
    private var serverAttendanceEventIDs: Set<String> = []
    private var serverDeclineEventIDs: Set<String> = []
    private var unavailableAttendanceEventIDs: Set<String> = []
    private var unavailableDeclineEventIDs: Set<String> = []

    private var friendRosterListeners: [String: ListenerRegistration] = [:]
    private var friendRosterListenerTokens: [String: UUID] = [:]
    private var friendRosterPublicationIDs: [String: String] = [:]
    private var friendDeclineRosterListeners:
        [String: ListenerRegistration] = [:]
    private var friendDeclineRosterListenerTokens: [String: UUID] = [:]
    private var friendDeclineRosterPublicationIDs: [String: String] = [:]

    private var ownEventListeners: [String: ListenerRegistration] = [:]
    private var ownEventListenerTokens: [String: UUID] = [:]
    private var ownEventPublicationIDs: [String: String] = [:]
    private var ownDeclineListeners: [String: ListenerRegistration] = [:]
    private var ownDeclineListenerTokens: [String: UUID] = [:]
    private var ownDeclinePublicationIDs: [String: String] = [:]

    private var attendanceRosterLoadedEventIDs: Set<String> = []
    private var declineRosterLoadedEventIDs: Set<String> = []

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
        declineListeners.values.forEach { $0.remove() }
        friendRosterListeners.values.forEach { $0.remove() }
        friendDeclineRosterListeners.values.forEach { $0.remove() }
        ownEventListeners.values.forEach { $0.remove() }
        ownDeclineListeners.values.forEach { $0.remove() }
    }

    // MARK: - Observation

    func observe(
        events: [String: OutingPlan],
        acceptedFriendUserIDs: Set<String>,
        selectedEventID: String?
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
        self.selectedEventID = selectedEventID

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
        selectedEventID = nil
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
            : friendEventAttendances[event.eventIDValue] ?? []
        return attendances.filter {
            $0.eventID == event.eventID
                && $0.publicationID == event.publicationID
        }
    }

    func visibleDeclines(for event: OutingPlan) -> [OutingDecline] {
        let declines = event.ownerID == currentUserID()
            ? ownEventDeclines[event.eventIDValue] ?? []
            : friendEventDeclines[event.eventIDValue] ?? []
        return declines.filter {
            $0.eventID == event.eventID
                && $0.publicationID == event.publicationID
        }
    }

    func rosterState(eventIDValue: String) -> OutingAttendanceRosterState {
        rosterStates[eventIDValue] ?? .notRequested
    }

    func participationState(
        eventIDValue: String,
        publicationIDValue: String
    ) -> OutingAttendanceParticipationState {
        guard observedPublicationIDs[eventIDValue] == publicationIDValue else {
            return .notRequested
        }
        return participationStates[eventIDValue] ?? .notRequested
    }

    // MARK: - Mutation

    func setResponse(
        _ response: OutingAttendanceResponse,
        event: OutingPlan
    ) async throws {
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

        let currentState = participationState(
            eventIDValue: eventIDValue,
            publicationIDValue: event.publicationIDValue
        )
        if currentState == .attending, response == .attending { return }
        if currentState == .declined, response == .declined { return }
        guard currentState == .attending
                || currentState == .declined
                || currentState == .notResponded else {
            throw OutingAttendanceServiceError.invalidResponse
        }

        let attendanceReference = try attendanceReference(
            for: event,
            participantID: participantID
        )
        let declineReference = try declineReference(
            for: event,
            participantID: participantID
        )
        let profile = try await participantProfile(participantID: participantID)
        let batch = database.batch()
        switch response {
        case .attending:
            batch.deleteDocument(declineReference)
            batch.setData(
                [
                    "eventId": eventIDValue,
                    "participantId": participantID,
                    "publicationId": event.publicationIDValue,
                    "displayName": profile.displayName,
                    "avatarID": profile.avatarID,
                    "joinedAt": FieldValue.serverTimestamp()
                ],
                forDocument: attendanceReference
            )
        case .declined:
            batch.deleteDocument(attendanceReference)
            batch.setData(
                [
                    "eventId": eventIDValue,
                    "participantId": participantID,
                    "publicationId": event.publicationIDValue,
                    "displayName": profile.displayName,
                    "avatarID": profile.avatarID,
                    "respondedAt": FieldValue.serverTimestamp()
                ],
                forDocument: declineReference
            )
        }
        try await batch.commit()

        await confirmCommittedResponseIfAvailable(
            response,
            event: event,
            participantID: participantID,
            attendanceReference: attendanceReference,
            declineReference: declineReference
        )
    }

    private func confirmCommittedResponseIfAvailable(
        _ response: OutingAttendanceResponse,
        event: OutingPlan,
        participantID: String,
        attendanceReference: DocumentReference,
        declineReference: DocumentReference
    ) async {
        let eventIDValue = event.eventIDValue
        switch response {
        case .attending:
            guard
                let document = try? await attendanceReference.getDocument(
                    source: .server
                ),
                let attendance = try? OutingAttendance(
                    document: document,
                    ownerID: event.ownerID,
                    eventIDValue: eventIDValue,
                    expectedParticipantID: participantID
                ),
                attendance.publicationID == event.publicationID
            else {
                return
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
            currentUserDeclines.removeValue(forKey: eventIDValue)
            serverAttendanceEventIDs.insert(eventIDValue)
            serverDeclineEventIDs.insert(eventIDValue)
        case .declined:
            guard
                let document = try? await declineReference.getDocument(
                    source: .server
                ),
                let decline = try? OutingDecline(
                    document: document,
                    ownerID: event.ownerID,
                    eventIDValue: eventIDValue,
                    expectedParticipantID: participantID
                ),
                decline.publicationID == event.publicationID
            else {
                return
            }
            guard currentUserID() == participantID,
                  observedCurrentUserID == participantID,
                  acceptedFriendUserIDs.contains(event.ownerID),
                  declineListeners[eventIDValue] != nil,
                  observedPublicationIDs[eventIDValue]
                    == event.publicationIDValue else {
                return
            }
            currentUserAttendances.removeValue(forKey: eventIDValue)
            currentUserDeclines[eventIDValue] = decline
            serverAttendanceEventIDs.insert(eventIDValue)
            serverDeclineEventIDs.insert(eventIDValue)
        }

        guard currentUserID() == participantID,
              observedCurrentUserID == participantID else { return }
        unavailableAttendanceEventIDs.remove(eventIDValue)
        unavailableDeclineEventIDs.remove(eventIDValue)
        reconcileParticipationState(for: eventIDValue)
        reconcileFriendRosterListener(for: event, participantID: participantID)
    }

    // MARK: - Friend event listeners

    private func reconcileFriendEventListeners(
        with events: [String: OutingPlan],
        participantID: String
    ) {
        let desiredEventIDs = Set(events.keys)
        let observedEventIDs = Set(attendanceListeners.keys)
            .union(declineListeners.keys)
        for eventID in observedEventIDs.subtracting(desiredEventIDs) {
            removePersonalResponseListeners(for: eventID)
        }

        for eventID in desiredEventIDs.sorted() {
            guard let event = events[eventID] else { continue }
            if observedPublicationIDs[eventID] != event.publicationIDValue {
                removePersonalResponseListeners(for: eventID)
                addPersonalResponseListeners(
                    for: event,
                    participantID: participantID
                )
            }
            reconcileFriendRosterListener(
                for: event,
                participantID: participantID
            )
        }
    }

    private func addPersonalResponseListeners(
        for event: OutingPlan,
        participantID: String
    ) {
        let eventID = event.eventIDValue
        guard let attendanceReference = try? attendanceReference(
            for: event,
            participantID: participantID
        ),
              let declineReference = try? declineReference(
            for: event,
            participantID: participantID
        ) else {
            participationStates[eventID] = .unavailable
            return
        }

        let token = UUID()
        attendanceListenerTokens[eventID] = token
        let declineToken = UUID()
        declineListenerTokens[eventID] = declineToken
        observedPublicationIDs[eventID] = event.publicationIDValue
        participationStates[eventID] = .loading
        attendanceListeners[eventID] = attendanceReference.addSnapshotListener(
            includeMetadataChanges: true
        ) { [weak self] snapshot, error in
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
        declineListeners[eventID] = declineReference.addSnapshotListener(
            includeMetadataChanges: true
        ) { [weak self] snapshot, error in
            DispatchQueue.main.async {
                guard let self,
                      self.declineListenerTokens[eventID] == declineToken else {
                    return
                }
                self.handleDeclineSnapshot(
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
        guard error == nil, let snapshot else {
            unavailableAttendanceEventIDs.insert(eventID)
            reconcileParticipationState(for: eventID)
            reconcileFriendRosterListener(
                for: event,
                participantID: participantID
            )
            return
        }
        guard !snapshot.metadata.isFromCache else {
            currentUserAttendances.removeValue(forKey: eventID)
            serverAttendanceEventIDs.remove(eventID)
            reconcileParticipationState(for: eventID)
            reconcileFriendRosterListener(
                for: event,
                participantID: participantID
            )
            return
        }
        guard snapshot.exists else {
            currentUserAttendances.removeValue(forKey: eventID)
            serverAttendanceEventIDs.insert(eventID)
            unavailableAttendanceEventIDs.remove(eventID)
            reconcileParticipationState(for: eventID)
            reconcileFriendRosterListener(
                for: event,
                participantID: participantID
            )
            return
        }
        guard let attendance = try? OutingAttendance(
                document: snapshot,
                ownerID: event.ownerID,
                eventIDValue: eventID,
                expectedParticipantID: participantID
              ),
              attendance.publicationID == event.publicationID else {
            unavailableAttendanceEventIDs.insert(eventID)
            reconcileParticipationState(for: eventID)
            reconcileFriendRosterListener(
                for: event,
                participantID: participantID
            )
            return
        }
        currentUserAttendances[eventID] = attendance
        serverAttendanceEventIDs.insert(eventID)
        unavailableAttendanceEventIDs.remove(eventID)
        reconcileParticipationState(for: eventID)
        reconcileFriendRosterListener(
            for: event,
            participantID: participantID
        )
    }

    private func handleDeclineSnapshot(
        _ snapshot: DocumentSnapshot?,
        error: Error?,
        event: OutingPlan,
        participantID: String
    ) {
        let eventID = event.eventIDValue
        guard error == nil, let snapshot else {
            unavailableDeclineEventIDs.insert(eventID)
            reconcileParticipationState(for: eventID)
            reconcileFriendRosterListener(for: event, participantID: participantID)
            return
        }
        guard !snapshot.metadata.isFromCache else {
            currentUserDeclines.removeValue(forKey: eventID)
            serverDeclineEventIDs.remove(eventID)
            reconcileParticipationState(for: eventID)
            reconcileFriendRosterListener(for: event, participantID: participantID)
            return
        }
        guard snapshot.exists else {
            currentUserDeclines.removeValue(forKey: eventID)
            serverDeclineEventIDs.insert(eventID)
            unavailableDeclineEventIDs.remove(eventID)
            reconcileParticipationState(for: eventID)
            reconcileFriendRosterListener(for: event, participantID: participantID)
            return
        }
        guard let decline = try? OutingDecline(
            document: snapshot,
            ownerID: event.ownerID,
            eventIDValue: eventID,
            expectedParticipantID: participantID
        ), decline.publicationID == event.publicationID else {
            unavailableDeclineEventIDs.insert(eventID)
            reconcileParticipationState(for: eventID)
            return
        }
        currentUserDeclines[eventID] = decline
        serverDeclineEventIDs.insert(eventID)
        unavailableDeclineEventIDs.remove(eventID)
        reconcileParticipationState(for: eventID)
        reconcileFriendRosterListener(for: event, participantID: participantID)
    }

    private func reconcileParticipationState(for eventID: String) {
        guard !unavailableAttendanceEventIDs.contains(eventID),
              !unavailableDeclineEventIDs.contains(eventID) else {
            participationStates[eventID] = .unavailable
            return
        }
        guard serverAttendanceEventIDs.contains(eventID),
              serverDeclineEventIDs.contains(eventID) else {
            participationStates[eventID] = .loading
            return
        }
        switch (
            currentUserAttendances[eventID] != nil,
            currentUserDeclines[eventID] != nil
        ) {
        case (true, false):
            participationStates[eventID] = .attending
        case (false, true):
            participationStates[eventID] = .declined
        case (false, false):
            participationStates[eventID] = .notResponded
        case (true, true):
            participationStates[eventID] = .unavailable
        }
    }

    private func removePersonalResponseListeners(for eventID: String) {
        attendanceListenerTokens.removeValue(forKey: eventID)
        declineListenerTokens.removeValue(forKey: eventID)
        observedPublicationIDs.removeValue(forKey: eventID)
        attendanceListeners.removeValue(forKey: eventID)?.remove()
        declineListeners.removeValue(forKey: eventID)?.remove()
        currentUserAttendances.removeValue(forKey: eventID)
        currentUserDeclines.removeValue(forKey: eventID)
        serverAttendanceEventIDs.remove(eventID)
        serverDeclineEventIDs.remove(eventID)
        unavailableAttendanceEventIDs.remove(eventID)
        unavailableDeclineEventIDs.remove(eventID)
        participationStates.removeValue(forKey: eventID)
        removeFriendRosterListener(for: eventID)
    }

    // MARK: - Friend event roster listeners

    private func reconcileFriendRosterListener(
        for event: OutingPlan,
        participantID: String
    ) {
        let eventID = event.eventIDValue
        guard shouldObserveFriendRoster(
            for: event,
            participantID: participantID
        ) else {
            removeFriendRosterListener(for: eventID)
            return
        }
        guard friendRosterPublicationIDs[eventID]
                != event.publicationIDValue
                || friendDeclineRosterPublicationIDs[eventID]
                != event.publicationIDValue else {
            return
        }

        removeFriendRosterListener(for: eventID)
        let token = UUID()
        friendRosterListenerTokens[eventID] = token
        friendRosterPublicationIDs[eventID] = event.publicationIDValue
        let declineToken = UUID()
        friendDeclineRosterListenerTokens[eventID] = declineToken
        friendDeclineRosterPublicationIDs[eventID] = event.publicationIDValue
        rosterStates[eventID] = .loading
        friendRosterListeners[eventID] = attendeesCollection(for: event)
            .whereField("publicationId", isEqualTo: event.publicationIDValue)
            .addSnapshotListener(
                includeMetadataChanges: true
            ) { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    guard let self,
                          self.friendRosterListenerTokens[eventID] == token else {
                        return
                    }
                    self.handleFriendRosterSnapshot(
                        snapshot,
                        error: error,
                        event: event
                    )
                }
            }
        friendDeclineRosterListeners[eventID] = declinesCollection(for: event)
            .whereField("publicationId", isEqualTo: event.publicationIDValue)
            .addSnapshotListener(
                includeMetadataChanges: true
            ) { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    guard let self,
                          self.friendDeclineRosterListenerTokens[eventID]
                            == declineToken else {
                        return
                    }
                    self.handleFriendDeclineRosterSnapshot(
                        snapshot,
                        error: error,
                        event: event
                    )
                }
            }
    }

    private func shouldObserveFriendRoster(
        for event: OutingPlan,
        participantID: String
    ) -> Bool {
        guard event.ownerID != participantID,
              acceptedFriendUserIDs.contains(event.ownerID) else {
            return false
        }
        return selectedEventID == event.eventIDValue
            || isAttending(
                eventIDValue: event.eventIDValue,
                publicationIDValue: event.publicationIDValue
            )
    }

    private func handleFriendRosterSnapshot(
        _ snapshot: QuerySnapshot?,
        error: Error?,
        event: OutingPlan
    ) {
        let eventID = event.eventIDValue
        guard error == nil, let snapshot else {
            removeFriendRosterListener(for: eventID)
            rosterStates[eventID] = .unavailable
            return
        }
        guard !snapshot.metadata.isFromCache else {
            friendEventAttendances.removeValue(forKey: eventID)
            attendanceRosterLoadedEventIDs.remove(eventID)
            reconcileRosterState(for: eventID)
            return
        }

        friendEventAttendances[eventID] = validAttendances(
            in: snapshot,
            for: event
        )
        attendanceRosterLoadedEventIDs.insert(eventID)
        reconcileRosterState(for: eventID)
    }

    private func handleFriendDeclineRosterSnapshot(
        _ snapshot: QuerySnapshot?,
        error: Error?,
        event: OutingPlan
    ) {
        let eventID = event.eventIDValue
        guard error == nil, let snapshot else {
            removeFriendRosterListener(for: eventID)
            rosterStates[eventID] = .unavailable
            return
        }
        guard !snapshot.metadata.isFromCache else {
            friendEventDeclines.removeValue(forKey: eventID)
            declineRosterLoadedEventIDs.remove(eventID)
            reconcileRosterState(for: eventID)
            return
        }
        friendEventDeclines[eventID] = validDeclines(in: snapshot, for: event)
        declineRosterLoadedEventIDs.insert(eventID)
        reconcileRosterState(for: eventID)
    }

    private func removeFriendRosterListener(for eventID: String) {
        friendRosterListenerTokens.removeValue(forKey: eventID)
        friendRosterPublicationIDs.removeValue(forKey: eventID)
        friendRosterListeners.removeValue(forKey: eventID)?.remove()
        friendDeclineRosterListenerTokens.removeValue(forKey: eventID)
        friendDeclineRosterPublicationIDs.removeValue(forKey: eventID)
        friendDeclineRosterListeners.removeValue(forKey: eventID)?.remove()
        friendEventAttendances.removeValue(forKey: eventID)
        friendEventDeclines.removeValue(forKey: eventID)
        attendanceRosterLoadedEventIDs.remove(eventID)
        declineRosterLoadedEventIDs.remove(eventID)
        rosterStates.removeValue(forKey: eventID)
    }

    // MARK: - Owned event listeners

    private func reconcileOwnEventListeners(
        with events: [String: OutingPlan],
        ownerID: String
    ) {
        let desiredEventIDs = Set(events.keys)
        let observedEventIDs = Set(ownEventListeners.keys)
            .union(ownDeclineListeners.keys)
        for eventID in observedEventIDs.subtracting(desiredEventIDs) {
            removeOwnEventListener(for: eventID)
        }

        for eventID in desiredEventIDs.sorted() {
            guard let event = events[eventID],
                  event.ownerID == ownerID else {
                continue
            }
            guard ownEventPublicationIDs[eventID]
                    != event.publicationIDValue
                    || ownDeclinePublicationIDs[eventID]
                    != event.publicationIDValue else {
                continue
            }

            removeOwnEventListener(for: eventID)
            let token = UUID()
            ownEventListenerTokens[eventID] = token
            ownEventPublicationIDs[eventID] = event.publicationIDValue
            let declineToken = UUID()
            ownDeclineListenerTokens[eventID] = declineToken
            ownDeclinePublicationIDs[eventID] = event.publicationIDValue
            rosterStates[eventID] = .loading
            ownEventListeners[eventID] = attendeesCollection(for: event)
                .whereField(
                    "publicationId",
                    isEqualTo: event.publicationIDValue
                )
                .addSnapshotListener(
                    includeMetadataChanges: true
                ) { [weak self] snapshot, error in
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
            ownDeclineListeners[eventID] = declinesCollection(for: event)
                .whereField(
                    "publicationId",
                    isEqualTo: event.publicationIDValue
                )
                .addSnapshotListener(
                    includeMetadataChanges: true
                ) { [weak self] snapshot, error in
                    DispatchQueue.main.async {
                        guard let self,
                              self.ownDeclineListenerTokens[eventID]
                                == declineToken else {
                            return
                        }
                        self.handleOwnDeclineSnapshot(
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
            let eventID = event.eventIDValue
            removeOwnEventListener(for: eventID)
            rosterStates[eventID] = .unavailable
            return
        }
        guard !snapshot.metadata.isFromCache else {
            ownEventAttendances.removeValue(forKey: event.eventIDValue)
            attendanceRosterLoadedEventIDs.remove(event.eventIDValue)
            reconcileRosterState(for: event.eventIDValue)
            return
        }
        ownEventAttendances[event.eventIDValue] = validAttendances(
            in: snapshot,
            for: event
        )
        attendanceRosterLoadedEventIDs.insert(event.eventIDValue)
        reconcileRosterState(for: event.eventIDValue)
    }

    private func handleOwnDeclineSnapshot(
        _ snapshot: QuerySnapshot?,
        error: Error?,
        event: OutingPlan
    ) {
        let eventID = event.eventIDValue
        guard error == nil, let snapshot else {
            removeOwnEventListener(for: eventID)
            rosterStates[eventID] = .unavailable
            return
        }
        guard !snapshot.metadata.isFromCache else {
            ownEventDeclines.removeValue(forKey: eventID)
            declineRosterLoadedEventIDs.remove(eventID)
            reconcileRosterState(for: eventID)
            return
        }
        ownEventDeclines[eventID] = validDeclines(in: snapshot, for: event)
        declineRosterLoadedEventIDs.insert(eventID)
        reconcileRosterState(for: eventID)
    }

    private func removeOwnEventListener(for eventID: String) {
        ownEventListenerTokens.removeValue(forKey: eventID)
        ownEventPublicationIDs.removeValue(forKey: eventID)
        ownEventListeners.removeValue(forKey: eventID)?.remove()
        ownDeclineListenerTokens.removeValue(forKey: eventID)
        ownDeclinePublicationIDs.removeValue(forKey: eventID)
        ownDeclineListeners.removeValue(forKey: eventID)?.remove()
        ownEventAttendances.removeValue(forKey: eventID)
        ownEventDeclines.removeValue(forKey: eventID)
        attendanceRosterLoadedEventIDs.remove(eventID)
        declineRosterLoadedEventIDs.remove(eventID)
        rosterStates.removeValue(forKey: eventID)
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

    private func validDeclines(
        in snapshot: QuerySnapshot,
        for event: OutingPlan
    ) -> [OutingDecline] {
        snapshot.documents.compactMap { document in
            guard let decline = try? OutingDecline(
                document: document,
                ownerID: event.ownerID,
                eventIDValue: event.eventIDValue
            ), decline.publicationID == event.publicationID else {
                return nil
            }
            return decline
        }
        .sorted { lhs, rhs in
            if lhs.respondedAt != rhs.respondedAt {
                return lhs.respondedAt < rhs.respondedAt
            }
            return lhs.participantID < rhs.participantID
        }
    }

    private func reconcileRosterState(for eventID: String) {
        rosterStates[eventID] = attendanceRosterLoadedEventIDs.contains(eventID)
            && declineRosterLoadedEventIDs.contains(eventID)
            ? .available
            : .loading
    }

    private func filterPublishedState(validEvents: [String: OutingPlan]) {
        let validEventIDs = Set(validEvents.keys)
        currentUserAttendances = currentUserAttendances.filter {
            eventID, attendance in
            validEventIDs.contains(eventID)
                && acceptedFriendUserIDs.contains(attendance.ownerID)
                && attendanceListeners[eventID] != nil
        }
        currentUserDeclines = currentUserDeclines.filter {
            eventID, decline in
            validEventIDs.contains(eventID)
                && acceptedFriendUserIDs.contains(decline.ownerID)
                && declineListeners[eventID] != nil
        }
        participationStates = participationStates.filter { eventID, _ in
            validEventIDs.contains(eventID)
                && attendanceListeners[eventID] != nil
                && declineListeners[eventID] != nil
        }
        ownEventAttendances = ownEventAttendances.filter {
            eventID, _ in validEventIDs.contains(eventID)
        }
        friendEventAttendances = friendEventAttendances.filter {
            eventID, _ in
            validEventIDs.contains(eventID)
                && friendRosterListeners[eventID] != nil
        }
        ownEventDeclines = ownEventDeclines.filter {
            eventID, _ in validEventIDs.contains(eventID)
        }
        friendEventDeclines = friendEventDeclines.filter {
            eventID, _ in
            validEventIDs.contains(eventID)
                && friendDeclineRosterListeners[eventID] != nil
        }
        rosterStates = rosterStates.filter { eventID, _ in
            validEventIDs.contains(eventID)
                && ((friendRosterListeners[eventID] != nil
                    && friendDeclineRosterListeners[eventID] != nil)
                    || (ownEventListeners[eventID] != nil
                        && ownDeclineListeners[eventID] != nil))
        }
    }

    private func resetObservation() {
        attendanceListenerTokens.removeAll()
        declineListenerTokens.removeAll()
        observedPublicationIDs.removeAll()
        attendanceListeners.values.forEach { $0.remove() }
        attendanceListeners.removeAll()
        declineListeners.values.forEach { $0.remove() }
        declineListeners.removeAll()
        serverAttendanceEventIDs.removeAll()
        serverDeclineEventIDs.removeAll()
        unavailableAttendanceEventIDs.removeAll()
        unavailableDeclineEventIDs.removeAll()

        friendRosterListenerTokens.removeAll()
        friendRosterPublicationIDs.removeAll()
        friendRosterListeners.values.forEach { $0.remove() }
        friendRosterListeners.removeAll()
        friendDeclineRosterListenerTokens.removeAll()
        friendDeclineRosterPublicationIDs.removeAll()
        friendDeclineRosterListeners.values.forEach { $0.remove() }
        friendDeclineRosterListeners.removeAll()

        ownEventListenerTokens.removeAll()
        ownEventPublicationIDs.removeAll()
        ownEventListeners.values.forEach { $0.remove() }
        ownEventListeners.removeAll()
        ownDeclineListenerTokens.removeAll()
        ownDeclinePublicationIDs.removeAll()
        ownDeclineListeners.values.forEach { $0.remove() }
        ownDeclineListeners.removeAll()

        friendEventAttendances = [:]
        ownEventAttendances = [:]
        friendEventDeclines = [:]
        ownEventDeclines = [:]
        currentUserAttendances = [:]
        currentUserDeclines = [:]
        participationStates = [:]
        rosterStates = [:]
        attendanceRosterLoadedEventIDs = []
        declineRosterLoadedEventIDs = []
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

    private func declineReference(
        for event: OutingPlan,
        participantID: String
    ) throws -> DocumentReference {
        let documentID = try OutingDecline.documentID(
            publicationIDValue: event.publicationIDValue,
            participantID: participantID
        )
        return declinesCollection(for: event).document(documentID)
    }

    private func declinesCollection(
        for event: OutingPlan
    ) -> CollectionReference {
        database.collection("users")
            .document(event.ownerID)
            .collection("events")
            .document(event.eventIDValue)
            .collection("declines")
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
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .noAuthenticatedUser:
            return "Connecte-toi pour participer à cet événement."
        case .eventUnavailable:
            return "Cet événement n’est plus disponible."
        case .invalidProfile:
            return "Ton profil doit être synchronisé avant de participer."
        case .invalidResponse:
            return "Ta réponse n’a pas pu être confirmée. Réessaie."
        }
    }
}
