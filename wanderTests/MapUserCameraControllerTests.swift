import MapKit
import XCTest
@testable import wander

@MainActor
final class MapUserCameraControllerTests: XCTestCase {
    private let position = CLLocationCoordinate2D(latitude: 10.76, longitude: 106.66)

    func testRepeatedTapsDuringAndAfterRecenterDoNotRestartCamera() async throws {
        let fixture = try await makeFixture()
        defer { fixture.close() }

        fixture.controller.recenter(on: fixture.map, at: position)
        fixture.controller.recenter(on: fixture.map, at: position)
        XCTAssertEqual(fixture.map.regionCommands, 1)
        try await settle(fixture, at: position)
        let distance = fixture.map.camera.centerCoordinateDistance

        for _ in 0..<5 {
            fixture.controller.recenter(on: fixture.map, at: position)
        }
        XCTAssertEqual(fixture.map.regionCommands, 1)
        XCTAssertEqual(fixture.map.centerCommands, 0)
        XCTAssertEqual(fixture.map.camera.centerCoordinateDistance, distance, accuracy: 0.01)
        XCTAssertTrue(fixture.controller.isFollowing)
        XCTAssertEqual(fixture.map.userTrackingMode, .none)
        XCTAssertTrue(fixture.map.trackingCommands.isEmpty)
    }

    func testAlreadyCenteredTapEnablesFollowingWithoutMovingCamera() async throws {
        let fixture = try await makeFixture()
        defer { fixture.close() }
        fixture.map.setRegion(MapUserCameraController.focusedRegion(at: position), animated: false)
        try await settle(fixture, at: position)
        fixture.map.clearCommands()

        fixture.controller.recenter(on: fixture.map, at: position)

        XCTAssertTrue(fixture.controller.isFollowing)
        XCTAssertEqual(fixture.map.regionCommands, 0)
        XCTAssertEqual(fixture.map.centerCommands, 0)
        XCTAssertTrue(fixture.map.trackingCommands.isEmpty)
    }

    func testLocationsReceivedDuringRecenterFollowOnlyLatestPositionWithoutZooming() async throws {
        let fixture = try await makeFixture()
        defer { fixture.close() }
        fixture.controller.recenter(on: fixture.map, at: position)
        let intermediate = CLLocationCoordinate2D(latitude: 10.761, longitude: 106.66)
        let latest = CLLocationCoordinate2D(latitude: 10.762, longitude: 106.66)
        fixture.controller.updateLocation(intermediate, on: fixture.map)
        fixture.controller.updateLocation(latest, on: fixture.map)
        XCTAssertEqual(fixture.map.centerCommands, 0)

        try await settle(fixture, at: latest)
        XCTAssertEqual(fixture.map.regionCommands, 1)
        XCTAssertEqual(fixture.map.centerCommands, 1)
        XCTAssertEqual(fixture.map.spanBeforeCenter?.latitudeDelta ?? 0,
                       fixture.map.region.span.latitudeDelta, accuracy: 0.00001)
        XCTAssertTrue(fixture.map.trackingCommands.isEmpty)

        fixture.controller.updateLocation(latest, on: fixture.map)
        fixture.controller.regionDidChange(on: fixture.map)
        XCTAssertEqual(fixture.map.centerCommands, 1)
    }

    func testStoppingFollowDiscardsQueuedPositionsAndDoesNotResumeAfterCompletion() async throws {
        let fixture = try await makeFixture()
        defer { fixture.close() }
        fixture.controller.recenter(on: fixture.map, at: position)
        fixture.controller.updateLocation(
            CLLocationCoordinate2D(latitude: 10.762, longitude: 106.66), on: fixture.map
        )
        fixture.controller.stopFollowing()
        try await settle(fixture, at: position)
        fixture.controller.regionDidChange(on: fixture.map)
        fixture.controller.updateLocation(
            CLLocationCoordinate2D(latitude: 10.764, longitude: 106.66), on: fixture.map
        )

        XCTAssertFalse(fixture.controller.isFollowing)
        XCTAssertEqual(fixture.map.centerCommands, 0)
        XCTAssertEqual(fixture.map.regionCommands, 1)
    }

