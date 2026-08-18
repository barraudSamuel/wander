//
//  MapOffscreenIndicatorView.swift
//  wander
//
//  Shared edge indicators for map content outside the viewport.
//

import UIKit

enum MapOffscreenIndicatorEdge: Int, CaseIterable {
    case top
    case right
    case bottom
    case left
}

struct MapOffscreenIndicatorCandidate {
    let id: String
    let targetPoint: CGPoint
}

struct MapOffscreenIndicatorPlacement {
    let id: String
    let center: CGPoint
    let edge: MapOffscreenIndicatorEdge
    let directionName: String
}

enum MapOffscreenIndicatorLayout {
    static let controlSize: CGFloat = 48
    static let visualSize: CGFloat = 28

    private static let edgeInset: CGFloat = 0
    private static let cornerClearance: CGFloat = controlSize * 0.72
    private static let overlappingSeparation: CGFloat = visualSize / 2

    static func visualFrame(
        in bounds: CGRect,
        edge: MapOffscreenIndicatorEdge
    ) -> CGRect {
        let origin: CGPoint
        switch edge {
        case .top:
            origin = CGPoint(
                x: (bounds.width - visualSize) / 2,
                y: 0
            )
        case .right:
            origin = CGPoint(
                x: bounds.width - visualSize,
                y: (bounds.height - visualSize) / 2
            )
        case .bottom:
            origin = CGPoint(
                x: (bounds.width - visualSize) / 2,
                y: bounds.height - visualSize
            )
        case .left:
            origin = CGPoint(
                x: 0,
                y: (bounds.height - visualSize) / 2
            )
        }

        return CGRect(
            origin: origin,
            size: CGSize(width: visualSize, height: visualSize)
        )
    }

    static func indicatorBounds(
        in bounds: CGRect,
        safeAreaInsets: UIEdgeInsets
    ) -> CGRect? {
        guard bounds.width > controlSize * 2,
              bounds.height > controlSize * 2 else {
            return nil
        }

        let safeBounds = bounds.inset(by: safeAreaInsets)
        let centerInset = controlSize / 2 + edgeInset
        let result = safeBounds.insetBy(dx: centerInset, dy: centerInset)

        guard result.width > 0, result.height > 0 else { return nil }
        return result
    }

    static func placements(
        for candidates: [MapOffscreenIndicatorCandidate],
        in indicatorBounds: CGRect
    ) -> [MapOffscreenIndicatorPlacement] {
        let mapCenter = CGPoint(
            x: indicatorBounds.midX,
            y: indicatorBounds.midY
        )
        var rawPlacements: [RawPlacement] = []

        for candidate in candidates.sorted(by: { $0.id < $1.id }) {
            let direction = CGPoint(
                x: candidate.targetPoint.x - mapCenter.x,
                y: candidate.targetPoint.y - mapCenter.y
            )
            guard direction.x.isFinite,
                  direction.y.isFinite,
                  abs(direction.x) > 0.001 || abs(direction.y) > 0.001,
                  let intersection = intersection(
                    from: mapCenter,
                    direction: direction,
                    with: indicatorBounds
                  ) else {
                continue
            }

            rawPlacements.append(
                RawPlacement(
                    id: candidate.id,
                    center: intersection.point,
                    edge: intersection.edge,
                    directionName: directionName(for: direction)
                )
            )
        }

        var resolved: [String: MapOffscreenIndicatorPlacement] = [:]
        for edge in MapOffscreenIndicatorEdge.allCases {
            let edgePlacements = rawPlacements.filter { $0.edge == edge }
            for placement in resolveCollisions(
                edgePlacements,
                on: edge,
                in: indicatorBounds
            ) {
                resolved[placement.id] = placement
            }
        }

        return candidates.compactMap { resolved[$0.id] }
    }

    private static func intersection(
        from origin: CGPoint,
        direction: CGPoint,
        with rect: CGRect
    ) -> (point: CGPoint, edge: MapOffscreenIndicatorEdge)? {
        let horizontalScale: CGFloat?
        let horizontalEdge: MapOffscreenIndicatorEdge?
        if direction.x > 0 {
            horizontalScale = (rect.maxX - origin.x) / direction.x
            horizontalEdge = .right
        } else if direction.x < 0 {
            horizontalScale = (rect.minX - origin.x) / direction.x
            horizontalEdge = .left
        } else {
            horizontalScale = nil
            horizontalEdge = nil
        }

        let verticalScale: CGFloat?
        let verticalEdge: MapOffscreenIndicatorEdge?
        if direction.y > 0 {
            verticalScale = (rect.maxY - origin.y) / direction.y
            verticalEdge = .bottom
        } else if direction.y < 0 {
            verticalScale = (rect.minY - origin.y) / direction.y
            verticalEdge = .top
        } else {
            verticalScale = nil
            verticalEdge = nil
        }

        let candidates = [
            horizontalScale.flatMap { scale in
                horizontalEdge.map { (scale, $0) }
            },
            verticalScale.flatMap { scale in
                verticalEdge.map { (scale, $0) }
            }
        ]
        .compactMap { $0 }
        .filter { $0.0 >= 0 && $0.0.isFinite }

        guard let nearest = candidates.min(by: { $0.0 < $1.0 }) else {
            return nil
        }

        let point = CGPoint(
            x: origin.x + direction.x * nearest.0,
            y: origin.y + direction.y * nearest.0
        )
        guard point.x.isFinite, point.y.isFinite else { return nil }
        return (point, nearest.1)
    }

