import AuthenticationServices
import CoreLocation
import SwiftUI
import UIKit

// MARK: - Profile

struct ProfilePanelView: View {
    @Binding var displayName: String
    @Binding var avatarID: String
    @Binding var profileColorHex: String
    @Binding var friendCodeInput: String
    @ObservedObject var locationTracker: LocationTracker
    @ObservedObject private var authenticationService = FirebaseService.shared
    @ObservedObject private var friendSyncService = FriendSyncService.shared
    @ObservedObject private var notificationService = NotificationService.shared
    @ObservedObject private var locationPushService = LocationPushService.shared
    @AppStorage("profile.onboardingCompleted") private var onboardingCompleted = false

    let summary: AnyView
    @Binding var heatMapEnabled: Bool
    let onProfileColorSelected: (String) -> Void
    var onAccountFlowStateChanged: (Bool) -> Void = { _ in }

    @State private var signOutConfirmationPresented = false
    @State private var deleteConfirmationPresented = false
    @State private var deletionAuthorizationPresented = false
    @State private var accountActionErrorMessage: String?
    @State private var isSigningOut = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    summary
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                friendSections

                Section {
                    Toggle("Carte de fréquentation", isOn: $heatMapEnabled)
                        .accessibilityIdentifier("profile-heat-map")
                } header: {
                    Text("Affichage de la carte")
                } footer: {
                    Text("Affiche les zones où tu as passé le plus de temps.")
                }

                Section("Avatar") {
                    ProfileAvatarPicker(selection: $avatarID)
                }

                Section {
                    TextField("Pseudo", text: $displayName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)

                    ColorPicker(
                        "Couleur de ma carte",
                        selection: profileColorBinding,
                        supportsOpacity: false
                    )
                } header: {
                    Text("Identité")
                } footer: {
                    Text(
                        "Cette couleur identifie ton profil et entoure ton avatar sur la carte."
                    )
                }

