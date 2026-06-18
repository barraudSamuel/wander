//
//  LegacyMigration.swift
//  wander
//
//  Handles migration from a JSON-based discovered-cells store (V1)
//  to SwiftData. Runs once on first app launch after the upgrade.
//

import Foundation
import SwiftData

enum LegacyMigration {

    /// Migrates discovered cells from `discovered_cells.json` into SwiftData,
    /// then renames the JSON file so the migration never runs twice.
    static func migrateJSONToSwiftData(container: ModelContainer) {
        let fileManager = FileManager.default

        guard let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("[Migration] applicationSupportDirectory not found")
            return
        }
        let appSupport = appSupportDir.appendingPathComponent("wander", isDirectory: true)
        let jsonURL = appSupport.appendingPathComponent("discovered_cells.json")

        guard fileManager.fileExists(atPath: jsonURL.path) else { return }

        do {
            let data = try Data(contentsOf: jsonURL)
            let legacyCells = try JSONDecoder().decode([LegacyDiscoveredCell].self, from: data)

            guard !legacyCells.isEmpty else {
                try? fileManager.removeItem(at: jsonURL)
                return
            }

            let context = container.mainContext
            for legacy in legacyCells {
                let cell = DiscoveredCell(
                    id: legacy.id,
                    resolution: legacy.resolution,
                    firstSeenAt: legacy.firstSeenAt,
                    lastSeenAt: legacy.lastSeenAt
                )
                context.insert(cell)
            }
            try context.save()

            let migratedURL = appSupport.appendingPathComponent("discovered_cells.json.migrated")
            try? fileManager.removeItem(at: migratedURL)
            try fileManager.moveItem(at: jsonURL, to: migratedURL)

            print("[Migration] Imported \(legacyCells.count) cells from JSON to SwiftData")
        } catch {
            print("[Migration] Failed: \(error.localizedDescription)")
        }
    }
}

private struct LegacyDiscoveredCell: Codable {
    let id: String
    let resolution: Int
    let firstSeenAt: Date
    let lastSeenAt: Date
}
