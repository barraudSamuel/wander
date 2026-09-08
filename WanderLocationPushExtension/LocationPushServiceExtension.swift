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
    private var isPublishing = false
    private var consentOwnerID: String?
    private var consentRevision: String?

    func didReceiveLocationPushPayload(
        _ payload: [String: Any],
        completion: @escaping () -> Void
    ) {
        self.completion = completion
        guard let sharedDefaults = UserDefaults(
            suiteName: LocationPushSharedConfiguration.appGroupID
        ), sharedDefaults.bool(
            forKey: LocationPushSharedConfiguration.sharingEnabledKey
        ), let ownerID = sharedDefaults.string(
            forKey: LocationPushSharedConfiguration.ownerIDKey
        ), !ownerID.isEmpty,
        let revision = sharedDefaults.string(
            forKey: LocationPushSharedConfiguration.consentRevisionKey
        ), !revision.isEmpty else {
            finish()
            return
        }
        consentOwnerID = ownerID
        consentRevision = revision
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
        guard !didFinish, !isPublishing else { return }
        guard let location = locations.last,
              isValid(location) else {
            finish()
            return
        }
        isPublishing = true

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
              let ownerID = consentOwnerID, ownerID == user.uid,
              let consentRevision,
              Self.sharedConsentMatches(ownerID: ownerID, revision: consentRevision) else {
            return
        }

        _ = try await user.getIDTokenResult(forcingRefresh: false)
        let database = Firestore.firestore()
        let profileReference = database.collection("users").document(user.uid)
        let locationReference = database.collection("locations").document(user.uid)
        let profile = try await profileReference.getDocument(source: .server)
        let expectedRevision = profile.data()?[LocationSharingPolicy.revisionKey] as? String
        guard profile.exists,
              let initialProfile = profile.data(),
              LocationSharingPolicy.allowsPublication(
                  profile: initialProfile,
                  expectedRevision: expectedRevision,
                  sampledAt: location.timestamp
              ),
              !didFinish,
              Self.sharedConsentMatches(ownerID: ownerID, revision: consentRevision) else {
            return
        }

        _ = try await database.runTransaction { transaction, errorPointer -> Any? in
            do {
                let currentProfile = try transaction.getDocument(profileReference)
                guard Self.sharedConsentMatches(
                    ownerID: ownerID,
                    revision: consentRevision
                ), currentProfile.exists,
                let profileData = currentProfile.data(),
                LocationSharingPolicy.allowsPublication(
                    profile: profileData,
                    expectedRevision: expectedRevision,
                    sampledAt: location.timestamp
                ), let rawDisplayName = profileData["displayName"] as? String else {
                    return nil
                }
                let displayName = rawDisplayName.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                guard !displayName.isEmpty, displayName.count <= 50 else { return nil }
                let previousLocation = try transaction.getDocument(locationReference)

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
                if let enteredAt = Self.preservedSpotEnteredAt(
                    from: previousLocation,
                    for: location,
                    resumedAt: (profileData[LocationSharingPolicy.resumedAtKey] as? Timestamp)?
                        .dateValue()
                ) {
                    data["spotEnteredAt"] = enteredAt
                }
                transaction.setData(data, forDocument: locationReference)
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }

    nonisolated private static func sharedConsentMatches(
        ownerID: String,
        revision: String
    ) -> Bool {
        guard let defaults = UserDefaults(
            suiteName: LocationPushSharedConfiguration.appGroupID
        ) else { return false }
        return defaults.bool(forKey: LocationPushSharedConfiguration.sharingEnabledKey)
            && defaults.string(forKey: LocationPushSharedConfiguration.ownerIDKey) == ownerID
            && defaults.string(forKey: LocationPushSharedConfiguration.consentRevisionKey) == revision
    }

    nonisolated private static func preservedSpotEnteredAt(
        from snapshot: DocumentSnapshot,
        for location: CLLocation,
        resumedAt: Date?
    ) -> Timestamp? {
        guard let data = snapshot.data(),
              let previousGeoPoint = data["location"] as? GeoPoint,
              let previousAccuracy = data["horizontalAccuracy"] as? Double,
              previousAccuracy > 0,
              let enteredAt = data["spotEnteredAt"] as? Timestamp,
              enteredAt.dateValue() <= location.timestamp else {
            return nil
        }
        if let resumedAt, enteredAt.dateValue() < resumedAt {
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
