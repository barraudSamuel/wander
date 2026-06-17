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

    var body: some View {
        ZStack {
            Map {
                UserAnnotation()
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }

            VStack {
                Spacer()
                debugPanel
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Debug panel

    private var debugPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Debug")
                    .font(.headline)
                Spacer()
                Text(locationTracker.isTracking ? "Tracking ON" : "Tracking OFF")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(locationTracker.isTracking ? Color.green : Color.red)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }

            Group {
                LabeledDebugRow(label: "Permission", value: locationStatusText(locationTracker.authorizationStatus))
                LabeledDebugRow(label: "Points reçus", value: "\(locationTracker.locationsReceived)")
                LabeledDebugRow(label: "Latitude", value: coordinateValue(locationTracker.lastLocation?.coordinate.latitude))
                LabeledDebugRow(label: "Longitude", value: coordinateValue(locationTracker.lastLocation?.coordinate.longitude))
                LabeledDebugRow(label: "Accuracy", value: accuracyValue(locationTracker.lastLocation?.horizontalAccuracy))
                LabeledDebugRow(label: "Speed", value: speedValue(locationTracker.lastLocation?.speed))
                LabeledDebugRow(label: "Timestamp", value: timestampValue(locationTracker.lastLocation?.timestamp))
                LabeledDebugRow(label: "Erreur", value: locationTracker.lastError ?? "—")
            }
            .font(.caption)

            HStack(spacing: 12) {
                Spacer()

                Button("Start") {
                    locationTracker.startTracking()
                }
                .buttonStyle(DebugButtonStyle(color: .green))

                Button("Stop") {
                    locationTracker.stopTracking()
                }
                .buttonStyle(DebugButtonStyle(color: .red))
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 8)
        .padding(.horizontal)
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
