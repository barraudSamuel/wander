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
    let profileColorHex: String

    var id: String { userID }
}

struct FriendRequest: Identifiable, Equatable {
    let pairID: String
    let userID: String
    let displayName: String
    let requestedBy: String

    var id: String { pairID }
}

struct FriendLocation: Equatable {
    let userID: String
    let displayName: String
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
            && lhs.profileColorHex == rhs.profileColorHex
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
            && lhs.horizontalAccuracy == rhs.horizontalAccuracy
            && lhs.sampledAt == rhs.sampledAt
            && lhs.updatedAt == rhs.updatedAt
            && lhs.receivedAt == rhs.receivedAt
            && lhs.spotEnteredAt == rhs.spotEnteredAt
    }
}

struct FriendExploration: Equatable {
    let userID: String
    let displayName: String
    let profileColorHex: String
    let cellIDs: Set<String>
}

private struct RemoteProfile {
    let displayName: String
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
    @Published private var receivedFriendExplorationCellIDs: [String: Set<String>] = [:]
    @Published private(set) var friendExplorationRevision = 0
    @Published private(set) var isProfileReady = false
    @Published private(set) var isPreparingProfile = true
    @Published private(set) var isProcessingFriendAction = false
    @Published var errorMessage: String?

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

    private let db = Firestore.firestore()
    private let friendCodeAlphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    private let friendCodeLength = 11
    private let maximumProfileCreationAttempts = 8
    private let maximumLocationAge: TimeInterval = 5 * 60
    private let maximumFutureTimestampSkew: TimeInterval = 60
    private let minimumLocationPushDistance: CLLocationDistance = 15
    private let minimumLocationPushInterval: TimeInterval = 10

    private var currentUserID: String?
    private var desiredDisplayName: String
    private var desiredProfileColorHex: String
    private var shouldAdoptRemoteProfileColor: Bool
    private var lastKnownProfileDisplayName: String?
    private var lastKnownProfileColorHex: String?
    private var friendshipRecords: [String: FriendshipRecord] = [:]
    private var profilesByUserID: [String: RemoteProfile] = [:]

