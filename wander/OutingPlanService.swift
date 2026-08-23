//
//  OutingPlanService.swift
//  wander
//

import Combine
import CoreLocation
import FirebaseFirestore
import Foundation

@MainActor
final class OutingPlanService: ObservableObject {
    static let shared = OutingPlanService()

    /// Events indexed by their stable Firestore `eventId`.
    @Published private(set) var events: [String: OutingPlan] = [:]

    private let database: Firestore
    private let currentUserID: @MainActor () -> String?
    private let publisher: OutingPlanPublisher
    private var observedCurrentUserID: String?
    private var eventListeners: [String: ListenerRegistration] = [:]
    private var listenerTokens: [String: UUID] = [:]
    private var eventIDsByOwnerID: [String: Set<String>] = [:]

    init(
        database: Firestore = Firestore.firestore(),
        currentUserID: @escaping @MainActor () -> String? = {
            FirebaseService.shared.currentUserId
        }
    ) {
        self.database = database
        self.currentUserID = currentUserID
        self.publisher = OutingPlanPublisher(database: database)
    }

    deinit {
        eventListeners.values.forEach { $0.remove() }
    }

    // MARK: - Observation

    /// Observes the event collections belonging to the authenticated account
    /// and its accepted friends. Unchanged registrations are preserved.
    func observeEvents(forAcceptedFriendUserIDs acceptedFriendUserIDs: Set<String>) {
        guard let authenticatedUserID = currentUserID(),
              !authenticatedUserID.isEmpty else {
            stopObserving()
            return
        }

        if observedCurrentUserID != authenticatedUserID {
            removeAllEventListeners()
            events = [:]
            observedCurrentUserID = authenticatedUserID
        }

        let desiredUserIDs = acceptedFriendUserIDs
            .filter { !$0.isEmpty && $0 != authenticatedUserID }
            .union([authenticatedUserID])

        let removedUserIDs = Set(eventListeners.keys).subtracting(desiredUserIDs)
        for userID in removedUserIDs {
            removeEventListener(for: userID)
        }

        let addedUserIDs = desiredUserIDs.subtracting(eventListeners.keys)
        for userID in addedUserIDs.sorted() {
            addEventListener(for: userID)
        }
    }

    func stopObserving() {
        removeAllEventListeners()
        observedCurrentUserID = nil
        if !events.isEmpty {
            events = [:]
        }
    }

    // MARK: - Mutation

    @discardableResult
    func publish(
        _ draft: OutingPlanDraft,
        existingPlan: OutingPlan? = nil
    ) async throws -> OutingPlan {
        let userID = try authenticatedUserID()
        if let existingPlan {
            return try await publisher.update(
                draft,
                existingPlan: existingPlan,
                ownerID: userID
            )
        }
        return try await publisher.publish(
            draft,
            ownerID: userID
        )
    }

    func fetchEvent(eventIDValue: String) async throws -> OutingPlan? {
        let userID = try authenticatedUserID()
        guard UUID(uuidString: eventIDValue) != nil else {
            throw OutingPlanServiceError.invalidEventID
        }
        let document = try await eventReference(
            ownerID: userID,
            eventID: eventIDValue
        )
        .getDocument(source: .server)
        guard document.exists else { return nil }
        return try OutingPlan(document: document)
    }

