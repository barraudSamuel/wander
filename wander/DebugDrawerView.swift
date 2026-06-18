//
//  DebugDrawerView.swift
//  wander
//
//  A draggable debug drawer that sits at the bottom of the map and shows
//  live location, tracking, and exploration stats. Expands/collapses with
//  a drag gesture or the chevron button.
//

import SwiftUI
import CoreLocation

struct DebugDrawerView: View {
    @ObservedObject var locationTracker: LocationTracker
    @Binding var isExpanded: Bool
    var cityProgress: CityProgress?
    var parentGeometry: GeometryProxy

    private let collapsedHeight: CGFloat = 120
    private let expandedFraction: CGFloat = 0.55
    private let handleHeight: CGFloat = 120

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        let screenHeight = parentGeometry.size.height
        let expandedHeight = screenHeight * expandedFraction
        let maxOffset = expandedHeight - collapsedHeight
        let baseOffset = isExpanded ? 0 : maxOffset
        let currentOffset = baseOffset + dragOffset

        VStack(spacing: 0) {
            drawerHandle(maxOffset: maxOffset)
            drawerContent
                .frame(height: expandedHeight - handleHeight)
        }
        .frame(height: expandedHeight)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 0.5)
                .frame(maxHeight: .infinity, alignment: .top),
            alignment: .top
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .offset(y: currentOffset)
        .animation(.interpolatingSpring(stiffness: 300, damping: 30), value: isExpanded)
        .animation(.interpolatingSpring(stiffness: 300, damping: 30), value: dragOffset)
    }

    // MARK: - Handle

    private let drawerHandleBottomPadding: CGFloat = 12

    private func drawerHandle(maxOffset: CGFloat) -> some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 40, height: 5)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation.height
                        }
                        .onEnded { value in
                            let base = isExpanded ? 0 : maxOffset
                            let projected = base + dragOffset
                            let threshold = maxOffset / 2

                            withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                                isExpanded = projected < threshold
                                dragOffset = 0
                            }
                        }
                )

            HStack(spacing: 12) {
                trackingStatusPill
                Spacer()
                Button("Start") { locationTracker.startTracking() }
                    .buttonStyle(DebugButtonStyle(color: .green))
                Button("Stop") { locationTracker.stopTracking() }
                    .buttonStyle(DebugButtonStyle(color: .red))
                Spacer()
                cellsSummary
                expandToggleButton
            }
            .padding(.horizontal)
            .padding(.bottom, drawerHandleBottomPadding)
        }
        .contentShape(Rectangle())
    }

    private var trackingStatusPill: some View {
        Text(locationTracker.isTracking ? "Tracking ON" : "Tracking OFF")
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(locationTracker.isTracking ? Color.green : Color.red)
            .foregroundColor(.white)
            .clipShape(Capsule())
    }

    private var cellsSummary: some View {
        HStack(spacing: 4) {
            Image(systemName: "hexagon.fill")
                .font(.caption2)
                .foregroundColor(.green)
            Text("\(locationTracker.discoveredCells.count)")
                .font(.caption.bold())
            Text("cells")
                .font(.caption)
        }
    }

    private var expandToggleButton: some View {
        Button {
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                isExpanded.toggle()
            }
        } label: {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
    }

    // MARK: - Expanded content

    private var drawerContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                locationSection
                trackingSection
                fogOfWarSection
                actionButtons
            }
            .padding()
        }
        .scrollIndicators(.hidden)
    }

    private var locationSection: some View {
        Group {
            LabeledDebugRow(label: "Permission", value: permissionText(locationTracker.authorizationStatus))
            LabeledDebugRow(label: "Locations received", value: "\(locationTracker.locationsReceived)")
            LabeledDebugRow(label: "Latitude", value: formattedCoordinate(locationTracker.lastLocation?.coordinate.latitude))
            LabeledDebugRow(label: "Longitude", value: formattedCoordinate(locationTracker.lastLocation?.coordinate.longitude))
            LabeledDebugRow(label: "Accuracy", value: formattedAccuracy(locationTracker.lastLocation?.horizontalAccuracy))
            LabeledDebugRow(label: "Speed", value: formattedSpeed(locationTracker.lastLocation?.speed))
            LabeledDebugRow(label: "Timestamp", value: formattedTimestamp(locationTracker.lastLocation?.timestamp))
            LabeledDebugRow(label: "Cells", value: "\(locationTracker.discoveredCells.count)")
            LabeledDebugRow(label: "Current H3", value: locationTracker.currentH3CellID ?? "\u{2014}")
            LabeledDebugRow(label: "Resolution", value: "10")
            LabeledDebugRow(label: "Last seg. distance", value: formattedDistance(locationTracker.lastSegmentDistance))
            LabeledDebugRow(label: "Last seg. speed", value: formattedSpeed(locationTracker.lastSegmentSpeed))
            LabeledDebugRow(label: "Last cells added", value: "\(locationTracker.lastCellsAdded)")
            LabeledDebugRow(label: "Error", value: locationTracker.lastError ?? "\u{2014}")
        }
        .font(.caption)
    }

    private var trackingSection: some View {
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

    private var fogOfWarSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fog of war")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            Group {
                LabeledDebugRow(label: "Discovered cells", value: "\(locationTracker.discoveredCells.count)")
                LabeledDebugRow(label: "Current H3", value: locationTracker.currentH3CellID ?? "\u{2014}")
                LabeledDebugRow(label: "City", value: cityProgress?.cityName ?? "\u{2014}")
                LabeledDebugRow(label: "City cells", value: "\(cityProgress?.totalCells ?? 0)")
                LabeledDebugRow(label: "Explored", value: "\(cityProgress?.exploredCells ?? 0)")
                LabeledDebugRow(label: "Progress", value: cityProgress?.percentageText ?? "\u{2014}")
            }
            .font(.caption)
        }
        .padding(.top, 4)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Spacer()
            #if DEBUG
            Button("Simulate Walk") { locationTracker.simulateWalk() }
                .buttonStyle(DebugButtonStyle(color: .blue))
            #endif
            Spacer()
        }
    }

    // MARK: - Formatters

    private func permissionText(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:    return "notDetermined"
        case .restricted:       return "restricted"
        case .denied:           return "denied"
        case .authorizedAlways: return "authorizedAlways"
        case .authorizedWhenInUse: return "authorizedWhenInUse"
        @unknown default:       return "unknown"
        }
    }

    private func formattedCoordinate(_ value: CLLocationDegrees?) -> String {
        guard let value else { return "\u{2014}" }
        return String(format: "%.6f", value)
    }

    private func formattedAccuracy(_ value: CLLocationAccuracy?) -> String {
        guard let value, value >= 0 else { return "\u{2014}" }
        return String(format: "%.1f m", value)
    }

    private func formattedSpeed(_ value: CLLocationSpeed?) -> String {
        guard let value, value >= 0 else { return "\u{2014}" }
        return String(format: "%.2f m/s", value)
    }

    private func formattedDistance(_ value: CLLocationDistance?) -> String {
        guard let value, value >= 0 else { return "\u{2014}" }
        return String(format: "%.1f m", value)
    }

    private func formattedTimestamp(_ date: Date?) -> String {
        guard let date else { return "\u{2014}" }
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Reusable components

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
