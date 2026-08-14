//
//  FriendSyncService.swift
//  wander
//

import Combine
import CoreLocation
import FirebaseFirestore
import Foundation

struct FriendContact: Identifiable, Equatable {
    let userID: String
    let displayName: String
    let avatarID: String
    let profileColorHex: String

    var id: String { userID }
}

struct FriendRequest: Identifiable, Equatable {
    let pairID: String
    let userID: String
    let displayName: String
    let avatarID: String
    let requestedBy: String

    var id: String { pairID }
}

struct FriendLocation: Equatable {
    static let maximumSampleAge: TimeInterval = 5 * 60
    static let maximumConfirmationAge: TimeInterval = 30 * 60
    static let maximumFutureTimestampSkew: TimeInterval = 60

    let userID: String
    let displayName: String
    let avatarID: String
    let profileColorHex: String
    let coordinate: CLLocationCoordinate2D
    let horizontalAccuracy: CLLocationAccuracy
    let sampledAt: Date
    let updatedAt: Date
    let receivedAt: Date
    let spotEnteredAt: Date?

    static func == (lhs: FriendLocation, rhs: FriendLocation) -> Bool {
        lhs.userID == rhs.userID
            && lhs.displayName == rhs.displayName
            && lhs.avatarID == rhs.avatarID
            && lhs.profileColorHex == rhs.profileColorHex
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
            && lhs.horizontalAccuracy == rhs.horizontalAccuracy
            && lhs.sampledAt == rhs.sampledAt
            && lhs.updatedAt == rhs.updatedAt
            && lhs.receivedAt == rhs.receivedAt
            && lhs.spotEnteredAt == rhs.spotEnteredAt
    }

    func isFresh(at referenceDate: Date = Date()) -> Bool {
        let age = referenceDate.timeIntervalSince(updatedAt)
        return age.isFinite
            && age >= -Self.maximumFutureTimestampSkew
            && age < Self.maximumConfirmationAge
            && Self.isCurrentSample(sampledAt: sampledAt, at: updatedAt)
    }

    static func isCurrentSample(
        sampledAt: Date,
        at referenceDate: Date
    ) -> Bool {
        let age = referenceDate.timeIntervalSince(sampledAt)
        return isValidLastKnown(sampledAt: sampledAt, at: referenceDate)
            && age < maximumSampleAge
    }

    static func isValidLastKnown(sampledAt: Date, at referenceDate: Date) -> Bool {
        let age = referenceDate.timeIntervalSince(sampledAt)
        return age.isFinite && age >= -maximumFutureTimestampSkew
    }
}

struct FriendExploration: Equatable {
    let userID: String
    let displayName: String
    let profileColorHex: String
    let cellIDs: Set<String>
}

enum OwnExplorationSyncState: Equatable {
    case idle
    case loading
    case ready
    case failed
}

enum AccountProfileOrigin: Equatable {
    case unresolved
    case created
    case existing
}

private struct RemoteProfile {
    let displayName: String
    let avatarID: String
    let profileColorHex: String
}

private struct FriendshipRecord {
    let pairID: String
    let participants: [String]
    let requestedBy: String
    let status: String
    let createdAt: Date?

    func otherUserID(for currentUserID: String) -> String? {
        participants.first { $0 != currentUserID }
    }
}

final class FriendSyncService: ObservableObject {
    static let shared = FriendSyncService()

    @Published private(set) var friendCode: String?
    @Published private(set) var incomingRequests: [FriendRequest] = []
    @Published private(set) var outgoingRequests: [FriendRequest] = []
    @Published private(set) var acceptedFriends: [FriendContact] = []
    @Published private var receivedFriendLocations: [String: FriendLocation] = [:]
    @Published private(set) var freshFriendLocationUserIDs: Set<String> = []
    @Published private var receivedFriendExplorationCellIDs: [String: Set<String>] = [:]
    @Published private(set) var friendExplorationRevision = 0
    @Published private(set) var isProfileReady = false
    @Published private(set) var isPreparingProfile = true
    @Published private(set) var hasLoadedOwnProfileFromServer = false
    @Published private(set) var accountProfileOrigin: AccountProfileOrigin = .unresolved
    @Published private(set) var ownExplorationCells: [RemoteDiscoveredCell] = []
    @Published private(set) var ownExplorationRevision = 0
    @Published private(set) var ownExplorationSyncState: OwnExplorationSyncState = .idle
    @Published private(set) var ownExplorationErrorMessage: String?
    @Published private(set) var accountBootstrapErrorMessage: String?
    @Published private(set) var isProcessingFriendAction = false
    @Published private(set) var isAccountDeletionPending = false
    @Published var errorMessage: String?

    var isAccountBootstrapResolved: Bool {
        hasLoadedOwnProfileFromServer
            && accountProfileOrigin != .unresolved
    }

    var friendLocations: [String: FriendLocation] {
        receivedFriendLocations
    }

    var friendExplorations: [String: FriendExploration] {
        Dictionary(
            uniqueKeysWithValues: acceptedFriends.map { friend in
                (
                    friend.userID,
                    FriendExploration(
                        userID: friend.userID,
                        displayName: friend.displayName,
                        profileColorHex: friend.profileColorHex,
                        cellIDs: receivedFriendExplorationCellIDs[friend.userID] ?? []
                    )
                )
            }
        )
    }

    /// A successful snapshot can legitimately contain zero cells. Keeping the
    /// loaded state separate prevents the UI from presenting "0%" while the
    /// first Firestore snapshot is still pending or has failed.
    var loadedFriendExplorationUserIDs: Set<String> {
        Set(receivedFriendExplorationCellIDs.keys)
    }

    private var db = Firestore.firestore()
    private let friendCodeAlphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    private let friendCodeLength = 11
    private let maximumProfileCreationAttempts = 8
    private let minimumLocationPushDistance: CLLocationDistance = 15
    private let minimumLocationPushInterval: TimeInterval = 10

    private var currentUserID: String?
    private var desiredDisplayName: String
    private var desiredAvatarID: String
    private var desiredProfileColorHex: String
    private var shouldAdoptRemoteAvatar: Bool
    private var shouldAdoptRemoteProfileColor: Bool
    private var lastKnownProfileDisplayName: String?
    private var lastKnownProfileAvatarID: String?
    private var lastKnownProfileColorHex: String?
    private var friendshipRecords: [String: FriendshipRecord] = [:]
    private var profilesByUserID: [String: RemoteProfile] = [:]

    private var ownProfileListener: ListenerRegistration?
    private var ownExplorationListener: ListenerRegistration?
    private var friendshipsListener: ListenerRegistration?
    private var profileListeners: [String: ListenerRegistration] = [:]
    private var locationListeners: [String: ListenerRegistration] = [:]
    private var locationFreshnessTimers: [String: Timer] = [:]
    private var explorationListeners: [String: ListenerRegistration] = [:]
    private var profileUpdateTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    private var isCreatingProfile = false
    private var isUpdatingProfile = false
    private var isUploadingExploration = false
    private var hasPendingDisplayNameEditBeforeProfileHydration = false
    private var hasPendingAvatarEditBeforeProfileHydration = false
    private var hasPendingProfileColorEditBeforeProfileHydration = false
    private var hasPendingDisplayNameChange = false
    private var hasPendingAvatarChange = false
    private var hasPendingProfileColorChange = false
    private var hasPendingUserSelectedProfileColor = false
    private var hasLoadedOwnExploration = false
    private var ownExplorationCellsByID: [String: RemoteDiscoveredCell] = [:]
    private var uploadedExplorationCellIDs: Set<String> = []
    private var desiredExplorationCellIDs: Set<String> = []
    private var pendingExplorationCellIDs: Set<String> = []
    private var uploadingExplorationCellIDs: Set<String> = []
    private var authenticationGeneration = 0
    private var latestLocationForSharing: (
        location: CLLocation,
        displayName: String,
        spotEnteredAt: Date?
    )?
    private var lastLocationPush: (
        location: CLLocation,
        attemptedAt: Date,
        spotEnteredAt: Date?
    )?
    private var shouldDeleteLocationWhenAuthenticated = false

