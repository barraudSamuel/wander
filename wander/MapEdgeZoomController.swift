import MapKit

/// Owns one-finger zooming without changing MapKit's built-in gesture delegates.
@MainActor
final class MapEdgeZoomController: NSObject, UIGestureRecognizerDelegate {
    enum Edge {
        case left
        case right
    }

    struct Target {
        let id: String
        let coordinate: CLLocationCoordinate2D
        let screenPoint: CGPoint
    }

    /// Value snapshots prevent a moving friend or regrouping from changing the pivot.
    struct ZoomSession {
        private let initialCamera: MKMapCamera
        let anchor: CLLocationCoordinate2D?
        private let focusCoordinate: CLLocationCoordinate2D

        init(camera: MKMapCamera, target: Target?, focusCoordinate: CLLocationCoordinate2D? = nil) {
            initialCamera = camera.copy() as! MKMapCamera
            anchor = target?.coordinate
            self.focusCoordinate = focusCoordinate ?? camera.centerCoordinate
        }

        func camera(at distance: CLLocationDistance, focusProgress: Double = 1) -> MKMapCamera {
            let camera = initialCamera.copy() as! MKMapCamera
            guard distance.isFinite, distance > 0,
                  initialCamera.centerCoordinateDistance > 0 else { return camera }
            if let anchor {
                let progress = max(0, min(1, focusProgress))
                let origin = MapEdgeZoomController.anchoredCenter(
                    initial: anchor, anchor: focusCoordinate, scale: 1 - progress
                )
                camera.centerCoordinate = MapEdgeZoomController.anchoredCenter(
                    initial: initialCamera.centerCoordinate,
                    anchor: anchor,
                    scale: distance / initialCamera.centerCoordinateDistance,
                    offsetOrigin: origin
                )
            }
            camera.centerCoordinateDistance = distance
            return camera
        }
    }

    private weak var viewport: MapViewportView?
    private let onBegin: () -> Void
    private let targets: (MKMapView) -> [Target]
    private let onFocus: @MainActor () -> Void
    private let feedback = MapEdgeZoomFeedbackView()
    private let pan = UIPanGestureRecognizer()
    private var edge: Edge?
    private var session: ZoomSession?
    private var previousTranslationY: CGFloat = 0
    private var pendingTranslationY: CGFloat = 0
    private var focusStartedAt: CFTimeInterval = 0
    private var focusDisplayLink: CADisplayLink?
    private var finishesAfterFocus = false
    private static let focusDuration: CFTimeInterval = 0.18

    var isActive: Bool { session != nil }

    init(
        viewport: MapViewportView,
        targets: @escaping (MKMapView) -> [Target] = { _ in [] },
        onFocus: @escaping @MainActor () -> Void = {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        },
        onBegin: @escaping () -> Void
    ) {
        self.viewport = viewport
        self.targets = targets
        self.onFocus = onFocus
        self.onBegin = onBegin
        super.init()
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        pan.cancelsTouchesInView = true
        pan.delegate = self
        pan.addTarget(self, action: #selector(handlePan(_:)))
        viewport.mapView.addGestureRecognizer(pan)
        viewport.mapView.addSubview(feedback)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cancel),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }

    func uninstall() {
        cancel()
        pan.view?.removeGestureRecognizer(pan)
        feedback.removeFromSuperview()
        NotificationCenter.default.removeObserver(self)
    }

    /// A resized viewport changes both the touch coordinates and its visible edges.
    @objc func cancel() {
        pan.isEnabled = false
        finish()
        pan.isEnabled = true
    }

    func owns(_ recognizer: UIGestureRecognizer) -> Bool {
        recognizer === pan
    }

    private var interactionBounds: CGRect {
        guard let viewport else { return .zero }
        let visible = viewport.visibleMapRect
        let safe = viewport.visibleSafeMapRect
        return CGRect(x: visible.minX, y: safe.minY, width: visible.width, height: safe.height)
    }

    static func edge(at point: CGPoint, in bounds: CGRect) -> Edge? {
        guard !bounds.isEmpty, bounds.contains(point) else { return nil }
        let width = min(CGFloat(28), bounds.width / 2)
        if point.x <= bounds.minX + width { return .left }
        if point.x >= bounds.maxX - width { return .right }
        return nil
    }

