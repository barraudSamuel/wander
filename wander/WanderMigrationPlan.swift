//
//  WanderMigrationPlan.swift
//  wander
//
//  Historical schemas preserve existing exploration while V3 removes heatmap data.
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

enum WanderMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [WanderSchemaV1.self, WanderSchemaV2.self, WanderSchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: WanderSchemaV1.self, toVersion: WanderSchemaV2.self),
            .lightweight(fromVersion: WanderSchemaV2.self, toVersion: WanderSchemaV3.self)
        ]
    }
}
