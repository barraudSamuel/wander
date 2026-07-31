//
//  FirebaseService.swift
//  wander
//

import Foundation
import Combine
import FirebaseCore
import FirebaseAuth

final class FirebaseService: ObservableObject {
    static let shared = FirebaseService()

    @Published private(set) var currentUserId: String?
    @Published private(set) var authErrorMessage: String?
    @Published private(set) var isAuthenticationResolved = false

    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var isSigningIn = false

    private init() {}

    func configure() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        guard authStateHandle == nil else { return }

        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                guard let self else { return }
                self.currentUserId = user?.uid
                self.isAuthenticationResolved = true
                if user != nil {
                    self.authErrorMessage = nil
                    self.isSigningIn = false
                }
            }
        }
    }

    func signIn() {
        configure()

        guard Auth.auth().currentUser == nil, !isSigningIn else { return }
        isSigningIn = true
        authErrorMessage = nil

        Auth.auth().signInAnonymously { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSigningIn = false

                if let error {
                    self.isAuthenticationResolved = true
                    self.authErrorMessage = self.friendlyAuthenticationMessage(for: error)
                    return
                }

                if let result {
                    self.currentUserId = result.user.uid
                    self.isAuthenticationResolved = true
                    self.authErrorMessage = nil
                }
            }
        }
    }

    func clearError() {
        authErrorMessage = nil
        if Auth.auth().currentUser == nil {
            signIn()
        }
    }

    private func friendlyAuthenticationMessage(for error: Error) -> String {
        let nsError = error as NSError

        if nsError.domain == NSURLErrorDomain
            || nsError.code == AuthErrorCode.networkError.rawValue {
            return "Connexion impossible. Vérifie ta connexion internet."
        }

        return "Connexion à ton compte impossible. Réessaie."
    }

    deinit {
        if let authStateHandle {
            Auth.auth().removeStateDidChangeListener(authStateHandle)
        }
    }
}
