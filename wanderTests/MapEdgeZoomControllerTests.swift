import MapKit
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
        XCTAssertNil(MapWithFogView.Coordinator.edgeZoomTargetID(for: MKPointAnnotation()))
        XCTAssertEqual(MapWithFogView.Coordinator.edgeZoomTargetID(for: friend), "friend:friend-a")
        XCTAssertEqual(MapWithFogView.Coordinator.edgeZoomTargetID(for: group), "group:group-a")
        group.update(memberAnnotations: [user])
        XCTAssertEqual(MapWithFogView.Coordinator.edgeZoomTargetID(for: group), "group:group-a")
        group.update(memberAnnotations: [MKPointAnnotation()])
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
        let initial = MKMapCamera(lookingAtCenter: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                                 fromDistance: 800, pitch: 30, heading: 45)
        let friend = FriendLocationAnnotation()
        friend.coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0.01)
        let target = MapEdgeZoomController.Target(id: "friend:a", coordinate: friend.coordinate, screenPoint: CGPoint(x: 160, y: 300))
        let session = MapEdgeZoomController.ZoomSession(camera: initial, target: target)
        // Both external inputs can change after the gesture starts.
        initial.centerCoordinate = CLLocationCoordinate2D(latitude: 20, longitude: 30)
        friend.coordinate = CLLocationCoordinate2D(latitude: 25, longitude: 35)
        let unchanged = session.camera(at: 800, focusProgress: 0)
        XCTAssertEqual(unchanged.centerCoordinate.latitude, 0, accuracy: 0.000001)
        XCTAssertEqual(unchanged.centerCoordinate.longitude, 0, accuracy: 0.000001)
        let zoomed = session.camera(at: 400)
        XCTAssertEqual(zoomed.centerCoordinate.longitude, 0.01, accuracy: 0.000001)
        XCTAssertEqual(zoomed.centerCoordinateDistance, 400, accuracy: 0.01)
        XCTAssertEqual(zoomed.heading, 45, accuracy: 0.01)
        XCTAssertEqual(zoomed.pitch, 30, accuracy: 0.01)
        XCTAssertEqual(session.anchor?.longitude, 0.01)
        let zoomedOut = session.camera(at: 1_600)
        XCTAssertEqual(zoomedOut.centerCoordinate.longitude, 0.01, accuracy: 0.000001)
        let halfway = session.camera(at: 800, focusProgress: 0.5)
        XCTAssertEqual(halfway.centerCoordinate.longitude, 0.005, accuracy: 0.000001)
    }

    func testZoomWithoutTargetKeepsOriginalCenter() {
        let center = CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.978)
        let camera = MKMapCamera(lookingAtCenter: center, fromDistance: 800, pitch: 0, heading: 90)
        let session = MapEdgeZoomController.ZoomSession(camera: camera, target: nil)
        for distance in [400.0, 1_600.0] {
            let next = session.camera(at: distance)
            XCTAssertEqual(next.centerCoordinate.latitude, center.latitude, accuracy: 0.000001)
            XCTAssertEqual(next.centerCoordinate.longitude, center.longitude, accuracy: 0.000001)
            XCTAssertEqual(next.centerCoordinateDistance, distance, accuracy: 0.01)
            XCTAssertEqual(next.heading, 90, accuracy: 0.01)
        }
    }

    func testTargetCentersInVisibleViewportOnRotatedAndTiltedMap() {
        let map = MKMapView(frame: CGRect(x: 0, y: 0, width: 375, height: 600))
        let center = CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.978)
        for pitch in [0.0, 30.0] {
            for heading in [0.0, 45.0, 180.0] {
                map.setCamera(MKMapCamera(lookingAtCenter: center, fromDistance: 1_200,
                                          pitch: pitch, heading: heading), animated: false)
                let point = CGPoint(x: 230, y: 375)
                let target = MapEdgeZoomController.Target(
                    id: "friend:a",
                    coordinate: map.convert(point, toCoordinateFrom: map),
                    screenPoint: point
                )
                let destination = CGPoint(x: 187.5, y: 325)
                let session = MapEdgeZoomController.ZoomSession(
                    camera: map.camera, target: target,
                    focusCoordinate: map.convert(destination, toCoordinateFrom: map)
                )
                for distance in [1_200.0, 600.0, 2_400.0] {
                    map.setCamera(session.camera(at: distance), animated: false)
                    let projected = map.convert(target.coordinate, toPointTo: map)
                    XCTAssertEqual(projected.x, destination.x, accuracy: 1)
                    XCTAssertEqual(projected.y, destination.y, accuracy: 1)
                }
            }
        }
    }

    func testFocusFeedbackOccursOnlyWhenGestureAcquiresTargetAndCancelStopsCamera() {
        let map = MKMapView(frame: CGRect(x: 0, y: 0, width: 375, height: 600))
        let viewport = MapViewportView(mapView: map, renderSize: nil)
        viewport.frame = map.frame
        viewport.layoutIfNeeded()
        map.setCamera(MKMapCamera(lookingAtCenter: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                                  fromDistance: 1_200, pitch: 0, heading: 0), animated: false)
        var offersTarget = true
        var focusCount = 0
        var beginCount = 0
        let controller = MapEdgeZoomController(viewport: viewport, targets: { map in
            guard offersTarget else { return [] }
            let point = CGPoint(x: 230, y: 375)
            return [.init(id: "friend:a", coordinate: map.convert(point, toCoordinateFrom: map), screenPoint: point)]
        }, onFocus: { focusCount += 1 }, onBegin: { beginCount += 1 })
        controller.begin(on: map)
        XCTAssertEqual(focusCount, 1)
        XCTAssertEqual(beginCount, 1)
        XCTAssertTrue(controller.isActive)
        controller.cancel()
        XCTAssertFalse(controller.isActive)
        let cancelledCenter = map.centerCoordinate
        let settled = expectation(description: "Cancelled focus has no later camera update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { settled.fulfill() }
        wait(for: [settled], timeout: 1)
        XCTAssertEqual(map.centerCoordinate.latitude, cancelledCenter.latitude, accuracy: 0.000001)
        XCTAssertEqual(map.centerCoordinate.longitude, cancelledCenter.longitude, accuracy: 0.000001)
        XCTAssertEqual(focusCount, 1)
        offersTarget = false
        controller.begin(on: map)
        XCTAssertEqual(beginCount, 2)
        XCTAssertEqual(focusCount, 1)
        controller.uninstall()
    }

    func testShortSwipeCompletesFocusAndNewGestureCanInterruptIt() {
        let map = MKMapView(frame: CGRect(x: 0, y: 0, width: 375, height: 600))
        let viewport = MapViewportView(mapView: map, renderSize: nil)
        viewport.frame = map.frame
        viewport.layoutIfNeeded()
        map.setCamera(MKMapCamera(lookingAtCenter: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                                  fromDistance: 1_200, pitch: 0, heading: 0), animated: false)
        let point = CGPoint(x: 230, y: 375)
        let coordinate = map.convert(point, toCoordinateFrom: map)
        var focusCount = 0
        let controller = MapEdgeZoomController(viewport: viewport, targets: { _ in
            [.init(id: "friend:a", coordinate: coordinate, screenPoint: point)]
        }, onFocus: { focusCount += 1 }, onBegin: {})
        controller.begin(on: map, at: 0)
        controller.end()
        controller.advanceFocus(at: 0.2)
        XCTAssertFalse(controller.isActive)
        XCTAssertEqual(focusCount, 1)
        let projected = map.convert(coordinate, toPointTo: map)
        XCTAssertEqual(projected.x, viewport.visibleSafeMapRect.midX, accuracy: 1)
        XCTAssertEqual(projected.y, viewport.visibleSafeMapRect.midY, accuracy: 1)

        controller.begin(on: map, at: 1)
        controller.end()
        controller.begin(on: map, at: 1.05)
        XCTAssertTrue(controller.isActive)
        XCTAssertEqual(focusCount, 3)
        controller.cancel()
        let cancelledCenter = map.centerCoordinate
        controller.advanceFocus(at: 2)
        XCTAssertFalse(controller.isActive)
        XCTAssertEqual(map.centerCoordinate.latitude, cancelledCenter.latitude, accuracy: 0.000001)
        XCTAssertEqual(map.centerCoordinate.longitude, cancelledCenter.longitude, accuracy: 0.000001)
        controller.uninstall()
    }

    func testAnchorAcrossAntimeridianUsesNearestWorldCopy() {
        let center = MapEdgeZoomController.anchoredCenter(
            initial: CLLocationCoordinate2D(latitude: 0, longitude: 179.999),
            anchor: CLLocationCoordinate2D(latitude: 0, longitude: -179.999),
            scale: 0.5
        )
        XCTAssertEqual(abs(center.longitude), 180, accuracy: 0.000001)
        XCTAssertEqual(center.latitude, 0, accuracy: 0.000001)
    }

    func testEdgeZonesUseCroppedMapCoordinatesAndRejectHiddenContent() {
        let bounds = CGRect(x: 30, y: 240, width: 375, height: 200)
        XCTAssertEqual(MapEdgeZoomController.edge(at: CGPoint(x: 40, y: 300), in: bounds), .left)
        XCTAssertEqual(MapEdgeZoomController.edge(at: CGPoint(x: 395, y: 300), in: bounds), .right)
        XCTAssertNil(MapEdgeZoomController.edge(at: CGPoint(x: 59, y: 300), in: bounds))
        XCTAssertNil(MapEdgeZoomController.edge(at: CGPoint(x: 376, y: 300), in: bounds))
        XCTAssertNil(MapEdgeZoomController.edge(at: CGPoint(x: 40, y: 239), in: bounds))
        XCTAssertNil(MapEdgeZoomController.edge(at: CGPoint(x: 40, y: 440), in: bounds))
        XCTAssertNil(MapEdgeZoomController.edge(at: .zero, in: .zero))
    }

    func testVerticalIntentRejectsHorizontalAndDiagonalPanning() {
        XCTAssertTrue(MapEdgeZoomController.isVertical(CGPoint(x: 3, y: -20)))
        XCTAssertTrue(MapEdgeZoomController.isVertical(CGPoint(x: -3, y: 20)))
        XCTAssertFalse(MapEdgeZoomController.isVertical(CGPoint(x: 20, y: 3)))
        XCTAssertFalse(MapEdgeZoomController.isVertical(CGPoint(x: 20, y: 20)))
        XCTAssertFalse(MapEdgeZoomController.isVertical(.zero))
    }

    func testZoomDirectionAndProportionalSensitivityAtDifferentScales() {
        for distance in [800.0, 80_000.0, 8_000_000.0] {
            let closer = MapEdgeZoomController.distance(from: distance, translationY: -150)
            XCTAssertEqual(closer, distance / 2, accuracy: 0.001)
            XCTAssertEqual(MapEdgeZoomController.distance(from: closer, translationY: 150),
                           distance, accuracy: 0.001)
        }
    }

    func testLimitsAndReversalHaveNoOverscrollDeadZone() {
        let closest = MapEdgeZoomController.distance(from: 100, translationY: -10_000)
        let farthest = MapEdgeZoomController.distance(from: 20_000_000, translationY: 10_000)
        XCTAssertEqual(closest, 80)
        XCTAssertEqual(farthest, 30_000_000)
        XCTAssertGreaterThan(MapEdgeZoomController.distance(from: closest, translationY: 1), closest)
        XCTAssertLessThan(MapEdgeZoomController.distance(from: farthest, translationY: -1), farthest)
        XCTAssertEqual(MapEdgeZoomController.distance(from: 800, translationY: .nan), 800)
        XCTAssertEqual(MapEdgeZoomController.distance(from: 800, translationY: 150,
                                                     minimum: 100, maximum: 1_000), 1_000)
    }

    func testDefaultMapKitRangeAllowsZoomInBothDirectionsWithoutJumping() throws {
        let map = MKMapView()
        let range = try XCTUnwrap(map.cameraZoomRange)
        for (translation, expected) in [(CGFloat(-150), 400.0), (CGFloat(150), 1600.0), (.zero, 800.0)] {
            XCTAssertEqual(
                MapEdgeZoomController.distance(
                    from: 800,
                    translationY: translation,
                    minimum: range.minCenterCoordinateDistance,
                    maximum: range.maxCenterCoordinateDistance
                ),
                expected,
                accuracy: 0.001
            )
        }
    }

    func testDefaultSentinelCanBeCombinedWithAnExplicitZoomLimit() {
        XCTAssertEqual(
            MapEdgeZoomController.distance(from: 800, translationY: -1_800,
                                           minimum: MKMapCameraZoomDefault, maximum: 1_000),
            80
        )
        XCTAssertEqual(
            MapEdgeZoomController.distance(from: 800, translationY: 150,
                                           minimum: MKMapCameraZoomDefault, maximum: 1_000),
            1_000
        )
        XCTAssertEqual(
            MapEdgeZoomController.distance(from: 800, translationY: -1_800,
                                           minimum: 100, maximum: MKMapCameraZoomDefault),
            100
        )
        XCTAssertEqual(
            MapEdgeZoomController.distance(from: 800, translationY: 150,
                                           minimum: 100, maximum: MKMapCameraZoomDefault),
            1_600
        )
    }

    func testControlsAndAnnotationsAreExcludedThroughTheirDescendants() {
        let map = MKMapView()
        let button = UIButton()
        let label = UILabel()
        map.addSubview(button)
        button.addSubview(label)
        XCTAssertTrue(MapEdgeZoomController.excludesTouch(on: label, mapView: map))
        let annotation = MKAnnotationView()
        let image = UIImageView()
        map.addSubview(annotation)
        annotation.addSubview(image)
        XCTAssertTrue(MapEdgeZoomController.excludesTouch(on: image, mapView: map))
        XCTAssertFalse(MapEdgeZoomController.excludesTouch(on: map, mapView: map))
    }

    func testGesturePriorityStaysInsideMapAndUninstallRestoresHierarchy() throws {
        let map = MKMapView()
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
}
