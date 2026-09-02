//
//  MapSocialClusterAnnotationView.swift
//  wander
//

import MapKit
import UIKit

enum MapSocialClusterMemberID: Hashable {
    case currentUser
    case friend(String)
    case outing(String)
}

struct MapSocialClusterPersonPresentation: Equatable {
    let id: String
    let displayName: String
    let avatarID: String
    let profileColorHex: String
    let isCurrentUser: Bool
}

struct MapSocialClusterOutingPresentation: Equatable {
    let id: String
    let placeName: String
    let category: OutingCategory
    let profileColorHex: String
    let isCurrentUser: Bool
}

struct MapSocialClusterPresentation: Equatable {
    let people: [MapSocialClusterPersonPresentation]
    let outings: [MapSocialClusterOutingPresentation]
}

private enum MapSocialClusterMemberPresentation {
    case person(MapSocialClusterPersonPresentation)
    case outing(MapSocialClusterOutingPresentation)

    var id: MapSocialClusterMemberID {
        switch self {
        case .person(let person):
            person.isCurrentUser ? .currentUser : .friend(person.id)
        case .outing(let outing):
            .outing(outing.id)
        }
    }
}

private extension MapSocialClusterPresentation {
    var members: [MapSocialClusterMemberPresentation] {
        people.map(MapSocialClusterMemberPresentation.person)
            + outings.map(MapSocialClusterMemberPresentation.outing)
    }
}

