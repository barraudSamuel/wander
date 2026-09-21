import MapKit

/// A prepared opening target, or a recenter when closing the profile.
struct MapFriendCameraRequest: Equatable {
    let id: UUID
    let userID: String
    let sheetTopInWindow: CGFloat?

    init(id: UUID = UUID(), userID: String, sheetTopInWindow: CGFloat? = nil) {
        self.id = id
        self.userID = userID
        self.sheetTopInWindow = sheetTopInWindow
    }
}

/// Performs one focus per request, without following sheet resizing.
@MainActor
final class MapFriendCameraController {
    struct Session {
        private let initialCamera: MKMapCamera
        private let focusCoordinate: CLLocationCoordinate2D
        private let target: CLLocationCoordinate2D

        init?(camera: MKMapCamera, focusCoordinate: CLLocationCoordinate2D,
              target: CLLocationCoordinate2D) {
            guard CLLocationCoordinate2DIsValid(camera.centerCoordinate),
                  CLLocationCoordinate2DIsValid(focusCoordinate),
                  CLLocationCoordinate2DIsValid(target),
                  camera.centerCoordinateDistance.isFinite,
                  camera.centerCoordinateDistance > 0,
                  camera.heading.isFinite, camera.pitch.isFinite else { return nil }
            initialCamera = camera.copy() as! MKMapCamera
            self.focusCoordinate = focusCoordinate
            self.target = target
        }

        func camera(at progress: Double) -> MKMapCamera {
            let camera = initialCamera.copy() as! MKMapCamera
            guard progress.isFinite, progress > 0 else { return camera }
            let focus = MapEdgeZoomController.anchoredCenter(
                initial: focusCoordinate, anchor: target, scale: 1 - min(1, progress)
            )
            // Translate the point underneath the visible area's center to the friend.
            // This uses MapKit's projection, including the current heading and pitch.
            camera.centerCoordinate = MapEdgeZoomController.anchoredCenter(
                initial: initialCamera.centerCoordinate, anchor: focus,
                scale: 1, offsetOrigin: focusCoordinate
            )
            return camera
        }
    }

    private final class DisplayLinkTarget: NSObject {
        weak var owner: MapFriendCameraController?

        init(owner: MapFriendCameraController) { self.owner = owner }

        @objc func frame(_ link: CADisplayLink) {
            guard let owner else {
                link.invalidate()
                return
            }
            owner.advance(at: CACurrentMediaTime())
        }
    }

    private weak var viewport: MapViewportView?
    private var session: Session?
    private var displayLink: CADisplayLink?
    private var startedAt: CFTimeInterval = 0
    private(set) var lastRequestID: UUID?
    var isAnimating: Bool { session != nil }
    private static let duration: CFTimeInterval = 0.22

    func apply(_ request: MapFriendCameraRequest, coordinate: CLLocationCoordinate2D,
               viewport: MapViewportView) {
        guard request.id != lastRequestID else { return }
        cancel()
        // A cancelled or unusable request must not restart on a later SwiftUI update.
        lastRequestID = request.id
        let mapView = viewport.mapView
        guard let window = mapView.window,
              CLLocationCoordinate2DIsValid(coordinate) else { return }
        let sheetTop = request.sheetTopInWindow.map {
            mapView.convert(CGPoint(x: window.bounds.midX, y: $0), from: window).y
        }
        guard let point = Self.focusPoint(in: viewport.visibleSafeMapRect, sheetTop: sheetTop),
              let session = Session(
                camera: mapView.camera,
                focusCoordinate: mapView.convert(point, toCoordinateFrom: mapView),
                target: coordinate
              ) else { return }

        if UIAccessibility.isReduceMotionEnabled {
            mapView.setCamera(session.camera(at: 1), animated: false)
            return
        }
        self.viewport = viewport
        self.session = session
        startedAt = CACurrentMediaTime()
        let link = CADisplayLink(target: DisplayLinkTarget(owner: self),
                                 selector: #selector(DisplayLinkTarget.frame(_:)))
        displayLink = link
        link.add(to: .main, forMode: .common)
    }

    func cancel(consuming request: MapFriendCameraRequest? = nil) {
        if let request { lastRequestID = request.id }
        displayLink?.invalidate()
        displayLink = nil
        session = nil
        viewport = nil
    }

    private func advance(at timestamp: CFTimeInterval) {
        guard let mapView = viewport?.mapView, mapView.window != nil,
              let session else {
            cancel()
            return
        }
        let progress = max(0, min(1, (timestamp - startedAt) / Self.duration))
        let eased = progress * progress * (3 - 2 * progress)
        mapView.setCamera(session.camera(at: eased), animated: false)
        if progress >= 1 { cancel() }
    }

    static func focusPoint(in safeRect: CGRect, sheetTop: CGFloat? = nil) -> CGPoint? {
        guard safeRect.origin.x.isFinite, safeRect.origin.y.isFinite,
              safeRect.width.isFinite, safeRect.height.isFinite,
              !safeRect.isEmpty else { return nil }
        guard safeRect.width >= 96, safeRect.height >= 96 else { return nil }
        guard let sheetTop else { return CGPoint(x: safeRect.midX, y: safeRect.midY) }
        guard sheetTop.isFinite else { return nil }
        // The pin is 88 points tall. Keep its anchor away from both the safe top
        // and the sheet edge, including when only a narrow strip is uncovered.
        let bottom = min(safeRect.maxY, sheetTop - 16)
        let availableHeight = bottom - safeRect.minY
        guard availableHeight >= 112 else { return nil }
        let centered = safeRect.minY + availableHeight / 2
        return CGPoint(x: safeRect.midX, y: max(safeRect.minY + 96, centered))
    }
}