    static func isVertical(_ translation: CGPoint) -> Bool {
        abs(translation.y) > abs(translation.x) * 1.25
    }

    static func nearestTarget(in targets: [Target], visibleBounds: CGRect) -> Target? {
        guard !visibleBounds.isEmpty, !visibleBounds.isInfinite else { return nil }
        let center = CGPoint(x: visibleBounds.midX, y: visibleBounds.midY)
        var nearest: Target?
        var nearestDistance = CGFloat.infinity
        for target in targets {
            guard CLLocationCoordinate2DIsValid(target.coordinate),
                  target.screenPoint.x.isFinite, target.screenPoint.y.isFinite,
                  visibleBounds.contains(target.screenPoint) else { continue }
            let distance = hypot(target.screenPoint.x - center.x, target.screenPoint.y - center.y)
            if distance < nearestDistance
                || (distance == nearestDistance && target.id < (nearest?.id ?? target.id)) {
                nearest = target
                nearestDistance = distance
            }
        }
        return nearest
    }

    static func anchoredCenter(
        initial: CLLocationCoordinate2D,
        anchor: CLLocationCoordinate2D,
        scale: Double,
        offsetOrigin: CLLocationCoordinate2D? = nil
    ) -> CLLocationCoordinate2D {
        guard CLLocationCoordinate2DIsValid(initial), CLLocationCoordinate2DIsValid(anchor),
              scale.isFinite, scale >= 0 else { return initial }
        if scale == 0 { return anchor }
        if scale == 1 && offsetOrigin == nil { return initial }
        let center = MKMapPoint(initial)
        let pivot = MKMapPoint(anchor)
        let origin = MKMapPoint(offsetOrigin ?? anchor)
        guard center.x.isFinite, center.y.isFinite, pivot.x.isFinite, pivot.y.isFinite,
              origin.x.isFinite, origin.y.isFinite else {
            return initial
        }
        let world = MKMapRect.world
        // Use the nearest world copy so a target across ±180° never crosses the globe.
        var deltaX = (center.x - origin.x).truncatingRemainder(dividingBy: world.width)
        if deltaX > world.width / 2 { deltaX -= world.width }
        if deltaX < -world.width / 2 { deltaX += world.width }
        var x = (pivot.x + deltaX * scale).truncatingRemainder(dividingBy: world.width)
        if x < 0 { x += world.width }
        let y = max(world.minY, min(world.maxY, pivot.y + (center.y - origin.y) * scale))
        return MKMapPoint(x: x, y: y).coordinate
    }

    static func distance(
        from distance: CLLocationDistance,
        translationY: CGFloat,
        minimum: CLLocationDistance = 80,
        maximum: CLLocationDistance = 30_000_000
    ) -> CLLocationDistance {
        guard distance.isFinite, distance > 0, translationY.isFinite else { return distance }
        // MapKit returns -1 for each default limit, even when the range is non-nil.
        let lowerBound = minimum == MKMapCameraZoomDefault ? 80 : minimum
        let upperBound = maximum == MKMapCameraZoomDefault ? 30_000_000 : maximum
        // Each 150 points doubles or halves the distance, at every zoom level.
        let exponent = max(-20, min(20, Double(translationY) / 150))
        return max(lowerBound, min(upperBound, distance * pow(2, exponent)))
    }

    static func excludesTouch(on view: UIView?, mapView: MKMapView) -> Bool {
        var candidate = view
        while let current = candidate, current !== mapView {
            if current is UIControl || current is MKAnnotationView
                || current is MKCompassButton || current is MKScaleView
                || current.accessibilityTraits.contains(.button) {
                return true
            }
            candidate = current.superview
        }
        return false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let mapView = viewport?.mapView else { return false }
        // Accept a second touch so maximumNumberOfTouches can cancel this pan.
        if pan.numberOfTouches > 0 { return true }
        if finishesAfterFocus { finish() }
        edge = nil
        guard !Self.excludesTouch(on: touch.view, mapView: mapView) else { return false }
        edge = Self.edge(at: touch.location(in: mapView), in: interactionBounds)
        return edge != nil
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        edge != nil && pan.numberOfTouches == 1 && Self.isVertical(pan.translation(in: pan.view))
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        guard let mapView = viewport?.mapView,
              let otherView = otherGestureRecognizer.view,
              otherView === mapView || otherView.isDescendant(of: mapView),
              !Self.excludesTouch(on: otherView, mapView: mapView),
              !(otherGestureRecognizer is UIScreenEdgePanGestureRecognizer) else { return false }
        // Native panning waits for the edge/direction decision, not vice versa.
        return otherGestureRecognizer is UIPanGestureRecognizer
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        false
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard let mapView = viewport?.mapView else { return }
        switch recognizer.state {
        case .began:
            begin(on: mapView)
            update(on: mapView)
        case .changed:
            update(on: mapView)
        case .ended:
            update(on: mapView)
            end()
        case .cancelled, .failed:
            finish()
        default:
            break
        }
    }

