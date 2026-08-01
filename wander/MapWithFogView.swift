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

private func markerForegroundColor(for backgroundColor: UIColor) -> UIColor {
    ProfileColor.contrastingUIColor(for: backgroundColor)
}

struct MapUserCalloutInfo: Equatable {
    let displayName: String
    let relationshipText: String
    let isExplorationLoaded: Bool
    let cityProgress: CityProgress?
    let totalExploredCellCount: Int
    let locationSampledAt: Date?
}

final class UserLocationAnnotation: MKPointAnnotation {}

final class FriendLocationAnnotation: MKPointAnnotation {
    var userID = ""
}

final class UserLocationAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "UserLocationAnnotation"
    static let friendReuseIdentifier = "FriendLocationAnnotation"

    private let markerRingView = UIView()
    private let avatarImageView = UIImageView()
    private let fallbackLabel = UILabel()
    private var configuredAvatarImageData: Data?
    private var configuredDisplayName: String?
    private var configuredProfileColorHex: String?
    private var configuredCalloutInfo: MapUserCalloutInfo?

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
        markerRingView.frame = CGRect(
            x: (bounds.width - markerSize) / 2,
            y: (bounds.height - markerSize) / 2,
            width: markerSize,
            height: markerSize
        )
        markerRingView.layer.cornerRadius = markerSize / 2
        markerRingView.layer.shadowPath = UIBezierPath(
            ovalIn: markerRingView.bounds
        ).cgPath

        let avatarInset: CGFloat = 3
        avatarImageView.frame = markerRingView.bounds.insetBy(
            dx: avatarInset,
            dy: avatarInset
        )
        avatarImageView.layer.cornerRadius = avatarImageView.bounds.width / 2
        fallbackLabel.frame = avatarImageView.frame
        fallbackLabel.layer.cornerRadius = fallbackLabel.bounds.width / 2
    }

    func configure(
        avatarImageData: Data,
        displayName: String,
        profileColorHex: String,
        calloutInfo: MapUserCalloutInfo
    ) {
        if configuredAvatarImageData != avatarImageData
            || configuredDisplayName != displayName
            || configuredProfileColorHex != profileColorHex {
            let profileColor = ProfileColor.uiColor(hex: profileColorHex)
            markerRingView.backgroundColor = profileColor
            markerRingView.layer.shadowColor = profileColor.cgColor
            fallbackLabel.backgroundColor = profileColor
            fallbackLabel.textColor = markerForegroundColor(for: profileColor)

            if let image = UIImage(data: avatarImageData) {
                avatarImageView.image = image
                avatarImageView.isHidden = false
                fallbackLabel.isHidden = true
            } else {
                let trimmedName = displayName.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                fallbackLabel.text = trimmedName.isEmpty
                    ? "W"
                    : String(trimmedName.prefix(1)).uppercased()
                avatarImageView.image = nil
                avatarImageView.isHidden = true
                fallbackLabel.isHidden = false
            }

            configuredAvatarImageData = avatarImageData
            configuredDisplayName = displayName
            configuredProfileColorHex = profileColorHex
        }

        if configuredCalloutInfo != calloutInfo {
            detailCalloutAccessoryView = makeCalloutDetailView(for: calloutInfo)
            accessibilityLabel = "\(calloutInfo.displayName), \(calloutInfo.relationshipText)"
            accessibilityHint = "Touchez pour afficher les informations d’exploration"
            accessibilityTraits = .button
            configuredCalloutInfo = calloutInfo
        }
    }

    private func configureView() {
        frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        backgroundColor = .clear
        clipsToBounds = false
        canShowCallout = true
        collisionMode = .none
        displayPriority = .required
        isAccessibilityElement = true

        markerRingView.layer.borderColor = UIColor.white.cgColor
        markerRingView.layer.borderWidth = 1.5
        markerRingView.layer.shadowOpacity = 0.38
        markerRingView.layer.shadowRadius = 8
        markerRingView.layer.shadowOffset = .zero
        markerRingView.isUserInteractionEnabled = false
        addSubview(markerRingView)

        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarImageView.layer.borderColor = UIColor.white.withAlphaComponent(0.85).cgColor
        avatarImageView.layer.borderWidth = 1
        markerRingView.addSubview(avatarImageView)

        fallbackLabel.backgroundColor = UIColor.systemBlue
        fallbackLabel.font = .systemFont(ofSize: 18, weight: .black)
        fallbackLabel.textAlignment = .center
        fallbackLabel.clipsToBounds = true
        fallbackLabel.layer.borderColor = UIColor.white.withAlphaComponent(0.85).cgColor
        fallbackLabel.layer.borderWidth = 1
        markerRingView.addSubview(fallbackLabel)

        setNeedsLayout()
    }

    private func makeCalloutDetailView(
        for info: MapUserCalloutInfo
    ) -> UIView {
        let label = UILabel()
        label.numberOfLines = 0
        label.preferredMaxLayoutWidth = 230
        label.adjustsFontForContentSizeCategory = true

        let content = NSMutableAttributedString()
        content.append(
            NSAttributedString(
                string: info.relationshipText.uppercased(),
                attributes: [
                    .font: UIFont.preferredFont(forTextStyle: .caption2),
                    .foregroundColor: UIColor.secondaryLabel
                ]
            )
        )
        content.append(NSAttributedString(string: "\n"))

        let progressText: String
        let progressDetailText: String
        if !info.isExplorationLoaded {
            progressText = "Exploration indisponible"
            progressDetailText = "La progression n’a pas encore été chargée"
        } else if let progress = info.cityProgress {
            let percentage = progress.percentage.formatted(
                .percent.precision(.fractionLength(1))
            )
            progressText = "\(percentage) exploré"
            progressDetailText = [
                progress.cityName,
                "\(progress.exploredCells.formatted()) / \(progress.totalCells.formatted()) zones"
            ].joined(separator: " · ")
        } else {
            progressText = Self.exploredZoneText(info.totalExploredCellCount)
            progressDetailText = "Progression par ville indisponible"
        }

        content.append(
            NSAttributedString(
                string: progressText,
                attributes: [
                    .font: UIFont.preferredFont(forTextStyle: .headline),
                    .foregroundColor: UIColor.label
                ]
            )
        )
        content.append(NSAttributedString(string: "\n"))
        content.append(
            NSAttributedString(
                string: progressDetailText,
                attributes: [
                    .font: UIFont.preferredFont(forTextStyle: .caption1),
                    .foregroundColor: UIColor.secondaryLabel
                ]
            )
        )

        if let locationText = Self.locationText(sampledAt: info.locationSampledAt) {
            content.append(NSAttributedString(string: "\n"))
            content.append(
                NSAttributedString(
                    string: locationText,
                    attributes: [
                        .font: UIFont.preferredFont(forTextStyle: .caption1),
                        .foregroundColor: UIColor.tertiaryLabel
                    ]
                )
            )
        }

        label.attributedText = content
        label.accessibilityLabel = [
            info.relationshipText,
            progressText,
            progressDetailText,
            Self.locationText(sampledAt: info.locationSampledAt)
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
        return label
    }

    private static func exploredZoneText(_ count: Int) -> String {
        switch count {
        case 0:
            "Aucune zone explorée"
        case 1:
            "1 zone explorée"
        default:
            "\(count.formatted()) zones explorées"
        }
    }

    private static func locationText(sampledAt: Date?) -> String? {
        guard let sampledAt else { return nil }

        if Calendar.autoupdatingCurrent.isDateInToday(sampledAt) {
            return "Dernière position à \(positionTimeFormatter.string(from: sampledAt))"
        }

        return "Dernière position le \(positionDateTimeFormatter.string(from: sampledAt))"
    }

    private static let positionTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeStyle = .short
        return formatter
    }()

    private static let positionDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

