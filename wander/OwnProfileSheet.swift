import MapKit
import SwiftUI

/// Shares the personal summary and compact presentation across both entry points.
struct OwnProfileSheet<ProfileContent: View>: View {
    let displayName: String
    let avatarID: String
    let profileColorHex: String
    @ObservedObject var locationTracker: LocationTracker
    let cityProgress: CityProgress?
    let isGhostModeEnabled: Bool
    let onPreparePresentation: (CGFloat) -> Void
    @ViewBuilder let content: (AnyView) -> ProfileContent

    @State private var address: String?
    @State private var isResolvingAddress = false
    @State private var addressRequest: MKReverseGeocodingRequest?

    private var coordinate: MapUserCoordinate? {
        locationTracker.lastLocation.map { MapUserCoordinate($0.coordinate) }
    }

    var body: some View {
        MapProfileNativeContent(
            content: content(AnyView(profileBody)),
            scrollIdentifier: "own-profile-scroll",
            compactContent: AnyView(profileBody),
            wrapsInScrollView: false,
            onPreparePresentation: onPreparePresentation
        )
        .task(id: coordinate?.cacheKey) {
            addressRequest?.cancel()
            address = nil
            isResolvingAddress = false
            guard let coordinate else { return }
            if let cached = MapProfileAddress.cache.object(forKey: coordinate.cacheKey) {
                address = cached as String
                return
            }
            guard let request = MKReverseGeocodingRequest(location: coordinate.location) else { return }
            addressRequest = request
            isResolvingAddress = true
            let items = try? await request.mapItems
            guard !Task.isCancelled else { return }
            address = MapProfileAddress.formattedAddress(from: items)
            if let address {
                MapProfileAddress.cache.setObject(address as NSString, forKey: coordinate.cacheKey)
            }
            isResolvingAddress = false
            addressRequest = nil
        }
        .onDisappear { addressRequest?.cancel() }
    }

    private var profileBody: some View {
        VStack(spacing: 20) {
            MapProfileIdentityView(
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "Explorer" : displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                avatarID: avatarID,
                profileColorHex: profileColorHex
            )

            Label(
                isGhostModeEnabled ? "Mode fantôme"
                    : locationTracker.isTracking ? "Exploration active" : "Exploration en pause",
                systemImage: isGhostModeEnabled ? "eye.slash"
                    : locationTracker.isTracking ? "location" : "pause.circle"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Exploration")
                    .font(.headline)
                if let progress = cityProgress {
                    LabeledContent(progress.cityName) {
                        Text(progress.percentage, format: .percent.precision(.fractionLength(1)))
                    }
                    Text("\(progress.exploredCells.formatted()) / \(progress.totalCells.formatted()) zones")
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(locationTracker.discoveredCellIDs.count.formatted()) zones explorées")
                    Text("Progression par ville indisponible")
                        .foregroundStyle(.secondary)
                }

                Divider()

                if let sampledAt = locationTracker.lastLocation?.timestamp {
                    LabeledContent("Position reçue") {
                        Text(sampledAt, style: .relative)
                    }
                    if let enteredAt = locationTracker.currentSpotEnteredAt,
                       enteredAt <= sampledAt {
                        LabeledContent("Au même endroit") {
                            Text(enteredAt, style: .relative)
                        }
                    }
                    if let address {
                        Text(address)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        Button("Copier l’adresse", systemImage: "doc.on.doc") {
                            UIPasteboard.general.string = address
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("own-profile-copy-address")
                    } else {
                        Text(isResolvingAddress ? "Recherche de l’adresse…" : "Adresse indisponible")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Position indisponible")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }
}