    func begin(on mapView: MKMapView, at timestamp: CFTimeInterval = CACurrentMediaTime()) {
        stopFocusAnimation()
        finishesAfterFocus = false
        let bounds = viewport?.visibleSafeMapRect ?? .zero
        let target = Self.nearestTarget(in: targets(mapView), visibleBounds: bounds)
        let focusPoint = CGPoint(x: bounds.midX, y: bounds.midY)
        session = ZoomSession(
            camera: mapView.camera,
            target: target,
            focusCoordinate: mapView.convert(focusPoint, toCoordinateFrom: mapView)
        )
        previousTranslationY = 0
        pendingTranslationY = 0
        focusStartedAt = timestamp
        onBegin()
        if target != nil {
            onFocus()
            if !UIAccessibility.isReduceMotionEnabled {
                let link = CADisplayLink(target: self, selector: #selector(handleFocusFrame))
                focusDisplayLink = link
                link.add(to: .main, forMode: .common)
            }
        }
    }

    func end() {
        if focusDisplayLink != nil {
            // Complete a quick swipe's focus without snapping at finger lift.
            finishesAfterFocus = true
            feedback.dismiss()
        } else {
            finish()
        }
    }

    private func focusProgress(at timestamp: CFTimeInterval) -> Double {
        guard focusDisplayLink != nil else { return 1 }
        let progress = max(0, min(1, (timestamp - focusStartedAt) / Self.focusDuration))
        return progress * progress * (3 - 2 * progress)
    }

    @objc private func handleFocusFrame() {
        advanceFocus(at: CACurrentMediaTime())
    }

    func advanceFocus(at timestamp: CFTimeInterval) {
        guard focusDisplayLink != nil else { return }
        guard let mapView = viewport?.mapView, session != nil else {
            stopFocusAnimation()
            return
        }
        let progress = focusProgress(at: timestamp)
        applyCamera(on: mapView, focusProgress: progress)
        if progress >= 1 {
            stopFocusAnimation()
            if finishesAfterFocus { finish() }
        }
    }

    private func stopFocusAnimation() {
        focusDisplayLink?.invalidate()
        focusDisplayLink = nil
    }

    private func update(on mapView: MKMapView) {
        guard session != nil, let edge else { return }
        let translationY = pan.translation(in: mapView).y
        pendingTranslationY += translationY - previousTranslationY
        previousTranslationY = translationY
        // During focus, the display link is the only camera writer for each frame.
        if focusDisplayLink == nil { applyCamera(on: mapView, focusProgress: 1) }
        mapView.bringSubviewToFront(feedback)
        feedback.show(at: pan.location(in: mapView), edge: edge, in: interactionBounds)
    }

    private func applyCamera(on mapView: MKMapView, focusProgress: Double) {
        guard let session else { return }
        let distance = Self.distance(
            from: mapView.camera.centerCoordinateDistance,
            translationY: pendingTranslationY,
            minimum: mapView.cameraZoomRange?.minCenterCoordinateDistance ?? 80,
            maximum: mapView.cameraZoomRange?.maxCenterCoordinateDistance ?? 30_000_000
        )
        pendingTranslationY = 0
        mapView.setCamera(session.camera(at: distance, focusProgress: focusProgress), animated: false)
    }

    private func finish() {
        stopFocusAnimation()
        finishesAfterFocus = false
        session = nil
        edge = nil
        previousTranslationY = 0
        pendingTranslationY = 0
        feedback.dismiss()
    }
}
