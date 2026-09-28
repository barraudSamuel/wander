import SwiftUI

// MARK: - Friends

/// Native sections embedded in the personal profile form.
struct FriendsPanelView: View {
    @ObservedObject var service: FriendSyncService
    let friends: [FriendMapSummary]
    let onShowOnMap: (FriendMapSummary) -> Void
    let onViewProfile: (String) -> Void

    @State private var processingRequestID: String?
    @Binding var processingFriendUserID: String?
    @Binding var friendPendingRemoval: FriendMapSummary?

    var body: some View {
        Group {
            if !service.incomingRequests.isEmpty {
                Section("Demandes reçues") {
                    ForEach(service.incomingRequests) { request in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                ProfileAvatarView(
                                    avatarID: request.avatarID,
                                    size: 32
                                )
                                .accessibilityHidden(true)

                                Text(request.displayName)
                            }

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
                .id(ProfileFriendsSection.incomingRequests)
            }

            Section("Mes amis") {
                if friends.isEmpty {
                    Text("Aucun ami pour le moment.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(friends) { friend in
                        HStack {
                            friendButton(friend)

                            if processingFriendUserID == friend.userID {
                                ProgressView()
                            }
                        }
                        .swipeActions(
                            edge: .trailing,
                            allowsFullSwipe: false
                        ) {
                            Button(role: .destructive) {
                                friendPendingRemoval = friend
                            } label: {
                                Label(
                                    "Retirer",
                                    systemImage: "person.badge.minus"
                                )
                            }
                            .disabled(service.isProcessingFriendAction)
                        }
                    }
                }
            }
            .id(ProfileFriendsSection.friends)

            if !service.outgoingRequests.isEmpty {
                Section("En attente") {
                    ForEach(service.outgoingRequests) { request in
                        HStack {
                            ProfileAvatarView(
                                avatarID: request.avatarID,
                                size: 32
                            )
                            .accessibilityHidden(true)

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
        .onChange(of: service.isProcessingFriendAction) { _, isProcessing in
            if !isProcessing {
                processingRequestID = nil
                processingFriendUserID = nil
            }
        }
    }

    @ViewBuilder
    private func friendButton(_ friend: FriendMapSummary) -> some View {
        let button = Button {
            if friend.canShowOnMap {
                onShowOnMap(friend)
            } else {
                onViewProfile(friend.userID)
            }
        } label: {
            FriendRow(friend: friend)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if friend.canShowOnMap {
            button.accessibilityLabel("Afficher \(friend.displayName) sur la carte")
        } else {
            button.accessibilityHint("Ouvrir le profil de cet ami")
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
            FriendAvatarBadge(
                avatarID: friend.avatarID,
                profileColorHex: friend.profileColorHex,
                size: 30
            )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(friend.displayName)
                    .font(.body.weight(.medium))

                TimelineView(.periodic(from: .now, by: 60)) { context in
                    statusLabel(relativeTo: context.date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func statusLabel(relativeTo referenceDate: Date) -> some View {
        if friend.isGhostModeEnabled {
            Text("👻 Indisponible")
                .accessibilityLabel("Indisponible, mode fantôme activé")
        } else if let sampledAt = friend.locationSampledAt {
            let locationText = presenceStatusText(relativeTo: referenceDate)
                ?? positionStatusText(sampledAt, relativeTo: referenceDate)
            Text(locationText)
        } else {
            Text("Position indisponible")
        }
    }

    private func positionStatusText(
        _ sampledAt: Date,
        relativeTo referenceDate: Date
    ) -> String {
        let age = referenceDate.timeIntervalSince(sampledAt)
        guard age >= 60 else {
            return "Dernière position reçue à l’instant"
        }

        let relativeText = Self.relativePositionFormatter.localizedString(
            for: sampledAt,
            relativeTo: referenceDate
        )
        return "Dernière position reçue \(relativeText)"
    }

    private func presenceStatusText(relativeTo referenceDate: Date) -> String? {
        guard friend.isLocationFresh,
              let sampledAt = friend.locationSampledAt,
              let enteredAt = friend.spotEnteredAt else {
            return nil
        }

        let sampleAge = referenceDate.timeIntervalSince(sampledAt)
        guard sampleAge >= -Self.maximumFutureTimestampSkew,
              enteredAt <= sampledAt else {
            return nil
        }

        let duration = max(0, referenceDate.timeIntervalSince(enteredAt))
        return "Au même endroit depuis \(FriendPresenceFormatting.durationText(duration))"
    }

    private static let maximumFutureTimestampSkew: TimeInterval = 60

    private static let relativePositionFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateTimeStyle = .numeric
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}
