import UIKit

final class SavedPlaceAnnotation: MapAnnotation {
    let placeID: String
    let sourceID: String
    var categoryCode: String?
    var categoryName: String?

    var categoryLabel: String { NaverPlaceCategory.label(for: categoryCode, name: categoryName) }

    init(place: SavedPlace) {
        placeID = place.id
        sourceID = place.sourceID
        categoryCode = place.categoryCode
        categoryName = place.categoryName
        super.init(coordinate: place.coordinate, title: place.name)
    }
}

final class SavedPlaceAnnotationView: MapAnnotationView {
    static let reuseIdentifier = "SavedPlaceAnnotation"

    enum Presentation: Equatable {
        case compact, detailed, selected
    }

    struct Geometry: Equatable {
        let circleRect: CGRect
        let labelRect: CGRect
        let contentSize = CGSize(width: 44, height: 44)
        let anchor = CGPoint(x: 22, y: 22)
        let visualRect: CGRect
        let state: SavedPlaceVisualState

        init(emphasis: CGFloat, labelWidth: CGFloat) {
            self.init(state: .mapPin(emphasis: emphasis), labelWidth: labelWidth)
        }

        private init(state: SavedPlaceVisualState, labelWidth: CGFloat) {
            self.state = state
            circleRect = state.bodyRect.offsetBy(dx: 22, dy: 22)
            labelRect = state.stickerOpacity > 0
                ? CGRect(x: 22 - labelWidth / 2, y: circleRect.minY + 2 - 22 * state.stickerScale,
                         width: labelWidth, height: 44 * state.stickerScale)
                : .zero
            let silhouette = CGRect(x: circleRect.minX, y: circleRect.minY,
                                    width: circleRect.width, height: circleRect.height + state.tip)
            visualRect = labelRect.isEmpty ? silhouette : silhouette.union(labelRect)
        }
    }

    private let visual = SavedPlaceCalloutView()
    private var displayLink: CADisplayLink?
    private var emphasisMotion = SavedPlaceEmphasisMotion()
    private var lastEmphasisFrame: CFTimeInterval?
    private(set) var mapEmphasis: CGFloat = 0
    private var categoryAccessibilityLabel = ""
    private var displayedState = Geometry(emphasis: 0, labelWidth: 0).state
    private(set) var presentationGeometry = Geometry(emphasis: 0, labelWidth: 0)
    var onPresentationTransitionEnd: (() -> Void)?

    var showsLabels: Bool { displayedState.stickerOpacity > 0.001 }
    var presentation: Presentation { isSelected ? .selected : mapEmphasis >= 0.5 ? .detailed : .compact }
    var isTransitioning: Bool { lastEmphasisFrame != nil }
    var renderedAnchorInHost: CGPoint { visual.renderedAnchor(in: self) }
    var renderedBodyRect: CGRect { displayedState.bodyRect }
    var currentVisualRect: CGRect {
        let body = displayedState.bodyRect
        let silhouette = CGRect(x: body.minX, y: body.minY, width: body.width, height: body.height + displayedState.tip)
        guard displayedState.stickerOpacity > 0 else { return silhouette }
        return silhouette.union(displayedState.stickerRect(baseWidth: visual.stickerWidth))
    }

