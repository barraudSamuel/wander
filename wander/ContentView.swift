//
//  ContentView.swift
//  wander
//
//  Map-first experience with native Apple navigation and controls.
//

import CoreLocation
import MapKit
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

private enum RootTab: Hashable {
    case explore
    case friends
    case profile
}

private struct FriendMapSummary: Identifiable, Hashable {
    let userID: String
    let displayName: String
    let hasLiveLocation: Bool

    var id: String { userID }
}

struct ContentView: View {
    @StateObject private var locationTracker = LocationTracker()
    @StateObject private var friendSyncService = FriendSyncService.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @AppStorage("profile.displayName") private var displayName = ""
    @AppStorage("profile.avatarImageData") private var avatarImageData = Data()

    @ObservedObject private var cityBoundary = CityBoundary.shared

    @State private var selectedTab: RootTab = .explore
    @State private var filterSheetVisible = false
    @State private var centerOnUser = false
    @State private var resetMapOrientation = false
    @State private var centerOnFriendUserID: String?
    @State private var heatMapEnabled = false

    #if DEBUG
    @State private var debugDrawerVisible = false
    @State private var drawerExpanded = false
    #endif

    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $selectedTab) {
                exploreTab
                    .tabItem {
                        Label("Explorer", systemImage: "map")
                    }
                    .tag(RootTab.explore)

                FriendsView(
                    service: friendSyncService,
                    friends: friendSummaries,
                    onShowOnMap: showFriendOnMap
                )
                .tabItem {
                    Label("Amis", systemImage: "person.2")
                }
                .tag(RootTab.friends)

                ProfileView(
                    displayName: $displayName,
                    avatarImageData: $avatarImageData,
                    locationTracker: locationTracker,
                    cityProgress: cityProgress,
                    cityProgressUnavailableText: cityProgressUnavailableText,
                    onStopSharingLocation: friendSyncService.stopSharingLocation
                )
                .tabItem {
                    Label("Profil", systemImage: "person.crop.circle")
                }
                .tag(RootTab.profile)
            }
            #if DEBUG
            .overlay(alignment: .bottom) {
                if debugDrawerVisible {
                    DebugDrawerView(
                        locationTracker: locationTracker,
                        isExpanded: $drawerExpanded,
                        cityProgress: cityProgress,
                        parentGeometry: geometry
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .overlay {
                ThreeFingerPressCatcher {
                    toggleDebugDrawerVisibility()
                }
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
            }
            #endif
        }
        .onAppear {
            locationTracker.configure(with: modelContext)
            locationTracker.resumeTrackingIfNeeded()
            friendSyncService.updateDisplayName(displayName)

            Task {
                await cityBoundary.load()
                if let location = locationTracker.lastLocation {
                    cityBoundary.detectCity(for: location.coordinate)
                }
            }
        }
        .onChange(of: locationTracker.lastLocation) { _, location in
            guard let location else { return }

            cityBoundary.detectCity(for: location.coordinate)
            guard locationTracker.trackingEnabled else { return }

            friendSyncService.updateLocation(
                location,
                displayName: displayName.isEmpty ? "Explorer" : displayName
            )
        }
        .onChange(of: locationTracker.trackingEnabled, initial: true) { _, isEnabled in
            if !isEnabled {
                friendSyncService.stopSharingLocation()
            }
        }
        .onChange(of: displayName) { _, newDisplayName in
            friendSyncService.updateDisplayName(newDisplayName)
        }
        .onChange(of: friendSyncService.isProfileReady) { _, isReady in
            guard isReady else { return }

            friendSyncService.updateDisplayName(displayName)
            if !locationTracker.trackingEnabled {
                friendSyncService.stopSharingLocation()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                locationTracker.resumeTrackingIfNeeded()
            case .background:
                if locationTracker.trackingEnabled {
                    locationTracker.applyTrackingMode(.background)
                }
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }

    // MARK: - Explore

    private var exploreTab: some View {
        ZStack(alignment: .topTrailing) {
            MapWithFogView(
                locationTracker: locationTracker,
                discoveredCellIDs: Set(locationTracker.discoveredCells.map(\.id)),
                cityBoundaryCoordinates: cityBoundary.boundaryCoordinates,
                friendLocations: friendSyncService.friendLocations,
                userDisplayName: displayName,
                userAvatarImageData: avatarImageData,
                centerOnUser: $centerOnUser,
                resetMapOrientation: $resetMapOrientation,
                centerOnFriendUserID: $centerOnFriendUserID,
                showsHeatMap: heatMapEnabled,
                heatMapCellData: locationTracker.heatMapCellData
            )
            .ignoresSafeArea()

            Button {
                filterSheetVisible = true
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .accessibilityLabel("Filtres de la carte")
            .accessibilityHint("Choisir les informations visibles sur la carte")
            .padding(.top, 8)
            .padding(.trailing, 16)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack {
                Spacer()

                VStack(spacing: 10) {
                    Button {
                        resetMapOrientation = true
                    } label: {
                        Image(systemName: "safari")
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)
                    .accessibilityLabel("Orienter la carte vers le nord")

                    Button {
                        centerOnUser = true
                    } label: {
                        Image(systemName: "scope")
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)
                    .accessibilityLabel("Recentrer la carte sur ma position")
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $filterSheetVisible) {
            MapFiltersSheet(
                heatMapEnabled: $heatMapEnabled
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Friends

    private var friendSummaries: [FriendMapSummary] {
        friendSyncService.acceptedFriends
            .map { friend in
                let location = friendSyncService.friendLocations[friend.userID]

                return FriendMapSummary(
                    userID: friend.userID,
                    displayName: location?.displayName ?? friend.displayName,
                    hasLiveLocation: location != nil
                )
            }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
    }

    private func showFriendOnMap(_ friend: FriendMapSummary) {
        guard friend.hasLiveLocation else { return }
        centerOnFriendUserID = friend.userID
        selectedTab = .explore
    }

    // MARK: - City progress

    private var cityProgress: CityProgress? {
        cityBoundary.progress(against: locationTracker.discoveredCells)
    }

    private var cityProgressUnavailableText: String {
        guard locationTracker.lastLocation != nil else {
            return "Active l’exploration pour révéler la carte."
        }

        guard !cityBoundary.cityCellIDs.isEmpty else {
            return "Préparation de la ville…"
        }

        return "Cette ville n’est pas encore disponible."
    }

    #if DEBUG
    private func toggleDebugDrawerVisibility() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            debugDrawerVisible.toggle()

            if !debugDrawerVisible {
                drawerExpanded = false
            }
        }
    }
    #endif
}

// MARK: - Friends

private struct FriendsView: View {
    @ObservedObject var service: FriendSyncService
    let friends: [FriendMapSummary]
    let onShowOnMap: (FriendMapSummary) -> Void

    @State private var friendCodeInput = ""
    @State private var processingRequestID: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Ton code ami") {
                    if service.isPreparingProfile {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Création de ton code…")
                                .foregroundStyle(.secondary)
                        }
                    } else if let friendCode = service.friendCode, !friendCode.isEmpty {
                        HStack {
                            Text(friendCode)
                                .font(.title3.weight(.semibold))
                                .monospaced()
                                .textSelection(.enabled)

                            Spacer()

                            Button {
                                UIPasteboard.general.string = friendCode
                            } label: {
                                Label("Copier", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.borderless)
                        }

                        ShareLink(item: shareMessage(for: friendCode)) {
                            Label("Partager mon code", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(
                                "Code indisponible",
                                systemImage: "exclamationmark.circle"
                            )
                            .foregroundStyle(.secondary)

                            Button("Réessayer") {
                                service.retryProfileSetup()
                            }
                        }
                    }
                }

                Section("Ajouter un ami") {
                    TextField("Code ami", text: $friendCodeInput)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .submitLabel(.send)
                        .onSubmit(sendFriendRequest)

                    Button(action: sendFriendRequest) {
                        if service.isProcessingFriendAction
                            && processingRequestID == nil {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Ajouter un ami", systemImage: "person.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        friendCodeInput.isEmpty
                            || !service.isProfileReady
                            || service.isProcessingFriendAction
                    )
                }

                if !service.incomingRequests.isEmpty {
                    Section("Demandes reçues") {
                        ForEach(service.incomingRequests) { request in
                            VStack(alignment: .leading, spacing: 10) {
                                Label(request.displayName, systemImage: "person.crop.circle")

                                if processingRequestID == request.id {
                                    HStack(spacing: 10) {
                                        ProgressView()
                                        Text("Mise à jour…")
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    HStack {
                                        Button("Accepter") {
                                            process(request, accepting: true)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .disabled(service.isProcessingFriendAction)

                                        Button("Refuser", role: .destructive) {
                                            process(request, accepting: false)
                                        }
                                        .buttonStyle(.bordered)
                                        .disabled(service.isProcessingFriendAction)
                                    }
                                }
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }

                Section("Mes amis") {
                    if friends.isEmpty {
                        Text("Aucun ami pour le moment.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(friends) { friend in
                            HStack {
                                FriendRow(friend: friend)

                                Spacer()

                                if friend.hasLiveLocation {
                                    Button {
                                        onShowOnMap(friend)
                                    } label: {
                                        Image(systemName: "map")
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel(
                                        "Afficher \(friend.displayName) sur la carte"
                                    )
                                }
                            }
                        }
                    }
                }

                if !service.outgoingRequests.isEmpty {
                    Section("En attente") {
                        ForEach(service.outgoingRequests) { request in
                            HStack {
                                Text(request.displayName)
                                Spacer()
                                Text("Demande envoyée")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Amis")
            .alert(
                "Impossible de terminer l’action",
                isPresented: errorIsPresented
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(service.errorMessage ?? "Réessaie dans quelques instants.")
            }
            .onChange(of: service.isProcessingFriendAction) { _, isProcessing in
                if !isProcessing {
                    processingRequestID = nil
                }
            }
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: {
                service.errorMessage != nil
            },
            set: { isPresented in
                if !isPresented {
                    service.clearError()
                }
            }
        )
    }

    private func shareMessage(for friendCode: String) -> String {
        "Ajoute-moi sur Wander avec le code \(friendCode)."
    }

    private func sendFriendRequest() {
        guard service.isProfileReady,
              !friendCodeInput.isEmpty,
              !service.isProcessingFriendAction else { return }
        let submittedCode = friendCodeInput

        service.sendFriendRequest(code: submittedCode) { didSend in
            guard didSend else { return }

            DispatchQueue.main.async {
                if friendCodeInput == submittedCode {
                    friendCodeInput = ""
                }
            }
        }
    }

    private func process(_ request: FriendRequest, accepting: Bool) {
        processingRequestID = request.id

        if accepting {
            service.accept(request)
        } else {
            service.decline(request)
        }

        if !service.isProcessingFriendAction {
            processingRequestID = nil
        }
    }
}

private struct FriendRow: View {
    let friend: FriendMapSummary

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(friend.displayName)
                    .font(.body.weight(.medium))

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var statusText: String {
        friend.hasLiveLocation ? "En direct" : "Position indisponible"
    }
}

// MARK: - Profile

private struct ProfileView: View {
    @Binding var displayName: String
    @Binding var avatarImageData: Data
    @ObservedObject var locationTracker: LocationTracker
    @AppStorage("profile.onboardingCompleted") private var onboardingCompleted = false

    let cityProgress: CityProgress?
    let cityProgressUnavailableText: String
    let onStopSharingLocation: () -> Void

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var resetConfirmationPresented = false
    @State private var resetFailed = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        ProfileAvatarView(imageData: avatarImageData, size: 72)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayName.isEmpty ? "Explorer" : displayName)
                                .font(.title2.bold())

                            Label(
                                locationTracker.isTracking ? "Exploration active" : "Exploration en pause",
                                systemImage: locationTracker.isTracking ? "location.fill" : "pause.circle"
                            )
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Choisir une photo", systemImage: "photo")
                    }
                }

                Section("Identité") {
                    TextField("Pseudo", text: $displayName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                }

                Section {
                    Toggle("Enregistrer mes déplacements", isOn: trackingBinding)

                    if locationTracker.authorizationStatus == .authorizedWhenInUse
                        || locationTracker.authorizationStatus == .authorizedAlways {
                        Toggle(
                            "Continuer en arrière-plan",
                            isOn: backgroundTrackingBinding
                        )
                    }

                    if locationTracker.authorizationStatus == .denied
                        || locationTracker.authorizationStatus == .restricted {
                        Label(
                            "Autorise la localisation dans Réglages pour reprendre l’exploration.",
                            systemImage: "location.slash"
                        )
                        .foregroundStyle(.secondary)

                        Button {
                            openSettings()
                        } label: {
                            Label("Ouvrir Réglages", systemImage: "gear")
                        }
                    } else if let lastError = locationTracker.lastError {
                        Label(lastError, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Localisation")
                } footer: {
                    Text(
                        "Quand l’exploration est active, Wander utilise ta position pour révéler la carte et alimenter les fonctions entre amis. Le suivi en arrière-plan reste optionnel."
                    )
                }

                Section("Progression") {
                    LabeledContent(
                        "Ville",
                        value: cityProgress?.cityName ?? cityProgressUnavailableText
                    )

                    LabeledContent(
                        "Progression",
                        value: cityProgress?.percentageText ?? "—"
                    )

                    LabeledContent("Zones explorées") {
                        Text(exploredCellsText)
                            .monospacedDigit()
                    }
                }

                Section {
                    Button(role: .destructive) {
                        resetConfirmationPresented = true
                    } label: {
                        Label("Effacer mes données locales", systemImage: "trash")
                    }
                } footer: {
                    Text(
                        "Supprime le profil, les préférences et la progression enregistrés sur cet appareil, puis relance l’onboarding. Le compte Firebase et les relations d’amitié ne sont pas effacés."
                    )
                }
            }
            .navigationTitle("Profil")
        }
        .onChange(of: selectedPhoto) { _, newPhoto in
            loadAvatar(from: newPhoto)
        }
        .confirmationDialog(
            "Effacer les données locales ?",
            isPresented: $resetConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Effacer et recommencer", role: .destructive) {
                resetLocalData()
            }

            Button("Annuler", role: .cancel) {}
        } message: {
            Text(
                "Cette action est irréversible sur cet appareil. Tu seras redirigé vers l’onboarding."
            )
        }
        .alert("Impossible d’effacer les données", isPresented: $resetFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Réessaie dans quelques instants.")
        }
    }

    private var trackingBinding: Binding<Bool> {
        Binding(
            get: {
                locationTracker.trackingEnabled
            },
            set: { isEnabled in
                if isEnabled {
                    locationTracker.startTracking()
                } else {
                    locationTracker.stopTracking()
                }
            }
        )
    }

    private var backgroundTrackingBinding: Binding<Bool> {
        Binding(
            get: {
                locationTracker.backgroundTrackingEnabled
            },
            set: { isEnabled in
                locationTracker.setBackgroundTrackingEnabled(isEnabled)
            }
        )
    }

    private var exploredCellsText: String {
        guard let cityProgress else { return "—" }
        return "\(cityProgress.exploredCells) / \(cityProgress.totalCells)"
    }

    private func loadAvatar(from item: PhotosPickerItem?) {
        guard let item else { return }

        Task {
            guard
                let data = try? await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data),
                let jpegData = image
                    .preparingThumbnail(of: CGSize(width: 360, height: 360))?
                    .jpegData(compressionQuality: 0.82)
            else {
                return
            }

            await MainActor.run {
                avatarImageData = jpegData
            }
        }
    }

    private func resetLocalData() {
        do {
            onStopSharingLocation()
            try locationTracker.resetLocalData()
            selectedPhoto = nil
            displayName = ""
            avatarImageData = Data()

            withAnimation(.easeInOut(duration: 0.25)) {
                onboardingCompleted = false
            }
        } catch {
            resetFailed = true
            print("[Profile] failed to reset local data: \(error.localizedDescription)")
        }
    }

    private func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }
}

// MARK: - Map filters

private struct MapFiltersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var heatMapEnabled: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Carte de fréquentation", isOn: $heatMapEnabled)
                } header: {
                    Text("Exploration")
                } footer: {
                    Text("Affiche les zones où tu as passé le plus de temps.")
                }
            }
            .navigationTitle("Affichage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminé") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#if DEBUG
private struct ThreeFingerPressCatcher: UIViewRepresentable {
    var onPress: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPress: onPress)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false

        DispatchQueue.main.async {
            context.coordinator.attach(to: view.window)
        }

        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.onPress = onPress

        DispatchQueue.main.async {
            context.coordinator.attach(to: view.window)
        }
    }

    static func dismantleUIView(_ view: UIView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onPress: () -> Void

        private weak var attachedView: UIView?
        private weak var gestureRecognizer: UILongPressGestureRecognizer?

        init(onPress: @escaping () -> Void) {
            self.onPress = onPress
        }

        func attach(to view: UIView?) {
            guard let view, attachedView !== view else { return }

            detach()

            let gestureRecognizer = UILongPressGestureRecognizer(
                target: self,
                action: #selector(handlePress(_:))
            )
            gestureRecognizer.numberOfTouchesRequired = 3
            gestureRecognizer.minimumPressDuration = 0.25
            gestureRecognizer.cancelsTouchesInView = false
            gestureRecognizer.delaysTouchesBegan = false
            gestureRecognizer.delaysTouchesEnded = false
            gestureRecognizer.delegate = self

            view.addGestureRecognizer(gestureRecognizer)
            attachedView = view
            self.gestureRecognizer = gestureRecognizer
        }

        func detach() {
            if let gestureRecognizer, let attachedView {
                attachedView.removeGestureRecognizer(gestureRecognizer)
            }

            attachedView = nil
            gestureRecognizer = nil
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        @objc private func handlePress(_ gestureRecognizer: UILongPressGestureRecognizer) {
            guard gestureRecognizer.state == .began else { return }
            onPress()
        }
    }
}
#endif

#Preview {
    ContentView()
}
