//
//  MapWithFogView.swift
//  wander
//
//  UIViewRepresentable bridge around MKMapView that renders a uniform fog of war.
//  A world-sized overlay fills the visible map with semi-transparent grey, and
//  every discovered H3 cell is punched through so Apple Maps shows where the
//  user has been.
//

import SwiftUI
import MapKit
import CoreLocation

enum FriendColor {
    private static let palette: [UIColor] = [
        .systemBlue, .systemGreen, .systemOrange,
        .systemPink, .systemPurple, .systemTeal,
        .systemIndigo, .systemRed, .systemYellow,
        .systemMint
    ]

    static func color(for userID: String) -> UIColor {
        let hash = stableHash(userID)
        return palette[Int(hash % UInt64(palette.count))]
    }

    private static func stableHash(_ value: String) -> UInt64 {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return hash
    }
}

final class FriendScratchOverlay: NSObject, MKOverlay {
    let userID: String
    let color: UIColor
    let boundingMapRect: MKMapRect
    let coordinate: CLLocationCoordinate2D
    let cellPolygons: [String: [CLLocationCoordinate2D]]

    init(
        userID: String,
        cellIDs: Set<String>,
        color: UIColor,
        explorationEngine: ExplorationEngine
    ) {
        self.userID = userID
        self.color = color

        var polygons: [String: [CLLocationCoordinate2D]] = [:]
        var minLat = 90.0
        var maxLat = -90.0
        var minLng = 180.0
        var maxLng = -180.0

        for cellID in cellIDs {
            let coords = explorationEngine.boundaryCoordinates(for: cellID)
            guard coords.count >= 3 else { continue }

            polygons[cellID] = coords

            for coord in coords {
                minLat = min(minLat, coord.latitude)
                maxLat = max(maxLat, coord.latitude)
                minLng = min(minLng, coord.longitude)
                maxLng = max(maxLng, coord.longitude)
            }
        }

        self.cellPolygons = polygons

        if polygons.isEmpty {
            self.coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
            self.boundingMapRect = MKMapRect.null
        } else {
            self.coordinate = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLng + maxLng) / 2
            )

            let topLeft = MKMapPoint(CLLocationCoordinate2D(latitude: maxLat, longitude: minLng))
            let bottomRight = MKMapPoint(CLLocationCoordinate2D(latitude: minLat, longitude: maxLng))
            let padding = 1000.0
            self.boundingMapRect = MKMapRect(
                x: topLeft.x - padding,
                y: topLeft.y - padding,
                width: bottomRight.x - topLeft.x + padding * 2,
                height: bottomRight.y - topLeft.y + padding * 2
            )
        }

        super.init()
    }
}

final class FriendScratchOverlayRenderer: MKOverlayRenderer {
    override func canDraw(_ mapRect: MKMapRect, zoomScale: MKZoomScale) -> Bool {
        true
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let overlay = self.overlay as? FriendScratchOverlay,
              !overlay.cellPolygons.isEmpty else { return }

        let color = overlay.color
        context.setLineWidth(1.0 / zoomScale)
        context.setFillColor(color.withAlphaComponent(0.34).cgColor)
        context.setStrokeColor(color.withAlphaComponent(0.75).cgColor)

        for coords in overlay.cellPolygons.values {
            context.beginPath()
            for (index, coord) in coords.enumerated() {
                let point = self.point(for: MKMapPoint(coord))
                if index == 0 {
                    context.move(to: point)
                } else {
                    context.addLine(to: point)
                }
            }
            context.closePath()
            context.drawPath(using: .fillStroke)
        }
    }
}

struct FogCellPolygon {
    let coordinates: [CLLocationCoordinate2D]
    let mapRect: MKMapRect
}

final class FogOfWarOverlay: NSObject, MKOverlay {
    let coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    let boundingMapRect = MKMapRect.world
    let cellPolygons: [FogCellPolygon]

    init(cellIDs: Set<String>, explorationEngine: ExplorationEngine) {
        self.cellPolygons = cellIDs.compactMap { cellID in
            let coords = explorationEngine.boundaryCoordinates(for: cellID)
            guard coords.count >= 3 else { return nil }
            return FogCellPolygon(
                coordinates: coords,
                mapRect: Self.mapRect(for: coords)
            )
        }
        super.init()
    }

