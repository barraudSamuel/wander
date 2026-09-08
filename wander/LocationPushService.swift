//
//  LocationPushService.swift
//  wander
//

import Combine
import CoreLocation
import FirebaseFirestore
import FirebaseFunctions
import Foundation

@MainActor
final class LocationPushService: ObservableObject {
    static let shared = LocationPushService()

    @Published private(set) var refreshingFriendUserIDs: Set<String> = []

    private static let installationIDKey = "locationPush.installationID"
    private static let registeredOwnerIDKey = "locationPush.registeredOwnerID"
    private static let refreshTimeout: Duration = .seconds(20)

    private let database: Firestore
    private let functions: Functions
    private let defaults: UserDefaults
    private let sharedDefaults: UserDefaults?
    private let locationManager = CLLocationManager()
    private let installationID: String

    private var currentUserID: String?
    private var isSharingEligible = false
    private var isMonitoringLocationPushes = false
    private var serviceSession: CLServiceSession?
    private var registrationRevision = UUID()
    private var monitoringAttemptID: UUID?
    private var registrationTask: Task<Void, Never>?
    private var registrationOperationID = UUID()
    private var unavailableFriendUserIDs: Set<String> = []
    private var refreshBaselineByUserID: [String: Date] = [:]
    private var refreshRequestIDsByUserID: [String: String] = [:]
    private var refreshTimeoutTasks: [String: Task<Void, Never>] = [:]

    private init(
        database: Firestore = Firestore.firestore(),
        functions: Functions = Functions.functions(region: "asia-northeast3"),
        defaults: UserDefaults = .standard
    ) {
        self.database = database
        self.functions = functions
        self.defaults = defaults
        self.sharedDefaults = UserDefaults(
            suiteName: LocationPushSharedConfiguration.appGroupID
        )

        if let storedID = defaults.string(forKey: Self.installationIDKey),
           UUID(uuidString: storedID) != nil {
            installationID = storedID.lowercased()
        } else {
            let generatedID = UUID().uuidString.lowercased()
            installationID = generatedID
            defaults.set(generatedID, forKey: Self.installationIDKey)
        }
    }

    func synchronizeRegistration(
        userID: String?,
        trackingEnabled: Bool,
        backgroundTrackingEnabled: Bool,
        locationSharingAllowed: Bool,
        authorizationStatus: CLAuthorizationStatus
    ) {
        let shouldMonitor = userID != nil
            && trackingEnabled
            && backgroundTrackingEnabled
            && locationSharingAllowed
            && authorizationStatus == .authorizedAlways

        if currentUserID != userID || isSharingEligible != shouldMonitor {
            revokeRegistration()
            currentUserID = userID
            isSharingEligible = shouldMonitor
        }

        if shouldMonitor {
            sharedDefaults?.set(
                userID,
                forKey: LocationPushSharedConfiguration.ownerIDKey
            )
            if sharedDefaults?.bool(
                forKey: LocationPushSharedConfiguration.sharingEnabledKey
            ) != true {
                sharedDefaults?.set(
                    UUID().uuidString,
                    forKey: LocationPushSharedConfiguration.consentRevisionKey
                )
            }
            sharedDefaults?.set(
                true,
                forKey: LocationPushSharedConfiguration.sharingEnabledKey
            )
            if !isMonitoringLocationPushes {
                startMonitoringLocationPushes()
            }
        } else {
            disableSharedConsent()
            if let ownerID = defaults.string(forKey: Self.registeredOwnerIDKey),
               registrationTask == nil {
                enqueueRegistrationRemoval(for: ownerID)
            }
        }
    }

    func requestRefresh(
        for friendUserID: String,
        currentLocation: FriendLocation?
    ) {
        guard !friendUserID.isEmpty,
              !unavailableFriendUserIDs.contains(friendUserID),
              !refreshingFriendUserIDs.contains(friendUserID) else {
            return
        }

        refreshingFriendUserIDs.insert(friendUserID)
        refreshBaselineByUserID[friendUserID] =
            currentLocation?.updatedAt ?? .distantPast
        let requestID = UUID().uuidString.lowercased()
        refreshRequestIDsByUserID[friendUserID] = requestID
        scheduleTimeout(for: friendUserID, requestID: requestID)
        Task {
            guard refreshRequestIDsByUserID[friendUserID] == requestID,
                  !unavailableFriendUserIDs.contains(friendUserID) else { return }
            do {
                let result = try await functions
                    .httpsCallable("requestFriendLocationRefresh")
                    .call([
                        "targetUserId": friendUserID,
                        "requestId": requestID
                    ])
                guard let payload = result.data as? [String: Any],
                      let status = payload["status"] as? String,
                      status == "sent" else {
                    finishRefresh(for: friendUserID, requestID: requestID)
                    return
                }
            } catch {
                finishRefresh(for: friendUserID, requestID: requestID)
            }
        }
    }

    func receiveUnavailableFriends(_ userIDs: Set<String>) {
        unavailableFriendUserIDs = userIDs
        for userID in refreshingFriendUserIDs.intersection(userIDs) {
            finishRefresh(for: userID)
        }
    }

    func receiveLocations(_ locations: [String: FriendLocation]) {
        for friendUserID in refreshingFriendUserIDs {
            guard let baseline = refreshBaselineByUserID[friendUserID],
                  let location = locations[friendUserID],
                  location.updatedAt > baseline else {
                continue
            }
            finishRefresh(for: friendUserID)
        }
    }