    func testRecenterAfterManualZoomRestoresSameScaleAndResumesFollowing() async throws {
        let fixture = try await makeFixture()
        defer { fixture.close() }
        fixture.controller.recenter(on: fixture.map, at: position)
        try await settle(fixture, at: position)
        let normalSpan = fixture.map.region.span

        for meters in [100.0, 50_000.0] {
            fixture.controller.stopFollowing()
            let completions = fixture.delegate.completions
            fixture.map.setRegion(MKCoordinateRegion(
                center: position, latitudinalMeters: meters, longitudinalMeters: meters
            ), animated: false)
            try await eventually { fixture.delegate.completions > completions }
            fixture.map.clearCommands()
            fixture.controller.recenter(on: fixture.map, at: position)
            try await settle(fixture, at: position)

            XCTAssertEqual(fixture.map.region.span.latitudeDelta,
                           normalSpan.latitudeDelta, accuracy: normalSpan.latitudeDelta * 0.01)
            XCTAssertEqual(fixture.map.regionCommands, 1)
            XCTAssertTrue(fixture.controller.isFollowing)
            fixture.controller.recenter(on: fixture.map, at: position)
            XCTAssertEqual(fixture.map.regionCommands, 1)
            XCTAssertTrue(fixture.map.trackingCommands.isEmpty)
        }
    }

    func testGPSJitterAndInvalidCoordinatesDoNotMoveCamera() async throws {
        let fixture = try await makeFixture()
        defer { fixture.close() }
        fixture.controller.recenter(on: fixture.map, at: position)
        try await settle(fixture, at: position)
        fixture.map.clearCommands()

        fixture.controller.updateLocation(
            CLLocationCoordinate2D(latitude: position.latitude + 0.00001,
                                   longitude: position.longitude), on: fixture.map
        )
        fixture.controller.updateLocation(kCLLocationCoordinate2DInvalid, on: fixture.map)
        fixture.controller.recenter(on: fixture.map, at: kCLLocationCoordinate2DInvalid)

        XCTAssertEqual(fixture.map.centerCommands, 0)
        XCTAssertEqual(fixture.map.regionCommands, 0)
    }

    private func makeFixture() async throws -> Fixture {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = scene.effectiveGeometry.coordinateSpace.bounds
        let host = UIViewController()
        let map = RecordingMapView(frame: window.bounds)
        let controller = MapUserCameraController()
        let delegate = CameraDelegate(controller: controller)
        map.delegate = delegate
        host.view = map
        window.rootViewController = host
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        map.setRegion(MKCoordinateRegion(
            center: position, latitudinalMeters: 30_000, longitudinalMeters: 30_000
        ), animated: false)
        try await eventually { delegate.completions > 0 }
        map.clearCommands()
        return Fixture(window: window, map: map, controller: controller, delegate: delegate)
    }

    private func settle(_ fixture: Fixture, at coordinate: CLLocationCoordinate2D) async throws {
        try await eventually {
            let center = fixture.map.centerCoordinate
            return abs(center.latitude - coordinate.latitude) < 0.00001
                && abs(center.longitude - coordinate.longitude) < 0.00001
                && fixture.delegate.lastCompletedRegionCommand == fixture.map.regionCommands
                && fixture.delegate.lastCompletedCenterCommand == fixture.map.centerCommands
        }
    }

    private func eventually(_ predicate: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            if predicate() { return }
            try await Task.sleep(for: .milliseconds(40))
        }
        XCTFail("MapKit did not complete the expected camera movement")
    }

    private struct Fixture {
        let window: UIWindow
        let map: RecordingMapView
        let controller: MapUserCameraController
        let delegate: CameraDelegate

        func close() {
            controller.stopFollowing()
            map.delegate = nil
            window.isHidden = true
        }
    }
}

@MainActor
private final class RecordingMapView: MKMapView {
    var regionCommands = 0
    var centerCommands = 0
    var trackingCommands: [MKUserTrackingMode] = []
    var spanBeforeCenter: MKCoordinateSpan?

    override func setRegion(_ region: MKCoordinateRegion, animated: Bool) {
        regionCommands += 1
        super.setRegion(region, animated: animated)
    }

    override func setCenter(_ coordinate: CLLocationCoordinate2D, animated: Bool) {
        centerCommands += 1
        spanBeforeCenter = region.span
        super.setCenter(coordinate, animated: animated)
    }

    override func setUserTrackingMode(_ mode: MKUserTrackingMode, animated: Bool) {
        trackingCommands.append(mode)
        super.setUserTrackingMode(mode, animated: animated)
    }

    func clearCommands() {
        regionCommands = 0
        centerCommands = 0
        trackingCommands = []
        spanBeforeCenter = nil
        if let cameraDelegate = delegate as? CameraDelegate {
            cameraDelegate.lastCompletedRegionCommand = -1
            cameraDelegate.lastCompletedCenterCommand = -1
        }
    }
}

@MainActor
private final class CameraDelegate: NSObject, MKMapViewDelegate {
    let controller: MapUserCameraController
    var completions = 0
    var lastCompletedRegionCommand = 0
    var lastCompletedCenterCommand = 0

    init(controller: MapUserCameraController) {
        self.controller = controller
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        completions += 1
        if let map = mapView as? RecordingMapView {
            lastCompletedRegionCommand = map.regionCommands
            lastCompletedCenterCommand = map.centerCommands
        }
        controller.regionDidChange(on: mapView)
    }
}
