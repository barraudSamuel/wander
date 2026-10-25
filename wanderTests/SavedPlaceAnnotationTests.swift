import MapboxMaps
import SwiftUI
import UIKit
import XCTest
@testable import wander

@MainActor
final class SavedPlaceAnnotationTests: XCTestCase {
    func testVisualMeasurementSurvivesAStaleNativeFrame() {
        let annotation = makeAnnotation(name: String(repeating: "Café avec un nom long ", count: 8))
        let pin = SavedPlaceAnnotationView(annotation: annotation, reuseIdentifier: nil)
        pin.configure(with: annotation)
        pin.setMapEmphasis(1)
        let expectedVisualRect = pin.currentVisualRect
        // Native placement owns the fixed host, not the photo or category size.
        pin.frame = CGRect(x: 80, y: 80, width: 44, height: 44)
        XCTAssertEqual(pin.systemLayoutSizeFitting(CGSize(width: 390, height: 700)), CGSize(width: 44, height: 44))
        XCTAssertEqual(pin.currentVisualRect, expectedVisualRect)
        XCTAssertGreaterThan(expectedVisualRect.width, 44)
    }

    func testNeighborsGrowTogetherAndTheFrontPhotoReceivesTheTap() async throws {
        let (map, store, window, previous) = try makeLayoutFixture()
        defer { store.removeAll(); window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        let center = CGPoint(x: map.bounds.midX, y: map.bounds.midY)
        let first = makeAnnotation(name: "Centre", id: "z-center")
        let second = makeAnnotation(name: "Voisin", id: "a-neighbor")
        first.coordinate = map.mapboxMap.coordinate(for: center)
        second.coordinate = map.mapboxMap.coordinate(for: CGPoint(x: center.x + 30, y: center.y))
        store.addAnnotations([second, first])
        let pins = try [first, second].map { try XCTUnwrap(store.view(for: $0) as? SavedPlaceAnnotationView) }
        let native = try pins.map { pin in try XCTUnwrap(map.viewAnnotations.allAnnotations.first { $0.view === pin }) }
        try await waitUntil { pins.allSatisfy { !$0.isHidden && !$0.isTransitioning } }
        XCTAssertTrue(native.allSatisfy(\.visible))
        for pin in pins { XCTAssertEqual(pin.renderedBodyRect.width, 50, accuracy: 0.1) }
        XCTAssertGreaterThan(try XCTUnwrap(native[0].priority), try XCTUnwrap(native[1].priority))
        var activated: SavedPlaceAnnotation?
        store.onActivateSavedPlace = { activated = $0 }
        // This point belongs to both drawn photos and is nearer the rear pin.
        XCTAssertTrue(store.activateSavedPlace(at: CGPoint(x: center.x + 20, y: center.y - 31)))
        XCTAssertTrue(activated === first)
        XCTAssertTrue(pins[0].superview === pins[1].superview)
        if let siblings = pins[0].superview?.subviews,
           let frontIndex = siblings.firstIndex(of: pins[0]), let rearIndex = siblings.firstIndex(of: pins[1]) {
            XCTAssertGreaterThan(frontIndex, rearIndex, "Native drawing order must match hit resolution")
        }

        map.mapboxMap.setCamera(to: CameraOptions(center: second.coordinate))
        store.updateSavedPlacePresentation()
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertGreaterThan(try XCTUnwrap(native[1].priority), try XCTUnwrap(native[0].priority))
        let firstPoint = map.mapboxMap.point(for: first.coordinate)
        XCTAssertTrue(store.activateSavedPlace(at: CGPoint(x: firstPoint.x + 10, y: firstPoint.y - 31)))
        XCTAssertTrue(activated === second, "The foreground changes with the centre, even while photos overlap")
        store.removeAnnotation(first)
        XCTAssertEqual(pins[1].renderedBodyRect.width, 50, accuracy: 0.1,
                       "Removing a neighbour must not change the remaining photo size")
    }

    func testOverlappingPhotosStayVisibleDuringZoomOutAndCoordinateUpdates() async throws {
        let (map, store, window, previous) = try makeLayoutFixture()
        defer { store.removeAll(); window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        let places = [0.0, 12, 24].enumerated().map { index, x in
            let place = makeAnnotation(name: "Café \(index)", id: "close-\(index)")
            place.coordinate = map.mapboxMap.coordinate(for: CGPoint(x: map.bounds.midX + x, y: map.bounds.midY))
            return place
        }
        store.addAnnotations(places)
        let pins = try places.map { try XCTUnwrap(store.view(for: $0) as? SavedPlaceAnnotationView) }
        let native = try pins.map { pin in try XCTUnwrap(map.viewAnnotations.allAnnotations.first { $0.view === pin }) }
        let camera = map.mapboxMap.onCameraChanged.observe { _ in store.updateSavedPlacePresentation() }
        defer { camera.cancel() }
        try await waitUntil { pins.allSatisfy { !$0.isTransitioning && !$0.isHidden } }
        var finished = false
        map.camera.ease(to: CameraOptions(zoom: 11.8), duration: 0.8) { _ in finished = true }
        try await waitUntil {
            XCTAssertTrue(native.allSatisfy(\.visible), "Overlap must not hide a saved address")
            return finished
        }
        try await waitUntil { pins.allSatisfy { !$0.isTransitioning } }
        for pin in pins { XCTAssertEqual(pin.renderedBodyRect.width, 24, accuracy: 0.1) }
        store.selectAnnotation(places[2], animated: false)
        XCTAssertTrue(native.allSatisfy(\.visible))
        XCTAssertEqual(native[2].priority, 1)
        store.deselectAnnotation(places[2], animated: false)
        let coordinate = places[0].coordinate
        places[0].coordinate = kCLLocationCoordinate2DInvalid
        store.synchronizeCoordinates()
        XCTAssertFalse(native[0].visible)
        places[0].coordinate = coordinate
        places[0].coordinate.longitude -= 1
        store.synchronizeCoordinates()
        XCTAssertFalse(native[0].visible, "Offscreen Mapbox sentinel must not become an upper-left pin")
        places[0].coordinate = coordinate
        store.synchronizeCoordinates()
        XCTAssertTrue(native[0].visible)
    }

    func testDrawnPhotoWinsOverForegroundMarginAndEmptyMarginsUseNearestAnchor() async throws {
        let (map, store, window, previous) = try makeLayoutFixture()
        defer { store.removeAll(); window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        map.mapboxMap.setCamera(to: CameraOptions(zoom: 12))
        let center = CGPoint(x: map.bounds.midX, y: map.bounds.midY)
        let front = makeAnnotation(name: "Centre", id: "front")
        let rear = makeAnnotation(name: "Voisin", id: "rear")
        front.coordinate = map.mapboxMap.coordinate(for: center)
        rear.coordinate = map.mapboxMap.coordinate(for: CGPoint(x: center.x + 26, y: center.y))
        store.addAnnotations([front, rear])
        let pins = try [front, rear].map { try XCTUnwrap(store.view(for: $0) as? SavedPlaceAnnotationView) }
        try await waitUntil { pins.allSatisfy { !$0.isHidden && !$0.isTransitioning } }
        for pin in pins { XCTAssertEqual(pin.renderedBodyRect.width, 24, accuracy: 0.1) }
        var activated: SavedPlaceAnnotation?
        store.onActivateSavedPlace = { activated = $0 }
        XCTAssertTrue(store.activateSavedPlace(at: CGPoint(x: center.x + 18, y: center.y - 12)))
        XCTAssertTrue(activated === rear, "The rear photo is drawn where the front pin has only a touch margin")
        activated = nil
        XCTAssertTrue(store.activateSavedPlace(at: CGPoint(x: center.x + 17, y: center.y + 5)))
        XCTAssertTrue(activated === rear, "With no drawn shape under the touch, the nearest anchor wins")
    }

    func testSelectionDoesNotCoverTheNeighborWithAnInvisibleCard() async throws {
        let (map, store, window, previous) = try makeLayoutFixture()
        defer { store.removeAll(); window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        map.mapboxMap.setCamera(to: CameraOptions(zoom: 12))
        let center = CGPoint(x: map.bounds.midX, y: map.bounds.midY)
        let selected = makeAnnotation(name: "Adresse", id: "selected")
        let neighbor = makeAnnotation(name: "Voisin", id: "neighbor")
        selected.coordinate = map.mapboxMap.coordinate(for: center)
        neighbor.coordinate = map.mapboxMap.coordinate(for: CGPoint(x: center.x + 100, y: center.y - 88))
        store.addAnnotations([selected, neighbor])
        let pin = try XCTUnwrap(store.view(for: selected) as? SavedPlaceAnnotationView)
        let other = try XCTUnwrap(store.view(for: neighbor) as? SavedPlaceAnnotationView)
        try await waitUntil { !pin.isHidden && !other.isHidden && !pin.isTransitioning }
        store.selectAnnotation(selected, animated: false)
        XCTAssertEqual(pin.renderedBodyRect.width, 24)
        var activated: SavedPlaceAnnotation?
        store.onActivateSavedPlace = { activated = $0 }
        XCTAssertTrue(store.activateSavedPlace(at: CGPoint(x: center.x + 100, y: center.y - 100)))
        XCTAssertTrue(activated === neighbor)
        XCTAssertFalse(store.activateSavedPlace(at: CGPoint(x: center.x + 20, y: center.y - 100)),
                       "The old photo card area must remain available to map gestures")
        XCTAssertTrue(store.activateSavedPlace(at: CGPoint(x: center.x, y: center.y - 12)))
        XCTAssertTrue(activated === selected)
    }

    func testSidesShrinkWhileUpperCentralPhotosRemainLargeAndPanIsContinuous() async throws {
        let (map, store, window, previous) = try makeLayoutFixture()
        defer { store.removeAll(); window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        let positions = [CGPoint(x: map.bounds.midX, y: map.bounds.midY),
                         CGPoint(x: map.bounds.midX, y: map.bounds.height * 0.15),
                         CGPoint(x: map.bounds.maxX - 22, y: map.bounds.midY)]
        let places = positions.enumerated().map { index, point in
            let place = makeAnnotation(name: "Position \(index)", id: "position-\(index)")
            place.coordinate = map.mapboxMap.coordinate(for: point)
            return place
        }
        store.addAnnotations(places)
        let pins = try places.map { try XCTUnwrap(store.view(for: $0) as? SavedPlaceAnnotationView) }
        let camera = map.mapboxMap.onCameraChanged.observe { _ in store.updateSavedPlacePresentation() }
        defer { camera.cancel() }
        try await waitUntil { pins.allSatisfy { !$0.isHidden && !$0.isTransitioning } }
        XCTAssertEqual(pins[0].renderedBodyRect.width, 50, accuracy: 0.1)
        XCTAssertEqual(pins[1].renderedBodyRect.width, 50, accuracy: 0.1)
        XCTAssertLessThan(pins[2].renderedBodyRect.width, 28)
        var finished = false
        var grewDuringPan = false
        map.camera.ease(to: CameraOptions(center: places[2].coordinate), duration: 1) { _ in finished = true }
        let deadline = Date().addingTimeInterval(5)
        while !finished && Date() < deadline {
            grewDuringPan = grewDuringPan || pins[2].renderedBodyRect.width > 35
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertTrue(finished)
        XCTAssertTrue(grewDuringPan)
        try await waitUntil { !pins[2].isTransitioning }
        XCTAssertEqual(pins[2].renderedBodyRect.width, 50, accuracy: 0.1)
    }

    func testCroppedViewportDefinesFocusAndSocialOverlapDoesNotChangeSize() async throws {
        let (map, store, window, previous) = try makeLayoutFixture(croppedHeight: 240)
        defer { store.removeAll(); window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        let viewport = try XCTUnwrap(map.superview as? MapViewportView)
        let visible = viewport.visibleMapRect
        let place = makeAnnotation(name: "Crop", id: "crop")
        place.coordinate = map.mapboxMap.coordinate(for: CGPoint(x: visible.midX, y: visible.minY + 5))
        store.addAnnotation(place)
        let pin = try XCTUnwrap(store.view(for: place) as? SavedPlaceAnnotationView)
        try await waitUntil { !pin.isTransitioning }
        XCTAssertLessThan(pin.renderedBodyRect.width, 28)
        viewport.onViewportChange = { store.updateSavedPlacePresentation() }
        viewport.frame.size.height = 480
        viewport.layoutIfNeeded()
        try await waitUntil { !pin.isTransitioning }
        XCTAssertEqual(pin.renderedBodyRect.width, 50, accuracy: 0.1)
        let makePlace = store.makeView
        store.makeView = { annotation in
            if annotation is SavedPlaceAnnotation { return makePlace?(annotation) }
            let view = MapAnnotationView(annotation: annotation, reuseIdentifier: nil)
            view.bounds.size = CGSize(width: 44, height: 44)
            return view
        }
        let social = MapAnnotation(coordinate: place.coordinate)
        store.addAnnotation(social)
        XCTAssertEqual(pin.renderedBodyRect.width, 50, accuracy: 0.1)
        let native = try XCTUnwrap(map.viewAnnotations.allAnnotations.first { $0.view === pin })
        XCTAssertTrue(native.visible)
        XCTAssertLessThan(try XCTUnwrap(native.priority), 0, "Social annotations keep their foreground layer")
    }

    func testPhotosUpdateDuringCameraAnimationAndHeldEdgeZoom() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first(where: \.isKeyWindow)
        let place = SavedPlace(place: NaverImportedPlace(
            id: "animated", name: "Café avec un nom assez long", address: "Adresse de test",
            latitude: 37, longitude: 127, naverURL: URL(string: "https://map.naver.com/")!,
            isUnavailable: false, hasLocationWarning: false, categoryCode: "CAFE"
        ), ownerID: "test-owner", listName: "Cafés")
        let host = UIHostingController(rootView: MapWithFogView(
            locationTracker: LocationTracker(scenarioLocation: CLLocation(latitude: 37, longitude: 127.1)),
            discoveredCellIDs: [], cityBoundaryCoordinates: [], savedPlaces: [place],
            centerOnUser: .constant(false), resetMapOrientation: .constant(false),
            centerOnFriendUserID: .constant(nil), centerOnOutingPlanEventID: .constant(nil)
        ))
        let window = UIWindow(windowScene: scene)
        window.frame = scene.effectiveGeometry.coordinateSpace.bounds
        window.rootViewController = host
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousWindow?.makeKey()
        }
        try await waitUntil { self.firstSubview(MapViewportView.self, in: host.view) != nil }
        let map = try XCTUnwrap(firstSubview(MapViewportView.self, in: host.view)).mapView
        map.mapboxMap.loadStyle(#"{"version":8,"sources":{},"layers":[]}"#)
        map.mapboxMap.setCamera(to: CameraOptions(center: place.coordinate, zoom: 15))
        try await waitUntil { self.firstSubview(SavedPlaceAnnotationView.self, in: map)?.showsLabels == true }
        let pin = try XCTUnwrap(firstSubview(SavedPlaceAnnotationView.self, in: map))
        try await waitUntil { !pin.isTransitioning }

        for (targetZoom, showsLabelsAtEnd) in [(12.0, false), (15.0, true)] {
            let initialWidth = pin.renderedBodyRect.width
            var finished = false
            var widthsAfterThreshold: [CGFloat] = []
            map.camera.ease(to: CameraOptions(zoom: targetZoom), duration: 1.2) { _ in finished = true }
            let deadline = Date().addingTimeInterval(5)
            while !finished && Date() < deadline {
                let zoom = map.mapboxMap.cameraState.zoom
                if (targetZoom == 12 && zoom < 12.5) || (targetZoom == 15 && zoom > 13.1) {
                    widthsAfterThreshold.append(pin.renderedBodyRect.width)
                }
                try await Task.sleep(for: .milliseconds(20))
            }
            XCTAssertTrue(finished)
            XCTAssertFalse(widthsAfterThreshold.isEmpty, "Must inspect frames after crossing the label threshold")
            XCTAssertTrue(widthsAfterThreshold.contains { abs($0 - initialWidth) > 5 },
                          "The photo must react before the camera stops")
            try await waitUntil { pin.showsLabels == showsLabelsAtEnd && !pin.isTransitioning }
        }

        let viewport = try XCTUnwrap(firstSubview(MapViewportView.self, in: host.view))
        let edgeZoom = MapEdgeZoomController(viewport: viewport, onBegin: {})
        defer { edgeZoom.uninstall() }
        let initialWidth = pin.renderedBodyRect.width
        edgeZoom.begin(on: map)
        edgeZoom.move(on: map, translationY: 450, velocityY: 0)
        XCTAssertLessThan(map.mapboxMap.cameraState.zoom, 12.2)
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertLessThan(pin.renderedBodyRect.width, initialWidth - 5,
                          "The photo must react while the edge zoom gesture is held")
        edgeZoom.end()
        try await waitUntil { !pin.showsLabels }
        // SwiftUI dismantles the map on a later run-loop turn; finish it within this test.
        window.isHidden = true
        window.rootViewController = nil
        try await Task.sleep(for: .milliseconds(150))
    }

    func testDenseCameraFrameCadence() async throws {
        let (map, store, window, previousWindow) = try makeLayoutFixture()
        defer { store.removeAll(); window.isHidden = true; window.rootViewController = nil; previousWindow?.makeKey() }
        let center = map.mapboxMap.cameraState.center
        let places = (0..<36).map { index in
            let place = makeAnnotation(name: "Café \(index)", id: String(format: "dense-%02d", index))
            place.coordinate = map.mapboxMap.coordinate(for: CGPoint(
                x: map.bounds.midX + CGFloat(index % 6 - 3) * 48,
                y: map.bounds.midY + CGFloat(index / 6 - 3) * 52))
            return place
        }
        store.addAnnotations(places)
        try await Task.sleep(for: .milliseconds(600))
        var frameTimes: [CFTimeInterval] = []
        var layoutTimes: [CFTimeInterval] = []
        let render = map.mapboxMap.onRenderFrameFinished.observe { _ in frameTimes.append(CACurrentMediaTime()) }
        let camera = map.mapboxMap.onCameraChanged.observe { _ in
            let start = CACurrentMediaTime()
            store.updateSavedPlacePresentation()
            layoutTimes.append(CACurrentMediaTime() - start)
        }
        defer { render.cancel(); camera.cancel() }
        for pass in 0..<3 {
            frameTimes.removeAll(); layoutTimes.removeAll()
            for (zoom, longitude) in [(15.3, center.longitude + 0.0008), (12.1, center.longitude - 0.0008), (13.3, center.longitude)] {
                var finished = false
                map.camera.ease(to: CameraOptions(center: CLLocationCoordinate2D(latitude: center.latitude, longitude: longitude), zoom: zoom),
                                duration: 0.8) { _ in finished = true }
                try await waitUntil { finished }
            }
            let intervals = zip(frameTimes.dropFirst(), frameTimes).map { ($0 - $1) * 1_000 }.sorted()
            let layouts = layoutTimes.map { $0 * 1_000 }.sorted()
            XCTAssertGreaterThan(intervals.count, 20)
            XCTAssertFalse(layouts.isEmpty)
            guard !intervals.isEmpty, !layouts.isEmpty else { continue }
            print("PIN_CADENCE pass=\(pass) frames=\(intervals.count) p50_ms=\(intervals[intervals.count / 2]) p95_ms=\(intervals[Int(Double(intervals.count - 1) * 0.95)]) max_ms=\(intervals.last!) layout_p95_ms=\(layouts[Int(Double(layouts.count - 1) * 0.95)])")
        }
    }

    private func makeLayoutFixture(croppedHeight: CGFloat? = nil) throws -> (MapboxMaps.MapView, MapAnnotationStore, UIWindow, UIWindow?) {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let map = MapboxMaps.MapView(frame: scene.effectiveGeometry.coordinateSpace.bounds)
        let controller = UIViewController()
        if let croppedHeight {
            let container = UIView(frame: scene.effectiveGeometry.coordinateSpace.bounds)
            let viewport = MapViewportView(mapView: map, renderSize: map.bounds.size)
            container.addSubview(viewport)
            viewport.frame = CGRect(x: 0, y: 100, width: map.bounds.width, height: croppedHeight)
            controller.view = container
        } else {
            controller.view = map
        }
        window.frame = scene.effectiveGeometry.coordinateSpace.bounds
        window.rootViewController = controller
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        map.mapboxMap.loadStyle(#"{"version":8,"sources":{},"layers":[]}"#)
        map.mapboxMap.setCamera(to: CameraOptions(center: CLLocationCoordinate2D(latitude: 37, longitude: 127), zoom: 15))
        let store = MapAnnotationStore(mapView: map)
        store.makeView = { annotation in
            guard let place = annotation as? SavedPlaceAnnotation else { return nil }
            let pin = SavedPlaceAnnotationView(annotation: place, reuseIdentifier: nil)
            pin.configure(with: place)
            return pin
        }
        return (map, store, window, previous)
    }

    func testLongLabelsKeepIconAnchoredAndHitTargetUsableWhenToggled() {
        let annotation = makeAnnotation(name: String(repeating: "Café avec un nom très long ", count: 10))
        annotation.categoryCode = "UNKNOWN"
        annotation.categoryName = "Une catégorie avec un nom très long"
        let view = SavedPlaceAnnotationView(annotation: annotation, reuseIdentifier: nil)
        view.configure(with: annotation)
        XCTAssertFalse(view.showsLabels)
        XCTAssertEqual(view.bounds.size, CGSize(width: 44, height: 44))
        assertRenderedCircle(view, diameter: 24)

        view.setMapEmphasis(1)
        let stickers = allSubviews(SavedPlaceCategoryStickerView.self, in: view)
        XCTAssertEqual(stickers.map(\.text), ["Une catégorie av…"])
        XCTAssertEqual(view.accessibilityLabel, annotation.title, "The full place name stays accessible")
        XCTAssertGreaterThan(view.presentationGeometry.labelRect.width, 50)
        XCTAssertLessThan(view.presentationGeometry.labelRect.midY, view.presentationGeometry.circleRect.midY,
                          "The category belongs above the photo, not beside it")
        XCTAssertEqual(view.bounds.width, 44)
        assertRenderedCircle(view, diameter: 50)
        XCTAssertEqual(view.centerOffset.width - view.bounds.midX + 22, 0, accuracy: 0.001)
        XCTAssertTrue(view.point(inside: CGPoint(x: 22, y: 22), with: nil))

        view.setMapEmphasis(0)
        XCTAssertEqual(view.bounds.size, CGSize(width: 44, height: 44))
        XCTAssertEqual(view.centerOffset, .zero)
        XCTAssertFalse(view.showsLabels)
        assertRenderedCircle(view, diameter: 24)
    }

    func testSelectedPinKeepsItsPhotoAndFollowsMapEmphasis() throws {
        let annotation = makeAnnotation(name: "Adresse sélectionnée")
        let pin = SavedPlaceAnnotationView(annotation: annotation, reuseIdentifier: nil)
        pin.configure(with: annotation)
        let fixture = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }
        pin.updatePhoto(fixture)
        let photo = try XCTUnwrap(firstSubview(SavedPlaceCalloutView.self, in: pin)).photoView
        pin.setSelected(true, animated: false)
        XCTAssertEqual(pin.presentation, .selected)
        XCTAssertFalse(pin.showsLabels)
        assertRenderedCircle(pin, diameter: 24)
        XCTAssertTrue(photo.image === fixture)
        XCTAssertEqual(photo.bounds.size, CGSize(width: 20, height: 20))

        pin.setMapEmphasis(1, animated: false)
        XCTAssertTrue(pin.showsLabels)
        XCTAssertEqual(pin.presentation, .selected)
        XCTAssertEqual(pin.bounds.size, CGSize(width: 44, height: 44))
        assertRenderedCircle(pin, diameter: 50)
        XCTAssertTrue(photo.image === fixture)
        XCTAssertTrue(allSubviews(UIButton.self, in: pin).isEmpty)

        pin.setMapEmphasis(0, animated: false)
        assertRenderedCircle(pin, diameter: 24)
        pin.setSelected(false, animated: false)
        XCTAssertEqual(pin.presentation, .compact)
        XCTAssertTrue(photo.image === fixture)
        XCTAssertEqual(pin.alpha, 1)
        XCTAssertEqual(photo.alpha, 1)
    }

    func testReconfigurationUpdatesVisibleNameAndType() {
        let annotation = makeAnnotation(name: "Café initial")
        let view = SavedPlaceAnnotationView(annotation: annotation, reuseIdentifier: nil)
        view.configure(with: annotation)
        view.setMapEmphasis(1)
        annotation.title = "Nouveau restaurant"
        annotation.categoryCode = "DINING"
        view.configure(with: annotation)
        XCTAssertEqual(view.accessibilityLabel, "Nouveau restaurant")
        XCTAssertEqual(allSubviews(SavedPlaceCategoryStickerView.self, in: view).map(\.text), ["Restaurant"])
        XCTAssertTrue(view.showsLabels)
        XCTAssertEqual(view.accessibilityValue, "Restaurant · Détaillé")

        annotation.categoryCode = "UNKNOWN"
        annotation.categoryName = "  "
        view.configure(with: annotation)
        XCTAssertEqual(view.accessibilityValue, "Adresse · Détaillé")
        XCTAssertEqual(allSubviews(SavedPlaceCategoryStickerView.self, in: view).map(\.text), ["Adresse"])
        assertRenderedCircle(view, diameter: 50)
    }

    func testInterruptedSelectionReturnsToLatestMapSizeAndCanBeReused() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first(where: \.isKeyWindow)
        let host = UIViewController()
        let window = UIWindow(windowScene: scene)
        window.frame = scene.effectiveGeometry.coordinateSpace.bounds
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousWindow?.makeKey()
        }
        let annotation = makeAnnotation(name: "Café interrompu")
        let pin = SavedPlaceAnnotationView(annotation: annotation, reuseIdentifier: nil)
        pin.configure(with: annotation)
        host.view.addSubview(pin)
        pin.center = CGPoint(x: 160, y: 180)
        try await Task.sleep(for: .milliseconds(30))
        pin.setMapEmphasis(1)
        try await waitUntil {
            pin.renderedBodyRect.width > 24 && pin.renderedBodyRect.width < 50
        }
        let interruptedWidth = pin.renderedBodyRect.width
        XCTAssertGreaterThan(interruptedWidth, 24)
        XCTAssertLessThan(interruptedWidth, 50)

        let visualBeforeSelection = pin.currentVisualRect
        pin.setSelected(true, animated: true)
        XCTAssertEqual(pin.renderedBodyRect.width,
                       interruptedWidth, accuracy: 1, "Do not restart from the previous target size")
        XCTAssertEqual(pin.currentVisualRect, visualBeforeSelection)
        try await Task.sleep(for: .milliseconds(35))
        XCTAssertEqual(pin.renderedAnchorInHost.x, pin.presentationGeometry.anchor.x, accuracy: 0.5,
                       "The morph must keep its tip at the geographic anchor")
        XCTAssertEqual(pin.renderedAnchorInHost.y, pin.presentationGeometry.anchor.y, accuracy: 0.5)
        pin.setSelected(false, animated: true)
        pin.setMapEmphasis(0)
        XCTAssertGreaterThan(pin.currentVisualRect.width, 24,
                             "The shrinking photo retains its current drawn extent")
        try await waitUntil { !pin.isTransitioning }
        XCTAssertFalse(pin.isTransitioning)
        XCTAssertEqual(pin.presentation, .compact)
        XCTAssertEqual(pin.renderedBodyRect.width, 24)
        assertRenderedCircle(pin, diameter: 24)
        XCTAssertEqual(pin.alpha, 1)

        pin.setSelected(true, animated: true)
        pin.setMapEmphasis(1)
        try await Task.sleep(for: .milliseconds(40))
        annotation.title = "Nom actualisé pendant la sélection"
        annotation.categoryCode = "DINING"
        let widthBeforeRefresh = pin.renderedBodyRect.width
        pin.configure(with: annotation)
        XCTAssertTrue(pin.isTransitioning, "Refreshing place data must not finish or restart its size animation")
        XCTAssertEqual(pin.renderedBodyRect.width, widthBeforeRefresh, accuracy: 0.001)
        try await waitUntil { !pin.isTransitioning }
        XCTAssertEqual(pin.renderedBodyRect.width, 50)
        pin.setSelected(false, animated: true)
        try await Task.sleep(for: .milliseconds(30))
        pin.prepareForReuse()
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertFalse(pin.isSelected)
        XCTAssertFalse(pin.showsLabels)
        XCTAssertFalse(pin.isTransitioning)
        XCTAssertNil(pin.accessibilityLabel)
        assertRenderedCircle(pin, diameter: 24)
        XCTAssertNil(firstSubview(SavedPlaceCalloutView.self, in: pin)?.photoView.image)
    }

    private func assertRenderedCircle(_ pin: SavedPlaceAnnotationView, diameter: CGFloat,
                                      file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(pin.renderedBodyRect.width, diameter, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(pin.renderedBodyRect.height, diameter, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(pin.centerOffset.width - pin.bounds.midX + pin.renderedAnchorInHost.x,
                       0, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(pin.centerOffset.height - pin.bounds.midY + pin.renderedAnchorInHost.y,
                       0, accuracy: 0.001, file: file, line: line)
    }

    func testActivationWaitsForParentConfirmationAndCleansUpOnRemoval() throws {
        let map = MapboxMaps.MapView(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
        map.mapboxMap.loadStyle(#"{"version":8,"sources":{},"layers":[]}"#)
        let store = MapAnnotationStore(mapView: map)
        defer { store.removeAll() }
        store.makeView = { annotation in
            if let place = annotation as? SavedPlaceAnnotation {
                let pin = SavedPlaceAnnotationView(annotation: place, reuseIdentifier: nil)
                pin.configure(with: place)
                return pin
            }
            return MapAnnotationView(annotation: annotation, reuseIdentifier: nil)
        }
        let first = makeAnnotation(name: "Premier", id: "first")
        let second = makeAnnotation(name: "Second", id: "second")
        let social = MapAnnotation(coordinate: first.coordinate)
        store.addAnnotations([first, second, social])
        let pin = try XCTUnwrap(store.view(for: first) as? SavedPlaceAnnotationView)
        var requested: [String] = []
        var selectionCallbacks = 0
        store.onActivateSavedPlace = { requested.append($0.placeID) }
        store.onSelect = { _ in selectionCallbacks += 1 }

        store.activateAnnotation(first)
        store.activateAnnotation(first)
        XCTAssertEqual(requested, [first.placeID, first.placeID])
        XCTAssertTrue(store.selectedAnnotations.isEmpty, "A declined opening must not select its pin")
        XCTAssertFalse(pin.isSelected)
        store.selectAnnotation(first, animated: true, notifySelection: false)
        XCTAssertTrue(pin.isSelected)
        XCTAssertEqual(selectionCallbacks, 0, "Parent synchronization must not reopen the sheet")
        XCTAssertEqual(requested.count, 2)
        store.deselectAnnotation(first, animated: true)
        XCTAssertFalse(pin.isSelected)
        store.activateAnnotation(first)
        XCTAssertEqual(requested.count, 3, "The same pin remains activatable after dismissal")
        store.selectAnnotation(first, animated: true, notifySelection: false)
        store.selectAnnotation(second, animated: true, notifySelection: false)
        XCTAssertFalse(pin.isSelected)
        XCTAssertEqual(store.selectedAnnotations.count, 1)
        XCTAssertTrue(store.selectedAnnotations.first === second)
        second.coordinate.longitude -= 1
        store.synchronizeCoordinates()
        XCTAssertTrue(store.view(for: second)?.isSelected == true, "Offscreen visibility must not clear selection")
        store.removeAnnotation(second)
        XCTAssertTrue(store.selectedAnnotations.isEmpty)
        XCTAssertNil(store.view(for: second))
        store.activateAnnotation(social)
        XCTAssertTrue(store.selectedAnnotations.first === social)
        XCTAssertEqual(selectionCallbacks, 1, "Social selection still delivers its callback")
    }

    private func makeAnnotation(name: String, id: String = "test") -> SavedPlaceAnnotation {
        let place = NaverImportedPlace(id: id, name: name, address: "Adresse de test",
                                      latitude: 37, longitude: 127,
                                      naverURL: URL(string: "https://map.naver.com/")!,
                                      isUnavailable: false, hasLocationWarning: false,
                                      categoryCode: "CAFE", categoryName: "카페")
        return SavedPlaceAnnotation(place: SavedPlace(place: place, ownerID: "test-owner", listName: "Cafés"))
    }

    private func firstSubview<T: UIView>(_ type: T.Type, in view: UIView) -> T? {
        if let match = view as? T { return match }
        return view.subviews.lazy.compactMap { self.firstSubview(type, in: $0) }.first
    }

    private func allSubviews<T: UIView>(_ type: T.Type, in view: UIView) -> [T] {
        (view as? T).map { [$0] } ?? view.subviews.flatMap { allSubviews(type, in: $0) }
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(5)
        while !condition() && Date() < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertTrue(condition())
    }
}
