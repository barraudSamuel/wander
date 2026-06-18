//
//  ContentView.swift
//  wander
//
//  Root view: map with fog-of-war overlay, city progress banner,
//  a floating location button, and a draggable debug drawer.
//
//  Created by Samuel Barraud on 17/06/2026.
//

import SwiftUI
import MapKit
import CoreLocation
import SwiftData

struct ContentView: View {
    @StateObject private var locationTracker = LocationTracker()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    @State private var drawerExpanded = false
    @State private var cityProgress: CityProgress?
    @State private var cityBoundaryCoordinates: [CLLocationCoordinate2D] = []
    @State private var centerOnUser = false

    private let drawerExpandedFraction: CGFloat = 0.55

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                MapWithFogView(
                    locationTracker: locationTracker,
                    discoveredCellIDs: Set(locationTracker.discoveredCells.map { $0.id }),
                    cityBoundaryCoordinates: cityBoundaryCoordinates,
                    centerOnUser: $centerOnUser
                )
                .ignoresSafeArea()

                VStack {
                    cityProgressBanner
                    Spacer()
                    DebugDrawerView(
                        locationTracker: locationTracker,
                        isExpanded: $drawerExpanded,
                        cityProgress: cityProgress,
                        parentGeometry: geometry
                    )
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            centerOnUser = true
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, geometry.size.height * drawerExpandedFraction + 16)
                    }
                }
            }
        }
        .onAppear {
            locationTracker.configure(with: modelContext)
            locationTracker.resumeTrackingIfNeeded()

            Task { [locationTracker] in
                await CityBoundary.shared.load()
                cityProgress = CityBoundary.shared.progress(against: locationTracker.discoveredCells)
                cityBoundaryCoordinates = CityBoundary.shared.boundaryCoordinates
            }
        }
        .onChange(of: locationTracker.discoveredCells) { _, _ in
            updateCityProgress()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                if locationTracker.trackingEnabled {
                    locationTracker.applyTrackingMode(.foreground)
                }
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

    // MARK: - City progress

    private func updateCityProgress() {
        Task { [locationTracker] in
            cityProgress = CityBoundary.shared.progress(against: locationTracker.discoveredCells)
        }
    }

    private var cityProgressBanner: some View {
        VStack(spacing: 4) {
            if let progress = cityProgress {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Circle().fill(locationTracker.isTracking ? Color.green : Color.secondary.opacity(0.3)))
                    Text(progress.cityName)
                        .font(.caption.bold())
                        .foregroundColor(.primary)
                }

                Text("\(progress.percentageText) explored — \(progress.exploredCells) / \(progress.totalCells) cells")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.green)
                            .frame(width: geo.size.width * progress.percentage, height: 4)
                    }
                }
                .frame(height: 4)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Circle().fill(locationTracker.isTracking ? Color.green : Color.secondary.opacity(0.3)))
                    Text("Calculating city progress…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

#Preview {
    ContentView()
}
