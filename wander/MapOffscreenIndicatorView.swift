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
    let pointerAngle: CGFloat
}

enum MapOffscreenIndicatorLayout {
    static let controlSize: CGFloat = 48
    static let visualSize: CGFloat = 28
    static let visualOverlapRatio: CGFloat = 0.30
    static let centerSeparation = visualSize * (1 - visualOverlapRatio)

    private static let edgeInset: CGFloat = 0

    static func visualFrame(in bounds: CGRect) -> CGRect {
        return CGRect(
            origin: CGPoint(
                x: (bounds.width - visualSize) / 2,
                y: (bounds.height - visualSize) / 2
            ),
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
                    directionName: directionName(for: direction),
                    targetPoint: candidate.targetPoint
                )
            )
        }

        let resolved = Dictionary(
            uniqueKeysWithValues: resolveCollisions(
                rawPlacements,
                in: indicatorBounds
            ).map { ($0.id, $0) }
        )

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
        in rect: CGRect
    ) -> [MapOffscreenIndicatorPlacement] {
        guard !placements.isEmpty else { return [] }

        let perimeterLength = 2 * (rect.width + rect.height)
        guard perimeterLength > 0 else { return [] }

        let positionedPlacements = placements.map { placement in
            PerimeterPlacement(
                rawPlacement: placement,
                position: perimeterPosition(
                    of: placement.center,
                    on: placement.edge,
                    in: rect
                )
            )
        }.sorted { lhs, rhs in
            if abs(lhs.position - rhs.position) > 0.5 {
                return lhs.position < rhs.position
            }
            return lhs.rawPlacement.id < rhs.rawPlacement.id
        }

        var largestGapStartIndex = 0
        var largestGap: CGFloat = -1
        for index in positionedPlacements.indices {
            let nextIndex = nextCircularIndex(
                after: index,
                in: positionedPlacements
            )
            var nextPosition = positionedPlacements[nextIndex].position
            if nextIndex == positionedPlacements.startIndex {
                nextPosition += perimeterLength
            }
            let gap = nextPosition - positionedPlacements[index].position
            if gap > largestGap {
                largestGap = gap
                largestGapStartIndex = index
            }
        }

        let cutPosition = normalizedPerimeterPosition(
            positionedPlacements[largestGapStartIndex].position
                + largestGap / 2,
            perimeterLength: perimeterLength
        )
        let orderedPlacements = positionedPlacements.sorted { lhs, rhs in
            let lhsPosition = normalizedPerimeterPosition(
                lhs.position - cutPosition,
                perimeterLength: perimeterLength
            )
            let rhsPosition = normalizedPerimeterPosition(
                rhs.position - cutPosition,
                perimeterLength: perimeterLength
            )
            if abs(lhsPosition - rhsPosition) > 0.5 {
                return lhsPosition < rhsPosition
            }
            return lhs.rawPlacement.id < rhs.rawPlacement.id
        }

        let separation = min(
            centerSeparation,
            perimeterLength / CGFloat(orderedPlacements.count)
        )
        let minimum = separation / 2
        let maximum = perimeterLength - separation / 2
        let preferredPositions = orderedPlacements.map {
            normalizedPerimeterPosition(
                $0.position - cutPosition,
                perimeterLength: perimeterLength
            )
        }
        var positions = preferredPositions.map {
            min(max($0, minimum), maximum)
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

        if let firstPosition = positions.first,
           let lastPosition = positions.last {
            let averageCorrection = zip(
                preferredPositions,
                positions
            ).reduce(CGFloat.zero) { partialResult, pair in
                partialResult + pair.0 - pair.1
            } / CGFloat(positions.count)
            let correction = min(
                max(averageCorrection, minimum - firstPosition),
                maximum - lastPosition
            )
            positions = positions.map { $0 + correction }
        }

        return zip(orderedPlacements, positions).map {
            positionedPlacement,
            position in
            let resolvedPosition = normalizedPerimeterPosition(
                cutPosition + position,
                perimeterLength: perimeterLength
            )
            let (center, edge) = pointAndEdge(
                at: resolvedPosition,
                in: rect
            )
            let targetPoint = positionedPlacement.rawPlacement.targetPoint
            let pointerAngle = atan2(
                targetPoint.y - center.y,
                targetPoint.x - center.x
            )

            return MapOffscreenIndicatorPlacement(
                id: positionedPlacement.rawPlacement.id,
                center: center,
                edge: edge,
                directionName: positionedPlacement.rawPlacement.directionName,
                pointerAngle: pointerAngle
            )
        }
    }

    private static func perimeterPosition(
        of point: CGPoint,
        on edge: MapOffscreenIndicatorEdge,
        in rect: CGRect
    ) -> CGFloat {
        switch edge {
        case .top:
            return point.x - rect.minX
        case .right:
            return rect.width + point.y - rect.minY
        case .bottom:
            return rect.width + rect.height + rect.maxX - point.x
        case .left:
            return 2 * rect.width + rect.height + rect.maxY - point.y
        }
    }

    private static func pointAndEdge(
        at position: CGFloat,
        in rect: CGRect
    ) -> (CGPoint, MapOffscreenIndicatorEdge) {
        if position <= rect.width {
            return (
                CGPoint(x: rect.minX + position, y: rect.minY),
                .top
            )
        }

        let rightPosition = position - rect.width
        if rightPosition <= rect.height {
            return (
                CGPoint(x: rect.maxX, y: rect.minY + rightPosition),
                .right
            )
        }

        let bottomPosition = rightPosition - rect.height
        if bottomPosition <= rect.width {
            return (
                CGPoint(x: rect.maxX - bottomPosition, y: rect.maxY),
                .bottom
            )
        }

        let leftPosition = bottomPosition - rect.width
        return (
            CGPoint(x: rect.minX, y: rect.maxY - leftPosition),
            .left
        )
    }

    private static func normalizedPerimeterPosition(
        _ position: CGFloat,
        perimeterLength: CGFloat
    ) -> CGFloat {
        let remainder = position.truncatingRemainder(
            dividingBy: perimeterLength
        )
        return remainder >= 0 ? remainder : remainder + perimeterLength
    }

    private static func nextCircularIndex<T>(
        after index: Array<T>.Index,
        in array: [T]
    ) -> Array<T>.Index {
        let nextIndex = array.index(after: index)
        if nextIndex == array.endIndex {
            return array.startIndex
        }
        return nextIndex
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
        let targetPoint: CGPoint
    }

    private struct PerimeterPlacement {
        let rawPlacement: RawPlacement
        let position: CGFloat
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
        isUserInteractionEnabled = false
        isAccessibilityElement = false

        symbolImageView.contentMode = .scaleAspectFit
        symbolImageView.isAccessibilityElement = false
        symbolImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            weight: .semibold
        )
        addSubview(symbolImageView)
    }
}

