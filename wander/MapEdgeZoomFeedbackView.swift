import UIKit

/// A non-interactive bulge attached to the visible map edge.
@MainActor
final class MapEdgeZoomFeedbackView: UIView {
    private let shape = CAShapeLayer()
    private var edge: MapEdgeZoomController.Edge = .left
    private var fingerY: CGFloat = 0
    private(set) var isShowing = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        backgroundColor = .clear
        clipsToBounds = true
        shape.fillColor = UIColor.black.cgColor
        layer.addSublayer(shape)
    }

    required init?(coder: NSCoder) { nil }

    func show(at point: CGPoint, edge: MapEdgeZoomController.Edge, in visibleBounds: CGRect) {
        let wasShowing = isShowing
        if frame != visibleBounds { frame = visibleBounds }
        self.edge = edge
        fingerY = max(0, min(bounds.height, point.y - visibleBounds.minY))
        isShowing = true
        // A new gesture must grow from its own edge, even after switching sides.
        if !wasShowing { setPath(depth: 0, animated: false) }
        setPath(depth: 20, animated: !wasShowing)
    }

    func dismiss() {
        guard isShowing else { return }
        isShowing = false
        setPath(depth: 0, animated: true)
    }

    private func setPath(depth: CGFloat, animated: Bool) {
        let shouldAnimate = animated && !UIAccessibility.isReduceMotionEnabled
        let previous = shouldAnimate ? shape.presentation()?.path ?? shape.path ?? path(depth: 0) : nil
        shape.removeAnimation(forKey: "edge-retraction")
        let next = path(depth: depth)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shape.path = next
        CATransaction.commit()
        if shouldAnimate {
            let animation = CABasicAnimation(keyPath: "path")
            animation.fromValue = previous
            animation.toValue = next
            animation.duration = 0.16
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            shape.add(animation, forKey: "edge-retraction")
        }
    }

    private func path(depth: CGFloat) -> CGPath {
        let x = edge == .left ? CGFloat(0) : bounds.width
        let inward: CGFloat = edge == .left ? 1 : -1
        let tip = x + inward * depth
        let path = UIBezierPath()
        path.move(to: CGPoint(x: x, y: fingerY - 72))
        path.addCurve(
            to: CGPoint(x: tip, y: fingerY),
            controlPoint1: CGPoint(x: x, y: fingerY - 42),
            controlPoint2: CGPoint(x: tip, y: fingerY - 28)
        )
        path.addCurve(
            to: CGPoint(x: x, y: fingerY + 72),
            controlPoint1: CGPoint(x: tip, y: fingerY + 28),
            controlPoint2: CGPoint(x: x, y: fingerY + 42)
        )
        path.close()
        return path.cgPath
    }
}
