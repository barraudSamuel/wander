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

    @Published var currentUserId: String?

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    private init() {}

    func configure() {
        FirebaseApp.configure()

        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.currentUserId = user?.uid
        }
    }

    func signIn() {
        guard Auth.auth().currentUser == nil else { return }

        Task {
            do {
                let result = try await Auth.auth().signInAnonymously()
                print("[FirebaseService] signed in anonymously: \(result.user.uid)")
            } catch {
                print("[FirebaseService] anonymous sign-in failed: \(error.localizedDescription)")
            }
        }
    }
}
