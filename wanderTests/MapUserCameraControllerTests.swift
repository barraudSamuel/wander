import MapboxMaps
import CoreLocation
import SwiftUI
import XCTest
@testable import wander

@MainActor
final class MapUserCameraControllerTests: XCTestCase {
    private let position = CLLocationCoordinate2D(latitude: 10.76, longitude: 106.66)

    func testRepeatedTapsDuringAndAfterRecenterDoNotRestartCamera() async throws {
        let fixture = try makeFixture()
        defer { fixture.close() }

        fixture.controller.recenter(on: fixture.map, at: position)
        fixture.controller.recenter(on: fixture.map, at: position)
        XCTAssertTrue(fixture.controller.isAnimating)
        try await settle(fixture, at: position)
        let zoom = fixture.map.mapboxMap.cameraState.zoom

        for _ in 0..<5 {
            fixture.controller.recenter(on: fixture.map, at: position)
            XCTAssertFalse(fixture.controller.isAnimating)
        }
        XCTAssertEqual(fixture.map.mapboxMap.cameraState.zoom, zoom, accuracy: 0.0001)
        XCTAssertTrue(fixture.controller.isFollowing)
    }

    func testAlreadyCenteredTapEnablesFollowingWithoutMovingCamera() throws {
        let fixture = try makeFixture()
        defer { fixture.close() }
        fixture.map.mapboxMap.setCamera(to: MapUserCameraController.focusedCamera(
            at: position, on: fixture.map
        ))
        let camera = fixture.map.mapboxMap.cameraState

        fixture.controller.recenter(on: fixture.map, at: position)

        XCTAssertTrue(fixture.controller.isFollowing)
        XCTAssertFalse(fixture.controller.isAnimating)
        XCTAssertEqual(fixture.map.mapboxMap.cameraState.center.latitude, camera.center.latitude)
        XCTAssertEqual(fixture.map.mapboxMap.cameraState.zoom, camera.zoom)
    }

    func testLocationsReceivedDuringRecenterFollowOnlyLatestPositionWithoutZooming() async throws {
        let fixture = try makeFixture()
        defer { fixture.close() }
        let targetZoom = await nativeFocusedZoom(at: position, on: fixture.map)
        fixture.controller.recenter(on: fixture.map, at: position)
        let intermediate = CLLocationCoordinate2D(latitude: 10.761, longitude: 106.66)
        let latest = CLLocationCoordinate2D(latitude: 10.762, longitude: 106.66)
        fixture.controller.updateLocation(intermediate, on: fixture.map)
        fixture.controller.updateLocation(latest, on: fixture.map)

        try await settle(fixture, at: latest)
        XCTAssertEqual(fixture.map.mapboxMap.cameraState.zoom, targetZoom, accuracy: 0.0001)
        XCTAssertEqual(fixture.map.mapboxMap.cameraState.bearing, 25, accuracy: 0.0001)
        XCTAssertEqual(fixture.map.mapboxMap.cameraState.pitch, 20, accuracy: 0.0001)
        fixture.controller.updateLocation(latest, on: fixture.map)
        XCTAssertFalse(fixture.controller.isAnimating)
    }

    func testStoppingFollowDiscardsQueuedPositionsAndDoesNotResumeAfterCompletion() async throws {
        let fixture = try makeFixture()
        defer { fixture.close() }
        fixture.controller.recenter(on: fixture.map, at: position)
        fixture.controller.updateLocation(
            CLLocationCoordinate2D(latitude: 10.762, longitude: 106.66), on: fixture.map
        )
        fixture.controller.stopFollowing()
        let stoppedCenter = fixture.map.mapboxMap.cameraState.center
        fixture.controller.updateLocation(
            CLLocationCoordinate2D(latitude: 10.764, longitude: 106.66), on: fixture.map
        )
        try await Task.sleep(for: .milliseconds(450))

        XCTAssertFalse(fixture.controller.isFollowing)
        XCTAssertFalse(fixture.controller.isAnimating)
        XCTAssertEqual(fixture.map.mapboxMap.cameraState.center.latitude,
                       stoppedCenter.latitude, accuracy: 0.000001)
        XCTAssertEqual(fixture.map.mapboxMap.cameraState.center.longitude,
                       stoppedCenter.longitude, accuracy: 0.000001)
    }

    func testRecenterAfterManualZoomRestoresSameScaleAndResumesFollowing() async throws {
        let fixture = try makeFixture()
        defer { fixture.close() }
        fixture.controller.recenter(on: fixture.map, at: position)
        try await settle(fixture, at: position)
        let normalZoom = fixture.map.mapboxMap.cameraState.zoom

        for zoom in [18.0, 7.0] {
            fixture.controller.stopFollowing()
            fixture.map.mapboxMap.setCamera(to: CameraOptions(center: position, zoom: zoom))
            fixture.controller.recenter(on: fixture.map, at: position)
            try await settle(fixture, at: position)

            XCTAssertEqual(fixture.map.mapboxMap.cameraState.zoom, normalZoom, accuracy: 0.0001)
            XCTAssertTrue(fixture.controller.isFollowing)
            fixture.controller.recenter(on: fixture.map, at: position)
            XCTAssertFalse(fixture.controller.isAnimating)
        }
    }