    private static func mapRect(for coordinates: [CLLocationCoordinate2D]) -> MKMapRect {
        coordinates.reduce(MKMapRect.null) { partialResult, coordinate in
            let point = MKMapPoint(coordinate)
            let pointRect = MKMapRect(
                x: point.x,
                y: point.y,
                width: 1,
                height: 1
            )
            return partialResult.union(pointRect)
        }
    }
}

final class FogOfWarOverlayRenderer: MKOverlayRenderer {
    private let fogColor: UIColor

    init(overlay: FogOfWarOverlay, fogColor: UIColor) {
        self.fogColor = fogColor
        super.init(overlay: overlay)
    }

    override func canDraw(_ mapRect: MKMapRect, zoomScale: MKZoomScale) -> Bool {
        true
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let overlay = overlay as? FogOfWarOverlay else { return }

        let path = CGMutablePath()
        path.addRect(rect(for: mapRect))

        for cell in overlay.cellPolygons where cell.mapRect.intersects(mapRect) {
            for (index, coordinate) in cell.coordinates.enumerated() {
                let point = self.point(for: MKMapPoint(coordinate))
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.closeSubpath()
        }

        context.addPath(path)
        context.setFillColor(fogColor.cgColor)
        context.drawPath(using: .eoFill)
    }
}

struct MapWithFogView: UIViewRepresentable {
    @ObservedObject var locationTracker: LocationTracker

    /// Set of H3 cell IDs that should be punched through the fog.
    var discoveredCellIDs: Set<String>

    /// City boundary used only for the initial map fit. Fog is global.
    var cityBoundaryCoordinates: [CLLocationCoordinate2D]

    /// Group members to display on the map (excluding the current user).
    var groupMembers: [GroupMember] = []

    /// Fog colour — used by the polygon renderer.
    var fogColor: UIColor = UIColor.black.withAlphaComponent(0.45)

    /// When toggled, centers the map on the user's current location.
    @Binding var centerOnUser: Bool

    /// When set, centers the map on the selected friend once.
    @Binding var centerOnFriendUserID: String?

    var showsHeatMap = false
    var friendCellIDsByUserID: [String: Set<String>] = [:]
    var allFriendCellIDsByUserID: [String: Set<String>] = [:]
    var heatMapCellData: [String: (duration: TimeInterval, visitCount: Int)] = [:]

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

        updateFogOverlay(
            on: mapView,
            context: context,
            visibleDiscoveredCellIDs: visibleDiscoveredCellIDs
        )
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        let visibleCellIDs = visibleDiscoveredCellIDs
        let membersByID = Dictionary(uniqueKeysWithValues: groupMembers.map { ($0.userId, $0) })
        let boundaryChanged = context.coordinator.lastBoundaryLength != cityBoundaryCoordinates.count
        let discoveredChanged = context.coordinator.lastDiscoveredIDs != visibleCellIDs
        let membersChanged = context.coordinator.lastMembersByID != membersByID
        let heatMapVisibilityChanged = context.coordinator.lastShowsHeatMap != showsHeatMap
        let friendCellsChanged = context.coordinator.lastFriendCellIDsByUserID != friendCellIDsByUserID
        let heatMapDataChanged = context.coordinator.lastHeatMapCellDataCount != heatMapCellData.count

        if boundaryChanged || discoveredChanged {
            updateFogOverlay(
                on: uiView,
                context: context,
                visibleDiscoveredCellIDs: visibleCellIDs
            )
        }

        if heatMapVisibilityChanged || heatMapDataChanged {
            updateHeatMapOverlay(on: uiView, context: context)
        }

        if friendCellsChanged {
            updateFriendScratchOverlays(on: uiView, context: context)
        }

        if membersChanged {
            updateMemberAnnotations(on: uiView, context: context, membersByID: membersByID)
        }

        context.coordinator.lastShowsHeatMap = showsHeatMap

