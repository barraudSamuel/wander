//
//  LocationTracker.swift
//  wander
//
//  Created by Samuel Barraud on 17/06/2026.
//

import Foundation
import CoreLocation
import Combine

final class LocationTracker: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let explorationEngine = ExplorationEngine()
    private let cellStore = DiscoveredCellStore()
    private var previousAcceptedLocation: CLLocation?

    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var lastLocation: CLLocation?
    @Published var locationsReceived: Int = 0
    @Published var isTracking: Bool = false
    @Published var lastError: String?
    @Published var discoveredCells: [DiscoveredCell] = []
    @Published var currentH3CellID: String?

    // Last accepted segment statistics for the debug panel.
    @Published var lastSegmentDistance: CLLocationDistance?
    @Published var lastSegmentTimeGap: TimeInterval?
    @Published var lastSegmentSpeed: CLLocationSpeed?
    @Published var lastCellsAdded: Int = 0

    /// Tracks whether the user tapped Start while the permission was still undetermined.
    /// We use this to automatically begin tracking once the permission is granted.
    private var shouldStartAfterPermission = false

    override init() {
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        // Only trigger an update when the user has moved at least 50 meters.
        // This value can be lowered later for a denser fog-reveal grid.
        locationManager.distanceFilter = 50
        locationManager.pausesLocationUpdatesAutomatically = true
        // Required so startUpdatingLocation keeps working when the app is in the background.
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true

        cellStore.load()
        discoveredCells = cellStore.cells
    }

    // MARK: - Permissions

    /// Requests the highest level of location permission we can get.
    /// On first launch this asks the user for "When In Use"; iOS can later
    /// offer an upgrade to "Always" after the app has used background location.
    private func requestPermissionIfNeeded() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    // MARK: - Tracking control

    /// Starts tracking, or requests permission first if it hasn't been asked yet.
    /// When permission is granted later, tracking begins automatically via the delegate.
    func startTracking() {
        lastError = nil

        guard CLLocationManager.locationServicesEnabled() else {
            lastError = "Location services are disabled on this device."
            isTracking = false
            return
        }

        switch authorizationStatus {
        case .notDetermined:
            shouldStartAfterPermission = true
            requestPermissionIfNeeded()
            return
        case .restricted, .denied:
            lastError = "Location permission is denied or restricted."
            return
        case .authorizedAlways, .authorizedWhenInUse:
            break
        @unknown default:
            lastError = "Unknown authorization status."
            return
        }

        isTracking = true
        lastError = nil
        // Continuous updates while the app is running.
        locationManager.startUpdatingLocation()
        // Significant-change monitoring helps the app wake in the background
        // after large user movements. It can generate callbacks alongside
        // continuous updates, which is acceptable for this prototype.
        locationManager.startMonitoringSignificantLocationChanges()
    }

    func stopTracking() {
        shouldStartAfterPermission = false
        isTracking = false
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = manager.authorizationStatus

        Task { @MainActor in
            self.authorizationStatus = newStatus

            if self.shouldStartAfterPermission,
               newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways {
                self.shouldStartAfterPermission = false
                self.startTracking()
            } else if newStatus == .denied || newStatus == .restricted {
                self.shouldStartAfterPermission = false
                self.isTracking = false
                self.lastError = "Location permission was denied or restricted."
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let now = Date()
        let filtered = locations
            .filter { $0.horizontalAccuracy > 0 && $0.horizontalAccuracy <= 150 }
            .sorted { $0.timestamp < $1.timestamp }

        Task { @MainActor [weak self] in
            guard let self else { return }

            var updated = false
            for location in filtered {
                self.locationsReceived += 1
                self.lastLocation = location
                self.lastError = nil
                updated = true

                let previous = self.previousAcceptedLocation
                let discoveredIDs = self.explorationEngine.discoveredCellIDs(
                    from: previous,
                    to: location
                )

                for cellID in discoveredIDs {
                    self.cellStore.upsert(
                        cellID: cellID,
                        resolution: self.explorationEngine.resolution,
                        seenAt: location.timestamp
                    )
                }

                self.currentH3CellID = self.explorationEngine.cellID(for: location)

                // Update segment statistics for the debug panel.
                if let previous = previous {
                    let distance = location.distance(from: previous)
                    let gap = location.timestamp.timeIntervalSince(previous.timestamp)
                    let speed = gap > 0 ? distance / gap : 0
                    let cellsAdded = max(0, discoveredIDs.count - 1)

                    self.lastSegmentDistance = distance
                    self.lastSegmentTimeGap = gap
                    self.lastSegmentSpeed = speed
                    self.lastCellsAdded = cellsAdded

                    print("🧭 Segment distance=\(Int(distance))m gap=\(Int(gap))s speed=\(String(format: "%.1f", speed))m/s cellsAdded=\(cellsAdded) current=\(self.currentH3CellID ?? "—")")
                } else {
                    self.lastSegmentDistance = nil
                    self.lastSegmentTimeGap = nil
                    self.lastSegmentSpeed = nil
                    self.lastCellsAdded = 0
                }

                self.previousAcceptedLocation = location

                print("""
                [LocationTracker] location received
                  - lat: \(location.coordinate.latitude)
                  - lng: \(location.coordinate.longitude)
                  - accuracy: \(location.horizontalAccuracy) m
                  - speed: \(location.speed) m/s
                  - timestamp: \(location.timestamp)
                  - age: \(now.timeIntervalSince(location.timestamp)) s
                  - cells discovered: \(self.discoveredCells.count)
                """)
            }

            if updated {
                self.cellStore.save()
                self.discoveredCells = self.cellStore.cells
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let message = error.localizedDescription

        Task { @MainActor [weak self] in
            self?.lastError = message
        }
        print("[LocationTracker] error: \(message)")
    }
}
