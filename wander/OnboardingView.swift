//
//  OnboardingView.swift
//  wander
//
//  Created by Codex on 18/06/2026.
//

import CoreLocation
import MapKit
import PhotosUI
import SwiftUI
import UIKit

struct OnboardingView: View {
    let isRestoringExistingProfile: Bool

    @AppStorage("profile.displayName") private var storedDisplayName = ""
    @AppStorage("profile.avatarImageData") private var avatarImageData = Data()
    @AppStorage("profile.onboardingCompleted") private var onboardingCompleted = false

    @Environment(\.openURL) private var openURL
    @StateObject private var locationTracker = LocationTracker()

    @State private var path: [Destination] = []
    @State private var displayName = ""
    @State private var selectedPhoto: PhotosPickerItem?

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
        }
        .onChange(of: selectedPhoto) { _, newPhoto in
            loadAvatar(from: newPhoto)
        }
    }

    private var discoveryStep: some View {
        VStack(spacing: 0) {
            OnboardingProgressView(step: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Map(
                        initialPosition: previewMapPosition,
                        interactionModes: []
                    ) {
                        MapCircle(center: previewCoordinate, radius: 480)
                            .foregroundStyle(Color.accentColor.opacity(0.16))
                            .stroke(Color.accentColor, lineWidth: 2)

                        Annotation("Zone explorée", coordinate: previewCoordinate) {
                            Image(systemName: "figure.walk.circle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.tint)
                                .padding(8)
                                .background(.regularMaterial, in: Circle())
                        }
                    }
                    .mapStyle(.standard)
                    .frame(minHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Aperçu d’une carte qui se révèle autour d’un trajet")

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Redécouvre les lieux que tu traverses")
                            .font(.largeTitle.bold())
                            .accessibilityAddTraits(.isHeader)

                        Text("Chaque trajet dévoile peu à peu ta carte. Marche, roule ou voyage, puis retrouve tout ce que tu as exploré.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Label("Suis ta progression quartier par quartier", systemImage: "map.fill")
                        Label("Retrouve tes amis en direct", systemImage: "person.2.fill")
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
            OnboardingProgressView(step: 2)

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
                                : "Ton pseudo et ta photo permettent à tes amis de te reconnaître sur la carte."
                        )
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 16) {
                        ProfileAvatarView(imageData: avatarImageData, size: 112)
                            .accessibilityHidden(true)

                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label(
                                avatarImageData.isEmpty ? "Ajouter une photo" : "Changer la photo",
                                systemImage: "photo"
                            )
                        }
                        .buttonStyle(.bordered)
                        .accessibilityHint("Ouvre la photothèque")

                        Text("La photo est facultative.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
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
            OnboardingProgressView(step: 3)

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
                        title: "Explorer entre amis",
                        detail: "Tes nouvelles zones explorées sont partagées avec tes amis acceptés. Ta position en direct n’est envoyée que pendant l’exploration."
                    )

                    OnboardingInformationRow(
                        iconName: "pause.circle.fill",
                        title: "Garder le contrôle",
                        detail: "Le profil permet de suspendre la collecte et l’envoi de nouvelles données. Les zones déjà partagées restent visibles par tes amis acceptés."
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

    private var previewCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)
    }

    private var previewMapPosition: MapCameraPosition {
        .region(
            MKCoordinateRegion(
                center: previewCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
            )
        )
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

    private func loadAvatar(from item: PhotosPickerItem?) {
        guard let item else { return }

        Task {
            guard
                let data = try? await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data),
                let jpegData = image.preparingThumbnail(of: CGSize(width: 360, height: 360))?.jpegData(compressionQuality: 0.82)
            else { return }

            await MainActor.run {
                avatarImageData = jpegData
            }
        }
    }
}

private struct OnboardingProgressView: View {
    let step: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Étape \(step) sur 3")
                .font(.caption)
                .foregroundStyle(.secondary)

            ProgressView(value: Double(step), total: 3)
                .accessibilityLabel("Progression de la configuration")
                .accessibilityValue("Étape \(step) sur 3")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
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

struct ProfileAvatarView: View {
    let imageData: Data
    let size: CGFloat

    var body: some View {
        Group {
            if let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
                    .padding(size * 0.1)
            }
        }
        .frame(width: size, height: size)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(Circle())
        .contentShape(Circle())
    }
}
