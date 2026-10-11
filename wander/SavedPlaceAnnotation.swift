import UIKit

final class SavedPlaceAnnotation: MapAnnotation {
    let placeID: String
    let sourceID: String
    var categoryCode: String?
    var categoryName: String?

    var categoryLabel: String {
        NaverPlaceCategory.label(for: categoryCode, name: categoryName)
    }

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
    private let iconView = UIImageView()
    private let nameLabel = UILabel()
    private let typeLabel = UILabel()
    var showsLabels: Bool { labelsAllowed && !labelsOccluded }
    private(set) var labelsAllowed = false
    private var labelsOccluded = false
    private var contentSize = CGSize(width: 44, height: 44)
    private var labelWidth: CGFloat = 0

    var labelCollisionRect: CGRect {
        CGRect(x: 44, y: 6, width: labelWidth, height: 32)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize { contentSize }

    override func systemLayoutSizeFitting(_ targetSize: CGSize) -> CGSize { contentSize }

    static func shouldShowLabels(at zoom: Double, wasVisible: Bool) -> Bool {
        zoom >= (wasVisible ? 13.7 : 14)
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
        iconView.image = UIImage(
            systemName: NaverPlaceCategory.symbol(for: annotation.categoryCode),
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        )
        nameLabel.text = annotation.title
        typeLabel.text = annotation.categoryLabel
        labelWidth = min(160, ceil(max(
            nameLabel.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: 20)).width,
            typeLabel.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: 16)).width
        )))
        accessibilityLabel = annotation.title
        accessibilityValue = annotation.categoryLabel
        accessibilityIdentifier = "saved-place-\(annotation.sourceID)"
        updateLayout()
    }

    func setLabelsVisible(_ visible: Bool) {
        guard labelsAllowed != visible else { return }
        labelsAllowed = visible
        updateLayout()
    }

    func setLabelsOccluded(_ occluded: Bool) {
        guard labelsOccluded != occluded else { return }
        labelsOccluded = occluded
        updateLayout()
    }

    private func configureView() {
        let glassView = UIVisualEffectView(effect: UIGlassEffect(style: .clear))
        glassView.frame = CGRect(x: 4, y: 4, width: 36, height: 36)
        glassView.cornerConfiguration = .capsule()
        glassView.isUserInteractionEnabled = false
        addSubview(glassView)

        iconView.tintColor = .systemBlue
        iconView.contentMode = .center
        iconView.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        nameLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        typeLabel.font = .systemFont(ofSize: 11)
        // The map's day style stays light independently of the surrounding app.
        nameLabel.textColor = .black
        typeLabel.textColor = .darkGray
        for label in [nameLabel, typeLabel] {
            label.lineBreakMode = .byTruncatingTail
            addSubview(label)
        }
        addSubview(iconView)
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityHint = "Afficher cette adresse enregistrée"
        clipsToBounds = true
        updateLayout()
    }

    private func updateLayout() {
        nameLabel.isHidden = !showsLabels
        typeLabel.isHidden = !showsLabels
        let labelWidth = showsLabels ? labelCollisionRect.width : 0
        let width: CGFloat = showsLabels ? 48 + labelWidth : 44
        nameLabel.frame = CGRect(x: 44, y: 6, width: labelWidth, height: 18)
        typeLabel.frame = CGRect(x: 44, y: 24, width: labelWidth, height: 14)
        // Mapbox can assign an older frame; it must not become the next measured size.
        contentSize = CGSize(width: width, height: 44)
        bounds = CGRect(origin: .zero, size: contentSize)
        // Keep the icon, rather than the wider label group, on the coordinate.
        centerOffset = CGSize(width: (width - 44) / 2, height: 0)
    }
}
