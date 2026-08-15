//
//  NotificationService.swift
//  wander
//

import Combine
import FirebaseFirestore
import FirebaseMessaging
import Foundation
import UIKit
import UserNotifications

struct OutingNotificationRoute: Equatable {
    let ownerID: String
    let publicationID: UUID
}

struct FriendRequestNotificationRoute: Equatable {
    let friendshipID: String
}

@MainActor
final class NotificationService: ObservableObject {
    static let shared = NotificationService()

    static let enabledStorageKey = "notifications.outings.enabled"

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var isEnabled: Bool
    @Published private(set) var errorMessage: String?
    @Published private(set) var pendingRoute: OutingNotificationRoute?
    @Published private(set) var pendingFriendRequestRoute: FriendRequestNotificationRoute?

    private static let deviceIDStorageKey = "notifications.installationID"
    private static let registeredOwnerStorageKey = "notifications.registeredOwnerID"

    private let database: Firestore
    private let notificationCenter: UNUserNotificationCenter
    private let defaults: UserDefaults
    private let deviceID: String
    private var currentUserID: String?
    private var pendingToken: String?
    private var cancellables = Set<AnyCancellable>()

    private init(
        database: Firestore = Firestore.firestore(),
        notificationCenter: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = .standard
    ) {
        self.database = database
        self.notificationCenter = notificationCenter
        self.defaults = defaults
        self.isEnabled = defaults.bool(forKey: Self.enabledStorageKey)

        if let storedDeviceID = defaults.string(
            forKey: Self.deviceIDStorageKey
        ), UUID(uuidString: storedDeviceID) != nil {
            deviceID = storedDeviceID.lowercased()
        } else {
            let generatedDeviceID = UUID().uuidString.lowercased()
            deviceID = generatedDeviceID
            defaults.set(generatedDeviceID, forKey: Self.deviceIDStorageKey)
        }

        FirebaseService.shared.$currentUserId
            .removeDuplicates()
            .sink { [weak self] userID in
                self?.authenticatedUserDidChange(userID)
            }
            .store(in: &cancellables)
    }

    func configure(application: UIApplication) {
        Task {
            await refreshAuthorizationStatus()
            guard isEnabled, authorizationAllowsNotifications else { return }
            application.registerForRemoteNotifications()
            await synchronizeCurrentToken()
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await notificationCenter.notificationSettings()
        authorizationStatus = settings.authorizationStatus

        if settings.authorizationStatus == .denied, isEnabled {
            do {
                try await removeCurrentRegistration(invalidateToken: true)
                UIApplication.shared.unregisterForRemoteNotifications()
            } catch {
                errorMessage = Self.friendlyMessage(
                    for: error,
                    fallback: "Impossible de nettoyer cet appareil."
                )
            }
            setEnabledLocally(false)
        }
    }

    func enableNotifications() async {
        errorMessage = nil

        do {
            let granted: Bool
            if authorizationStatus == .notDetermined {
                granted = try await notificationCenter.requestAuthorization(
                    options: [.alert, .badge, .sound]
                )
            } else {
                granted = authorizationAllowsNotifications
            }

            await refreshAuthorizationStatus()
            guard granted, authorizationAllowsNotifications else {
                setEnabledLocally(false)
                return
            }

            setEnabledLocally(true)
            UIApplication.shared.registerForRemoteNotifications()
            await synchronizeCurrentToken()
        } catch {
            setEnabledLocally(false)
            errorMessage = Self.friendlyMessage(
                for: error,
                fallback: "Impossible d’activer les notifications."
            )
        }
    }

    func disableNotifications() async {
        errorMessage = nil

        do {
            try await removeCurrentRegistration(invalidateToken: true)
            UIApplication.shared.unregisterForRemoteNotifications()
            setEnabledLocally(false)
        } catch {
            errorMessage = Self.friendlyMessage(
                for: error,
                fallback: "Impossible de désactiver les notifications."
            )
        }
    }

    /// Removes the account/device association before Firebase Auth signs out,
    /// so a later account on the same installation cannot inherit its pushes.
    func prepareForSignOut() async throws {
        try await removeCurrentRegistration(invalidateToken: true)
        UIApplication.shared.unregisterForRemoteNotifications()
    }

    /// The account deletion flow also removes every remote device document.
    /// This method invalidates the current installation before that bulk work.
    func prepareForAccountDeletion() async throws {
        try await removeCurrentRegistration(invalidateToken: true)
        UIApplication.shared.unregisterForRemoteNotifications()
    }

    func receiveRegistrationToken(_ token: String?) {
        guard let token, !token.isEmpty else { return }
        pendingToken = token
        guard isEnabled, authorizationAllowsNotifications else { return }

        Task {
            await persistPendingTokenIfPossible()
        }
    }

    func remoteRegistrationDidFail(_ error: Error) {
        errorMessage = Self.friendlyMessage(
            for: error,
            fallback: "Impossible d’enregistrer cet appareil auprès d’Apple."
        )
    }

    func receiveNotification(userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else {
            return
        }

        switch type {
        case "outingPublished", "outingAttendanceCreated":
            guard let ownerID = userInfo["outingOwnerId"] as? String,
                  Self.isValidUserID(ownerID),
                  let publicationIDValue = userInfo["publicationId"] as? String,
                  let publicationID = UUID(uuidString: publicationIDValue) else {
                return
            }

            pendingFriendRequestRoute = nil
            pendingRoute = OutingNotificationRoute(
                ownerID: ownerID,
                publicationID: publicationID
            )
        case "friendRequestCreated":
            guard let friendshipID = userInfo["friendshipId"] as? String,
                  Self.isValidFriendshipID(friendshipID) else {
                return
            }

            pendingRoute = nil
            pendingFriendRequestRoute = FriendRequestNotificationRoute(
                friendshipID: friendshipID
            )
        default:
            return
        }
    }

    func consume(_ route: OutingNotificationRoute) {
        guard pendingRoute == route else { return }
        pendingRoute = nil
    }

    func consume(_ route: FriendRequestNotificationRoute) {
        guard pendingFriendRequestRoute == route else { return }
        pendingFriendRequestRoute = nil
    }

    func clearError() {
        errorMessage = nil
    }

    var authorizationAllowsNotifications: Bool {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            true
        case .notDetermined, .denied:
            false
        @unknown default:
            false
        }
    }

