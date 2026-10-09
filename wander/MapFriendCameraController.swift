import MapboxMaps
import QuartzCore
import UIKit

/// Identifies a map profile independently of the account settings panel.
enum MapProfileSelection: Hashable, Identifiable {
    case currentUser
    case friend(String)

    var id: Self { self }

    var detailSelection: MapDetailSelection {
        switch self {
        case .currentUser: .ownProfile
        case .friend(let userID): .friend(userID)
        }
    }
}

/// A prepared opening target, or a recenter when closing a map profile.
struct MapFriendCameraRequest: Equatable {
    let id: UUID
    let target: MapProfileSelection
    let sheetTopInWindow: CGFloat?

    init(id: UUID = UUID(), target: MapProfileSelection, sheetTopInWindow: CGFloat? = nil) {
        self.id = id
        self.target = target
        self.sheetTopInWindow = sheetTopInWindow
    }
}

/// Performs one focus per request, without following sheet resizing.
@MainActor
final class MapFriendCameraController {
    // Avoid synthesized isolated deinit on older Swift runtimes (swiftlang/swift#88036).
    // Animation cleanup remains in cancel() on the main actor.
    nonisolated deinit {}

    struct Session {
        private let initialCamera: CameraState
        private let focusCoordinate: CLLocationCoordinate2D
        private let target: CLLocationCoordinate2D

        init?(camera: CameraState, focusCoordinate: CLLocationCoordinate2D,
              target: CLLocationCoordinate2D) {
            guard CLLocationCoordinate2DIsValid(camera.center),
                  CLLocationCoordinate2DIsValid(focusCoordinate),
                  CLLocationCoordinate2DIsValid(target),
                  camera.zoom.isFinite, camera.bearing.isFinite, camera.pitch.isFinite else { return nil }
            initialCamera = camera
            self.focusCoordinate = focusCoordinate
            self.target = target
        }

        func camera(at progress: Double) -> CameraOptions {
            var camera = CameraOptions(
                center: initialCamera.center, padding: initialCamera.padding,
                zoom: initialCamera.zoom, bearing: initialCamera.bearing, pitch: initialCamera.pitch
            )
            guard progress.isFinite, progress > 0 else { return camera }
            let focus = MapEdgeZoomController.anchoredCenter(
                initial: focusCoordinate, anchor: target, scale: 1 - min(1, progress)
            )
            // Translate the point underneath the visible area's center to the friend.
            // The focus coordinate comes from Mapbox at the current bearing and pitch.
            camera.center = MapEdgeZoomController.anchoredCenter(
                initial: initialCamera.center, anchor: focus,
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
                camera: mapView.mapboxMap.cameraState,
                focusCoordinate: mapView.mapboxMap.coordinate(for: point),
                target: coordinate
              ) else { return }

        mapView.camera.cancelAnimations()
        if UIAccessibility.isReduceMotionEnabled {
            mapView.mapboxMap.setCamera(to: session.camera(at: 1))
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
        mapView.mapboxMap.setCamera(to: session.camera(at: eased))
        if progress >= 1 { cancel() }
    }

    static func focusPoint(in safeRect: CGRect, sheetTop: CGFloat? = nil) -> CGPoint? {
        guard safeRect.origin.x.isFinite, safeRect.origin.y.isFinite,
              safeRect.width.isFinite, safeRect.height.isFinite,
              !safeRect.isEmpty, !safeRect.isInfinite else { return nil }
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
