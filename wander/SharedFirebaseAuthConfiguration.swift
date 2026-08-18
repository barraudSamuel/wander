//
//  SharedFirebaseAuthConfiguration.swift
//  wander
//

import FirebaseAuth
import Foundation

enum SharedFirebaseAuthConfiguration {
    private static let accessGroupInfoKey = "WanderSharedAuthAccessGroup"

    static func configureHost(
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        do {
            let auth = Auth.auth()
            let accessGroup = try resolvedAccessGroup()

            if try auth.getStoredUser(forAccessGroup: accessGroup) != nil {
                try auth.useUserAccessGroup(accessGroup)
                completion(.success(()))
                return
            }

            let existingUser = auth.currentUser
            try auth.useUserAccessGroup(accessGroup)

            guard let existingUser else {
                completion(.success(()))
                return
            }

            auth.updateCurrentUser(existingUser) { error in
                if let error {
                    restoreUnsharedUser(existingUser) {
                        completion(.failure(error))
                    }
                } else {
                    completion(.success(()))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }

    static func configureExtension() throws {
        try Auth.auth().useUserAccessGroup(resolvedAccessGroup())
    }

    private static func restoreUnsharedUser(
        _ user: User,
        completion: @escaping () -> Void
    ) {
        do {
            try Auth.auth().useUserAccessGroup(nil)
            Auth.auth().updateCurrentUser(user) { _ in
                completion()
            }
        } catch {
            completion()
        }
    }

    private static func resolvedAccessGroup() throws -> String {
        guard let accessGroup = Bundle.main.object(
            forInfoDictionaryKey: accessGroupInfoKey
        ) as? String,
              !accessGroup.isEmpty,
              !accessGroup.contains("$(") else {
            throw SharedFirebaseAuthConfigurationError.missingAccessGroup
        }
        return accessGroup
    }
}

enum SharedFirebaseAuthConfigurationError: LocalizedError {
    case missingAccessGroup

    var errorDescription: String? {
        "La session partagée Wander n’est pas configurée."
    }
}
