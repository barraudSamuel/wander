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
        TimelineView(.animation(minimumInterval: 1, paused: isGhostModeEnabled || location == nil)) { context in
            MapDetailPanel(
                title: displayName,
                closeLabel: "Fermer la fiche de l’ami",
                scrollIdentifier: "friend-profile-scroll",
                narrativeIdentifier: "friend-profile-narrative",
                content: narrative(relativeTo: context.date),
                onDismiss: onDismiss
            ) {
                if location != nil || isGhostModeEnabled {
                    fields.locationFooter
                }
            } actions: {
                fields.directionsButton
                    .labelStyle(.iconOnly)
                    .fixedSize(horizontal: true, vertical: false)
                    .accessibilityLabel("Itinéraire")
            }
        }
    }

    private func narrative(relativeTo now: Date) -> MapDetailTextContent {
        var fragments: [MapDetailTextContent.Fragment] = [
            .avatars([avatarID]), .text(" "), .emphasis(displayName), .text(".\n")
        ]
        var status: String
        if isGhostModeEnabled {
            fragments += [.text("👻 Mode fantôme activé. "), .emphasis("Indisponible"), .text(".")]
            status = "Mode fantôme activé. Indisponible."
        } else if let location {
            let updated = duration(since: location.sampledAt, now: now)
            let date = location.sampledAt.formatted(.dateTime.day().month(.abbreviated).hour().minute())
            let freshness = isLocationFresh ? "Position actualisée" : "Dernière position reçue"
            fragments += [
                .text("📍 \(freshness) il y a "), .emphasis(updated),
                .text(", le 📅 "), .emphasis(date), .text(".")
            ]
            status = "\(freshness) il y a \(updated), le \(date)."
            if isLocationFresh, let spotEnteredAt = location.spotEnteredAt {
                let presenceDuration = duration(since: spotEnteredAt, now: now)
                fragments += [.text(" Au même endroit depuis "), .emphasis(presenceDuration), .text(".")]
                status += " Au même endroit depuis \(presenceDuration)."
            } else if !isLocationFresh {
                let stale = " Position non actualisée récemment."
                fragments += [.text(stale)]
                status += stale
            }
        } else {
            fragments += [.text("📍 Position indisponible.")]
            status = "Position indisponible."
        }
        return MapDetailTextContent(fragments: fragments, accessibilityLabel: "\(displayName). \(status)")
    }

    private func duration(since date: Date, now: Date) -> String {
        Self.durationFormatter.string(from: max(0, now.timeIntervalSince(date))) ?? "0 s"
    }

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute, .second]
        formatter.maximumUnitCount = 2
        formatter.unitsStyle = .full
        formatter.zeroFormattingBehavior = .dropAll
        return formatter
    }()

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
