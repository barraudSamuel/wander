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

    /// A normalized location fix used by the spot-presence state machine.
    private struct SpotSample {
        let coordinate: CLLocationCoordinate2D
        let horizontalAccuracy: CLLocationAccuracy
        let timestamp: Date

        init?(_ location: CLLocation) {
            guard CLLocationCoordinate2DIsValid(location.coordinate),
                  location.horizontalAccuracy.isFinite,
                  location.horizontalAccuracy > 0,
                  location.timestamp.timeIntervalSinceReferenceDate.isFinite else {
                return nil
            }

            coordinate = location.coordinate
            horizontalAccuracy = location.horizontalAccuracy
            timestamp = location.timestamp
        }

        func distance(to other: SpotSample) -> CLLocationDistance {
            CLLocation(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            ).distance(
                from: CLLocation(
                    latitude: other.coordinate.latitude,
                    longitude: other.coordinate.longitude
                )
            )
        }
    }

    private enum SpotTransitionDecision {
        /// The fix belongs to the current spot (or is too uncertain to leave it).
        case remain
        /// One confidently-outside fix is not enough; wait for a matching one.
        case awaitConfirmation(SpotSample)
        /// Two consecutive outside fixes agree on the same prospective spot.
        case confirm(firstSample: SpotSample)
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
    private let currentSpotAnchorLatitudeKey = "currentSpotAnchorLatitude"
    private let currentSpotAnchorLongitudeKey = "currentSpotAnchorLongitude"
    private let currentSpotAnchorAccuracyKey = "currentSpotAnchorAccuracy"
    private let currentSpotEnteredAtKey = "currentSpotEnteredAt"
    private let latestProcessedSpotSampleAtKey = "latestProcessedSpotSampleAt"

    /// These keys belonged to the former H3-cell presence implementation. H3 is
    /// still exposed for discovery/debugging, but it is no longer presence state.
    private let obsoleteH3PresenceKeys = [
        "currentH3CellID",
        "currentH3CellEnteredAt",
        "currentH3CellLatestSampledAt"
    ]

    private let spotRadius: CLLocationDistance = 40
    private let maximumSpotAccuracyAllowance: CLLocationAccuracy = 30
    private let maximumSpotSampleAge: TimeInterval = 5 * 60
    private let maximumSpotSampleFutureSkew: TimeInterval = 60

    private var currentSpotAnchor: SpotSample?
    private var pendingSpotCandidate: SpotSample?
    private var latestProcessedSpotSampleAt: Date?

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
    @Published private(set) var currentH3CellID: String?
    @Published private(set) var currentSpotEnteredAt: Date?
    @Published var heatMapCellData: [String: (duration: TimeInterval, visitCount: Int)] = [:]
    @Published private(set) var heatMapRevision = 0

    var discoveredCellIDs: Set<String> {
        cellStore.cellIDs
    }

    /// Newly discovered cell IDs from the most recent local processing pass.
    /// The complete local set is mirrored to Firebase by `FriendSyncService`
    /// and remains readable only by accepted friends.
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
        restoreCurrentSpotPresence()
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
        heatMapRevision &+= 1
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

        switch authorizationStatus {
        case .notDetermined:
            shouldStartAfterPermission = true
            requestPermissionIfNeeded()
            return
        case .restricted, .denied:
            lastError = "L’accès à la localisation est refusé ou restreint."
            trackingEnabled = false
            UserDefaults.standard.set(false, forKey: trackingEnabledKey)
            clearCurrentPresence()
            return
        case .authorizedAlways, .authorizedWhenInUse:
            break
        @unknown default:
            lastError = "L’état de l’autorisation de localisation est inconnu."
            trackingEnabled = false
            UserDefaults.standard.set(false, forKey: trackingEnabledKey)
            clearCurrentPresence()
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
        clearCurrentPresence()
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
        newlyDiscoveredCellIDs = []
        discoveredCells = []
        let hadHeatMapData = !heatMapCellData.isEmpty
        heatMapCellData = [:]
        if hadHeatMapData {
            heatMapRevision &+= 1
        }
        locationsReceived = 0
        visitsReceived = 0
        lastSegmentDistance = nil
        lastSegmentTimeGap = nil
        lastSegmentSpeed = nil
        lastCellsAdded = 0
        lastError = nil
    }

    // MARK: - Tracking resume & modes

    private func restoreCurrentSpotPresence() {
        let defaults = UserDefaults.standard
        removeObsoleteH3PresencePersistence(from: defaults)

        let hasLocationPermission = authorizationStatus == .authorizedWhenInUse
            || authorizationStatus == .authorizedAlways
        guard trackingEnabled,
              hasLocationPermission,
              let latitude = persistedDouble(
                  forKey: currentSpotAnchorLatitudeKey,
                  from: defaults
              ),
              let longitude = persistedDouble(
                  forKey: currentSpotAnchorLongitudeKey,
                  from: defaults
              ),
              let accuracy = persistedDouble(
                  forKey: currentSpotAnchorAccuracyKey,
                  from: defaults
              ),
              let enteredAt = defaults.object(forKey: currentSpotEnteredAtKey) as? Date,
              let latestSampleAt = defaults.object(
                  forKey: latestProcessedSpotSampleAtKey
              ) as? Date,
              latitude.isFinite,
              longitude.isFinite,
              accuracy.isFinite,
              accuracy > 0,
              accuracy <= explorationEngine.maxAccuracy,
              enteredAt.timeIntervalSinceReferenceDate.isFinite,
              latestSampleAt.timeIntervalSinceReferenceDate.isFinite,
              enteredAt <= latestSampleAt else {
            clearCurrentSpotPresence()
            return
        }

        let coordinate = CLLocationCoordinate2D(
            latitude: latitude,
            longitude: longitude
        )
        let restoredLocation = CLLocation(
            coordinate: coordinate,
            altitude: 0,
            horizontalAccuracy: accuracy,
            verticalAccuracy: -1,
            timestamp: enteredAt
        )
        guard let restoredAnchor = SpotSample(restoredLocation) else {
            clearCurrentSpotPresence()
            return
        }

        currentSpotAnchor = restoredAnchor
        pendingSpotCandidate = nil
        latestProcessedSpotSampleAt = latestSampleAt
        currentSpotEnteredAt = enteredAt
    }

    /// Advances the live spot state without deciding whether exploration should
    /// accept the same fix. Exploration deliberately continues for every accepted
    /// Core Location sample, including samples too old/future for presence.
    private func updateCurrentSpotPresence(
        with location: CLLocation,
        receivedAt: Date
    ) {
        guard let sample = SpotSample(location) else { return }

        // A replayed or out-of-order fix cannot roll the live spot backwards.
        if let latestProcessedSpotSampleAt,
           sample.timestamp <= latestProcessedSpotSampleAt {
            return
        }

        let sampleAge = receivedAt.timeIntervalSince(sample.timestamp)
        guard sampleAge.isFinite,
              sampleAge <= maximumSpotSampleAge,
              sampleAge >= -maximumSpotSampleFutureSkew else {
            return
        }

        latestProcessedSpotSampleAt = sample.timestamp

        guard let currentSpotAnchor, currentSpotEnteredAt != nil else {
            establishCurrentSpot(at: sample, enteredAt: sample.timestamp)
            return
        }

        let decision = spotTransitionDecision(
            for: sample,
            relativeTo: currentSpotAnchor,
            pendingCandidate: pendingSpotCandidate
        )

        switch decision {
        case .remain:
            pendingSpotCandidate = nil
        case .awaitConfirmation(let firstSample):
            pendingSpotCandidate = firstSample
        case .confirm(let firstSample):
            // The first of the two agreeing B samples is the moment B began.
            establishCurrentSpot(at: firstSample, enteredAt: firstSample.timestamp)
            return
        }

        persistCurrentSpotPresence()
    }

    /// Deterministic transition scenarios:
    /// - Repeated A samples preserve A and its original `enteredAt`, regardless of
    ///   the time gap between fixes.
    /// - A single stray B sample only becomes a candidate; a following A sample
    ///   cancels it.
    /// - Two consecutive, mutually consistent B samples confirm B, timestamped at
    ///   the first B sample.
    private func spotTransitionDecision(
        for sample: SpotSample,
        relativeTo anchor: SpotSample,
        pendingCandidate: SpotSample?
    ) -> SpotTransitionDecision {
        guard isConfidentlyOutside(sample, relativeTo: anchor) else {
            return .remain
        }

        guard let pendingCandidate else {
            return .awaitConfirmation(sample)
        }

        guard areMutuallyConsistent(pendingCandidate, sample) else {
            // This outside fix starts a fresh consecutive pair.
            return .awaitConfirmation(sample)
        }

        return .confirm(firstSample: pendingCandidate)
    }

    private func isConfidentlyOutside(
        _ sample: SpotSample,
        relativeTo anchor: SpotSample
    ) -> Bool {
        let uncertainty = spotAccuracyAllowance(between: anchor, and: sample)
        return sample.distance(to: anchor) > spotRadius + uncertainty
    }

    private func areMutuallyConsistent(
        _ first: SpotSample,
        _ second: SpotSample
    ) -> Bool {
        let uncertainty = spotAccuracyAllowance(between: first, and: second)
        return first.distance(to: second) <= spotRadius + uncertainty
    }

    private func spotAccuracyAllowance(
        between first: SpotSample,
        and second: SpotSample
    ) -> CLLocationAccuracy {
        min(
            max(first.horizontalAccuracy, second.horizontalAccuracy),
            maximumSpotAccuracyAllowance
        )
    }

    private func establishCurrentSpot(at anchor: SpotSample, enteredAt: Date) {
        currentSpotAnchor = anchor
        pendingSpotCandidate = nil
        currentSpotEnteredAt = enteredAt
        persistCurrentSpotPresence()
    }

    private func persistCurrentSpotPresence() {
        guard let currentSpotAnchor,
              let currentSpotEnteredAt,
              let latestProcessedSpotSampleAt else {
            removeCurrentSpotPresencePersistence(from: .standard)
            return
        }

        let defaults = UserDefaults.standard
        defaults.set(
            currentSpotAnchor.coordinate.latitude,
            forKey: currentSpotAnchorLatitudeKey
        )
        defaults.set(
            currentSpotAnchor.coordinate.longitude,
            forKey: currentSpotAnchorLongitudeKey
        )
        defaults.set(
            currentSpotAnchor.horizontalAccuracy,
            forKey: currentSpotAnchorAccuracyKey
        )
        defaults.set(currentSpotEnteredAt, forKey: currentSpotEnteredAtKey)
        defaults.set(
            latestProcessedSpotSampleAt,
            forKey: latestProcessedSpotSampleAtKey
        )
    }

    private func clearCurrentSpotPresence() {
        currentSpotAnchor = nil
        pendingSpotCandidate = nil
        latestProcessedSpotSampleAt = nil
        currentSpotEnteredAt = nil

        let defaults = UserDefaults.standard
        removeCurrentSpotPresencePersistence(from: defaults)
        removeObsoleteH3PresencePersistence(from: defaults)
    }

    private func clearCurrentPresence() {
        clearCurrentSpotPresence()
        currentH3CellID = nil
    }

    private func removeCurrentSpotPresencePersistence(from defaults: UserDefaults) {
        defaults.removeObject(forKey: currentSpotAnchorLatitudeKey)
        defaults.removeObject(forKey: currentSpotAnchorLongitudeKey)
        defaults.removeObject(forKey: currentSpotAnchorAccuracyKey)
        defaults.removeObject(forKey: currentSpotEnteredAtKey)
        defaults.removeObject(forKey: latestProcessedSpotSampleAtKey)
    }

    private func removeObsoleteH3PresencePersistence(from defaults: UserDefaults) {
        for key in obsoleteH3PresenceKeys {
            defaults.removeObject(forKey: key)
        }
    }

    private func persistedDouble(
        forKey key: String,
        from defaults: UserDefaults
    ) -> Double? {
        (defaults.object(forKey: key) as? NSNumber)?.doubleValue
    }

    /// Resumes location services if the user previously opted in and permission is valid.
    /// Call this from app launch and when the authorization status changes.
    func resumeTrackingIfNeeded() {
        guard trackingEnabled else { return }

        let status = locationManager.authorizationStatus
        guard status == .authorizedAlways || status == .authorizedWhenInUse else {
            isTracking = false
            clearCurrentPresence()
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

            if newStatus != .authorizedWhenInUse
                && newStatus != .authorizedAlways {
                self.clearCurrentPresence()
            }

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
        // Core Location may deliver a callback that was already queued when the
        // user stopped tracking or revoked permission.
        guard trackingEnabled else { return }

        locationsReceived += 1
        lastError = nil

        let cellID = explorationEngine.cellID(for: location)
        updateCurrentSpotPresence(with: location, receivedAt: receivedAt)
        currentH3CellID = cellID

        // ContentView observes `lastLocation` and reads `currentSpotEnteredAt` in
        // that callback, so the spot state must be fully updated first.
        lastLocation = location

        let previous = previousAcceptedLocation
        let discoveredIDs = explorationEngine.discoveredCellIDs(
            from: previous,
            to: location
        )

        let newIDs = discoveredIDs.subtracting(cellStore.cellIDs)

        let newCells = cellStore.upsertMany(
            cellIDs: discoveredIDs,
            resolution: explorationEngine.resolution,
            seenAt: location.timestamp
        )

        newlyDiscoveredCellIDs = newIDs

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
        let locationError = error as? CLError
        let message = locationError?.code == .denied
            ? "La localisation est indisponible ou son accès a été refusé."
            : error.localizedDescription

        Task { @MainActor [weak self] in
            guard let self else { return }
            if locationError?.code == .denied {
                self.isTracking = false
                self.trackingEnabled = false
                UserDefaults.standard.set(false, forKey: self.trackingEnabledKey)
                self.clearCurrentPresence()
            }
            self.lastError = message
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
