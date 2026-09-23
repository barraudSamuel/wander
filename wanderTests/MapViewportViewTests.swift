import MapKit
import XCTest
@testable import wander

@MainActor
final class MapViewportViewTests: XCTestCase {
    func testChangingContentInsetsPreservesFullViewportAndNativeBounds() {
        let map = MKMapView()
        let renderSize = CGSize(width: 375, height: 680)
        let viewport = MapViewportView(
            mapView: map,
            renderSize: renderSize,
            contentInsets: UIEdgeInsets(top: 20, left: 12, bottom: 34, right: 8)
        )
        var safeRects: [CGRect] = []
        viewport.onViewportChange = { [weak viewport] in
            guard let viewport else { return }
            safeRects.append(viewport.visibleSafeMapRect)
        }
        viewport.frame = CGRect(x: 0, y: 0, width: 375, height: 200)
        viewport.layoutIfNeeded()

        XCTAssertEqual(viewport.visibleMapRect, CGRect(x: 0, y: 240, width: 375, height: 200))
        XCTAssertEqual(viewport.visibleSafeMapRect, CGRect(x: 12, y: 260, width: 355, height: 146))
        XCTAssertEqual(map.layoutMargins, UIEdgeInsets(top: 260, left: 12, bottom: 274, right: 8))

        let paneInsets = UIEdgeInsets(top: 0, left: 6, bottom: 83, right: 4)
        viewport.contentInsets = paneInsets
        viewport.layoutIfNeeded()
        XCTAssertEqual(viewport.visibleSafeMapRect, CGRect(x: 6, y: 240, width: 365, height: 117))
        XCTAssertEqual(map.layoutMargins, UIEdgeInsets(top: 240, left: 6, bottom: 323, right: 4))
        XCTAssertEqual(map.bounds.size, renderSize)
        XCTAssertEqual(viewport.visibleMapRect, CGRect(x: 0, y: 240, width: 375, height: 200))
        XCTAssertEqual(safeRects.count, 2)
        XCTAssertEqual(safeRects.last, viewport.visibleSafeMapRect)

        viewport.contentInsets = paneInsets
        viewport.layoutIfNeeded()
        viewport.setNeedsLayout()
        viewport.layoutIfNeeded()
        XCTAssertEqual(safeRects.count, 2)
        XCTAssertEqual(map.bounds.size, renderSize)
    }

    func testContentInsetsUseTheLargerSystemOrExplicitInsetOnEachEdge() throws {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = try XCTUnwrap(scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)
        let window = UIWindow(windowScene: scene)
        window.frame = scene.effectiveGeometry.coordinateSpace.bounds
        let controller = UIViewController()
        let map = MKMapView()
        let renderSize = CGSize(width: window.bounds.width + 80, height: window.bounds.height + 200)
        let viewport = MapViewportView(
            mapView: map,
            renderSize: renderSize
        )
        controller.view = viewport
        controller.additionalSafeAreaInsets = UIEdgeInsets(top: 30, left: 16, bottom: 20, right: 8)
        window.rootViewController = controller
        window.isHidden = false
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        window.layoutIfNeeded()
        viewport.layoutIfNeeded()

        let systemInsets = viewport.safeAreaInsets
        XCTAssertGreaterThan(systemInsets.top, 0)
        XCTAssertGreaterThan(systemInsets.right, 0)
        let explicitLeft = systemInsets.left + 24
        let explicitBottom = systemInsets.bottom + 40
        viewport.contentInsets = UIEdgeInsets(top: 0, left: explicitLeft, bottom: explicitBottom, right: 0)
        viewport.layoutIfNeeded()
        let safe = viewport.visibleSafeMapRect
        let visible = viewport.visibleMapRect
        XCTAssertEqual(safe.minY - visible.minY, systemInsets.top, accuracy: 0.01)
        XCTAssertEqual(safe.minX - visible.minX, explicitLeft, accuracy: 0.01)
        XCTAssertEqual(visible.maxY - safe.maxY, explicitBottom, accuracy: 0.01)
        XCTAssertEqual(visible.maxX - safe.maxX, systemInsets.right, accuracy: 0.01)
        XCTAssertEqual(map.bounds.size, renderSize)
    }

    func testResizingVisibleWindowKeepsNativeMapBoundsStable() {
        let size = CGSize(width: 375, height: 680)
        let map = MKMapView()
        let viewport = MapViewportView(mapView: map, renderSize: size)

        // Include drags, event/friend list switches, a profile suspension and closure.
        let heights: [CGFloat] = [680, 317, 300, 243, 180, 140, 475, 340, 260, 475, 260, 680, 260, 680]
        for height in heights {
            viewport.frame = CGRect(x: 0, y: 0, width: 375, height: height)
            viewport.layoutIfNeeded()
            XCTAssertEqual(map.bounds.size, size)
            XCTAssertEqual(viewport.visibleMapRect.height, height, accuracy: 0.01)
            XCTAssertEqual(viewport.visibleMapRect.midY, map.bounds.midY, accuracy: 0.01)
            XCTAssertEqual(viewport.visibleMapRect.midX, map.bounds.midX, accuracy: 0.01)
        }
    }

    func testVisibleGeometryUsesNativeCoordinatesAndNotifiesOnlyOnChange() {
        let map = MKMapView()
        let viewport = MapViewportView(
            mapView: map,
            renderSize: CGSize(width: 375, height: 680)
        )
        var changes = 0
        viewport.onViewportChange = {
            changes += 1
            XCTAssertEqual(viewport.visibleMapRect, CGRect(x: 0, y: 240, width: 375, height: 200))
        }
        viewport.frame = CGRect(x: 0, y: 0, width: 375, height: 200)
        viewport.layoutIfNeeded()
        viewport.setNeedsLayout()
        viewport.layoutIfNeeded()

        XCTAssertEqual(changes, 1)
        XCTAssertEqual(viewport.visibleSafeMapRect, viewport.visibleMapRect)
        XCTAssertTrue(viewport.clipsToBounds)
        XCTAssertFalse(viewport.point(inside: CGPoint(x: 100, y: -10), with: nil))
        XCTAssertEqual(map.layoutMargins.top, 240, accuracy: 0.01)
        XCTAssertEqual(map.layoutMargins.bottom, 240, accuracy: 0.01)
    }

    func testChangingAvailableScreenSizeUpdatesBackingSize() {
        let map = MKMapView()
        let viewport = MapViewportView(
            mapView: map,
            renderSize: CGSize(width: 375, height: 680)
        )
        viewport.frame = CGRect(x: 0, y: 0, width: 375, height: 200)
        viewport.layoutIfNeeded()
        viewport.renderSize = CGSize(width: 680, height: 375)
        viewport.frame = CGRect(x: 0, y: 0, width: 680, height: 140)
        viewport.layoutIfNeeded()

        XCTAssertEqual(map.bounds.size, CGSize(width: 680, height: 375))
        XCTAssertEqual(viewport.visibleMapRect, CGRect(x: 0, y: 117.5, width: 680, height: 140))
    }
}
