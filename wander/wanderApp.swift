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
        LegacyMigration.migrateJSONToSwiftData(container: container)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
