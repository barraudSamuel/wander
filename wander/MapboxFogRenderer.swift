import MapboxMaps
import OSLog
import Turf
import UIKit

@MainActor
final class MapboxFogRenderer {
    private static let sourceID = "wander-exploration-fog"
    private static let layerID = "wander-exploration-fog-fill"
    private let logger = Logger(subsystem: "com.iterar.wander", category: "map")
    private weak var mapView: MapboxMaps.MapView?
    private let fogColor: UIColor
    private var styleSubscription: AnyCancelable?
    private let geometryWorker = FogGeometryWorker()
    private var computation: Task<[MapboxFogGeometry.Polygon], Never>?
    private var updateTask: Task<Void, Never>?
    private var cellIDs: Set<String>?
    private var generation = 0
    private var geometry = MapboxFogGeometry.polygons(revealedRings: [])

    init(mapView: MapboxMaps.MapView, fogColor: UIColor) {
        self.mapView = mapView
        self.fogColor = fogColor
        styleSubscription = mapView.mapboxMap.onStyleLoaded.observe { [weak self] _ in
            self?.install()
        }
        if mapView.mapboxMap.isStyleLoaded { install() }
    }

    func update(cellIDs: Set<String>) {
        guard self.cellIDs != cellIDs else { return }
        self.cellIDs = cellIDs
        generation &+= 1
        let revision = generation
        computation?.cancel()
        updateTask?.cancel()
        let geometryWorker = geometryWorker
        let computation = Task.detached(priority: .userInitiated) {
            await geometryWorker.polygons(cellIDs: cellIDs)
        }
        self.computation = computation
        updateTask = Task { [weak self] in
            let geometry = await computation.value
            guard !Task.isCancelled, let self, revision == generation else { return }
            self.geometry = geometry
            install()
        }
    }

    func tearDown() {
        generation &+= 1
        computation?.cancel()
        updateTask?.cancel()
        styleSubscription?.cancel()
        computation = nil
        updateTask = nil
        styleSubscription = nil
        mapView = nil
    }

    private func install() {
        guard let map = mapView?.mapboxMap else { return }
        let sourceExists = map.sourceExists(withId: Self.sourceID)
        // Parsing a pending source can make isStyleLoaded false. Its next snapshot
        // must still be queued, or the initial full-world mask can remain visible.
        guard sourceExists || map.isStyleLoaded else { return }
        let features = geometry.map { Feature(geometry: .polygon(Polygon($0.rings))) }
        let collection = FeatureCollection(features: features)
        let data = GeoJSONObject.featureCollection(collection)
        do {
            if sourceExists {
                map.updateGeoJSONSource(withId: Self.sourceID, geoJSON: data)
            } else {
                var source = GeoJSONSource(id: Self.sourceID)
                source.data = .featureCollection(collection)
                source.tolerance = 0
                source.maxzoom = 22
                try map.addSource(source)
            }
            if !map.layerExists(withId: Self.layerID) {
                var layer = FillLayer(id: Self.layerID, source: Self.sourceID)
                layer.fillColor = .constant(StyleColor(fogColor))
                // Preserve the fog tint independently of Standard's lighting.
                layer.fillEmissiveStrength = .constant(1)
                layer.fillAntialias = .constant(false)
                try map.addLayer(layer)
            }
        } catch {
            // Never log source geometry or account/location identifiers.
            logger.error("Le masque d’exploration Mapbox n’a pas pu être installé.")
        }
    }
}

/// Serializes the non-interruptible CoreGraphics subtraction. Cancelled snapshots
/// return before starting another subtraction when newer exploration has arrived.
private actor FogGeometryWorker {
    func polygons(cellIDs: Set<String>) -> [MapboxFogGeometry.Polygon] {
        guard !Task.isCancelled else { return [] }
        return MapboxFogGeometry.polygons(cellIDs: cellIDs)
    }
}
