//
//  FirebaseService.swift
//  wander
//

import AuthenticationServices
import Combine
import CryptoKit
import FirebaseAuth
import FirebaseCore
import Foundation
import Security

final class FirebaseService: ObservableObject {
    static let shared = FirebaseService()

    @Published private(set) var currentUserId: String?
    @Published private(set) var authErrorMessage: String?
    @Published private(set) var isAuthenticationResolved = false
    @Published private(set) var isSigningIn = false
    @Published private(set) var isDeletingAccount = false
    @Published private(set) var hasLegacyAnonymousAccount = false
    @Published private(set) var requiresExistingAccountConfirmation = false

    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var authStateGeneration = 0
    private var credentialRevocationObserver: NSObjectProtocol?
    private var currentNonce: String?
    private var accountDeletionNonce: String?
    private var pendingExistingAccountCredential: AuthCredential?

    private init() {}

    func configure() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        observeAppleCredentialRevocation()

        guard authStateHandle == nil else { return }

        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.resolveAuthenticationState(for: user)
            }
        }
    }

    func prepareAppleAuthorizationRequest(
        _ request: ASAuthorizationAppleIDRequest
    ) {
        configure()

        guard !isSigningIn else { return }
        isSigningIn = true
        authErrorMessage = nil
        requiresExistingAccountConfirmation = false
        pendingExistingAccountCredential = nil

        do {
            let nonce = try Self.randomNonceString()
            currentNonce = nonce
            request.nonce = Self.sha256(nonce)
        } catch {
            currentNonce = nil
            isSigningIn = false
            authErrorMessage = "La connexion sécurisée n’a pas pu démarrer. Réessaie."
        }
    }

    func handleAppleAuthorizationCompletion(
        _ result: Result<ASAuthorization, Error>
    ) {
        switch result {
        case .success(let authorization):
            handleAppleAuthorization(authorization)
        case .failure(let error):
            currentNonce = nil
            isSigningIn = false

            if let authorizationError = error as? ASAuthorizationError,
               authorizationError.code == .canceled {
                authErrorMessage = nil
            } else {
                authErrorMessage = friendlyAuthenticationMessage(for: error)
            }
        }
    }

    func clearError() {
        authErrorMessage = nil
    }

    @discardableResult
    func signOut() -> Bool {
        guard !isDeletingAccount else { return false }

        currentNonce = nil
        pendingExistingAccountCredential = nil
        requiresExistingAccountConfirmation = false
        authErrorMessage = nil

        do {
            try Auth.auth().signOut()
            return true
        } catch {
            authErrorMessage =
                "Impossible de te déconnecter pour le moment. Réessaie."
            return false
        }
    }

    func prepareAccountDeletionAuthorizationRequest(
        _ request: ASAuthorizationAppleIDRequest
    ) {
        configure()

        guard currentUserId != nil, !isDeletingAccount else { return }

        authErrorMessage = nil
        do {
            let nonce = try Self.randomNonceString()
            accountDeletionNonce = nonce
            isDeletingAccount = true
            request.nonce = Self.sha256(nonce)
        } catch {
            accountDeletionNonce = nil
            isDeletingAccount = false
            authErrorMessage =
                "La vérification sécurisée n’a pas pu démarrer. Réessaie."
        }
    }

    /// Returns the fresh Apple authorization code after proving that the
    /// currently authenticated Firebase user owns the Apple credential.
    /// A cancelled Apple sheet is represented by `nil` and changes no data.
    func reauthenticateForAccountDeletion(
        _ result: Result<ASAuthorization, Error>
    ) async throws -> String? {
        switch result {
        case .failure(let error):
            accountDeletionNonce = nil
            isDeletingAccount = false

            if let authorizationError = error as? ASAuthorizationError,
               authorizationError.code == .canceled {
                return nil
            }
            throw AccountDeletionError.appleAuthorizationFailed

        case .success(let authorization):
            guard let appleCredential =
                    authorization.credential as? ASAuthorizationAppleIDCredential,
                  let nonce = accountDeletionNonce,
                  let identityToken = appleCredential.identityToken,
                  let identityTokenString = String(
                    data: identityToken,
                    encoding: .utf8
                  ),
                  let authorizationCode = appleCredential.authorizationCode,
                  let authorizationCodeString = String(
                    data: authorizationCode,
                    encoding: .utf8
                  ),
                  let currentUser = Auth.auth().currentUser,
                  currentUser.uid == currentUserId
            else {
                accountDeletionNonce = nil
                isDeletingAccount = false
                throw AccountDeletionError.incompleteAppleResponse
            }

            accountDeletionNonce = nil
            let credential = OAuthProvider.appleCredential(
                withIDToken: identityTokenString,
                rawNonce: nonce,
                fullName: appleCredential.fullName
            )

            do {
                let result = try await currentUser.reauthenticate(
                    with: credential
                )
                guard result.user.uid == currentUser.uid else {
                    isDeletingAccount = false
                    throw AccountDeletionError.wrongAccount
                }
                return authorizationCodeString
            } catch let error as AccountDeletionError {
                throw error
            } catch {
                isDeletingAccount = false
                throw AccountDeletionError.reauthenticationFailed(error)
            }
        }
    }

    /// Revokes the Sign in with Apple grant before deleting the Firebase Auth
    /// record, following Firebase's required Apple account-deletion sequence.
    func finishAccountDeletion(authorizationCode: String) async throws {
        guard let user = Auth.auth().currentUser,
              user.uid == currentUserId else {
            isDeletingAccount = false
            throw AccountDeletionError.noAuthenticatedUser
        }

        do {
            try await Auth.auth().revokeToken(
                withAuthorizationCode: authorizationCode
            )
            try await user.delete()
            isDeletingAccount = false
            authErrorMessage = nil
        } catch {
            isDeletingAccount = false
            throw AccountDeletionError.finalizationFailed(error)
        }
    }

    func cancelAccountDeletion() {
        accountDeletionNonce = nil
        isDeletingAccount = false
    }

    func continueWithExistingAppleAccount() {
        guard let credential = pendingExistingAccountCredential else { return }

        pendingExistingAccountCredential = nil
        requiresExistingAccountConfirmation = false
        isSigningIn = true
        signIn(with: credential)
    }

    func cancelExistingAppleAccountSignIn() {
        pendingExistingAccountCredential = nil
        requiresExistingAccountConfirmation = false
        isSigningIn = false
    }

    private func handleAppleAuthorization(_ authorization: ASAuthorization) {
        guard let appleCredential =
                authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let identityToken = appleCredential.identityToken,
              let identityTokenString = String(data: identityToken, encoding: .utf8)
        else {
            currentNonce = nil
            isSigningIn = false
            authErrorMessage = "La réponse d’Apple est incomplète. Réessaie."
            return
        }

        currentNonce = nil

        let credential = OAuthProvider.appleCredential(
            withIDToken: identityTokenString,
            rawNonce: nonce,
            fullName: appleCredential.fullName
        )

        if let currentUser = Auth.auth().currentUser,
           currentUser.isAnonymous {
            linkLegacyAnonymousUser(currentUser, with: credential)
        } else {
            signIn(with: credential)
        }
    }

    private func linkLegacyAnonymousUser(
        _ user: User,
        with credential: AuthCredential
    ) {
        user.link(with: credential) { [weak self] result, error in
            guard let self else { return }

            if let error,
               let updatedCredential = self.updatedCredential(from: error) {
                self.pendingExistingAccountCredential = updatedCredential
                self.requiresExistingAccountConfirmation = true
                self.isSigningIn = false
                return
            }

            self.completeAuthentication(result: result, error: error)
        }
    }

    private func signIn(with credential: AuthCredential) {
        Auth.auth().signIn(with: credential) { [weak self] result, error in
            self?.completeAuthentication(result: result, error: error)
        }
    }

    private func completeAuthentication(
        result: AuthDataResult?,
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.isSigningIn = false
            self.isAuthenticationResolved = true

            if let error {
                self.authErrorMessage = self.friendlyAuthenticationMessage(for: error)
                return
            }

            guard let user = result?.user, Self.hasAppleProvider(user) else {
                self.authErrorMessage = "Connexion à ton compte impossible. Réessaie."
                return
            }

            self.resolveAuthenticationState(for: user)
        }
    }

    private func updatedCredential(from error: Error) -> AuthCredential? {
        let nsError = error as NSError
        guard nsError.domain == AuthErrors.domain,
              nsError.code == AuthErrorCode.credentialAlreadyInUse.rawValue else {
            return nil
        }

        return nsError.userInfo[
            AuthErrors.userInfoUpdatedCredentialKey
        ] as? AuthCredential
    }

    private func resolveAuthenticationState(for user: User?) {
        authStateGeneration &+= 1
        let generation = authStateGeneration
        let isAnonymous = user?.isAnonymous == true

        currentUserId = nil
        hasLegacyAnonymousAccount = isAnonymous
        isSigningIn = false

        guard let user, !isAnonymous, Self.hasAppleProvider(user) else {
            isAuthenticationResolved = true
            return
        }

        isAuthenticationResolved = false
        user.getIDTokenResult { [weak self] tokenResult, error in
            DispatchQueue.main.async {
                guard let self, self.authStateGeneration == generation else {
                    return
                }

                if let error {
                    self.isAuthenticationResolved = true
                    self.authErrorMessage = self.friendlyAuthenticationMessage(
                        for: error
                    )
                    return
                }

                guard tokenResult?.signInProvider
                        == AuthProviderID.apple.rawValue else {
                    self.isAuthenticationResolved = true
                    self.authErrorMessage = nil
                    return
                }

                guard let appleUserID = Self.appleUserID(for: user) else {
                    self.isAuthenticationResolved = true
                    self.authErrorMessage =
                        "Connexion à ton compte impossible. Réessaie."
                    return
                }

                self.verifyAppleCredentialState(
                    for: user,
                    appleUserID: appleUserID,
                    generation: generation
                )
            }
        }
    }

    private static func hasAppleProvider(_ user: User?) -> Bool {
        guard let user, !user.isAnonymous else { return false }

        return user.providerData.contains { userInfo in
            userInfo.providerID == AuthProviderID.apple.rawValue
        }
    }

    private static func appleUserID(for user: User) -> String? {
        user.providerData.first { userInfo in
            userInfo.providerID == AuthProviderID.apple.rawValue
        }?.uid
    }

    private func verifyAppleCredentialState(
        for user: User,
        appleUserID: String,
        generation: Int
    ) {
        ASAuthorizationAppleIDProvider().getCredentialState(
            forUserID: appleUserID
        ) { [weak self] credentialState, error in
            DispatchQueue.main.async {
                guard let self, self.authStateGeneration == generation else {
                    return
                }

                if error != nil {
                    self.isAuthenticationResolved = true
                    self.authErrorMessage =
                        "Impossible de vérifier ta connexion Apple. Réessaie."
                    return
                }

                switch credentialState {
                case .authorized:
                    self.currentUserId = user.uid
                    self.hasLegacyAnonymousAccount = false
                    self.isAuthenticationResolved = true
                    self.authErrorMessage = nil
                case .revoked, .notFound, .transferred:
                    self.invalidateAppleSession()
                @unknown default:
                    self.isAuthenticationResolved = true
                    self.authErrorMessage =
                        "Impossible de vérifier ta connexion Apple. Réessaie."
                }
            }
        }
    }

    private func observeAppleCredentialRevocation() {
        guard credentialRevocationObserver == nil else { return }

        credentialRevocationObserver = NotificationCenter.default.addObserver(
            forName: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async {
                guard FirebaseService.hasAppleProvider(
                    Auth.auth().currentUser
                ) else {
                    return
                }
                self?.invalidateAppleSession()
            }
        }
    }

    private func invalidateAppleSession() {
        authStateGeneration &+= 1
        currentNonce = nil
        accountDeletionNonce = nil
        pendingExistingAccountCredential = nil
        requiresExistingAccountConfirmation = false
        currentUserId = nil
        hasLegacyAnonymousAccount = false
        isSigningIn = false
        isDeletingAccount = false
        isAuthenticationResolved = true

        do {
            try Auth.auth().signOut()
            authErrorMessage =
                "Ta connexion Apple a été révoquée. Connecte-toi de nouveau."
        } catch {
            authErrorMessage =
                "Impossible de fermer la session Apple révoquée. Relance Wander."
        }
    }

    private func friendlyAuthenticationMessage(for error: Error) -> String {
        let nsError = error as NSError

        if nsError.domain == NSURLErrorDomain
            || nsError.code == AuthErrorCode.networkError.rawValue {
            return "Connexion impossible. Vérifie ta connexion internet."
        }

        if nsError.domain == AuthErrors.domain,
           nsError.code == AuthErrorCode.operationNotAllowed.rawValue {
            return "La connexion avec Apple n’est pas disponible pour le moment."
        }

        return "Connexion à ton compte impossible. Réessaie."
    }

    private static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.map { String(format: "%02x", $0) }.joined()
    }

    private static func randomNonceString(length: Int = 32) throws -> String {
        precondition(length > 0)

        var randomBytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(
            kSecRandomDefault,
            randomBytes.count,
            &randomBytes
        )
        guard status == errSecSuccess else {
            throw NonceGenerationError.randomBytesUnavailable
        }

        let characterSet = Array(
            "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._"
        )
        let nonce = randomBytes.map { byte in
            characterSet[Int(byte) % characterSet.count]
        }
        return String(nonce)
    }

    private enum NonceGenerationError: Error {
        case randomBytesUnavailable
    }

    enum AccountDeletionError: LocalizedError {
        case appleAuthorizationFailed
        case incompleteAppleResponse
        case wrongAccount
        case noAuthenticatedUser
        case reauthenticationFailed(Error)
        case finalizationFailed(Error)

        var errorDescription: String? {
            switch self {
            case .appleAuthorizationFailed:
                return "La vérification Apple a échoué. Réessaie."
            case .incompleteAppleResponse:
                return "La réponse d’Apple est incomplète. Réessaie."
            case .wrongAccount:
                return "Utilise le même compte Apple que celui connecté à Wander."
            case .noAuthenticatedUser:
                return "Ta session a expiré. Reconnecte-toi avant de réessayer."
            case .reauthenticationFailed(let error),
                 .finalizationFailed(let error):
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain
                    || nsError.code == AuthErrorCode.networkError.rawValue {
                    return "Connexion impossible. Vérifie ta connexion internet."
                }
                return "La suppression du compte n’a pas pu aboutir. Réessaie."
            }
        }
    }

    deinit {
        if let authStateHandle {
            Auth.auth().removeStateDidChangeListener(authStateHandle)
        }
        if let credentialRevocationObserver {
            NotificationCenter.default.removeObserver(
                credentialRevocationObserver
            )
        }
    }
}
