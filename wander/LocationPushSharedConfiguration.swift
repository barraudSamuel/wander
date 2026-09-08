//
//  LocationPushSharedConfiguration.swift
//  wander
//

import CoreFoundation
import FirebaseFirestore
import Foundation

nonisolated enum LocationPushSharedConfiguration {
    static let appGroupID = "group.com.iterar.wander.shared"
    static let sharingEnabledKey = "locationPush.sharingEnabled"
    static let ownerIDKey = "locationPush.ownerID"
    static let consentRevisionKey = "locationPush.consentRevision"
}

/// Used by every location publisher, including the location push extension.
nonisolated enum LocationSharingPolicy {
    static let ghostModeKey = "isGhostModeEnabled"
    static let revisionKey = "locationSharingRevision"
    static let resumedAtKey = "locationSharingResumedAt"

    static func ghostModeEnabled(in profile: [String: Any]) -> Bool {
        guard let rawValue = profile[ghostModeKey] else { return false }
        guard let value = rawValue as? NSNumber,
              CFGetTypeID(value) == CFBooleanGetTypeID() else {
            return true
        }
        return value.boolValue
    }

    static func allowsPublication(
        profile: [String: Any],
        expectedRevision: String?,
        sampledAt: Date? = nil
    ) -> Bool {
        guard profile["deletionRequestedAt"] == nil,
              !ghostModeEnabled(in: profile) else { return false }

        let revision: String?
        if let rawRevision = profile[revisionKey] {
            guard let value = rawRevision as? String, !value.isEmpty else {
                return false
            }
            revision = value
        } else {
            revision = nil
        }
        guard revision == expectedRevision else { return false }

        if let sampledAt, let rawResumedAt = profile[resumedAtKey] {
            guard let resumedAt = rawResumedAt as? Timestamp,
                  sampledAt >= resumedAt.dateValue() else { return false }
        }
        return true
    }
}
