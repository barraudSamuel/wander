//
//  OutingAttendance.swift
//  wander
//

import FirebaseFirestore
import Foundation

struct OutingAttendance: Identifiable, Equatable {
    static let maximumUserIDLength = 128

    let id: String
    let ownerID: String
    let participantID: String
    let publicationID: UUID
    let publicationIDValue: String
    let displayName: String
    let avatarID: String
    let joinedAt: Date
    let expiresAt: Date

    func isActive(at referenceDate: Date = Date()) -> Bool {
        referenceDate < expiresAt
    }

    static func documentID(
        publicationIDValue: String,
        participantID: String
    ) throws -> String {
        guard isValidUserID(participantID) else {
            throw OutingAttendanceValidationError.invalidParticipant
        }
        guard UUID(uuidString: publicationIDValue) != nil else {
            throw OutingAttendanceValidationError.invalidPublication
        }
        return "\(publicationIDValue)__\(participantID)"
    }

    init(
        document: DocumentSnapshot,
        ownerID: String,
        expectedParticipantID: String? = nil
    ) throws {
        guard Self.isValidUserID(ownerID) else {
            throw OutingAttendanceValidationError.invalidOwner
        }
        guard let data = document.data(),
              let participantID = data["participantId"] as? String,
              Self.isValidUserID(participantID),
              expectedParticipantID == nil
                || participantID == expectedParticipantID else {
            throw OutingAttendanceValidationError.invalidParticipant
        }
        guard let publicationIDValue = data["publicationId"] as? String,
              let publicationID = UUID(uuidString: publicationIDValue),
              document.documentID
                == "\(publicationIDValue)__\(participantID)" else {
            throw OutingAttendanceValidationError.invalidPublication
        }
        guard let displayName = data["displayName"] as? String,
              Self.isValidDisplayName(displayName),
              let avatarID = data["avatarID"] as? String,
              ProfileAvatar.normalizedID(avatarID) == avatarID else {
            throw OutingAttendanceValidationError.invalidProfile
        }
        guard let joinedAt = (data["joinedAt"] as? Timestamp)?.dateValue(),
              let expiresAt = (data["expiresAt"] as? Timestamp)?.dateValue(),
              joinedAt < expiresAt else {
            throw OutingAttendanceValidationError.invalidDates
        }

        self.id = document.documentID
        self.ownerID = ownerID
        self.participantID = participantID
        self.publicationID = publicationID
        self.publicationIDValue = publicationIDValue
        self.displayName = displayName
        self.avatarID = avatarID
        self.joinedAt = joinedAt
        self.expiresAt = expiresAt
    }

    private static func isValidUserID(_ value: String) -> Bool {
        !value.isEmpty
            && value.count <= maximumUserIDLength
            && !value.contains("__")
    }

    private static func isValidDisplayName(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return !normalized.isEmpty
            && normalized == value
            && value.count <= 50
    }
}

enum OutingAttendanceValidationError: Error, Equatable {
    case invalidOwner
    case invalidParticipant
    case invalidPublication
    case invalidProfile
    case invalidDates
}
