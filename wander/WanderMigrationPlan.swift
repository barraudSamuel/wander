//
//  WanderMigrationPlan.swift
//  wander
//
//  SwiftData schema migration from V1 (firstSeenAt, lastSeenAt only)
//  to V2 (added duration & visitCount).
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

enum WanderMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [WanderSchemaV1.self, WanderSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: WanderSchemaV1.self,
        toVersion: WanderSchemaV2.self
    )
}

// V2 uses the current app model.
enum WanderSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [DiscoveredCell.self]
    }
}
