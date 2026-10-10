import MapboxMaps
import QuartzCore
import SwiftUI
import UIKit

private struct MapRenderSizeKey: EnvironmentKey {
    static let defaultValue: CGSize? = nil
}

private struct MapContentInsetsKey: EnvironmentKey {
    static let defaultValue = SwiftUI.EdgeInsets()
}

extension EnvironmentValues {
    var mapRenderSize: CGSize? {
        get { self[MapRenderSizeKey.self] }
        set { self[MapRenderSizeKey.self] = newValue }
    }

    var mapContentInsets: SwiftUI.EdgeInsets {
        get { self[MapContentInsetsKey.self] }
        set { self[MapContentInsetsKey.self] = newValue }
    }
}

/// Crops a stable Mapbox drawable while the surrounding detail pane resizes.
/// Keeping the map and viewport centers aligned preserves native camera gestures.
final class MapViewportView: UIView {
    let mapView: MapboxMaps.MapView
    var renderSize: CGSize? {
        didSet {
            if renderSize != oldValue { setNeedsLayout() }
        }
    }
    var contentInsets: UIEdgeInsets {
        didSet {
            if contentInsets != oldValue { setNeedsLayout() }
        }
    }
    private(set) var visibleMapRect = CGRect.zero
    private(set) var visibleSafeMapRect = CGRect.zero
    var onViewportChange: (() -> Void)?
    var tracksSheetPresentation = false {
        didSet {
            guard tracksSheetPresentation != oldValue else { return }
            if tracksSheetPresentation { startSheetTracking() }
            refreshPresentedSheet()
        }
    }
    private(set) var ornamentSafeMapRect = CGRect.zero
    private var sheetDisplayLink: CADisplayLink?

    private final class DisplayLinkTarget: NSObject {
        weak var viewport: MapViewportView?

        init(viewport: MapViewportView) { self.viewport = viewport }

        @objc func frame(_ link: CADisplayLink) {
            guard let viewport else {
                link.invalidate()
                return
            }
            viewport.refreshPresentedSheet()
        }
    }

    init(mapView: MapboxMaps.MapView, renderSize: CGSize?, contentInsets: UIEdgeInsets = .zero) {
        self.mapView = mapView
        self.renderSize = renderSize
        self.contentInsets = contentInsets
        super.init(frame: .zero)
        clipsToBounds = true
        accessibilityIdentifier = "map-visible-viewport"
        addSubview(mapView)
    }

    required init?(coder: NSCoder) { nil }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stopSheetTracking()
        } else if tracksSheetPresentation {
            startSheetTracking()
        }
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = renderSize ?? bounds.size
        guard size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0 else { return }

        // Keep the drawable size stable while detail panes change the visible window.
        if mapView.bounds.size != size {
            mapView.bounds.size = size
        }
        mapView.center = CGPoint(x: bounds.midX, y: bounds.midY)

        let visible = convert(bounds, to: mapView).intersection(mapView.bounds)
        let insets = UIEdgeInsets(
            top: max(safeAreaInsets.top, contentInsets.top),
            left: max(safeAreaInsets.left, contentInsets.left),
            bottom: max(safeAreaInsets.bottom, contentInsets.bottom),
            right: max(safeAreaInsets.right, contentInsets.right)
        )
        let safe = convert(bounds.inset(by: insets), to: mapView)
            .intersection(visible)
        let changed = visible != visibleMapRect || safe != visibleSafeMapRect
        visibleMapRect = visible
        visibleSafeMapRect = safe

        refreshPresentedSheet()
        if changed { onViewportChange?() }
    }

    func updateOrnaments(occludedBelow sheetTop: CGFloat? = nil) {
        // Bottom controls reserve camera space, but the corner ornaments can sit
        // below them. Keep the system home-indicator inset and sheet occlusion.
        let systemSafe = convert(bounds.inset(by: safeAreaInsets), to: mapView)
            .intersection(visibleMapRect)
        let safe = CGRect(x: visibleSafeMapRect.minX, y: visibleSafeMapRect.minY,
                          width: visibleSafeMapRect.width,
                          height: max(0, systemSafe.maxY - visibleSafeMapRect.minY))
        guard !safe.isEmpty, !safe.isInfinite else { return }
        let bottomEdge = sheetTop.map { min(safe.maxY, max(safe.minY, $0)) } ?? safe.maxY
        ornamentSafeMapRect = CGRect(x: safe.minX, y: safe.minY,
                                     width: safe.width, height: bottomEdge - safe.minY)
        // A sheet changes only ornament placement, never map gestures or camera framing.
        let mapSafe = mapView.safeAreaInsets
        let left = max(0, safe.minX - mapView.bounds.minX - mapSafe.left) + 8
        // A large sheet can leave less room than the buttons need. Keep them
        // inside the map safe area; the sheet covers them until space reopens.
        let controlHeight = max(32, max(mapView.ornaments.logoView.bounds.height,
                                        mapView.ornaments.attributionButton.bounds.height))
        let controlsBottom = max(bottomEdge, min(safe.maxY, safe.minY + controlHeight + 16))
        let bottom = max(0, mapView.bounds.maxY - controlsBottom - mapSafe.bottom) + 8
        let right = max(0, mapView.bounds.maxX - safe.maxX - mapSafe.right) + 8
        var ornaments = mapView.ornaments.options
        ornaments.compass.visibility = .hidden
        ornaments.scaleBar.visibility = .hidden
        ornaments.logo.position = .bottomLeft
        ornaments.logo.margins = CGPoint(x: left, y: bottom)
        ornaments.attributionButton.position = .bottomRight
        ornaments.attributionButton.margins = CGPoint(x: right, y: bottom)
        if mapView.ornaments.options != ornaments {
            mapView.ornaments.options = ornaments
        }
    }

    private func startSheetTracking() {
        guard sheetDisplayLink == nil, window != nil else { return }
        let link = CADisplayLink(target: DisplayLinkTarget(viewport: self),
                                 selector: #selector(DisplayLinkTarget.frame(_:)))
        sheetDisplayLink = link
        link.add(to: .main, forMode: .common)
    }

    func stopTrackingSheetPresentation() {
        stopSheetTracking()
        tracksSheetPresentation = false
    }

    private func stopSheetTracking() {
        sheetDisplayLink?.invalidate()
        sheetDisplayLink = nil
    }

    private func refreshPresentedSheet() {
        var sheetTop: CGFloat?
        if tracksSheetPresentation || sheetDisplayLink != nil {
            var controller = window?.rootViewController
            while let presented = controller?.presentedViewController {
                if let sheet = presented.presentationController as? UISheetPresentationController,
                   let container = sheet.containerView {
                    let frame = mapView.convert(sheet.frameOfPresentedViewInContainerView, from: container)
                    if frame.intersects(visibleMapRect), frame.minY.isFinite {
                        sheetTop = min(sheetTop ?? frame.minY, frame.minY)
                    }
                }
                controller = presented
            }
        }
        updateOrnaments(occludedBelow: sheetTop)
        // Continue through the dismissal animation after SwiftUI clears selection.
        if !tracksSheetPresentation, sheetTop == nil { stopSheetTracking() }
    }
}
