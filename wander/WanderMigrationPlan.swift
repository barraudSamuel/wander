//
//  WanderMigrationPlan.swift
//  wander
//
//  Historical schemas preserve exploration and saved places; V5 adds categories.
//

import Foundation
import SwiftData

enum WanderSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [DiscoveredCell.self]
    }

    @Model
    final class DiscoveredCell {
        @Attribute(.unique) var id: String
        var resolution: Int
        var firstSeenAt: Date
        var lastSeenAt: Date

        init(id: String, resolution: Int, firstSeenAt: Date, lastSeenAt: Date) {
            self.id = id
            self.resolution = resolution
            self.firstSeenAt = firstSeenAt
            self.lastSeenAt = lastSeenAt
        }
    }
}

enum WanderSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [DiscoveredCell.self]
    }

    @Model
    final class DiscoveredCell {
        @Attribute(.unique) var id: String
        var resolution: Int
        var firstSeenAt: Date
        var lastSeenAt: Date
        var duration: TimeInterval = 0
        var visitCount: Int = 1

        init(id: String, resolution: Int, firstSeenAt: Date, lastSeenAt: Date) {
            self.id = id
            self.resolution = resolution
            self.firstSeenAt = firstSeenAt
            self.lastSeenAt = lastSeenAt
        }
    }
}

enum WanderSchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [DiscoveredCell.self]
    }
}

enum WanderSchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 0, 0)

    static var models: [any PersistentModel.Type] {
        [DiscoveredCell.self, SavedPlace.self]
    }

    @Model
    final class SavedPlace {
        @Attribute(.unique) var id: String
        var ownerID: String
        var sourceID: String
        var name: String
        var address: String
        var latitude: Double
        var longitude: Double
        var naverURLString: String
        var isUnavailable: Bool
        var hasLocationWarning: Bool
        var listName: String

        init(place: NaverImportedPlace, ownerID: String, listName: String) {
            // Length prefix keeps account/source pairs unique even when identifiers contain separators.
            self.id = "\(ownerID.utf8.count):\(ownerID):\(place.id)"
            self.ownerID = ownerID
            self.sourceID = place.id
            self.name = place.name
            self.address = place.address
            self.latitude = place.latitude
            self.longitude = place.longitude
            self.naverURLString = place.naverURL.absoluteString
            self.isUnavailable = place.isUnavailable
            self.hasLocationWarning = place.hasLocationWarning
            self.listName = listName
        }
    }
}

enum WanderSchemaV5: VersionedSchema {
    static var versionIdentifier = Schema.Version(5, 0, 0)

    static var models: [any PersistentModel.Type] {
        [DiscoveredCell.self, SavedPlace.self]
    }
}

enum WanderMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [WanderSchemaV1.self, WanderSchemaV2.self, WanderSchemaV3.self, WanderSchemaV4.self, WanderSchemaV5.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: WanderSchemaV1.self, toVersion: WanderSchemaV2.self),
            .lightweight(fromVersion: WanderSchemaV2.self, toVersion: WanderSchemaV3.self),
            .lightweight(fromVersion: WanderSchemaV3.self, toVersion: WanderSchemaV4.self),
            .lightweight(fromVersion: WanderSchemaV4.self, toVersion: WanderSchemaV5.self)
        ]
    }
}
