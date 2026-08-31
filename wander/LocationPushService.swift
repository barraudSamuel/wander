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
    private var refreshBaselineByUserID: [String: Date] = [:]
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
        authorizationStatus: CLAuthorizationStatus
    ) {
        currentUserID = userID
        let shouldMonitor = userID != nil
            && trackingEnabled
            && backgroundTrackingEnabled
            && authorizationStatus == .authorizedAlways

        if shouldMonitor {
            isSharingEligible = true
            sharedDefaults?.set(
                true,
                forKey: LocationPushSharedConfiguration.sharingEnabledKey
            )
            sharedDefaults?.set(
                userID,
                forKey: LocationPushSharedConfiguration.ownerIDKey
            )
            if !isMonitoringLocationPushes {
                startMonitoringLocationPushes()
            }
        } else {
            disableSharedConsent()
            if isSharingEligible
                || isMonitoringLocationPushes
                || defaults.string(forKey: Self.registeredOwnerIDKey) != nil {
                isSharingEligible = false
                stopMonitoringAndRemoveRegistration()
            }
        }
    }

    func requestRefresh(
        for friendUserID: String,
        currentLocation: FriendLocation?
    ) {
        guard !friendUserID.isEmpty,
              !refreshingFriendUserIDs.contains(friendUserID) else {
            return
        }

        refreshingFriendUserIDs.insert(friendUserID)
        refreshBaselineByUserID[friendUserID] =
            currentLocation?.updatedAt ?? .distantPast
        scheduleTimeout(for: friendUserID)

        let requestID = UUID().uuidString.lowercased()
        Task {
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
                    finishRefresh(for: friendUserID)
                    return
                }
            } catch {
                finishRefresh(for: friendUserID)
            }
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
        try? await removeCurrentRegistration()
        resetLocalState()
    }

    func prepareForAccountDeletion() async {
        try? await removeCurrentRegistration()
        resetLocalState()
    }

    // MARK: - Registration

    private func startMonitoringLocationPushes() {
        guard !isMonitoringLocationPushes else { return }
        isMonitoringLocationPushes = true
        serviceSession?.invalidate()
        serviceSession = CLServiceSession(authorization: .always)

        locationManager.startMonitoringLocationPushes { [weak self] token, error in
            Task { @MainActor in
                guard let self else { return }
                guard self.isSharingEligible,
                      error == nil,
                      let token,
                      !token.isEmpty else {
                    self.isMonitoringLocationPushes = false
                    return
                }
                await self.persist(token: token)
            }
        }
    }

    private func stopMonitoringAndRemoveRegistration() {
        locationManager.stopMonitoringLocationPushes()
        isMonitoringLocationPushes = false
        serviceSession?.invalidate()
        serviceSession = nil

        Task {
            try? await removeCurrentRegistrationDocument()
        }
    }

    private func persist(token: Data) async {
        guard let userID = currentUserID,
              isSharingEligible else { return }

        do {
            try await registrationReference(for: userID).setData([
                "token": token.map { String(format: "%02x", $0) }.joined(),
                "environment": Self.apnsEnvironment,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            defaults.set(userID, forKey: Self.registeredOwnerIDKey)
        } catch {
            // Registration is opportunistic. Existing location sharing remains active.
        }
    }

    private func removeCurrentRegistration() async throws {
        locationManager.stopMonitoringLocationPushes()
        isMonitoringLocationPushes = false
        isSharingEligible = false
        disableSharedConsent()
        serviceSession?.invalidate()
        serviceSession = nil
        try await removeCurrentRegistrationDocument()
    }

    private func removeCurrentRegistrationDocument() async throws {
        guard let ownerID = defaults.string(
            forKey: Self.registeredOwnerIDKey
        ) else {
            return
        }
        try await registrationReference(for: ownerID).delete()
        defaults.removeObject(forKey: Self.registeredOwnerIDKey)
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

    private func scheduleTimeout(for friendUserID: String) {
        refreshTimeoutTasks[friendUserID]?.cancel()
        refreshTimeoutTasks[friendUserID] = Task { [weak self] in
            try? await Task.sleep(for: Self.refreshTimeout)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.finishRefresh(for: friendUserID)
            }
        }
    }

    private func finishRefresh(for friendUserID: String) {
        refreshingFriendUserIDs.remove(friendUserID)
        refreshBaselineByUserID.removeValue(forKey: friendUserID)
        refreshTimeoutTasks.removeValue(forKey: friendUserID)?.cancel()
    }

    private func resetLocalState() {
        currentUserID = nil
        for task in refreshTimeoutTasks.values {
            task.cancel()
        }
        refreshTimeoutTasks.removeAll()
        refreshBaselineByUserID.removeAll()
        refreshingFriendUserIDs.removeAll()
    }

    private func disableSharedConsent() {
        sharedDefaults?.set(
            false,
            forKey: LocationPushSharedConfiguration.sharingEnabledKey
        )
        sharedDefaults?.removeObject(
            forKey: LocationPushSharedConfiguration.ownerIDKey
        )
    }
}