    private init() {
        let storedAvatarID = UserDefaults.standard.string(
            forKey: ProfileAvatar.storageKey
        )
        let storedProfileColorHex = UserDefaults.standard.string(
            forKey: ProfileColor.storageKey
        )
        desiredDisplayName = Self.normalizedDisplayName(
            UserDefaults.standard.string(forKey: "profile.displayName") ?? ""
        )
        desiredAvatarID =
            ProfileAvatar.normalizedID(storedAvatarID)
            ?? ProfileAvatar.randomID()
        shouldAdoptRemoteAvatar = true
        shouldAdoptRemoteProfileColor =
            storedProfileColorHex.flatMap(ProfileColor.normalizedHex) == nil
        desiredProfileColorHex =
            storedProfileColorHex.flatMap(ProfileColor.normalizedHex)
            ?? ProfileColor.storedOrGeneratedHex()
        hasPendingUserSelectedProfileColor = UserDefaults.standard.bool(
            forKey: ProfileColor.pendingUserSelectionStorageKey
        )
        shouldDeleteLocationWhenAuthenticated =
            !UserDefaults.standard.bool(forKey: "trackingEnabled")

        FirebaseService.shared.$currentUserId
            .removeDuplicates()
            .sink { [weak self] userID in
                self?.handleAuthenticatedUserChange(userID)
            }
            .store(in: &cancellables)

        FirebaseService.shared.$authErrorMessage
            .compactMap { $0 }
            .sink { [weak self] message in
                self?.isPreparingProfile = false
                self?.errorMessage = message
            }
            .store(in: &cancellables)
    }

    deinit {
        removeAllListeners()
        profileUpdateTask?.cancel()
    }

    // MARK: - Public actions

    func clearError() {
        errorMessage = nil
        if !isProfileReady {
            isPreparingProfile = true
        }
        FirebaseService.shared.clearError()
        if !isProfileReady, let currentUserID {
            ensureProfile(for: currentUserID)
        }
    }

    func retryProfileSetup() {
        errorMessage = nil
        accountBootstrapErrorMessage = nil
        FirebaseService.shared.clearError()
        guard let currentUserID else { return }

        isPreparingProfile = true
        listenToOwnProfile(for: currentUserID)
        if accountProfileOrigin == .unresolved || !isProfileReady {
            ensureProfile(for: currentUserID)
        }
    }

    func retryOwnExplorationSync() {
        guard let currentUserID else { return }
        errorMessage = nil
        ownExplorationErrorMessage = nil
        listenToOwnExploration(for: currentUserID)
    }

    func updateDisplayName(_ displayName: String) {
        guard !isAccountDeletionPending else { return }

        let normalizedDisplayName = Self.normalizedDisplayName(displayName)
        guard normalizedDisplayName != desiredDisplayName else { return }

        desiredDisplayName = normalizedDisplayName
        if hasLoadedOwnProfileFromServer {
            hasPendingDisplayNameChange = true
        } else {
            hasPendingDisplayNameEditBeforeProfileHydration = true
        }
        scheduleProfileUpdate()
    }

    func updateAvatarID(_ avatarID: String) {
        guard !isAccountDeletionPending,
              let normalizedAvatarID = ProfileAvatar.normalizedID(avatarID),
              normalizedAvatarID != desiredAvatarID else {
            return
        }

        desiredAvatarID = normalizedAvatarID
        shouldAdoptRemoteAvatar = false
        UserDefaults.standard.set(
            normalizedAvatarID,
            forKey: ProfileAvatar.storageKey
        )
        if let currentUserID {
            UserDefaults.standard.set(
                currentUserID,
                forKey: ProfileAvatar.ownerStorageKey
            )
        }
        if hasLoadedOwnProfileFromServer {
            hasPendingAvatarChange = true
        } else {
            hasPendingAvatarEditBeforeProfileHydration = true
        }
        scheduleProfileUpdate()
    }

    func updateProfileColor(
        _ profileColorHex: String,
        userInitiated: Bool = false
    ) {
        guard !isAccountDeletionPending else { return }

        let normalizedProfileColorHex =
            ProfileColor.normalizedHex(profileColorHex)
        desiredProfileColorHex =
            normalizedProfileColorHex ?? ProfileColor.storedOrGeneratedHex()

        if userInitiated {
            if hasLoadedOwnProfileFromServer {
                hasPendingProfileColorChange = true
            } else {
                hasPendingProfileColorEditBeforeProfileHydration = true
            }
        }

        if userInitiated {
            shouldAdoptRemoteProfileColor = false
            UserDefaults.standard.removeObject(
                forKey: ProfileColor.pendingOwnerStorageKey
            )
            if let currentUserID {
                hasPendingUserSelectedProfileColor = false
                UserDefaults.standard.set(
                    currentUserID,
                    forKey: ProfileColor.ownerStorageKey
                )
                UserDefaults.standard.set(
                    false,
                    forKey: ProfileColor.pendingUserSelectionStorageKey
                )
            } else {
                hasPendingUserSelectedProfileColor = true
                UserDefaults.standard.set(
                    true,
                    forKey: ProfileColor.pendingUserSelectionStorageKey
                )
            }
        } else if normalizedProfileColorHex == nil {
            shouldAdoptRemoteProfileColor = true
        }
        scheduleProfileUpdate()
    }

    /// Keeps the user's complete local exploration mirrored in Firestore.
    /// Existing remote cells are loaded first, so relaunching the app does not
    /// rewrite the full history.
    func syncDiscoveredCells(_ cellIDs: Set<String>) {
        guard !isAccountDeletionPending else { return }

        let validCellIDs = Set(cellIDs.filter(Self.isValidH3CellID))
        desiredExplorationCellIDs.formUnion(validCellIDs)
        if hasLoadedOwnExploration {
            pendingExplorationCellIDs.formUnion(
                validCellIDs.subtracting(uploadedExplorationCellIDs)
            )
        }
        uploadMissingExplorationCellsIfNeeded()
    }

    /// Adds only the cells discovered by the latest location update. Keeping this
    /// path incremental avoids filtering and diffing the complete local history.
    func addDiscoveredCells(_ cellIDs: Set<String>) {
        guard !isAccountDeletionPending else { return }

        for cellID in cellIDs where Self.isValidH3CellID(cellID) {
            desiredExplorationCellIDs.insert(cellID)
            if hasLoadedOwnExploration,
               !uploadedExplorationCellIDs.contains(cellID) {
                pendingExplorationCellIDs.insert(cellID)
            }
        }
        uploadMissingExplorationCellsIfNeeded()
    }

    func sendFriendRequest(
        code rawCode: String,
        completion: @escaping (Bool) -> Void
    ) {
        guard !isAccountDeletionPending else {
            completion(false)
            return
        }

        guard !isProcessingFriendAction else {
            completion(false)
            return
        }

        guard let currentUserID else {
            errorMessage = "Connexion à ton compte impossible. Réessaie."
            completion(false)
            return
        }

        let code = Self.normalizedFriendCode(rawCode)
        guard Self.isValidFriendCode(code) else {
            errorMessage = "Le code ami doit contenir 10 à 12 caractères valides."
            completion(false)
            return
        }

        isProcessingFriendAction = true
        let generation = authenticationGeneration

        db.collection("friendCodes").document(code).getDocument { [weak self] snapshot, error in
            DispatchQueue.main.async {
                guard let self else {
                    completion(false)
                    return
                }
                guard self.currentUserID == currentUserID,
                      self.authenticationGeneration == generation else {
                    completion(false)
                    return
                }

                if let error {
                    self.finishFriendAction(
                        success: false,
                        error: error,
                        completion: completion
                    )
                    return
                }

                guard let snapshot, snapshot.exists,
                      let targetUserID = snapshot.data()?["ownerId"] as? String,
                      !targetUserID.isEmpty else {
                    self.isProcessingFriendAction = false
                    self.errorMessage = "Ce code ami est introuvable."
                    completion(false)
                    return
                }

                guard targetUserID != currentUserID else {
                    self.isProcessingFriendAction = false
                    self.errorMessage = "Tu ne peux pas t’ajouter toi-même."
                    completion(false)
                    return
                }

                self.createPendingFriendship(
                    currentUserID: currentUserID,
                    targetUserID: targetUserID,
                    completion: completion
                )
            }
        }
    }

