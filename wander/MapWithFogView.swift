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

final class UserLocationAnnotation: MKPointAnnotation {}

final class UserLocationAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "UserLocationAnnotation"

    private let accentColor = UIColor(
        red: 0.31,
        green: 0.20,
        blue: 1.00,
        alpha: 1.00
    )
    private let markerRingView = UIView()
    private let avatarImageView = UIImageView()
    private let fallbackLabel = UILabel()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let markerSize: CGFloat = 32
        markerRingView.frame = CGRect(origin: .zero, size: CGSize(width: markerSize, height: markerSize))
        markerRingView.layer.cornerRadius = markerSize / 2

        let avatarInset: CGFloat = 0
        avatarImageView.frame = markerRingView.bounds.insetBy(
            dx: avatarInset,
            dy: avatarInset
        )
        avatarImageView.layer.cornerRadius = avatarImageView.bounds.width / 2
        fallbackLabel.frame = avatarImageView.frame
        fallbackLabel.layer.cornerRadius = fallbackLabel.bounds.width / 2
    }

    func configure(avatarImageData: Data, displayName: String) {
        if let image = UIImage(data: avatarImageData) {
            avatarImageView.image = image
            avatarImageView.isHidden = false
            fallbackLabel.isHidden = true
        } else {
            let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            fallbackLabel.text = trimmedName.isEmpty
                ? "W"
                : String(trimmedName.prefix(1)).uppercased()
            avatarImageView.image = nil
            avatarImageView.isHidden = true
            fallbackLabel.isHidden = false
        }
    }

    private func configureView() {
        frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        backgroundColor = .clear
        clipsToBounds = false
        canShowCallout = false
        collisionMode = .none
        displayPriority = .required

        markerRingView.backgroundColor = accentColor
        markerRingView.layer.borderColor = UIColor.white.cgColor
        markerRingView.layer.borderWidth = 1
        markerRingView.layer.shadowColor = accentColor.cgColor
        markerRingView.layer.shadowOpacity = 0.32
        markerRingView.layer.shadowRadius = 9
        markerRingView.layer.shadowOffset = .zero
        addSubview(markerRingView)

        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarImageView.layer.borderColor = UIColor.white.withAlphaComponent(0.85).cgColor
        avatarImageView.layer.borderWidth = 1
        markerRingView.addSubview(avatarImageView)

        fallbackLabel.backgroundColor = UIColor.systemBlue
        fallbackLabel.textColor = .white
        fallbackLabel.font = .systemFont(ofSize: 18, weight: .black)
        fallbackLabel.textAlignment = .center
        fallbackLabel.clipsToBounds = true
        markerRingView.addSubview(fallbackLabel)

        setNeedsLayout()
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

    /// Fresh locations belonging to accepted friends.
    var friendLocations: [String: FriendLocation] = [:]

    var userDisplayName = ""
    var userAvatarImageData = Data()

    /// Fog colour — used by the polygon renderer.
    var fogColor: UIColor = UIColor.black.withAlphaComponent(0.45)

    /// When toggled, follows the user's location while keeping north at the top.
    @Binding var centerOnUser: Bool

    /// When toggled, resets the map camera to a north-up, flat orientation.
    @Binding var resetMapOrientation: Bool

    /// When set, centers the map on the selected friend once.
    @Binding var centerOnFriendUserID: String?

    var showsHeatMap = false
    var heatMapCellData: [String: (duration: TimeInterval, visitCount: Int)] = [:]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.preferredConfiguration = MKStandardMapConfiguration(
            elevationStyle: .flat,
            emphasisStyle: .muted
        )
        mapView.showsUserLocation = true
        mapView.showsCompass = true
        mapView.userTrackingMode = .none

        // Failsafe initial view over Ho Chi Minh City before the boundary loads.
        mapView.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 10.76, longitude: 106.66),
            span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
        )

        updateFogOverlay(
            on: mapView,
            context: context,
            visibleDiscoveredCellIDs: discoveredCellIDs
        )
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        let boundaryChanged = context.coordinator.lastBoundaryLength != cityBoundaryCoordinates.count
        let discoveredChanged = context.coordinator.lastDiscoveredIDs != discoveredCellIDs
        let heatMapVisibilityChanged = context.coordinator.lastShowsHeatMap != showsHeatMap
        let heatMapDataChanged = context.coordinator.lastHeatMapCellDataCount != heatMapCellData.count

        if boundaryChanged || discoveredChanged {
            updateFogOverlay(
                on: uiView,
                context: context,
                visibleDiscoveredCellIDs: discoveredCellIDs
            )
        }

        if heatMapVisibilityChanged || heatMapDataChanged {
            updateHeatMapOverlay(on: uiView, context: context)
        }

        updateFriendAnnotations(on: uiView, context: context)
        updateUserLocationAnnotation(on: uiView, context: context)
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

        if centerOnUser, locationTracker.lastLocation != nil {
            DispatchQueue.main.async { centerOnUser = false }
            uiView.setUserTrackingMode(.follow, animated: true)
        }

        if resetMapOrientation {
            DispatchQueue.main.async { resetMapOrientation = false }
            resetCameraOrientation(on: uiView)
        }

        if let friendUserID = centerOnFriendUserID {
            DispatchQueue.main.async { centerOnFriendUserID = nil }
            centerMap(
                onFriend: friendUserID,
                on: uiView,
                friendLocations: friendLocations
            )
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(fogColor: fogColor)
    }

    // MARK: - User location

    private func updateUserLocationAnnotation(on mapView: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.updateUserMarkerAppearance(
            avatarImageData: userAvatarImageData,
            displayName: userDisplayName,
            on: mapView
        )

        guard let coordinate = locationTracker.lastLocation?.coordinate else {
            if let annotation = coordinator.userLocationAnnotation {
                mapView.removeAnnotation(annotation)
                coordinator.userLocationAnnotation = nil
            }
            mapView.view(for: mapView.userLocation)?.isHidden = false
            return
        }

        let annotation: UserLocationAnnotation
        if let existing = coordinator.userLocationAnnotation {
            annotation = existing
            annotation.coordinate = coordinate
        } else {
            annotation = UserLocationAnnotation()
            annotation.coordinate = coordinate
            coordinator.userLocationAnnotation = annotation
            mapView.addAnnotation(annotation)
        }

        mapView.view(for: mapView.userLocation)?.isHidden = true
    }

    // MARK: - Friend annotations

    private func updateFriendAnnotations(
        on mapView: MKMapView,
        context: Context
    ) {
        let coordinator = context.coordinator

        // Remove annotations when a friendship ends or its fresh location expires.
        let currentIDs = Set(friendLocations.keys)
        let removedIDs = coordinator.friendAnnotations.keys.filter { !currentIDs.contains($0) }
        for userID in removedIDs {
            if let annotation = coordinator.friendAnnotations.removeValue(forKey: userID) {
                mapView.removeAnnotation(annotation)
            }
        }

        // Incrementally add or move annotations for fresh accepted-friend locations.
        for friendLocation in friendLocations.values {
            if let existing = coordinator.friendAnnotations[friendLocation.userID] {
                if existing.coordinate.latitude != friendLocation.coordinate.latitude
                    || existing.coordinate.longitude != friendLocation.coordinate.longitude {
                    UIView.animate(withDuration: 0.5) {
                        existing.coordinate = friendLocation.coordinate
                    }
                }

                existing.title = friendLocation.displayName
                existing.subtitle = friendLocation.userID
                mapView.view(for: existing)?.image = coordinator.friendImage(
                    displayName: friendLocation.displayName,
                    userID: friendLocation.userID
                )
            } else {
                let annotation = MKPointAnnotation()
                annotation.coordinate = friendLocation.coordinate
                annotation.title = friendLocation.displayName
                annotation.subtitle = friendLocation.userID
                coordinator.friendAnnotations[friendLocation.userID] = annotation
                mapView.addAnnotation(annotation)
            }
        }
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

    private func resetCameraOrientation(on mapView: MKMapView) {
        let camera = mapView.camera.copy() as! MKMapCamera
        camera.heading = 0
        camera.pitch = 0
        mapView.setCamera(camera, animated: true)
    }

    private func centerMap(
        onFriend userID: String,
        on mapView: MKMapView,
        friendLocations: [String: FriendLocation]
    ) {
        mapView.setUserTrackingMode(.none, animated: false)

        if let coordinate = friendLocations[userID]?.coordinate {
            setFocusedRegion(on: mapView, center: coordinate, animated: true)
        }
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

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        let explorationEngine = ExplorationEngine()
        let fogColor: UIColor
        var fogOverlay: FogOfWarOverlay?
        var heatMapOverlay: HeatMapOverlay?
        var lastDiscoveredIDs: Set<String> = []
        var lastBoundaryLength: Int = 0
        var lastShowsHeatMap = false
        var lastHeatMapCellDataCount: Int = 0
        var didSetInitialRegion = false
        var userLocationAnnotation: UserLocationAnnotation?
        private var userAvatarImageData = Data()
        private var userDisplayName = ""
        var friendAnnotations: [String: MKPointAnnotation] = [:]

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
            if overlay is HeatMapOverlay {
                return HeatMapOverlayRenderer(overlay: overlay)
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is UserLocationAnnotation {
                let annotationView = mapView.dequeueReusableAnnotationView(
                    withIdentifier: UserLocationAnnotationView.reuseIdentifier
                ) as? UserLocationAnnotationView
                    ?? UserLocationAnnotationView(
                        annotation: annotation,
                        reuseIdentifier: UserLocationAnnotationView.reuseIdentifier
                    )
                annotationView.annotation = annotation
                annotationView.configure(
                    avatarImageData: userAvatarImageData,
                    displayName: userDisplayName
                )
                return annotationView
            }

            guard !(annotation is MKUserLocation) else { return nil }

            let identifier = "FriendLocationAnnotation"
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
            annotationView?.image = friendImage(displayName: displayName, userID: userID)
            return annotationView
        }

        func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
            for view in views where view.annotation is MKUserLocation {
                view.isHidden = userLocationAnnotation != nil
            }
        }

        func updateUserMarkerAppearance(
            avatarImageData: Data,
            displayName: String,
            on mapView: MKMapView
        ) {
            guard userAvatarImageData != avatarImageData ||
                    userDisplayName != displayName else { return }

            userAvatarImageData = avatarImageData
            userDisplayName = displayName

            guard let annotation = userLocationAnnotation,
                  let annotationView = mapView.view(for: annotation)
                    as? UserLocationAnnotationView else { return }

            annotationView.configure(
                avatarImageData: avatarImageData,
                displayName: displayName
            )
        }

        func friendImage(displayName: String, userID: String) -> UIImage {
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
