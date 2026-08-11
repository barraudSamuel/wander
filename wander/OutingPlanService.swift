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

    @Published private(set) var activePlans: [String: OutingPlan] = [:]

    private let database: Firestore
    private let currentUserID: @MainActor () -> String?
    private var observedCurrentUserID: String?
    private var planListeners: [String: ListenerRegistration] = [:]
    private var listenerTokens: [String: UUID] = [:]
    private var expirationTimer: Timer?
    private var expirationTimerToken: UUID?

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
        planListeners.values.forEach { $0.remove() }
        expirationTimer?.invalidate()
    }

    // MARK: - Observation

    /// Observes only the authenticated account and accepted friends by their
    /// deterministic document paths. Calling this method again incrementally
    /// reconciles listeners instead of recreating unchanged registrations.
    func observePlans(forAcceptedFriendUserIDs acceptedFriendUserIDs: Set<String>) {
        guard let authenticatedUserID = currentUserID(),
              !authenticatedUserID.isEmpty else {
            stopObserving()
            return
        }

        if observedCurrentUserID != authenticatedUserID {
            removeAllPlanListeners()
            activePlans = [:]
            observedCurrentUserID = authenticatedUserID
        }

        let desiredUserIDs = acceptedFriendUserIDs
            .filter { !$0.isEmpty && $0 != authenticatedUserID }
            .union([authenticatedUserID])

        let removedUserIDs = Set(planListeners.keys).subtracting(desiredUserIDs)
        for userID in removedUserIDs {
            removePlanListener(for: userID)
            activePlans.removeValue(forKey: userID)
        }

        let addedUserIDs = desiredUserIDs.subtracting(planListeners.keys)
        for userID in addedUserIDs.sorted() {
            addPlanListener(for: userID)
        }

        removeExpiredPlansAndScheduleTimer()
    }

    func stopObserving() {
        removeAllPlanListeners()
        observedCurrentUserID = nil
        if !activePlans.isEmpty {
            activePlans = [:]
        }
    }

    @discardableResult
    func publish(_ draft: OutingPlanDraft) async throws -> OutingPlan {
        let userID = try authenticatedUserID()
        let validatedDraft = try OutingPlan.validatedDraft(draft)
        let reference = planReference(for: userID)

        var data: [String: Any] = [
            "ownerId": userID,
            "publicationId": UUID().uuidString,
            "displayName": validatedDraft.displayName,
            "placeName": validatedDraft.placeName,
            "location": GeoPoint(
                latitude: validatedDraft.coordinate.latitude,
                longitude: validatedDraft.coordinate.longitude
            ),
            "plannedAt": Timestamp(date: validatedDraft.plannedAt),
            "expiresAt": Timestamp(
                date: validatedDraft.plannedAt.addingTimeInterval(
                    OutingPlan.activeInterval
                )
            ),
            "publishedAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "timeZoneIdentifier": validatedDraft.timeZoneIdentifier
        ]
        if let address = validatedDraft.address {
            data["address"] = address
        }

        try await reference.setData(data)
        let document = try await reference.getDocument(source: .server)
        guard document.exists else {
            throw OutingPlanServiceError.missingPublishedPlan
        }
        return try OutingPlan(document: document)
    }

    func fetchCurrentPlan() async throws -> OutingPlan? {
        let userID = try authenticatedUserID()
        let document = try await planReference(for: userID)
            .getDocument(source: .server)
        guard document.exists else { return nil }
        return try OutingPlan(document: document)
    }

    func cancelCurrentPlan() async throws {
        let userID = try authenticatedUserID()
        try await planReference(for: userID).delete()
    }

    private func addPlanListener(for userID: String) {
        let token = UUID()
        listenerTokens[userID] = token
        planListeners[userID] = planReference(for: userID)
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    guard let self,
                          self.listenerTokens[userID] == token else {
                        return
                    }
                    self.handlePlanSnapshot(
                        snapshot,
                        error: error,
                        expectedOwnerID: userID
                    )
                }
            }
    }

    private func handlePlanSnapshot(
        _ snapshot: DocumentSnapshot?,
        error: Error?,
        expectedOwnerID: String
    ) {
        guard error == nil,
              let snapshot,
              snapshot.exists,
              let plan = try? OutingPlan(document: snapshot),
              plan.ownerID == expectedOwnerID,
              plan.isActive() else {
            activePlans.removeValue(forKey: expectedOwnerID)
            removeExpiredPlansAndScheduleTimer()
            return
        }

        if activePlans[expectedOwnerID] != plan {
            activePlans[expectedOwnerID] = plan
        }
        removeExpiredPlansAndScheduleTimer()
    }

    private func removePlanListener(for userID: String) {
        listenerTokens.removeValue(forKey: userID)
        planListeners.removeValue(forKey: userID)?.remove()
    }

    private func removeAllPlanListeners() {
        listenerTokens.removeAll()
        planListeners.values.forEach { $0.remove() }
        planListeners.removeAll()
        invalidateExpirationTimer()
    }

    private func removeExpiredPlansAndScheduleTimer(
        referenceDate: Date = Date()
    ) {
        let expiredOwnerIDs = activePlans.compactMap { ownerID, plan in
            plan.isActive(at: referenceDate) ? nil : ownerID
        }
        if !expiredOwnerIDs.isEmpty {
            var remainingPlans = activePlans
            expiredOwnerIDs.forEach { remainingPlans.removeValue(forKey: $0) }
            activePlans = remainingPlans
        }

        invalidateExpirationTimer()
        guard let nextExpiration = activePlans.values
            .map(\.expiresAt)
            .min() else {
            return
        }

        let interval = max(nextExpiration.timeIntervalSince(referenceDate), 0.1)
        let token = UUID()
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.expirationTimerDidFire(token: token)
            }
        }
        expirationTimerToken = token
        expirationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func expirationTimerDidFire(token: UUID) {
        guard token == expirationTimerToken else { return }
        expirationTimerToken = nil
        expirationTimer = nil
        removeExpiredPlansAndScheduleTimer()
    }

    private func invalidateExpirationTimer() {
        expirationTimer?.invalidate()
        expirationTimer = nil
        expirationTimerToken = nil
    }

    private func authenticatedUserID() throws -> String {
        guard let userID = currentUserID(), !userID.isEmpty else {
            throw OutingPlanServiceError.noAuthenticatedUser
        }
        return userID
    }

    private func planReference(for userID: String) -> DocumentReference {
        database.collection("plans").document(userID)
    }
}

enum OutingPlanServiceError: LocalizedError, Equatable {
    case noAuthenticatedUser
    case missingPublishedPlan

    var errorDescription: String? {
        switch self {
        case .noAuthenticatedUser:
            return "Connecte-toi pour gérer une sortie."
        case .missingPublishedPlan:
            return "La sortie publiée n’a pas pu être relue. Réessaie."
        }
    }
}
