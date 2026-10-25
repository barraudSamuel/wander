import Combine
import MapboxMaps
import SwiftUI
import UIKit
import XCTest
@testable import wander

@MainActor
final class SavedPlaceSelectionTests: XCTestCase {
    func testViewportExpansionRevealsPinsWithoutChangingTheCamera() async throws {
        let fixture = try await makeFixture()
        defer { fixture.close() }
        let viewport = try XCTUnwrap(fixture.viewport)
        let map = viewport.mapView
        let size = map.bounds.size
        let camera = map.mapboxMap.cameraState
        let pins = fixture.pins
        let native = map.viewAnnotations.allAnnotations.filter { candidate in pins.contains { $0 === candidate.view } }
        XCTAssertEqual(native.count, 3)
        XCTAssertTrue(native.allSatisfy(\.visible))
        viewport.renderSize = size
        viewport.bounds.size.height = 60
        viewport.layoutIfNeeded()
        XCTAssertTrue(native.allSatisfy { !$0.visible },
                      "Cropping must hide photos entirely outside the visible map, including their drawn extent")
        viewport.bounds.size = size
        viewport.layoutIfNeeded()
        XCTAssertTrue(native.allSatisfy(\.visible), "Expanding must reveal pins without waiting for another camera event")
        XCTAssertEqual(map.bounds.size, size)
        XCTAssertEqual(map.mapboxMap.cameraState.center.latitude, camera.center.latitude, accuracy: 0.0000001)
        XCTAssertEqual(map.mapboxMap.cameraState.center.longitude, camera.center.longitude, accuracy: 0.0000001)
        XCTAssertEqual(map.mapboxMap.cameraState.zoom, camera.zoom)
    }

    func testParentSelectionSwitchesPinsAndCanClearAndReopen() async throws {
        let fixture = try await makeFixture()
        defer { fixture.close() }
        let first = try XCTUnwrap(fixture.pin(for: "first"))
        let second = try XCTUnwrap(fixture.pin(for: "second"))
        let third = try XCTUnwrap(fixture.pin(for: "third"))

        fixture.select("first")
        try await waitUntil("The parent selection reaches the first pin") { first.isSelected }
        fixture.select("second")
        try await waitUntil("The parent selection switches pins") { second.isSelected && !first.isSelected }
        fixture.select("third")
        try await waitUntil("The latest parent selection wins") { third.isSelected && !second.isSelected }
        XCTAssertEqual(fixture.pins.filter(\.isSelected).count, 1)

        fixture.model.selectedID = nil
        try await waitUntil("Dismissing the sheet clears the pin selection") {
            fixture.pins.allSatisfy { !$0.isSelected }
        }
        fixture.select("third")
        try await waitUntil("The same address can be reopened") { third.isSelected }
    }

    func testSelectionKeepsPhotoPinGeometryAndCamera() async throws {
        let fixture = try await makeFixture()
        defer { fixture.close() }
        let pin = try XCTUnwrap(fixture.pin(for: "first"))
        let map = try XCTUnwrap(fixture.viewport?.mapView)
        let camera = map.mapboxMap.cameraState
        let body = pin.renderedBodyRect

        fixture.select("first")
        try await waitUntil("Selection is confirmed") { pin.isSelected && !pin.isTransitioning }
        XCTAssertEqual(pin.renderedBodyRect, body, "Selecting an address must not turn its pin into a photo card")
        XCTAssertEqual(map.mapboxMap.cameraState.center.latitude, camera.center.latitude, accuracy: 0.0000001)
        XCTAssertEqual(map.mapboxMap.cameraState.center.longitude, camera.center.longitude, accuracy: 0.0000001)
        XCTAssertEqual(map.mapboxMap.cameraState.zoom, camera.zoom)
    }

    func testDeletingASelectedPlaceDetachesItAndAllowsAnotherSelection() async throws {
        let fixture = try await makeFixture()
        defer { fixture.close() }
        let pin = try XCTUnwrap(fixture.pin(for: "first"))
        let removedID = fixture.placeID(for: "first")
        fixture.select("first")
        try await waitUntil("The first pin is selected") { pin.isSelected }

        fixture.model.places.removeAll { $0.id == removedID }
        try await waitUntil("The removed pin is detached") { pin.superview == nil }
        XCTAssertFalse(fixture.pins.contains { ($0.annotation as? SavedPlaceAnnotation)?.placeID == removedID })
        fixture.select("second")
        let second = try XCTUnwrap(fixture.pin(for: "second"))
        try await waitUntil("Another address remains selectable") { second.isSelected }
        XCTAssertEqual(fixture.pins.filter(\.isSelected).count, 1)
    }

