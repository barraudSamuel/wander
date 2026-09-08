import MapKit
import SwiftUI

private struct MapRenderSizeKey: EnvironmentKey {
    static let defaultValue: CGSize? = nil
}

private struct MapContentInsetsKey: EnvironmentKey {
    static let defaultValue = EdgeInsets()
}

extension EnvironmentValues {
    var mapRenderSize: CGSize? {
        get { self[MapRenderSizeKey.self] }
        set { self[MapRenderSizeKey.self] = newValue }
    }

    var mapContentInsets: EdgeInsets {
        get { self[MapContentInsetsKey.self] }
        set { self[MapContentInsetsKey.self] = newValue }
    }
}

/// Crops a stable MapKit drawable while the surrounding detail pane resizes.
/// Keeping the map and viewport centers aligned preserves native camera gestures.
final class MapViewportView: UIView {
    let mapView: MKMapView
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

    init(mapView: MKMapView, renderSize: CGSize?, contentInsets: UIEdgeInsets = .zero) {
        self.mapView = mapView
        self.renderSize = renderSize
        self.contentInsets = contentInsets
        super.init(frame: .zero)
        clipsToBounds = true
        accessibilityIdentifier = "map-visible-viewport"
        addSubview(mapView)
    }

    required init?(coder: NSCoder) { nil }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = renderSize ?? bounds.size
        guard size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0 else { return }

        // Do not assign frame during pane animations: MapKit resizes its Metal
        // drawable from setFrame, even when only the visible window should change.
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
        guard visible != visibleMapRect || safe != visibleSafeMapRect else { return }
        visibleMapRect = visible
        visibleSafeMapRect = safe

        // MapKit positions its compass and attribution inside layout margins.
        // These insets move its controls without changing the rendering bounds.
        mapView.layoutMargins = UIEdgeInsets(
            top: max(0, safe.minY - mapView.bounds.minY),
            left: max(0, safe.minX - mapView.bounds.minX),
            bottom: max(0, mapView.bounds.maxY - safe.maxY),
            right: max(0, mapView.bounds.maxX - safe.maxX)
        )
        onViewportChange?()
    }
}