private final class MapOffscreenDirectionPointerLayer: CAShapeLayer {
    func setColor(_ color: UIColor) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fillColor = color.cgColor
        CATransaction.commit()
    }

    func update(
        in bounds: CGRect,
        angle: CGFloat,
        displayScale: CGFloat
    ) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        guard angle.isFinite else {
            path = nil
            return
        }

        let direction = CGPoint(x: cos(angle), y: sin(angle))
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let baseDistance = MapOffscreenIndicatorLayout.visualSize / 2 - 1.5
        let tipDistance = baseDistance + 7.5
        let baseHalfWidth: CGFloat = 5.5
        let perpendicular = CGPoint(x: -direction.y, y: direction.x)
        let baseCenter = CGPoint(
            x: center.x + direction.x * baseDistance,
            y: center.y + direction.y * baseDistance
        )
        let firstBasePoint = CGPoint(
            x: baseCenter.x + perpendicular.x * baseHalfWidth,
            y: baseCenter.y + perpendicular.y * baseHalfWidth
        )
        let secondBasePoint = CGPoint(
            x: baseCenter.x - perpendicular.x * baseHalfWidth,
            y: baseCenter.y - perpendicular.y * baseHalfWidth
        )
        let tip = CGPoint(
            x: center.x + direction.x * tipDistance,
            y: center.y + direction.y * tipDistance
        )

        let pointerPath = UIBezierPath()
        pointerPath.move(to: firstBasePoint)
        pointerPath.addLine(to: tip)
        pointerPath.addLine(to: secondBasePoint)
        pointerPath.close()

        contentsScale = displayScale
        frame = bounds
        path = pointerPath.cgPath
    }
}

final class FriendOffscreenIndicatorView: UIControl {
    let userID: String
    var onActivate: ((String) -> Void)?

    private let pointerLayer = MapOffscreenDirectionPointerLayer()
    private let avatarImageView = UIImageView()
    private var baseAlpha: CGFloat = 1
    private var pointerAngle: CGFloat = 0

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
            in: bounds
        )
        avatarImageView.layer.cornerRadius =
            MapOffscreenIndicatorLayout.visualSize / 2
        pointerLayer.update(
            in: bounds,
            angle: pointerAngle,
            displayScale: traitCollection.displayScale
        )
    }

    func configure(
        displayName: String,
        avatarID: String,
        profileColorHex: String,
        isLocationFresh: Bool,
        directionName: String,
        pointerAngle: CGFloat
    ) {
        if abs(self.pointerAngle - pointerAngle) > 0.001 {
            self.pointerAngle = pointerAngle
            setNeedsLayout()
        }

        let avatar = ProfileAvatar(rawValue: avatarID)
            ?? ProfileAvatar.cyclopsHorns
        avatarImageView.image = UIImage(named: avatar.assetName)
            ?? UIImage(systemName: "person.crop.circle.fill")
        let profileColor = ProfileColor.uiColor(
            hex: profileColorHex
        )
        avatarImageView.layer.borderColor = profileColor.cgColor
        pointerLayer.setColor(profileColor)

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

        layer.addSublayer(pointerLayer)

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

    private let pointerLayer = MapOffscreenDirectionPointerLayer()
    private let badgeView = OutingCategoryBadgeView()
    private var pointerAngle: CGFloat = 0

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

        pointerLayer.update(
            in: bounds,
            angle: pointerAngle,
            displayScale: traitCollection.displayScale
        )
        badgeView.frame = MapOffscreenIndicatorLayout.visualFrame(in: bounds)
    }

    func configure(
        placeName: String,
        category: OutingCategory,
        profileColorHex: String,
        isCurrentUser: Bool,
        directionName: String,
        pointerAngle: CGFloat
    ) {
        if abs(self.pointerAngle - pointerAngle) > 0.001 {
            self.pointerAngle = pointerAngle
            setNeedsLayout()
        }

        pointerLayer.setColor(ProfileColor.uiColor(hex: profileColorHex))
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

        layer.addSublayer(pointerLayer)
        addSubview(badgeView)
        addTarget(self, action: #selector(activate), for: .touchUpInside)
    }

    @objc private func activate() {
        onActivate?(eventID)
    }
}