    func prepareForSignOut() async {
        let removal = revokeRegistration()
        resetLocalState()
        await removal?.value
    }

    func prepareForAccountDeletion() async {
        let removal = revokeRegistration()
        resetLocalState()
        await removal?.value
    }

    // MARK: - Registration

    private func startMonitoringLocationPushes() {
        guard !isMonitoringLocationPushes else { return }
        isMonitoringLocationPushes = true
        let attemptID = UUID()
        let revision = registrationRevision
        monitoringAttemptID = attemptID
        serviceSession?.invalidate()
        serviceSession = CLServiceSession(authorization: .always)

        locationManager.startMonitoringLocationPushes { [weak self] token, error in
            guard let self else { return }
            Task { @MainActor in
                guard self.monitoringAttemptID == attemptID,
                      self.registrationRevision == revision else { return }
                guard self.isSharingEligible,
                      error == nil,
                      let token,
                      !token.isEmpty else {
                    self.isMonitoringLocationPushes = false
                    self.monitoringAttemptID = nil
                    self.serviceSession?.invalidate()
                    self.serviceSession = nil
                    return
                }
                self.enqueueRegistration(token: token, revision: revision)
            }
        }
    }

    @discardableResult
    private func revokeRegistration() -> Task<Void, Never>? {
        // Capture owners before changing account state. Serialize deletion behind
        // any in-flight token write, and before a later registration.
        let ownerIDs = Set([
            currentUserID,
            defaults.string(forKey: Self.registeredOwnerIDKey)
        ].compactMap { $0 })
        registrationRevision = UUID()
        monitoringAttemptID = nil
        isSharingEligible = false
        disableSharedConsent()
        locationManager.stopMonitoringLocationPushes()
        isMonitoringLocationPushes = false
        serviceSession?.invalidate()
        serviceSession = nil

        for ownerID in ownerIDs {
            enqueueRegistrationRemoval(for: ownerID)
        }
        return registrationTask
    }

    private func enqueueRegistration(token: Data, revision: UUID) {
        guard let userID = currentUserID,
              isSharingEligible,
              registrationRevision == revision else { return }

        enqueueRegistrationOperation { [self] in
            guard currentUserID == userID,
                  isSharingEligible,
                  registrationRevision == revision else { return }
            do {
                try await registrationReference(for: userID).setData([
                    "token": token.map { String(format: "%02x", $0) }.joined(),
                    "environment": Self.apnsEnvironment,
                    "updatedAt": FieldValue.serverTimestamp()
                ])
                // A revocation queued during this write will remove this owner
                // next. Remember it even if that deletion needs a later retry.
                defaults.set(userID, forKey: Self.registeredOwnerIDKey)
            } catch {
                // Registration is opportunistic; publication checks consent separately.
            }
        }
    }

    private func enqueueRegistrationRemoval(for ownerID: String) {
        enqueueRegistrationOperation { [self] in
            do {
                try await registrationReference(for: ownerID).delete()
                if defaults.string(forKey: Self.registeredOwnerIDKey) == ownerID {
                    defaults.removeObject(forKey: Self.registeredOwnerIDKey)
                }
            } catch {
                // Keep the saved owner so a later synchronization can retry.
            }
        }
    }

    private func enqueueRegistrationOperation(
        _ operation: @escaping @MainActor () async -> Void
    ) {
        let previousTask = registrationTask
        let operationID = UUID()
        registrationOperationID = operationID
        registrationTask = Task { [self] in
            await previousTask?.value
            await operation()
            if registrationOperationID == operationID {
                registrationTask = nil
            }
        }
    }

    private func registrationReference(for userID: String) -> DocumentReference {
        database
            .collection("users")
            .document(userID)
            .collection("locationPushDevices")
            .document(installationID)
    }

    private static var apnsEnvironment: String {
        #if DEBUG
        "sandbox"
        #else
        "production"
        #endif
    }

    // MARK: - Refresh lifecycle

    private func scheduleTimeout(for friendUserID: String, requestID: String) {
        refreshTimeoutTasks[friendUserID]?.cancel()
        refreshTimeoutTasks[friendUserID] = Task { [weak self] in
            try? await Task.sleep(for: Self.refreshTimeout)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.finishRefresh(for: friendUserID, requestID: requestID)
            }
        }
    }

    private func finishRefresh(for friendUserID: String, requestID: String? = nil) {
        if let requestID, refreshRequestIDsByUserID[friendUserID] != requestID {
            return
        }
        refreshingFriendUserIDs.remove(friendUserID)
        refreshBaselineByUserID.removeValue(forKey: friendUserID)
        refreshRequestIDsByUserID.removeValue(forKey: friendUserID)
        refreshTimeoutTasks.removeValue(forKey: friendUserID)?.cancel()
    }

    private func resetLocalState() {
        currentUserID = nil
        for task in refreshTimeoutTasks.values {
            task.cancel()
        }
        refreshTimeoutTasks.removeAll()
        refreshBaselineByUserID.removeAll()
        refreshRequestIDsByUserID.removeAll()
        refreshingFriendUserIDs.removeAll()
        unavailableFriendUserIDs.removeAll()
    }

    private func disableSharedConsent() {
        sharedDefaults?.set(
            false,
            forKey: LocationPushSharedConfiguration.sharingEnabledKey
        )
        sharedDefaults?.removeObject(
            forKey: LocationPushSharedConfiguration.ownerIDKey
        )
        sharedDefaults?.removeObject(
            forKey: LocationPushSharedConfiguration.consentRevisionKey
        )
    }
}
