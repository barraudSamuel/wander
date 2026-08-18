//
//  OutingPlanPublishing.swift
//  wander
//

import CoreLocation
import FirebaseFirestore
import Foundation

@MainActor
struct OutingPlanPublisher {
    private let database: Firestore

    init(database: Firestore = Firestore.firestore()) {
        self.database = database
    }

    func publish(
        _ draft: OutingPlanDraft,
        ownerID: String,
        eventIDValue existingEventIDValue: String? = nil
    ) async throws -> OutingPlan {
        guard !ownerID.isEmpty,
              ownerID.count <= 128,
              !ownerID.contains("__") else {
            throw OutingPlanServiceError.noAuthenticatedUser
        }

        let validatedDraft = try OutingPlan.validatedDraft(draft)
        if let existingEventIDValue,
           UUID(uuidString: existingEventIDValue) == nil {
            throw OutingPlanServiceError.invalidEventID
        }

        let eventIDValue = existingEventIDValue ?? UUID().uuidString
        let reference = database.collection("users")
            .document(ownerID)
            .collection("events")
            .document(eventIDValue)

        var data: [String: Any] = [
            "eventId": eventIDValue,
            "ownerId": ownerID,
            "publicationId": UUID().uuidString,
            "displayName": validatedDraft.displayName,
            "placeName": validatedDraft.placeName,
            "category": validatedDraft.category.rawValue,
            "location": GeoPoint(
                latitude: validatedDraft.coordinate.latitude,
                longitude: validatedDraft.coordinate.longitude
            ),
            "plannedAt": Timestamp(date: validatedDraft.plannedAt),
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
            throw OutingPlanServiceError.missingPublishedEvent
        }
        return try OutingPlan(document: document)
    }
}

enum OutingPlanServiceError: LocalizedError, Equatable {
    case noAuthenticatedUser
    case invalidEventID
    case missingPublishedEvent
    case notificationEventUnavailable

    var errorDescription: String? {
        switch self {
        case .noAuthenticatedUser:
            return "Connecte-toi pour gérer un événement."
        case .invalidEventID:
            return "L’identifiant de l’événement est invalide."
        case .missingPublishedEvent:
            return "L’événement publié n’a pas pu être relu. Réessaie."
        case .notificationEventUnavailable:
            return "Cet événement n’est plus disponible."
        }
    }
}