    func testViewportChangesKeepTheParentSelection() async throws {
        let fixture = try await makeFixture()
        defer { fixture.close() }
        let pin = try XCTUnwrap(fixture.pin(for: "first"))
        let viewport = try XCTUnwrap(fixture.viewport)
        let originalSize = viewport.bounds.size
        fixture.select("first")
        try await waitUntil("The address is selected") { pin.isSelected }
        let selectedID = fixture.model.selectedID

        viewport.renderSize = viewport.mapView.bounds.size
        viewport.bounds.size.height = 60
        viewport.layoutIfNeeded()
        fixture.model.revision += 1
        try await waitUntil("The selected pin finishes following the resized viewport") { !pin.isTransitioning }
        XCTAssertEqual(fixture.model.selectedID, selectedID)
        XCTAssertTrue(pin.isSelected, "A sheet resize must not dismiss an address outside the map viewport")

        viewport.bounds.size = originalSize
        viewport.layoutIfNeeded()
        fixture.model.revision += 1
        try await waitUntil("The selected pin follows the restored viewport") { !pin.isTransitioning }
        XCTAssertTrue(pin.isSelected)
        XCTAssertEqual(fixture.model.selectedID, selectedID)
    }

    private func makeFixture() async throws -> SavedPlaceSelectionFixture {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = try XCTUnwrap(scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)
        let fixture = SavedPlaceSelectionFixture(scene: scene)
        do {
            try await waitUntil("The production map is mounted") { fixture.viewport != nil }
            let map = try XCTUnwrap(fixture.viewport?.mapView)
            map.mapboxMap.loadStyle(#"{"version":8,"sources":{},"layers":[]}"#)
            map.mapboxMap.setCamera(to: CameraOptions(center: CLLocationCoordinate2D(latitude: 37, longitude: 127), zoom: 15))
            fixture.model.places = ["first", "second", "third"].enumerated().map { index, sourceID in
                let coordinate = map.mapboxMap.coordinate(for: CGPoint(x: map.bounds.midX + CGFloat(index - 1) * 80,
                                                                       y: map.bounds.midY + 110))
                return SavedPlace(place: NaverImportedPlace(
                    id: sourceID, name: "Café \(sourceID)", address: "Adresse de test",
                    latitude: coordinate.latitude, longitude: coordinate.longitude,
                    naverURL: URL(string: "https://map.naver.com/")!,
                    isUnavailable: false, hasLocationWarning: false, categoryCode: "CAFE"
                ), ownerID: "selection-tests", listName: "Cafés de test")
            }
            try await waitUntil("All saved-place views are mounted") {
                fixture.pins.count == 3 && fixture.pins.allSatisfy { $0.window != nil && !$0.isTransitioning }
            }
            return fixture
        } catch {
            fixture.close()
            throw error
        }
    }

    private func waitUntil(_ description: String, file: StaticString = #filePath, line: UInt = #line,
                           condition: @MainActor () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail(description, file: file, line: line)
        throw SelectionTestError.timeout
    }

    private enum SelectionTestError: Error { case timeout }
}

@MainActor
private final class SavedPlaceSelectionModel: ObservableObject {
    let locationTracker = LocationTracker(scenarioLocation: CLLocation(latitude: 37, longitude: 127.1))
    @Published var places: [SavedPlace] = []
    @Published var selectedID: String?
    @Published var revision = 0
}

private struct SavedPlaceSelectionHost: View {
    @ObservedObject var model: SavedPlaceSelectionModel

    var body: some View {
        let _ = model.revision
        MapWithFogView(
            locationTracker: model.locationTracker,
            discoveredCellIDs: [], cityBoundaryCoordinates: [], savedPlaces: model.places,
            centerOnUser: .constant(false), resetMapOrientation: .constant(false),
            centerOnFriendUserID: .constant(nil), centerOnOutingPlanEventID: .constant(nil),
            selectedSavedPlaceID: model.selectedID,
            onSelectSavedPlace: { model.selectedID = $0 }
        )
    }
}

@MainActor
private final class SavedPlaceSelectionFixture {
    let model = SavedPlaceSelectionModel()
    private let window: UIWindow
    private let host: UIHostingController<SavedPlaceSelectionHost>
    private weak var previousWindow: UIWindow?
    var viewport: MapViewportView? { descendants(MapViewportView.self, in: host.view).first }
    var pins: [SavedPlaceAnnotationView] { descendants(SavedPlaceAnnotationView.self, in: host.view) }

    init(scene: UIWindowScene) {
        previousWindow = scene.windows.first(where: \.isKeyWindow)
        host = UIHostingController(rootView: SavedPlaceSelectionHost(model: model))
        window = UIWindow(windowScene: scene)
        window.frame = scene.effectiveGeometry.coordinateSpace.bounds
        window.rootViewController = host
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
    }

    func placeID(for sourceID: String) -> String {
        model.places.first { $0.sourceID == sourceID }!.id
    }

    func pin(for sourceID: String) -> SavedPlaceAnnotationView? {
        pins.first { ($0.annotation as? SavedPlaceAnnotation)?.sourceID == sourceID }
    }

    func select(_ sourceID: String) { model.selectedID = placeID(for: sourceID) }

    func close() {
        window.isHidden = true
        window.rootViewController = nil
        previousWindow?.makeKey()
    }

    private func descendants<T: UIView>(_ type: T.Type, in view: UIView) -> [T] {
        (view as? T).map { [$0] } ?? view.subviews.flatMap { descendants(type, in: $0) }
    }
}