    private static func resolveCollisions(
        _ placements: [RawPlacement],
        on edge: MapOffscreenIndicatorEdge,
        in rect: CGRect
    ) -> [MapOffscreenIndicatorPlacement] {
        guard !placements.isEmpty else { return [] }

        let isHorizontalEdge = edge == .top || edge == .bottom
        let rawMinimum = isHorizontalEdge ? rect.minX : rect.minY
        let rawMaximum = isHorizontalEdge ? rect.maxX : rect.maxY
        let rawSpan = rawMaximum - rawMinimum
        let requiredMinimumSpan = overlappingSeparation
            * CGFloat(max(0, placements.count - 1))
        let maximumClearanceToFit = max(
            0,
            (rawSpan - requiredMinimumSpan) / 2
        )
        let resolvedCornerClearance = min(
            cornerClearance,
            maximumClearanceToFit
        )
        let minimum = rawMinimum + resolvedCornerClearance
        let maximum = rawMaximum - resolvedCornerClearance
        guard maximum >= minimum else { return [] }

        let sorted = placements.sorted { lhs, rhs in
            let lhsValue = scalarPosition(of: lhs.center, on: edge)
            let rhsValue = scalarPosition(of: rhs.center, on: edge)
            if abs(lhsValue - rhsValue) > 0.5 {
                return lhsValue < rhsValue
            }
            return lhs.id < rhs.id
        }

        let availableSpan = maximum - minimum
        let separation: CGFloat
        if sorted.count > 1 {
            separation = min(
                overlappingSeparation,
                availableSpan / CGFloat(sorted.count - 1)
            )
        } else {
            separation = overlappingSeparation
        }

        var positions = sorted.map {
            min(
                max(scalarPosition(of: $0.center, on: edge), minimum),
                maximum
            )
        }

        for index in positions.indices.dropFirst() {
            positions[index] = max(
                positions[index],
                positions[index - 1] + separation
            )
        }

        if let lastIndex = positions.indices.last,
           positions[lastIndex] > maximum {
            positions[lastIndex] = maximum
            for index in positions.indices.dropLast().reversed() {
                positions[index] = min(
                    positions[index],
                    positions[index + 1] - separation
                )
            }
        }

        return zip(sorted, positions).map { placement, position in
            let center: CGPoint
            switch edge {
            case .top:
                center = CGPoint(x: position, y: rect.minY)
            case .right:
                center = CGPoint(x: rect.maxX, y: position)
            case .bottom:
                center = CGPoint(x: position, y: rect.maxY)
            case .left:
                center = CGPoint(x: rect.minX, y: position)
            }

            return MapOffscreenIndicatorPlacement(
                id: placement.id,
                center: center,
                edge: edge,
                directionName: placement.directionName
            )
        }
    }

    private static func scalarPosition(
        of point: CGPoint,
        on edge: MapOffscreenIndicatorEdge
    ) -> CGFloat {
        switch edge {
        case .top, .bottom:
            point.x
        case .right, .left:
            point.y
        }
    }

    private static func directionName(for direction: CGPoint) -> String {
        let angle: CGFloat = atan2(direction.x, -direction.y)
        let normalizedAngle = angle >= 0 ? angle : angle + 2 * .pi
        let octant = Int(
            (normalizedAngle / (.pi / 4)).rounded()
        ) % 8

        switch octant {
        case 0:
            return "nord"
        case 1:
            return "nord-est"
        case 2:
            return "est"
        case 3:
            return "sud-est"
        case 4:
            return "sud"
        case 5:
            return "sud-ouest"
        case 6:
            return "ouest"
        default:
            return "nord-ouest"
        }
    }

    private struct RawPlacement {
        let id: String
        let center: CGPoint
        let edge: MapOffscreenIndicatorEdge
        let directionName: String
    }
}

final class MapOffscreenIndicatorContainerView: UIView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        subviews.contains { subview in
            !subview.isHidden
                && subview.isUserInteractionEnabled
                && subview.point(
                    inside: subview.convert(point, from: self),
                    with: event
                )
        }
    }
}

final class OutingCategoryBadgeView: UIView {
    private let symbolImageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        layer.cornerRadius = min(bounds.width, bounds.height) / 2
        layer.borderColor = UIColor.systemBackground
            .resolvedColor(with: traitCollection)
            .cgColor
        let symbolInset = max(5, min(bounds.width, bounds.height) * 0.25)
        symbolImageView.frame = bounds.insetBy(
            dx: symbolInset,
            dy: symbolInset
        )
    }

    func configure(
        category: OutingCategory,
        profileColorHex: String,
        isCurrentUser: Bool
    ) {
        let backgroundColor = ProfileColor.uiColor(hex: profileColorHex)
        self.backgroundColor = backgroundColor
        layer.borderWidth = isCurrentUser ? 3 : 2
        symbolImageView.image = UIImage(systemName: category.systemImageName)
        symbolImageView.tintColor = ProfileColor.contrastingUIColor(
            for: backgroundColor
        )
        setNeedsLayout()
    }

    private func configureView() {
        clipsToBounds = true
        isAccessibilityElement = false

        symbolImageView.contentMode = .scaleAspectFit
        symbolImageView.isAccessibilityElement = false
        symbolImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            weight: .semibold
        )
        addSubview(symbolImageView)
    }
}

