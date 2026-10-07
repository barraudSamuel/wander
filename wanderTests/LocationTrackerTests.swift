import CoreLocation
import XCTest
@testable import wander

@MainActor
final class LocationTrackerTests: XCTestCase {
    func testFirstBackgroundRequestAsksForForegroundThenAlwaysOnce() {
        var request = LocationTracker.BackgroundAuthorizationRequest()

        XCTAssertEqual(request.begin(with: .notDetermined), .whenInUse)
        XCTAssertNil(request.receive(.notDetermined))
        XCTAssertEqual(request.receive(.authorizedWhenInUse), .always)
        XCTAssertNil(request.receive(.authorizedWhenInUse))
    }

    func testExistingForegroundPermissionRequestsAlwaysDirectly() {
        var request = LocationTracker.BackgroundAuthorizationRequest()

        XCTAssertEqual(request.begin(with: .authorizedWhenInUse), .always)
        // Keeping While Using may produce no callback at all. Neither a later
        // callback nor a Settings refresh should start another request.
        XCTAssertNil(request.receive(.authorizedWhenInUse))
    }

    func testRestoringPreferenceOrReturningFromSettingsDoesNotRequestPermission() {
        var request = LocationTracker.BackgroundAuthorizationRequest()

        XCTAssertNil(request.receive(.authorizedWhenInUse))
        XCTAssertNil(request.receive(.authorizedAlways))
        XCTAssertNil(request.receive(.authorizedWhenInUse))
        XCTAssertNil(request.receive(.notDetermined))
    }

    func testCancellingBackgroundRequestPreventsUpgradeAfterForegroundGrant() {
        var request = LocationTracker.BackgroundAuthorizationRequest()

        XCTAssertEqual(request.begin(with: .notDetermined), .whenInUse)
        request.cancel()
        XCTAssertNil(request.receive(.authorizedWhenInUse))
    }

    func testRefusalOrRestrictionCancelsPendingUpgrade() {
        for status: CLAuthorizationStatus in [.denied, .restricted] {
            var request = LocationTracker.BackgroundAuthorizationRequest()
            XCTAssertEqual(request.begin(with: .notDetermined), .whenInUse)
            XCTAssertNil(request.receive(status))
            XCTAssertNil(request.receive(.authorizedWhenInUse))
        }
    }

    func testAlwaysGrantCompletesPendingRequestAndRevocationDoesNotReprompt() {
        var request = LocationTracker.BackgroundAuthorizationRequest()

        XCTAssertEqual(request.begin(with: .notDetermined), .whenInUse)
        XCTAssertNil(request.receive(.authorizedAlways))
        XCTAssertNil(request.receive(.authorizedWhenInUse))
    }

    func testAlreadyAlwaysDeniedOrRestrictedDoesNotAskAgain() {
        for status: CLAuthorizationStatus in [.authorizedAlways, .denied, .restricted] {
            var request = LocationTracker.BackgroundAuthorizationRequest()
            XCTAssertNil(request.begin(with: status))
            XCTAssertNil(request.receive(.authorizedWhenInUse))
        }
    }
}