    func testGPSJitterAndInvalidCoordinatesDoNotMoveCamera() async throws {
        let fixture = try makeFixture()
        defer { fixture.close() }
        fixture.controller.recenter(on: fixture.map, at: position)
        try await settle(fixture, at: position)
        let camera = fixture.map.mapboxMap.cameraState

        fixture.controller.updateLocation(
            CLLocationCoordinate2D(latitude: position.latitude + 0.00001,
                                   longitude: position.longitude), on: fixture.map
        )
        fixture.controller.updateLocation(kCLLocationCoordinate2DInvalid, on: fixture.map)
        fixture.controller.recenter(on: fixture.map, at: kCLLocationCoordinate2DInvalid)

        XCTAssertFalse(fixture.controller.isAnimating)
        XCTAssertEqual(fixture.map.mapboxMap.cameraState.center.latitude, camera.center.latitude)
        XCTAssertEqual(fixture.map.mapboxMap.cameraState.center.longitude, camera.center.longitude)
        XCTAssertEqual(fixture.map.mapboxMap.cameraState.zoom, camera.zoom)
    }

    func testFocusedCameraShowsEightHundredMetersAcrossItsShortSide() throws {
        let fixture = try makeFixture()
        defer { fixture.close() }

        for latitude in [0.0, 45.0, 70.0] {
            var camera = MapUserCameraController.focusedCamera(
                at: CLLocationCoordinate2D(latitude: latitude, longitude: 10), on: fixture.map
            )
            camera.bearing = 0
            camera.pitch = 0
            fixture.map.mapboxMap.setCamera(to: camera)
            let bounds = fixture.map.bounds
            let isPortrait = bounds.width <= bounds.height
            let start = CGPoint(x: isPortrait ? bounds.minX : bounds.midX,
                                y: isPortrait ? bounds.midY : bounds.minY)
            let end = CGPoint(x: isPortrait ? bounds.maxX : bounds.midX,
                              y: isPortrait ? bounds.midY : bounds.maxY)
            let first = fixture.map.mapboxMap.coordinate(for: start)
            let last = fixture.map.mapboxMap.coordinate(for: end)
            let distance = CLLocation(latitude: first.latitude, longitude: first.longitude)
                .distance(from: CLLocation(latitude: last.latitude, longitude: last.longitude))
            // CoreLocation uses an ellipsoid; the map's Mercator scale uses a sphere.
            XCTAssertEqual(distance, 800, accuracy: 8, "Incorrect extent at latitude \(latitude)")
        }
    }