    private var ownProfileListener: ListenerRegistration?
    private var ownExplorationListener: ListenerRegistration?
    private var friendshipsListener: ListenerRegistration?
    private var profileListeners: [String: ListenerRegistration] = [:]
    private var locationListeners: [String: ListenerRegistration] = [:]
    private var explorationListeners: [String: ListenerRegistration] = [:]
    private var profileUpdateTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    private var isCreatingProfile = false
    private var isUpdatingProfile = false
    private var isUploadingExploration = false
    private var hasPendingUserSelectedProfileColor = false
    private var hasLoadedOwnExploration = false
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
        let storedProfileColorHex = UserDefaults.standard.string(
            forKey: ProfileColor.storageKey
        )
        desiredDisplayName = Self.normalizedDisplayName(
            UserDefaults.standard.string(forKey: "profile.displayName") ?? ""
        )
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
        clearError()
    }

    func updateDisplayName(_ displayName: String) {
        desiredDisplayName = Self.normalizedDisplayName(displayName)
        scheduleProfileUpdate()
    }

    func updateProfileColor(
        _ profileColorHex: String,
        userInitiated: Bool = false
    ) {
        let normalizedProfileColorHex =
            ProfileColor.normalizedHex(profileColorHex)
        desiredProfileColorHex =
            normalizedProfileColorHex ?? ProfileColor.storedOrGeneratedHex()

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
        guard location.horizontalAccuracy > 0,
              location.horizontalAccuracy <= 1_000,
              CLLocationCoordinate2DIsValid(location.coordinate),
              isFresh(location.timestamp, at: Date()) else {
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
        hasLoadedOwnExploration = false
        uploadedExplorationCellIDs = []
        pendingExplorationCellIDs = []
        uploadingExplorationCellIDs = []
        lastKnownProfileDisplayName = nil
        lastKnownProfileColorHex = nil
        friendshipRecords = [:]
        profilesByUserID = [:]
        incomingRequests = []
        outgoingRequests = []
        acceptedFriends = []
        receivedFriendLocations = [:]
        receivedFriendExplorationCellIDs = [:]
        friendExplorationRevision &+= 1
        isProcessingFriendAction = false
        lastLocationPush = nil
        if userID != nil {
            errorMessage = nil
        }

        guard let userID else { return }

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
        let profileColorHex = desiredProfileColorHex

        db.runTransaction({ transaction, errorPointer -> Any? in
            do {
                let userSnapshot = try transaction.getDocument(userReference)
                if userSnapshot.exists {
                    guard let existingCode = userSnapshot.data()?["friendCode"] as? String,
                          Self.isValidFriendCode(existingCode) else {
                        return "invalid-profile"
                    }
                    return existingCode
                }

                let codeSnapshot = try transaction.getDocument(codeReference)
                if codeSnapshot.exists {
                    return "collision"
                }

                transaction.setData(
                    [
                        "displayName": displayName,
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
                return proposedCode
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
                    self.errorMessage = self.friendlyMessage(
                        for: error,
                        fallback: "Impossible de créer ton profil Wander."
                    )
                    return
                }

                if result as? String == "collision",
                   attempt + 1 < self.maximumProfileCreationAttempts {
                    self.attemptProfileCreation(for: userID, attempt: attempt + 1)
                    return
                }

                self.isCreatingProfile = false

                if result as? String == "collision"
                    || result as? String == "invalid-profile" {
                    self.isPreparingProfile = false
                    self.errorMessage = "Impossible de créer ton profil Wander."
                    return
                }

                self.scheduleProfileUpdate()
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
                        self.errorMessage = self.friendlyMessage(
                            for: error,
                            fallback: "Impossible de charger ton profil Wander."
                        )
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
                    self.lastKnownProfileDisplayName =
                        data["displayName"] as? String
                    self.lastKnownProfileColorHex =
                        (data["profileColorHex"] as? String).flatMap(
                            ProfileColor.normalizedHex
                        )

                    if self.shouldAdoptRemoteProfileColor {
                        guard !snapshot.metadata.isFromCache else {
                            // Metadata changes are included, so an identical
                            // server snapshot will still arrive after this
                            // potentially stale cached value.
                            return
                        }

                        self.shouldAdoptRemoteProfileColor = false
                        let resolvedProfileColorHex =
                            self.lastKnownProfileColorHex
                            ?? self.desiredProfileColorHex
                        self.desiredProfileColorHex = resolvedProfileColorHex
                        UserDefaults.standard.set(
                            resolvedProfileColorHex,
                            forKey: ProfileColor.storageKey
                        )
                    }

                    if !snapshot.metadata.isFromCache {
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
                    }

                    if self.lastKnownProfileDisplayName != self.desiredDisplayName
                        || self.lastKnownProfileColorHex != self.desiredProfileColorHex {
                        self.scheduleProfileUpdate()
                    }
                }
            }
    }

    private func scheduleProfileUpdate() {
        profileUpdateTask?.cancel()

        guard currentUserID != nil else { return }
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
        guard !isUpdatingProfile,
              !shouldAdoptRemoteProfileColor,
              let currentUserID,
              let friendCode,
              isProfileReady,
              lastKnownProfileDisplayName != desiredDisplayName
                || lastKnownProfileColorHex != desiredProfileColorHex else {
            return
        }

        isUpdatingProfile = true
        let newDisplayName = desiredDisplayName
        let newProfileColorHex = desiredProfileColorHex
        let displayNameChanged =
            lastKnownProfileDisplayName != newDisplayName
        let batch = db.batch()
        batch.updateData(
            [
                "displayName": newDisplayName,
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
                self.lastKnownProfileColorHex = newProfileColorHex
                if self.desiredDisplayName != newDisplayName
                    || self.desiredProfileColorHex != newProfileColorHex {
                    self.scheduleProfileUpdate()
                }
            }
        }
    }

    // MARK: - Exploration sharing

    private func listenToOwnExploration(for userID: String) {
        let generation = authenticationGeneration
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
                        self.errorMessage = self.friendlyMessage(
                            for: error,
                            fallback: "Impossible de synchroniser ta carte découverte."
                        )
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
                                if !self.uploadingExplorationCellIDs.contains(cellID) {
                                    self.pendingExplorationCellIDs.remove(cellID)
                                }
                            case .removed:
                                self.uploadedExplorationCellIDs.remove(cellID)
                                if self.desiredExplorationCellIDs.contains(cellID) {
                                    self.pendingExplorationCellIDs.insert(cellID)
                                }
                            }
                        }
                    } else {
                        self.uploadedExplorationCellIDs = Self.explorationCellIDs(
                            in: snapshot
                        )
                        self.pendingExplorationCellIDs =
                            self.desiredExplorationCellIDs.subtracting(
                                self.uploadedExplorationCellIDs
                            )
                        self.hasLoadedOwnExploration = true
                    }
                    self.uploadMissingExplorationCellsIfNeeded()
                }
            }
    }

    private func uploadMissingExplorationCellsIfNeeded() {
        guard let currentUserID,
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
                        let profileColorHex =
                            (data?["profileColorHex"] as? String).flatMap(
                                ProfileColor.normalizedHex
                            ) ?? ProfileColor.generatedHex(seed: userID)
                        let profile = RemoteProfile(
                            displayName: displayName,
                            profileColorHex: profileColorHex
                        )
                        self.profilesByUserID[userID] = profile

                        if let currentLocation = self.receivedFriendLocations[userID] {
                            self.receivedFriendLocations[userID] = FriendLocation(
                                userID: currentLocation.userID,
                                displayName: profile.displayName,
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
                profileColorHex: ProfileColor.generatedHex(seed: otherUserID)
            )
            let displayName = profile.displayName

            if record.status == "accepted" {
                friends.append(
                    FriendContact(
                        userID: otherUserID,
                        displayName: displayName,
                        profileColorHex: profile.profileColorHex
                    )
                )
            } else {
                let request = FriendRequest(
                    pairID: record.pairID,
                    userID: otherUserID,
                    displayName: displayName,
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
            receivedFriendLocations.removeValue(forKey: userID)
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

                        let friendLocation = FriendLocation(
                            userID: userID,
                            displayName: displayName,
                            profileColorHex: profileColorHex,
                            coordinate: CLLocationCoordinate2D(
                                latitude: geoPoint.latitude,
                                longitude: geoPoint.longitude
                            ),
                            horizontalAccuracy: accuracy.doubleValue,
                            sampledAt: sampledAt,
                            updatedAt: updatedAt,
                            receivedAt: receivedAt,
                            spotEnteredAt: spotEnteredAt
                        )
                        self.receivedFriendLocations[userID] = friendLocation
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
        receivedFriendLocations.removeValue(forKey: userID)
    }

    // MARK: - Location writes

    private func writeLocation(
        _ location: CLLocation,
        displayName: String,
        spotEnteredAt: Date?,
        for userID: String,
        bypassThrottle: Bool
    ) {
        guard currentUserID == userID,
              isFresh(location.timestamp, at: Date()) else {
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

    private func isFresh(_ timestamp: Date, at date: Date) -> Bool {
        let age = date.timeIntervalSince(timestamp)
        return age >= -maximumFutureTimestampSkew
            && age < maximumLocationAge
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
