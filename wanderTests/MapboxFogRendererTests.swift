import CoreLocation
import H3
import MapboxMaps
import UIKit
import XCTest
@testable import wander

/// Queries the native fog layer after renderer updates, without fetching map tiles.
@MainActor
final class MapboxFogRendererTests: XCTestCase {
    private static let sourceID = "wander-exploration-fog"
    private static let layerID = "wander-exploration-fog-fill"
    private let firstCell = H3Index(coordinate: H3Coordinate(lat: 37.57, lng: 126.98), resolution: 10)
    private let secondCell = H3Index(coordinate: H3Coordinate(lat: 37.574, lng: 126.98), resolution: 10)

    func testExplorationReceivedBeforeStyleLoadIsInstalledWhenReady() async throws {
        let fixture = try makeFixture()
        defer { fixture.close() }
        XCTAssertFalse(fixture.mapView.mapboxMap.isStyleLoaded)

        fixture.renderer.update(cellIDs: [firstCell.description])
        XCTAssertFalse(fixture.mapView.mapboxMap.sourceExists(withId: Self.sourceID))
        fixture.loadStyle(backgroundID: "initial-background")

        try await eventually("The pending exploration is installed in the loaded style", fixture: fixture) {
            try await self.matchesFog(fixture, firstCovered: false, secondCovered: true)
        }
        let layer = try fixture.mapView.mapboxMap.layer(withId: Self.layerID, type: FillLayer.self)
        XCTAssertEqual(layer.source, Self.sourceID)
    }

    func testReplacingExplorationKeepsOnlyTheLatestSnapshot() async throws {
        let fixture = try makeFixture()
        defer { fixture.close() }
        fixture.loadStyle(backgroundID: "initial-background")
        fixture.renderer.update(cellIDs: [firstCell.description])
        try await eventually("The initial cell is revealed", fixture: fixture) {
            try await self.matchesFog(fixture, firstCovered: false, secondCovered: true)
        }

        // Queue a larger obsolete snapshot, then replace it before yielding the main actor.
        fixture.renderer.update(cellIDs: Set(firstCell.kRing(k: 18).map(\.description)))
        fixture.renderer.update(cellIDs: [secondCell.description])
        try await eventually("Removed exploration is covered and only the latest cell is revealed", fixture: fixture) {
            try await self.matchesFog(fixture, firstCovered: true, secondCovered: false)
        }

        fixture.renderer.update(cellIDs: [])
        try await eventually("An empty replacement restores fog over both former cells", fixture: fixture) {
            try await self.matchesFog(fixture, firstCovered: true, secondCovered: true)
        }
    }

    func testStyleReloadReinstallsTheCurrentExploration() async throws {
        let fixture = try makeFixture()
        defer { fixture.close() }
        fixture.loadStyle(backgroundID: "initial-background")
        fixture.renderer.update(cellIDs: [firstCell.description])
        try await eventually("The initial fog source is ready", fixture: fixture) {
            try await self.matchesFog(fixture, firstCovered: false, secondCovered: true)
        }

        fixture.loadStyle(backgroundID: "replacement-background")
        try await eventually("The replacement style receives the current fog and its layer", fixture: fixture) {
            guard fixture.mapView.mapboxMap.layerExists(withId: "replacement-background") else { return false }
            return try await self.matchesFog(fixture, firstCovered: false, secondCovered: true)
        }
        XCTAssertFalse(fixture.mapView.mapboxMap.layerExists(withId: "initial-background"))
    }

    func testTearDownPreventsPendingUpdatesAndStyleReloadFromInstallingFog() async throws {
        let fixture = try makeFixture()
        defer { fixture.close() }
        fixture.loadStyle(backgroundID: "initial-background")
        fixture.renderer.update(cellIDs: [firstCell.description])
        try await eventually("The initial fog source is installed", fixture: fixture) {
            try await self.matchesFog(fixture, firstCovered: false, secondCovered: true)
        }

        fixture.renderer.update(cellIDs: Set(secondCell.kRing(k: 18).map(\.description)))
        fixture.renderer.tearDown()
        fixture.loadStyle(backgroundID: "replacement-background")
        try await eventually("The replacement style has loaded after teardown", fixture: fixture) {
            fixture.mapView.mapboxMap.isStyleLoaded
                && fixture.mapView.mapboxMap.layerExists(withId: "replacement-background")
        }
        // Allow pending geometry and native style callbacks to run after the reload.
        let deadline = Date().addingTimeInterval(0.25)
        repeat {
            XCTAssertFalse(fixture.mapView.mapboxMap.sourceExists(withId: Self.sourceID))
            XCTAssertFalse(fixture.mapView.mapboxMap.layerExists(withId: Self.layerID))
            try await Task.sleep(nanoseconds: 20_000_000)
        } while Date() < deadline
    }

    // MARK: - Native style inspection

    private func matchesFog(
        _ fixture: FogMapFixture,
        firstCovered: Bool,
        secondCovered: Bool
    ) async throws -> Bool {
        let first = try await hasFog(fixture, at: firstCell)
        let second = try await hasFog(fixture, at: secondCell)
        fixture.lastCoverage = "first=\(String(describing: first)), second=\(String(describing: second))"
        return first == firstCovered && second == secondCovered
    }

