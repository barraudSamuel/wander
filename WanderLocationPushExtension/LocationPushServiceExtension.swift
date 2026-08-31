//
//  LocationPushServiceExtension.swift
//  WanderLocationPushExtension
//

import CoreLocation
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation

final class LocationPushServiceExtension: NSObject,
    CLLocationPushServiceExtension,
    CLLocationManagerDelegate {

    private var completion: (() -> Void)?
    private var locationManager: CLLocationManager?
    private var serviceSession: CLServiceSession?
    private var didFinish = false

    func didReceiveLocationPushPayload(
        _ payload: [String: Any],
        completion: @escaping () -> Void
    ) {
        self.completion = completion
        guard UserDefaults(
            suiteName: LocationPushSharedConfiguration.appGroupID
        )?.bool(
            forKey: LocationPushSharedConfiguration.sharingEnabledKey
        ) == true else {
            finish()
            return
        }
        serviceSession = CLServiceSession(authorization: .always)

        let manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager = manager
        manager.requestLocation()
    }

    func serviceExtensionWillTerminate() {
        finish()
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last,
              isValid(location) else {
            finish()
            return
        }

        Task {
            defer { finish() }
            do {
                try await publish(location)
            } catch {
                // The requester times out while preserving the last known position.
            }
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        finish()
    }

    private func publish(_ location: CLLocation) async throws {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        try SharedFirebaseAuthConfiguration.configureExtension()

        guard let user = Auth.auth().currentUser,
              !user.isAnonymous,
              user.providerData.contains(where: {
                  $0.providerID == "apple.com"
              }),
              let sharedDefaults = UserDefaults(
                  suiteName: LocationPushSharedConfiguration.appGroupID
              ),
              sharedDefaults.bool(
                  forKey: LocationPushSharedConfiguration.sharingEnabledKey
              ),
              sharedDefaults.string(
                  forKey: LocationPushSharedConfiguration.ownerIDKey
              ) == user.uid else {
            return
        }

        _ = try await user.getIDTokenResult(forcingRefresh: false)
        let database = Firestore.firestore()
        let profileReference = database.collection("users").document(user.uid)
        let locationReference = database.collection("locations").document(user.uid)
        async let profileSnapshot = profileReference.getDocument(source: .server)
        async let previousLocationSnapshot = locationReference.getDocument(source: .server)
        let (profile, previousLocation) = try await (
            profileSnapshot,
            previousLocationSnapshot
        )

        guard profile.exists,
              profile.data()?["deletionRequestedAt"] == nil,
              let rawDisplayName = profile.data()?["displayName"] as? String else {
            return
        }
        let displayName = rawDisplayName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !displayName.isEmpty, displayName.count <= 50 else { return }

        var data: [String: Any] = [
            "location": GeoPoint(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            ),
            "displayName": displayName,
            "horizontalAccuracy": location.horizontalAccuracy,
            "sampledAt": Timestamp(date: location.timestamp),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if let preservedSpotEnteredAt = preservedSpotEnteredAt(
            from: previousLocation,
            for: location
        ) {
            data["spotEnteredAt"] = preservedSpotEnteredAt
        }

        try await locationReference.setData(data)
    }

    private func preservedSpotEnteredAt(
        from snapshot: DocumentSnapshot,
        for location: CLLocation
    ) -> Timestamp? {
        guard let data = snapshot.data(),
              let previousGeoPoint = data["location"] as? GeoPoint,
              let previousAccuracy = data["horizontalAccuracy"] as? Double,
              previousAccuracy > 0,
              let enteredAt = data["spotEnteredAt"] as? Timestamp,
              enteredAt.dateValue() <= location.timestamp else {
            return nil
        }

        let previousLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(
                latitude: previousGeoPoint.latitude,
                longitude: previousGeoPoint.longitude
            ),
            altitude: 0,
            horizontalAccuracy: previousAccuracy,
            verticalAccuracy: -1,
            timestamp: enteredAt.dateValue()
        )
        let uncertainty = min(
            max(previousAccuracy, location.horizontalAccuracy),
            30
        )
        return location.distance(from: previousLocation) <= 40 + uncertainty
            ? enteredAt
            : nil
    }

    private func isValid(_ location: CLLocation) -> Bool {
        let age = Date().timeIntervalSince(location.timestamp)
        return CLLocationCoordinate2DIsValid(location.coordinate)
            && location.horizontalAccuracy > 0
            && location.horizontalAccuracy <= 1_000
            && age.isFinite
            && age >= -60
            && age < 5 * 60
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        locationManager?.delegate = nil
        locationManager = nil
        serviceSession?.invalidate()
        serviceSession = nil
        let completion = completion
        self.completion = nil
        completion?()
    }
}