    func testInitialCameraWaitsForFirstNonzeroViewportLayout() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first)
        let map = MapboxMaps.MapView(frame: .zero, mapInitOptions: MapInitOptions(
            cameraOptions: CameraOptions(center: position, zoom: 10),
            styleJSON: #"{"version":8,"sources":{},"layers":[]}"#
        ))
        let viewport = MapViewportView(mapView: map, renderSize: nil)
        var wantsRecenter = true
        let mapView = MapWithFogView(
            locationTracker: LocationTracker(scenarioLocation: CLLocation(
                latitude: position.latitude, longitude: position.longitude
            )),
            discoveredCellIDs: [],
            cityBoundaryCoordinates: [],
            centerOnUser: Binding(get: { wantsRecenter }, set: { wantsRecenter = $0 }),
            resetMapOrientation: .constant(false),
            centerOnFriendUserID: .constant(nil),
            centerOnOutingPlanEventID: .constant(nil)
        )
        let coordinator = mapView.makeCoordinator()
        viewport.onViewportChange = { [weak coordinator] in
            coordinator?.applyPendingCameraUpdate()
        }
        mapView.scheduleCameraUpdate(in: viewport, coordinator: coordinator)

        XCTAssertFalse(coordinator.didCenterOnUser)
        XCTAssertFalse(coordinator.didSetInitialRegion)
        XCTAssertFalse(coordinator.userCamera.isAnimating)
        XCTAssertFalse(coordinator.userCamera.isFollowing)
        XCTAssertTrue(wantsRecenter)
        XCTAssertEqual(map.mapboxMap.cameraState.zoom, 10, accuracy: 0.0001)
        XCTAssertNil(MapUserCameraController.focusedCamera(at: position, on: map).zoom)

        let window = UIWindow(windowScene: scene)
        window.frame = scene.effectiveGeometry.coordinateSpace.bounds
        let host = UIViewController()
        host.view = viewport
        window.rootViewController = host
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        let fixture = Fixture(window: window, map: map, controller: coordinator.userCamera)
        defer {
            viewport.onViewportChange = nil
            fixture.close()
        }
        try await settle(fixture, at: position)
        let requestDeadline = Date().addingTimeInterval(1)
        while wantsRecenter && Date() < requestDeadline {
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertTrue(coordinator.didCenterOnUser)
        XCTAssertTrue(coordinator.didSetInitialRegion)
        XCTAssertTrue(coordinator.userCamera.isFollowing)
        XCTAssertFalse(wantsRecenter)
        XCTAssertGreaterThan(map.mapboxMap.cameraState.zoom, 14)
        let completedZoom = map.mapboxMap.cameraState.zoom
        map.mapboxMap.setCamera(to: MapUserCameraController.focusedCamera(at: position, on: map))
        XCTAssertEqual(completedZoom, map.mapboxMap.cameraState.zoom, accuracy: 0.0001)
    }

    func testInitialCameraUsesTrackerLocationBeforeMapJoinsWindow() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first)
        let seoul = CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780)
        let size = scene.effectiveGeometry.coordinateSpace.bounds.size
        let map = MapboxMaps.MapView(
            frame: CGRect(origin: .zero, size: size),
            mapInitOptions: MapInitOptions(
                cameraOptions: CameraOptions(center: position, zoom: 11),
                styleURI: nil,
                styleJSON: #"{"version":8,"sources":{},"layers":[]}"#
            )
        )
        let viewport = MapViewportView(mapView: map, renderSize: size)
        let mapView = MapWithFogView(
            locationTracker: LocationTracker(scenarioLocation: CLLocation(
                latitude: seoul.latitude, longitude: seoul.longitude
            )),
            discoveredCellIDs: [],
            cityBoundaryCoordinates: [],
            centerOnUser: .constant(false),
            resetMapOrientation: .constant(false),
            centerOnFriendUserID: .constant(nil),
            centerOnOutingPlanEventID: .constant(nil)
        )
        let coordinator = mapView.makeCoordinator()
        XCTAssertNil(map.window)
        mapView.scheduleCameraUpdate(in: viewport, coordinator: coordinator)

        XCTAssertTrue(coordinator.didCenterOnUser)
        XCTAssertTrue(coordinator.didSetInitialRegion)
        XCTAssertEqual(map.mapboxMap.cameraState.center.latitude, seoul.latitude, accuracy: 0.00001)
        XCTAssertEqual(map.mapboxMap.cameraState.center.longitude, seoul.longitude, accuracy: 0.00001)
        let initialZoom = map.mapboxMap.cameraState.zoom
        XCTAssertGreaterThan(initialZoom, 14)

        let window = UIWindow(windowScene: scene)
        window.frame = scene.effectiveGeometry.coordinateSpace.bounds
        let host = UIViewController()
        host.view = viewport
        window.rootViewController = host
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        defer { window.isHidden = true }
        try await Task.sleep(for: .milliseconds(450))

        XCTAssertEqual(map.mapboxMap.cameraState.center.latitude, seoul.latitude, accuracy: 0.00001)
        XCTAssertEqual(map.mapboxMap.cameraState.center.longitude, seoul.longitude, accuracy: 0.00001)
        XCTAssertEqual(map.mapboxMap.cameraState.zoom, initialZoom, accuracy: 0.0001)
    }

    private func nativeFocusedZoom(
        at coordinate: CLLocationCoordinate2D,
        on map: MapboxMaps.MapView
    ) async -> CGFloat {
        let original = map.mapboxMap.cameraState
        // Use the native animation endpoint as the reference for preserved zoom.
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            map.camera.ease(to: MapUserCameraController.focusedCamera(at: coordinate, on: map),
                            duration: 0.01) { _ in
                continuation.resume()
            }
        }
        let zoom = map.mapboxMap.cameraState.zoom
        map.mapboxMap.setCamera(to: CameraOptions(cameraState: original))
        return zoom
    }

    private func makeFixture() throws -> Fixture {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = scene.effectiveGeometry.coordinateSpace.bounds
        let host = UIViewController()
        let map = MapboxMaps.MapView(frame: window.bounds, mapInitOptions: MapInitOptions(
            cameraOptions: CameraOptions(center: position, zoom: 10, bearing: 25, pitch: 20),
            styleJSON: #"{"version":8,"sources":{},"layers":[]}"#
        ))
        let controller = MapUserCameraController()
        host.view = map
        window.rootViewController = host
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        return Fixture(window: window, map: map, controller: controller)
    }

    private func settle(_ fixture: Fixture, at coordinate: CLLocationCoordinate2D) async throws {
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            let center = fixture.map.mapboxMap.cameraState.center
            if !fixture.controller.isAnimating,
               abs(center.latitude - coordinate.latitude) < 0.00001,
               abs(center.longitude - coordinate.longitude) < 0.00001 {
                return
            }
            try await Task.sleep(for: .milliseconds(40))
        }
        XCTFail("Mapbox did not complete the expected camera movement")
    }

    private struct Fixture {
        let window: UIWindow
        let map: MapboxMaps.MapView
        let controller: MapUserCameraController

        func close() {
            controller.stopFollowing()
            window.isHidden = true
        }
    }
}
