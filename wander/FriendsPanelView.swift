import SwiftUI

// MARK: - Friends

struct FriendsPanelView: View {
    @Environment(\.mapNavigationBottomInset) private var navigationBottomInset
    @ObservedObject var service: FriendSyncService
    let friends: [FriendMapSummary]
    let onShowOnMap: (FriendMapSummary) -> Void
    let onViewProfile: (String) -> Void
    var isActive = true

    @State private var processingRequestID: String?
    @State private var processingFriendUserID: String?
    @State private var friendPendingRemoval: FriendMapSummary?

    var body: some View {
        NavigationStack {
            List {
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
                }

                Section("Mes amis") {
                    if friends.isEmpty {
                        Text("Aucun ami pour le moment.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(friends) { friend in
                            HStack {
                                if friend.canShowOnMap {
                                    Button {
                                        onShowOnMap(friend)
                                    } label: {
                                        FriendRow(friend: friend)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(
                                        "Afficher \(friend.displayName) sur la carte"
                                    )
                                } else {
                                    Button {
                                        onViewProfile(friend.userID)
                                    } label: {
                                        FriendRow(friend: friend)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityHint("Ouvrir le profil de cet ami")
                                }

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
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, navigationBottomInset, for: .scrollContent)
            .accessibilityIdentifier("friends-expanded-list")
            .toolbar(.hidden, for: .navigationBar)
            .scrollDismissesKeyboard(.interactively)
            .alert(
                removalAlertTitle,
                isPresented: removalAlertIsPresented,
                presenting: friendPendingRemoval
            ) { friend in
                Button("Retirer", role: .destructive) {
                    remove(friend)
                }
                Button("Annuler", role: .cancel) {}
            } message: { _ in
                Text(
                    "Vous disparaîtrez tous les deux de la liste d’amis de l’autre. "
                        + "Il faudra envoyer une nouvelle demande pour redevenir amis."
                )
            }
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
                    processingFriendUserID = nil
                }
            }
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: {
                isActive && service.errorMessage != nil
            },
            set: { isPresented in
                if !isPresented {
                    service.clearError()
                }
            }
        )
    }

    private var removalAlertIsPresented: Binding<Bool> {
        Binding(
            get: {
                isActive && friendPendingRemoval != nil
            },
            set: { isPresented in
                if !isPresented {
                    friendPendingRemoval = nil
                }
            }
        )
    }

    private var removalAlertTitle: String {
        guard let friendPendingRemoval else {
            return "Retirer cet ami ?"
        }
        return "Retirer \(friendPendingRemoval.displayName) de tes amis ?"
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

    private func remove(_ friend: FriendMapSummary) {
        processingFriendUserID = friend.userID
        service.removeFriend(userID: friend.userID)

        if !service.isProcessingFriendAction {
            processingFriendUserID = nil
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
        return "Au même endroit depuis \(Self.durationText(duration))"
    }

    private static func durationText(_ duration: TimeInterval) -> String {
        let totalMinutes = max(0, Int(duration / 60))
        guard totalMinutes > 0 else { return "moins d’1 min" }

        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60

        if days > 0 {
            return hours > 0 ? "\(days) j \(hours) h" : "\(days) j"
        }
        if hours > 0 {
            return minutes > 0 ? "\(hours) h \(minutes) min" : "\(hours) h"
        }
        return "\(minutes) min"
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