    func accept(_ request: FriendRequest) {
        guard !isAccountDeletionPending else { return }
        guard !isProcessingFriendAction else { return }
        guard let currentUserID,
              request.requestedBy != currentUserID,
              friendshipRecords[request.pairID]?.status == "pending" else {
            errorMessage = "Cette demande n’est plus disponible."
            return
        }

        isProcessingFriendAction = true
        let generation = authenticationGeneration
        let reference = db.collection("friendships").document(request.pairID)

        db.runTransaction({ transaction, errorPointer -> Any? in
            do {
                let snapshot = try transaction.getDocument(reference)
                guard snapshot.exists, let data = snapshot.data(),
                      data["status"] as? String == "pending",
                      let participants = data["participants"] as? [String],
                      participants.count == 2,
                      participants.contains(currentUserID),
                      let requestedBy = data["requestedBy"] as? String,
                      requestedBy != currentUserID else {
                    return "invalid"
                }

                transaction.updateData(
                    [
                        "status": "accepted",
                        "acceptedAt": FieldValue.serverTimestamp()
                    ],
                    forDocument: reference
                )
                return "accepted"
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self,
                      self.currentUserID == currentUserID,
                      self.authenticationGeneration == generation else {
                    return
                }
                self.isProcessingFriendAction = false

                if let error {
                    self.errorMessage = self.friendlyMessage(
                        for: error,
                        fallback: "Impossible d’accepter cette demande."
                    )
                } else if result as? String != "accepted" {
                    self.errorMessage = "Cette demande n’est plus disponible."
                }
            }
        }
    }

    func decline(_ request: FriendRequest) {
        guard !isAccountDeletionPending else { return }
        guard !isProcessingFriendAction else { return }
        guard let currentUserID,
              request.requestedBy != currentUserID,
              friendshipRecords[request.pairID]?.status == "pending" else {
            errorMessage = "Cette demande n’est plus disponible."
            return
        }

        isProcessingFriendAction = true
        let generation = authenticationGeneration
        let reference = db.collection("friendships").document(request.pairID)

        db.runTransaction({ transaction, errorPointer -> Any? in
            do {
                let snapshot = try transaction.getDocument(reference)
                guard snapshot.exists, let data = snapshot.data(),
                      data["status"] as? String == "pending",
                      let participants = data["participants"] as? [String],
                      participants.count == 2,
                      participants.contains(currentUserID),
                      let requestedBy = data["requestedBy"] as? String,
                      requestedBy != currentUserID else {
                    return "invalid"
                }

                transaction.deleteDocument(reference)
                return "declined"
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self,
                      self.currentUserID == currentUserID,
                      self.authenticationGeneration == generation else {
                    return
                }
                self.isProcessingFriendAction = false

                if let error {
                    self.errorMessage = self.friendlyMessage(
                        for: error,
                        fallback: "Impossible de refuser cette demande."
                    )
                } else if result as? String != "declined" {
                    self.errorMessage = "Cette demande n’est plus disponible."
                }
            }
        }
    }

    func removeFriend(userID: String) {
        guard !isAccountDeletionPending else { return }
        guard !isProcessingFriendAction else { return }
        guard let currentUserID,
              let friendship = friendshipRecords.values.first(where: { record in
                  record.status == "accepted"
                      && record.otherUserID(for: currentUserID) == userID
              }) else {
            errorMessage = "Cette relation d’amitié n’est plus disponible."
            return
        }

        isProcessingFriendAction = true
        let generation = authenticationGeneration
        let reference = db.collection("friendships").document(friendship.pairID)

        db.runTransaction({ transaction, errorPointer -> Any? in
            do {
                let snapshot = try transaction.getDocument(reference)
                guard snapshot.exists else {
                    return "removed"
                }
                guard let data = snapshot.data(),
                      data["status"] as? String == "accepted",
                      let participants = data["participants"] as? [String],
                      participants.count == 2,
                      participants.contains(currentUserID),
                      participants.contains(userID) else {
                    return "invalid"
                }

                transaction.deleteDocument(reference)
                return "removed"
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self,
                      self.currentUserID == currentUserID,
                      self.authenticationGeneration == generation else {
                    return
                }
                self.isProcessingFriendAction = false

                if let error {
                    self.errorMessage = self.friendlyMessage(
                        for: error,
                        fallback: "Impossible de supprimer cet ami."
                    )
                } else if result as? String == "removed" {
                    if self.friendshipRecords[friendship.pairID]?.status == "accepted" {
                        self.friendshipRecords.removeValue(forKey: friendship.pairID)
                        self.reconcileRelatedListeners()
                        self.rebuildPublishedRelationships()
                    }
                } else {
                    self.errorMessage = "Cette relation d’amitié n’est plus disponible."
                }
            }
        }
    }

    func updateLocation(
        _ location: CLLocation,
        displayName: String,
        spotEnteredAt: Date?
    ) {
        guard !isAccountDeletionPending else { return }

        guard location.horizontalAccuracy > 0,
              location.horizontalAccuracy <= 1_000,
              CLLocationCoordinate2DIsValid(location.coordinate),
              FriendLocation.isCurrentSample(
                sampledAt: location.timestamp,
                at: Date()
              ) else {
            return
        }

        let normalizedName = Self.normalizedDisplayName(displayName)
        let validSpotEnteredAt = Self.validSpotEnteredAt(
            spotEnteredAt,
            sampledAt: location.timestamp
        )
        latestLocationForSharing = (
            location,
            normalizedName,
            validSpotEnteredAt
        )
        shouldDeleteLocationWhenAuthenticated = false

        guard let currentUserID else { return }
        writeLocation(
            location,
            displayName: normalizedName,
            spotEnteredAt: validSpotEnteredAt,
            for: currentUserID,
            bypassThrottle: false
        )
    }

    func stopSharingLocation() {
        latestLocationForSharing = nil
        lastLocationPush = nil
        shouldDeleteLocationWhenAuthenticated = true

        guard let currentUserID else { return }
        deleteOwnLocation(for: currentUserID)
    }

    /// Deletes every Firestore document owned by or linking the current user.
    /// The operation is idempotent: after the remote deletion marker is set,
    /// synchronization stays suspended and a later Apple authorization can
    /// safely retry any remaining batches.
    func deleteCurrentAccountData() async throws {
        guard let userID = currentUserID else {
            throw AccountDataDeletionError.noAuthenticatedUser
        }

        let userReference = db.collection("users").document(userID)
        let profileSnapshot = try await userReference.getDocument(source: .server)
        let friendCode = profileSnapshot.data()?["friendCode"] as? String

        if profileSnapshot.exists,
           profileSnapshot.data()?["deletionRequestedAt"] == nil {
            try await userReference.updateData(
                [
                    "deletionRequestedAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp()
                ]
            )
        }

        suspendSynchronizationForAccountDeletion()

        try await deleteDocumentsInBatches(
            from: explorationCellsCollection(for: userID)
        )
        try await deleteDocumentsInBatches(
            from: db.collection("friendships")
                .whereField("participants", arrayContains: userID)
        )
        try await db.collection("locations").document(userID).delete()
        try await db.collection("plans").document(userID).delete()

        guard profileSnapshot.exists else { return }
        guard let friendCode, Self.isValidFriendCode(friendCode) else {
            throw AccountDataDeletionError.invalidProfile
        }

        let finalBatch = db.batch()
        finalBatch.deleteDocument(
            db.collection("friendCodes").document(friendCode)
        )
        finalBatch.deleteDocument(userReference)
        try await finalBatch.commit()
    }

    /// Removes Firestore's on-disk cache after all remote writes are confirmed.
    /// The next `Firestore.firestore()` call creates a usable fresh instance.
    func clearLocalFirestoreCache() async throws {
        authenticationGeneration &+= 1
        removeAllListeners()
        profileUpdateTask?.cancel()
        profileUpdateTask = nil

        let currentDatabase = db
        try await currentDatabase.terminate()
        defer { db = Firestore.firestore() }
        try await currentDatabase.clearPersistence()
    }

    func accountDeletionMessage(for error: Error) -> String {
        if let deletionError = error as? AccountDataDeletionError {
            return deletionError.errorDescription
                ?? "La suppression du compte n’a pas pu aboutir. Réessaie."
        }

        return friendlyMessage(
            for: error,
            fallback: "La suppression du compte n’a pas pu aboutir. Réessaie."
        )
    }

    // MARK: - Authentication and profile

    private func handleAuthenticatedUserChange(_ userID: String?) {
        guard currentUserID != userID else { return }

        authenticationGeneration &+= 1
        removeAllListeners()
        profileUpdateTask?.cancel()
        profileUpdateTask = nil
        currentUserID = userID
        friendCode = nil
        isProfileReady = false
        isPreparingProfile =
            userID != nil || !FirebaseService.shared.isAuthenticationResolved
        isCreatingProfile = false
        isUpdatingProfile = false
        isUploadingExploration = false
        hasLoadedOwnProfileFromServer = false
        accountProfileOrigin = .unresolved
        accountBootstrapErrorMessage = nil
        hasPendingDisplayNameEditBeforeProfileHydration = false
        hasPendingAvatarEditBeforeProfileHydration = false
        hasPendingProfileColorEditBeforeProfileHydration = false
        hasPendingDisplayNameChange = false
        hasPendingAvatarChange = false
        hasPendingProfileColorChange = false
        hasLoadedOwnExploration = false
        ownExplorationCellsByID = [:]
        uploadedExplorationCellIDs = []
        pendingExplorationCellIDs = []
        uploadingExplorationCellIDs = []
        ownExplorationCells = []
        ownExplorationRevision &+= 1
        ownExplorationSyncState = userID == nil ? .idle : .loading
        ownExplorationErrorMessage = nil
        lastKnownProfileDisplayName = nil
        lastKnownProfileAvatarID = nil
        lastKnownProfileColorHex = nil
        friendshipRecords = [:]
        profilesByUserID = [:]
        incomingRequests = []
        outgoingRequests = []
        acceptedFriends = []
        receivedFriendLocations = [:]
        freshFriendLocationUserIDs = []
        receivedFriendExplorationCellIDs = [:]
        friendExplorationRevision &+= 1
        isProcessingFriendAction = false
        isAccountDeletionPending = false
        lastLocationPush = nil
        if userID != nil {
            errorMessage = nil
        } else {
            latestLocationForSharing = nil
            desiredExplorationCellIDs = []
        }

        guard let userID else { return }

        let storedAvatarID = UserDefaults.standard.string(
            forKey: ProfileAvatar.storageKey
        )
        let storedAvatarOwnerID = UserDefaults.standard.string(
            forKey: ProfileAvatar.ownerStorageKey
        )
        if storedAvatarOwnerID != userID
            || ProfileAvatar.normalizedID(storedAvatarID) == nil {
            desiredAvatarID = ProfileAvatar.randomID()
            UserDefaults.standard.set(
                desiredAvatarID,
                forKey: ProfileAvatar.storageKey
            )
        } else if let storedAvatarID = ProfileAvatar.normalizedID(
            storedAvatarID
        ) {
            desiredAvatarID = storedAvatarID
        }
        shouldAdoptRemoteAvatar = true
        UserDefaults.standard.set(
            userID,
            forKey: ProfileAvatar.ownerStorageKey
        )
        UserDefaults.standard.removeObject(forKey: "profile.avatarImageData")

        let storedProfileColorHex = UserDefaults.standard.string(
            forKey: ProfileColor.storageKey
        )
        let storedProfileColorOwnerID = UserDefaults.standard.string(
            forKey: ProfileColor.ownerStorageKey
        )
        var pendingProfileColorOwnerID = UserDefaults.standard.string(
            forKey: ProfileColor.pendingOwnerStorageKey
        )
        let profileColorBelongsToAnotherUser =
            storedProfileColorOwnerID != nil
            && storedProfileColorOwnerID != userID

        if hasPendingUserSelectedProfileColor {
            hasPendingUserSelectedProfileColor = false
            hasPendingProfileColorEditBeforeProfileHydration = true
            shouldAdoptRemoteProfileColor = false
            UserDefaults.standard.removeObject(
                forKey: ProfileColor.pendingOwnerStorageKey
            )
            UserDefaults.standard.set(
                false,
                forKey: ProfileColor.pendingUserSelectionStorageKey
            )
            UserDefaults.standard.set(
                userID,
                forKey: ProfileColor.ownerStorageKey
            )
        } else {
            if pendingProfileColorOwnerID == "" {
                pendingProfileColorOwnerID = userID
                UserDefaults.standard.set(
                    userID,
                    forKey: ProfileColor.pendingOwnerStorageKey
                )
            } else if let candidateOwnerID = pendingProfileColorOwnerID,
                      candidateOwnerID != userID {
                let generatedProfileColorHex = ProfileColor.randomHex()
                desiredProfileColorHex = generatedProfileColorHex
                UserDefaults.standard.set(
                    generatedProfileColorHex,
                    forKey: ProfileColor.storageKey
                )
                UserDefaults.standard.set(
                    userID,
                    forKey: ProfileColor.pendingOwnerStorageKey
                )
                pendingProfileColorOwnerID = userID
            } else if pendingProfileColorOwnerID == nil,
                      profileColorBelongsToAnotherUser {
                let generatedProfileColorHex = ProfileColor.randomHex()
                desiredProfileColorHex = generatedProfileColorHex
                UserDefaults.standard.set(
                    generatedProfileColorHex,
                    forKey: ProfileColor.storageKey
                )
                UserDefaults.standard.set(
                    userID,
                    forKey: ProfileColor.pendingOwnerStorageKey
                )
                pendingProfileColorOwnerID = userID
            }

            shouldAdoptRemoteProfileColor =
                storedProfileColorHex.flatMap(ProfileColor.normalizedHex) == nil
                || storedProfileColorOwnerID == nil
                || profileColorBelongsToAnotherUser
                || pendingProfileColorOwnerID == userID
        }

        listenToOwnProfile(for: userID)
        listenToOwnExploration(for: userID)
        listenToFriendships(for: userID)
        ensureProfile(for: userID)

        if shouldDeleteLocationWhenAuthenticated {
            deleteOwnLocation(for: userID)
        } else if let latestLocationForSharing {
            writeLocation(
                latestLocationForSharing.location,
                displayName: latestLocationForSharing.displayName,
                spotEnteredAt: latestLocationForSharing.spotEnteredAt,
                for: userID,
                bypassThrottle: true
            )
        }
    }

    private func ensureProfile(for userID: String) {
        guard !isAccountDeletionPending else { return }
        guard !isCreatingProfile else { return }
        isCreatingProfile = true
        attemptProfileCreation(for: userID, attempt: 0)
    }

    private func attemptProfileCreation(for userID: String, attempt: Int) {
        guard currentUserID == userID else {
            isCreatingProfile = false
            return
        }

        let proposedCode = generateFriendCode()
        let userReference = db.collection("users").document(userID)
        let codeReference = db.collection("friendCodes").document(proposedCode)
        let displayName = desiredDisplayName
        let avatarID = desiredAvatarID
        let profileColorHex = desiredProfileColorHex

        db.runTransaction({ transaction, errorPointer -> Any? in
            do {
                let userSnapshot = try transaction.getDocument(userReference)
                if userSnapshot.exists {
                    guard let existingCode = userSnapshot.data()?["friendCode"] as? String,
                          Self.isValidFriendCode(existingCode) else {
                        return ["status": "invalid-profile"]
                    }
                    return [
                        "status": "existing",
                        "friendCode": existingCode
                    ]
                }

                let codeSnapshot = try transaction.getDocument(codeReference)
                if codeSnapshot.exists {
                    return ["status": "collision"]
                }

                transaction.setData(
                    [
                        "displayName": displayName,
                        "avatarID": avatarID,
                        "profileColorHex": profileColorHex,
                        "friendCode": proposedCode,
                        "createdAt": FieldValue.serverTimestamp(),
                        "updatedAt": FieldValue.serverTimestamp()
                    ],
                    forDocument: userReference
                )
                transaction.setData(
                    [
                        "ownerId": userID,
                        "displayName": displayName,
                        "createdAt": FieldValue.serverTimestamp()
                    ],
                    forDocument: codeReference
                )
                return [
                    "status": "created",
                    "friendCode": proposedCode
                ]
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self, self.currentUserID == userID else { return }

                if let error {
                    self.isCreatingProfile = false
                    self.isPreparingProfile = false
                    let message = self.friendlyMessage(
                        for: error,
                        fallback: "Impossible de créer ton profil Wander."
                    )
                    self.accountBootstrapErrorMessage = message
                    self.errorMessage = message
                    return
                }

                let transactionResult = result as? [String: String]
                let status = transactionResult?["status"]

                if status == "collision",
                   attempt + 1 < self.maximumProfileCreationAttempts {
                    self.attemptProfileCreation(for: userID, attempt: attempt + 1)
                    return
                }

                self.isCreatingProfile = false

                if status == "collision" || status == "invalid-profile" {
                    self.isPreparingProfile = false
                    let message = "Impossible de créer ton profil Wander."
                    self.accountBootstrapErrorMessage = message
                    self.errorMessage = message
                    return
                }

                switch status {
                case "existing":
                    self.accountProfileOrigin = .existing
                case "created":
                    self.accountProfileOrigin = .created
                default:
                    self.isPreparingProfile = false
                    let message = "Impossible de préparer ton profil Wander."
                    self.accountBootstrapErrorMessage = message
                    self.errorMessage = message
                }
            }
        }
    }

    private func listenToOwnProfile(for userID: String) {
        let generation = authenticationGeneration
        ownProfileListener?.remove()
        ownProfileListener = db.collection("users").document(userID)
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    guard let self,
                          self.currentUserID == userID,
                          self.authenticationGeneration == generation else {
                        return
                    }

                    if let error {
                        self.isPreparingProfile = false
                        let message = self.friendlyMessage(
                            for: error,
                            fallback: "Impossible de charger ton profil Wander."
                        )
                        self.accountBootstrapErrorMessage = message
                        self.errorMessage = message
                        return
                    }

                    guard let snapshot, snapshot.exists, let data = snapshot.data(),
                          let code = data["friendCode"] as? String,
                          Self.isValidFriendCode(code) else {
                        self.friendCode = nil
                        self.isProfileReady = false
                        return
                    }

                    self.friendCode = code
                    self.isProfileReady = true
                    self.isPreparingProfile = false
                    let deletionIsPending =
                        data["deletionRequestedAt"] is Timestamp
                    let remoteDisplayName = Self.normalizedDisplayName(
                        data["displayName"] as? String ?? ""
                    )
                    let remoteAvatarID = ProfileAvatar.normalizedID(
                        data["avatarID"] as? String
                    )
                    let remoteProfileColorHex =
                        (data["profileColorHex"] as? String).flatMap(
                            ProfileColor.normalizedHex
                        )
                    self.lastKnownProfileDisplayName = remoteDisplayName
                    self.lastKnownProfileAvatarID = remoteAvatarID
                    self.lastKnownProfileColorHex = remoteProfileColorHex

                    guard !snapshot.metadata.isFromCache else {
                        // A cached profile is useful for rendering, but it must
                        // not unlock outbound writes on a fresh installation.
                        return
                    }

                    if deletionIsPending {
                        self.hasLoadedOwnProfileFromServer = true
                        self.accountProfileOrigin = .existing
                        self.accountBootstrapErrorMessage = nil
                        self.suspendSynchronizationForAccountDeletion()
                        return
                    }

                    if self.hasPendingDisplayNameEditBeforeProfileHydration {
                        self.hasPendingDisplayNameChange = true
                    } else if !self.hasPendingDisplayNameChange {
                        self.desiredDisplayName = remoteDisplayName
                        UserDefaults.standard.set(
                            remoteDisplayName,
                            forKey: "profile.displayName"
                        )
                    }

                    if self.hasPendingAvatarEditBeforeProfileHydration {
                        self.hasPendingAvatarChange = true
                    } else if !self.hasPendingAvatarChange {
                        let resolvedAvatarID =
                            remoteAvatarID ?? self.desiredAvatarID
                        self.desiredAvatarID = resolvedAvatarID
                        UserDefaults.standard.set(
                            resolvedAvatarID,
                            forKey: ProfileAvatar.storageKey
                        )
                        if remoteAvatarID == nil {
                            self.hasPendingAvatarChange = true
                        }
                    }

                    if self.hasPendingProfileColorEditBeforeProfileHydration {
                        self.hasPendingProfileColorChange = true
                    } else if !self.hasPendingProfileColorChange {
                        let resolvedProfileColorHex =
                            remoteProfileColorHex ?? self.desiredProfileColorHex
                        self.desiredProfileColorHex = resolvedProfileColorHex
                        UserDefaults.standard.set(
                            resolvedProfileColorHex,
                            forKey: ProfileColor.storageKey
                        )
                        if remoteProfileColorHex == nil {
                            self.hasPendingProfileColorChange = true
                        }
                    }

                    self.shouldAdoptRemoteAvatar = false
                    self.shouldAdoptRemoteProfileColor = false
                    self.hasLoadedOwnProfileFromServer = true
                    self.accountBootstrapErrorMessage = nil
                    self.hasPendingDisplayNameEditBeforeProfileHydration = false
                    self.hasPendingAvatarEditBeforeProfileHydration = false
                    self.hasPendingProfileColorEditBeforeProfileHydration = false
                    self.isPreparingProfile = false

                    UserDefaults.standard.set(
                        userID,
                        forKey: ProfileAvatar.ownerStorageKey
                    )
                    UserDefaults.standard.set(
                        userID,
                        forKey: ProfileColor.ownerStorageKey
                    )
                    UserDefaults.standard.removeObject(
                        forKey: ProfileColor.pendingOwnerStorageKey
                    )
                    UserDefaults.standard.set(
                        false,
                        forKey: ProfileColor.pendingUserSelectionStorageKey
                    )

                    if self.lastKnownProfileDisplayName != self.desiredDisplayName
                        || self.lastKnownProfileAvatarID != self.desiredAvatarID
                        || self.lastKnownProfileColorHex != self.desiredProfileColorHex {
                        self.scheduleProfileUpdate()
                    }
                }
            }
    }

    private func scheduleProfileUpdate() {
        profileUpdateTask?.cancel()

        guard !isAccountDeletionPending,
              currentUserID != nil,
              hasLoadedOwnProfileFromServer else {
            return
        }
        profileUpdateTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 450_000_000)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            self?.performProfileUpdate()
        }
    }

