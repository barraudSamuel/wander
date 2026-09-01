//
//  OutingDecline.swift
//  wander
//

import FirebaseFirestore
import Foundation

struct OutingDecline: Identifiable, Equatable {
    let id: String
    let eventID: UUID
    let eventIDValue: String
    let ownerID: String
    let participantID: String
    let publicationID: UUID
    let publicationIDValue: String
    let displayName: String
    let avatarID: String
    let respondedAt: Date

    static func documentID(
        publicationIDValue: String,
        participantID: String
    ) throws -> String {
        try OutingAttendance.documentID(
            publicationIDValue: publicationIDValue,
            participantID: participantID
        )
    }

    init(
        document: DocumentSnapshot,
        ownerID: String,
        eventIDValue: String,
        expectedParticipantID: String? = nil
    ) throws {
        guard let eventID = UUID(uuidString: eventIDValue),
              let data = document.data(),
              data["eventId"] as? String == eventIDValue else {
            throw OutingDeclineValidationError.invalidEvent
        }
        guard let participantID = data["participantId"] as? String,
              !participantID.isEmpty,
              participantID.count <= OutingAttendance.maximumUserIDLength,
              !participantID.contains("__"),
              expectedParticipantID == nil
                || participantID == expectedParticipantID else {
            throw OutingDeclineValidationError.invalidParticipant
        }
        guard let publicationIDValue = data["publicationId"] as? String,
              let publicationID = UUID(uuidString: publicationIDValue),
              document.documentID
                == "\(publicationIDValue)__\(participantID)" else {
            throw OutingDeclineValidationError.invalidPublication
        }
        guard let displayName = data["displayName"] as? String,
              !displayName.isEmpty,
              displayName.count <= 50,
              displayName == displayName.trimmingCharacters(
                in: .whitespacesAndNewlines
              ),
              let avatarID = data["avatarID"] as? String,
              ProfileAvatar.normalizedID(avatarID) == avatarID else {
            throw OutingDeclineValidationError.invalidProfile
        }
        guard let respondedAt = (data["respondedAt"] as? Timestamp)?
            .dateValue() else {
            throw OutingDeclineValidationError.invalidDate
        }

        self.id = document.documentID
        self.eventID = eventID
        self.eventIDValue = eventIDValue
        self.ownerID = ownerID
        self.participantID = participantID
        self.publicationID = publicationID
        self.publicationIDValue = publicationIDValue
        self.displayName = displayName
        self.avatarID = avatarID
        self.respondedAt = respondedAt
    }
}

enum OutingDeclineValidationError: Error, Equatable {
    case invalidEvent
    case invalidParticipant
    case invalidPublication
    case invalidProfile
    case invalidDate
}
