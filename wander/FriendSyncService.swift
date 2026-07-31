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
    let coordinate: CLLocationCoordinate2D
    let horizontalAccuracy: CLLocationAccuracy
    let sampledAt: Date
    let updatedAt: Date
    let receivedAt: Date

    static func == (lhs: FriendLocation, rhs: FriendLocation) -> Bool {
        lhs.userID == rhs.userID
            && lhs.displayName == rhs.displayName
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
            && lhs.horizontalAccuracy == rhs.horizontalAccuracy
            && lhs.sampledAt == rhs.sampledAt
            && lhs.updatedAt == rhs.updatedAt
            && lhs.receivedAt == rhs.receivedAt
    }
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
    @Published private(set) var isProfileReady = false
    @Published private(set) var isPreparingProfile = true
    @Published private(set) var isProcessingFriendAction = false
    @Published var errorMessage: String?

    var friendLocations: [String: FriendLocation] {
        receivedFriendLocations.filter { _, location in
            isFresh(location, at: Date())
        }
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
    private var lastKnownProfileDisplayName: String?
    private var friendshipRecords: [String: FriendshipRecord] = [:]
    private var profilesByUserID: [String: String] = [:]

    private var ownProfileListener: ListenerRegistration?
    private var friendshipsListener: ListenerRegistration?
    private var profileListeners: [String: ListenerRegistration] = [:]
    private var locationListeners: [String: ListenerRegistration] = [:]
    private var locationExpirationTasks: [String: Task<Void, Never>] = [:]
    private var displayNameUpdateTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    private var isCreatingProfile = false
    private var isUpdatingDisplayName = false
    private var authenticationGeneration = 0
    private var latestLocationForSharing: (location: CLLocation, displayName: String)?
    private var lastLocationPush: (location: CLLocation, attemptedAt: Date)?
    private var shouldDeleteLocationWhenAuthenticated = false

    private init() {
        desiredDisplayName = Self.normalizedDisplayName(
            UserDefaults.standard.string(forKey: "profile.displayName") ?? ""
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
        displayNameUpdateTask?.cancel()
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
        scheduleDisplayNameUpdate()
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

    func updateLocation(_ location: CLLocation, displayName: String) {
        guard location.horizontalAccuracy > 0,
              location.horizontalAccuracy <= 1_000,
              CLLocationCoordinate2DIsValid(location.coordinate),
              isFresh(location.timestamp, at: Date()) else {
            return
        }

        let normalizedName = Self.normalizedDisplayName(displayName)
        latestLocationForSharing = (location, normalizedName)
        shouldDeleteLocationWhenAuthenticated = false

        guard let currentUserID else { return }
        writeLocation(
            location,
            displayName: normalizedName,
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
        displayNameUpdateTask?.cancel()
        displayNameUpdateTask = nil
        currentUserID = userID
        friendCode = nil
        isProfileReady = false
        isPreparingProfile =
            userID != nil || !FirebaseService.shared.isAuthenticationResolved
        isCreatingProfile = false
        isUpdatingDisplayName = false
        lastKnownProfileDisplayName = nil
        friendshipRecords = [:]
        profilesByUserID = [:]
        incomingRequests = []
        outgoingRequests = []
        acceptedFriends = []
        receivedFriendLocations = [:]
        isProcessingFriendAction = false
        lastLocationPush = nil
        if userID != nil {
            errorMessage = nil
        }

        guard let userID else { return }

        listenToOwnProfile(for: userID)
        listenToFriendships(for: userID)
        ensureProfile(for: userID)

        if shouldDeleteLocationWhenAuthenticated {
            deleteOwnLocation(for: userID)
        } else if let latestLocationForSharing {
            writeLocation(
                latestLocationForSharing.location,
                displayName: latestLocationForSharing.displayName,
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

                self.scheduleDisplayNameUpdate()
            }
        }
    }

    private func listenToOwnProfile(for userID: String) {
        let generation = authenticationGeneration
        ownProfileListener?.remove()
        ownProfileListener = db.collection("users").document(userID)
            .addSnapshotListener { [weak self] snapshot, error in
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

                    if self.lastKnownProfileDisplayName != self.desiredDisplayName {
                        self.scheduleDisplayNameUpdate()
                    }
                }
            }
    }

    private func scheduleDisplayNameUpdate() {
        displayNameUpdateTask?.cancel()

        guard currentUserID != nil else { return }
        displayNameUpdateTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 450_000_000)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            self?.performDisplayNameUpdate()
        }
    }

    private func performDisplayNameUpdate() {
        guard !isUpdatingDisplayName,
              let currentUserID,
              let friendCode,
              isProfileReady,
              lastKnownProfileDisplayName != desiredDisplayName else {
            return
        }

        isUpdatingDisplayName = true
        let newDisplayName = desiredDisplayName
        let batch = db.batch()
        batch.updateData(
            [
                "displayName": newDisplayName,
                "updatedAt": FieldValue.serverTimestamp()
            ],
            forDocument: db.collection("users").document(currentUserID)
        )
        batch.updateData(
            ["displayName": newDisplayName],
            forDocument: db.collection("friendCodes").document(friendCode)
        )

        batch.commit { [weak self] error in
            DispatchQueue.main.async {
                guard let self, self.currentUserID == currentUserID else { return }
                self.isUpdatingDisplayName = false

                if let error {
                    self.errorMessage = self.friendlyMessage(
                        for: error,
                        fallback: "Impossible de mettre à jour ton profil."
                    )
                    return
                }

                self.lastKnownProfileDisplayName = newDisplayName
                if self.desiredDisplayName != newDisplayName {
                    self.scheduleDisplayNameUpdate()
                }
            }
        }
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

                        let displayName = snapshot?.data()?["displayName"] as? String
                        self.profilesByUserID[userID] = displayName.map {
                            Self.normalizedDisplayName($0)
                        } ?? "Explorer"

                        if let currentLocation = self.receivedFriendLocations[userID] {
                            self.receivedFriendLocations[userID] = FriendLocation(
                                userID: currentLocation.userID,
                                displayName: self.profilesByUserID[userID] ?? "Explorer",
                                coordinate: currentLocation.coordinate,
                                horizontalAccuracy: currentLocation.horizontalAccuracy,
                                sampledAt: currentLocation.sampledAt,
                                updatedAt: currentLocation.updatedAt,
                                receivedAt: currentLocation.receivedAt
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
            let displayName = profilesByUserID[otherUserID] ?? "Explorer"

            if record.status == "accepted" {
                friends.append(
                    FriendContact(
                        userID: otherUserID,
                        displayName: displayName
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
            locationExpirationTasks.removeValue(forKey: userID)?.cancel()
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
                        guard self.isFresh(sampledAt, at: receivedAt),
                              self.isFresh(updatedAt, at: receivedAt) else {
                            self.removeFriendLocation(for: userID)
                            return
                        }

                        let displayName =
                            self.profilesByUserID[userID]
                            ?? (data["displayName"] as? String).map {
                                Self.normalizedDisplayName($0)
                            }
                            ?? "Explorer"

                        let friendLocation = FriendLocation(
                            userID: userID,
                            displayName: displayName,
                            coordinate: CLLocationCoordinate2D(
                                latitude: geoPoint.latitude,
                                longitude: geoPoint.longitude
                            ),
                            horizontalAccuracy: accuracy.doubleValue,
                            sampledAt: sampledAt,
                            updatedAt: updatedAt,
                            receivedAt: receivedAt
                        )
                        self.receivedFriendLocations[userID] = friendLocation
                        self.scheduleExpiration(for: friendLocation)
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

    private func scheduleExpiration(for location: FriendLocation) {
        locationExpirationTasks.removeValue(forKey: location.userID)?.cancel()
        let freshnessReference = min(
            min(location.sampledAt, location.updatedAt),
            location.receivedAt
        )
        let delay = max(
            0,
            maximumLocationAge - Date().timeIntervalSince(freshnessReference)
        )
        let nanoseconds = UInt64(delay * 1_000_000_000)

        locationExpirationTasks[location.userID] = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: nanoseconds)
            } catch {
                return
            }

            guard !Task.isCancelled, let self,
                  let currentLocation =
                    self.receivedFriendLocations[location.userID],
                  currentLocation.sampledAt == location.sampledAt,
                  currentLocation.updatedAt == location.updatedAt,
                  currentLocation.receivedAt == location.receivedAt else {
                return
            }
            self.receivedFriendLocations.removeValue(forKey: location.userID)
            self.locationExpirationTasks.removeValue(forKey: location.userID)
        }
    }

    private func removeFriendLocation(for userID: String) {
        locationExpirationTasks.removeValue(forKey: userID)?.cancel()
        receivedFriendLocations.removeValue(forKey: userID)
    }

    // MARK: - Location writes

    private func writeLocation(
        _ location: CLLocation,
        displayName: String,
        for userID: String,
        bypassThrottle: Bool
    ) {
        guard currentUserID == userID,
              isFresh(location.timestamp, at: Date()) else {
            return
        }

        let now = Date()
        if !bypassThrottle, let lastLocationPush {
            let distance = location.distance(from: lastLocationPush.location)
            let elapsed = now.timeIntervalSince(lastLocationPush.attemptedAt)
            if distance < minimumLocationPushDistance
                && elapsed < minimumLocationPushInterval {
                return
            }
        }

        lastLocationPush = (location, now)
        let attemptedLocationTimestamp = location.timestamp
        db.collection("locations").document(userID).setData(
            [
                "location": GeoPoint(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                ),
                "displayName": displayName,
                "horizontalAccuracy": location.horizontalAccuracy,
                "sampledAt": Timestamp(date: location.timestamp),
                "updatedAt": FieldValue.serverTimestamp()
            ]
        ) { [weak self] error in
            DispatchQueue.main.async {
                guard let self, self.currentUserID == userID else { return }

                if let error {
                    if self.lastLocationPush?.location.timestamp
                        == attemptedLocationTimestamp {
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

        for task in locationExpirationTasks.values {
            task.cancel()
        }
        locationExpirationTasks.removeAll()
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

    private func isFresh(_ location: FriendLocation, at date: Date) -> Bool {
        isFresh(location.sampledAt, at: date)
            && isFresh(location.updatedAt, at: date)
            && isFresh(location.receivedAt, at: date)
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
}
