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
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        FriendAvatarBadge(
                            avatarID: avatarID,
                            profileColorHex: profileColorHex,
                            size: 64
                        )
                        .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayName)
                                .font(.title2.bold())

                            Label("Ami", systemImage: "person.2.fill")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    if let location {
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

                        if isLocationFresh,
                           let spotEnteredAt = location.spotEnteredAt {
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

                    Button {
                        opensDirectionsAfterDismiss = true
                        dismiss()
                    } label: {
                        Label("Itinéraire", systemImage: "map")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(location == nil)
                    .accessibilityHint(
                        "Choisir une application pour rejoindre cet ami"
                    )
                } header: {
                    Text("Position")
                } footer: {
                    Text(
                        "L’action Itinéraire utilise la dernière position connue, même si elle n’a pas été actualisée récemment."
                    )
                }
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
        .onChange(of: isFriendAccepted, initial: true) { _, isAccepted in
            if !isAccepted {
                dismiss()
            }
        }
        .onDisappear {
            guard opensDirectionsAfterDismiss else { return }
            Task { @MainActor in
                await Task.yield()
                onOpenDirections()
            }
        }
    }

    private var friend: FriendContact? {
        service.acceptedFriends.first { $0.userID == userID }
    }

    private var location: FriendLocation? {
        service.friendLocations[userID]
    }

    private var isFriendAccepted: Bool {
        friend != nil
    }

    private var isLocationFresh: Bool {
        service.freshFriendLocationUserIDs.contains(userID)
    }

    private var displayName: String {
        location?.displayName
            ?? friend?.displayName
            ?? "Ami"
    }

    private var avatarID: String {
        friend?.avatarID ?? ""
    }

    private var profileColorHex: String {
        ProfileColor.normalizedHex(
            location?.profileColorHex
                ?? friend?.profileColorHex
                ?? ""
        ) ?? ProfileColor.generatedHex(seed: userID)
    }

}
