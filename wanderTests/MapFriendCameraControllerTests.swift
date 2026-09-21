import MapKit
import XCTest
@testable import wander

@MainActor
final class MapFriendCameraControllerTests: XCTestCase {
    func testOpeningTargetsExposedAreaWithRoomForTheWholePin() throws {
        let safe = CGRect(x: 20, y: 90, width: 350, height: 680)
        let point = try XCTUnwrap(MapFriendCameraController.focusPoint(in: safe, sheetTop: 450))
        XCTAssertEqual(point, CGPoint(x: 195, y: 262))
        XCTAssertGreaterThanOrEqual(point.y - 88, safe.minY)
        XCTAssertLessThan(point.y, 450 - 16)
        XCTAssertNil(MapFriendCameraController.focusPoint(in: safe, sheetTop: 180))
        XCTAssertNil(MapFriendCameraController.focusPoint(in: safe, sheetTop: .nan))
    }

    func testDismissalCentersInTheWholeSafeArea() {
        let safe = CGRect(x: 20, y: 90, width: 350, height: 680)
        let expected = CGPoint(x: 195, y: 430)
        XCTAssertEqual(MapFriendCameraController.focusPoint(in: safe), expected)
    }

    func testInsufficientSpaceAndInvalidGeometryDoNotMoveTheMap() {
        for rect in [CGRect.zero, .null, .infinite,
                     CGRect(x: 0, y: 0, width: 95, height: 400),
                     CGRect(x: 0, y: 0, width: 400, height: 95)] {
            XCTAssertNil(MapFriendCameraController.focusPoint(in: rect))
        }
    }

    func testSessionFreezesCameraSettingsAndDoesNotMoveAtTheFirstFrame() throws {
        let initial = MKMapCamera(lookingAtCenter: .init(latitude: 0, longitude: 0),
                                  fromDistance: 1_200, pitch: 30, heading: 45)
        let session = try XCTUnwrap(MapFriendCameraController.Session(
            camera: initial, focusCoordinate: .init(latitude: 0, longitude: 0.001),
            target: .init(latitude: 0, longitude: 0.003)
        ))
        initial.centerCoordinateDistance = 8_000
        initial.heading = 180
        initial.pitch = 0
        initial.centerCoordinate = .init(latitude: 20, longitude: 30)

        for progress in [0.0, 0.5, 1] {
            let camera = session.camera(at: progress)
            XCTAssertEqual(camera.centerCoordinateDistance, 1_200, accuracy: 0.001)
            XCTAssertEqual(camera.heading, 45, accuracy: 0.001)
            XCTAssertEqual(camera.pitch, 30, accuracy: 0.001)
            XCTAssertEqual(camera.centerCoordinate.longitude, progress * 0.002, accuracy: 0.000001)
        }
        XCTAssertEqual(session.camera(at: .nan).centerCoordinate.longitude, 0, accuracy: 0.000001)
    }

    func testPreparedOpeningTargetsExposedAreaOnRotatedAndTiltedMapWithoutChangingZoom() throws {
        let map = MKMapView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let safe = CGRect(x: 0, y: 60, width: 390, height: 740)
        for pitch in [0.0, 30.0] {
            for heading in [0.0, 45.0, 180.0] {
                map.setCamera(MKMapCamera(lookingAtCenter: .init(latitude: 37.5665, longitude: 126.978),
                                          fromDistance: 1_200, pitch: pitch, heading: heading), animated: false)
                let target = map.convert(CGPoint(x: 230, y: 420), toCoordinateFrom: map)
                let destination = try XCTUnwrap(MapFriendCameraController.focusPoint(in: safe, sheetTop: 450))
                let initialCamera = map.camera.copy() as! MKMapCamera
                let session = try XCTUnwrap(MapFriendCameraController.Session(
                    camera: initialCamera,
                    focusCoordinate: map.convert(destination, toCoordinateFrom: map), target: target
                ))
                map.setCamera(session.camera(at: 1), animated: false)
                let projected = map.convert(target, toPointTo: map)
                XCTAssertEqual(projected.x, destination.x, accuracy: 1)
                XCTAssertEqual(projected.y, destination.y, accuracy: 1)
                XCTAssertEqual(map.camera.centerCoordinateDistance, initialCamera.centerCoordinateDistance, accuracy: 0.01)
                XCTAssertEqual(map.camera.heading, initialCamera.heading, accuracy: 0.01)
                XCTAssertEqual(map.camera.pitch, initialCamera.pitch, accuracy: 0.01)
            }
        }
    }

    func testAnimationTakesShortestRouteAcrossAntimeridian() throws {
        let initial = MKMapCamera(lookingAtCenter: .init(latitude: 0, longitude: 179.999),
                                  fromDistance: 1_200, pitch: 0, heading: 0)
        let session = try XCTUnwrap(MapFriendCameraController.Session(
            camera: initial, focusCoordinate: initial.centerCoordinate,
            target: .init(latitude: 0, longitude: -179.999)
        ))
        XCTAssertEqual(abs(session.camera(at: 0.5).centerCoordinate.longitude), 180, accuracy: 0.000001)
        XCTAssertEqual(session.camera(at: 1).centerCoordinate.longitude, -179.999, accuracy: 0.000001)
        XCTAssertNil(MapFriendCameraController.Session(
            camera: initial, focusCoordinate: kCLLocationCoordinate2DInvalid,
            target: .init(latitude: 0, longitude: 0)
        ))
    }

    func testMissingWindowConsumesRequestAndCancelDoesNotMakeItEligibleAgain() throws {
        let controller = MapFriendCameraController()
        let map = MKMapView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let viewport = MapViewportView(mapView: map, renderSize: nil)
        viewport.frame = map.frame
        viewport.layoutIfNeeded()
        let request = MapFriendCameraRequest(userID: "friend-a")
        let coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        controller.apply(request, coordinate: coordinate, viewport: viewport)
        XCTAssertEqual(controller.lastRequestID, request.id)
        XCTAssertFalse(controller.isAnimating)
        controller.cancel()

        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = try XCTUnwrap(scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)
        let window = UIWindow(windowScene: scene)
        window.frame = viewport.frame
        window.addSubview(viewport)
        XCTAssertNotNil(map.window)
        controller.apply(request, coordinate: coordinate, viewport: viewport)
        XCTAssertEqual(controller.lastRequestID, request.id)
        XCTAssertFalse(controller.isAnimating)
        let dismissal = MapFriendCameraRequest(userID: request.userID)
        XCTAssertNotEqual(dismissal.id, request.id)
        controller.cancel(consuming: dismissal)
        controller.apply(dismissal, coordinate: coordinate, viewport: viewport)
        XCTAssertEqual(controller.lastRequestID, dismissal.id)
        XCTAssertFalse(controller.isAnimating)
    }
}