struct FriendScratchCellPolygon {
    let coordinates: [CLLocationCoordinate2D]
    let mapRect: MKMapRect
}

final class FriendScratchOverlay: NSObject, MKOverlay {
    let userID: String
    let color: UIColor
    let boundingMapRect: MKMapRect
    let coordinate: CLLocationCoordinate2D
    let cellPolygons: [String: FriendScratchCellPolygon]

    init(
        userID: String,
        cellIDs: Set<String>,
        color: UIColor,
        explorationEngine: ExplorationEngine
    ) {
        self.userID = userID
        self.color = color

        var polygons: [String: FriendScratchCellPolygon] = [:]
        var minLat = 90.0
        var maxLat = -90.0
        var minLng = 180.0
        var maxLng = -180.0

        for cellID in cellIDs.sorted() {
            let coordinates = explorationEngine.boundaryCoordinates(for: cellID)
            guard coordinates.count >= 3 else { continue }

            polygons[cellID] = FriendScratchCellPolygon(
                coordinates: coordinates,
                mapRect: Self.mapRect(for: coordinates)
            )

            for coordinate in coordinates {
                minLat = min(minLat, coordinate.latitude)
                maxLat = max(maxLat, coordinate.latitude)
                minLng = min(minLng, coordinate.longitude)
                maxLng = max(maxLng, coordinate.longitude)
            }
        }

        cellPolygons = polygons

        if polygons.isEmpty {
            coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
            boundingMapRect = .null
        } else {
            coordinate = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLng + maxLng) / 2
            )