    private func performProfileUpdate() {
        guard !isAccountDeletionPending,
              !isUpdatingProfile,
              !shouldAdoptRemoteAvatar,
              !shouldAdoptRemoteProfileColor,
              hasLoadedOwnProfileFromServer,
              let currentUserID,
              let friendCode,
              isProfileReady,
              lastKnownProfileDisplayName != desiredDisplayName
                || lastKnownProfileAvatarID != desiredAvatarID
                || lastKnownProfileColorHex != desiredProfileColorHex else {
            return
        }

        isUpdatingProfile = true
        let newDisplayName = desiredDisplayName
        let newAvatarID = desiredAvatarID
        let newProfileColorHex = desiredProfileColorHex
        let displayNameChanged =
            lastKnownProfileDisplayName != newDisplayName
        let batch = db.batch()
        batch.updateData(
            [
                "displayName": newDisplayName,
                "avatarID": newAvatarID,
                "profileColorHex": newProfileColorHex,
                "updatedAt": FieldValue.serverTimestamp()
            ],
            forDocument: db.collection("users").document(currentUserID)
        )
        if displayNameChanged {
            batch.updateData(
                ["displayName": newDisplayName],
                forDocument: db.collection("friendCodes").document(friendCode)
            )
        }

        batch.commit { [weak self] error in
            DispatchQueue.main.async {
                guard let self, self.currentUserID == currentUserID else { return }
                self.isUpdatingProfile = false

                if let error {
                    self.errorMessage = self.friendlyMessage(
                        for: error,
                        fallback: "Impossible de mettre à jour ton profil."
                    )
                    return
                }

                self.lastKnownProfileDisplayName = newDisplayName
                self.lastKnownProfileAvatarID = newAvatarID
                self.lastKnownProfileColorHex = newProfileColorHex
                if self.desiredDisplayName == newDisplayName {
                    self.hasPendingDisplayNameChange = false
                }
                if self.desiredProfileColorHex == newProfileColorHex {
                    self.hasPendingProfileColorChange = false
                }
                if self.desiredAvatarID == newAvatarID {
                    self.hasPendingAvatarChange = false
                }
                if self.desiredDisplayName != newDisplayName
                    || self.desiredAvatarID != newAvatarID
                    || self.desiredProfileColorHex != newProfileColorHex {
                    self.scheduleProfileUpdate()
                }
            }
        }
    }

