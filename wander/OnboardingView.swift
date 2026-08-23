//
//  OnboardingView.swift
//  wander
//
//  Created by Codex on 18/06/2026.
//

import CoreLocation
import SwiftUI
import UIKit

struct OnboardingView: View {
    let isRestoringExistingProfile: Bool

    @AppStorage("profile.displayName") private var storedDisplayName = ""
    @AppStorage(ProfileAvatar.storageKey) private var avatarID = ""
    @AppStorage("profile.onboardingCompleted") private var onboardingCompleted = false

    @Environment(\.openURL) private var openURL
    @StateObject private var locationTracker = LocationTracker()
    @ObservedObject private var friendSyncService = FriendSyncService.shared

    @State private var path: [Destination] = []
    @State private var displayName = ""

    private enum Destination: Hashable {
        case profile
        case location
    }

    private var trimmedDisplayName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canContinue: Bool {
        !trimmedDisplayName.isEmpty
    }

    var body: some View {
        NavigationStack(path: $path) {
            discoveryStep
                .navigationDestination(for: Destination.self) { destination in
                    switch destination {
                    case .profile:
                        profileStep
                    case .location:
                        locationStep
                    }
                }
        }
        .onAppear {
            displayName = storedDisplayName
            ensureAvatarSelection()
        }
        .onChange(of: avatarID) { _, newAvatarID in
            friendSyncService.updateAvatarID(newAvatarID)
        }
    }

