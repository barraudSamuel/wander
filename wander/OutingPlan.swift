//
//  OutingPlan.swift
//  wander
//

import CoreLocation
import FirebaseFirestore
import Foundation

struct OutingPlan: Identifiable, Equatable {
    static let maximumPlanningInterval: TimeInterval = 24 * 60 * 60
    static let maximumDisplayNameLength = 50
    static let maximumPlaceNameLength = 120
    static let maximumAddressLength = 200

    let eventID: UUID
    let eventIDValue: String
    let ownerID: String
    let publicationID: UUID
    let publicationIDValue: String
    let displayName: String
    let placeName: String
    let address: String?
    let coordinate: CLLocationCoordinate2D
    let plannedAt: Date
    let publishedAt: Date
    let updatedAt: Date
    let timeZoneIdentifier: String

    var id: String { eventIDValue }

    static func == (lhs: OutingPlan, rhs: OutingPlan) -> Bool {
        lhs.eventID == rhs.eventID
            && lhs.eventIDValue == rhs.eventIDValue
            && lhs.ownerID == rhs.ownerID
            && lhs.publicationID == rhs.publicationID
            && lhs.publicationIDValue == rhs.publicationIDValue
            && lhs.displayName == rhs.displayName
            && lhs.placeName == rhs.placeName
            && lhs.address == rhs.address
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
            && lhs.plannedAt == rhs.plannedAt
            && lhs.publishedAt == rhs.publishedAt
            && lhs.updatedAt == rhs.updatedAt
            && lhs.timeZoneIdentifier == rhs.timeZoneIdentifier
    }
}

struct OutingPlanDraft: Equatable {
    let displayName: String
    let placeName: String
    let address: String?
    let coordinate: CLLocationCoordinate2D
    let plannedAt: Date
    let timeZoneIdentifier: String

    static func == (lhs: OutingPlanDraft, rhs: OutingPlanDraft) -> Bool {
        lhs.displayName == rhs.displayName
            && lhs.placeName == rhs.placeName
            && lhs.address == rhs.address
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
            && lhs.plannedAt == rhs.plannedAt
            && lhs.timeZoneIdentifier == rhs.timeZoneIdentifier
    }
}

enum OutingPlanValidationError: LocalizedError, Equatable {
    case invalidOwner
    case invalidDisplayName
    case invalidPlaceName
    case invalidAddress
    case invalidCoordinate
    case invalidPlannedDate
    case invalidEventID
    case invalidTimeZone
    case invalidPublicationID
    case invalidAuditDates

    var errorDescription: String? {
        switch self {
        case .invalidOwner:
            return "Le propriétaire de la sortie est invalide."
        case .invalidDisplayName:
            return "Le nom du profil est invalide."
        case .invalidPlaceName:
            return "Le nom du lieu est invalide."
        case .invalidAddress:
            return "L’adresse du lieu est invalide."
        case .invalidCoordinate:
            return "La position du lieu est invalide."
        case .invalidPlannedDate:
            return "Choisis une heure dans les prochaines 24 heures."
        case .invalidEventID:
            return "L’identifiant de l’événement est invalide."
        case .invalidTimeZone:
            return "Le fuseau horaire est invalide."
        case .invalidPublicationID:
            return "L’identifiant de publication est invalide."
        case .invalidAuditDates:
            return "Les dates de publication sont invalides."
        }
    }
}

extension OutingPlan {
    static func validatedDraft(
        _ draft: OutingPlanDraft,
        referenceDate: Date = Date()
    ) throws -> OutingPlanDraft {
        let displayName = normalizeRequiredText(draft.displayName)
        guard !displayName.isEmpty,
              displayName.count <= maximumDisplayNameLength else {
            throw OutingPlanValidationError.invalidDisplayName
        }

        let placeName = normalizeRequiredText(draft.placeName)
        guard !placeName.isEmpty,
              placeName.count <= maximumPlaceNameLength else {
            throw OutingPlanValidationError.invalidPlaceName
        }

        let address = normalizeOptionalText(draft.address)
        guard address?.count ?? 0 <= maximumAddressLength else {
            throw OutingPlanValidationError.invalidAddress
        }

        guard CLLocationCoordinate2DIsValid(draft.coordinate),
              draft.coordinate.latitude.isFinite,
              draft.coordinate.longitude.isFinite else {
            throw OutingPlanValidationError.invalidCoordinate
        }

        let planningInterval = draft.plannedAt.timeIntervalSince(referenceDate)
        guard planningInterval > 0,
              planningInterval <= maximumPlanningInterval else {
            throw OutingPlanValidationError.invalidPlannedDate
        }

        guard isValidTimeZoneIdentifier(draft.timeZoneIdentifier) else {
            throw OutingPlanValidationError.invalidTimeZone
        }

        return OutingPlanDraft(
            displayName: displayName,
            placeName: placeName,
            address: address,
            coordinate: draft.coordinate,
            plannedAt: draft.plannedAt,
            timeZoneIdentifier: draft.timeZoneIdentifier
        )
    }

