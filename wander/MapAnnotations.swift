//
//  MapAnnotations.swift
//  wander
//

import CoreLocation
import MapboxMaps
import Turf
import UIKit

class MapAnnotation: NSObject {
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?

    init(
        coordinate: CLLocationCoordinate2D = kCLLocationCoordinate2DInvalid,
        title: String? = nil,
        subtitle: String? = nil
    ) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        super.init()
    }
}

class MapAnnotationView: UIView {
    nonisolated deinit {}

    var annotation: MapAnnotation?
    let reuseIdentifier: String?
    var centerOffset: CGSize = .zero {
        didSet {
            if oldValue != centerOffset { onGeometryChange?() }
        }
    }
    private(set) var isSelected = false
    fileprivate var onGeometryChange: (() -> Void)?
    fileprivate var onActivate: (() -> Void)?

    override var bounds: CGRect {
        didSet {
            if oldValue.size != bounds.size { onGeometryChange?() }
        }
    }

    init(annotation: MapAnnotation? = nil, reuseIdentifier: String? = nil) {
        self.annotation = annotation
        self.reuseIdentifier = reuseIdentifier
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        annotation = nil
        reuseIdentifier = nil
        super.init(coder: coder)
    }

    func setSelected(_ selected: Bool, animated: Bool) {
        isSelected = selected
    }

    func prepareForReuse() {}

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        bounds.size
    }

    override func systemLayoutSizeFitting(_ targetSize: CGSize) -> CGSize {
        bounds.size
    }

    override func accessibilityActivate() -> Bool {
        guard let onActivate else { return false }
        onActivate()
        return true
    }
}

/// Owns Mapbox view annotations and delivers the app's selection lifecycle.
@MainActor
final class MapAnnotationStore: NSObject, UIGestureRecognizerDelegate {
    var makeView: ((MapAnnotation) -> MapAnnotationView?)?
    var onSelect: ((MapAnnotationView) -> Void)?
    var onDeselect: ((MapAnnotationView) -> Void)?
    var onDidAdd: (([MapAnnotationView]) -> Void)?
    private(set) var annotations: [MapAnnotation] = []
    private(set) var selectedAnnotations: [MapAnnotation] = []

    private weak var mapView: MapboxMaps.MapView?
    private var entries: [ObjectIdentifier: Entry] = [:]
    private var overlapUpdateScheduled = false
    private var previousOverlapZoom: Double?
    private var lastHiddenIcons: Set<ObjectIdentifier> = []
    private var lastHiddenLabels: Set<ObjectIdentifier> = []
    private var zoomOutHiddenIcons: Set<ObjectIdentifier> = []
    private var zoomOutHiddenLabels: Set<ObjectIdentifier> = []
    private var isOverlapZoomingOut = false

    private struct Entry {
        let view: MapAnnotationView
        let native: ViewAnnotation
        var coordinate: CLLocationCoordinate2D
    }

    init(mapView: MapboxMaps.MapView) {
        self.mapView = mapView
        super.init()
    }

    // Native annotations are detached explicitly while the map is on the main actor.
    nonisolated deinit {}

    func view(for annotation: MapAnnotation) -> MapAnnotationView? {
        entries[ObjectIdentifier(annotation)]?.view
    }

    func addAnnotation(_ annotation: MapAnnotation) {
        addAnnotations([annotation])
    }

    func addAnnotations(_ additions: [MapAnnotation]) {
        var annotationIDs = Set(annotations.map(ObjectIdentifier.init))
        var addedViews: [MapAnnotationView] = []
        for annotation in additions {
            guard annotationIDs.insert(ObjectIdentifier(annotation)).inserted else { continue }
            annotations.append(annotation)
            if let view = attach(annotation) { addedViews.append(view) }
        }
        if !addedViews.isEmpty { onDidAdd?(addedViews) }
        updateSavedPlaceOverlap()
    }