    /// Re-reads a notification destination under the current Firestore rules.
    /// The payload alone is never trusted to reveal or center a destination.
    func refreshEventFromNotification(
        ownerID: String,
        eventIDValue: String,
        publicationID: UUID
    ) async throws -> OutingPlan {
        _ = try authenticatedUserID()
        guard !ownerID.isEmpty,
              ownerID.count <= 128,
              !ownerID.contains("__"),
              UUID(uuidString: eventIDValue) != nil else {
            throw OutingPlanServiceError.notificationEventUnavailable
        }

        let document: DocumentSnapshot
        do {
            document = try await eventReference(
                ownerID: ownerID,
                eventID: eventIDValue
            )
            .getDocument(source: .server)
        } catch {
            let nsError = error as NSError
            if nsError.domain == FirestoreErrorDomain,
               nsError.code == FirestoreErrorCode.permissionDenied.rawValue
                || nsError.code == FirestoreErrorCode.notFound.rawValue
                || nsError.code == FirestoreErrorCode.unauthenticated.rawValue {
                throw OutingPlanServiceError.notificationEventUnavailable
            }
            throw error
        }
        guard document.exists else {
            throw OutingPlanServiceError.notificationEventUnavailable
        }

        let event = try OutingPlan(document: document)
        guard event.ownerID == ownerID,
              event.eventIDValue == eventIDValue,
              event.publicationID == publicationID else {
            throw OutingPlanServiceError.notificationEventUnavailable
        }

        events[event.eventIDValue] = event
        eventIDsByOwnerID[ownerID, default: []].insert(event.eventIDValue)
        return event
    }

    func cancel(eventIDValue: String) async throws {
        let userID = try authenticatedUserID()
        guard UUID(uuidString: eventIDValue) != nil else {
            throw OutingPlanServiceError.invalidEventID
        }
        try await eventReference(
            ownerID: userID,
            eventID: eventIDValue
        )
        .delete()
    }

    // MARK: - Listener reconciliation

    private func addEventListener(for userID: String) {
        let token = UUID()
        listenerTokens[userID] = token
        eventListeners[userID] = eventsCollection(ownerID: userID)
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    guard let self,
                          self.listenerTokens[userID] == token else {
                        return
                    }
                    self.handleEventSnapshot(
                        snapshot,
                        error: error,
                        expectedOwnerID: userID
                    )
                }
            }
    }

    private func handleEventSnapshot(
        _ snapshot: QuerySnapshot?,
        error: Error?,
        expectedOwnerID: String
    ) {
        guard error == nil, let snapshot else {
            replaceEvents(for: expectedOwnerID, with: [:])
            return
        }

        let validEvents = snapshot.documents.reduce(
            into: [String: OutingPlan]()
        ) { result, document in
            guard let event = try? OutingPlan(document: document),
                  event.ownerID == expectedOwnerID else {
                return
            }
            result[event.eventIDValue] = event
        }
        replaceEvents(for: expectedOwnerID, with: validEvents)
    }

    private func replaceEvents(
        for ownerID: String,
        with replacement: [String: OutingPlan]
    ) {
        var updatedEvents = events
        for eventID in eventIDsByOwnerID[ownerID] ?? [] {
            updatedEvents.removeValue(forKey: eventID)
        }
        replacement.forEach { updatedEvents[$0.key] = $0.value }
        eventIDsByOwnerID[ownerID] = Set(replacement.keys)
        if updatedEvents != events {
            events = updatedEvents
        }
    }

    private func removeEventListener(for userID: String) {
        listenerTokens.removeValue(forKey: userID)
        eventListeners.removeValue(forKey: userID)?.remove()
        replaceEvents(for: userID, with: [:])
        eventIDsByOwnerID.removeValue(forKey: userID)
    }

    private func removeAllEventListeners() {
        listenerTokens.removeAll()
        eventListeners.values.forEach { $0.remove() }
        eventListeners.removeAll()
        eventIDsByOwnerID.removeAll()
    }

    // MARK: - Firestore paths

    private func eventsCollection(ownerID: String) -> CollectionReference {
        database.collection("users")
            .document(ownerID)
            .collection("events")
    }

    private func eventReference(
        ownerID: String,
        eventID: String
    ) -> DocumentReference {
        eventsCollection(ownerID: ownerID).document(eventID)
    }

    private func authenticatedUserID() throws -> String {
        guard let userID = currentUserID(), !userID.isEmpty else {
            throw OutingPlanServiceError.noAuthenticatedUser
        }
        return userID
    }
}
