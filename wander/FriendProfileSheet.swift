//
//  FriendProfileSheet.swift
//  wander
//
//  Friend profile and shared avatar presentation.
//

import SwiftUI

struct FriendAvatarBadge: View {
    private let avatarID: String
    private let profileColorHex: String
    private let size: CGFloat

    init(avatarID: String, profileColorHex: String, size: CGFloat) {
        self.avatarID = avatarID
        self.profileColorHex = profileColorHex
        self.size = size
    }

    var body: some View {
        ProfileAvatarView(avatarID: avatarID, size: size)
            .overlay {
                Circle()
                    .stroke(
                        ProfileColor.color(hex: profileColorHex),
                        lineWidth: max(2, size * 0.055)
                    )
            }
    }
}

struct FriendProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var service: FriendSyncService
    @State private var opensDirectionsAfterDismiss = false

    private let userID: String
    private let onOpenDirections: () -> Void

    init(
        userID: String,
        service: FriendSyncService,
        onOpenDirections: @escaping () -> Void
    ) {
        self.userID = userID
        self.service = service
        self.onOpenDirections = onOpenDirections
    }

    var body: some View {
        let renderedProfile = profile
        return NavigationStack {
            Form {
                FriendProfileFields(
                    displayName: renderedProfile.displayName,
                    avatarID: renderedProfile.avatarID,
                    profileColorHex: renderedProfile.profileColorHex,
                    isGhostModeEnabled: renderedProfile.isGhostModeEnabled,
                    location: renderedProfile.location,
                    isLocationFresh: renderedProfile.isLocationFresh,
                    onOpenDirections: {
                        guard self.profile.canOpenDirections else { return }
                        opensDirectionsAfterDismiss = true
                        dismiss()
                    }
                )
            }
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: renderedProfile.isFriendAccepted, initial: true) { _, isAccepted in
            if !isAccepted {
                dismiss()
            }
        }
        .onChange(of: renderedProfile.canOpenDirections) { _, canOpenDirections in
            if !canOpenDirections {
                opensDirectionsAfterDismiss = false
            }
        }
        .onDisappear {
            guard opensDirectionsAfterDismiss else { return }
            opensDirectionsAfterDismiss = false
            Task { @MainActor in
                await Task.yield()
                guard self.profile.canOpenDirections else { return }
                onOpenDirections()
            }
        }
    }

    private var profile: FriendProfileData {
        FriendProfileData(userID: userID, service: service)
    }
}

struct FriendProfilePanel: View {
    @ObservedObject private var service: FriendSyncService

    private let userID: String
    private let onDismiss: () -> Void
    private let onOpenDirections: () -> Void

    init(
        userID: String,
        service: FriendSyncService,
        onDismiss: @escaping () -> Void,
        onOpenDirections: @escaping () -> Void
    ) {
        self.userID = userID
        self.service = service
        self.onDismiss = onDismiss
        self.onOpenDirections = onOpenDirections
    }

    var body: some View {
        let renderedProfile = profile
        return FriendProfileContentView(
            displayName: renderedProfile.displayName,
            avatarID: renderedProfile.avatarID,
            profileColorHex: renderedProfile.profileColorHex,
            isGhostModeEnabled: renderedProfile.isGhostModeEnabled,
            location: renderedProfile.location,
            isLocationFresh: renderedProfile.isLocationFresh,
            onDismiss: onDismiss,
            onOpenDirections: {
                guard self.profile.canOpenDirections else { return }
                onOpenDirections()
            }
        )
        .onChange(of: renderedProfile.isFriendAccepted, initial: true) { _, isAccepted in
            if !isAccepted {
                onDismiss()
            }
        }
    }

    private var profile: FriendProfileData {
        FriendProfileData(userID: userID, service: service)
    }
}

struct FriendProfileContentView: View {
    let displayName: String
    let avatarID: String
    let profileColorHex: String
    let isGhostModeEnabled: Bool
    let location: FriendLocation?
    let isLocationFresh: Bool
    let onDismiss: () -> Void
    let onOpenDirections: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    fields.identity
                    Divider()
                    Text("Position")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    fields.locationDetails
                    fields.directionsButton
                    fields.locationFooter
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
            .accessibilityIdentifier("friend-profile-scroll")
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Profil")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Fermer la fiche de l’ami")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var fields: FriendProfileFields {
        FriendProfileFields(
            displayName: displayName,
            avatarID: avatarID,
            profileColorHex: profileColorHex,
            isGhostModeEnabled: isGhostModeEnabled,
            location: location,
            isLocationFresh: isLocationFresh,
            onOpenDirections: onOpenDirections
        )
    }
}