    private func attach(_ annotation: MapAnnotation) -> MapAnnotationView? {
        guard let mapView,
              CLLocationCoordinate2DIsValid(annotation.coordinate),
              let view = makeView?(annotation) else { return nil }
        view.annotation = annotation
        let native = ViewAnnotation(coordinate: annotation.coordinate, view: view)
        native.allowOverlap = true
        // Social markers reserve space before saved-place icons and labels.
        native.priority = annotation is SavedPlaceAnnotation ? -1 : 0
        native.allowOverlapWithPuck = true
        native.ignoreCameraPadding = true
        let key = ObjectIdentifier(annotation)
        entries[key] = Entry(view: view, native: native, coordinate: annotation.coordinate)
        native.onVisibilityChanged = { [weak self] _ in self?.scheduleSavedPlaceOverlapUpdate() }
        native.onFrameChanged = { [weak self] _ in self?.scheduleSavedPlaceOverlapUpdate() }
        view.onGeometryChange = { [weak self] in self?.updateGeometry(for: key) }
        view.onActivate = { [weak self, weak annotation] in
            guard let self, let annotation else { return }
            self.selectAnnotation(annotation, animated: true)
        }
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapAnnotation(_:)))
        tap.delegate = self
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        updateGeometry(for: key)
        mapView.viewAnnotations.add(native)
        return view
    }

    private func updateGeometry(for key: ObjectIdentifier) {
        guard let entry = entries[key] else { return }
        entry.native.variableAnchors = [ViewAnnotationAnchorConfig(
            anchor: .center,
            offsetX: entry.view.centerOffset.width,
            offsetY: -entry.view.centerOffset.height
        )]
        entry.native.setNeedsUpdateSize()
        scheduleSavedPlaceOverlapUpdate()
    }

    func removeAnnotation(_ annotation: MapAnnotation) {
        removeAnnotations([annotation])
    }

    func removeAnnotations(_ removals: [MapAnnotation]) {
        let removedIDs = Set(removals.map(ObjectIdentifier.init))
        annotations.removeAll { removedIDs.contains(ObjectIdentifier($0)) }
        for annotation in removals {
            let key = ObjectIdentifier(annotation)
            deselectAnnotation(annotation, animated: false)
            guard let entry = entries.removeValue(forKey: key) else { continue }
            entry.view.onActivate = nil
            entry.view.onGeometryChange = nil
            entry.native.remove()
            entry.view.prepareForReuse()
        }
        updateSavedPlaceOverlap()
    }

    func selectAnnotation(_ annotation: MapAnnotation, animated: Bool) {
        guard annotations.contains(where: { $0 === annotation }),
              let entry = entries[ObjectIdentifier(annotation)],
              !selectedAnnotations.contains(where: { $0 === annotation }) else { return }
        for previous in selectedAnnotations {
            deselectAnnotation(previous, animated: animated)
        }
        // Deselect callbacks can detach or replace a pending annotation.
        guard entries[ObjectIdentifier(annotation)]?.view === entry.view else { return }
        selectedAnnotations = [annotation]
        entry.native.priority = 1
        entry.view.setSelected(true, animated: animated)
        updateSavedPlaceOverlap()
        onSelect?(entry.view)
    }

    func deselectAnnotation(_ annotation: MapAnnotation, animated: Bool) {
        guard selectedAnnotations.contains(where: { $0 === annotation }) else { return }
        selectedAnnotations.removeAll { $0 === annotation }
        guard let entry = entries[ObjectIdentifier(annotation)] else { return }
        entry.native.priority = annotation is SavedPlaceAnnotation ? -1 : 0
        entry.view.setSelected(false, animated: animated)
        updateSavedPlaceOverlap()
        onDeselect?(entry.view)
    }

    func synchronizeCoordinates() {
        var addedViews: [MapAnnotationView] = []
        for annotation in annotations {
            let key = ObjectIdentifier(annotation)
            guard var entry = entries[key] else {
                if let view = attach(annotation) { addedViews.append(view) }
                continue
            }
            let coordinate = annotation.coordinate
            let isValid = CLLocationCoordinate2DIsValid(coordinate)
            if !(annotation is SavedPlaceAnnotation) || !isValid {
                entry.native.visible = isValid
            }
            guard isValid,
                  coordinate.latitude != entry.coordinate.latitude
                    || coordinate.longitude != entry.coordinate.longitude else { continue }
            entry.native.annotatedFeature = .geometry(Point(coordinate))
            entry.coordinate = coordinate
            entries[key] = entry
        }
        if !addedViews.isEmpty { onDidAdd?(addedViews) }
        updateSavedPlaceOverlap()
    }

    private func scheduleSavedPlaceOverlapUpdate() {
        guard !overlapUpdateScheduled else { return }
        overlapUpdateScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.overlapUpdateScheduled = false
            self.updateSavedPlaceOverlap()
        }
    }

    func updateSavedPlaceOverlap() {
        guard let mapView else { return }
        let places = annotations.compactMap { $0 as? SavedPlaceAnnotation }.sorted {
            let leftSelected = view(for: $0)?.isSelected == true
            let rightSelected = view(for: $1)?.isSelected == true
            if leftSelected != rightSelected { return leftSelected }
            if $0.sourceID != $1.sourceID { return $0.sourceID < $1.sourceID }
            return $0.placeID < $1.placeID
        }
        guard !places.isEmpty else { return }

        let zoom = mapView.mapboxMap.cameraState.zoom
        let moving = mapView.mapboxMap.isGestureInProgress || mapView.mapboxMap.isAnimationInProgress
        if !moving || zoom > (previousOverlapZoom ?? zoom) + 0.000001 {
            isOverlapZoomingOut = false
            zoomOutHiddenIcons.removeAll()
            zoomOutHiddenLabels.removeAll()
        } else if zoom < (previousOverlapZoom ?? zoom) - 0.000001, !isOverlapZoomingOut {
            isOverlapZoomingOut = true
            zoomOutHiddenIcons = lastHiddenIcons
            zoomOutHiddenLabels = lastHiddenLabels
        }
        previousOverlapZoom = zoom

        func frame(for annotation: MapAnnotation, view: MapAnnotationView) -> CGRect? {
            guard CLLocationCoordinate2DIsValid(annotation.coordinate) else { return nil }
            let point = mapView.mapboxMap.point(for: annotation.coordinate)
            // Mapbox returns (-1, -1) for an offscreen coordinate, not its projected position.
            guard point.x.isFinite, point.y.isFinite, mapView.bounds.contains(point) else { return nil }
            let rect = CGRect(x: point.x + view.centerOffset.width - view.bounds.width / 2,
                              y: point.y + view.centerOffset.height - view.bounds.height / 2,
                              width: view.bounds.width, height: view.bounds.height)
            return rect.intersects(mapView.bounds) ? rect : nil
        }

        let socialRects: [CGRect] = annotations.compactMap { annotation in
            guard !(annotation is SavedPlaceAnnotation),
                  let view = view(for: annotation), !view.isHidden else { return nil }
            return frame(for: annotation, view: view)
        }
        var occupiedIcons = socialRects
        var visiblePlaces: [(id: ObjectIdentifier, view: SavedPlaceAnnotationView, origin: CGPoint, icon: CGRect)] = []
        lastHiddenIcons.removeAll()
        lastHiddenLabels.removeAll()
        for (index, place) in places.enumerated() {
            let id = ObjectIdentifier(place)
            guard let entry = entries[id], let pin = entry.view as? SavedPlaceAnnotationView else { continue }
            let selected = entry.view.isSelected
            let priority = selected ? 1 : -index - 1
            if entry.native.priority != priority { entry.native.priority = priority }
            guard CLLocationCoordinate2DIsValid(place.coordinate) else {
                if entry.native.visible { entry.native.visible = false }
                continue
            }
            let point = mapView.mapboxMap.point(for: place.coordinate)
            guard point.x.isFinite, point.y.isFinite,
                  mapView.bounds.contains(point) else {
                if entry.native.visible { entry.native.visible = false }
                continue
            }
            let origin = CGPoint(x: point.x - 22, y: point.y - 22)
            // Collisions use the 36 pt visual circle, not its larger touch target or name.
            let icon = CGRect(x: origin.x + 4, y: origin.y + 4, width: 36, height: 36)
            // A small release margin prevents visibility toggling around a collision boundary.
            let collisionRect = entry.native.visible ? icon : icon.insetBy(dx: -4, dy: -4)
            let visible = selected || (!zoomOutHiddenIcons.contains(id)
                && !occupiedIcons.contains { $0.intersects(collisionRect) })
            if entry.native.visible != visible { entry.native.visible = visible }
            if visible {
                occupiedIcons.append(icon)
                visiblePlaces.append((id, pin, origin, icon))
            } else {
                lastHiddenIcons.insert(id)
                if isOverlapZoomingOut { zoomOutHiddenIcons.insert(id) }
                pin.setLabelsOccluded(true)
            }
        }

        var occupiedLabels: [CGRect] = []
        for candidate in visiblePlaces {
            let pin = candidate.view
            let rect = pin.labelCollisionRect.offsetBy(dx: candidate.origin.x, dy: candidate.origin.y)
            let collisionRect = pin.showsLabels ? rect : rect.insetBy(dx: -2, dy: -2)
            let show = pin.labelsAllowed && (!zoomOutHiddenLabels.contains(candidate.id) || pin.isSelected)
                && !socialRects.contains { $0.intersects(collisionRect) }
                && !visiblePlaces.contains { $0.id != candidate.id && $0.icon.intersects(collisionRect) }
                && !occupiedLabels.contains { $0.intersects(collisionRect) }
            pin.setLabelsOccluded(!show)
            if show {
                occupiedLabels.append(rect)
            } else if pin.labelsAllowed {
                lastHiddenLabels.insert(candidate.id)
                if isOverlapZoomingOut { zoomOutHiddenLabels.insert(candidate.id) }
            }
        }
    }

    func removeAll() {
        removeAnnotations(annotations)
    }

    @objc private func didTapAnnotation(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended,
              let view = recognizer.view as? MapAnnotationView,
              let annotation = view.annotation else { return }
        selectAnnotation(annotation, animated: true)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var touchedView = touch.view
        while let view = touchedView, view !== gestureRecognizer.view {
            if view is UIControl { return false }
            touchedView = view.superview
        }
        return true
    }
}
