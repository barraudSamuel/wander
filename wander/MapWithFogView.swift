//
//  MapWithFogView.swift
//  wander
//
//  UIViewRepresentable bridge around MKMapView that renders a uniform fog of war.
//  A large overlay polygon is filled with semi-transparent grey, and every
//  discovered H3 cell is added as an interior polygon hole so the underlying
//  Apple Maps content shows through exactly where the user has been.
//

import SwiftUI
import MapKit
import CoreLocation

struct MapWithFogView: UIViewRepresentable {
    @ObservedObject var locationTracker: LocationTracker

    /// Set of H3 cell IDs that should be punched through the fog.
    var discoveredCellIDs: Set<String>

    /// City boundary used as the outer fog shape. When empty, no fog is drawn.
    var cityBoundaryCoordinates: [CLLocationCoordinate2D]

    /// Fog colour. Defaults to a semi-transparent black.
    var fogColor: UIColor = UIColor.black.withAlphaComponent(0.45)

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none

        // Failsafe initial view over Ho Chi Minh City before the boundary loads.
        mapView.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 10.76, longitude: 106.66),
            span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
        )

        updateFogOverlay(on: mapView, context: context)
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        let boundaryChanged = context.coordinator.lastBoundaryLength != cityBoundaryCoordinates.count
        let discoveredChanged = context.coordinator.lastDiscoveredIDs != discoveredCellIDs

        if boundaryChanged || discoveredChanged {
            updateFogOverlay(on: uiView, context: context)
        }

        // Center on the user once we have a location; otherwise fit the city
        // boundary so the fog overlay is visible immediately.
        if let coordinate = locationTracker.lastLocation?.coordinate,
           !context.coordinator.didSetInitialRegion {
            context.coordinator.didSetInitialRegion = true
            let region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 800,
                longitudinalMeters: 800
            )
            uiView.setRegion(region, animated: true)
        } else if !context.coordinator.didSetInitialRegion,
                  cityBoundaryCoordinates.count >= 3 {
            context.coordinator.didSetInitialRegion = true
            let region = coordinateRegion(for: cityBoundaryCoordinates)
            uiView.setRegion(region, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Fog overlay

    private func updateFogOverlay(on mapView: MKMapView, context: Context) {
        let coordinator = context.coordinator

        // Remove the previous fog overlay.
        if let overlay = coordinator.fogOverlay {
            mapView.removeOverlay(overlay)
            coordinator.fogOverlay = nil
        }

        guard cityBoundaryCoordinates.count >= 3 else {
            coordinator.lastDiscoveredIDs = discoveredCellIDs
            return
        }

        let explorationEngine = coordinator.explorationEngine
        let holes: [MKPolygon] = discoveredCellIDs.compactMap { cellID -> MKPolygon? in
            let coords = explorationEngine.boundaryCoordinates(for: cellID)
            guard coords.count >= 3 else { return nil }
            return coords.withUnsafeBufferPointer { buffer in
                guard let base = buffer.baseAddress else { return nil }
                return MKPolygon(coordinates: base, count: coords.count)
            }
        }

        let outerPolygon = cityBoundaryCoordinates.withUnsafeBufferPointer { buffer -> MKPolygon in
            guard let base = buffer.baseAddress else {
                return cityBoundaryCoordinates.withUnsafeBufferPointer { fallbackBuffer in
                    MKPolygon(
                        coordinates: fallbackBuffer.baseAddress!,
                        count: cityBoundaryCoordinates.count,
                        interiorPolygons: holes
                    )
                }
            }
            return MKPolygon(
                coordinates: base,
                count: cityBoundaryCoordinates.count,
                interiorPolygons: holes
            )
        }

        mapView.addOverlay(outerPolygon, level: .aboveRoads)
        coordinator.fogOverlay = outerPolygon
        coordinator.lastDiscoveredIDs = discoveredCellIDs
        coordinator.lastBoundaryLength = cityBoundaryCoordinates.count
    }

    private func coordinateRegion(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard let first = coordinates.first else {
            return MKCoordinateRegion()
        }

        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude

        for coordinate in coordinates.dropFirst() {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.01),
            longitudeDelta: max((maxLon - minLon) * 1.4, 0.01)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        let explorationEngine = ExplorationEngine()
        var fogOverlay: MKPolygon?
        var lastDiscoveredIDs: Set<String> = []
        var lastBoundaryLength: Int = 0
        var didSetInitialRegion = false

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.black.withAlphaComponent(0.45)
                renderer.strokeColor = nil
                renderer.lineWidth = 0
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
