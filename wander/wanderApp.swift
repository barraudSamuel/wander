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
    @UIApplicationDelegateAdaptor(WanderAppDelegate.self)
    private var appDelegate

    let container: ModelContainer
    @AppStorage("profile.onboardingCompleted") private var onboardingCompleted = false
    @StateObject private var authenticationService = FirebaseService.shared
    @StateObject private var friendSyncService = FriendSyncService.shared

    private var showsOnboardingPreview: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-preview-onboarding")
        #else
        false
        #endif
    }

    init() {
        do {
            container = try ModelContainer(for: DiscoveredCell.self, migrationPlan: WanderMigrationPlan.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        LegacyMigration.migrateJSONToSwiftData(container: container)

        FirebaseService.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if showsOnboardingPreview {
                    OnboardingView(isRestoringExistingProfile: false)
                } else if !authenticationService.isAuthenticationResolved {
                    ProgressView("Connexion…")
                } else if authenticationService.currentUserId == nil {
                    AuthenticationView(
                        authenticationService: authenticationService
                    )
                } else if onboardingCompleted {
                    ContentView()
                } else if !friendSyncService.isAccountBootstrapResolved {
                    AccountBootstrapView(service: friendSyncService)
                } else {
                    OnboardingView(
                        isRestoringExistingProfile:
                            friendSyncService.accountProfileOrigin == .existing
                    )
                }
            }
            .animation(
                .default,
                value: authenticationService.currentUserId
            )
        }
        .modelContainer(container)
    }
}

private struct AccountBootstrapView: View {
    @ObservedObject var service: FriendSyncService

    var body: some View {
        Group {
            if let errorMessage = service.accountBootstrapErrorMessage {
                ContentUnavailableView {
                    Label(
                        "Compte indisponible",
                        systemImage: "person.crop.circle.badge.exclamationmark"
                    )
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Réessayer") {
                        service.retryProfileSetup()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ProgressView("Restauration de ton compte…")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
