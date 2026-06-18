//
//  LocationTracker.swift
//  wander
//
//  Created by Samuel Barraud on 17/06/2026.
//

import Foundation
import CoreLocation
import Combine
import SwiftData

final class LocationTracker: NSObject, ObservableObject, CLLocationManagerDelegate {
    enum TrackingMode: String {
        case foreground
        case background
        case lowPower
    }

    private let locationManager = CLLocationManager()
    private let explorationEngine = ExplorationEngine()
    private let cellStore = DiscoveredCellStore()
    private var previousAcceptedLocation: CLLocation?

    // Persistence key for the user's tracking intention.
    private let trackingEnabledKey = "trackingEnabled"

    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var lastLocation: CLLocation?
    @Published var locationsReceived: Int = 0
    @Published var isTracking: Bool = false
    @Published var trackingEnabled: Bool
    @Published var trackingMode: TrackingMode = .foreground
    @Published var visitsReceived: Int = 0
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
        self.trackingEnabled = UserDefaults.standard.bool(forKey: trackingEnabledKey)
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 20
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true
    }

    func configure(with context: ModelContext) {
        cellStore.configure(with: context)
        discoveredCells = cellStore.cells
    }

    // MARK: - Debug info

    /// Human-readable description of the current desired accuracy setting.
    var desiredAccuracyDescription: String {
        switch locationManager.desiredAccuracy {
        case kCLLocationAccuracyBestForNavigation:
            return "Best for Navigation"
        case kCLLocationAccuracyBest:
            return "Best"
        case kCLLocationAccuracyNearestTenMeters:
            return "10 m"
        case kCLLocationAccuracyHundredMeters:
            return "100 m"
        case kCLLocationAccuracyKilometer:
            return "1 km"
        case kCLLocationAccuracyThreeKilometers:
            return "3 km"
        default:
            return "\(Int(locationManager.desiredAccuracy)) m"
        }
    }

    /// Human-readable description of the current distance filter.
    var distanceFilterDescription: String {
        return "\(Int(locationManager.distanceFilter)) m"
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

        // Persist the user's intention immediately so the app can resume after a restart.
        UserDefaults.standard.set(true, forKey: trackingEnabledKey)
        trackingEnabled = true

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
            trackingEnabled = false
            UserDefaults.standard.set(false, forKey: trackingEnabledKey)
            return
        }

        isTracking = true
        lastError = nil

        // Start tracking with the most precise foreground profile.
        applyTrackingMode(.foreground)
    }

    func stopTracking() {
        shouldStartAfterPermission = false
        UserDefaults.standard.set(false, forKey: trackingEnabledKey)
        trackingEnabled = false
        isTracking = false
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        locationManager.stopMonitoringVisits()
    }

    // MARK: - Tracking resume & modes

    /// Resumes location services if the user previously opted in and permission is valid.
    /// Call this from app launch and when the authorization status changes.
    func resumeTrackingIfNeeded() {
        guard trackingEnabled else { return }

        let status = locationManager.authorizationStatus
        guard status == .authorizedAlways || status == .authorizedWhenInUse else {
            isTracking = false
            return
        }

        guard CLLocationManager.locationServicesEnabled() else {
            isTracking = false
            return
        }

        isTracking = true
        applyTrackingMode(trackingMode)
    }

    /// Applies accuracy/distance settings and starts or stops the appropriate location services.
    /// Only starts services if the user has enabled tracking.
    func applyTrackingMode(_ mode: TrackingMode) {
        trackingMode = mode

        switch mode {
        case .foreground:
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.distanceFilter = 20
            locationManager.pausesLocationUpdatesAutomatically = false

            guard trackingEnabled else { return }
            locationManager.startUpdatingLocation()
            locationManager.startMonitoringSignificantLocationChanges()
            locationManager.startMonitoringVisits()

        case .background:
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locationManager.distanceFilter = 75
            locationManager.pausesLocationUpdatesAutomatically = true

            guard trackingEnabled else { return }
            locationManager.startUpdatingLocation()
            locationManager.startMonitoringSignificantLocationChanges()
            locationManager.startMonitoringVisits()

        case .lowPower:
            locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
            locationManager.distanceFilter = 500
            locationManager.pausesLocationUpdatesAutomatically = true

            guard trackingEnabled else { return }
            locationManager.stopUpdatingLocation()
            locationManager.startMonitoringSignificantLocationChanges()
            locationManager.startMonitoringVisits()
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = manager.authorizationStatus

        Task { @MainActor in
            self.authorizationStatus = newStatus

            if newStatus == .denied || newStatus == .restricted {
                self.shouldStartAfterPermission = false
                self.trackingEnabled = false
                UserDefaults.standard.set(false, forKey: self.trackingEnabledKey)
                self.isTracking = false
                self.lastError = "Location permission was denied or restricted."
            } else if newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways {
                if self.shouldStartAfterPermission {
                    self.shouldStartAfterPermission = false
                    self.startTracking()
                } else if self.trackingEnabled {
                    self.resumeTrackingIfNeeded()
                }
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

            for location in filtered {
                self.processAcceptedLocation(location, receivedAt: now)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        visitsReceived += 1

        print("""
        [LocationTracker] visit received
          - coordinate: \(visit.coordinate.latitude), \(visit.coordinate.longitude)
          - arrivalDate: \(visit.arrivalDate)
          - departureDate: \(visit.departureDate)
          - horizontalAccuracy: \(visit.horizontalAccuracy) m
        """)

        guard visit.horizontalAccuracy > 0 && visit.horizontalAccuracy <= explorationEngine.maxAccuracy else { return }

        let location = CLLocation(
            coordinate: visit.coordinate,
            altitude: 0,
            horizontalAccuracy: visit.horizontalAccuracy,
            verticalAccuracy: -1,
            timestamp: visit.arrivalDate == Date.distantPast ? Date() : visit.arrivalDate
        )

        guard let cellID = explorationEngine.cellID(for: location) else { return }

        cellStore.upsertMany(
            cellIDs: [cellID],
            resolution: explorationEngine.resolution,
            seenAt: location.timestamp
        )
        discoveredCells = cellStore.cells
    }

    // MARK: - Debug simulation

    /// Feeds a realistic walking trajectory into the same processing path as real
    /// CoreLocation updates, without touching the location manager.
    #if DEBUG
    func simulateWalk() {
        let unionSquare = CLLocationCoordinate2D(latitude: 37.787994, longitude: -122.407437)
        let pathOffsets: [(north: Double, east: Double)] = [
            (0,     0),
            (70,    0),
            (130,  40),
            (190,   0),
            (190, -70),
            (120, -70),
            (60,  -70),
            (0,   -70),
            (-60, -40),
            (0,    0)
        ]
        let baseTimestamp = Date().addingTimeInterval(-60 * Double(pathOffsets.count - 1))

        Task { @MainActor [weak self] in
            for (index, offset) in pathOffsets.enumerated() {
                guard let self else { return }

                let coordinate = unionSquare.coordinate(
                    offsetByMetersNorth: offset.north,
                    east: offset.east
                )
                let timestamp = baseTimestamp.addingTimeInterval(60 * Double(index))
                let accuracy = Double.random(in: 5...10)
                let location = CLLocation(
                    coordinate: coordinate,
                    altitude: 0,
                    horizontalAccuracy: accuracy,
                    verticalAccuracy: -1,
                    timestamp: timestamp
                )

                self.processAcceptedLocation(location, receivedAt: Date())

                if index < pathOffsets.count - 1 {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                }
            }
        }
    }
    #endif

    private func processAcceptedLocation(_ location: CLLocation, receivedAt: Date) {
        locationsReceived += 1
        lastLocation = location
        lastError = nil

        let previous = previousAcceptedLocation
        let discoveredIDs = explorationEngine.discoveredCellIDs(
            from: previous,
            to: location
        )

        let newCells = cellStore.upsertMany(
            cellIDs: discoveredIDs,
            resolution: explorationEngine.resolution,
            seenAt: location.timestamp
        )

        currentH3CellID = explorationEngine.cellID(for: location)

        // Update segment statistics for the debug panel.
        if let previous = previous {
            let distance = location.distance(from: previous)
            let gap = location.timestamp.timeIntervalSince(previous.timestamp)
            let speed = gap > 0 ? distance / gap : 0

            lastSegmentDistance = distance
            lastSegmentTimeGap = gap
            lastSegmentSpeed = speed
            lastCellsAdded = newCells

            print("🧭 Segment distance=\(Int(distance))m gap=\(Int(gap))s speed=\(String(format: "%.1f", speed))m/s cellsAdded=\(newCells) current=\(currentH3CellID ?? "—")")
        } else {
            lastSegmentDistance = nil
            lastSegmentTimeGap = nil
            lastSegmentSpeed = nil
            lastCellsAdded = newCells
        }

        previousAcceptedLocation = location

        print("""
        [LocationTracker] location received
          - lat: \(location.coordinate.latitude)
          - lng: \(location.coordinate.longitude)
          - accuracy: \(location.horizontalAccuracy) m
          - speed: \(location.speed) m/s
          - timestamp: \(location.timestamp)
          - age: \(receivedAt.timeIntervalSince(location.timestamp)) s
          - cells discovered: \(discoveredCells.count)
        """)

        discoveredCells = cellStore.cells
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let message = error.localizedDescription

        Task { @MainActor [weak self] in
            self?.lastError = message
        }
        print("[LocationTracker] error: \(message)")
    }
}

private extension CLLocationCoordinate2D {
    /// Returns a coordinate shifted by the given north/east offsets in meters.
    func coordinate(offsetByMetersNorth north: Double, east: Double) -> CLLocationCoordinate2D {
        let metersPerDegreeLatitude = 111_320.0
        let metersPerDegreeLongitude = 111_320.0 * cos(latitude * .pi / 180)
        return CLLocationCoordinate2D(
            latitude: latitude + north / metersPerDegreeLatitude,
            longitude: longitude + east / metersPerDegreeLongitude
        )
    }
}
