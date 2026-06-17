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

    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var lastLocation: CLLocation?
    @Published var locationsReceived: Int = 0
    @Published var isTracking: Bool = false
    @Published var lastError: String?

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

                // TODO: Convert lat/lng to H3 cell index for fog-of-war reveal.

                print("""
                [LocationTracker] location received
                  - lat: \(location.coordinate.latitude)
                  - lng: \(location.coordinate.longitude)
                  - accuracy: \(location.horizontalAccuracy) m
                  - speed: \(location.speed) m/s
                  - timestamp: \(location.timestamp)
                  - age: \(now.timeIntervalSince(location.timestamp)) s
                """)
            }

            // TODO: When persistence is added, store each new location/visited cell here.

            if updated {
                // TODO: Reconstruct the trip segment between lastLocation and the new point.
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
