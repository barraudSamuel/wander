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
    }

    private func attach(_ annotation: MapAnnotation) -> MapAnnotationView? {
        guard let mapView,
              CLLocationCoordinate2DIsValid(annotation.coordinate),
              let view = makeView?(annotation) else { return nil }
        view.annotation = annotation
        let native = ViewAnnotation(coordinate: annotation.coordinate, view: view)
        native.allowOverlap = true
        native.allowOverlapWithPuck = true
        native.ignoreCameraPadding = true
        let key = ObjectIdentifier(annotation)
        entries[key] = Entry(view: view, native: native, coordinate: annotation.coordinate)
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
        onSelect?(entry.view)
    }

    func deselectAnnotation(_ annotation: MapAnnotation, animated: Bool) {
        guard selectedAnnotations.contains(where: { $0 === annotation }) else { return }
        selectedAnnotations.removeAll { $0 === annotation }
        guard let entry = entries[ObjectIdentifier(annotation)] else { return }
        entry.native.priority = 0
        entry.view.setSelected(false, animated: animated)
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
            entry.native.visible = isValid
            guard isValid,
                  coordinate.latitude != entry.coordinate.latitude
                    || coordinate.longitude != entry.coordinate.longitude else { continue }
            entry.native.annotatedFeature = .geometry(Point(coordinate))
            entry.coordinate = coordinate
            entries[key] = entry
        }
        if !addedViews.isEmpty { onDidAdd?(addedViews) }
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