final class FriendOffscreenIndicatorView: UIControl {
    let userID: String
    var onActivate: ((String) -> Void)?

    private let avatarImageView = UIImageView()
    private var baseAlpha: CGFloat = 1
    private var edge = MapOffscreenIndicatorEdge.top

    init(userID: String) {
        self.userID = userID
        super.init(
            frame: CGRect(
                origin: .zero,
                size: CGSize(
                    width: MapOffscreenIndicatorLayout.controlSize,
                    height: MapOffscreenIndicatorLayout.controlSize
                )
            )
        )
        configureView()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isHighlighted: Bool {
        didSet {
            alpha = baseAlpha * (isHighlighted ? 0.68 : 1)
        }
    }

    override func accessibilityActivate() -> Bool {
        activate()
        return true
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        avatarImageView.frame = MapOffscreenIndicatorLayout.visualFrame(
            in: bounds,
            edge: edge
        )
        avatarImageView.layer.cornerRadius =
            MapOffscreenIndicatorLayout.visualSize / 2
    }

    func configure(
        displayName: String,
        avatarID: String,
        profileColorHex: String,
        isLocationFresh: Bool,
        directionName: String,
        edge: MapOffscreenIndicatorEdge
    ) {
        if self.edge != edge {
            self.edge = edge
            setNeedsLayout()
        }

        let avatar = ProfileAvatar(rawValue: avatarID)
            ?? ProfileAvatar.cyclopsHorns
        avatarImageView.image = UIImage(named: avatar.assetName)
            ?? UIImage(systemName: "person.crop.circle.fill")
        avatarImageView.layer.borderColor = ProfileColor.uiColor(
            hex: profileColorHex
        ).cgColor

        baseAlpha = isLocationFresh ? 1 : 0.5
        alpha = baseAlpha * (isHighlighted ? 0.68 : 1)
        accessibilityLabel = "\(displayName), hors de la carte, direction \(directionName)"
        accessibilityValue = isLocationFresh
            ? "Position récente"
            : "Dernière position connue"
        accessibilityHint = "Touchez deux fois pour centrer cet ami sur la carte"
    }

    private func configureView() {
        backgroundColor = .clear
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityIdentifier = "friend-offscreen-indicator-\(userID)"

        avatarImageView.backgroundColor = .secondarySystemBackground
        avatarImageView.clipsToBounds = true
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.isAccessibilityElement = false
        avatarImageView.layer.borderWidth = 2.5
        addSubview(avatarImageView)

        addTarget(self, action: #selector(activate), for: .touchUpInside)
    }

    @objc private func activate() {
        onActivate?(userID)
    }
}

final class OutingOffscreenIndicatorView: UIControl {
    let eventID: String
    var onActivate: ((String) -> Void)?

    private let badgeView = OutingCategoryBadgeView()
    private var edge = MapOffscreenIndicatorEdge.top

    init(eventID: String) {
        self.eventID = eventID
        super.init(
            frame: CGRect(
                origin: .zero,
                size: CGSize(
                    width: MapOffscreenIndicatorLayout.controlSize,
                    height: MapOffscreenIndicatorLayout.controlSize
                )
            )
        )
        configureView()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isHighlighted: Bool {
        didSet {
            alpha = isHighlighted ? 0.68 : 1
        }
    }

    override func accessibilityActivate() -> Bool {
        activate()
        return true
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        badgeView.frame = MapOffscreenIndicatorLayout.visualFrame(
            in: bounds,
            edge: edge
        )
    }

    func configure(
        placeName: String,
        category: OutingCategory,
        profileColorHex: String,
        isCurrentUser: Bool,
        directionName: String,
        edge: MapOffscreenIndicatorEdge
    ) {
        if self.edge != edge {
            self.edge = edge
            setNeedsLayout()
        }

        badgeView.configure(
            category: category,
            profileColorHex: profileColorHex,
            isCurrentUser: isCurrentUser
        )
        accessibilityLabel = isCurrentUser
            ? "Votre sortie prévue, \(placeName), hors de la carte, direction \(directionName)"
            : "Sortie prévue, \(placeName), hors de la carte, direction \(directionName)"
        accessibilityValue = category.title
        accessibilityHint =
            "Touchez deux fois pour centrer et afficher la fiche de cette sortie"
    }

    private func configureView() {
        backgroundColor = .clear
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityIdentifier = "outing-offscreen-indicator-\(eventID)"

        addSubview(badgeView)
        addTarget(self, action: #selector(activate), for: .touchUpInside)
    }

    @objc private func activate() {
        onActivate?(eventID)
    }
}
