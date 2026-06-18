//
//  wanderApp.swift
//  wander
//
//  Created by Samuel Barraud on 17/06/2026.
//

import SwiftUI
import SwiftData

@main
struct wanderApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: DiscoveredCell.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        migrateJSONToSwiftData(container: container)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }

    private func migrateJSONToSwiftData(container: ModelContainer) {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = urls.first!.appendingPathComponent("wander", isDirectory: true)
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
