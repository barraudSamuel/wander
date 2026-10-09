import MapboxMaps
import QuartzCore
import UIKit

/// Owns one-finger zooming without changing Mapbox's built-in gesture delegates.
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
        private let initialCamera: CameraState
        let anchor: CLLocationCoordinate2D?
        private let focusCoordinate: CLLocationCoordinate2D

        init(camera: CameraState, target: Target?, focusCoordinate: CLLocationCoordinate2D? = nil) {
            initialCamera = camera
            anchor = target?.coordinate
            self.focusCoordinate = focusCoordinate ?? camera.center
        }

        func camera(at zoom: CGFloat, focusProgress: Double = 1) -> CameraOptions {
            var camera = CameraOptions(
                center: initialCamera.center, padding: initialCamera.padding,
                zoom: initialCamera.zoom, bearing: initialCamera.bearing, pitch: initialCamera.pitch
            )
            guard zoom.isFinite, initialCamera.zoom.isFinite else { return camera }
            if let anchor {
                let progress = max(0, min(1, focusProgress))
                let origin = MapEdgeZoomController.anchoredCenter(
                    initial: anchor, anchor: focusCoordinate, scale: 1 - progress
                )
                camera.center = MapEdgeZoomController.anchoredCenter(
                    initial: initialCamera.center,
                    anchor: anchor,
                    scale: pow(2, Double(initialCamera.zoom - zoom)),
                    offsetOrigin: origin
                )
            }
            camera.zoom = zoom
            return camera
        }
    }

    private weak var viewport: MapViewportView?
    private let onBegin: () -> Void
    private let targets: (MapboxMaps.MapView) -> [Target]
    private let onFocus: @MainActor () -> Void
    private let feedback = MapEdgeZoomFeedbackView()
    private let pan = UIPanGestureRecognizer()
    private var edge: Edge?
    private var session: ZoomSession?
    private var isZoomingIn: Bool?
    private var previousTranslationY: CGFloat = 0
    private var pendingTranslationY: CGFloat = 0
    private var focusStartedAt: CFTimeInterval = 0
    private var focusDisplayLink: CADisplayLink?
    private var finishesAfterFocus = false
    private static let focusDuration: CFTimeInterval = 0.18

    var isActive: Bool { session != nil }

    init(
        viewport: MapViewportView,
        targets: @escaping (MapboxMaps.MapView) -> [Target] = { _ in [] },
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
        let width = min(CGFloat(44), bounds.width / 2)
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
        if let offsetOrigin, !CLLocationCoordinate2DIsValid(offsetOrigin) { return initial }
        if scale == 0 { return anchor }
        if scale == 1 && offsetOrigin == nil { return initial }
        let latitudeLimit = 85.0511287798066
        func project(_ coordinate: CLLocationCoordinate2D) -> (x: Double, y: Double) {
            let latitude = max(-latitudeLimit, min(latitudeLimit, coordinate.latitude)) * .pi / 180
            return ((coordinate.longitude + 180) / 360, (1 - asinh(tan(latitude)) / .pi) / 2)
        }
        let center = project(initial)
        let pivot = project(anchor)
        let origin = project(offsetOrigin ?? anchor)
        // Use the nearest world copy so a target across ±180° never crosses the globe.
        var deltaX = (center.x - origin.x).truncatingRemainder(dividingBy: 1)
        if deltaX > 0.5 { deltaX -= 1 }
        if deltaX < -0.5 { deltaX += 1 }
        var x = (pivot.x + deltaX * scale).truncatingRemainder(dividingBy: 1)
        if x < 0 { x += 1 }
        let y = max(0, min(1, pivot.y + (center.y - origin.y) * scale))
        return CLLocationCoordinate2D(latitude: atan(sinh(.pi * (1 - 2 * y))) * 180 / .pi,
                                      longitude: x * 360 - 180)
    }

    static func acceleratedTranslation(_ translationY: CGFloat, velocityY: CGFloat) -> CGFloat {
        guard translationY.isFinite else { return 0 }
        guard velocityY.isFinite else { return translationY }
        // Preserve precise slow gestures; smoothly reach the capped gain at 900 pt/s.
        let progress = max(0, min(1, (abs(velocityY) - 100) / 800))
        let gain = 1 + 2 * progress * progress * (3 - 2 * progress)
        return translationY * gain
    }

    static func zoom(
        from zoom: CGFloat,
        translationY: CGFloat,
        minimum: CGFloat = 0,
        maximum: CGFloat = 22
    ) -> CGFloat {
        guard zoom.isFinite, translationY.isFinite else { return zoom }
        // Each 150 weighted points changes one zoom level, halving or doubling the scale.
        return max(minimum, min(maximum, zoom - translationY / 150))
    }

    static func excludesTouch(on view: UIView?, mapView: MapboxMaps.MapView) -> Bool {
        var candidate = view
        while let current = candidate, current !== mapView {
            if current is UIControl || current is MapAnnotationView
                || current === mapView.ornaments.compassView
                || current === mapView.ornaments.scaleBarView
                || current === mapView.ornaments.logoView
                || current === mapView.ornaments.attributionButton
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

    func begin(on mapView: MapboxMaps.MapView) {
        stopFocusAnimation()
        finishesAfterFocus = false
        session = ZoomSession(camera: mapView.mapboxMap.cameraState, target: nil)
        isZoomingIn = nil
        previousTranslationY = 0
        pendingTranslationY = 0
        mapView.camera.cancelAnimations()
        onBegin()
    }

    private func startZoomPhase(on mapView: MapboxMaps.MapView, zoomingIn: Bool, at timestamp: CFTimeInterval) {
        stopFocusAnimation()
        // Drop any unrendered movement from the previous direction and keep the displayed camera.
        pendingTranslationY = 0
        isZoomingIn = zoomingIn
        guard zoomingIn else {
            session = ZoomSession(camera: mapView.mapboxMap.cameraState, target: nil)
            return
        }
        let bounds = viewport?.visibleSafeMapRect ?? .zero
        let target = Self.nearestTarget(in: targets(mapView), visibleBounds: bounds)
        let focusPoint = CGPoint(x: bounds.midX, y: bounds.midY)
        session = ZoomSession(
            camera: mapView.mapboxMap.cameraState,
            target: target,
            focusCoordinate: mapView.mapboxMap.coordinate(for: focusPoint)
        )
        focusStartedAt = timestamp
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

    private func update(on mapView: MapboxMaps.MapView) {
        guard session != nil, let edge else { return }
        move(on: mapView, translationY: pan.translation(in: mapView).y, velocityY: pan.velocity(in: mapView).y)
        mapView.bringSubviewToFront(feedback)
        feedback.show(at: pan.location(in: mapView), edge: edge, in: interactionBounds)
    }

    func move(
        on mapView: MapboxMaps.MapView,
        translationY: CGFloat,
        velocityY: CGFloat,
        at timestamp: CFTimeInterval = CACurrentMediaTime()
    ) {
        guard session != nil, translationY.isFinite else { return }
        let delta = translationY - previousTranslationY
        previousTranslationY = translationY
        guard delta != 0 else { return }
        let zoomingIn = delta < 0
        if isZoomingIn != zoomingIn {
            startZoomPhase(on: mapView, zoomingIn: zoomingIn, at: timestamp)
        }
        pendingTranslationY += Self.acceleratedTranslation(
            delta,
            velocityY: velocityY
        )
        // During focus, the display link is the only camera writer for each frame.
        if focusDisplayLink == nil { applyCamera(on: mapView, focusProgress: 1) }
    }

    private func applyCamera(on mapView: MapboxMaps.MapView, focusProgress: Double) {
        guard let session else { return }
        let bounds = mapView.mapboxMap.cameraBounds
        let zoom = Self.zoom(
            from: mapView.mapboxMap.cameraState.zoom,
            translationY: pendingTranslationY,
            minimum: bounds.minZoom,
            maximum: bounds.maxZoom
        )
        pendingTranslationY = 0
        mapView.mapboxMap.setCamera(to: session.camera(at: zoom, focusProgress: focusProgress))
    }

    private func finish() {
        stopFocusAnimation()
        finishesAfterFocus = false
        session = nil
        isZoomingIn = nil
        edge = nil
        previousTranslationY = 0
        pendingTranslationY = 0
        feedback.dismiss()
    }
}