    // MARK: - Exploration sharing

    private func listenToOwnExploration(for userID: String) {
        let generation = authenticationGeneration
        ownExplorationSyncState = .loading
        ownExplorationListener?.remove()
        ownExplorationListener = explorationCellsCollection(for: userID)
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    guard let self,
                          self.currentUserID == userID,
                          self.authenticationGeneration == generation else {
                        return
                    }

                    if let error {
                        self.hasLoadedOwnExploration = false
                        self.ownExplorationSyncState = .failed
                        let message = self.friendlyMessage(
                            for: error,
                            fallback: "Impossible de synchroniser ta carte découverte."
                        )
                        self.ownExplorationErrorMessage = message
                        self.errorMessage = message
                        return
                    }

                    guard let snapshot else { return }
                    if !self.hasLoadedOwnExploration,
                       snapshot.metadata.isFromCache {
                        // A cold/offline cache can be empty even when Firestore
                        // already contains the full history. Wait for the first
                        // server-backed snapshot before computing missing cells.
                        return
                    }

                    if self.hasLoadedOwnExploration {
                        for change in snapshot.documentChanges {
                            let cellID = change.document.documentID
                            guard Self.isValidH3CellID(cellID) else { continue }

                            switch change.type {
                            case .added, .modified:
                                self.uploadedExplorationCellIDs.insert(cellID)
                                self.ownExplorationCellsByID[cellID] =
                                    Self.remoteDiscoveredCell(
                                        from: change.document
                                    )
                                if !self.uploadingExplorationCellIDs.contains(cellID) {
                                    self.pendingExplorationCellIDs.remove(cellID)
                                }
                            case .removed:
                                self.uploadedExplorationCellIDs.remove(cellID)
                                self.ownExplorationCellsByID.removeValue(
                                    forKey: cellID
                                )
                                if self.desiredExplorationCellIDs.contains(cellID) {
                                    self.pendingExplorationCellIDs.insert(cellID)
                                }
                            }
                        }
                    } else {
                        self.uploadedExplorationCellIDs = Self.explorationCellIDs(
                            in: snapshot
                        )
                        self.ownExplorationCellsByID = Dictionary(
                            uniqueKeysWithValues: snapshot.documents.compactMap {
                                document in
                                guard let remoteCell = Self.remoteDiscoveredCell(
                                    from: document
                                ) else {
                                    return nil
                                }
                                return (remoteCell.id, remoteCell)
                            }
                        )
                        self.pendingExplorationCellIDs =
                            self.desiredExplorationCellIDs.subtracting(
                                self.uploadedExplorationCellIDs
                            )
                        self.hasLoadedOwnExploration = true
                    }
                    let resolvedRemoteCells =
                        self.ownExplorationCellsByID.values.sorted {
                            $0.id < $1.id
                        }
                    if self.ownExplorationCells != resolvedRemoteCells
                        || self.ownExplorationSyncState != .ready {
                        self.ownExplorationCells = resolvedRemoteCells
                        self.ownExplorationRevision &+= 1
                    }
                    self.ownExplorationSyncState = .ready
                    self.ownExplorationErrorMessage = nil
                    self.uploadMissingExplorationCellsIfNeeded()
                }
            }
    }

    private func uploadMissingExplorationCellsIfNeeded() {
        guard !isAccountDeletionPending,
              let currentUserID,
              hasLoadedOwnExploration,
              !isUploadingExploration else {
            return
        }

        guard !pendingExplorationCellIDs.isEmpty else { return }

        // Firestore batches support at most 500 writes. Leave some headroom for
        // future metadata writes without changing the batching contract.
        let batchCellIDs = Array(pendingExplorationCellIDs.prefix(450))
        let generation = authenticationGeneration
        let batch = db.batch()
        let collection = explorationCellsCollection(for: currentUserID)

        for cellID in batchCellIDs {
            batch.setData(
                ["sharedAt": FieldValue.serverTimestamp()],
                forDocument: collection.document(cellID)
            )
        }

        isUploadingExploration = true
        uploadingExplorationCellIDs = Set(batchCellIDs)
        batch.commit { [weak self] error in
            DispatchQueue.main.async {
                guard let self,
                      self.currentUserID == currentUserID,
                      self.authenticationGeneration == generation else {
                    return
                }

                self.isUploadingExploration = false
                self.uploadingExplorationCellIDs = []
                if let error {
                    self.errorMessage = self.friendlyMessage(
                        for: error,
                        fallback: "Impossible de partager ta carte découverte."
                    )
                    return
                }

                self.uploadedExplorationCellIDs.formUnion(batchCellIDs)
                self.pendingExplorationCellIDs.subtract(batchCellIDs)
                self.uploadMissingExplorationCellsIfNeeded()
            }
        }
    }

    private func reconcileExplorationListeners(for acceptedUserIDs: Set<String>) {
        let removedUserIDs = explorationListeners.keys.filter {
            !acceptedUserIDs.contains($0)
        }

        for userID in removedUserIDs {
            explorationListeners.removeValue(forKey: userID)?.remove()
            if receivedFriendExplorationCellIDs.removeValue(forKey: userID) != nil {
                friendExplorationRevision &+= 1
            }
        }

        for userID in acceptedUserIDs where explorationListeners[userID] == nil {
            let generation = authenticationGeneration
            explorationListeners[userID] = explorationCellsCollection(for: userID)
                .addSnapshotListener { [weak self] snapshot, error in
                    DispatchQueue.main.async {
                        guard let self,
                              self.authenticationGeneration == generation,
                              self.explorationListeners[userID] != nil,
                              self.isAcceptedFriend(userID) else {
                            return
                        }

                        if let error {
                            self.errorMessage = self.friendlyMessage(
                                for: error,
                                fallback: "Impossible de charger la carte d’un ami."
                            )
                            return
                        }

                        guard let snapshot else { return }

                        if var cellIDs = self.receivedFriendExplorationCellIDs[userID] {
                            guard Self.applyExplorationChanges(
                                from: snapshot,
                                to: &cellIDs
                            ) else {
                                return
                            }
                            self.receivedFriendExplorationCellIDs[userID] = cellIDs
                        } else {
                            self.receivedFriendExplorationCellIDs[userID] =
                                Self.explorationCellIDs(in: snapshot)
                        }
                        self.friendExplorationRevision &+= 1
                    }
                }
        }
    }

    private static func explorationCellIDs(
        in snapshot: QuerySnapshot
    ) -> Set<String> {
        Set(
            snapshot.documents
                .map(\.documentID)
                .filter(Self.isValidH3CellID)
        )
    }

    private static func remoteDiscoveredCell(
        from document: QueryDocumentSnapshot
    ) -> RemoteDiscoveredCell? {
        let cellID = document.documentID
        guard isValidH3CellID(cellID) else { return nil }

        return RemoteDiscoveredCell(
            id: cellID,
            sharedAt: (document.data()["sharedAt"] as? Timestamp)?.dateValue()
        )
    }

    @discardableResult
    private static func applyExplorationChanges(
        from snapshot: QuerySnapshot,
        to cellIDs: inout Set<String>
    ) -> Bool {
        var didChange = false

        for change in snapshot.documentChanges {
            let cellID = change.document.documentID

            switch change.type {
            case .added, .modified:
                if Self.isValidH3CellID(cellID) {
                    didChange = cellIDs.insert(cellID).inserted || didChange
                } else {
                    didChange = cellIDs.remove(cellID) != nil || didChange
                }
            case .removed:
                didChange = cellIDs.remove(cellID) != nil || didChange
            }
        }

        return didChange
    }

    private func explorationCellsCollection(for userID: String) -> CollectionReference {
        db.collection("explorations").document(userID).collection("cells")
    }

    // MARK: - Friendships

    private func listenToFriendships(for userID: String) {
        let generation = authenticationGeneration
        friendshipsListener?.remove()
        friendshipsListener = db.collection("friendships")
            .whereField("participants", arrayContains: userID)
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    guard let self,
                          self.currentUserID == userID,
                          self.authenticationGeneration == generation else {
                        return
                    }

                    if let error {
                        self.errorMessage = self.friendlyMessage(
                            for: error,
                            fallback: "Impossible de synchroniser tes amis."
                        )
                        return
                    }

                    guard let snapshot else { return }
                    var records: [String: FriendshipRecord] = [:]

                    for document in snapshot.documents {
                        let data = document.data()
                        guard let participants = data["participants"] as? [String],
                              participants.count == 2,
                              participants.contains(userID),
                              let requestedBy = data["requestedBy"] as? String,
                              participants.contains(requestedBy),
                              let status = data["status"] as? String,
                              status == "pending" || status == "accepted" else {
                            continue
                        }

                        records[document.documentID] = FriendshipRecord(
                            pairID: document.documentID,
                            participants: participants,
                            requestedBy: requestedBy,
                            status: status,
                            createdAt: (data["createdAt"] as? Timestamp)?.dateValue()
                        )
                    }

                    self.friendshipRecords = records
                    self.reconcileRelatedListeners()
                    self.rebuildPublishedRelationships()
                }
            }
    }

    private func reconcileRelatedListeners() {
        guard let currentUserID else { return }

        let relatedUserIDs = Set(
            friendshipRecords.values.compactMap {
                $0.otherUserID(for: currentUserID)
            }
        )
        reconcileProfileListeners(for: relatedUserIDs)

        let acceptedUserIDs: Set<String> = Set(
            friendshipRecords.values.compactMap { record in
                guard record.status == "accepted" else { return nil }
                return record.otherUserID(for: currentUserID)
            }
        )
        reconcileLocationListeners(for: acceptedUserIDs)
        reconcileExplorationListeners(for: acceptedUserIDs)
    }

    private func reconcileProfileListeners(for requiredUserIDs: Set<String>) {
        let removedUserIDs = profileListeners.keys.filter {
            !requiredUserIDs.contains($0)
        }

        for userID in removedUserIDs {
            profileListeners.removeValue(forKey: userID)?.remove()
            profilesByUserID.removeValue(forKey: userID)
        }

        for userID in requiredUserIDs where profileListeners[userID] == nil {
            let generation = authenticationGeneration
            profileListeners[userID] = db.collection("users").document(userID)
                .addSnapshotListener { [weak self] snapshot, error in
                    DispatchQueue.main.async {
                        guard let self,
                              self.currentUserID != nil,
                              self.authenticationGeneration == generation,
                              self.profileListeners[userID] != nil else {
                            return
                        }

                        if let error {
                            self.errorMessage = self.friendlyMessage(
                                for: error,
                                fallback: "Impossible de charger le profil d’un ami."
                            )
                            return
                        }

                        let data = snapshot?.data()
                        let displayName = (data?["displayName"] as? String).map {
                            Self.normalizedDisplayName($0)
                        } ?? "Explorer"
                        let avatarID = ProfileAvatar.normalizedID(
                            data?["avatarID"] as? String
                        ) ?? ProfileAvatar.generatedID(seed: userID)
                        let profileColorHex =
                            (data?["profileColorHex"] as? String).flatMap(
                                ProfileColor.normalizedHex
                            ) ?? ProfileColor.generatedHex(seed: userID)
                        let profile = RemoteProfile(
                            displayName: displayName,
                            avatarID: avatarID,
                            profileColorHex: profileColorHex
                        )
                        self.profilesByUserID[userID] = profile

                        if let currentLocation = self.receivedFriendLocations[userID] {
                            self.receivedFriendLocations[userID] = FriendLocation(
                                userID: currentLocation.userID,
                                displayName: profile.displayName,
                                avatarID: profile.avatarID,
                                profileColorHex: profile.profileColorHex,
                                coordinate: currentLocation.coordinate,
                                horizontalAccuracy: currentLocation.horizontalAccuracy,
                                sampledAt: currentLocation.sampledAt,
                                updatedAt: currentLocation.updatedAt,
                                receivedAt: currentLocation.receivedAt,
                                spotEnteredAt: currentLocation.spotEnteredAt
                            )
                        }

                        self.rebuildPublishedRelationships()
                    }
                }
        }
    }

    private func rebuildPublishedRelationships() {
        guard let currentUserID else {
            incomingRequests = []
            outgoingRequests = []
            acceptedFriends = []
            return
        }

        var incoming: [FriendRequest] = []
        var outgoing: [FriendRequest] = []
        var friends: [FriendContact] = []

        for record in friendshipRecords.values {
            guard let otherUserID = record.otherUserID(for: currentUserID) else {
                continue
            }
            let profile = profilesByUserID[otherUserID] ?? RemoteProfile(
                displayName: "Explorer",
                avatarID: ProfileAvatar.generatedID(seed: otherUserID),
                profileColorHex: ProfileColor.generatedHex(seed: otherUserID)
            )
            let displayName = profile.displayName

            if record.status == "accepted" {
                friends.append(
                    FriendContact(
                        userID: otherUserID,
                        displayName: displayName,
                        avatarID: profile.avatarID,
                        profileColorHex: profile.profileColorHex
                    )
                )
            } else {
                let request = FriendRequest(
                    pairID: record.pairID,
                    userID: otherUserID,
                    displayName: displayName,
                    avatarID: profile.avatarID,
                    requestedBy: record.requestedBy
                )

                if record.requestedBy == currentUserID {
                    outgoing.append(request)
                } else {
                    incoming.append(request)
                }
            }
        }

        let nameSort: (String, String) -> Bool = {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        incomingRequests = incoming.sorted {
            if $0.displayName == $1.displayName {
                return $0.pairID < $1.pairID
            }
            return nameSort($0.displayName, $1.displayName)
        }
        outgoingRequests = outgoing.sorted {
            if $0.displayName == $1.displayName {
                return $0.pairID < $1.pairID
            }
            return nameSort($0.displayName, $1.displayName)
        }
        acceptedFriends = friends.sorted {
            if $0.displayName == $1.displayName {
                return $0.userID < $1.userID
            }
            return nameSort($0.displayName, $1.displayName)
        }
    }

    private func createPendingFriendship(
        currentUserID: String,
        targetUserID: String,
        completion: @escaping (Bool) -> Void
    ) {
        let generation = authenticationGeneration
        let participants = [currentUserID, targetUserID].sorted()
        let pairID = participants.joined(separator: "__")
        let reference = db.collection("friendships").document(pairID)

        if let existing = friendshipRecords[pairID] {
            isProcessingFriendAction = false
            errorMessage = existing.status == "accepted"
                ? "Vous êtes déjà amis."
                : existing.requestedBy == currentUserID
                    ? "Cette demande a déjà été envoyée."
                    : "Cette personne t’a déjà envoyé une demande."
            completion(false)
            return
        }

        db.runTransaction({ transaction, errorPointer -> Any? in
            do {
                let snapshot = try transaction.getDocument(reference)
                if snapshot.exists, let data = snapshot.data() {
                    if data["status"] as? String == "accepted" {
                        return "already-friends"
                    }
                    if data["status"] as? String == "pending" {
                        return data["requestedBy"] as? String == currentUserID
                            ? "already-sent"
                            : "already-received"
                    }
                    return "already-exists"
                }

                transaction.setData(
                    [
                        "participants": participants,
                        "requestedBy": currentUserID,
                        "status": "pending",
                        "createdAt": FieldValue.serverTimestamp()
                    ],
                    forDocument: reference
                )
                return "created"
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self else {
                    completion(false)
                    return
                }
                guard self.currentUserID == currentUserID,
                      self.authenticationGeneration == generation else {
                    completion(false)
                    return
                }

                self.isProcessingFriendAction = false

                if let error {
                    self.errorMessage = self.friendlyMessage(
                        for: error,
                        fallback: "Impossible d’envoyer la demande d’ami."
                    )
                    completion(false)
                    return
                }

                switch result as? String {
                case "created":
                    completion(true)
                case "already-friends":
                    self.errorMessage = "Vous êtes déjà amis."
                    completion(false)
                case "already-sent":
                    self.errorMessage = "Cette demande a déjà été envoyée."
                    completion(false)
                case "already-received":
                    self.errorMessage = "Cette personne t’a déjà envoyé une demande."
                    completion(false)
                default:
                    self.errorMessage = "Une demande existe déjà pour cet utilisateur."
                    completion(false)
                }
            }
        }
    }

    // MARK: - Location listeners

    private func reconcileLocationListeners(for acceptedUserIDs: Set<String>) {
        let removedUserIDs = locationListeners.keys.filter {
            !acceptedUserIDs.contains($0)
        }

        for userID in removedUserIDs {
            locationListeners.removeValue(forKey: userID)?.remove()
            removeFriendLocation(for: userID)
        }

        for userID in acceptedUserIDs where locationListeners[userID] == nil {
            let generation = authenticationGeneration
            locationListeners[userID] = db.collection("locations").document(userID)
                .addSnapshotListener { [weak self] snapshot, error in
                    DispatchQueue.main.async {
                        guard let self,
                              self.authenticationGeneration == generation,
                              self.locationListeners[userID] != nil,
                              self.isAcceptedFriend(userID) else {
                            return
                        }

                        if let error {
                            self.errorMessage = self.friendlyMessage(
                                for: error,
                                fallback: "Impossible de recevoir la position d’un ami."
                            )
                            return
                        }

                        guard let snapshot, snapshot.exists, let data = snapshot.data(),
                              let geoPoint = data["location"] as? GeoPoint,
                              let sampledTimestamp = data["sampledAt"] as? Timestamp,
                              let timestamp = data["updatedAt"] as? Timestamp,
                              let accuracy = data["horizontalAccuracy"] as? NSNumber else {
                            self.removeFriendLocation(for: userID)
                            return
                        }

                        let receivedAt = Date()
                        let sampledAt = sampledTimestamp.dateValue()
                        let updatedAt = timestamp.dateValue()
                        let coordinate = CLLocationCoordinate2D(
                            latitude: geoPoint.latitude,
                            longitude: geoPoint.longitude
                        )
                        guard FriendLocation.isValidLastKnown(
                            sampledAt: sampledAt,
                            at: receivedAt
                        ), CLLocationCoordinate2DIsValid(coordinate),
                           coordinate.latitude.isFinite,
                           coordinate.longitude.isFinite else {
                            self.removeFriendLocation(for: userID)
                            return
                        }
                        let spotEnteredAt: Date?
                        if data.keys.contains("spotEnteredAt") {
                            spotEnteredAt = Self.validSpotEnteredAt(
                                (data["spotEnteredAt"] as? Timestamp)?.dateValue(),
                                sampledAt: sampledAt
                            )
                        } else {
                            spotEnteredAt = Self.validLegacySpotEnteredAt(
                                cellID: data["h3CellId"] as? String,
                                enteredAt: (data["h3EnteredAt"] as? Timestamp)?.dateValue(),
                                sampledAt: sampledAt
                            )
                        }

                        let profile = self.profilesByUserID[userID]
                        let displayName = profile?.displayName
                            ?? (data["displayName"] as? String).map {
                                Self.normalizedDisplayName($0)
                            }
                            ?? "Explorer"
                        let profileColorHex =
                            profile?.profileColorHex
                            ?? ProfileColor.generatedHex(seed: userID)
                        let avatarID = profile?.avatarID
                            ?? ProfileAvatar.generatedID(seed: userID)

                        let friendLocation = FriendLocation(
                            userID: userID,
                            displayName: displayName,
                            avatarID: avatarID,
                            profileColorHex: profileColorHex,
                            coordinate: coordinate,
                            horizontalAccuracy: accuracy.doubleValue,
                            sampledAt: sampledAt,
                            updatedAt: updatedAt,
                            receivedAt: receivedAt,
                            spotEnteredAt: spotEnteredAt
                        )
                        self.receivedFriendLocations[userID] = friendLocation
                        self.updateFreshness(
                            for: friendLocation,
                            authenticationGeneration: generation
                        )
                    }
                }
        }
    }

    private func isAcceptedFriend(_ userID: String) -> Bool {
        guard let currentUserID else { return false }
        return friendshipRecords.values.contains { record in
            record.status == "accepted"
                && record.otherUserID(for: currentUserID) == userID
        }
    }

    private func removeFriendLocation(for userID: String) {
        locationFreshnessTimers.removeValue(forKey: userID)?.invalidate()
        freshFriendLocationUserIDs.remove(userID)
        receivedFriendLocations.removeValue(forKey: userID)
    }

    private func updateFreshness(
        for location: FriendLocation,
        authenticationGeneration generation: Int
    ) {
        locationFreshnessTimers.removeValue(forKey: location.userID)?.invalidate()

        guard location.isFresh() else {
            freshFriendLocationUserIDs.remove(location.userID)
            return
        }
        freshFriendLocationUserIDs.insert(location.userID)

        let delay = location.updatedAt
            .addingTimeInterval(FriendLocation.maximumConfirmationAge)
            .timeIntervalSinceNow
        guard delay > 0 else {
            freshFriendLocationUserIDs.remove(location.userID)
            return
        }

        let userID = location.userID
        let updatedAt = location.updatedAt
        let timer = Timer(
            timeInterval: delay,
            repeats: false
        ) { [weak self] timer in
            guard let self,
                  self.authenticationGeneration == generation,
                  let currentLocation = self.receivedFriendLocations[userID],
                  currentLocation.updatedAt == updatedAt else {
                return
            }
            self.locationFreshnessTimers.removeValue(forKey: userID)?.invalidate()
            timer.invalidate()

            if currentLocation.isFresh() {
                self.updateFreshness(
                    for: currentLocation,
                    authenticationGeneration: generation
                )
            } else {
                self.freshFriendLocationUserIDs.remove(userID)
            }
        }
        timer.tolerance = min(1, delay * 0.1)
        RunLoop.main.add(timer, forMode: .common)
        locationFreshnessTimers[userID] = timer
    }

    // MARK: - Location writes

    private func writeLocation(
        _ location: CLLocation,
        displayName: String,
        spotEnteredAt: Date?,
        for userID: String,
        bypassThrottle: Bool
    ) {
        guard !isAccountDeletionPending,
              currentUserID == userID,
              FriendLocation.isCurrentSample(
                sampledAt: location.timestamp,
                at: Date()
              ) else {
            return
        }

        let now = Date()
        let validSpotEnteredAt = Self.validSpotEnteredAt(
            spotEnteredAt,
            sampledAt: location.timestamp
        )
        if !bypassThrottle, let lastLocationPush {
            let distance = location.distance(from: lastLocationPush.location)
            let elapsed = now.timeIntervalSince(lastLocationPush.attemptedAt)
            if validSpotEnteredAt == lastLocationPush.spotEnteredAt
                && distance < minimumLocationPushDistance
                && elapsed < minimumLocationPushInterval {
                return
            }
        }

        lastLocationPush = (location, now, validSpotEnteredAt)
        let attemptedAt = now
        var data: [String: Any] = [
            "location": GeoPoint(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            ),
            "displayName": displayName,
            "horizontalAccuracy": location.horizontalAccuracy,
            "sampledAt": Timestamp(date: location.timestamp),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let validSpotEnteredAt {
            data["spotEnteredAt"] = Timestamp(date: validSpotEnteredAt)
        }

        db.collection("locations").document(userID).setData(data) { [weak self] error in
            DispatchQueue.main.async {
                guard let self, self.currentUserID == userID else { return }

                if let error {
                    if self.lastLocationPush?.attemptedAt == attemptedAt {
                        self.lastLocationPush = nil
                    }
                    self.errorMessage = self.friendlyMessage(
                        for: error,
                        fallback: "Impossible d’envoyer ta position."
                    )
                }
            }
        }
    }

    private func deleteOwnLocation(for userID: String) {
        lastLocationPush = nil
        db.collection("locations").document(userID).delete { [weak self] error in
            DispatchQueue.main.async {
                guard let self, self.currentUserID == userID else { return }

                if let error {
                    self.errorMessage = self.friendlyMessage(
                        for: error,
                        fallback: "Impossible d’arrêter le partage de position."
                    )
                } else {
                    self.shouldDeleteLocationWhenAuthenticated = false
                }
            }
        }
    }

    // MARK: - Cleanup and helpers

    private func suspendSynchronizationForAccountDeletion() {
        guard !isAccountDeletionPending else { return }

        isAccountDeletionPending = true
        authenticationGeneration &+= 1
        removeAllListeners()
        profileUpdateTask?.cancel()
        profileUpdateTask = nil
        isCreatingProfile = false
        isUpdatingProfile = false
        isUploadingExploration = false
        isProcessingFriendAction = false
        uploadingExplorationCellIDs = []
        latestLocationForSharing = nil
        lastLocationPush = nil
    }

    private func deleteDocumentsInBatches(from query: Query) async throws {
        while true {
            let snapshot = try await query
                .limit(to: 400)
                .getDocuments(source: .server)
            guard !snapshot.documents.isEmpty else { return }

            let batch = db.batch()
            for document in snapshot.documents {
                batch.deleteDocument(document.reference)
            }
            try await batch.commit()
        }
    }

    private func removeAllListeners() {
        ownProfileListener?.remove()
        ownProfileListener = nil
        ownExplorationListener?.remove()
        ownExplorationListener = nil
        friendshipsListener?.remove()
        friendshipsListener = nil

        for listener in profileListeners.values {
            listener.remove()
        }
        profileListeners.removeAll()

        for listener in locationListeners.values {
            listener.remove()
        }
        locationListeners.removeAll()

        for timer in locationFreshnessTimers.values {
            timer.invalidate()
        }
        locationFreshnessTimers.removeAll()

        for listener in explorationListeners.values {
            listener.remove()
        }
        explorationListeners.removeAll()

    }

    private func finishFriendAction(
        success: Bool,
        error: Error?,
        completion: @escaping (Bool) -> Void
    ) {
        isProcessingFriendAction = false
        if let error {
            errorMessage = friendlyMessage(
                for: error,
                fallback: "Impossible d’envoyer la demande d’ami."
            )
        }
        completion(success)
    }

    private func friendlyMessage(for error: Error, fallback: String) -> String {
        let nsError = error as NSError

        if nsError.domain == NSURLErrorDomain
            || nsError.code == 4
            || nsError.code == 14 {
            return "Problème réseau. Vérifie ta connexion puis réessaie."
        }

        if nsError.code == 7 {
            return "Accès Firestore refusé. Vérifie les règles de sécurité publiées."
        }

        return fallback
    }

    private func generateFriendCode() -> String {
        var generator = SystemRandomNumberGenerator()
        return String(
            (0..<friendCodeLength).compactMap { _ in
                friendCodeAlphabet.randomElement(using: &generator)
            }
        )
    }

    private static func normalizedDisplayName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = trimmed.isEmpty ? "Explorer" : trimmed
        return String(displayName.prefix(50))
    }

    private static func normalizedFriendCode(_ value: String) -> String {
        value
            .uppercased()
            .filter { character in
                !character.isWhitespace && character != "-"
            }
    }

    private static func isValidFriendCode(_ code: String) -> Bool {
        guard (10...12).contains(code.count) else { return false }
        let allowedCharacters = Set("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return code.allSatisfy { allowedCharacters.contains($0) }
    }

    private enum AccountDataDeletionError: LocalizedError {
        case noAuthenticatedUser
        case invalidProfile

        var errorDescription: String? {
            switch self {
            case .noAuthenticatedUser:
                return "Ta session a expiré. Reconnecte-toi avant de réessayer."
            case .invalidProfile:
                return "Le profil distant est incomplet. Réessaie dans quelques instants."
            }
        }
    }

    nonisolated private static func isValidH3CellID(_ cellID: String) -> Bool {
        guard cellID.count == 15 else { return false }
        let allowedCharacters = Set("0123456789abcdef")
        return cellID.allSatisfy { allowedCharacters.contains($0) }
    }

    nonisolated private static func validSpotEnteredAt(
        _ enteredAt: Date?,
        sampledAt: Date
    ) -> Date? {
        guard let enteredAt,
              enteredAt.timeIntervalSinceReferenceDate.isFinite,
              enteredAt <= sampledAt else {
            return nil
        }
        return enteredAt
    }

    nonisolated private static func validLegacySpotEnteredAt(
        cellID: String?,
        enteredAt: Date?,
        sampledAt: Date
    ) -> Date? {
        guard let cellID,
              isValidH3CellID(cellID),
              let enteredAt = validSpotEnteredAt(
                  enteredAt,
                  sampledAt: sampledAt
              ) else {
            return nil
        }
        return enteredAt
    }
}