                Section {
                    Toggle(isOn: ghostModeBinding) {
                        Text("👻 Mode fantôme")
                    }
                    .disabled(!friendSyncService.canChangeGhostMode)
                    .accessibilityLabel("Mode fantôme")
                    .accessibilityHint(
                        "Masquer ta position à tous tes amis jusqu’à désactivation"
                    )

                    GhostModeStatusView(service: friendSyncService)
                } header: {
                    Text("Visibilité auprès de mes amis")
                } footer: {
                    Text(
                        "En mode fantôme, tes amis te voient indisponible et ne peuvent plus actualiser ta position. Ton exploration continue sur cet appareil ; les nouvelles zones seront synchronisées quand tu désactiveras ce mode."
                    )
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
                        "Quand l’exploration est active, Wander utilise ta position pour révéler la carte. Si le mode fantôme est désactivé, ta position est partagée avec tes amis. Avec le suivi en arrière-plan et l’autorisation Toujours, ils peuvent aussi l’actualiser lorsqu’ils te sélectionnent."
                    )
                }

                Section {
                    Toggle(
                        "Activité de mes amis",
                        isOn: notificationsBinding
                    )

                    Label(
                        notificationAuthorizationText,
                        systemImage: notificationAuthorizationSystemImage
                    )
                    .foregroundStyle(.secondary)

                    if notificationService.authorizationStatus == .denied {
                        Button {
                            openSettings()
                        } label: {
                            Label("Ouvrir Réglages", systemImage: "gear")
                        }
                    }

                    if let errorMessage = notificationService.errorMessage {
                        Label(
                            errorMessage,
                            systemImage: "exclamationmark.triangle"
                        )
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text(
                        "Active-les pour recevoir les demandes d’amis, les nouvelles sorties et les participations de tes amis acceptés. Wander n’affiche jamais leur adresse ni leurs coordonnées dans une notification."
                    )
                }

                accountSection
            }
            .contentMargins(.top, 0, for: .scrollContent)
            .accessibilityIdentifier("own-profile-scroll")
            .toolbar(.hidden, for: .navigationBar)
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            Task {
                await notificationService.refreshAuthorizationStatus()
            }
            if friendSyncService.isAccountDeletionPending {
                deletionAuthorizationPresented = true
            }
        }
        .onChange(of: friendSyncService.isAccountDeletionPending) {
            if friendSyncService.isAccountDeletionPending {
                deletionAuthorizationPresented = true
            }
        }
        .onChange(of: isAccountFlowActive, initial: true) { _, isActive in
            onAccountFlowStateChanged(isActive)
        }
        .onDisappear {
            onAccountFlowStateChanged(false)
        }
        .alert(
            "Se déconnecter ?",
            isPresented: $signOutConfirmationPresented
        ) {
            Button("Se déconnecter") {
                isSigningOut = true
                Task {
                    do {
                        try await notificationService.prepareForSignOut()
                        await locationPushService.prepareForSignOut()
                        if !authenticationService.signOut() {
                            await notificationService.enableNotifications()
                            locationPushService.synchronizeRegistration(
                                userID: authenticationService.currentUserId,
                                trackingEnabled: locationTracker.trackingEnabled,
                                backgroundTrackingEnabled:
                                    locationTracker.backgroundTrackingEnabled,
                                locationSharingAllowed:
                                    friendSyncService.isLocationSharingAllowed,
                                authorizationStatus:
                                    locationTracker.authorizationStatus
                            )
                            accountActionErrorMessage =
                                authenticationService.authErrorMessage
                        }
                    } catch {
                        accountActionErrorMessage = error.localizedDescription
                    }
                    isSigningOut = false
                }
            }

            Button("Annuler", role: .cancel) {}
        } message: {
            Text(
                "Tes données restent enregistrées et seront retrouvées à ta prochaine connexion."
            )
        }
        .alert(
            "Supprimer définitivement ton compte ?",
            isPresented: $deleteConfirmationPresented
        ) {
            Button("Continuer", role: .destructive) {
                deletionAuthorizationPresented = true
            }

            Button("Annuler", role: .cancel) {}
        } message: {
            Text(
                "Ton profil, ta progression, tes relations et tes données locales seront définitivement supprimés. Cette action est irréversible."
            )
        }
        .sheet(isPresented: $deletionAuthorizationPresented) {
            deletionAuthorizationSheet
        }
        .alert(
            "Impossible de terminer l’action",
            isPresented: profileActionErrorPresented
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(accountActionErrorMessage ?? friendSyncService.errorMessage
                ?? "Réessaie dans quelques instants.")
        }
    }

    private var ghostModeBinding: Binding<Bool> {
        Binding(
            get: { friendSyncService.isGhostModeEnabled },
            set: { friendSyncService.setGhostModeEnabled($0) }
        )
    }

    private var isAccountFlowActive: Bool {
        signOutConfirmationPresented || deleteConfirmationPresented
            || deletionAuthorizationPresented || isSigningOut
            || authenticationService.isDeletingAccount
            || accountActionErrorMessage != nil
    }

    private var accountSection: some View {
        Section {
            Button {
                signOutConfirmationPresented = true
            } label: {
                Label(
                    "Se déconnecter",
                    systemImage: "rectangle.portrait.and.arrow.right"
                )
            }
            .disabled(isSigningOut)

            Button(role: .destructive) {
                deleteConfirmationPresented = true
            } label: {
                Label(
                    accountDeletionButtonTitle,
                    systemImage: "person.crop.circle.badge.minus"
                )
            }
            .disabled(isSigningOut)
        } header: {
            Text("Compte")
        } footer: {
            Text(
                "La déconnexion conserve tes données. La suppression du compte efface définitivement ton profil Wander, ta progression, tes relations et les données de cet appareil."
            )
        }
    }

    private var accountDeletionButtonTitle: String {
        friendSyncService.isAccountDeletionPending
            ? "Terminer la suppression"
            : "Supprimer mon compte"
    }

    private var deletionAuthorizationSheet: some View {
        AccountDeletionAuthorizationView(
            authenticationService: authenticationService,
            deletionIsPending: friendSyncService.isAccountDeletionPending,
            errorMessage: accountActionErrorMessage,
            onCompletion: handleAccountDeletionAuthorization,
            onCancel: cancelAccountDeletionAuthorization
        )
        .interactiveDismissDisabled(
            authenticationService.isDeletingAccount
                || friendSyncService.isAccountDeletionPending
        )
    }

    // MARK: - Friend invitations

    @ViewBuilder
    private var friendSections: some View {
        Section("Ton code ami") {
            if friendSyncService.isPreparingProfile {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Création de ton code…")
                        .foregroundStyle(.secondary)
                }
            } else if let friendCode = friendSyncService.friendCode, !friendCode.isEmpty {
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
                        friendSyncService.retryProfileSetup()
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
                if friendSyncService.isProcessingFriendAction {
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
                    || !friendSyncService.isProfileReady
                    || friendSyncService.isProcessingFriendAction
            )
        }
    }

    private func shareMessage(for friendCode: String) -> String {
        "Ajoute-moi sur Wander avec le code \(friendCode)."
    }

    private func sendFriendRequest() {
        guard friendSyncService.isProfileReady,
              !friendCodeInput.isEmpty,
              !friendSyncService.isProcessingFriendAction else { return }
        let submittedCode = friendCodeInput

        friendSyncService.sendFriendRequest(code: submittedCode) { didSend in
            guard didSend else { return }

            DispatchQueue.main.async {
                if friendCodeInput == submittedCode {
                    friendCodeInput = ""
                }
            }
        }
    }

    private var profileActionErrorPresented: Binding<Bool> {
        Binding(
            get: { accountActionErrorMessage != nil || friendSyncService.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    if accountActionErrorMessage != nil {
                        accountActionErrorMessage = nil
                    } else if friendSyncService.errorMessage != nil {
                        friendSyncService.clearError()
                    }
                }
            }
        )
    }

    private func cancelAccountDeletionAuthorization() {
        authenticationService.cancelAccountDeletion()
        deletionAuthorizationPresented = false
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

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { notificationService.isEnabled },
            set: { isEnabled in
                notificationService.clearError()
                Task {
                    if isEnabled {
                        await notificationService.enableNotifications()
                    } else {
                        await notificationService.disableNotifications()
                    }
                }
            }
        )
    }

    private var notificationAuthorizationText: String {
        switch notificationService.authorizationStatus {
        case .notDetermined:
            "Autorisation non demandée"
        case .denied:
            "Notifications refusées dans Réglages"
        case .authorized:
            "Notifications autorisées"
        case .provisional:
            "Notifications autorisées provisoirement"
        case .ephemeral:
            "Notifications autorisées temporairement"
        @unknown default:
            "État des notifications indisponible"
        }
    }

    private var notificationAuthorizationSystemImage: String {
        notificationService.authorizationAllowsNotifications
            ? "bell.badge"
            : "bell.slash"
    }

    private func handleAccountDeletionAuthorization(
        _ result: Result<ASAuthorization, Error>
    ) {
        let authenticationService = authenticationService
        let friendSyncService = friendSyncService
        let locationTracker = locationTracker

        Task {
            do {
                guard let authorizationCode = try await authenticationService
                    .reauthenticateForAccountDeletion(result) else {
                    if friendSyncService.isAccountDeletionPending {
                        accountActionErrorMessage =
                            "La vérification Apple est nécessaire pour terminer la suppression."
                    } else {
                        deletionAuthorizationPresented = false
                    }
                    return
                }

                try await notificationService.prepareForAccountDeletion()
                await locationPushService.prepareForAccountDeletion()
                try await friendSyncService.deleteCurrentAccountData()
                try await authenticationService.finishAccountDeletion(
                    authorizationCode: authorizationCode
                )

                var localCleanupError: Error?
                do {
                    try locationTracker.resetLocalData()
                } catch {
                    localCleanupError = error
                }

                clearLocalProfileData()

                do {
                    try await friendSyncService.clearLocalFirestoreCache()
                } catch {
                    localCleanupError = localCleanupError ?? error
                }

                if let localCleanupError {
                    print(
                        "[Profile] account deleted but local cleanup failed: "
                            + localCleanupError.localizedDescription
                    )
                }
            } catch {
                authenticationService.cancelAccountDeletion()
                if let authenticationError =
                    error as? FirebaseService.AccountDeletionError {
                    accountActionErrorMessage =
                        authenticationError.errorDescription
                } else {
                    accountActionErrorMessage =
                        friendSyncService.accountDeletionMessage(for: error)
                }
            }
        }
    }

    private func clearLocalProfileData() {
        displayName = ""
        avatarID = ""
        profileColorHex = ""

        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: ProfileAvatar.storageKey)
        defaults.removeObject(forKey: ProfileAvatar.ownerStorageKey)
        defaults.removeObject(forKey: ProfileColor.storageKey)
        defaults.removeObject(forKey: ProfileColor.ownerStorageKey)
        defaults.removeObject(forKey: ProfileColor.pendingOwnerStorageKey)
        defaults.removeObject(
            forKey: ProfileColor.pendingUserSelectionStorageKey
        )
        onboardingCompleted = false

        defaults.removeObject(forKey: "profile.displayName")
        defaults.removeObject(forKey: "profile.avatarImageData")
        defaults.removeObject(forKey: "profile.onboardingCompleted")
    }

    private func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }

    private var profileColorBinding: Binding<Color> {
        Binding(
            get: {
                ProfileColor.color(hex: profileColorHex)
            },
            set: { newColor in
                let selectedColorHex = ProfileColor.hex(from: newColor)
                profileColorHex = selectedColorHex
                onProfileColorSelected(selectedColorHex)
            }
        )
    }
}