        // Center on the user once we have a location; otherwise fit the loaded
        // city boundary as a useful starting region.
        if let coordinate = locationTracker.lastLocation?.coordinate,
           !context.coordinator.didSetInitialRegion {
            context.coordinator.didSetInitialRegion = true
            setFocusedRegion(on: uiView, center: coordinate, animated: true)
        } else if !context.coordinator.didSetInitialRegion,
                  cityBoundaryCoordinates.count >= 3 {
            context.coordinator.didSetInitialRegion = true
            let region = coordinateRegion(for: cityBoundaryCoordinates)
            uiView.setRegion(region, animated: true)
        }

        if centerOnUser, let coordinate = locationTracker.lastLocation?.coordinate {
            DispatchQueue.main.async { centerOnUser = false }
            setFocusedRegion(on: uiView, center: coordinate, animated: true)
        }

        if let friendUserID = centerOnFriendUserID {
            DispatchQueue.main.async { centerOnFriendUserID = nil }
            centerMap(
                onFriend: friendUserID,
                on: uiView,
                context: context,
                membersByID: membersByID
            )
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(fogColor: fogColor)
    }

    private var visibleDiscoveredCellIDs: Set<String> {
        return friendCellIDsByUserID.values.reduce(into: discoveredCellIDs) { result, cellIDs in
            result.formUnion(cellIDs)
        }
    }

    // MARK: - Member annotations

    private func updateMemberAnnotations(
        on mapView: MKMapView,
        context: Context,
        membersByID: [String: GroupMember]
    ) {
        let coordinator = context.coordinator

        // Remove annotations that are no longer in the group.
        let currentIDs = Set(membersByID.keys)
        let removedIDs = coordinator.memberAnnotations.keys.filter { !currentIDs.contains($0) }
        for userId in removedIDs {
            if let annotation = coordinator.memberAnnotations.removeValue(forKey: userId) {
                mapView.removeAnnotation(annotation)
            }
        }

        // Add or update annotations for current members.
        for member in membersByID.values {
            guard let location = member.location else { continue }

            if let existing = coordinator.memberAnnotations[member.userId] {
                UIView.animate(withDuration: 0.5) {
                    existing.coordinate = location
                }
                existing.title = member.displayName
                existing.subtitle = member.userId
                mapView.view(for: existing)?.image = coordinator.memberImage(
                    displayName: member.displayName,
                    userID: member.userId
                )
            } else {
                let annotation = MKPointAnnotation()
                annotation.coordinate = location
                annotation.title = member.displayName
                annotation.subtitle = member.userId
                coordinator.memberAnnotations[member.userId] = annotation
                mapView.addAnnotation(annotation)
            }
        }

        coordinator.lastMembersByID = membersByID
    }

    // MARK: - Fog overlay

    private func updateFogOverlay(
        on mapView: MKMapView,
        context: Context,
        visibleDiscoveredCellIDs: Set<String>
    ) {
        let coordinator = context.coordinator

        if let overlay = coordinator.fogOverlay {
            mapView.removeOverlay(overlay)
            coordinator.fogOverlay = nil
        }

        let overlay = FogOfWarOverlay(
            cellIDs: visibleDiscoveredCellIDs,
            explorationEngine: coordinator.explorationEngine
        )

        mapView.addOverlay(overlay, level: .aboveRoads)
        coordinator.fogOverlay = overlay
        coordinator.lastDiscoveredIDs = visibleDiscoveredCellIDs
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

    private func setFocusedRegion(
        on mapView: MKMapView,
        center: CLLocationCoordinate2D,
        animated: Bool
    ) {
        let region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: 800,
            longitudinalMeters: 800
        )
        mapView.setRegion(region, animated: animated)
    }

    private func centerMap(
        onFriend userID: String,
        on mapView: MKMapView,
        context: Context,
        membersByID: [String: GroupMember]
    ) {
        if let coordinate = membersByID[userID]?.location {
            setFocusedRegion(on: mapView, center: coordinate, animated: true)
            return
        }

        if let coordinate = friendScratchCenter(for: userID, context: context) {
            setFocusedRegion(on: mapView, center: coordinate, animated: true)
        }
    }

