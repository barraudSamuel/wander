import MapboxMaps
import UIKit
import XCTest
@testable import wander

@MainActor
final class MapViewportViewTests: XCTestCase {
    func testChangingContentInsetsPreservesFullViewportAndNativeBounds() {
        let map = makeMap()
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
        XCTAssertEqual(map.ornaments.options.logo.margins, CGPoint(x: 20, y: 248))
        XCTAssertEqual(map.ornaments.options.attributionButton.margins, CGPoint(x: 16, y: 248))

        let paneInsets = UIEdgeInsets(top: 0, left: 6, bottom: 83, right: 4)
        viewport.contentInsets = paneInsets
        viewport.layoutIfNeeded()
        XCTAssertEqual(viewport.visibleSafeMapRect, CGRect(x: 6, y: 240, width: 365, height: 117))
        XCTAssertEqual(map.ornaments.options.logo.margins, CGPoint(x: 14, y: 248))
        XCTAssertEqual(map.ornaments.options.attributionButton.margins, CGPoint(x: 12, y: 248))
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
        let map = makeMap()
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
        map.layoutIfNeeded()
        for ornament in [map.ornaments.logoView, map.ornaments.attributionButton] {
            let frame = map.convert(ornament.bounds, from: ornament)
            XCTAssertFalse(frame.isEmpty)
            XCTAssertTrue(viewport.ornamentSafeMapRect.contains(frame), "Required ornament must remain above the home indicator")
            XCTAssertEqual(frame.maxY, viewport.ornamentSafeMapRect.maxY - 8, accuracy: 1)
            XCTAssertGreaterThan(frame.maxY, safe.maxY, "Camera padding must not lift the corner ornaments")
        }
    }

    func testResizingVisibleWindowKeepsNativeMapBoundsStable() {
        let size = CGSize(width: 375, height: 680)
        let map = makeMap()
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
        let map = makeMap()
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
        XCTAssertEqual(map.ornaments.options.attributionButton.margins.y, 248, accuracy: 0.01)
    }

    func testChangingAvailableScreenSizeUpdatesBackingSize() {
        let map = makeMap()
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

    func testSheetOcclusionMovesOnlyOrnamentsAndRestoresTheirFullViewport() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = scene.effectiveGeometry.coordinateSpace.bounds
        let host = UIViewController()
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        let map = makeMap()
        let viewport = MapViewportView(mapView: map, renderSize: CGSize(width: 375, height: 680))
        viewport.frame = CGRect(x: 0, y: 0, width: 375, height: 680)
        viewport.contentInsets = UIEdgeInsets(top: 60, left: 0, bottom: 34, right: 0)
        host.view.addSubview(viewport)
        viewport.layoutIfNeeded()
        let safe = viewport.visibleSafeMapRect
        let initialOrnamentRect = viewport.ornamentSafeMapRect
        let initialCamera = map.mapboxMap.cameraState
        var viewportChanges = 0
        viewport.onViewportChange = { viewportChanges += 1 }

        for sheetTop: CGFloat in [450, 350, 520] {
            viewport.updateOrnaments(occludedBelow: sheetTop)
            try await waitForOrnaments("Required native frames must move above the synthetic sheet",
                                       diagnostics: { self.ornamentDiagnostics(viewport) }) {
                map.layoutIfNeeded()
                return self.requiredOrnamentsFit(in: viewport.ornamentSafeMapRect, map: map)
            }
            XCTAssertEqual(viewport.ornamentSafeMapRect.maxY, sheetTop)
            XCTAssertEqual(viewport.visibleSafeMapRect, safe)
            XCTAssertEqual(map.bounds.size, CGSize(width: 375, height: 680))
            for ornament in [map.ornaments.logoView, map.ornaments.attributionButton] {
                let frame = map.convert(ornament.bounds, from: ornament)
                XCTAssertFalse(frame.isEmpty)
                XCTAssertTrue(viewport.ornamentSafeMapRect.contains(frame), ornamentDiagnostics(viewport))
            }
        }
        viewport.updateOrnaments(occludedBelow: safe.minY - 20)
        try await waitForOrnaments("Covered controls must remain inside the underlying safe map",
                                   diagnostics: { self.ornamentDiagnostics(viewport) }) {
            map.layoutIfNeeded()
            return self.requiredOrnamentsFit(in: safe, map: map)
        }
        XCTAssertEqual(viewport.ornamentSafeMapRect.height, 0)
        for ornament in [map.ornaments.logoView, map.ornaments.attributionButton] {
            XCTAssertTrue(safe.contains(map.convert(ornament.bounds, from: ornament)))
        }
        viewport.updateOrnaments()
        XCTAssertEqual(viewport.ornamentSafeMapRect, initialOrnamentRect)
        XCTAssertEqual(viewportChanges, 0)
        XCTAssertEqual(map.mapboxMap.cameraState, initialCamera)
        map.layoutIfNeeded()
        XCTAssertTrue(map.ornaments.compassView.isHidden)
    }