            let topLeft = MKMapPoint(
                CLLocationCoordinate2D(latitude: maxLat, longitude: minLng)
            )
            let bottomRight = MKMapPoint(
                CLLocationCoordinate2D(latitude: minLat, longitude: maxLng)
            )
            let padding = 1_000.0
            boundingMapRect = MKMapRect(
                x: topLeft.x - padding,
                y: topLeft.y - padding,
                width: bottomRight.x - topLeft.x + padding * 2,
                height: bottomRight.y - topLeft.y + padding * 2
            )
        }

        super.init()
    }

    private static func mapRect(
        for coordinates: [CLLocationCoordinate2D]
    ) -> MKMapRect {
        coordinates.reduce(.null) { partialResult, coordinate in
            let point = MKMapPoint(coordinate)
            return partialResult.union(
                MKMapRect(x: point.x, y: point.y, width: 1, height: 1)
            )
        }
    }
}

final class FriendScratchOverlayRenderer: MKOverlayRenderer {
    override func canDraw(_ mapRect: MKMapRect, zoomScale: MKZoomScale) -> Bool {
        true
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let overlay = overlay as? FriendScratchOverlay,
              !overlay.cellPolygons.isEmpty else { return }

        let color = overlay.color
        context.setLineWidth(1 / zoomScale)
        context.setFillColor(color.withAlphaComponent(0.34).cgColor)
        context.setStrokeColor(color.withAlphaComponent(0.75).cgColor)

        for polygon in overlay.cellPolygons.values
            where polygon.mapRect.intersects(mapRect) {

            context.beginPath()
            for (index, coordinate) in polygon.coordinates.enumerated() {
                let point = point(for: MKMapPoint(coordinate))
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
        self.cellPolygons = cellIDs.sorted().compactMap { cellID in
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

    /// Selected friends whose explored cells are visible on the map.
    var friendExplorations: [String: FriendExploration] = [:]

    /// All accepted-friend exploration data, including maps not currently visible.
    var allFriendExplorations: [String: FriendExploration] = [:]

    /// Exploration progress for the city containing each visible user marker.
    var userExplorationProgress: CityProgress?
    var friendExplorationProgress: [String: CityProgress] = [:]
    var loadedFriendExplorationUserIDs: Set<String> = []

    var userDisplayName = ""
    var userAvatarImageData = Data()
    var userProfileColorHex = ""

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
    /// Monotonic token that must change whenever heat-map values change.
    var heatMapRevision: Int = 0

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
            visibleDiscoveredCellIDs: visibleDiscoveredCellIDs
        )
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        let visibleCellIDs = visibleDiscoveredCellIDs
        let boundaryChanged = context.coordinator.lastBoundaryLength != cityBoundaryCoordinates.count
        let discoveredChanged = context.coordinator.lastDiscoveredIDs != visibleCellIDs
        let heatMapVisibilityChanged = context.coordinator.lastShowsHeatMap != showsHeatMap
        let friendExplorationsChanged =
            context.coordinator.lastFriendExplorations != friendExplorations
        let heatMapDataChanged =
            context.coordinator.lastHeatMapRevision != heatMapRevision

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

        if friendExplorationsChanged {
            updateFriendScratchOverlays(on: uiView, context: context)
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
                friendLocations: friendLocations,
                context: context
            )
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(fogColor: fogColor)
    }

    private var visibleDiscoveredCellIDs: Set<String> {
        friendExplorations.values.reduce(into: discoveredCellIDs) { result, exploration in
            result.formUnion(exploration.cellIDs)
        }
    }

    // MARK: - User location

    private func updateUserLocationAnnotation(on mapView: MKMapView, context: Context) {
        let coordinator = context.coordinator
        let trimmedDisplayName = userDisplayName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let resolvedDisplayName = trimmedDisplayName.isEmpty
            ? "Explorer"
            : trimmedDisplayName
        let calloutInfo = MapUserCalloutInfo(
            displayName: resolvedDisplayName,
            relationshipText: "Vous",
            isExplorationLoaded: true,
            cityProgress: userExplorationProgress,
            totalExploredCellCount: discoveredCellIDs.count,
            locationSampledAt: locationTracker.lastLocation?.timestamp
        )
        coordinator.updateUserMarkerAppearance(
            avatarImageData: userAvatarImageData,
            displayName: resolvedDisplayName,
            profileColorHex: userProfileColorHex,
            calloutInfo: calloutInfo,
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
            annotation.title = resolvedDisplayName
            coordinator.userLocationAnnotation = annotation
            mapView.addAnnotation(annotation)
        }

        annotation.title = resolvedDisplayName
        annotation.subtitle = nil

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
        let removedIDs = coordinator.friendAnnotations.keys
            .filter { !currentIDs.contains($0) }
            .sorted()
        for userID in removedIDs {
            if let annotation = coordinator.friendAnnotations.removeValue(forKey: userID) {
                mapView.removeAnnotation(annotation)
            }
            coordinator.friendProfileColorHexByUserID.removeValue(forKey: userID)
            coordinator.friendCalloutInfoByUserID.removeValue(forKey: userID)
        }

        // Incrementally add or move annotations for fresh accepted-friend locations.
        for userID in friendLocations.keys.sorted() {
            guard let friendLocation = friendLocations[userID] else { continue }

            coordinator.friendProfileColorHexByUserID[friendLocation.userID] =
                friendLocation.profileColorHex
            let friendExploration = allFriendExplorations[friendLocation.userID]
            let calloutInfo = MapUserCalloutInfo(
                displayName: friendLocation.displayName,
                relationshipText: "Ami",
                isExplorationLoaded: loadedFriendExplorationUserIDs.contains(
                    friendLocation.userID
                ),
                cityProgress: friendExplorationProgress[friendLocation.userID],
                totalExploredCellCount: friendExploration?.cellIDs.count ?? 0,
                locationSampledAt: friendLocation.sampledAt
            )
            coordinator.friendCalloutInfoByUserID[friendLocation.userID] = calloutInfo

            if let existing = coordinator.friendAnnotations[friendLocation.userID] {
                if existing.coordinate.latitude != friendLocation.coordinate.latitude
                    || existing.coordinate.longitude != friendLocation.coordinate.longitude {
                    UIView.animate(withDuration: 0.5) {
                        existing.coordinate = friendLocation.coordinate
                    }
                }

                existing.title = friendLocation.displayName
                existing.subtitle = nil
                if let annotationView = mapView.view(for: existing) {
                    coordinator.configureFriendAnnotationView(
                        annotationView,
                        displayName: friendLocation.displayName,
                        profileColorHex: friendLocation.profileColorHex,
                        calloutInfo: calloutInfo
                    )
                }
            } else {
                let annotation = FriendLocationAnnotation()
                annotation.userID = friendLocation.userID
                annotation.coordinate = friendLocation.coordinate
                annotation.title = friendLocation.displayName
                annotation.subtitle = nil
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

        let overlay = FogOfWarOverlay(
            cellIDs: visibleDiscoveredCellIDs,
            explorationEngine: coordinator.explorationEngine
        )

        coordinator.fogOverlay = overlay
        coordinator.lastDiscoveredIDs = visibleDiscoveredCellIDs
        coordinator.lastBoundaryLength = cityBoundaryCoordinates.count
        applyManagedOverlayOrder(on: mapView, context: context)
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
        friendLocations: [String: FriendLocation],
        context: Context
    ) {
        mapView.setUserTrackingMode(.none, animated: false)

        if let coordinate = friendLocations[userID]?.coordinate {
            setFocusedRegion(on: mapView, center: coordinate, animated: true)
            return
        }

        if let overlay = friendScratchOverlay(for: userID, context: context) {
            setVisibleRegion(for: overlay, on: mapView)
        }
    }

    private func friendScratchOverlay(
        for userID: String,
        context: Context
    ) -> FriendScratchOverlay? {
        if let overlay = context.coordinator.friendScratchOverlays.first(
            where: { $0.userID == userID }
        ), !overlay.cellPolygons.isEmpty {
            return overlay
        }

        guard let exploration = allFriendExplorations[userID],
              !exploration.cellIDs.isEmpty else {
            return nil
        }

        let overlay = FriendScratchOverlay(
            userID: exploration.userID,
            cellIDs: exploration.cellIDs,
            color: ProfileColor.uiColor(hex: exploration.profileColorHex),
            explorationEngine: context.coordinator.explorationEngine
        )

        return overlay.cellPolygons.isEmpty ? nil : overlay
    }

    private func setVisibleRegion(
        for overlay: FriendScratchOverlay,
        on mapView: MKMapView
    ) {
        guard !overlay.boundingMapRect.isNull else { return }

        let pointsPerMeter = MKMapPointsPerMeterAtLatitude(
            overlay.coordinate.latitude
        )
        let minimumHalfWidth = 400 * pointsPerMeter
        let minimumMapRect = MKMapRect(
            x: MKMapPoint(overlay.coordinate).x - minimumHalfWidth,
            y: MKMapPoint(overlay.coordinate).y - minimumHalfWidth,
            width: minimumHalfWidth * 2,
            height: minimumHalfWidth * 2
        )
        let visibleMapRect = overlay.boundingMapRect.union(minimumMapRect)

        mapView.setVisibleMapRect(
            visibleMapRect,
            edgePadding: UIEdgeInsets(
                top: 64,
                left: 32,
                bottom: 120,
                right: 32
            ),
            animated: true
        )
    }

    // MARK: - Heat map overlay

    private func updateHeatMapOverlay(on mapView: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.lastHeatMapRevision = heatMapRevision

        guard showsHeatMap else {
            coordinator.heatMapOverlay = nil
            applyManagedOverlayOrder(on: mapView, context: context)
            return
        }

        guard !heatMapCellData.isEmpty else {
            coordinator.heatMapOverlay = nil
            applyManagedOverlayOrder(on: mapView, context: context)
            return
        }

        let overlay = HeatMapOverlay(
            cellData: heatMapCellData,
            explorationEngine: coordinator.explorationEngine
        )

        coordinator.heatMapOverlay =
            overlay.cellPolygons.isEmpty ? nil : overlay

        applyManagedOverlayOrder(on: mapView, context: context)
    }

    // MARK: - Friend scratch overlays

    private func updateFriendScratchOverlays(
        on mapView: MKMapView,
        context: Context
    ) {
        let coordinator = context.coordinator

        let overlays = friendExplorations
            .filter { !$0.value.cellIDs.isEmpty }
            .sorted { $0.key < $1.key }
            .compactMap { _, exploration -> FriendScratchOverlay? in
                let overlay = FriendScratchOverlay(
                    userID: exploration.userID,
                    cellIDs: exploration.cellIDs,
                    color: ProfileColor.uiColor(hex: exploration.profileColorHex),
                    explorationEngine: coordinator.explorationEngine
                )
                return overlay.cellPolygons.isEmpty ? nil : overlay
            }

        coordinator.friendScratchOverlays = overlays
        coordinator.lastFriendExplorations = friendExplorations
        applyManagedOverlayOrder(on: mapView, context: context)
    }

    /// Keeps the visual stack deterministic regardless of which filter changed
    /// most recently: fog first, then the local heat map, then friend colors.
    private func applyManagedOverlayOrder(
        on mapView: MKMapView,
        context: Context
    ) {
        let coordinator = context.coordinator
        var desiredManagedOverlays: [MKOverlay] = []
        if let fogOverlay = coordinator.fogOverlay {
            desiredManagedOverlays.append(fogOverlay)
        }
        if let heatMapOverlay = coordinator.heatMapOverlay {
            desiredManagedOverlays.append(heatMapOverlay)
        }
        desiredManagedOverlays.append(contentsOf: coordinator.friendScratchOverlays)

        let desiredIdentifiers = Set(desiredManagedOverlays.map {
            ObjectIdentifier($0 as AnyObject)
        })
        let attachedManagedOverlays = mapView.overlays.filter {
            $0 is FogOfWarOverlay
                || $0 is HeatMapOverlay
                || $0 is FriendScratchOverlay
        }
        let staleOverlays = attachedManagedOverlays.filter {
            !desiredIdentifiers.contains(ObjectIdentifier($0 as AnyObject))
        }
        if !staleOverlays.isEmpty {
            mapView.removeOverlays(staleOverlays)
        }

        // Keep renderers for unchanged overlays alive. A fog update should not
        // recreate the heat-map and every friend renderer (and vice versa).
        var attachedIdentifiers = Set(mapView.overlays.map {
            ObjectIdentifier($0 as AnyObject)
        })

        for (index, overlay) in desiredManagedOverlays.enumerated() {
            let identifier = ObjectIdentifier(overlay as AnyObject)
            guard !attachedIdentifiers.contains(identifier) else { continue }

            let followingOverlay = desiredManagedOverlays
                .dropFirst(index + 1)
                .first {
                    attachedIdentifiers.contains(ObjectIdentifier($0 as AnyObject))
                }
            let precedingOverlay = desiredManagedOverlays[..<index]
                .reversed()
                .first {
                    attachedIdentifiers.contains(ObjectIdentifier($0 as AnyObject))
                }

            if let followingOverlay {
                mapView.insertOverlay(overlay, below: followingOverlay)
            } else if let precedingOverlay {
                mapView.insertOverlay(overlay, above: precedingOverlay)
            } else {
                mapView.addOverlay(overlay, level: .aboveRoads)
            }
            attachedIdentifiers.insert(identifier)
        }
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
        var lastHeatMapRevision = 0
        var lastFriendExplorations: [String: FriendExploration] = [:]
        var didSetInitialRegion = false
        var userLocationAnnotation: UserLocationAnnotation?
        private var userAvatarImageData = Data()
        private var userDisplayName = ""
        private var userProfileColorHex = ""
        private var userCalloutInfo: MapUserCalloutInfo?
        var friendAnnotations: [String: FriendLocationAnnotation] = [:]
        var friendProfileColorHexByUserID: [String: String] = [:]
        var friendCalloutInfoByUserID: [String: MapUserCalloutInfo] = [:]
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
                    displayName: userDisplayName,
                    profileColorHex: userProfileColorHex,
                    calloutInfo: userCalloutInfo ?? MapUserCalloutInfo(
                        displayName: userDisplayName,
                        relationshipText: "Vous",
                        isExplorationLoaded: true,
                        cityProgress: nil,
                        totalExploredCellCount: 0,
                        locationSampledAt: nil
                    )
                )
                return annotationView
            }

            guard !(annotation is MKUserLocation) else { return nil }
            guard let friendAnnotation = annotation as? FriendLocationAnnotation else {
                return nil
            }

            let annotationView = mapView.dequeueReusableAnnotationView(
                withIdentifier: UserLocationAnnotationView.friendReuseIdentifier
            ) as? UserLocationAnnotationView
                ?? UserLocationAnnotationView(
                    annotation: annotation,
                    reuseIdentifier: UserLocationAnnotationView.friendReuseIdentifier
                )
            annotationView.annotation = annotation

            let displayName = annotation.title.flatMap { $0 } ?? "Explorer"
            let userID = friendAnnotation.userID
            let profileColorHex =
                friendProfileColorHexByUserID[userID]
                ?? ProfileColor.generatedHex(seed: userID)
            let calloutInfo = friendCalloutInfoByUserID[userID]
                ?? MapUserCalloutInfo(
                    displayName: displayName,
                    relationshipText: "Ami",
                    isExplorationLoaded: false,
                    cityProgress: nil,
                    totalExploredCellCount: 0,
                    locationSampledAt: nil
                )
            configureFriendAnnotationView(
                annotationView,
                displayName: displayName,
                profileColorHex: profileColorHex,
                calloutInfo: calloutInfo
            )
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
            profileColorHex: String,
            calloutInfo: MapUserCalloutInfo,
            on mapView: MKMapView
        ) {
            let normalizedProfileColorHex =
                ProfileColor.normalizedHex(profileColorHex)
                ?? ProfileColor.storedOrGeneratedHex()

            guard userAvatarImageData != avatarImageData ||
                    userDisplayName != displayName ||
                    userProfileColorHex != normalizedProfileColorHex ||
                    userCalloutInfo != calloutInfo else { return }

            userAvatarImageData = avatarImageData
            userDisplayName = displayName
            userProfileColorHex = normalizedProfileColorHex
            userCalloutInfo = calloutInfo

            guard let annotation = userLocationAnnotation,
                  let annotationView = mapView.view(for: annotation)
                    as? UserLocationAnnotationView else { return }

            annotationView.configure(
                avatarImageData: avatarImageData,
                displayName: displayName,
                profileColorHex: normalizedProfileColorHex,
                calloutInfo: calloutInfo
            )
        }

        func configureFriendAnnotationView(
            _ annotationView: MKAnnotationView,
            displayName: String,
            profileColorHex: String,
            calloutInfo: MapUserCalloutInfo
        ) {
            guard let annotationView = annotationView as? UserLocationAnnotationView else {
                return
            }

            annotationView.configure(
                avatarImageData: Data(),
                displayName: displayName,
                profileColorHex: profileColorHex,
                calloutInfo: calloutInfo
            )
        }
    }
}
