//
//  FriendProfileSheet.swift
//  wander
//
//  Friend profile and shared avatar presentation.
//

import SwiftUI

enum CityBoundaryResolutionState: Equatable {
    case loading
    case ready
    case unavailable
}

struct FriendAvatarBadge: View {
    private let profileColorHex: String
    private let size: CGFloat

    init(profileColorHex: String, size: CGFloat) {
        self.profileColorHex = profileColorHex
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(ProfileColor.color(hex: profileColorHex))

            Image(systemName: "person.fill")
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(
                    ProfileColor.foregroundColor(hex: profileColorHex)
                )
        }
        .frame(width: size, height: size)
    }
}

struct FriendProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var service: FriendSyncService
    @ObservedObject private var cityBoundary: CityBoundary
    @Binding private var cityBoundaryResolutionState: CityBoundaryResolutionState

    private let userID: String

    private enum CityProgressState {
        case explorationLoading
        case boundariesLoading
        case boundariesUnavailable
        case positionUnavailable
        case unsupportedCity
        case available(CityProgress)
    }

    init(
        userID: String,
        service: FriendSyncService,
        cityBoundary: CityBoundary,
        cityBoundaryResolutionState: Binding<CityBoundaryResolutionState>
    ) {
        self.userID = userID
        self.service = service
        self.cityBoundary = cityBoundary
        _cityBoundaryResolutionState = cityBoundaryResolutionState
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        FriendAvatarBadge(
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

                Section("Exploration") {
                    switch cityProgressState {
                    case .explorationLoading:
                        HStack {
                            Text("Progression")
                            Spacer()
                            ProgressView()
                                .accessibilityLabel("Chargement de la progression")
                        }

                        Text("Chargement de l’exploration de cet ami…")
                            .foregroundStyle(.secondary)
                    case .boundariesLoading:
                        HStack {
                            Text("Progression")
                            Spacer()
                            ProgressView()
                                .accessibilityLabel("Préparation des villes")
                        }

                        Text("Préparation des villes prises en charge…")
                            .foregroundStyle(.secondary)
                    case .boundariesUnavailable:
                        LabeledContent("Progression", value: "Indisponible")

                        Text("Les données des villes ne sont pas disponibles pour le moment.")
                            .foregroundStyle(.secondary)
                    case .positionUnavailable:
                        LabeledContent("Progression", value: "Indisponible")

                        Text("Une position partagée est nécessaire pour calculer la progression par ville.")
                            .foregroundStyle(.secondary)
                    case .unsupportedCity:
                        LabeledContent("Progression", value: "Indisponible")

                        Text("La dernière position ne correspond à aucune ville prise en charge.")
                            .foregroundStyle(.secondary)
                    case .available(let progress):
                        LabeledContent("Ville", value: progress.cityName)
                        LabeledContent("Progression", value: progress.percentageText)

                        ProgressView(value: progress.percentage)
                            .accessibilityLabel("Progression explorée")
                            .accessibilityValue(progress.percentageText)

                        LabeledContent("Zones dans la ville") {
                            Text(
                                "\(progress.exploredCells.formatted()) / \(progress.totalCells.formatted())"
                            )
                            .monospacedDigit()
                        }
                    }

                    if isExplorationLoaded {
                        LabeledContent("Zones explorées au total") {
                            Text(totalExploredCellCount.formatted())
                                .monospacedDigit()
                        }
                    } else {
                        LabeledContent("Zones explorées au total", value: "Chargement…")
                    }
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
                } header: {
                    Text("Position")
                } footer: {
                    Text(
                        "L’action Rejoindre utilise la dernière position connue, même si elle n’a pas été actualisée récemment."
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
    }

    private var friend: FriendContact? {
        service.acceptedFriends.first { $0.userID == userID }
    }

    private var exploration: FriendExploration? {
        service.friendExplorations[userID]
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

    private var isExplorationLoaded: Bool {
        service.loadedFriendExplorationUserIDs.contains(userID)
    }

    private var totalExploredCellCount: Int {
        exploration?.cellIDs.count ?? 0
    }

    private var displayName: String {
        location?.displayName
            ?? exploration?.displayName
            ?? friend?.displayName
            ?? "Ami"
    }

    private var profileColorHex: String {
        ProfileColor.normalizedHex(
            location?.profileColorHex
                ?? exploration?.profileColorHex
                ?? friend?.profileColorHex
                ?? ""
        ) ?? ProfileColor.generatedHex(seed: userID)
    }

    private var cityProgressState: CityProgressState {
        guard isExplorationLoaded else {
            return .explorationLoading
        }

        guard let location else {
            return .positionUnavailable
        }

        switch cityBoundaryResolutionState {
        case .loading:
            return .boundariesLoading
        case .unavailable:
            return .boundariesUnavailable
        case .ready:
            guard let exploration,
                  let progress = cityBoundary.progress(
                    against: exploration.cellIDs,
                    at: location.coordinate
                  ) else {
                return .unsupportedCity
            }
            return .available(progress)
        }
    }
}
