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
    private var previousAcceptedCellID: String?
    private var pendingHeatMapUpdates: [String: CellHeatMapUpdate] = [:]
    private var heatMapFlushTimer: Timer?
    private let heatMapFlushInterval: TimeInterval = 30

    // Persistence key for the user's tracking intention.
    private let trackingEnabledKey = "trackingEnabled"
    private let backgroundTrackingEnabledKey = "backgroundTrackingEnabled"

    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var lastLocation: CLLocation?
    @Published var locationsReceived: Int = 0
    @Published var isTracking: Bool = false
    @Published var trackingEnabled: Bool
    @Published var backgroundTrackingEnabled: Bool
    @Published var trackingMode: TrackingMode = .foreground
    @Published var visitsReceived: Int = 0
    @Published var lastError: String?
    @Published var discoveredCells: [DiscoveredCell] = []
    @Published var currentH3CellID: String?
    @Published var heatMapCellData: [String: (duration: TimeInterval, visitCount: Int)] = [:]

    /// Newly discovered cell IDs from the most recent local processing pass.
    /// Exploration cells stay on-device and are not shared with friends.
    @Published var newlyDiscoveredCellIDs: Set<String> = []

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
        self.backgroundTrackingEnabled = UserDefaults.standard.bool(
            forKey: backgroundTrackingEnabledKey
        )
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 20
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.allowsBackgroundLocationUpdates = backgroundTrackingEnabled
        locationManager.showsBackgroundLocationIndicator = true
    }

    func configure(with context: ModelContext) {
        cellStore.configure(with: context)
        discoveredCells = cellStore.cells
        rebuildHeatMapData()
    }

    // MARK: - Heat map persistence

    private func scheduleHeatMapFlush() {
        heatMapFlushTimer?.invalidate()
        heatMapFlushTimer = Timer.scheduledTimer(withTimeInterval: heatMapFlushInterval, repeats: false) { [weak self] _ in
            self?.flushHeatMapUpdates()
        }
    }

    private func flushHeatMapUpdates() {
        guard !pendingHeatMapUpdates.isEmpty else { return }
        let updates = Array(pendingHeatMapUpdates.values)
        pendingHeatMapUpdates.removeAll()
        cellStore.applyHeatMapUpdates(updates, resolution: explorationEngine.resolution, seenAt: Date())
        discoveredCells = cellStore.cells
        rebuildHeatMapData()
    }

    private func rebuildHeatMapData() {
        var data: [String: (duration: TimeInterval, visitCount: Int)] = [:]
        for cell in discoveredCells {
            if cell.duration > 0 || cell.visitCount > 1 {
                data[cell.id] = (cell.duration, cell.visitCount)
            }
        }
        heatMapCellData = data
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

    /// Requests foreground access first. The optional background upgrade is
    /// presented later, once the user has experienced the core exploration flow.
    private func requestPermissionIfNeeded() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            break
        }
    }

    /// Applies the user's explicit background-tracking preference and, when
    /// necessary, asks iOS to upgrade the foreground permission.
    func setBackgroundTrackingEnabled(_ isEnabled: Bool) {
        backgroundTrackingEnabled = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: backgroundTrackingEnabledKey)
        locationManager.allowsBackgroundLocationUpdates = isEnabled

        guard isEnabled else {
            locationManager.stopMonitoringSignificantLocationChanges()
            locationManager.stopMonitoringVisits()
            return
        }

        if authorizationStatus == .authorizedWhenInUse {
            locationManager.requestAlwaysAuthorization()
        } else if authorizationStatus == .notDetermined {
            requestPermissionIfNeeded()
        }

        if trackingEnabled, isTracking {
            applyTrackingMode(.foreground)
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
            lastError = "Les services de localisation sont désactivés sur cet appareil."
            isTracking = false
            trackingEnabled = false
            UserDefaults.standard.set(false, forKey: trackingEnabledKey)
            return
        }

        switch authorizationStatus {
        case .notDetermined:
            shouldStartAfterPermission = true
            requestPermissionIfNeeded()
            return
        case .restricted, .denied:
            lastError = "L’accès à la localisation est refusé ou restreint."
            trackingEnabled = false
            UserDefaults.standard.set(false, forKey: trackingEnabledKey)
            return
        case .authorizedAlways, .authorizedWhenInUse:
            break
        @unknown default:
            lastError = "L’état de l’autorisation de localisation est inconnu."
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
        heatMapFlushTimer?.invalidate()
        flushHeatMapUpdates()
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        locationManager.stopMonitoringVisits()
    }

    /// Stops location services and removes every user-owned value persisted on
    /// this device. System location permissions are managed by iOS and remain
    /// unchanged.
    func resetLocalData() throws {
        stopTracking()
        setBackgroundTrackingEnabled(false)

        heatMapFlushTimer?.invalidate()
        heatMapFlushTimer = nil
        pendingHeatMapUpdates.removeAll()

        try cellStore.deleteAll()

        UserDefaults.standard.removeObject(forKey: trackingEnabledKey)
        UserDefaults.standard.removeObject(forKey: backgroundTrackingEnabledKey)

        lastLocation = nil
        previousAcceptedLocation = nil
        previousAcceptedCellID = nil
        currentH3CellID = nil
        newlyDiscoveredCellIDs = []
        discoveredCells = []
        heatMapCellData = [:]
        locationsReceived = 0
        visitsReceived = 0
        lastSegmentDistance = nil
        lastSegmentTimeGap = nil
        lastSegmentSpeed = nil
        lastCellsAdded = 0
        lastError = nil
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
            trackingEnabled = false
            lastError = "Les services de localisation sont désactivés sur cet appareil."
            UserDefaults.standard.set(false, forKey: trackingEnabledKey)
            return
        }

        isTracking = true
        applyTrackingMode(.foreground)
    }

    /// Applies accuracy/distance settings and starts or stops the appropriate location services.
    /// Only starts services if the user has enabled tracking.
    func applyTrackingMode(_ mode: TrackingMode) {
        trackingMode = mode

        if mode == .background, !backgroundTrackingEnabled {
            locationManager.stopUpdatingLocation()
            locationManager.stopMonitoringSignificantLocationChanges()
            locationManager.stopMonitoringVisits()
            return
        }

        let useContinuousUpdates: Bool

        switch mode {
        case .foreground:
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.distanceFilter = 20
            locationManager.pausesLocationUpdatesAutomatically = false
            useContinuousUpdates = true

        case .background:
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locationManager.distanceFilter = 75
            locationManager.pausesLocationUpdatesAutomatically = true
            useContinuousUpdates = true

        case .lowPower:
            locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
            locationManager.distanceFilter = 500
            locationManager.pausesLocationUpdatesAutomatically = true
            useContinuousUpdates = false
        }

        startServicesIfTracking(continuousUpdates: useContinuousUpdates)
    }

    private func startServicesIfTracking(continuousUpdates: Bool) {
        guard trackingEnabled else { return }

        if continuousUpdates {
            locationManager.startUpdatingLocation()
        } else {
            locationManager.stopUpdatingLocation()
        }
        if backgroundTrackingEnabled {
            locationManager.startMonitoringSignificantLocationChanges()
            locationManager.startMonitoringVisits()
        } else {
            locationManager.stopMonitoringSignificantLocationChanges()
            locationManager.stopMonitoringVisits()
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
                self.lastError = "L’accès à la localisation a été refusé ou restreint."
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

        let existingBefore = Set(cellStore.cells.map { $0.id })
        let newIDs = discoveredIDs.subtracting(existingBefore)

        let newCells = cellStore.upsertMany(
            cellIDs: discoveredIDs,
            resolution: explorationEngine.resolution,
            seenAt: location.timestamp
        )

        newlyDiscoveredCellIDs = newIDs

        let cellID = explorationEngine.cellID(for: location)
        currentH3CellID = cellID

        if let previous = previous, let cellID = cellID {
            let timeDelta = location.timestamp.timeIntervalSince(previous.timestamp)
            if timeDelta > 0, timeDelta <= explorationEngine.maxGapToConnect {
                let attributedCellID: String
                let isNewCell: Bool

                if let previousCell = previousAcceptedCellID, previousCell != cellID {
                    attributedCellID = previousCell
                    isNewCell = true
                } else {
                    attributedCellID = cellID
                    isNewCell = previousAcceptedCellID == nil
                }

                var update = pendingHeatMapUpdates[attributedCellID] ?? CellHeatMapUpdate(
                    cellID: attributedCellID,
                    duration: 0,
                    visitIncrement: 0
                )
                update = CellHeatMapUpdate(
                    cellID: attributedCellID,
                    duration: update.duration + timeDelta,
                    visitIncrement: update.visitIncrement
                )
                pendingHeatMapUpdates[attributedCellID] = update

                if isNewCell, let _ = previousAcceptedCellID {
                    var newUpdate = pendingHeatMapUpdates[cellID] ?? CellHeatMapUpdate(
                        cellID: cellID,
                        duration: 0,
                        visitIncrement: 0
                    )
                    newUpdate = CellHeatMapUpdate(
                        cellID: cellID,
                        duration: newUpdate.duration,
                        visitIncrement: newUpdate.visitIncrement + 1
                    )
                    pendingHeatMapUpdates[cellID] = newUpdate
                }

                scheduleHeatMapFlush()
            }
        } else if let cellID = cellID, previousAcceptedCellID == nil {
            var update = pendingHeatMapUpdates[cellID] ?? CellHeatMapUpdate(
                cellID: cellID,
                duration: 0,
                visitIncrement: 0
            )
            update = CellHeatMapUpdate(
                cellID: cellID,
                duration: update.duration,
                visitIncrement: update.visitIncrement + 1
            )
            pendingHeatMapUpdates[cellID] = update
        }

        previousAcceptedCellID = cellID

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