    func testNativeSheetTrackingFollowsDetentChangesAndDismissal() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = scene.effectiveGeometry.coordinateSpace.bounds
        let map = makeMap()
        let viewport = MapViewportView(mapView: map, renderSize: window.bounds.size)
        let host = AppearanceReportingController()
        host.view = viewport
        window.rootViewController = host
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        try await waitForOrnaments("The host must complete its appearance before presenting a sheet") {
            host.hasAppeared
        }
        viewport.tracksSheetPresentation = true
        defer {
            viewport.stopTrackingSheetPresentation()
            host.dismiss(animated: false)
            window.isHidden = true
            window.rootViewController = nil
        }
        let initialCamera = map.mapboxMap.cameraState
        let sheet = UIViewController()
        sheet.modalPresentationStyle = .pageSheet
        let compact = UISheetPresentationController.Detent.Identifier("ornament-test-compact")
        let presentation = try XCTUnwrap(sheet.sheetPresentationController)
        presentation.detents = [.custom(identifier: compact) { _ in 240 }, .large()]
        presentation.selectedDetentIdentifier = compact
        presentation.largestUndimmedDetentIdentifier = compact
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            host.present(sheet, animated: false) { continuation.resume() }
        }
        try await waitForOrnaments("Native compact sheet must move required ornament frames",
                                   diagnostics: { self.ornamentDiagnostics(viewport, sheet: presentation) }) {
            map.layoutIfNeeded()
            return viewport.ornamentSafeMapRect.maxY < viewport.visibleSafeMapRect.maxY - 100
                && self.requiredOrnamentsFit(in: viewport.ornamentSafeMapRect, map: map)
        }
        map.layoutIfNeeded()
        let compactBottom = viewport.ornamentSafeMapRect.maxY
        for ornament in [map.ornaments.logoView, map.ornaments.attributionButton] {
            XCTAssertTrue(viewport.ornamentSafeMapRect.contains(map.convert(ornament.bounds, from: ornament)),
                          ornamentDiagnostics(viewport, sheet: presentation))
        }
        presentation.animateChanges { presentation.selectedDetentIdentifier = .large }
        try await waitForOrnaments("Native expanded sheet must update ornament clipping",
                                   diagnostics: { self.ornamentDiagnostics(viewport, sheet: presentation) }) {
            viewport.ornamentSafeMapRect.maxY < compactBottom - 100
        }
        host.dismiss(animated: false)
        viewport.tracksSheetPresentation = false
        try await waitForOrnaments("Dismissing the sheet must restore the full ornament area",
                                   diagnostics: { self.ornamentDiagnostics(viewport) }) {
            map.layoutIfNeeded()
            return viewport.ornamentSafeMapRect == viewport.visibleSafeMapRect
                && self.requiredOrnamentsFit(in: viewport.visibleSafeMapRect, map: map)
        }
        XCTAssertEqual(map.bounds.size, window.bounds.size)
        XCTAssertEqual(map.mapboxMap.cameraState, initialCamera)
    }

    private func requiredOrnamentsFit(in rect: CGRect, map: MapboxMaps.MapView) -> Bool {
        [map.ornaments.logoView, map.ornaments.attributionButton].allSatisfy {
            let frame = map.convert($0.bounds, from: $0)
            return !frame.isEmpty && rect.contains(frame)
        }
    }

    private func ornamentDiagnostics(_ viewport: MapViewportView,
                                     sheet: UISheetPresentationController? = nil) -> String {
        let map = viewport.mapView
        let logo = map.convert(map.ornaments.logoView.bounds, from: map.ornaments.logoView)
        let attribution = map.convert(map.ornaments.attributionButton.bounds, from: map.ornaments.attributionButton)
        let sheetFrame = sheet?.presentedView.map { map.convert($0.bounds, from: $0) }
        let presentationFrame = sheet?.presentedView?.layer.presentation()?.frame
        let view = sheet?.presentedView
        let containerFrame: CGRect?
        if let sheet, let container = sheet.containerView {
            containerFrame = map.convert(sheet.frameOfPresentedViewInContainerView, from: container)
        } else {
            containerFrame = nil
        }
        return "visible=\(viewport.visibleMapRect), safe=\(viewport.visibleSafeMapRect), "
            + "ornamentRect=\(viewport.ornamentSafeMapRect), mapSafe=\(map.safeAreaInsets), "
            + "logo=\(logo), attribution=\(attribution), "
            + "logoMargins=\(map.ornaments.options.logo.margins), "
            + "attributionMargins=\(map.ornaments.options.attributionButton.margins), "
            + "sheet=\(String(describing: sheetFrame)), layer=\(String(describing: presentationFrame)), "
            + "modelFrame=\(String(describing: view?.frame)), bounds=\(String(describing: view?.bounds)), "
            + "parentFrame=\(String(describing: view?.superview?.frame)), "
            + "windowFrame=\(String(describing: view?.window?.frame)), "
            + "presentationRect=\(String(describing: sheet?.frameOfPresentedViewInContainerView)), "
            + "presentationRectInMap=\(String(describing: containerFrame)), "
            + "detent=\(String(describing: sheet?.selectedDetentIdentifier))"
    }

    private func waitForOrnaments(_ message: String, diagnostics: () -> String = { "" },
                                  condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(2)
        while !condition(), Date() < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertTrue(condition(), message + "; " + diagnostics())
    }

    private final class AppearanceReportingController: UIViewController {
        private(set) var hasAppeared = false

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            hasAppeared = true
        }
    }

    private func makeMap() -> MapboxMaps.MapView {
        MapboxMaps.MapView(frame: .zero, mapInitOptions: MapInitOptions(
            styleJSON: #"{"version":8,"sources":{},"layers":[]}"#
        ))
    }
}