private struct AccountDeletionAuthorizationView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var authenticationService: FirebaseService

    let deletionIsPending: Bool
    let errorMessage: String?
    let onCompletion: (Result<ASAuthorization, Error>) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "person.crop.circle.badge.minus")
                        .font(.system(size: 48))
                        .foregroundStyle(.red)
                        .accessibilityHidden(true)

                    VStack(spacing: 8) {
                        Text(
                            deletionIsPending
                                ? "Terminer la suppression"
                                : "Confirmer avec Apple"
                        )
                        .font(.title2.bold())

                        Text(
                            deletionIsPending
                                ? "La suppression a déjà commencé. Identifie-toi de nouveau pour effacer les données restantes."
                                : "Wander doit vérifier ton identité avant de supprimer définitivement ton compte."
                        )
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    }

                    if authenticationService.isDeletingAccount {
                        ProgressView("Suppression du compte…")
                    } else {
                        SignInWithAppleButton(
                            .continue,
                            onRequest: authenticationService
                                .prepareAccountDeletionAuthorizationRequest,
                            onCompletion: onCompletion
                        )
                        .signInWithAppleButtonStyle(
                            colorScheme == .dark ? .white : .black
                        )
                        .frame(height: 50)
                        .accessibilityLabel(
                            "Confirmer la suppression avec Apple"
                        )
                    }

                    if let errorMessage {
                        Label(
                            errorMessage,
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .navigationTitle("Suppression du compte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !deletionIsPending
                    && !authenticationService.isDeletingAccount {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annuler", action: onCancel)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