final class MapSocialClusterAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "MapSocialClusterAnnotation"

    private static let compactItemSize: CGFloat = 34
    private static let compactItemStep: CGFloat = 18
    private static let compactInset: CGFloat = 7
    private static let compactMaximumVisibleMemberCount = 3
    private static let standardExpandedWidth: CGFloat = 244
    private static let accessibilityExpandedWidth: CGFloat = 300
    private static let standardExpandedRowHeight: CGFloat = 58
    private static let accessibilityExpandedRowHeight: CGFloat = 72
    private static let expandedInset: CGFloat = 6
    private static let expandedMaximumHeight: CGFloat = 360
    private static let anchorGap: CGFloat = 8

    var onSelectMember: ((MapSocialClusterMemberID) -> Void)?

    private let compactContainer = UIView()
    private let expandedContainer = UIView()
    private let expandedScrollView = UIScrollView()
    private var compactMemberViews: [UIView] = []
    private var expandedRows: [MapSocialClusterRowControl] = []
    private var presentation: MapSocialClusterPresentation?
    private(set) var isExpanded = false

    override init(
        annotation: (any MKAnnotation)?,
        reuseIdentifier: String?
    ) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onSelectMember = nil
        presentation = nil
        removeMemberViews()
        setExpanded(false, animated: false)
        accessibilityLabel = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let compactSize = compactControlSize
        compactContainer.frame = CGRect(
            x: (bounds.width - compactSize.width) / 2,
            y: bounds.height - compactSize.height,
            width: compactSize.width,
            height: compactSize.height
        )
        compactContainer.layer.cornerRadius = compactSize.width / 2
        compactContainer.layer.shadowPath = UIBezierPath(
            roundedRect: compactContainer.bounds,
            cornerRadius: compactContainer.layer.cornerRadius
        ).cgPath

        for (index, memberView) in compactMemberViews.enumerated() {
            memberView.frame = CGRect(
                x: (compactSize.width - Self.compactItemSize) / 2,
                y: Self.compactInset
                    + CGFloat(index) * Self.compactItemStep,
                width: Self.compactItemSize,
                height: Self.compactItemSize
            )
            memberView.layer.cornerRadius = Self.compactItemSize / 2
        }

        expandedContainer.frame = expandedPresentationFrame.insetBy(
            dx: Self.expandedInset,
            dy: Self.expandedInset
        )
        expandedContainer.layer.cornerRadius = 16
        expandedContainer.layer.shadowPath = UIBezierPath(
            roundedRect: expandedContainer.bounds,
            cornerRadius: 16
        ).cgPath
        expandedScrollView.frame = expandedContainer.bounds

        for (index, row) in expandedRows.enumerated() {
            row.frame = CGRect(
                x: 0,
                y: CGFloat(index) * expandedRowHeight,
                width: expandedScrollView.bounds.width,
                height: expandedRowHeight
            )
            row.showsSeparator = index < expandedRows.count - 1
        }
        expandedScrollView.contentSize = CGSize(
            width: expandedScrollView.bounds.width,
            height: CGFloat(expandedRows.count) * expandedRowHeight
        )
    }

    override func point(
        inside point: CGPoint,
        with event: UIEvent?
    ) -> Bool {
        if super.point(inside: point, with: event) {
            return true
        }

        guard isExpanded,
              !expandedContainer.isHidden,
              expandedContainer.alpha > 0 else {
            return false
        }
        return expandedContainer.frame.contains(point)
    }

    func configure(with presentation: MapSocialClusterPresentation) {
        guard self.presentation != presentation else { return }

        setExpanded(false, animated: false)
        self.presentation = presentation
        rebuildMemberViews()
        updateAccessibilityPresentation()
        applyGeometry(forExpandedState: false)
    }

    func setExpanded(_ expanded: Bool, animated: Bool) {
        guard expanded != isExpanded else { return }
        isExpanded = expanded

        if expanded {
            expandedContainer.isHidden = false
            expandedContainer.accessibilityElementsHidden = false
            isAccessibilityElement = true
            accessibilityElements = nil
        } else {
            compactContainer.isHidden = false
            compactContainer.accessibilityElementsHidden = false
            isAccessibilityElement = true
            accessibilityElements = nil
        }
        updateAccessibilityPresentation()

        let changes = {
            self.applyGeometry(forExpandedState: expanded)
            self.compactContainer.alpha = expanded ? 0 : 1
            self.compactContainer.transform = expanded
                ? CGAffineTransform(scaleX: 0.9, y: 0.9)
                : .identity
            self.expandedContainer.alpha = expanded ? 1 : 0
            for row in self.expandedRows {
                row.alpha = expanded ? 1 : 0
                row.transform = expanded
                    ? .identity
                    : Self.collapsedRowTransform
            }
            self.layoutIfNeeded()
        }
        let completion: (Bool) -> Void = { [weak self] _ in
            guard let self, self.isExpanded == expanded else { return }
            self.compactContainer.isHidden = expanded
            self.compactContainer.accessibilityElementsHidden = expanded
            self.expandedContainer.isHidden = !expanded
            self.expandedContainer.accessibilityElementsHidden = !expanded
            if expanded {
                UIAccessibility.post(
                    notification: .layoutChanged,
                    argument: self
                )
            }
        }

        if animated && !UIAccessibility.isReduceMotionEnabled {
            UIView.animate(
                withDuration: 0.36,
                delay: 0,
                usingSpringWithDamping: 0.84,
                initialSpringVelocity: 0,
                options: [.beginFromCurrentState, .allowUserInteraction],
                animations: changes,
                completion: completion
            )
        } else {
            changes()
            completion(true)
        }
    }

    func projectedExpandedFrame(at anchorPoint: CGPoint) -> CGRect {
        let size = expandedControlSize
        return CGRect(
            x: anchorPoint.x - size.width / 2,
            y: anchorPoint.y - size.height - Self.anchorGap,
            width: size.width,
            height: size.height
        )
    }

    private var compactControlSize: CGSize {
        let itemCount = max(1, compactMemberViews.count)
        let width = Self.compactItemSize + Self.compactInset * 2
        let height = Self.compactInset * 2
            + Self.compactItemSize
            + CGFloat(itemCount - 1) * Self.compactItemStep
        return CGSize(width: width, height: height)
    }

    private var expandedControlSize: CGSize {
        let contentHeight = CGFloat(max(1, expandedRows.count))
            * expandedRowHeight
            + Self.expandedInset * 2
        return CGSize(
            width: expandedWidth,
            height: min(Self.expandedMaximumHeight, contentHeight)
        )
    }

    private var expandedPresentationFrame: CGRect {
        let size = expandedControlSize
        return CGRect(
            x: (bounds.width - size.width) / 2,
            y: bounds.height - size.height,
            width: size.width,
            height: size.height
        )
    }

    private var expandedWidth: CGFloat {
        traitCollection.preferredContentSizeCategory.isAccessibilityCategory
            ? Self.accessibilityExpandedWidth
            : Self.standardExpandedWidth
    }

    private var expandedRowHeight: CGFloat {
        traitCollection.preferredContentSizeCategory.isAccessibilityCategory
            ? Self.accessibilityExpandedRowHeight
            : Self.standardExpandedRowHeight
    }

    private func configureView() {
        backgroundColor = .clear
        clipsToBounds = false
        canShowCallout = false
        clusteringIdentifier = nil
        collisionMode = .rectangle
        displayPriority = .required
        isAccessibilityElement = true
        accessibilityTraits = .button

        compactContainer.backgroundColor = UIColor.systemBackground
            .withAlphaComponent(0.94)
        compactContainer.isUserInteractionEnabled = false
        compactContainer.isAccessibilityElement = false
        compactContainer.layer.shadowColor = UIColor.black.cgColor
        compactContainer.layer.shadowOpacity = 0.2
        compactContainer.layer.shadowRadius = 3
        compactContainer.layer.shadowOffset = CGSize(width: 0, height: 2)
        addSubview(compactContainer)

        expandedContainer.backgroundColor = UIColor.systemBackground
            .withAlphaComponent(0.96)
        expandedContainer.layer.shadowColor = UIColor.black.cgColor
        expandedContainer.layer.shadowOpacity = 0.2
        expandedContainer.layer.shadowRadius = 5
        expandedContainer.layer.shadowOffset = CGSize(width: 0, height: 3)
        expandedContainer.alpha = 0
        expandedContainer.isHidden = true
        expandedContainer.accessibilityElementsHidden = true
        addSubview(expandedContainer)

        expandedScrollView.alwaysBounceVertical = false
        expandedScrollView.showsVerticalScrollIndicator = true
        expandedScrollView.delaysContentTouches = false
        expandedScrollView.isAccessibilityElement = false
        expandedContainer.addSubview(expandedScrollView)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferredContentSizeDidChange),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )

        applyGeometry(forExpandedState: false)
    }

    @objc private func preferredContentSizeDidChange() {
        applyGeometry(forExpandedState: isExpanded)
        setNeedsLayout()
    }

    private func rebuildMemberViews() {
        removeMemberViews()
        guard let presentation else { return }

        let members = presentation.members
        let visibleMembers = compactMembers(in: presentation)
        for member in visibleMembers {
            let view = compactView(for: member)
            compactContainer.addSubview(view)
            compactMemberViews.append(view)
        }

        let remainingCount = members.count - visibleMembers.count
        if remainingCount > 0 {
            let countLabel = UILabel()
            countLabel.text = "+\(remainingCount)"
            countLabel.font = .systemFont(ofSize: 12, weight: .bold)
            countLabel.adjustsFontForContentSizeCategory = true
            countLabel.textAlignment = .center
            countLabel.textColor = .label
            countLabel.backgroundColor = .secondarySystemBackground
            countLabel.clipsToBounds = true
            countLabel.layer.borderWidth = 2
            countLabel.layer.borderColor = UIColor.systemBackground.cgColor
            countLabel.isAccessibilityElement = false
            compactContainer.addSubview(countLabel)
            compactMemberViews.append(countLabel)
        }

        for member in members {
            let row = MapSocialClusterRowControl(presentation: member)
            row.alpha = 0
            row.transform = Self.collapsedRowTransform
            row.onActivate = { [weak self] memberID in
                self?.onSelectMember?(memberID)
            }
            expandedScrollView.addSubview(row)
            expandedRows.append(row)
        }
        setNeedsLayout()
    }

    private static var collapsedRowTransform: CGAffineTransform {
        CGAffineTransform(translationX: 0, y: -6)
            .scaledBy(x: 1, y: 0.96)
    }

    private func compactMembers(
        in presentation: MapSocialClusterPresentation
    ) -> [MapSocialClusterMemberPresentation] {
        let members = presentation.members
        guard members.count > Self.compactMaximumVisibleMemberCount,
              !presentation.people.isEmpty,
              !presentation.outings.isEmpty else {
            return Array(
                members.prefix(Self.compactMaximumVisibleMemberCount)
            )
        }

        var result = presentation.people.prefix(2).map(
            MapSocialClusterMemberPresentation.person
        )
        result.append(.outing(presentation.outings[0]))
        let selectedIDs = Set(result.map(\.id))
        for member in members where result.count
            < Self.compactMaximumVisibleMemberCount {
            guard !selectedIDs.contains(member.id) else { continue }
            result.append(member)
        }
        return result
    }

    private func compactView(
        for member: MapSocialClusterMemberPresentation
    ) -> UIView {
        switch member {
        case .person(let person):
            let imageView = UIImageView()
            let avatar = ProfileAvatar(rawValue: person.avatarID)
                ?? ProfileAvatar.cyclopsHorns
            imageView.image = UIImage(named: avatar.assetName)
                ?? UIImage(systemName: "person.crop.circle.fill")
            imageView.backgroundColor = .secondarySystemBackground
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.borderWidth = person.isCurrentUser ? 3 : 2
            imageView.layer.borderColor = ProfileColor.uiColor(
                hex: person.profileColorHex
            ).cgColor
            imageView.isAccessibilityElement = false
            return imageView

        case .outing(let outing):
            let badgeView = OutingCategoryBadgeView()
            badgeView.configure(
                category: outing.category,
                profileColorHex: outing.profileColorHex,
                isCurrentUser: outing.isCurrentUser
            )
            return badgeView
        }
    }

    private func removeMemberViews() {
        for view in compactMemberViews {
            view.removeFromSuperview()
        }
        compactMemberViews.removeAll()
        for row in expandedRows {
            row.removeFromSuperview()
        }
        expandedRows.removeAll()
    }

    private func applyGeometry(forExpandedState expanded: Bool) {
        let size = compactControlSize
        bounds = CGRect(origin: .zero, size: size)
        centerOffset = CGPoint(
            x: 0,
            y: -size.height / 2 - Self.anchorGap
        )
        displayPriority = .required
        setNeedsLayout()
    }

    private func updateAccessibilityPresentation() {
        guard let presentation else {
            accessibilityCustomActions = nil
            return
        }

        let summary = Self.accessibilitySummary(for: presentation)
        if isExpanded {
            accessibilityLabel = "Groupe ouvert, "
                + summary.replacingOccurrences(
                    of: "Groupe, ",
                    with: ""
                )
            accessibilityHint =
                "Utilisez les actions pour zoomer sur un élément du groupe."
            accessibilityTraits = [.button, .selected]
            accessibilityCustomActions = expandedRows.map { row in
                UIAccessibilityCustomAction(
                    name: row.accessibilityActionName
                ) { [weak self] _ in
                    self?.onSelectMember?(row.memberID)
                    return true
                }
            }
        } else {
            accessibilityLabel = summary
            accessibilityHint =
                "Touchez deux fois pour afficher verticalement les éléments du groupe."
            accessibilityTraits = .button
            accessibilityCustomActions = nil
        }
    }

    private static func accessibilitySummary(
        for presentation: MapSocialClusterPresentation
    ) -> String {
        var parts: [String] = []
        if !presentation.people.isEmpty {
            let peopleLabel = presentation.people.count == 1
                ? "1 personne"
                : "\(presentation.people.count) personnes"
            parts.append(peopleLabel)
        }
        if !presentation.outings.isEmpty {
            let outingLabel = presentation.outings.count == 1
                ? "1 sortie prévue"
                : "\(presentation.outings.count) sorties prévues"
            parts.append(outingLabel)
        }
        return "Groupe, " + parts.joined(separator: " et ")
    }
}

