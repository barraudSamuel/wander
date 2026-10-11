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
    private(set) var showsLabels = false

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
        accessibilityLabel = annotation.title
        accessibilityValue = annotation.categoryLabel
        accessibilityIdentifier = "saved-place-\(annotation.sourceID)"
        updateLayout()
    }

    func setLabelsVisible(_ visible: Bool) {
        guard showsLabels != visible else { return }
        showsLabels = visible
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
        updateLayout()
    }

    private func updateLayout() {
        nameLabel.isHidden = !showsLabels
        typeLabel.isHidden = !showsLabels
        let labelWidth = showsLabels ? min(160, ceil(max(
            nameLabel.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: 20)).width,
            typeLabel.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: 16)).width
        ))) : 0
        let width: CGFloat = showsLabels ? 48 + labelWidth : 44
        nameLabel.frame = CGRect(x: 44, y: 6, width: labelWidth, height: 18)
        typeLabel.frame = CGRect(x: 44, y: 24, width: labelWidth, height: 14)
        bounds = CGRect(x: 0, y: 0, width: width, height: 44)
        // Keep the icon, rather than the wider label group, on the coordinate.
        centerOffset = CGSize(width: (width - 44) / 2, height: 0)
    }
}
