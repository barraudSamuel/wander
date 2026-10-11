import MapboxMaps
import SwiftUI
import UIKit
import XCTest
@testable import wander

@MainActor
final class SavedPlaceAnnotationTests: XCTestCase {
    func testLabelMeasurementSurvivesAStaleNativeFrame() {
        let annotation = makeAnnotation(name: String(repeating: "Café avec un nom long ", count: 8))
        let pin = SavedPlaceAnnotationView(annotation: annotation, reuseIdentifier: nil)
        pin.configure(with: annotation)
        pin.setLabelsVisible(true)
        let expectedSize = pin.systemLayoutSizeFitting(CGSize(width: 390, height: 700))
        // A queued compact Mapbox placement may arrive after labels have expanded.
        pin.frame = CGRect(x: 80, y: 80, width: 44, height: 44)
        XCTAssertEqual(pin.systemLayoutSizeFitting(CGSize(width: 390, height: 700)), expectedSize,
                       "Native placement must not shrink the measured text to the icon's bounds")
    }

    func testLongNamesYieldToOtherIconsWithoutHidingThePlaces() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first(where: \.isKeyWindow)
        let map = MapboxMaps.MapView(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
        let host = UIViewController()
        host.view = map
        let window = UIWindow(windowScene: scene)
        window.frame = scene.effectiveGeometry.coordinateSpace.bounds
        window.rootViewController = host
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        let store = MapAnnotationStore(mapView: map)
        defer {
            store.removeAll()
            window.isHidden = true
            window.rootViewController = nil
            previousWindow?.makeKey()
        }
        map.mapboxMap.loadStyle(#"{"version":8,"sources":{},"layers":[]}"#)
        map.mapboxMap.setCamera(to: CameraOptions(center: CLLocationCoordinate2D(latitude: 37, longitude: 127), zoom: 15))
        let places = [-65.0, 65.0].flatMap { y in
            [-130.0, -50.0, 30.0, 110.0].map { x in
                let pin = makeAnnotation(name: "Café avec un nom très long \(x)", id: "\(y)-\(x)")
                pin.coordinate = map.mapboxMap.coordinate(for: CGPoint(x: map.bounds.midX + x, y: map.bounds.midY + y))
                return pin
            }
        }
        store.makeView = { annotation in
            guard let place = annotation as? SavedPlaceAnnotation else { return nil }
            let pin = SavedPlaceAnnotationView(annotation: annotation, reuseIdentifier: nil)
            pin.configure(with: place)
            pin.setLabelsVisible(true)
            return pin
        }
        let token = map.mapboxMap.onCameraChanged.observe { _ in store.updateSavedPlaceOverlap() }
        defer { token.cancel() }
        store.addAnnotations(Array(places.reversed()))
        let pins = try places.map { try XCTUnwrap(store.view(for: $0) as? SavedPlaceAnnotationView) }
        try await Task.sleep(for: .milliseconds(700))
        XCTAssertEqual(pins.filter { !$0.isHidden }.count, 8,
                       "All eight separated icons must remain even when their names cannot fit")
        let visibleLabels = pins.filter { !$0.isHidden && $0.showsLabels }
        XCTAssertGreaterThanOrEqual(visibleLabels.count, 2, "Exercise several actual names, not just one visible place")
        assertDisplayedContentIsSeparated(pins, on: map)

        var finished = false
        map.camera.ease(to: CameraOptions(zoom: 14.3), duration: 1.2) { _ in finished = true }
        let deadline = Date().addingTimeInterval(4)
        var samples = 0
        while !finished && Date() < deadline {
            XCTAssertEqual(pins.filter { !$0.isHidden }.count, 8,
                           "A gentle zoom out must hide names before separated icons")
            XCTAssertTrue(pins.allSatisfy { $0.alpha == 1 })
            assertDisplayedContentIsSeparated(pins, on: map)
            samples += 1
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertTrue(finished)
        XCTAssertGreaterThan(samples, 10)

        map.mapboxMap.setCamera(to: CameraOptions(zoom: 15))
        try await waitUntil { pins.allSatisfy { !$0.isHidden } }
        store.removeAnnotations(places.enumerated().filter { $0.offset != 0 && $0.offset != 4 }.map(\.element))
        try await waitUntil {
            pins[0].showsLabels && pins[4].showsLabels && pins[0].bounds.width > 44 && pins[4].bounds.width > 44
        }
        assertDisplayedContentIsSeparated([pins[0], pins[4]], on: map)
        store.selectAnnotation(places[0], animated: false)
        XCTAssertTrue(pins[0].isSelected)
        XCTAssertFalse(pins[0].isHidden)
        store.deselectAnnotation(places[0], animated: false)
    }

    private func assertDisplayedContentIsSeparated(_ pins: [SavedPlaceAnnotationView], on map: MapboxMaps.MapView,
                                                   file: StaticString = #filePath, line: UInt = #line) {
        let visible = pins.filter { !$0.isHidden && $0.superview != nil }
        let icons = visible.map { $0.convert(CGRect(x: 4, y: 4, width: 36, height: 36), to: map) }
        var labelRects: [CGRect] = []
        for (index, pin) in visible.enumerated() {
            let labels = pin.subviews.compactMap { $0 as? UILabel }.filter { !$0.isHidden }
            for label in labels {
                let rect = label.convert(label.bounds, to: map)
                XCTAssertTrue(pin.bounds.contains(label.frame), "Text extends beyond the bounds measured for Mapbox", file: file, line: line)
                XCTAssertTrue(icons.enumerated().filter { $0.offset != index }.allSatisfy { !$0.element.intersects(rect) },
                              "A visible text intersects another place's icon", file: file, line: line)
                XCTAssertTrue(labelRects.allSatisfy { !$0.intersects(rect) }, "Visible names overlap", file: file, line: line)
                labelRects.append(rect)
            }
        }
    }

    func testCompactPlacesHideOverlapsWithoutReappearingDuringZoomOut() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first(where: \.isKeyWindow)
        let map = MapboxMaps.MapView(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
        let host = UIViewController()
        host.view = map
        let window = UIWindow(windowScene: scene)
        window.frame = scene.effectiveGeometry.coordinateSpace.bounds
        window.rootViewController = host
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        let store = MapAnnotationStore(mapView: map)
        defer {
            store.removeAll()
            window.isHidden = true
            window.rootViewController = nil
            previousWindow?.makeKey()
        }
        map.mapboxMap.loadStyle(#"{"version":8,"sources":{},"layers":[]}"#)
        map.mapboxMap.setCamera(to: CameraOptions(center: CLLocationCoordinate2D(latitude: 37, longitude: 127), zoom: 15))
        let places = [0.0, 60.0, 90.0].enumerated().map { index, offset in
            let annotation = makeAnnotation(name: "Café \(index)", id: "zoom-\(index)")
            annotation.coordinate = map.mapboxMap.coordinate(for: CGPoint(x: map.bounds.midX + offset,
                                                                         y: map.bounds.midY))
            return annotation
        }
        store.makeView = { annotation in
            guard let savedPlace = annotation as? SavedPlaceAnnotation else {
                let view = MapAnnotationView(annotation: annotation, reuseIdentifier: nil)
                view.bounds.size = CGSize(width: 44, height: 44)
                return view
            }
            let pin = SavedPlaceAnnotationView(annotation: annotation, reuseIdentifier: nil)
            pin.configure(with: savedPlace)
            return pin
        }
        let cameraSubscription = map.mapboxMap.onCameraChanged.observe { _ in
            store.updateSavedPlaceOverlap()
        }
        defer { cameraSubscription.cancel() }
        store.addAnnotations(Array(places.reversed()))
        try await Task.sleep(for: .milliseconds(500))
        let pins = try places.map { try XCTUnwrap(store.view(for: $0)) }
        let nativePins = try pins.map { pin in
            try XCTUnwrap(map.viewAnnotations.allAnnotations.first { $0.view === pin })
        }
        XCTAssertTrue(pins[2].isHidden, "An overlapping café must be fully hidden, not faded")
        var finished = false
        var visibility: [[Bool]] = []
        map.camera.ease(to: CameraOptions(zoom: 13), duration: 2) { _ in finished = true }
        let deadline = Date().addingTimeInterval(5)
        while !finished && Date() < deadline {
            visibility.append(pins.map { !$0.isHidden && $0.superview != nil })
            XCTAssertTrue(pins.allSatisfy { $0.alpha == 1 }, "No marker may be faded")
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertTrue(finished)
        XCTAssertFalse(visibility.isEmpty)
        for index in places.indices {
            let states = visibility.map { $0[index] }.reduce(into: [Bool]()) {
                if $0.last != $1 { $0.append($1) }
            }
            XCTAssertLessThanOrEqual(states.count, 2,
                                     "Compact café \(index) reappeared during zoom out: \(states)")
        }
        XCTAssertTrue(visibility.allSatisfy { $0[0] && !$0[2] },
                      "The rear café must stay hidden instead of taking another hidden café's place")
        XCTAssertEqual(nativePins.map(\.visible), [true, false, false])
        store.selectAnnotation(places[2], animated: false)
        XCTAssertEqual(nativePins.map(\.visible), [false, false, true])
        try await waitUntil { !pins[2].isHidden && pins[0].isHidden }
        store.deselectAnnotation(places[2], animated: false)
        XCTAssertEqual(nativePins.map(\.visible), [true, false, false])
        map.mapboxMap.setCamera(to: CameraOptions(zoom: 16))
        try await waitUntil { pins.allSatisfy { $0.alpha == 1 && !$0.isHidden } }
        let firstPoint = map.mapboxMap.point(for: places[0].coordinate)
        for (offset, visible) in [(32.0, false), (38.0, false), (42.0, true)] {
            places[1].coordinate = map.mapboxMap.coordinate(for: CGPoint(x: firstPoint.x + offset,
                                                                         y: firstPoint.y))
            store.synchronizeCoordinates()
            XCTAssertEqual(nativePins[1].visible, visible,
                           "Visibility must use a release margin around collisions and survive coordinate sync")
        }
        let social = MapAnnotation(coordinate: places[0].coordinate)
        store.addAnnotation(social)
        try await waitUntil { pins[0].isHidden }
        XCTAssertEqual(store.view(for: social)?.alpha, 1)
        XCTAssertFalse(nativePins[0].visible)
        store.removeAnnotation(social)
        XCTAssertTrue(nativePins[0].visible)
        try await waitUntil { !pins[0].isHidden }
        places[0].coordinate = kCLLocationCoordinate2DInvalid
        store.synchronizeCoordinates()
        XCTAssertFalse(nativePins[0].visible)
        places[0].coordinate = map.mapboxMap.coordinate(for: firstPoint)
        store.synchronizeCoordinates()
        XCTAssertTrue(nativePins[0].visible)
        let originalCoordinate = places[0].coordinate
        places[0].coordinate.longitude -= 1
        store.synchronizeCoordinates()
        XCTAssertFalse(nativePins[0].visible, "Do not treat Mapbox's offscreen sentinel as a position near the top left")
        places[0].coordinate = originalCoordinate
        store.synchronizeCoordinates()
        XCTAssertTrue(nativePins[0].visible)
    }

    func testLabelsKeepTheirWidthDuringCameraAnimationAndUpdateWhenItStops() async throws {
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

        for (targetZoom, showsLabelsAtEnd) in [(12.0, false), (15.0, true)] {
            let initialWidth = pin.bounds.width
            var finished = false
            var widthsAfterThreshold: [CGFloat] = []
            map.camera.ease(to: CameraOptions(zoom: targetZoom), duration: 1.2) { _ in finished = true }
            let deadline = Date().addingTimeInterval(5)
            while !finished && Date() < deadline {
                let zoom = map.mapboxMap.cameraState.zoom
                if (targetZoom == 12 && zoom < 13.6) || (targetZoom == 15 && zoom > 14.1) {
                    widthsAfterThreshold.append(pin.bounds.width)
                }
                try await Task.sleep(for: .milliseconds(20))
            }
            XCTAssertTrue(finished)
            XCTAssertFalse(widthsAfterThreshold.isEmpty, "Must inspect frames after crossing the label threshold")
            XCTAssertTrue(widthsAfterThreshold.allSatisfy { $0 == initialWidth },
                          "Marker width changed during zoom: \(Set(widthsAfterThreshold)); initial: \(initialWidth)")
            try await waitUntil { pin.showsLabels == showsLabelsAtEnd }
        }

        let viewport = try XCTUnwrap(firstSubview(MapViewportView.self, in: host.view))
        let edgeZoom = MapEdgeZoomController(viewport: viewport, onBegin: {})
        defer { edgeZoom.uninstall() }
        let initialWidth = pin.bounds.width
        edgeZoom.begin(on: map)
        edgeZoom.move(on: map, translationY: 300, velocityY: 0)
        XCTAssertLessThan(map.mapboxMap.cameraState.zoom, 13.7)
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertEqual(pin.bounds.width, initialWidth, "Keep labels while the edge zoom gesture is held")
        edgeZoom.end()
        try await waitUntil { !pin.showsLabels }
        // SwiftUI dismantles the map on a later run-loop turn; finish it within this test.
        window.isHidden = true
        window.rootViewController = nil
        try await Task.sleep(for: .milliseconds(150))
    }

    func testLabelVisibilityHasSeparateZoomInAndZoomOutThresholds() {
        var visible = false
        for (zoom, expected) in [(13.9, false), (14.0, true), (13.9, true),
                                 (13.7, true), (13.69, false), (13.8, false), (15.0, true)] {
            visible = SavedPlaceAnnotationView.shouldShowLabels(at: zoom, wasVisible: visible)
            XCTAssertEqual(visible, expected, "Unexpected labels at zoom \(zoom)")
        }
    }

    func testLongLabelsKeepIconAnchoredAndHitTargetUsableWhenToggled() {
        let annotation = makeAnnotation(name: String(repeating: "Café avec un nom très long ", count: 10))
        let view = SavedPlaceAnnotationView(annotation: annotation, reuseIdentifier: nil)
        view.configure(with: annotation)
        let labels = view.subviews.compactMap { $0 as? UILabel }
        XCTAssertTrue(labels.allSatisfy(\.isHidden))
        XCTAssertEqual(view.bounds.size, CGSize(width: 44, height: 44))

        view.setLabelsVisible(true)
        XCTAssertEqual(labels.map(\.text), [annotation.title, "Café"])
        XCTAssertTrue(labels.allSatisfy { !$0.isHidden && $0.frame.width <= 160 })
        XCTAssertLessThanOrEqual(view.bounds.width, 208)
        XCTAssertEqual(view.centerOffset.width - view.bounds.midX + 22, 0, accuracy: 0.001)
        XCTAssertTrue(view.point(inside: CGPoint(x: 22, y: 22), with: nil))

        view.setLabelsVisible(false)
        XCTAssertEqual(view.bounds.size, CGSize(width: 44, height: 44))
        XCTAssertEqual(view.centerOffset, .zero)
        XCTAssertTrue(labels.allSatisfy(\.isHidden))
    }

    func testReconfigurationUpdatesVisibleNameAndType() {
        let annotation = makeAnnotation(name: "Café initial")
        let view = SavedPlaceAnnotationView(annotation: annotation, reuseIdentifier: nil)
        view.configure(with: annotation)
        view.setLabelsVisible(true)
        annotation.title = "Nouveau restaurant"
        annotation.categoryCode = "DINING"
        view.configure(with: annotation)
        XCTAssertEqual(view.subviews.compactMap { ($0 as? UILabel)?.text },
                       ["Nouveau restaurant", "Restaurant"])
        XCTAssertTrue(view.showsLabels)
        XCTAssertEqual(view.accessibilityValue, "Restaurant")
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

    private func waitUntil(_ condition: @MainActor () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(5)
        while !condition() && Date() < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertTrue(condition())
    }
}
