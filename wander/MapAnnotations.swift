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
    var onActivateSavedPlace: ((SavedPlaceAnnotation) -> Void)?
    var onDeselect: ((MapAnnotationView) -> Void)?
    var onDidAdd: (([MapAnnotationView]) -> Void)?
    private(set) var annotations: [MapAnnotation] = []
    private(set) var selectedAnnotations: [MapAnnotation] = []

    private weak var mapView: MapboxMaps.MapView?
    private var entries: [ObjectIdentifier: Entry] = [:]
    private var presentationUpdateScheduled = false

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
        updateSavedPlacePresentation()
    }

    private func attach(_ annotation: MapAnnotation) -> MapAnnotationView? {
        guard let mapView,
              CLLocationCoordinate2DIsValid(annotation.coordinate),
              let view = makeView?(annotation) else { return nil }
        view.annotation = annotation
        let native = ViewAnnotation(coordinate: annotation.coordinate, view: view)
        native.allowOverlap = true
        // Saved places can overlap; social markers keep their own foreground layer.
        native.priority = annotation is SavedPlaceAnnotation ? -1 : 0
        native.allowOverlapWithPuck = true
        native.ignoreCameraPadding = true
        let key = ObjectIdentifier(annotation)
        entries[key] = Entry(view: view, native: native, coordinate: annotation.coordinate)
        native.onVisibilityChanged = { [weak self] _ in self?.scheduleSavedPlacePresentationUpdate() }
        native.onFrameChanged = { [weak self] _ in self?.scheduleSavedPlacePresentationUpdate() }
        view.onGeometryChange = { [weak self] in self?.updateGeometry(for: key) }
        view.onActivate = { [weak self, weak annotation] in
            guard let self, let annotation else { return }
            self.activateAnnotation(annotation)
        }
        (view as? SavedPlaceAnnotationView)?.onPresentationTransitionEnd = { [weak self] in
            self?.scheduleSavedPlacePresentationUpdate()
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
        scheduleSavedPlacePresentationUpdate()
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
        updateSavedPlacePresentation()
    }

    func activateAnnotation(_ annotation: MapAnnotation) {
        guard entries[ObjectIdentifier(annotation)] != nil else { return }
        if let place = annotation as? SavedPlaceAnnotation {
            onActivateSavedPlace?(place)
        } else {
            selectAnnotation(annotation, animated: true)
        }
    }

    func selectAnnotation(_ annotation: MapAnnotation, animated: Bool, notifySelection: Bool = true) {
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
        updateSavedPlacePresentation()
        if notifySelection { onSelect?(entry.view) }
    }

    func deselectAnnotation(_ annotation: MapAnnotation, animated: Bool) {
        guard selectedAnnotations.contains(where: { $0 === annotation }) else { return }
        selectedAnnotations.removeAll { $0 === annotation }
        guard let entry = entries[ObjectIdentifier(annotation)] else { return }
        entry.native.priority = annotation is SavedPlaceAnnotation ? -1 : 0
        entry.view.setSelected(false, animated: animated)
        updateSavedPlacePresentation()
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
        updateSavedPlacePresentation()
    }

    private func scheduleSavedPlacePresentationUpdate() {
        guard !presentationUpdateScheduled else { return }
        presentationUpdateScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.presentationUpdateScheduled = false
            self.updateSavedPlacePresentation()
        }
    }

    func updateSavedPlacePresentation() {
        guard let mapView else { return }
        let viewport = (mapView.superview as? MapViewportView)?.visibleMapRect ?? mapView.bounds
        var candidates: [SavedPlaceEmphasisLayout.Candidate] = []
        var places: [String: Entry] = [:]
        for annotation in annotations {
            guard let place = annotation as? SavedPlaceAnnotation,
                  let entry = entries[ObjectIdentifier(place)],
                  let pin = entry.view as? SavedPlaceAnnotationView else { continue }
            guard let point = projectedPoint(place, on: mapView) else {
                entry.native.visible = false
                continue
            }
            // Keep the visible part of a photo at a viewport edge. Native placement
            // owns the 44 pt host; the photo and category may extend beyond it.
            let compact = pin.geometry(forEmphasis: 0).visualRect.offsetBy(dx: point.x - 22, dy: point.y - 22)
            let drawn = pin.currentVisualRect.offsetBy(dx: point.x, dy: point.y)
            let visible = compact.intersects(viewport) || drawn.intersects(viewport)
            if entry.native.visible != visible { entry.native.visible = visible }
            guard visible else {
                pin.setMapEmphasis(0, animated: false)
                continue
            }
            candidates.append(.init(id: place.placeID, point: point, isSelected: pin.isSelected))
            places[place.placeID] = entry
        }
        let placements = SavedPlaceEmphasisLayout.resolve(candidates, viewport: viewport,
                                                         zoom: mapView.mapboxMap.cameraState.zoom)
        for placement in placements {
            guard let entry = places[placement.id], let pin = entry.view as? SavedPlaceAnnotationView else { continue }
            if entry.native.priority != placement.priority { entry.native.priority = placement.priority }
            pin.setMapEmphasis(placement.emphasis)
        }
    }

    private func projectedPoint(_ annotation: MapAnnotation, on mapView: MapboxMaps.MapView) -> CGPoint? {
        guard CLLocationCoordinate2DIsValid(annotation.coordinate) else { return nil }
        let point = mapView.mapboxMap.point(for: annotation.coordinate)
        // Mapbox's offscreen sentinel is not a coordinate near the upper-left corner.
        return point.x.isFinite && point.y.isFinite && point != CGPoint(x: -1, y: -1) ? point : nil
    }

    func removeAll() {
        removeAnnotations(annotations)
    }

    @objc private func didTapAnnotation(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended,
              let view = recognizer.view as? MapAnnotationView,
              let annotation = view.annotation else { return }
        if annotation is SavedPlaceAnnotation, let mapView,
           activateSavedPlace(at: recognizer.location(in: mapView)) { return }
        activateAnnotation(annotation)
    }

    /// Resolves the visible shape before the invisible minimum touch margin.
    /// Overlapping photos use the same foreground order as Mapbox placement.
    @discardableResult
    func activateSavedPlace(at point: CGPoint) -> Bool {
        guard let mapView else { return false }
        let hits = annotations.compactMap { annotation -> (place: SavedPlaceAnnotation, drawn: Bool, rank: Int, distance: CGFloat)? in
            guard let place = annotation as? SavedPlaceAnnotation,
                  let entry = entries[ObjectIdentifier(place)], entry.native.visible,
                  let pin = entry.view as? SavedPlaceAnnotationView, !pin.isHidden,
                  let anchor = projectedPoint(place, on: mapView) else { return nil }
            let local = CGPoint(x: point.x - anchor.x, y: point.y - anchor.y)
            guard pin.point(inside: CGPoint(x: local.x + 22, y: local.y + 22), with: nil) else { return nil }
            return (place, pin.containsRenderedPoint(local), entry.native.priority ?? -1,
                    hypot(local.x, local.y))
        }
        let front = hits.min { lhs, rhs in
            if lhs.drawn != rhs.drawn { return lhs.drawn }
            if lhs.drawn, lhs.rank != rhs.rank { return lhs.rank > rhs.rank }
            if lhs.distance != rhs.distance { return lhs.distance < rhs.distance }
            return lhs.place.placeID < rhs.place.placeID
        }
        guard let front else { return false }
        activateAnnotation(front.place)
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var touchedView = touch.view
        while let view = touchedView, view !== gestureRecognizer.view {
            if view is UIControl || view is UIScrollView { return false }
            touchedView = view.superview
        }
        return true
    }
}