    override init(annotation: MapAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    func configure(with annotation: SavedPlaceAnnotation) {
        visual.configure(with: annotation)
        accessibilityLabel = annotation.title
        categoryAccessibilityLabel = annotation.categoryLabel
        updateAccessibilityValue()
        accessibilityIdentifier = "saved-place-\(annotation.sourceID)"
        presentationGeometry = targetGeometry
        apply(displayedState)
    }

    func updatePhoto(_ image: UIImage?) {
        visual.updatePhoto(image)
    }

    func geometry(forEmphasis emphasis: CGFloat) -> Geometry {
        Geometry(emphasis: emphasis, labelWidth: visual.stickerWidth * (14 / 24))
    }

    private var targetGeometry: Geometry { geometry(forEmphasis: mapEmphasis) }

    override func sizeThatFits(_ size: CGSize) -> CGSize { presentationGeometry.contentSize }
    override func systemLayoutSizeFitting(_ targetSize: CGSize) -> CGSize { presentationGeometry.contentSize }

    func setMapEmphasis(_ emphasis: CGFloat, animated: Bool = true) {
        let target = SavedPlaceEmphasisMotion.bounded(emphasis)
        guard mapEmphasis != target else { return }
        mapEmphasis = target
        emphasisMotion.retarget(target)
        presentationGeometry = targetGeometry
        updateAccessibilityValue()
        followMapEmphasis(animated: animated)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        guard isSelected != selected else { return }
        super.setSelected(selected, animated: animated)
        accessibilityTraits = selected ? [.button, .selected] : .button
        updateAccessibilityValue()
    }

    /// The drawn silhouette, relative to the geographic anchor. Hit ranking uses this
    /// before the larger touch target so a transparent host cannot cover a visible pin.
    func containsRenderedPoint(_ point: CGPoint) -> Bool {
        let anchor = presentationGeometry.anchor
        let hostPoint = CGPoint(x: point.x + anchor.x, y: point.y + anchor.y)
        return visual.containsRenderedPoint(visual.convert(hostPoint, from: self))
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let local = CGPoint(x: point.x - 22, y: point.y - 22)
        if containsRenderedPoint(local) { return true }
        let body = displayedState.bodyRect
        guard body.width < 44 || body.height < 44 else { return false }
        let hitRect = body.insetBy(dx: -max(0, 44 - body.width) / 2,
                                  dy: -max(0, 44 - body.height) / 2)
        return hitRect.contains(local)
    }

    override func prepareForReuse() {
        stopAnimation()
        onPresentationTransitionEnd = nil
        super.setSelected(false, animated: false)
        mapEmphasis = 0
        emphasisMotion.reset(to: 0)
        categoryAccessibilityLabel = ""
        visual.updatePhoto(nil)
        accessibilityLabel = nil
        accessibilityValue = nil
        accessibilityIdentifier = nil
        accessibilityTraits = .button
        isAccessibilityElement = true
        presentationGeometry = geometry(forEmphasis: 0)
        apply(presentationGeometry.state)
        super.prepareForReuse()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil, isTransitioning {
            stopAnimation()
            emphasisMotion.reset(to: mapEmphasis)
            presentationGeometry = targetGeometry
            apply(presentationGeometry.state)
            onPresentationTransitionEnd?()
        }
    }

    private func configureView() {
        bounds = CGRect(origin: .zero, size: CGSize(width: 44, height: 44))
        clipsToBounds = false
        visual.frame = bounds
        addSubview(visual)
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityHint = "Afficher cette adresse enregistrée"
        apply(displayedState)
    }

    private func followMapEmphasis(animated: Bool) {
        guard animated, window != nil, !UIAccessibility.isReduceMotionEnabled else {
            stopAnimation()
            emphasisMotion.reset(to: mapEmphasis)
            apply(presentationGeometry.state)
            onPresentationTransitionEnd?()
            return
        }
        guard !emphasisMotion.isSettled else { return }
        if lastEmphasisFrame == nil { lastEmphasisFrame = CACurrentMediaTime() }
        startDisplayLink()
    }

    private func startDisplayLink() {
        guard displayLink == nil else { return }
        let proxy = SavedPlaceDisplayLinkProxy(owner: self)
        let link = CADisplayLink(target: proxy, selector: #selector(SavedPlaceDisplayLinkProxy.tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    fileprivate func advance(at timestamp: CFTimeInterval) {
        guard let lastFrame = lastEmphasisFrame else { return }
        let elapsed = max(0, timestamp - lastFrame)
        lastEmphasisFrame = max(timestamp, lastFrame)
        emphasisMotion.advance(by: elapsed)
        apply(.mapPin(emphasis: emphasisMotion.value))
        if emphasisMotion.isSettled { finishAnimation() }
    }

    private func finishAnimation() {
        stopAnimation()
        onPresentationTransitionEnd?()
    }

    private func apply(_ state: SavedPlaceVisualState) {
        displayedState = state
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        visual.apply(state, at: presentationGeometry.anchor)
        CATransaction.commit()
    }

    private func stopAnimation() {
        displayLink?.invalidate()
        displayLink = nil
        lastEmphasisFrame = nil
    }

    private func updateAccessibilityValue() {
        let state: String
        switch presentation {
        case .compact: state = "Compact"
        case .detailed: state = "Détaillé"
        case .selected: state = "Sélectionné"
        }
        accessibilityValue = "\(categoryAccessibilityLabel) · \(state)"
    }
}

@MainActor
private final class SavedPlaceDisplayLinkProxy: NSObject {
    weak var owner: SavedPlaceAnnotationView?
    init(owner: SavedPlaceAnnotationView) { self.owner = owner }

    @objc func tick(_ link: CADisplayLink) {
        guard let owner else { link.invalidate(); return }
        owner.advance(at: link.timestamp)
    }
}
