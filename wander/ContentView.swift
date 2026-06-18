//
//  ContentView.swift
//  wander
//
//  Created by Samuel Barraud on 17/06/2026.
//

import SwiftUI
import MapKit
import CoreLocation

struct ContentView: View {
    @StateObject private var locationTracker = LocationTracker()
    @Environment(\.scenePhase) private var scenePhase

    @State private var drawerExpanded = false
    @State private var drawerDragOffset: CGFloat = 0

    private let drawerCollapsedHeight: CGFloat = 120
    private let drawerExpandedFraction: CGFloat = 0.55

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Map with a uniform fog of war overlay. Discovered cells are punched out
                // as transparent holes; the rest of the zone stays under semi-transparent fog.
                MapWithFogView(
                    locationTracker: locationTracker,
                    discoveredCellIDs: Set(locationTracker.discoveredCells.map { $0.id }),
                    fogColor: UIColor.black.withAlphaComponent(0.45)
                )
                .ignoresSafeArea()

                VStack {
                    Spacer()
                    debugDrawer(in: geometry)
                }
            }
        }
        .onAppear {
            // iOS ne garantit pas le tracking continu après un force quit utilisateur.
            // Ce flag sert à reprendre le tracking quand l’app est relancée ou quand iOS autorise une reprise.
            locationTracker.resumeTrackingIfNeeded()
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

    // MARK: - Debug drawer

    private func debugDrawer(in geometry: GeometryProxy) -> some View {
        let screenHeight = geometry.size.height
        let expandedHeight = screenHeight * drawerExpandedFraction
        let maxOffset = expandedHeight - drawerCollapsedHeight
        let baseOffset = drawerExpanded ? 0 : maxOffset
        let currentOffset = baseOffset + drawerDragOffset

        return VStack(spacing: 0) {
            drawerHandle(in: geometry, maxOffset: maxOffset)

            ScrollView {
                debugContent
                    .padding()
            }
            .frame(height: expandedHeight - drawerHandleHeight)
            .scrollIndicators(.hidden)
        }
        .frame(height: expandedHeight)
        .background(.ultraThinMaterial)
        .overlay(
            // Visible top border for the drawer.
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 0.5)
                .frame(maxHeight: .infinity, alignment: .top),
            alignment: .top
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 16)
        )
        .offset(y: currentOffset)
        .animation(.interpolatingSpring(stiffness: 300, damping: 30), value: drawerExpanded)
        .animation(.interpolatingSpring(stiffness: 300, damping: 30), value: drawerDragOffset)
    }

    private let drawerHandleHeight: CGFloat = 120

    private func drawerHandle(in geometry: GeometryProxy, maxOffset: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Drag indicator only, so buttons still receive taps.
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 40, height: 5)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            drawerDragOffset = value.translation.height
                        }
                        .onEnded { value in
                            let projected = baseOffsetForDrag(maxOffset: maxOffset) + drawerDragOffset
                            let threshold = maxOffset / 2

                            withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                                drawerExpanded = projected < threshold
                                drawerDragOffset = 0
                            }
                        }
                )

            HStack(spacing: 12) {
                // Tracking status pill.
                Text(locationTracker.isTracking ? "Tracking ON" : "Tracking OFF")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(locationTracker.isTracking ? Color.green : Color.red)
                    .foregroundColor(.white)
                    .clipShape(Capsule())

                Spacer()

                // Always-visible tracking controls.
                Button("Start") {
                    locationTracker.startTracking()
                }
                .buttonStyle(DebugButtonStyle(color: .green))

                Button("Stop") {
                    locationTracker.stopTracking()
                }
                .buttonStyle(DebugButtonStyle(color: .red))

                Spacer()

                // Cells summary with proper spacing.
                HStack(spacing: 4) {
                    Image(systemName: "hexagon.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text("\(locationTracker.discoveredCells.count)")
                        .font(.caption.bold())
                    Text(locationTracker.discoveredCells.count == 1 ? "cellule" : "cellules")
                        .font(.caption)
                }

                // Toggle drawer expansion.
                Button {
                    withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                        drawerExpanded.toggle()
                    }
                } label: {
                    Image(systemName: drawerExpanded ? "chevron.down" : "chevron.up")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .contentShape(Rectangle())
    }

    private func baseOffsetForDrag(maxOffset: CGFloat) -> CGFloat {
        drawerExpanded ? 0 : maxOffset
    }

    private var debugContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                LabeledDebugRow(label: "Permission", value: locationStatusText(locationTracker.authorizationStatus))
                LabeledDebugRow(label: "Points reçus", value: "\(locationTracker.locationsReceived)")
                LabeledDebugRow(label: "Latitude", value: coordinateValue(locationTracker.lastLocation?.coordinate.latitude))
                LabeledDebugRow(label: "Longitude", value: coordinateValue(locationTracker.lastLocation?.coordinate.longitude))
                LabeledDebugRow(label: "Accuracy", value: accuracyValue(locationTracker.lastLocation?.horizontalAccuracy))
                LabeledDebugRow(label: "Speed", value: speedValue(locationTracker.lastLocation?.speed))
                LabeledDebugRow(label: "Timestamp", value: timestampValue(locationTracker.lastLocation?.timestamp))
                LabeledDebugRow(label: "Cells", value: "\(locationTracker.discoveredCells.count)")
                LabeledDebugRow(label: "Current H3", value: locationTracker.currentH3CellID ?? "—")
                LabeledDebugRow(label: "Resolution", value: "10")
                LabeledDebugRow(label: "Last seg dist", value: distanceValue(locationTracker.lastSegmentDistance))
                LabeledDebugRow(label: "Last seg speed", value: speedValue(locationTracker.lastSegmentSpeed))
                LabeledDebugRow(label: "Last cells added", value: "\(locationTracker.lastCellsAdded)")
                LabeledDebugRow(label: "Erreur", value: locationTracker.lastError ?? "—")
            }
            .font(.caption)

            debugStatusSection

            scratchMapDebugSection

            HStack(spacing: 12) {
                Spacer()

                Button("Start") {
                    locationTracker.startTracking()
                }
                .buttonStyle(DebugButtonStyle(color: .green))

                #if DEBUG
                Button("Simulate Walk") {
                    locationTracker.simulateWalk()
                }
                .buttonStyle(DebugButtonStyle(color: .blue))
                #endif

                Button("Stop") {
                    locationTracker.stopTracking()
                }
                .buttonStyle(DebugButtonStyle(color: .red))

                Spacer()
            }
        }
    }

    // MARK: - Tracking status section

    private var debugStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tracking")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            Group {
                LabeledDebugRow(label: "Enabled", value: locationTracker.trackingEnabled ? "true" : "false")
                LabeledDebugRow(label: "Mode", value: locationTracker.trackingMode.rawValue)
                LabeledDebugRow(label: "Visits", value: "\(locationTracker.visitsReceived)")
                LabeledDebugRow(label: "Desired acc.", value: locationTracker.desiredAccuracyDescription)
                LabeledDebugRow(label: "Dist. filter", value: locationTracker.distanceFilterDescription)
            }
            .font(.caption)
        }
        .padding(.top, 4)
    }

    // MARK: - Scratch map debug section

    private var scratchMapDebugSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fog of war")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            Group {
                LabeledDebugRow(label: "Discovered cells", value: "\(locationTracker.discoveredCells.count)")
                LabeledDebugRow(label: "Current H3", value: locationTracker.currentH3CellID ?? "—")
            }
            .font(.caption)
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private func locationStatusText(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "notDetermined"
        case .restricted:
            return "restricted"
        case .denied:
            return "denied"
        case .authorizedAlways:
            return "authorizedAlways"
        case .authorizedWhenInUse:
            return "authorizedWhenInUse"
        @unknown default:
            return "unknown"
        }
    }

    private func coordinateValue(_ value: CLLocationDegrees?) -> String {
        guard let value else { return "—" }
        return String(format: "%.6f", value)
    }

    private func accuracyValue(_ value: CLLocationAccuracy?) -> String {
        guard let value, value >= 0 else { return "—" }
        return String(format: "%.1f m", value)
    }

    private func speedValue(_ value: CLLocationSpeed?) -> String {
        guard let value, value >= 0 else { return "—" }
        return String(format: "%.2f m/s", value)
    }

    private func distanceValue(_ value: CLLocationDistance?) -> String {
        guard let value, value >= 0 else { return "—" }
        return String(format: "%.1f m", value)
    }

    private func timestampValue(_ date: Date?) -> String {
        guard let date else { return "—" }
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Reusable UI pieces

struct LabeledDebugRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(minWidth: 80, alignment: .leading)
            Text(value)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
        }
    }
}

struct DebugButtonStyle: ButtonStyle {
    var color: Color = .blue

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color.opacity(configuration.isPressed ? 0.7 : 1))
            .foregroundColor(.white)
            .clipShape(Capsule())
    }
}

#Preview {
    ContentView()
}
