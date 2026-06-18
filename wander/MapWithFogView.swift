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

    /// Fog colour. Defaults to a semi-transparent black.
    var fogColor: UIColor = UIColor.black.withAlphaComponent(0.45)

    /// Radius around the user covered by the fog. 10 km hides the hard edge
    /// for normal city use while keeping the overlay lightweight.
    var outerRadiusMeters: CLLocationDistance = 10_000

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow

        updateFogOverlay(on: mapView, context: context)
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        let overlayChanged = context.coordinator.lastDiscoveredIDs != discoveredCellIDs
        let centerMoved = shouldRecenterFog(context: context)

        if overlayChanged || centerMoved {
            updateFogOverlay(on: uiView, context: context)
        }

        // Keep the camera roughly centered on the latest user location when it
        // first becomes available.
        if let coordinate = locationTracker.lastLocation?.coordinate,
           !context.coordinator.didSetInitialRegion {
            context.coordinator.didSetInitialRegion = true
            let region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 800,
                longitudinalMeters: 800
            )
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

        guard let center = locationTracker.lastLocation?.coordinate else {
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

        let outerCoords = squareCoordinates(
            around: center,
            radiusInMeters: outerRadiusMeters
        )
        let outerPolygon = outerCoords.withUnsafeBufferPointer { buffer -> MKPolygon in
            guard let base = buffer.baseAddress else {
                return outerCoords.withUnsafeBufferPointer { fallbackBuffer in
                    MKPolygon(
                        coordinates: fallbackBuffer.baseAddress!,
                        count: outerCoords.count,
                        interiorPolygons: holes
                    )
                }
            }
            return MKPolygon(
                coordinates: base,
                count: outerCoords.count,
                interiorPolygons: holes
            )
        }

        mapView.addOverlay(outerPolygon, level: .aboveRoads)
        coordinator.fogOverlay = outerPolygon
        coordinator.lastFogCenter = center
        coordinator.lastDiscoveredIDs = discoveredCellIDs
    }

    private func shouldRecenterFog(context: Context) -> Bool {
        guard let current = locationTracker.lastLocation?.coordinate,
              let previous = context.coordinator.lastFogCenter else {
            return locationTracker.lastLocation != nil
        }

        let threshold: CLLocationDistance = 2_000
        let distance = CLLocation(latitude: current.latitude, longitude: current.longitude)
            .distance(from: CLLocation(latitude: previous.latitude, longitude: previous.longitude))
        return distance > threshold
    }

    /// Returns four corners of a square-ish box around `center`.
    private func squareCoordinates(
        around center: CLLocationCoordinate2D,
        radiusInMeters: CLLocationDistance
    ) -> [CLLocationCoordinate2D] {
        let metersPerDegreeLatitude = 111_320.0
        let metersPerDegreeLongitude = 111_320.0 * cos(center.latitude * .pi / 180)

        let latDelta = radiusInMeters / metersPerDegreeLatitude
        let lonDelta = radiusInMeters / metersPerDegreeLongitude

        return [
            CLLocationCoordinate2D(latitude: center.latitude + latDelta, longitude: center.longitude - lonDelta),
            CLLocationCoordinate2D(latitude: center.latitude + latDelta, longitude: center.longitude + lonDelta),
            CLLocationCoordinate2D(latitude: center.latitude - latDelta, longitude: center.longitude + lonDelta),
            CLLocationCoordinate2D(latitude: center.latitude - latDelta, longitude: center.longitude - lonDelta)
        ]
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        let explorationEngine = ExplorationEngine()
        var fogOverlay: MKPolygon?
        var lastDiscoveredIDs: Set<String> = []
        var lastFogCenter: CLLocationCoordinate2D?
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
