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

    /// Group members to display on the map (excluding the current user).
    var groupMembers: [GroupMember] = []

    /// Fog colour — used by the polygon renderer.
    var fogColor: UIColor = UIColor.black.withAlphaComponent(0.45)

    /// When toggled, centers the map on the user's current location.
    @Binding var centerOnUser: Bool

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
        let membersChanged = context.coordinator.lastMemberUserIDs != Set(groupMembers.map { $0.userId })

        if boundaryChanged || discoveredChanged {
            updateFogOverlay(on: uiView, context: context)
        }

        if membersChanged {
            updateMemberAnnotations(on: uiView, context: context)
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

        if centerOnUser, let coordinate = locationTracker.lastLocation?.coordinate {
            DispatchQueue.main.async { centerOnUser = false }
            let region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 800,
                longitudinalMeters: 800
            )
            uiView.setRegion(region, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(fogColor: fogColor)
    }

    // MARK: - Member annotations

    private func updateMemberAnnotations(on mapView: MKMapView, context: Context) {
        let coordinator = context.coordinator

        // Remove annotations that are no longer in the group.
        let currentIDs = Set(groupMembers.map { $0.userId })
        let removedIDs = coordinator.memberAnnotations.keys.filter { !currentIDs.contains($0) }
        for userId in removedIDs {
            if let annotation = coordinator.memberAnnotations.removeValue(forKey: userId) {
                mapView.removeAnnotation(annotation)
            }
        }

        // Add or update annotations for current members.
        for member in groupMembers {
            guard let location = member.location else { continue }

            if let existing = coordinator.memberAnnotations[member.userId] {
                UIView.animate(withDuration: 0.5) {
                    existing.coordinate = location
                }
                existing.title = member.displayName
                existing.subtitle = member.userId
            } else {
                let annotation = MKPointAnnotation()
                annotation.coordinate = location
                annotation.title = member.displayName
                annotation.subtitle = member.userId
                coordinator.memberAnnotations[member.userId] = annotation
                mapView.addAnnotation(annotation)
            }
        }

        coordinator.lastMemberUserIDs = currentIDs
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

        // count >= 3 already guaranteed, so buffer.baseAddress is non-nil.
        let outerPolygon = cityBoundaryCoordinates.withUnsafeBufferPointer { buffer in
            MKPolygon(
                coordinates: buffer.baseAddress!,
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
        let fogColor: UIColor
        var fogOverlay: MKPolygon?
        var lastDiscoveredIDs: Set<String> = []
        var lastBoundaryLength: Int = 0
        var didSetInitialRegion = false
        var memberAnnotations: [String: MKPointAnnotation] = [:]
        var lastMemberUserIDs: Set<String> = []

        init(fogColor: UIColor) {
            self.fogColor = fogColor
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = fogColor
                renderer.strokeColor = nil
                renderer.lineWidth = 0
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }

            let identifier = "GroupMemberAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
                annotationView?.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
                annotationView?.layer.cornerRadius = 16
                annotationView?.layer.borderWidth = 2
                annotationView?.layer.borderColor = UIColor.white.cgColor
                annotationView?.clipsToBounds = true
            } else {
                annotationView?.annotation = annotation
            }

            // Colored circle with first letter of display name.
            let name = annotation.title ?? "?"
            let initial = String(name?.prefix(1) ?? "?")
            let stableKey = annotation.subtitle.flatMap { $0 } ?? name ?? "?"
            let color = memberColor(for: stableKey)

            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32))
            let image = renderer.image { ctx in
                color.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 32, height: 32))

                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14, weight: .bold),
                    .foregroundColor: UIColor.white
                ]
                let size = initial.size(withAttributes: attributes)
                let point = CGPoint(
                    x: (32 - size.width) / 2,
                    y: (32 - size.height) / 2
                )
                initial.draw(at: point, withAttributes: attributes)
            }

            annotationView?.image = image
            return annotationView
        }

        private func memberColor(for name: String?) -> UIColor {
            let colors: [UIColor] = [
                .systemBlue, .systemGreen, .systemOrange,
                .systemPink, .systemPurple, .systemTeal,
                .systemIndigo, .systemRed, .systemYellow,
                .systemMint
            ]
            let hash = abs((name ?? "?").hashValue)
            return colors[hash % colors.count]
        }
    }
}
