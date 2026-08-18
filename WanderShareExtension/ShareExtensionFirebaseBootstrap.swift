//
//  ShareExtensionFirebaseBootstrap.swift
//  WanderShareExtension
//

import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation

struct ShareExtensionSession {
    let userID: String
    let displayName: String
}

enum ShareExtensionFirebaseBootstrap {
    static func loadSession() async throws -> ShareExtensionSession {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        try SharedFirebaseAuthConfiguration.configureExtension()

        guard let user = Auth.auth().currentUser,
              !user.isAnonymous,
              user.providerData.contains(where: { $0.providerID == "apple.com" }) else {
            throw ShareExtensionBootstrapError.noSession
        }

        _ = try await user.getIDTokenResult(forcingRefresh: false)
        let document = try await Firestore.firestore()
            .collection("users")
            .document(user.uid)
            .getDocument(source: .server)
        guard document.exists,
              let displayName = document.data()?["displayName"] as? String else {
            throw ShareExtensionBootstrapError.profileUnavailable
        }

        let normalizedName = displayName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !normalizedName.isEmpty,
              normalizedName.count <= OutingPlan.maximumDisplayNameLength else {
            throw ShareExtensionBootstrapError.profileUnavailable
        }

        return ShareExtensionSession(
            userID: user.uid,
            displayName: normalizedName
        )
    }
}

enum ShareExtensionBootstrapError: LocalizedError {
    case noSession
    case profileUnavailable

    var errorDescription: String? {
        switch self {
        case .noSession:
            return "Ouvre Wander et connecte-toi une fois, puis réessaie le partage."
        case .profileUnavailable:
            return "Ton profil Wander n’est pas disponible pour le moment."
        }
    }
}