    private func friendScratchCenter(for userID: String, context: Context) -> CLLocationCoordinate2D? {
        if let overlay = context.coordinator.friendScratchOverlays.first(where: { $0.userID == userID }),
           !overlay.cellPolygons.isEmpty {
            return overlay.coordinate
        }

        guard let cellIDs = allFriendCellIDsByUserID[userID], !cellIDs.isEmpty else {
            return nil
        }

        let overlay = FriendScratchOverlay(
            userID: userID,
            cellIDs: cellIDs,
            color: FriendColor.color(for: userID),
            explorationEngine: context.coordinator.explorationEngine
        )

        return overlay.cellPolygons.isEmpty ? nil : overlay.coordinate
    }

    // MARK: - Heat map overlay

    private func updateHeatMapOverlay(on mapView: MKMapView, context: Context) {
        let coordinator = context.coordinator

        if let overlay = coordinator.heatMapOverlay {
            mapView.removeOverlay(overlay)
            coordinator.heatMapOverlay = nil
        }

        guard showsHeatMap else {
            coordinator.lastHeatMapCellDataCount = heatMapCellData.count
            return
        }

        guard !heatMapCellData.isEmpty else {
            coordinator.lastHeatMapCellDataCount = heatMapCellData.count
            return
        }

        let overlay = HeatMapOverlay(
            cellData: heatMapCellData,
            explorationEngine: coordinator.explorationEngine
        )

        if !overlay.cellPolygons.isEmpty {
            mapView.addOverlay(overlay, level: .aboveRoads)
            coordinator.heatMapOverlay = overlay
        }

        coordinator.lastHeatMapCellDataCount = heatMapCellData.count
    }

    // MARK: - Friend scratch overlays

    private func updateFriendScratchOverlays(on mapView: MKMapView, context: Context) {
        let coordinator = context.coordinator

        for overlay in coordinator.friendScratchOverlays {
            mapView.removeOverlay(overlay)
        }
        coordinator.friendScratchOverlays.removeAll()

        let overlays = friendCellIDsByUserID
            .filter { !$0.value.isEmpty }
            .sorted { $0.key < $1.key }
            .compactMap { userID, cellIDs -> FriendScratchOverlay? in
                let overlay = FriendScratchOverlay(
                    userID: userID,
                    cellIDs: cellIDs,
                    color: FriendColor.color(for: userID),
                    explorationEngine: coordinator.explorationEngine
                )
                return overlay.cellPolygons.isEmpty ? nil : overlay
            }

        for overlay in overlays {
            mapView.addOverlay(overlay, level: .aboveRoads)
        }

        coordinator.friendScratchOverlays = overlays
        coordinator.lastFriendCellIDsByUserID = friendCellIDsByUserID
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        let explorationEngine = ExplorationEngine()
        let fogColor: UIColor
        var fogOverlay: FogOfWarOverlay?
        var heatMapOverlay: HeatMapOverlay?
        var friendScratchOverlays: [FriendScratchOverlay] = []
        var lastDiscoveredIDs: Set<String> = []
        var lastBoundaryLength: Int = 0
        var lastShowsHeatMap = false
        var lastHeatMapCellDataCount: Int = 0
        var lastFriendCellIDsByUserID: [String: Set<String>] = [:]
        var didSetInitialRegion = false
        var memberAnnotations: [String: MKPointAnnotation] = [:]
        var lastMembersByID: [String: GroupMember] = [:]

        init(fogColor: UIColor) {
            self.fogColor = fogColor
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let fogOverlay = overlay as? FogOfWarOverlay {
                return FogOfWarOverlayRenderer(overlay: fogOverlay, fogColor: fogColor)
            }
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = fogColor
                renderer.strokeColor = nil
                renderer.lineWidth = 0
                return renderer
            }
            if overlay is FriendScratchOverlay {
                return FriendScratchOverlayRenderer(overlay: overlay)
            }
            if overlay is HeatMapOverlay {
                return HeatMapOverlayRenderer(overlay: overlay)
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

            let displayName = annotation.title.flatMap { $0 } ?? "?"
            let userID = annotation.subtitle.flatMap { $0 } ?? displayName
            annotationView?.image = memberImage(displayName: displayName, userID: userID)
            return annotationView
        }

        func memberImage(displayName: String, userID: String) -> UIImage {
            let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            let initial = trimmedName.isEmpty ? "?" : String(trimmedName.prefix(1)).uppercased()
            let color = FriendColor.color(for: userID)

            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32))
            return renderer.image { ctx in
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
        }
    }
}