    private func hasFog(_ fixture: FogMapFixture, at cell: H3Index) async throws -> Bool? {
        let map = try XCTUnwrap(fixture.mapView.mapboxMap)
        guard map.isStyleLoaded, map.layerExists(withId: Self.layerID) else { return nil }
        let coordinate = CLLocationCoordinate2D(latitude: cell.coordinate.lat, longitude: cell.coordinate.lng)
        let point = map.point(for: coordinate)
        XCTAssertTrue(fixture.mapView.bounds.contains(point), "Both test cells must remain visible")

        // GeoJSONSource.data is nil when read back after the SDK's native data update.
        // Query the rendered fill instead, so the assertion also waits for native parsing.
        var result: Result<Bool, Error>?
        let query = map.queryRenderedFeatures(
            with: point,
            options: RenderedQueryOptions(layerIds: [Self.layerID], filter: nil)
        ) { response in
            result = response.map { !$0.isEmpty }
        }
        defer { query.cancel() }
        let deadline = Date().addingTimeInterval(1)
        while result == nil && Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        return try XCTUnwrap(result, "The native feature query must finish").get()
    }

    private func makeFixture() throws -> FogMapFixture {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = try XCTUnwrap(scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)
        return FogMapFixture(windowScene: scene)
    }

    private func eventually(
        _ description: String,
        fixture: FogMapFixture,
        file: StaticString = #filePath,
        line: UInt = #line,
        condition: @MainActor () async throws -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if try await condition() { return }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("\(description). \(fixture.diagnostics)", file: file, line: line)
        throw WaitFailure.timeout
    }

    private enum WaitFailure: Error {
        case timeout
    }
}

@MainActor
private final class FogMapFixture {
    let mapView: MapboxMaps.MapView
    let renderer: MapboxFogRenderer
    private let window: UIWindow
    private weak var previousKeyWindow: UIWindow?
    private var subscriptions: Set<AnyCancelable> = []
    private var styleLoadCount = 0
    private var renderedFrameCount = 0
    private var idleCount = 0
    private var sourceEvents: [String] = []
    var lastCoverage = "not queried"

    var diagnostics: String {
        let map = mapView.mapboxMap!
        return [
            "coverage: \(lastCoverage)",
            "styleLoaded=\(map.isStyleLoaded)",
            "source=\(map.sourceExists(withId: "wander-exploration-fog")), layer=\(map.layerExists(withId: "wander-exploration-fog-fill"))",
            "styleEvents=\(styleLoadCount), frames=\(renderedFrameCount), idle=\(idleCount)",
            "sourceEvents=\(sourceEvents)",
            "keyWindow=\(window.isKeyWindow), hidden=\(window.isHidden), attached=\(mapView.window === window)",
            "scene=\(window.windowScene?.activationState.rawValue ?? -1)"
        ].joined(separator: "; ")
    }

    init(windowScene: UIWindowScene) {
        previousKeyWindow = windowScene.windows.first(where: \.isKeyWindow)
        window = UIWindow(windowScene: windowScene)
        window.frame = windowScene.effectiveGeometry.coordinateSpace.bounds
        mapView = MapboxMaps.MapView(
            frame: window.bounds,
            mapInitOptions: MapInitOptions(
                cameraOptions: CameraOptions(center: CLLocationCoordinate2D(latitude: 37.572, longitude: 126.98), zoom: 16),
                styleURI: nil
            )
        )
        renderer = MapboxFogRenderer(mapView: mapView, fogColor: .black)
        mapView.mapboxMap.onStyleLoaded.observe { [weak self] _ in
            self?.styleLoadCount += 1
        }.store(in: &subscriptions)
        mapView.mapboxMap.onRenderFrameFinished.observe { [weak self] _ in
            self?.renderedFrameCount += 1
        }.store(in: &subscriptions)
        mapView.mapboxMap.onMapIdle.observe { [weak self] _ in
            self?.idleCount += 1
        }.store(in: &subscriptions)
        mapView.mapboxMap.onSourceDataLoaded.observe { [weak self] event in
            guard let self, event.sourceId == "wander-exploration-fog" else { return }
            sourceEvents.append("type=\(event.type.rawValue), loaded=\(String(describing: event.loaded)), styleLoaded=\(mapView.mapboxMap.isStyleLoaded)")
            sourceEvents = Array(sourceEvents.suffix(12))
        }.store(in: &subscriptions)
        let controller = UIViewController()
        controller.view = mapView
        window.rootViewController = controller
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue + 1)
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
    }

    func loadStyle(backgroundID: String) {
        mapView.mapboxMap.loadStyle("""
        {"version":8,"sources":{},"layers":[{"id":"\(backgroundID)","type":"background","paint":{"background-color":"#f2f2f2"}}]}
        """)
    }

    func close() {
        renderer.tearDown()
        subscriptions.removeAll()
        mapView.removeFromSuperview()
        window.isHidden = true
        window.rootViewController = nil
        previousKeyWindow?.makeKey()
    }
}