    init(document: DocumentSnapshot) throws {
        guard let data = document.data(),
              let eventIDValue = data["eventId"] as? String,
              eventIDValue == document.documentID,
              let eventID = UUID(uuidString: eventIDValue) else {
            throw OutingPlanValidationError.invalidEventID
        }

        guard let ownerID = data["ownerId"] as? String,
              !ownerID.isEmpty,
              ownerID.count <= 128,
              !ownerID.contains("__") else {
            throw OutingPlanValidationError.invalidOwner
        }

        guard let publicationIDValue = data["publicationId"] as? String,
              let publicationID = UUID(uuidString: publicationIDValue) else {
            throw OutingPlanValidationError.invalidPublicationID
        }

        guard let displayName = data["displayName"] as? String,
              displayName == Self.normalizeRequiredText(displayName),
              !displayName.isEmpty,
              displayName.count <= Self.maximumDisplayNameLength else {
            throw OutingPlanValidationError.invalidDisplayName
        }

        guard let placeName = data["placeName"] as? String,
              placeName == Self.normalizeRequiredText(placeName),
              !placeName.isEmpty,
              placeName.count <= Self.maximumPlaceNameLength else {
            throw OutingPlanValidationError.invalidPlaceName
        }

        let address: String?
        if let rawAddress = data["address"] as? String {
            guard rawAddress == Self.normalizeRequiredText(rawAddress),
                  !rawAddress.isEmpty,
                  rawAddress.count <= Self.maximumAddressLength else {
                throw OutingPlanValidationError.invalidAddress
            }
            address = rawAddress
        } else {
            address = nil
        }

        guard let location = data["location"] as? GeoPoint else {
            throw OutingPlanValidationError.invalidCoordinate
        }
        let coordinate = CLLocationCoordinate2D(
            latitude: location.latitude,
            longitude: location.longitude
        )
        guard CLLocationCoordinate2DIsValid(coordinate) else {
            throw OutingPlanValidationError.invalidCoordinate
        }

        guard let publishedAt = (data["publishedAt"] as? Timestamp)?.dateValue(),
              let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue(),
              updatedAt >= publishedAt else {
            throw OutingPlanValidationError.invalidAuditDates
        }

        guard let plannedAt = (data["plannedAt"] as? Timestamp)?.dateValue(),
              plannedAt > publishedAt,
              plannedAt.timeIntervalSince(publishedAt)
                <= Self.maximumPlanningInterval else {
            throw OutingPlanValidationError.invalidPlannedDate
        }

        guard let timeZoneIdentifier = data["timeZoneIdentifier"] as? String,
              Self.isValidTimeZoneIdentifier(timeZoneIdentifier) else {
            throw OutingPlanValidationError.invalidTimeZone
        }

        self.eventID = eventID
        self.eventIDValue = eventIDValue
        self.ownerID = ownerID
        self.publicationID = publicationID
        self.publicationIDValue = publicationIDValue
        self.displayName = displayName
        self.placeName = placeName
        self.address = address
        self.coordinate = coordinate
        self.plannedAt = plannedAt
        self.publishedAt = publishedAt
        self.updatedAt = updatedAt
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    private static func normalizeRequiredText(_ value: String) -> String {
        value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func normalizeOptionalText(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = normalizeRequiredText(value)
        return normalized.isEmpty ? nil : normalized
    }

    private static func isValidTimeZoneIdentifier(_ identifier: String) -> Bool {
        TimeZone.knownTimeZoneIdentifiers.contains(identifier)
    }
}