private final class MapSocialClusterRowControl: UIControl {
    fileprivate let memberID: MapSocialClusterMemberID
    private let iconView: UIView
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let separatorView = UIView()

    var onActivate: ((MapSocialClusterMemberID) -> Void)?

    fileprivate var accessibilityActionName: String {
        [titleLabel.text, subtitleLabel.text]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    var showsSeparator = true {
        didSet { separatorView.isHidden = !showsSeparator }
    }

    override var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted ? .tertiarySystemFill : .clear
        }
    }

    init(presentation: MapSocialClusterMemberPresentation) {
        switch presentation {
        case .person(let person):
            memberID = person.isCurrentUser
                ? .currentUser
                : .friend(person.id)
            titleLabel.text = person.displayName
            subtitleLabel.text = person.isCurrentUser ? "Vous" : "Ami"

            let imageView = UIImageView()
            let avatar = ProfileAvatar(rawValue: person.avatarID)
                ?? ProfileAvatar.cyclopsHorns
            imageView.image = UIImage(named: avatar.assetName)
                ?? UIImage(systemName: "person.crop.circle.fill")
            imageView.backgroundColor = .secondarySystemBackground
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.borderWidth = person.isCurrentUser ? 3 : 2
            imageView.layer.borderColor = ProfileColor.uiColor(
                hex: person.profileColorHex
            ).cgColor
            iconView = imageView

        case .outing(let outing):
            memberID = .outing(outing.id)
            titleLabel.text = outing.placeName
            subtitleLabel.text = outing.isCurrentUser
                ? "Votre sortie · \(outing.category.title)"
                : "Sortie · \(outing.category.title)"

            let badgeView = OutingCategoryBadgeView()
            badgeView.configure(
                category: outing.category,
                profileColorHex: outing.profileColorHex,
                isCurrentUser: outing.isCurrentUser
            )
            iconView = badgeView
        }

        super.init(frame: .zero)
        configureView()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let iconSize: CGFloat = 38
        iconView.frame = CGRect(
            x: 10,
            y: (bounds.height - iconSize) / 2,
            width: iconSize,
            height: iconSize
        )
        iconView.layer.cornerRadius = iconSize / 2

        let textX = iconView.frame.maxX + 10
        let textWidth = max(0, bounds.width - textX - 12)
        let usesAccessibilityLayout = traitCollection
            .preferredContentSizeCategory.isAccessibilityCategory
        titleLabel.frame = CGRect(
            x: textX,
            y: usesAccessibilityLayout ? 5 : 8,
            width: textWidth,
            height: usesAccessibilityLayout ? 34 : 23
        )
        subtitleLabel.frame = CGRect(
            x: textX,
            y: titleLabel.frame.maxY,
            width: textWidth,
            height: usesAccessibilityLayout ? 28 : 18
        )
        separatorView.frame = CGRect(
            x: textX,
            y: bounds.height - 1 / traitCollection.displayScale,
            width: bounds.width - textX,
            height: 1 / traitCollection.displayScale
        )
    }

    private func configureView() {
        accessibilityTraits = .button
        accessibilityLabel = titleLabel.text
        accessibilityValue = subtitleLabel.text
        accessibilityHint = "Zoome et sélectionne cet élément sur la carte."

        iconView.isUserInteractionEnabled = false
        iconView.isAccessibilityElement = false
        addSubview(iconView)

        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.75
        titleLabel.textColor = .label
        titleLabel.isAccessibilityElement = false
        addSubview(titleLabel)

        subtitleLabel.font = .preferredFont(forTextStyle: .caption1)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.adjustsFontSizeToFitWidth = true
        subtitleLabel.minimumScaleFactor = 0.75
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.isAccessibilityElement = false
        addSubview(subtitleLabel)

        separatorView.backgroundColor = .separator
        separatorView.isAccessibilityElement = false
        addSubview(separatorView)

        addTarget(self, action: #selector(activate), for: .touchUpInside)
    }

    @objc private func activate() {
        onActivate?(memberID)
    }
}
