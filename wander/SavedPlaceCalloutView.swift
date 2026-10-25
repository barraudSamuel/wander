import UIKit

/// Keeps one photo view while the map pin changes size around its geographic tip.
final class SavedPlaceCalloutView: UIView {
    let photoView = UIImageView()
    let fallbackView = UIImageView()
    private let contentView = UIView()
    private let bodyView = UIView()
    private let tipLayer = CAShapeLayer()
    private let stickerView = SavedPlaceCategoryStickerView()
    private(set) var stickerText = ""
    private(set) var stickerWidth: CGFloat = 12

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with annotation: SavedPlaceAnnotation) {
        let label = annotation.categoryLabel
        let nextStickerText = label.count > 18 ? String(label.prefix(16)) + "…" : label
        if nextStickerText != stickerText {
            stickerText = nextStickerText
            stickerWidth = SavedPlaceCategoryStickerView.measuredWidth(for: stickerText, size: 24)
            stickerView.text = stickerText
        }
        fallbackView.image = UIImage(systemName: NaverPlaceCategory.symbol(for: annotation.categoryCode))
    }

    func updatePhoto(_ image: UIImage?) {
        photoView.image = image
        fallbackView.isHidden = image != nil
    }

    func renderedAnchor(in view: UIView) -> CGPoint {
        contentView.convert(CGPoint(x: contentView.bounds.midX, y: contentView.bounds.maxY), to: view)
    }

    func containsRenderedPoint(_ point: CGPoint) -> Bool {
        let local = contentView.convert(point, from: self)
        guard local.x.isFinite, local.y.isFinite else { return false }
        if UIBezierPath(roundedRect: bodyView.bounds, cornerRadius: bodyView.layer.cornerRadius)
            .contains(bodyView.convert(local, from: contentView)) { return true }
        if stickerView.alpha > 0.001,
           stickerView.bounds.contains(stickerView.convert(local, from: contentView)) { return true }
        return tipLayer.path?.contains(tipLayer.convert(local, from: contentView.layer)) == true
    }

    func apply(_ state: SavedPlaceVisualState, at anchor: CGPoint) {
        let size = CGSize(width: state.width, height: state.height + state.tip)
        contentView.bounds = CGRect(origin: .zero, size: size)
        contentView.layer.anchorPoint = CGPoint(x: 0.5, y: 1)
        contentView.layer.position = anchor
        bodyView.frame = CGRect(x: 0, y: 0, width: state.width, height: state.height)
        bodyView.layer.cornerRadius = state.radius

        let pointer = UIBezierPath()
        pointer.move(to: CGPoint(x: state.width / 2 - state.tip, y: state.height - 1))
        pointer.addLine(to: CGPoint(x: state.width / 2, y: state.height + state.tip))
        pointer.addLine(to: CGPoint(x: state.width / 2 + state.tip, y: state.height - 1))
        pointer.close()
        let shadow = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: state.width, height: state.height),
                                  cornerRadius: state.radius)
        shadow.append(pointer)
        contentView.layer.shadowPath = shadow.cgPath
        tipLayer.frame = CGRect(origin: .zero, size: size)
        tipLayer.path = pointer.cgPath
        photoView.frame = CGRect(x: state.border, y: state.border,
                                 width: max(1, state.width - state.border * 2),
                                 height: max(1, state.height - state.border * 2))
        photoView.layer.cornerRadius = max(1, state.radius - state.border)
        let iconSide = min(photoView.bounds.width, photoView.bounds.height) * 0.42
        fallbackView.frame = CGRect(x: photoView.frame.midX - iconSide / 2,
                                    y: photoView.frame.midY - iconSide / 2,
                                    width: iconSide, height: iconSide)
        stickerView.bounds = CGRect(x: 0, y: 0, width: stickerWidth, height: 44)
        stickerView.center = CGPoint(x: state.width / 2, y: 2)
        stickerView.transform = CGAffineTransform(scaleX: state.stickerScale, y: state.stickerScale)
        stickerView.alpha = state.stickerOpacity
    }

    private func configureView() {
        clipsToBounds = false
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        addSubview(contentView)
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOpacity = 0.15
        contentView.layer.shadowRadius = 2
        contentView.layer.shadowOffset = CGSize(width: 0, height: 1)
        contentView.addSubview(bodyView)
        contentView.layer.addSublayer(tipLayer)
        tipLayer.fillColor = UIColor.white.cgColor
        bodyView.backgroundColor = .white
        bodyView.clipsToBounds = true
        photoView.contentMode = .scaleAspectFill
        photoView.clipsToBounds = true
        photoView.backgroundColor = UIColor(white: 0.91, alpha: 1)
        bodyView.addSubview(photoView)
        fallbackView.tintColor = .darkGray
        fallbackView.contentMode = .scaleAspectFit
        bodyView.addSubview(fallbackView)
        contentView.addSubview(stickerView)
        stickerView.fontSize = 24
        updatePhoto(nil)
    }
}
