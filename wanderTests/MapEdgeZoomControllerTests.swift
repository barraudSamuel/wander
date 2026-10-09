import MapboxMaps
import UIKit
import XCTest
@testable import wander

@MainActor
final class MapEdgeZoomControllerTests: XCTestCase {
    func testNearestTargetUsesVisibleViewportAndIgnoresHiddenOrInvalidCoordinates() {
        let coordinate = CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.978)
        let targets = [
            MapEdgeZoomController.Target(id: "outside", coordinate: coordinate, screenPoint: CGPoint(x: 180, y: 150)),
            MapEdgeZoomController.Target(id: "far", coordinate: coordinate, screenPoint: CGPoint(x: 40, y: 320)),
            MapEdgeZoomController.Target(id: "near", coordinate: coordinate, screenPoint: CGPoint(x: 190, y: 345)),
            MapEdgeZoomController.Target(id: "invalid", coordinate: kCLLocationCoordinate2DInvalid, screenPoint: CGPoint(x: 187.5, y: 340))
        ]
        let visible = CGRect(x: 0, y: 240, width: 375, height: 200)
        XCTAssertEqual(MapEdgeZoomController.nearestTarget(in: targets, visibleBounds: visible)?.id, "near")
        XCTAssertNil(MapEdgeZoomController.nearestTarget(in: Array(targets.prefix(1)), visibleBounds: visible))
        XCTAssertNil(MapEdgeZoomController.nearestTarget(in: targets, visibleBounds: .zero))
        XCTAssertNil(MapEdgeZoomController.nearestTarget(in: [], visibleBounds: visible))
    }

    func testEquidistantTargetsHaveStableChoiceRegardlessOfAnnotationOrder() {
        let coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let first = MapEdgeZoomController.Target(id: "friend:a", coordinate: coordinate, screenPoint: CGPoint(x: 40, y: 50))
        let second = MapEdgeZoomController.Target(id: "outing:b", coordinate: coordinate, screenPoint: CGPoint(x: 60, y: 50))
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        for targets in [[first, second], [second, first]] {
            XCTAssertEqual(MapEdgeZoomController.nearestTarget(in: targets, visibleBounds: bounds)?.id, first.id)
        }
    }

    func testSocialTargetEligibilityIncludesSelfAndKeepsGroupAsOneTarget() {
        let user = UserLocationAnnotation()
        let friend = FriendLocationAnnotation()
        friend.userID = "friend-a"
        let group = MapSocialProximityGroupAnnotation(identifier: "group-a", memberAnnotations: [user, friend])
        XCTAssertEqual(MapWithFogView.Coordinator.edgeZoomTargetID(for: user), "current-user")
        XCTAssertNil(MapWithFogView.Coordinator.edgeZoomTargetID(for: MapAnnotation()))
        XCTAssertEqual(MapWithFogView.Coordinator.edgeZoomTargetID(for: friend), "friend:friend-a")
        XCTAssertEqual(MapWithFogView.Coordinator.edgeZoomTargetID(for: group), "group:group-a")
        group.update(memberAnnotations: [user])
        XCTAssertEqual(MapWithFogView.Coordinator.edgeZoomTargetID(for: group), "group:group-a")
        group.update(memberAnnotations: [MapAnnotation()])
        XCTAssertNil(MapWithFogView.Coordinator.edgeZoomTargetID(for: group))
    }

    func testOwnProfileCanBeFocusedAloneOrCompeteWithOtherTargets() {
        let coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let own = MapEdgeZoomController.Target(id: "current-user", coordinate: coordinate,
                                               screenPoint: CGPoint(x: 50, y: 50))
        let friend = MapEdgeZoomController.Target(id: "friend:a", coordinate: coordinate,
                                                  screenPoint: CGPoint(x: 70, y: 50))
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        XCTAssertEqual(MapEdgeZoomController.nearestTarget(in: [own], visibleBounds: bounds)?.id, own.id)
        XCTAssertEqual(MapEdgeZoomController.nearestTarget(in: [friend, own], visibleBounds: bounds)?.id, own.id)
        let offsetBounds = CGRect(x: 20, y: 0, width: 100, height: 100)
        XCTAssertEqual(MapEdgeZoomController.nearestTarget(in: [own, friend], visibleBounds: offsetBounds)?.id, friend.id)
        XCTAssertNil(MapEdgeZoomController.nearestTarget(in: [own], visibleBounds: CGRect(x: 100, y: 0, width: 100, height: 100)))
    }

    func testZoomSessionFreezesCameraAndTargetWithoutAnInitialJump() {
        var initial = CameraState(center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                                 padding: .zero, zoom: 15, bearing: 45, pitch: 30)
        let friend = FriendLocationAnnotation()
        friend.coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0.01)
        let target = MapEdgeZoomController.Target(id: "friend:a", coordinate: friend.coordinate, screenPoint: CGPoint(x: 160, y: 300))
        let session = MapEdgeZoomController.ZoomSession(camera: initial, target: target)
        // Both external inputs can change after the gesture starts.
        initial.center = CLLocationCoordinate2D(latitude: 20, longitude: 30)
        friend.coordinate = CLLocationCoordinate2D(latitude: 25, longitude: 35)
        let unchanged = session.camera(at: 15, focusProgress: 0)
        XCTAssertEqual(unchanged.center?.latitude ?? .nan, 0, accuracy: 0.000001)
        XCTAssertEqual(unchanged.center?.longitude ?? .nan, 0, accuracy: 0.000001)
        let zoomed = session.camera(at: 16)
        XCTAssertEqual(zoomed.center?.longitude ?? .nan, 0.01, accuracy: 0.000001)
        XCTAssertEqual(zoomed.zoom ?? .nan, 16, accuracy: 0.01)
        XCTAssertEqual(zoomed.bearing ?? .nan, 45, accuracy: 0.01)
        XCTAssertEqual(zoomed.pitch ?? .nan, 30, accuracy: 0.01)
        XCTAssertEqual(session.anchor?.longitude, 0.01)
        let zoomedOut = session.camera(at: 14)
        XCTAssertEqual(zoomedOut.center?.longitude ?? .nan, 0.01, accuracy: 0.000001)
        let halfway = session.camera(at: 15, focusProgress: 0.5)
        XCTAssertEqual(halfway.center?.longitude ?? .nan, 0.005, accuracy: 0.000001)
    }

    func testZoomWithoutTargetKeepsOriginalCenter() {
        let center = CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.978)
        let camera = CameraState(center: center, padding: .zero, zoom: 15, bearing: 90, pitch: 0)
        let session = MapEdgeZoomController.ZoomSession(camera: camera, target: nil)
        for zoom: CGFloat in [16, 14] {
            let next = session.camera(at: zoom)
            XCTAssertEqual(next.center?.latitude ?? .nan, center.latitude, accuracy: 0.000001)
            XCTAssertEqual(next.center?.longitude ?? .nan, center.longitude, accuracy: 0.000001)
            XCTAssertEqual(next.zoom ?? .nan, zoom, accuracy: 0.01)
            XCTAssertEqual(next.bearing ?? .nan, 90, accuracy: 0.01)
        }
    }

    func testTargetCentersInVisibleViewportOnRotatedAndTiltedMap() {
        let map = makeMap(frame: CGRect(x: 0, y: 0, width: 375, height: 600))
        let center = CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.978)
        for pitch in [0.0, 30.0] {
            for heading in [0.0, 45.0, 180.0] {
                map.mapboxMap.setCamera(to: CameraOptions(center: center, zoom: 15,
                                          bearing: heading, pitch: pitch))
                let point = CGPoint(x: 230, y: 375)
                let target = MapEdgeZoomController.Target(
                    id: "friend:a",
                    coordinate: map.mapboxMap.coordinate(for: point),
                    screenPoint: point
                )
                let destination = CGPoint(x: 187.5, y: 325)
                let session = MapEdgeZoomController.ZoomSession(
                    camera: map.mapboxMap.cameraState, target: target,
                    focusCoordinate: map.mapboxMap.coordinate(for: destination)
                )
                for zoom: CGFloat in [15, 16, 14] {
                    map.mapboxMap.setCamera(to: session.camera(at: zoom))
                    let projected = map.mapboxMap.point(for: target.coordinate)
                    XCTAssertEqual(projected.x, destination.x, accuracy: 1)
                    XCTAssertEqual(projected.y, destination.y, accuracy: 1)
                }
            }
        }
    }

    func testFocusFeedbackOccursOnlyWhenGestureAcquiresTargetAndCancelStopsCamera() {
        let map = makeMap(frame: CGRect(x: 0, y: 0, width: 375, height: 600))
        let viewport = MapViewportView(mapView: map, renderSize: nil)
        viewport.frame = map.frame
        viewport.layoutIfNeeded()
        map.mapboxMap.setCamera(to: CameraOptions(center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                                  zoom: 15, bearing: 0, pitch: 0))
        var offersTarget = true
        var focusCount = 0
        var beginCount = 0
        let controller = MapEdgeZoomController(viewport: viewport, targets: { map in
            guard offersTarget else { return [] }
            let point = CGPoint(x: 230, y: 375)
            return [.init(id: "friend:a", coordinate: map.mapboxMap.coordinate(for: point), screenPoint: point)]
        }, onFocus: { focusCount += 1 }, onBegin: { beginCount += 1 })
        controller.begin(on: map)
        XCTAssertEqual(focusCount, 0)
        controller.move(on: map, translationY: -1, velocityY: -50)
        XCTAssertEqual(focusCount, 1)
        XCTAssertEqual(beginCount, 1)
        XCTAssertTrue(controller.isActive)
        controller.cancel()
        XCTAssertFalse(controller.isActive)
        let cancelledCenter = map.mapboxMap.cameraState.center
        let settled = expectation(description: "Cancelled focus has no later camera update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { settled.fulfill() }
        wait(for: [settled], timeout: 1)
        XCTAssertEqual(map.mapboxMap.cameraState.center.latitude, cancelledCenter.latitude, accuracy: 0.000001)
        XCTAssertEqual(map.mapboxMap.cameraState.center.longitude, cancelledCenter.longitude, accuracy: 0.000001)
        XCTAssertEqual(focusCount, 1)
        offersTarget = false
        controller.begin(on: map)
        controller.move(on: map, translationY: -1, velocityY: -50)
        XCTAssertEqual(beginCount, 2)
        XCTAssertEqual(focusCount, 1)
        controller.uninstall()
    }

    func testShortSwipeCompletesFocusAndNewGestureCanInterruptIt() {
        let map = makeMap(frame: CGRect(x: 0, y: 0, width: 375, height: 600))
        let viewport = MapViewportView(mapView: map, renderSize: nil)
        viewport.frame = map.frame
        viewport.layoutIfNeeded()
        map.mapboxMap.setCamera(to: CameraOptions(center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                                  zoom: 15, bearing: 0, pitch: 0))
        let point = CGPoint(x: 230, y: 375)
        let coordinate = map.mapboxMap.coordinate(for: point)
        var focusCount = 0
        let controller = MapEdgeZoomController(viewport: viewport, targets: { _ in
            [.init(id: "friend:a", coordinate: coordinate, screenPoint: point)]
        }, onFocus: { focusCount += 1 }, onBegin: {})
        controller.begin(on: map)
        controller.move(on: map, translationY: -1, velocityY: -50, at: 0)
        controller.end()
        controller.advanceFocus(at: 0.2)
        XCTAssertFalse(controller.isActive)
        XCTAssertEqual(focusCount, 1)
        let projected = map.mapboxMap.point(for: coordinate)
        XCTAssertEqual(projected.x, viewport.visibleSafeMapRect.midX, accuracy: 1)
        XCTAssertEqual(projected.y, viewport.visibleSafeMapRect.midY, accuracy: 1)

        controller.begin(on: map)
        controller.move(on: map, translationY: -1, velocityY: -50, at: 1)
        controller.end()
        controller.begin(on: map)
        controller.move(on: map, translationY: -1, velocityY: -50, at: 1.05)
        XCTAssertTrue(controller.isActive)
        XCTAssertEqual(focusCount, 3)
        controller.cancel()
        let cancelledCenter = map.mapboxMap.cameraState.center
        controller.advanceFocus(at: 2)
        XCTAssertFalse(controller.isActive)
        XCTAssertEqual(map.mapboxMap.cameraState.center.latitude, cancelledCenter.latitude, accuracy: 0.000001)
        XCTAssertEqual(map.mapboxMap.cameraState.center.longitude, cancelledCenter.longitude, accuracy: 0.000001)
        controller.uninstall()
    }

    func testZoomOutNeverAcquiresTargetOrMovesCenter() {
        let map = makeMap(frame: CGRect(x: 0, y: 0, width: 375, height: 600))
        let viewport = MapViewportView(mapView: map, renderSize: nil)
        viewport.frame = map.frame
        viewport.layoutIfNeeded()
        map.mapboxMap.setCamera(to: CameraOptions(center: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.978),
                                 zoom: 15, bearing: 45, pitch: 0))
        let center = map.mapboxMap.cameraState.center
        let initialZoom = map.mapboxMap.cameraState.zoom
        let controller = MapEdgeZoomController(viewport: viewport, targets: { _ in
            XCTFail("Zoom out must not look for a magnetic target")
            return []
        }, onFocus: { XCTFail("Zoom out must not trigger focus feedback") }, onBegin: {})
        controller.begin(on: map)
        controller.move(on: map, translationY: 0, velocityY: 0, at: 0)
        controller.move(on: map, translationY: 150, velocityY: 50, at: 0.1)
        XCTAssertLessThan(map.mapboxMap.cameraState.zoom, initialZoom)
        XCTAssertEqual(map.mapboxMap.cameraState.center.latitude, center.latitude, accuracy: 0.000001)
        XCTAssertEqual(map.mapboxMap.cameraState.center.longitude, center.longitude, accuracy: 0.000001)
        controller.end()
        controller.advanceFocus(at: 1)
        XCTAssertFalse(controller.isActive)
        XCTAssertEqual(map.mapboxMap.cameraState.center.longitude, center.longitude, accuracy: 0.000001)
        controller.uninstall()
    }

    func testReversingToZoomOutStopsFocusAndKeepsDisplayedCenter() {
        for elapsed in [0.0, 0.05, 0.2] {
            let map = makeMap(frame: CGRect(x: 0, y: 0, width: 375, height: 600))
            let viewport = MapViewportView(mapView: map, renderSize: nil)
            viewport.frame = map.frame
            viewport.layoutIfNeeded()
            map.mapboxMap.setCamera(to: CameraOptions(center: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.978),
                                     zoom: 15, bearing: 0, pitch: 0))
            var focusCount = 0
            let controller = MapEdgeZoomController(viewport: viewport, targets: { map in
                let point = CGPoint(x: 230, y: 375)
                return [.init(id: "friend:a", coordinate: map.mapboxMap.coordinate(for: point), screenPoint: point)]
            }, onFocus: { focusCount += 1 }, onBegin: {})
            controller.begin(on: map)
            controller.move(on: map, translationY: -50, velocityY: -100, at: 0)
            if elapsed > 0 { controller.advanceFocus(at: elapsed) }
            let before = map.mapboxMap.cameraState
            // Still a negative total translation, but this increment is zooming out.
            controller.move(on: map, translationY: -40, velocityY: 50, at: elapsed + 0.01)
            XCTAssertLessThan(map.mapboxMap.cameraState.zoom, before.zoom)
            XCTAssertEqual(map.mapboxMap.cameraState.center.latitude, before.center.latitude, accuracy: 0.000001)
            XCTAssertEqual(map.mapboxMap.cameraState.center.longitude, before.center.longitude, accuracy: 0.000001)
            controller.advanceFocus(at: 1)
            XCTAssertEqual(map.mapboxMap.cameraState.center.longitude, before.center.longitude, accuracy: 0.000001)
            XCTAssertEqual(focusCount, 1)
            // Returning to zoom in can acquire focus again, from the current camera.
            controller.move(on: map, translationY: -45, velocityY: -50, at: 1.1)
            XCTAssertEqual(focusCount, 2)
            controller.cancel()
            controller.uninstall()
        }
    }

    func testAnchorAcrossAntimeridianUsesNearestWorldCopy() {
        let center = MapEdgeZoomController.anchoredCenter(
            initial: CLLocationCoordinate2D(latitude: 0, longitude: 179.999),
            anchor: CLLocationCoordinate2D(latitude: 0, longitude: -179.999),
            scale: 0.5
        )
        XCTAssertEqual(abs(center.longitude), 180, accuracy: 0.000001)
        XCTAssertEqual(center.latitude, 0, accuracy: 0.000001)
        let original = CLLocationCoordinate2D(latitude: 37, longitude: 127)
        let invalidOffset = MapEdgeZoomController.anchoredCenter(
            initial: original, anchor: center, scale: 0.5,
            offsetOrigin: kCLLocationCoordinate2DInvalid
        )
        XCTAssertEqual(invalidOffset.latitude, original.latitude)
        XCTAssertEqual(invalidOffset.longitude, original.longitude)
    }

    func testEdgeZonesUseCroppedMapCoordinatesAndRejectHiddenContent() {
        let bounds = CGRect(x: 30, y: 240, width: 375, height: 200)
        XCTAssertEqual(MapEdgeZoomController.edge(at: CGPoint(x: 40, y: 300), in: bounds), .left)
        XCTAssertEqual(MapEdgeZoomController.edge(at: CGPoint(x: 395, y: 300), in: bounds), .right)
        XCTAssertEqual(MapEdgeZoomController.edge(at: CGPoint(x: 74, y: 300), in: bounds), .left)
        XCTAssertEqual(MapEdgeZoomController.edge(at: CGPoint(x: 361, y: 300), in: bounds), .right)
        XCTAssertNil(MapEdgeZoomController.edge(at: CGPoint(x: 75, y: 300), in: bounds))
        XCTAssertNil(MapEdgeZoomController.edge(at: CGPoint(x: 360, y: 300), in: bounds))
        XCTAssertNil(MapEdgeZoomController.edge(at: CGPoint(x: 40, y: 239), in: bounds))
        XCTAssertNil(MapEdgeZoomController.edge(at: CGPoint(x: 40, y: 440), in: bounds))
        XCTAssertNil(MapEdgeZoomController.edge(at: .zero, in: .zero))
    }

    func testAccelerationPreservesSlowPrecisionAndCapsFastGesturesInBothDirections() {
        for direction: CGFloat in [-1, 1] {
            let delta = direction * 10
            XCTAssertEqual(MapEdgeZoomController.acceleratedTranslation(delta, velocityY: direction * 50), delta)
            XCTAssertEqual(MapEdgeZoomController.acceleratedTranslation(delta, velocityY: direction * 100), delta)
            XCTAssertEqual(MapEdgeZoomController.acceleratedTranslation(delta, velocityY: direction * 500), delta * 2)
            XCTAssertEqual(MapEdgeZoomController.acceleratedTranslation(delta, velocityY: direction * 900), delta * 3)
            XCTAssertEqual(MapEdgeZoomController.acceleratedTranslation(delta, velocityY: direction * 5_000), delta * 3)
        }
    }

    func testAccelerationKeepsDisplacementDirectionAndIgnoresInvalidSamples() {
        XCTAssertEqual(MapEdgeZoomController.acceleratedTranslation(-10, velocityY: 900), -30)
        XCTAssertEqual(MapEdgeZoomController.acceleratedTranslation(10, velocityY: -900), 30)
        XCTAssertEqual(MapEdgeZoomController.acceleratedTranslation(0, velocityY: 900), 0)
        XCTAssertEqual(MapEdgeZoomController.acceleratedTranslation(10, velocityY: .nan), 10)
        XCTAssertEqual(MapEdgeZoomController.acceleratedTranslation(10, velocityY: .infinity), 10)
        XCTAssertEqual(MapEdgeZoomController.acceleratedTranslation(.nan, velocityY: 900), 0)
    }

    func testFastGestureZoomsFurtherAndStillRespectsCameraLimits() {
        let slow = MapEdgeZoomController.acceleratedTranslation(150, velocityY: 50)
        let fast = MapEdgeZoomController.acceleratedTranslation(150, velocityY: 900)
        XCTAssertEqual(MapEdgeZoomController.zoom(from: 15, translationY: slow), 14)
        XCTAssertEqual(MapEdgeZoomController.zoom(from: 15, translationY: fast), 12)
        XCTAssertEqual(MapEdgeZoomController.zoom(from: 15, translationY: -fast), 18)
        XCTAssertEqual(MapEdgeZoomController.zoom(from: 15, translationY: fast, minimum: 13), 13)
        XCTAssertEqual(MapEdgeZoomController.zoom(from: 15, translationY: -fast, maximum: 17), 17)
    }

    func testVerticalIntentRejectsHorizontalAndDiagonalPanning() {
        XCTAssertTrue(MapEdgeZoomController.isVertical(CGPoint(x: 3, y: -20)))
        XCTAssertTrue(MapEdgeZoomController.isVertical(CGPoint(x: -3, y: 20)))
        XCTAssertFalse(MapEdgeZoomController.isVertical(CGPoint(x: 20, y: 3)))
        XCTAssertFalse(MapEdgeZoomController.isVertical(CGPoint(x: 20, y: 20)))
        XCTAssertFalse(MapEdgeZoomController.isVertical(.zero))
    }

    func testZoomDirectionAndProportionalSensitivityAtDifferentScales() {
        for zoom: CGFloat in [5, 10, 15] {
            let closer = MapEdgeZoomController.zoom(from: zoom, translationY: -150)
            XCTAssertEqual(closer, zoom + 1, accuracy: 0.001)
            XCTAssertEqual(MapEdgeZoomController.zoom(from: closer, translationY: 150),
                           zoom, accuracy: 0.001)
        }
    }

    func testLimitsAndReversalHaveNoOverscrollDeadZone() {
        let closest = MapEdgeZoomController.zoom(from: 21, translationY: -10_000)
        let farthest = MapEdgeZoomController.zoom(from: 1, translationY: 10_000)
        XCTAssertEqual(closest, 22)
        XCTAssertEqual(farthest, 0)
        XCTAssertLessThan(MapEdgeZoomController.zoom(from: closest, translationY: 1), closest)
        XCTAssertGreaterThan(MapEdgeZoomController.zoom(from: farthest, translationY: -1), farthest)
        XCTAssertEqual(MapEdgeZoomController.zoom(from: 15, translationY: .nan), 15)
        XCTAssertEqual(MapEdgeZoomController.zoom(from: 15, translationY: 150,
                                                 minimum: 14.5, maximum: 16), 14.5)
    }

    func testDefaultMapboxRangeAllowsZoomInBothDirectionsWithoutJumping() {
        let map = makeMap()
        let bounds = map.mapboxMap.cameraBounds
        for (translation, expected) in [(CGFloat(-150), CGFloat(16)), (CGFloat(150), 14), (.zero, 15)] {
            XCTAssertEqual(
                MapEdgeZoomController.zoom(
                    from: 15,
                    translationY: translation,
                    minimum: bounds.minZoom,
                    maximum: bounds.maxZoom
                ),
                expected,
                accuracy: 0.001
            )
        }
    }

    func testDefaultBoundsCanBeCombinedWithAnExplicitZoomLimit() throws {
        let map = makeMap()
        try map.mapboxMap.setCameraBounds(with: CameraBoundsOptions(minZoom: 14))
        var bounds = map.mapboxMap.cameraBounds
        XCTAssertEqual(
            MapEdgeZoomController.zoom(from: 15, translationY: -1_800,
                                        minimum: bounds.minZoom, maximum: bounds.maxZoom),
            22
        )
        XCTAssertEqual(
            MapEdgeZoomController.zoom(from: 15, translationY: 300,
                                        minimum: bounds.minZoom, maximum: bounds.maxZoom),
            14
        )
        try map.mapboxMap.setCameraBounds(with: CameraBoundsOptions(maxZoom: 17, minZoom: 0))
        bounds = map.mapboxMap.cameraBounds
        XCTAssertEqual(
            MapEdgeZoomController.zoom(from: 15, translationY: -1_800,
                                        minimum: bounds.minZoom, maximum: bounds.maxZoom),
            17
        )
        XCTAssertEqual(
            MapEdgeZoomController.zoom(from: 15, translationY: 150,
                                        minimum: bounds.minZoom, maximum: bounds.maxZoom),
            14
        )
    }

    func testControlsAndAnnotationsAreExcludedThroughTheirDescendants() {
        let map = makeMap()
        let button = UIButton()
        let label = UILabel()
        map.addSubview(button)
        button.addSubview(label)
        XCTAssertTrue(MapEdgeZoomController.excludesTouch(on: label, mapView: map))
        let annotation = MapAnnotationView()
        let image = UIImageView()
        map.addSubview(annotation)
        annotation.addSubview(image)
        XCTAssertTrue(MapEdgeZoomController.excludesTouch(on: image, mapView: map))
        XCTAssertFalse(MapEdgeZoomController.excludesTouch(on: map, mapView: map))
    }

    func testGesturePriorityStaysInsideMapAndUninstallRestoresHierarchy() throws {
        let map = makeMap()
        let viewport = MapViewportView(mapView: map, renderSize: nil)
        let initialRecognizers = map.gestureRecognizers ?? []
        let initialSubviews = map.subviews
        let controller = MapEdgeZoomController(viewport: viewport) { XCTFail("No zoom has begun") }
        let pan = try XCTUnwrap(map.gestureRecognizers?.first { controller.owns($0) })
        let nativeSurface = UIView()
        map.addSubview(nativeSurface)
        let nativePan = UIPanGestureRecognizer()
        nativeSurface.addGestureRecognizer(nativePan)
        XCTAssertTrue(controller.gestureRecognizer(pan, shouldBeRequiredToFailBy: nativePan))
        let longPress = UILongPressGestureRecognizer()
        map.addGestureRecognizer(longPress)
        XCTAssertFalse(controller.gestureRecognizer(pan, shouldBeRequiredToFailBy: longPress))
        let systemEdge = UIScreenEdgePanGestureRecognizer()
        nativeSurface.addGestureRecognizer(systemEdge)
        XCTAssertFalse(controller.gestureRecognizer(pan, shouldBeRequiredToFailBy: systemEdge))
        let outsidePan = UIPanGestureRecognizer()
        viewport.addGestureRecognizer(outsidePan)
        XCTAssertFalse(controller.gestureRecognizer(pan, shouldBeRequiredToFailBy: outsidePan))
        XCTAssertFalse(controller.gestureRecognizer(pan, shouldRecognizeSimultaneouslyWith: nativePan))
        controller.cancel()
        XCTAssertFalse(controller.isActive)
        controller.uninstall()
        map.removeGestureRecognizer(longPress)
        nativeSurface.removeFromSuperview()
        XCTAssertEqual(map.gestureRecognizers ?? [], initialRecognizers)
        XCTAssertEqual(map.subviews, initialSubviews)
    }

    func testFeedbackFollowsFingerOnEitherEdgeAndRetractsWithoutInterceptingTouches() throws {
        let feedback = MapEdgeZoomFeedbackView()
        let bounds = CGRect(x: 0, y: 240, width: 375, height: 200)
        feedback.show(at: CGPoint(x: 370, y: 330), edge: .right, in: bounds)
        let shape = try XCTUnwrap(feedback.layer.sublayers?.first as? CAShapeLayer)
        var outline = try XCTUnwrap(shape.path).boundingBoxOfPath
        XCTAssertEqual(outline.maxX, 375)
        XCTAssertEqual(outline.width, 20)
        XCTAssertEqual(outline.midY, 90)
        XCTAssertFalse(feedback.isUserInteractionEnabled)
        XCTAssertTrue(feedback.clipsToBounds)
        XCTAssertTrue(feedback.isShowing)
        feedback.dismiss()
        XCTAssertFalse(feedback.isShowing)
        feedback.show(at: CGPoint(x: 10, y: 360), edge: .left, in: bounds)
        outline = try XCTUnwrap(shape.path).boundingBoxOfPath
        XCTAssertEqual(outline.minX, 0)
        XCTAssertEqual(outline.midY, 120)
        feedback.dismiss()
        XCTAssertFalse(feedback.isShowing)
        XCTAssertEqual(try XCTUnwrap(shape.path).boundingBoxOfPath.width, 0)
    }

    private func makeMap(frame: CGRect = .zero) -> MapboxMaps.MapView {
        MapboxMaps.MapView(frame: frame, mapInitOptions: MapInitOptions(
            styleJSON: #"{"version":8,"sources":{},"layers":[]}"#
        ))
    }
}
