//
//  OutingPlanService.swift
//  wander
//

import CoreLocation
import FirebaseFirestore
import Foundation

@MainActor
final class OutingPlanService {
    static let shared = OutingPlanService()

    private let database: Firestore
    private let currentUserID: @MainActor () -> String?

    init(
        database: Firestore = Firestore.firestore(),
        currentUserID: @escaping @MainActor () -> String? = {
            FirebaseService.shared.currentUserId
        }
    ) {
        self.database = database
        self.currentUserID = currentUserID
    }

    @discardableResult
    func publish(_ draft: OutingPlanDraft) async throws -> OutingPlan {
        let userID = try authenticatedUserID()
        let validatedDraft = try OutingPlan.validatedDraft(draft)
        let reference = planReference(for: userID)

        var data: [String: Any] = [
            "ownerId": userID,
            "publicationId": UUID().uuidString,
            "displayName": validatedDraft.displayName,
            "placeName": validatedDraft.placeName,
            "location": GeoPoint(
                latitude: validatedDraft.coordinate.latitude,
                longitude: validatedDraft.coordinate.longitude
            ),
            "plannedAt": Timestamp(date: validatedDraft.plannedAt),
            "expiresAt": Timestamp(
                date: validatedDraft.plannedAt.addingTimeInterval(
                    OutingPlan.activeInterval
                )
            ),
            "publishedAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "timeZoneIdentifier": validatedDraft.timeZoneIdentifier
        ]
        if let address = validatedDraft.address {
            data["address"] = address
        }

        try await reference.setData(data)
        let document = try await reference.getDocument(source: .server)
        guard document.exists else {
            throw OutingPlanServiceError.missingPublishedPlan
        }
        return try OutingPlan(document: document)
    }

    func fetchCurrentPlan() async throws -> OutingPlan? {
        let userID = try authenticatedUserID()
        let document = try await planReference(for: userID)
            .getDocument(source: .server)
        guard document.exists else { return nil }
        return try OutingPlan(document: document)
    }

    func cancelCurrentPlan() async throws {
        let userID = try authenticatedUserID()
        try await planReference(for: userID).delete()
    }

    private func authenticatedUserID() throws -> String {
        guard let userID = currentUserID(), !userID.isEmpty else {
            throw OutingPlanServiceError.noAuthenticatedUser
        }
        return userID
    }

    private func planReference(for userID: String) -> DocumentReference {
        database.collection("plans").document(userID)
    }
}

enum OutingPlanServiceError: LocalizedError, Equatable {
    case noAuthenticatedUser
    case missingPublishedPlan

    var errorDescription: String? {
        switch self {
        case .noAuthenticatedUser:
            return "Connecte-toi pour gérer une sortie."
        case .missingPublishedPlan:
            return "La sortie publiée n’a pas pu être relue. Réessaie."
        }
    }
}