// MARK: - Shared profile content

private struct FriendProfileFields: View {
    let displayName: String
    let avatarID: String
    let profileColorHex: String
    let isGhostModeEnabled: Bool
    let location: FriendLocation?
    let isLocationFresh: Bool
    let onOpenDirections: () -> Void

    var body: some View {
        Section {
            identity
                .padding(.vertical, 8)
        }

        Section {
            locationDetails
            directionsButton
        } header: {
            Text("Position")
        } footer: {
            locationFooter
        }
    }

    var identity: some View {
        FriendProfileIdentityView(
            displayName: displayName,
            avatarID: avatarID,
            profileColorHex: profileColorHex,
            isGhostModeEnabled: isGhostModeEnabled
        )
    }

    @ViewBuilder
    var locationDetails: some View {
        if isGhostModeEnabled {
            Text("Cet ami a activé le mode fantôme.")
                .foregroundStyle(.secondary)
        } else if let location {
            LabeledContent(
                isLocationFresh
                    ? "Dernière mise à jour"
                    : "Dernière position reçue"
            ) {
                Text(location.sampledAt, style: .relative)
            }

            LabeledContent("Date") {
                Text(
                    location.sampledAt.formatted(
                        date: .abbreviated,
                        time: .shortened
                    )
                )
            }

            if isLocationFresh, let spotEnteredAt = location.spotEnteredAt {
                LabeledContent("Au même endroit depuis") {
                    Text(spotEnteredAt, style: .relative)
                }
            } else if !isLocationFresh {
                Label(
                    "Position non actualisée récemment",
                    systemImage: "clock"
                )
                .foregroundStyle(.secondary)
            }
        } else {
            Text("Position indisponible")
                .foregroundStyle(.secondary)
        }
    }

    var directionsButton: some View {
        Button {
            guard !isGhostModeEnabled, location != nil else { return }
            onOpenDirections()
        } label: {
            Label("Itinéraire", systemImage: "map")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(isGhostModeEnabled || location == nil)
        .accessibilityHint("Choisir une application pour rejoindre cet ami")
    }

    var locationFooter: some View {
        Text(
            isGhostModeEnabled
                ? "Sa position est masquée. L’itinéraire et l’actualisation sont indisponibles jusqu’à son retour."
                : "L’action Itinéraire utilise la dernière position connue, même si elle n’a pas été actualisée récemment."
        )
    }
}

private struct FriendProfileIdentityView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let displayName: String
    let avatarID: String
    let profileColorHex: String
    let isGhostModeEnabled: Bool

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 16))

        return layout {
            FriendAvatarBadge(
                avatarID: avatarID,
                profileColorHex: profileColorHex,
                size: 64
            )
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                if isGhostModeEnabled {
                    Text("👻 Indisponible")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Indisponible, mode fantôme activé")
                } else {
                    Label("Ami", systemImage: "person.2.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct FriendProfileData {
    let friend: FriendContact?
    let location: FriendLocation?
    let isGhostModeEnabled: Bool
    let isLocationFresh: Bool
    let profileColorHex: String

    init(userID: String, service: FriendSyncService) {
        friend = service.acceptedFriends.first { $0.userID == userID }
        isGhostModeEnabled = friend?.isGhostModeEnabled == true
            || service.ghostFriendUserIDs.contains(userID)
        location = isGhostModeEnabled ? nil : service.friendLocation(for: userID)
        isLocationFresh = service.freshFriendLocationUserIDs.contains(userID)
        profileColorHex = ProfileColor.normalizedHex(
            location?.profileColorHex ?? friend?.profileColorHex ?? ""
        ) ?? ProfileColor.generatedHex(seed: userID)
    }

    var isFriendAccepted: Bool {
        friend != nil
    }

    var canOpenDirections: Bool {
        isFriendAccepted && !isGhostModeEnabled && location != nil
    }

    var displayName: String {
        location?.displayName ?? friend?.displayName ?? "Ami"
    }

    var avatarID: String {
        friend?.avatarID ?? ""
    }
}