    private var discoveryStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image("OnboardingDiscoveryMap")
                        .resizable()
                        .scaledToFill()
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                        )
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(
                            "Illustration d’une carte révélée au fil des déplacements"
                        )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Découvre ta propre carte")
                            .font(.largeTitle.bold())
                            .accessibilityAddTraits(.isHeader)

                        Text(
                            "Dévoile la carte au fil de tes déplacements et "
                                + "partage ta position avec tes amis pour vous "
                                + "retrouver plus facilement."
                        )
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Label("Explore la carte zone par zone", systemImage: "map.fill")
                        Label(
                            "Partage ta position avec tes amis",
                            systemImage: "person.2.fill"
                        )
                    }
                    .font(.headline)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }

            Button {
                path.append(.profile)
            } label: {
                Label(
                    isRestoringExistingProfile
                        ? "Continuer"
                        : "Créer mon profil",
                    systemImage: "arrow.right"
                )
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .navigationTitle("Wander")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
    }

    private var profileStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(
                            isRestoringExistingProfile
                                ? "Retrouve ton profil"
                                : "Fais connaissance"
                        )
                            .font(.largeTitle.bold())
                            .accessibilityAddTraits(.isHeader)

                        Text(
                            isRestoringExistingProfile
                                ? "Ton pseudo a été récupéré depuis ton compte. Tu peux le vérifier avant de configurer ce téléphone."
                                : "Ton pseudo et ton avatar permettent à tes amis de te reconnaître."
                        )
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 16) {
                        ProfileAvatarView(avatarID: avatarID, size: 112)
                            .accessibilityHidden(true)

                        ProfileAvatarPicker(selection: $avatarID)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pseudo")
                            .font(.headline)

                        TextField("Comment doit-on t’appeler ?", text: $displayName)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.words)
                            .textContentType(.nickname)
                            .submitLabel(.continue)
                            .onSubmit(saveProfileAndContinue)
                            .accessibilityLabel("Pseudo")

                        Text("Obligatoire")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)

            Button(action: saveProfileAndContinue) {
                Label("Continuer", systemImage: "arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canContinue)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var locationStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                locationMessage
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }

            locationActions
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
        .navigationTitle("Localisation")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var locationMessage: some View {
        switch locationTracker.authorizationStatus {
        case .notDetermined:
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Révèle ta carte en chemin")
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)

                    Text("Wander a besoin de ta localisation pour transformer tes déplacements en zones explorées.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 18) {
                    OnboardingInformationRow(
                        iconName: "map.fill",
                        title: "Révéler la carte",
                        detail: "Ta position permet de découvrir les lieux que tu parcours."
                    )

                    OnboardingInformationRow(
                        iconName: "person.2.fill",
                        title: "Retrouver tes amis",
                        detail: "La carte affichée reste personnelle. Ta position en direct n’est envoyée à tes amis acceptés que pendant l’exploration."
                    )

                    OnboardingInformationRow(
                        iconName: "pause.circle.fill",
                        title: "Garder le contrôle",
                        detail: "Le profil permet de suspendre la collecte et l’envoi de nouvelles données. Tes zones déjà synchronisées restent liées à ton compte."
                    )
                }

                Text("Cette première autorisation s’applique quand tu utilises l’app. Wander te demandera séparément si tu souhaites poursuivre une exploration en arrière-plan. Tu peux changer d’avis dans les Réglages.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if locationTracker.lastError != nil {
                    Label(
                        "La localisation n’est pas disponible actuellement. Vérifie les réglages de l’appareil ou choisis Plus tard.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.footnote)
                    .foregroundStyle(.red)
                }
            }

        case .authorizedAlways, .authorizedWhenInUse:
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Tout est prêt")
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)

                    Text("La localisation est autorisée. Wander peut maintenant révéler les zones que tu explores.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Label(
                    locationTracker.isTracking ? "Exploration active" : "Prêt à lancer l’exploration",
                    systemImage: locationTracker.isTracking ? "location.fill" : "location"
                )
                .font(.headline)
                .foregroundStyle(locationTracker.isTracking ? .green : .secondary)
            }

        case .denied:
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "location.slash.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Localisation désactivée")
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)

                    Text("Wander ne peut pas révéler ta carte sans cet accès. Tu peux l’autoriser depuis les Réglages, ou continuer et le faire plus tard.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

        case .restricted:
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "location.slash.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Localisation indisponible")
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)

                    Text("L’accès à la localisation est restreint sur cet appareil. Tu peux continuer et l’activer plus tard si cette restriction change.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

        @unknown default:
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "location.slash.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Text("Localisation indisponible")
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)

                Text("Tu peux terminer la configuration et réessayer plus tard.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var locationActions: some View {
        switch locationTracker.authorizationStatus {
        case .notDetermined:
            VStack(spacing: 12) {
                Button {
                    locationTracker.startTracking()
                } label: {
                    Label("Activer la localisation", systemImage: "location.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: completeWithoutLocation) {
                    Text("Plus tard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

        case .authorizedAlways, .authorizedWhenInUse:
            Button(action: startExploring) {
                Label("Commencer à explorer", systemImage: "map.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

        case .denied:
            VStack(spacing: 12) {
                Button(action: openAppSettings) {
                    Label("Ouvrir les Réglages", systemImage: "gear")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: completeWithoutLocation) {
                    Text("Plus tard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

        case .restricted:
            Button(action: completeWithoutLocation) {
                Text("Continuer")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

        @unknown default:
            Button(action: completeWithoutLocation) {
                Text("Continuer")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private func saveProfileAndContinue() {
        guard canContinue else { return }
        storedDisplayName = trimmedDisplayName
        path.append(.location)
    }

    private func startExploring() {
        locationTracker.startTracking()
        completeOnboarding()
    }

    private func completeWithoutLocation() {
        locationTracker.stopTracking()
        completeOnboarding()
    }

    private func completeOnboarding() {
        guard canContinue else { return }

        storedDisplayName = trimmedDisplayName

        withAnimation(.easeInOut(duration: 0.25)) {
            onboardingCompleted = true
        }
    }

    private func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(settingsURL)
    }

    private func ensureAvatarSelection() {
        guard ProfileAvatar.normalizedID(avatarID) == nil else { return }
        avatarID = ProfileAvatar.randomID()
    }
}

private struct OnboardingInformationRow: View {
    let iconName: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}