    // MARK: - Registration

    private func authenticatedUserDidChange(_ userID: String?) {
        currentUserID = userID
        guard let userID, isEnabled else { return }

        let registeredOwnerID = defaults.string(
            forKey: Self.registeredOwnerStorageKey
        )
        Task {
            if let registeredOwnerID, registeredOwnerID != userID {
                try? await deleteMessagingToken()
                pendingToken = nil
                defaults.removeObject(forKey: Self.registeredOwnerStorageKey)
            }

            await refreshAuthorizationStatus()
            guard authorizationAllowsNotifications else { return }
            UIApplication.shared.registerForRemoteNotifications()
            await synchronizeCurrentToken()
        }
    }

    private func synchronizeCurrentToken() async {
        guard isEnabled, authorizationAllowsNotifications else { return }

        do {
            pendingToken = try await fetchMessagingToken()
            await persistPendingTokenIfPossible()
        } catch {
            errorMessage = Self.friendlyMessage(
                for: error,
                fallback: "Impossible d’enregistrer cet appareil."
            )
        }
    }

    private func persistPendingTokenIfPossible() async {
        guard isEnabled,
              authorizationAllowsNotifications,
              let userID = currentUserID,
              !userID.isEmpty,
              let token = pendingToken,
              !token.isEmpty else {
            return
        }

        do {
            try await deviceReference(for: userID).setData(
                [
                    "token": token,
                    "platform": "ios",
                    "updatedAt": FieldValue.serverTimestamp()
                ]
            )
            defaults.set(userID, forKey: Self.registeredOwnerStorageKey)
        } catch {
            errorMessage = Self.friendlyMessage(
                for: error,
                fallback: "Impossible d’enregistrer cet appareil."
            )
        }
    }

    private func removeCurrentRegistration(
        invalidateToken: Bool
    ) async throws {
        if let userID = currentUserID, !userID.isEmpty {
            try await deviceReference(for: userID).delete()
        }

        if invalidateToken {
            try await deleteMessagingToken()
            pendingToken = nil
        }
        defaults.removeObject(forKey: Self.registeredOwnerStorageKey)
    }

    private func deviceReference(for userID: String) -> DocumentReference {
        database.collection("users")
            .document(userID)
            .collection("devices")
            .document(deviceID)
    }

    private func fetchMessagingToken() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            Messaging.messaging().token { token, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let token, !token.isEmpty {
                    continuation.resume(returning: token)
                } else {
                    continuation.resume(
                        throwing: NotificationServiceError.missingToken
                    )
                }
            }
        }
    }

    private func deleteMessagingToken() async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            Messaging.messaging().deleteToken { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func setEnabledLocally(_ enabled: Bool) {
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.enabledStorageKey)
    }

    private static func friendlyMessage(
        for error: Error,
        fallback: String
    ) -> String {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return "Connexion impossible. Vérifie ta connexion internet."
        }
        return fallback
    }

    private static func isValidUserID(_ value: String) -> Bool {
        !value.isEmpty && value.count <= 128 && !value.contains("__")
    }

    private static func isValidFriendshipID(_ value: String) -> Bool {
        let participants = value.components(separatedBy: "__")
        guard participants.count == 2,
              let first = participants.first,
              let second = participants.last else {
            return false
        }
        return isValidUserID(first)
            && isValidUserID(second)
            && first < second
    }
}

private enum NotificationServiceError: Error {
    case missingToken
}
