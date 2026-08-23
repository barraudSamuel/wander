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
        eventIDValue: String? = nil
    ) async throws -> OutingPlan {
        try validateOwnerID(ownerID)
        let validatedDraft = try OutingPlan.validatedDraft(draft)
        if let eventIDValue,
           UUID(uuidString: eventIDValue) == nil {
            throw OutingPlanServiceError.invalidEventID
        }

        let eventIDValue = eventIDValue ?? UUID().uuidString
        let reference = eventReference(
            ownerID: ownerID,
            eventIDValue: eventIDValue
        )

        var data: [String: Any] = [
            "eventId": eventIDValue,
            "ownerId": ownerID,
            "publicationId": eventIDValue,
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
        return try await publishedEvent(from: reference)
    }

    func update(
        _ draft: OutingPlanDraft,
        existingPlan: OutingPlan,
        ownerID: String
    ) async throws -> OutingPlan {
        try validateOwnerID(ownerID)
        guard existingPlan.ownerID == ownerID,
              UUID(uuidString: existingPlan.eventIDValue) != nil else {
            throw OutingPlanServiceError.invalidEventID
        }

        let validatedDraft = try OutingPlan.validatedDraft(draft)
        let reference = eventReference(
            ownerID: ownerID,
            eventIDValue: existingPlan.eventIDValue
        )
        var data: [String: Any] = [
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
        } else {
            data["address"] = FieldValue.delete()
        }

        try await reference.updateData(data)
        return try await publishedEvent(from: reference)
    }

    private func validateOwnerID(_ ownerID: String) throws {
        guard !ownerID.isEmpty,
              ownerID.count <= 128,
              !ownerID.contains("__") else {
            throw OutingPlanServiceError.noAuthenticatedUser
        }
    }

    private func eventReference(
        ownerID: String,
        eventIDValue: String
    ) -> DocumentReference {
        database.collection("users")
            .document(ownerID)
            .collection("events")
            .document(eventIDValue)
    }

    private func publishedEvent(
        from reference: DocumentReference
    ) async throws -> OutingPlan {
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
