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
    @AppStorage("profile.onboardingCompleted") private var onboardingCompleted = false

    init() {
        do {
            container = try ModelContainer(for: DiscoveredCell.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        LegacyMigration.migrateJSONToSwiftData(container: container)

        FirebaseService.shared.configure()
        FirebaseService.shared.signIn()
    }

    var body: some Scene {
        WindowGroup {
            if onboardingCompleted {
                ContentView()
            } else {
                OnboardingView()
            }
        }
        .modelContainer(container)
    }
}
