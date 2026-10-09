//
//  MapWithFogView.swift
//  wander
//
//  SwiftUI bridge around Mapbox with the exploration fog and social annotations.
//

import SwiftUI
import MapKit
import MapboxMaps
import CoreLocation
import UIKit.UIGestureRecognizerSubclass

final class PassiveMapTapObserver: UIGestureRecognizer {
    var onTouchBegan: ((CGPoint) -> Void)?
    var onTapEnded: ((CGPoint) -> Void)?
    var onTouchCancelled: (() -> Void)?

    private let maximumMovement: CGFloat
    private weak var trackedTouch: UITouch?
    private var initialPoint: CGPoint?

    init(maximumMovement: CGFloat) {
        self.maximumMovement = maximumMovement
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard trackedTouch == nil,
              touches.count == 1,
              let touch = touches.first,
              let view else {
            cancelTracking()
            return
        }

        trackedTouch = touch
        let point = touch.location(in: view)
        initialPoint = point
        onTouchBegan?(point)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let trackedTouch,
              touches.contains(trackedTouch),
              let view,
              let initialPoint else {
            return
        }

        let point = trackedTouch.location(in: view)
        guard hypot(
            point.x - initialPoint.x,
            point.y - initialPoint.y
        ) <= maximumMovement else {
            cancelTracking()
            return
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let trackedTouch,
              touches.contains(trackedTouch),
              let view,
              let initialPoint else {
            return
        }

        let point = trackedTouch.location(in: view)
        let stayedWithinTapTolerance = hypot(
            point.x - initialPoint.x,
            point.y - initialPoint.y
        ) <= maximumMovement
        self.trackedTouch = nil
        self.initialPoint = nil

        if stayedWithinTapTolerance {
            // This observer reports taps without recognizing a UIKit gesture.
            // Keep receiving touches while Mapbox resolves the same event sequence.
            onTapEnded?(point)
        } else {
            state = .failed
            onTouchCancelled?()
        }
    }

    override func touchesCancelled(
        _ touches: Set<UITouch>,
        with event: UIEvent
    ) {
        cancelTracking()
    }

    override func reset() {
        trackedTouch = nil
        initialPoint = nil
        super.reset()
    }

    override func canPrevent(
        _ preventedGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        false
    }

    override func canBePrevented(
        by preventingGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        false
    }

    private func cancelTracking() {
        guard trackedTouch != nil || initialPoint != nil else {
            state = .failed
            return
        }
        trackedTouch = nil
        initialPoint = nil
        onTouchCancelled?()
        state = .failed
    }
}

struct MapUserPresenceInfo: Equatable {
    let displayName: String
    let relationshipText: String
    let locationSampledAt: Date?
    let spotEnteredAt: Date?
    let isLocationFresh: Bool
    let keepsSpotDurationVisible: Bool
}

struct FriendNavigationDestination: Equatable {
    let userID: String
    let displayName: String
    let coordinate: MapUserCoordinate
    let sampledAt: Date
}

struct MapUserCoordinate: Equatable {
    let latitude: CLLocationDegrees
    let longitude: CLLocationDegrees

    init(_ coordinate: CLLocationCoordinate2D) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var cacheKey: NSString {
        let roundedLatitude = Int((latitude * 10_000).rounded())
        let roundedLongitude = Int((longitude * 10_000).rounded())
        return "\(roundedLatitude):\(roundedLongitude)" as NSString
    }
}

/// Shared normalization and bounded cache for the map's address presentations.
@MainActor
enum MapProfileAddress {
    static let cache: NSCache<NSString, NSString> = {
        let cache = NSCache<NSString, NSString>()
        cache.countLimit = 200
        return cache
    }()
    static func formattedAddress(
        from mapItems: [MKMapItem]?
    ) -> String? {
        for mapItem in mapItems ?? [] {
            let rawAddress = mapItem.addressRepresentations?.fullAddress(
                includingRegion: true,
                singleLine: true
            ) ?? mapItem.address?.fullAddress

            let address = rawAddress?
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: ", ")

            if let address, !address.isEmpty {
                return address
            }
        }

        return nil
    }

}

struct MapOutingPlan: Equatable {
    let plan: OutingPlan
    let organizer: MapOutingAttendee
    let profileColorHex: String
    let isCurrentUser: Bool
    let rosterState: OutingAttendanceRosterState
    let participationState: OutingAttendanceParticipationState
    let attendees: [MapOutingAttendee]
    let declines: [MapOutingAttendee]
    let isAttendanceUpdating: Bool

    var isCurrentUserAttending: Bool {
        participationState == .attending
    }

    var visiblePeople: [MapOutingAttendee] {
        var seenUserIDs: Set<String> = []
        return ([organizer] + attendees).filter {
            seenUserIDs.insert($0.userID).inserted
        }
    }

    var visibleDeclines: [MapOutingAttendee] {
        let attendingUserIDs = Set(visiblePeople.map(\.userID))
        var seenUserIDs: Set<String> = []
        return declines.filter {
            !attendingUserIDs.contains($0.userID)
                && seenUserIDs.insert($0.userID).inserted
        }
    }
}

struct MapOutingAttendee: Identifiable, Equatable {
    let userID: String
    let displayName: String
    let avatarID: String

    var id: String { userID }
}

final class UserLocationAnnotation: MapAnnotation {}

final class FriendLocationAnnotation: MapAnnotation {
    var userID = ""
}

fileprivate final class OutingPlanAnnotation: MapAnnotation {
    var eventID = ""
    var profileColorHex = ""
    var isCurrentUser = false
    var category = OutingCategory.other
    var participantAvatarIDs: [String] = []

    var participantCount: Int {
        participantAvatarIDs.count
    }
}

fileprivate final class DraftOutingAnnotation: MapAnnotation {}

private final class DraftOutingAnnotationView: MapAnnotationView {
    override init(annotation: MapAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    private func configureView() {
        bounds = CGRect(x: 0, y: 0, width: 44, height: 52)
        centerOffset = CGSize(width: 0, height: -26)
        let image = UIImageView(image: UIImage(
            systemName: "mappin.circle.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 36, weight: .medium)
        ))
        image.tintColor = .systemRed
        image.contentMode = .scaleAspectFit
        image.frame = bounds
        image.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(image)
        isAccessibilityElement = true
        accessibilityLabel = "Lieu du nouvel événement"
        accessibilityHint = "Ce pin indique le lieu qui sera publié."
        accessibilityTraits = .image
    }
}

private final class OutingPlanAnnotationView: MapAnnotationView {
    static let reuseIdentifier = "OutingPlanAnnotation"
    static let controlSize: CGFloat = 48
    static let visualSize: CGFloat = 40
    static let annotationCenterOffset = CGPoint(x: 0, y: -20)

    private let badgeView = OutingCategoryBadgeView()
    private var isSocialClusterFocused = false

    override init(annotation: MapAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        isSocialClusterFocused = false
        applySocialClusterPresentation()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        badgeView.frame = CGRect(
            x: (bounds.width - Self.visualSize) / 2,
            y: (bounds.height - Self.visualSize) / 2,
            width: Self.visualSize,
            height: Self.visualSize
        )
    }

    func configure(with annotation: OutingPlanAnnotation) {
        badgeView.configure(
            category: annotation.category,
            profileColorHex: annotation.profileColorHex,
            isCurrentUser: annotation.isCurrentUser,
            participantAvatarIDs: annotation.participantAvatarIDs
        )
        applySocialClusterPresentation()

        let placeName = annotation.title ?? "Lieu sans nom"
        let outingLabel = annotation.isCurrentUser
            ? "Votre sortie prévue, \(placeName)"
            : "Sortie prévue, \(placeName)"
        accessibilityLabel = outingLabel
            + Self.participantAccessibilitySuffix(
                count: annotation.participantCount
            )
        accessibilityHint = "Touchez deux fois pour afficher la fiche de la sortie."
    }

    private func configureView() {
        frame = CGRect(
            origin: .zero,
            size: CGSize(
                width: Self.controlSize,
                height: Self.controlSize
            )
        )
        bounds = CGRect(
            origin: .zero,
            size: CGSize(
                width: Self.controlSize,
                height: Self.controlSize
            )
        )
        centerOffset = CGSize(
            width: Self.annotationCenterOffset.x, height: Self.annotationCenterOffset.y
        )
        backgroundColor = .clear
        clipsToBounds = false
        isAccessibilityElement = true
        accessibilityTraits = .button
        addSubview(badgeView)
        setNeedsLayout()
    }

    func setSocialClusterFocus(_ isFocused: Bool) {
        guard isSocialClusterFocused != isFocused else { return }
        isSocialClusterFocused = isFocused
        applySocialClusterPresentation()
    }

    private func applySocialClusterPresentation() {
        centerOffset = CGSize(
            width: Self.annotationCenterOffset.x, height: Self.annotationCenterOffset.y
        )
    }

    static func projectedFrame(at anchorPoint: CGPoint) -> CGRect {
        CGRect(
            x: anchorPoint.x + annotationCenterOffset.x - controlSize / 2,
            y: anchorPoint.y + annotationCenterOffset.y - controlSize / 2,
            width: controlSize,
            height: controlSize
        )
    }

    private static func participantAccessibilitySuffix(count: Int) -> String {
        guard count > 0 else { return ", participants indisponibles" }
        return count == 1
            ? ", organisateur seul"
            : ", \(count) personnes participent"
    }
}

private final class UserPinBackgroundView: UIView {
    private let shapeLayer = CAShapeLayer()

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

        let circleRect = CGRect(x: 0, y: 0, width: 44, height: 44)
        let path = UIBezierPath(ovalIn: circleRect)

        shapeLayer.frame = bounds
        shapeLayer.path = path.cgPath
        shapeLayer.shadowPath = path.cgPath
    }

    func setColor(_ color: UIColor) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shapeLayer.fillColor = color.cgColor
        CATransaction.commit()
    }

    private func configureView() {
        backgroundColor = .clear
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true

        shapeLayer.fillColor = UIColor.white.cgColor
        shapeLayer.shadowColor = UIColor.black.cgColor
        shapeLayer.shadowOpacity = 0.22
        shapeLayer.shadowRadius = 3
        shapeLayer.shadowOffset = CGSize(width: 0, height: 2)
        layer.addSublayer(shapeLayer)
    }
}

private final class CircularPresenceTextView: UIView {
    var text: String? {
        didSet {
            guard text != oldValue else { return }
            setNeedsDisplay()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    override func draw(_ rect: CGRect) {
        guard let text, !text.isEmpty else { return }

        let baseFont = UIFont.systemFont(ofSize: 11, weight: .bold)
        let font = baseFont.fontDescriptor.withDesign(.rounded).map {
            UIFont(descriptor: $0, size: 11)
        } ?? baseFont
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.label,
            .strokeColor: UIColor.systemBackground.withAlphaComponent(0.94),
            .strokeWidth: -4,
            .kern: 0.25
        ]
        let unit = "\(text)  •  "
        let unitWidth = max(
            1,
            (unit as NSString).size(withAttributes: attributes).width
        )
        let radius = min(bounds.width, bounds.height) / 2
            - font.lineHeight * 0.56
            - 3
        guard radius > 0 else { return }

        let circumference = 2 * CGFloat.pi * radius
        let repeatCount = max(2, Int((circumference / unitWidth).rounded()))
        let circularText = String(repeating: unit, count: repeatCount)
        let glyphs = circularText.map(String.init)
        let glyphWidths = glyphs.map {
            max(1, ($0 as NSString).size(withAttributes: attributes).width)
        }
        let totalWidth = glyphWidths.reduce(0, +)
        guard totalWidth > 0 else { return }

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radiansPerPoint = 2 * CGFloat.pi / totalWidth
        var angle = -CGFloat.pi / 2

        guard let context = UIGraphicsGetCurrentContext() else { return }
        for (glyph, glyphWidth) in zip(glyphs, glyphWidths) {
            let advance = glyphWidth * radiansPerPoint
            angle += advance / 2

            let glyphCenter = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            let drawingPoint = CGPoint(
                x: -glyphWidth / 2,
                y: -font.lineHeight / 2
            )

            context.saveGState()
            context.translateBy(x: glyphCenter.x, y: glyphCenter.y)
            context.rotate(by: angle + CGFloat.pi / 2)
            (glyph as NSString).draw(at: drawingPoint, withAttributes: attributes)
            context.restoreGState()

            angle += advance / 2
        }
    }

    private func configureView() {
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        contentMode = .redraw
    }
}

final class UserLocationAnnotationView: MapAnnotationView {
    static let reuseIdentifier = "UserLocationAnnotation"
    static let friendReuseIdentifier = "FriendLocationAnnotation"

    private static let controlSize: CGFloat = 48
    private static let presenceVisualSize: CGFloat = 88
    private static let pinVisualSize: CGFloat = 44
    private static let avatarVisualSize: CGFloat = 36

    private let circularPresenceTextView = CircularPresenceTextView()
    private let pinBackgroundView = UserPinBackgroundView()
    private let avatarImageView = UIImageView()
    private let locationRefreshIndicator = UIActivityIndicatorView(style: .medium)
    private var configuredAvatarID: String?
    private var configuredPresenceInfo: MapUserPresenceInfo?
    private var configuredIsRefreshingLocation = false
    private var isSocialClusterFocused = false
    private var presenceRefreshTimer: Timer?
    override init(annotation: MapAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        circularPresenceTextView.frame = CGRect(
            x: (bounds.width - Self.presenceVisualSize) / 2,
            y: (bounds.height - Self.presenceVisualSize) / 2,
            width: Self.presenceVisualSize,
            height: Self.presenceVisualSize
        )
        pinBackgroundView.frame = CGRect(
            x: (bounds.width - Self.pinVisualSize) / 2,
            y: (bounds.height - Self.pinVisualSize) / 2,
            width: Self.pinVisualSize,
            height: Self.pinVisualSize
        )
        avatarImageView.frame = CGRect(
            x: (Self.pinVisualSize - Self.avatarVisualSize) / 2,
            y: (Self.pinVisualSize - Self.avatarVisualSize) / 2,
            width: Self.avatarVisualSize,
            height: Self.avatarVisualSize
        )
        avatarImageView.layer.cornerRadius = Self.avatarVisualSize / 2
        locationRefreshIndicator.frame = avatarImageView.frame
        locationRefreshIndicator.layer.cornerRadius =
            Self.avatarVisualSize / 2
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        stopPresenceRefreshTimer()
        configuredPresenceInfo = nil
        configuredIsRefreshingLocation = false
        configuredAvatarID = nil
        isSocialClusterFocused = false
        avatarImageView.image = nil
        avatarImageView.alpha = 1
        locationRefreshIndicator.stopAnimating()
        circularPresenceTextView.text = nil
        applySocialClusterPresentation()
    }

    deinit {
        presenceRefreshTimer?.invalidate()
    }

    fileprivate func configure(
        avatarID: String,
        profileColorHex: String,
        presenceInfo: MapUserPresenceInfo,
        isRefreshingLocation: Bool = false
    ) {
        let refreshStateChanged = configuredIsRefreshingLocation
            != isRefreshingLocation
        configuredIsRefreshingLocation = isRefreshingLocation

        let resolvedAvatar = ProfileAvatar(rawValue: avatarID)
            ?? ProfileAvatar.cyclopsHorns
        if configuredAvatarID != resolvedAvatar.id {
            avatarImageView.image = UIImage(named: resolvedAvatar.assetName)
                ?? UIImage(systemName: "person.crop.circle.fill")
            configuredAvatarID = resolvedAvatar.id
        }
        pinBackgroundView.setColor(
            ProfileColor.uiColor(hex: profileColorHex)
        )
        avatarImageView.alpha = isRefreshingLocation ? 0.3 : 1
        if isRefreshingLocation {
            locationRefreshIndicator.startAnimating()
        } else {
            locationRefreshIndicator.stopAnimating()
        }

        if configuredPresenceInfo != presenceInfo
            || refreshStateChanged {
            configuredPresenceInfo = presenceInfo
            pinBackgroundView.alpha = presenceInfo.isLocationFresh ? 1 : 0.5
            refreshPresencePresentation()
            accessibilityLabel = "\(presenceInfo.displayName), \(presenceInfo.relationshipText)"
            accessibilityValue = isRefreshingLocation
                ? "Actualisation de la position en cours"
                : Self.locationAccessibilityText(for: presenceInfo)
            accessibilityTraits = .button
        }
    }

    private static func locationAccessibilityText(
        for info: MapUserPresenceInfo
    ) -> String? {
        let presenceSampledAt = info.isLocationFresh
            ? info.locationSampledAt
            : nil
        return presenceText(
            enteredAt: info.spotEnteredAt,
            sampledAt: presenceSampledAt,
            relativeTo: Date(),
            keepsSpotDurationVisible: info.keepsSpotDurationVisible
        ) ?? locationText(sampledAt: info.locationSampledAt)
    }

    private func ensurePresenceRefreshTimer() {
        guard presenceRefreshTimer == nil else { return }

        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.refreshPresencePresentation()
        }
        RunLoop.main.add(timer, forMode: .common)
        presenceRefreshTimer = timer
    }

    private func stopPresenceRefreshTimer() {
        presenceRefreshTimer?.invalidate()
        presenceRefreshTimer = nil
    }

    private func refreshPresencePresentation() {
        guard let configuredPresenceInfo else {
            circularPresenceTextView.text = nil
            stopPresenceRefreshTimer()
            return
        }

        let circularText = configuredPresenceInfo.isLocationFresh
            && !isSocialClusterFocused
            ? Self.circularDurationText(
                enteredAt: configuredPresenceInfo.spotEnteredAt,
                sampledAt: configuredPresenceInfo.locationSampledAt,
                relativeTo: Date(),
                keepsSpotDurationVisible:
                    configuredPresenceInfo.keepsSpotDurationVisible
            )
            : nil
        circularPresenceTextView.text = circularText
        circularPresenceTextView.isHidden = circularText == nil
        accessibilityValue = Self.locationAccessibilityText(
            for: configuredPresenceInfo
        )

        if circularText == nil {
            stopPresenceRefreshTimer()
        } else {
            ensurePresenceRefreshTimer()
        }
    }

    private func configureView() {
        frame = CGRect(
            origin: .zero,
            size: CGSize(
                width: Self.controlSize,
                height: Self.controlSize
            )
        )
        bounds = CGRect(
            origin: .zero,
            size: CGSize(
                width: Self.controlSize,
                height: Self.controlSize
            )
        )
        centerOffset = .zero
        backgroundColor = .clear
        clipsToBounds = false
        isAccessibilityElement = true

        circularPresenceTextView.isHidden = true
        addSubview(circularPresenceTextView)

        addSubview(pinBackgroundView)

        avatarImageView.clipsToBounds = true
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.isAccessibilityElement = false
        pinBackgroundView.addSubview(avatarImageView)

        locationRefreshIndicator.hidesWhenStopped = true
        locationRefreshIndicator.color = .label
        locationRefreshIndicator.backgroundColor = UIColor.systemBackground
            .withAlphaComponent(0.72)
        locationRefreshIndicator.isAccessibilityElement = false
        pinBackgroundView.addSubview(locationRefreshIndicator)

        setNeedsLayout()
    }

    func setSocialClusterFocus(_ isFocused: Bool) {
        guard isSocialClusterFocused != isFocused else { return }
        isSocialClusterFocused = isFocused
        applySocialClusterPresentation()
        refreshPresencePresentation()
    }

    private func applySocialClusterPresentation() {
        centerOffset = .zero
    }

    private static func locationText(sampledAt: Date?) -> String? {
        guard let sampledAt else { return nil }

        if Calendar.autoupdatingCurrent.isDateInToday(sampledAt) {
            return "Dernière position reçue à \(positionTimeFormatter.string(from: sampledAt))"
        }

        return "Dernière position reçue le \(positionDateTimeFormatter.string(from: sampledAt))"
    }

    private static func presenceText(
        enteredAt: Date?,
        sampledAt: Date?,
        relativeTo referenceDate: Date,
        keepsSpotDurationVisible: Bool
    ) -> String? {
        guard let duration = presenceDuration(
            enteredAt: enteredAt,
            sampledAt: sampledAt,
            relativeTo: referenceDate,
            keepsSpotDurationVisible: keepsSpotDurationVisible
        ) else { return nil }
        return "Au même endroit depuis \(FriendPresenceFormatting.durationText(duration))"
    }

    private static func circularDurationText(
        enteredAt: Date?,
        sampledAt: Date?,
        relativeTo referenceDate: Date,
        keepsSpotDurationVisible: Bool
    ) -> String? {
        guard let duration = presenceDuration(
            enteredAt: enteredAt,
            sampledAt: sampledAt,
            relativeTo: referenceDate,
            keepsSpotDurationVisible: keepsSpotDurationVisible
        ) else { return nil }

        let totalMinutes = max(0, Int(duration / 60))
        guard totalMinutes > 0 else { return "<1 MIN" }

        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60

        if days > 0 {
            return hours > 0 ? "\(days) J \(hours) H" : "\(days) J"
        }
        if hours > 0 {
            return minutes > 0
                ? "\(hours) H \(minutes) MIN"
                : "\(hours) H"
        }
        return "\(minutes) MIN"
    }

    private static func presenceDuration(
        enteredAt: Date?,
        sampledAt: Date?,
        relativeTo referenceDate: Date,
        keepsSpotDurationVisible: Bool
    ) -> TimeInterval? {
        guard let enteredAt, let sampledAt else { return nil }

        let sampleAge = referenceDate.timeIntervalSince(sampledAt)
        guard sampleAge >= -maximumFutureTimestampSkew,
              (keepsSpotDurationVisible || sampleAge < maximumPresenceSampleAge),
              enteredAt <= sampledAt else {
            return nil
        }
        return max(0, referenceDate.timeIntervalSince(enteredAt))
    }

    private static let maximumPresenceSampleAge: TimeInterval = 5 * 60
    private static let maximumFutureTimestampSkew: TimeInterval = 60

    private static let positionTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeStyle = .short
        return formatter
    }()

    private static let positionDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

struct MapWithFogView: UIViewRepresentable {
    @Environment(\.mapRenderSize) private var mapRenderSize
    @Environment(\.mapContentInsets) private var mapContentInsets
    @Environment(\.layoutDirection) private var layoutDirection
    @ObservedObject var locationTracker: LocationTracker

    /// Set of H3 cell IDs that should be punched through the fog.
    var discoveredCellIDs: Set<String>

    /// City boundary used only for the initial map fit. Fog is global.
    var cityBoundaryCoordinates: [CLLocationCoordinate2D]

    /// Last known locations belonging to accepted friends.
    var friendLocations: [String: FriendLocation] = [:]

    /// Friends whose last known location is still recent.
    var freshFriendLocationUserIDs: Set<String> = []

    /// Friends currently waiting for an on-demand location update.
    var refreshingFriendLocationUserIDs: Set<String> = []

    /// Events belonging to the account and accepted friends, keyed by event ID.
    var outingPlans: [String: MapOutingPlan] = [:]

    var userDisplayName = ""
    var userAvatarID = ""
    var userProfileColorHex = ""

    /// Fog colour — used by the polygon renderer.
    var fogColor: UIColor = UIColor.black.withAlphaComponent(0.22)

    /// Restores the local zoom and follows new positions until the next map gesture.
    @Binding var centerOnUser: Bool

    /// When toggled, resets the map camera to a north-up, flat orientation.
    @Binding var resetMapOrientation: Bool

    /// When set, centers the map on the selected friend once.
    @Binding var centerOnFriendUserID: String?

    /// When set, centers and selects one event once.
    @Binding var centerOnOutingPlanEventID: String?

    /// Coordinate selected for an event that has not been published yet.
    var pendingOutingCoordinate: CLLocationCoordinate2D?

    /// Whether a long press may start another event creation flow.
    var isEventCreationEnabled = true

    /// Event whose information is visible above the map.
    var selectedOutingPlanEventID: String?

    /// Personal or friend profile visible above the map.
    var selectedMapProfile: MapProfileSelection?

    /// One-shot framing from prepared sheet geometry, or when closing the profile.
    var friendCameraRequest: MapFriendCameraRequest?

    /// Opens the personal map profile.
    var onSelectOwnProfile: () -> Void = {}

    /// Opens the profile and requests a location update when a friend is selected.
    var onSelectFriend: (String) -> Void = { _ in }

    /// Presents the information for the selected outing.
    var onSelectOutingPlan: (String) -> Void = { _ in }

    /// Hides the detail card when that outing is deselected.
    var onDeselectOutingPlan: (String) -> Void = { _ in }

    /// Creates a new event from a long press on an empty point of the map.
    var onCreateEvent: (CLLocationCoordinate2D) -> Void = { _ in }

    func makeUIView(context: Context) -> MapViewportView {
        let mapView = MapboxConfiguration.makeMapView()
        if let mapRenderSize,
           mapRenderSize.width.isFinite, mapRenderSize.height.isFinite,
           mapRenderSize.width > 0, mapRenderSize.height > 0 {
            mapView.frame = CGRect(origin: .zero, size: mapRenderSize)
            mapView.layoutIfNeeded()
        }
        context.coordinator.install(on: mapView)
        // LocationTracker owns GPS updates and permission prompts.
        mapView.location.options.puckType = nil
        mapView.ornaments.options.compass.visibility = .visible
        mapView.accessibilityIdentifier = "exploration-map-canvas"
        mapView.accessibilityLabel = "Carte d’exploration"
        mapView.accessibilityHint =
            "Maintenez un doigt sur un endroit vide pour créer un événement."

        context.coordinator.installLongPressRecognizer(on: mapView)
        context.coordinator.installImmediateSocialAnnotationRecognizer(
            on: mapView
        )
        context.coordinator.installMapOffscreenIndicatorContainer(
            on: mapView
        )

        context.coordinator.fogRenderer.update(cellIDs: visibleDiscoveredCellIDs)
        let viewport = MapViewportView(
            mapView: mapView,
            renderSize: mapRenderSize,
            contentInsets: viewportContentInsets
        )
        viewport.tracksSheetPresentation = selectedMapProfile != nil || !isEventCreationEnabled
        let coordinator = context.coordinator
        coordinator.viewport = viewport
        coordinator.edgeZoom = MapEdgeZoomController(
            viewport: viewport,
            targets: { [weak coordinator] mapView in
                coordinator?.edgeZoomTargets(on: mapView) ?? []
            },
            onBegin: { [weak coordinator] in
                coordinator?.friendCamera.cancel()
                coordinator?.userCamera.stopFollowing()
            }
        )
        viewport.onViewportChange = { [weak coordinator, weak mapView] in
            guard let coordinator, let mapView else { return }
            coordinator.edgeZoom?.cancel()
            coordinator.friendCamera.cancel()
            coordinator.socialProximityController.viewportDidChange(on: mapView)
            coordinator.refreshMapOffscreenIndicators(on: mapView)
            coordinator.applyPendingCameraUpdate()
        }
        return viewport
    }

    func updateUIView(_ viewport: MapViewportView, context: Context) {
        viewport.renderSize = mapRenderSize
        viewport.contentInsets = viewportContentInsets
        viewport.tracksSheetPresentation = selectedMapProfile != nil || !isEventCreationEnabled
        let uiView = viewport.mapView
        context.coordinator.onSelectOwnProfile = onSelectOwnProfile
        context.coordinator.onSelectFriend = onSelectFriend
        context.coordinator.refreshingFriendUserIDs =
            refreshingFriendLocationUserIDs
        context.coordinator.onSelectOutingPlan = onSelectOutingPlan
        context.coordinator.onDeselectOutingPlan = onDeselectOutingPlan
        context.coordinator.onCreateEvent = onCreateEvent
        context.coordinator.setEventCreationEnabled(isEventCreationEnabled)
        uiView.accessibilityHint = isEventCreationEnabled
            ? "Maintenez un doigt sur un endroit vide pour créer un événement."
            : "Le lieu du nouvel événement est indiqué par un pin."

        context.coordinator.fogRenderer.update(cellIDs: visibleDiscoveredCellIDs)

        updateFriendAnnotations(on: uiView, context: context)
        updateUserLocationAnnotation(on: uiView, context: context)
        updateOutingPlanAnnotations(on: uiView, context: context)
        context.coordinator.synchronizeSocialProximityAnnotations(on: uiView)
        updateDraftOutingAnnotation(on: uiView, context: context)
        context.coordinator.refreshMapOffscreenIndicators(on: uiView)
        synchronizeDetailSelection(on: uiView, context: context)

        scheduleCameraUpdate(in: viewport, coordinator: context.coordinator)
    }

    func scheduleCameraUpdate(in viewport: MapViewportView, coordinator: Coordinator) {
        coordinator.pendingCameraUpdate = { [weak viewport, weak coordinator] in
            guard let viewport, let coordinator else { return true }
            return updateCamera(in: viewport, coordinator: coordinator)
        }
        coordinator.applyPendingCameraUpdate()
    }

    private func updateCamera(in viewport: MapViewportView, coordinator: Coordinator) -> Bool {
        let uiView = viewport.mapView
        guard MapUserCameraController.hasUsableBounds(on: uiView) else { return false }
        uiView.layoutIfNeeded()

        // A loaded city boundary is only a temporary starting region. Always
        // let the first valid user location take precedence, then leave later
        // camera movement under the user's control.
        if let coordinate = locationTracker.lastLocation?.coordinate,
           CLLocationCoordinate2DIsValid(coordinate),
           !coordinator.didCenterOnUser {
            // The initial view can have a size before Mapbox's animation runner has a window.
            setFocusedRegion(on: uiView, center: coordinate, animated: false)
            coordinator.didCenterOnUser = true
            coordinator.didSetInitialRegion = true
        } else if !coordinator.didSetInitialRegion,
                  cityBoundaryCoordinates.count >= 3 {
            guard fitCityBoundary(on: uiView) else { return false }
            coordinator.didSetInitialRegion = true
        }

        if centerOnUser,
           let coordinate = locationTracker.lastLocation?.coordinate,
           CLLocationCoordinate2DIsValid(coordinate),
           !coordinator.isConsumingRecenterRequest {
            coordinator.friendCamera.cancel()
            coordinator.isConsumingRecenterRequest = true
            DispatchQueue.main.async {
                centerOnUser = false
                coordinator.isConsumingRecenterRequest = false
            }
            coordinator.userCamera.recenter(on: uiView, at: coordinate)
        }

        if resetMapOrientation {
            coordinator.friendCamera.cancel()
            DispatchQueue.main.async { resetMapOrientation = false }
            resetCameraOrientation(on: uiView)
        }

        if let friendUserID = centerOnFriendUserID {
            coordinator.friendCamera.cancel()
            DispatchQueue.main.async { centerOnFriendUserID = nil }
            centerMap(
                onFriend: friendUserID,
                on: uiView,
                friendLocations: friendLocations,
                coordinator: coordinator
            )
        }

        if let outingEventID = centerOnOutingPlanEventID {
            coordinator.friendCamera.cancel()
            DispatchQueue.main.async { centerOnOutingPlanEventID = nil }
            centerMap(
                onOutingPlan: outingEventID,
                on: uiView,
                coordinator: coordinator
            )
        }

        if let coordinate = locationTracker.lastLocation?.coordinate {
            coordinator.userCamera.updateLocation(coordinate, on: uiView)
        }

        if let request = friendCameraRequest {
            let coordinate: CLLocationCoordinate2D?
            switch request.target {
            case .currentUser:
                coordinate = locationTracker.lastLocation?.coordinate
            case .friend(let userID):
                coordinate = friendLocations[userID]?.coordinate
            }
            let matchesSelection = request.sheetTopInWindow != nil
                ? selectedMapProfile == request.target
                : selectedMapProfile == nil && selectedOutingPlanEventID == nil
            coordinator.applyFriendCameraRequest(
                request,
                coordinate: coordinate,
                viewport: viewport,
                isAllowed: matchesSelection && isEventCreationEnabled
                    && !centerOnUser && !resetMapOrientation
                    && centerOnFriendUserID == nil && centerOnOutingPlanEventID == nil
            )
        }
        return true
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            fogColor: fogColor,
            onSelectFriend: onSelectFriend,
            onSelectOutingPlan: onSelectOutingPlan,
            onDeselectOutingPlan: onDeselectOutingPlan,
            onCreateEvent: onCreateEvent
        )
    }

    static func dismantleUIView(_ viewport: MapViewportView, coordinator: Coordinator) {
        viewport.stopTrackingSheetPresentation()
        viewport.onViewportChange = nil
        coordinator.pendingCameraUpdate = nil
        coordinator.edgeZoom?.uninstall()
        coordinator.edgeZoom = nil
        let uiView = viewport.mapView
        coordinator.removeLongPressRecognizer(from: uiView)
        coordinator.removeImmediateSocialAnnotationRecognizer(from: uiView)
        coordinator.removeMapOffscreenIndicatorContainer()
        coordinator.friendCamera.cancel()
        coordinator.userCamera.stopFollowing()
        coordinator.socialProximityController.tearDown()
        coordinator.annotationStore.removeAll()
        coordinator.mapSubscriptions.removeAll()
        coordinator.fogRenderer.tearDown()
        coordinator.fogRenderer = nil
        uiView.gestures.delegate = nil
    }

    private var viewportContentInsets: UIEdgeInsets {
        UIEdgeInsets(
            top: mapContentInsets.top,
            left: layoutDirection == .leftToRight ? mapContentInsets.leading : mapContentInsets.trailing,
            bottom: mapContentInsets.bottom,
            right: layoutDirection == .leftToRight ? mapContentInsets.trailing : mapContentInsets.leading
        )
    }

    private var visibleDiscoveredCellIDs: Set<String> {
        discoveredCellIDs
    }

    // MARK: - User location

    private func updateUserLocationAnnotation(on mapView: MapboxMaps.MapView, context: Context) {
        let coordinator = context.coordinator
        let trimmedDisplayName = userDisplayName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let resolvedDisplayName = trimmedDisplayName.isEmpty
            ? "Explorer"
            : trimmedDisplayName
        let presenceInfo = MapUserPresenceInfo(
            displayName: resolvedDisplayName,
            relationshipText: "Vous",
            locationSampledAt: locationTracker.lastLocation?.timestamp,
            spotEnteredAt: locationTracker.currentSpotEnteredAt,
            isLocationFresh: true,
            keepsSpotDurationVisible:
                locationTracker.trackingEnabled && locationTracker.isTracking
        )
        coordinator.updateUserMarkerAppearance(
            displayName: resolvedDisplayName,
            avatarID: userAvatarID,
            profileColorHex: userProfileColorHex,
            presenceInfo: presenceInfo,
            on: mapView
        )

        let nextUserCoordinate = locationTracker.lastLocation?.coordinate

        guard let coordinate = nextUserCoordinate,
              CLLocationCoordinate2DIsValid(coordinate) else {
            coordinator.userLocationAnnotation = nil
            return
        }

        let annotation: UserLocationAnnotation
        if let existing = coordinator.userLocationAnnotation {
            annotation = existing
            annotation.coordinate = coordinate
        } else {
            annotation = UserLocationAnnotation()
            annotation.coordinate = coordinate
            annotation.title = resolvedDisplayName
            coordinator.userLocationAnnotation = annotation
        }

        annotation.title = resolvedDisplayName
        annotation.subtitle = nil

    }

    // MARK: - Friend annotations

    private func updateFriendAnnotations(
        on mapView: MapboxMaps.MapView,
        context: Context
    ) {
        let coordinator = context.coordinator

        // Remove annotations only when the friendship or shared location disappears.
        let currentIDs = Set(friendLocations.keys)
        let removedIDs = coordinator.friendAnnotations.keys
            .filter { !currentIDs.contains($0) }
            .sorted()
        for userID in removedIDs {
            coordinator.friendAnnotations.removeValue(forKey: userID)
            coordinator.friendAvatarIDByUserID.removeValue(forKey: userID)
            coordinator.friendProfileColorHexByUserID.removeValue(forKey: userID)
            coordinator.friendPresenceInfoByUserID.removeValue(forKey: userID)
        }

        // Incrementally add or move annotations for accepted friends' last locations.
        for userID in friendLocations.keys.sorted() {
            guard let friendLocation = friendLocations[userID] else { continue }

            coordinator.friendAvatarIDByUserID[friendLocation.userID] =
                friendLocation.avatarID
            coordinator.friendProfileColorHexByUserID[friendLocation.userID] =
                friendLocation.profileColorHex
            let isLocationFresh = freshFriendLocationUserIDs.contains(
                friendLocation.userID
            )
            let presenceInfo = MapUserPresenceInfo(
                displayName: friendLocation.displayName,
                relationshipText: "Ami",
                locationSampledAt: friendLocation.sampledAt,
                spotEnteredAt: friendLocation.spotEnteredAt,
                isLocationFresh: isLocationFresh,
                keepsSpotDurationVisible: isLocationFresh
            )
            coordinator.friendPresenceInfoByUserID[friendLocation.userID] = presenceInfo

            if let existing = coordinator.friendAnnotations[friendLocation.userID] {
                if existing.coordinate.latitude != friendLocation.coordinate.latitude
                    || existing.coordinate.longitude != friendLocation.coordinate.longitude {
                    existing.coordinate = friendLocation.coordinate
                }

                existing.title = friendLocation.displayName
                existing.subtitle = nil
                if let annotationView = coordinator.annotationStore.view(for: existing) {
                    coordinator.configureFriendAnnotationView(
                        annotationView,
                        avatarID: friendLocation.avatarID,
                        profileColorHex: friendLocation.profileColorHex,
                        presenceInfo: presenceInfo,
                        isRefreshingLocation: refreshingFriendLocationUserIDs
                            .contains(friendLocation.userID)
                    )
                }
            } else {
                let annotation = FriendLocationAnnotation()
                annotation.userID = friendLocation.userID
                annotation.coordinate = friendLocation.coordinate
                annotation.title = friendLocation.displayName
                annotation.subtitle = nil
                coordinator.friendAnnotations[friendLocation.userID] = annotation
            }
        }
    }

    // MARK: - Planned outing annotations

    private func updateOutingPlanAnnotations(
        on mapView: MapboxMaps.MapView,
        context: Context
    ) {
        let coordinator = context.coordinator
        let currentEventIDs = Set(outingPlans.keys)
        let removedEventIDs = coordinator.outingPlanAnnotations.keys
            .filter { !currentEventIDs.contains($0) }
            .sorted()

        for eventID in removedEventIDs {
            coordinator.outingPlanAnnotations.removeValue(forKey: eventID)
        }

        for eventID in outingPlans.keys.sorted() {
            guard let presentation = outingPlans[eventID] else { continue }
            let plan = presentation.plan

            let annotation: OutingPlanAnnotation
            let isNewAnnotation: Bool
            if let existing = coordinator.outingPlanAnnotations[eventID] {
                annotation = existing
                isNewAnnotation = false
                if annotation.coordinate.latitude != plan.coordinate.latitude
                    || annotation.coordinate.longitude != plan.coordinate.longitude {
                    UIView.animate(withDuration: 0.35) {
                        annotation.coordinate = plan.coordinate
                    }
                }
            } else {
                annotation = OutingPlanAnnotation()
                annotation.eventID = eventID
                annotation.coordinate = plan.coordinate
                isNewAnnotation = true
                coordinator.outingPlanAnnotations[eventID] = annotation
            }

            annotation.title = plan.placeName
            annotation.subtitle = nil
            annotation.profileColorHex = presentation.profileColorHex
            annotation.isCurrentUser = presentation.isCurrentUser
            annotation.category = plan.category
            annotation.participantAvatarIDs = presentation.rosterState
                == .available
                ? presentation.visiblePeople.map(\.avatarID)
                : []

            if !isNewAnnotation,
               let annotationView = coordinator.annotationStore.view(for: annotation)
                as? OutingPlanAnnotationView {
                annotationView.configure(with: annotation)
            }
        }
    }

    private func updateDraftOutingAnnotation(
        on mapView: MapboxMaps.MapView,
        context: Context
    ) {
        let coordinator = context.coordinator

        guard let pendingOutingCoordinate,
              CLLocationCoordinate2DIsValid(pendingOutingCoordinate) else {
            if let annotation = coordinator.draftOutingAnnotation {
                coordinator.annotationStore.removeAnnotation(annotation)
                coordinator.draftOutingAnnotation = nil
            }
            coordinator.lastFocusedDraftCoordinate = nil
            return
        }

        let annotation: DraftOutingAnnotation
        if let existing = coordinator.draftOutingAnnotation {
            annotation = existing
            if annotation.coordinate.latitude
                != pendingOutingCoordinate.latitude
                || annotation.coordinate.longitude
                    != pendingOutingCoordinate.longitude {
                annotation.coordinate = pendingOutingCoordinate
            }
        } else {
            annotation = DraftOutingAnnotation()
            annotation.coordinate = pendingOutingCoordinate
            annotation.title = "Lieu du nouvel événement"
            coordinator.draftOutingAnnotation = annotation
            coordinator.annotationStore.addAnnotation(annotation)
        }

        coordinator.annotationStore.synchronizeCoordinates()
        let draftCoordinate = MapUserCoordinate(pendingOutingCoordinate)
        guard coordinator.lastFocusedDraftCoordinate != draftCoordinate else {
            return
        }

        coordinator.userCamera.stopFollowing()
        guard focusDraftOuting(
            at: pendingOutingCoordinate,
            on: mapView,
            visibleBounds: coordinator.visibleSafeBounds(on: mapView)
        ) else {
            return
        }
        coordinator.lastFocusedDraftCoordinate = draftCoordinate
    }

    private func focusDraftOuting(
        at coordinate: CLLocationCoordinate2D,
        on mapView: MapboxMaps.MapView,
        visibleBounds: CGRect
    ) -> Bool {
        guard visibleBounds.width > 0, visibleBounds.height > 0 else {
            return false
        }

        let topInset = visibleBounds.minY + 24
        let exposedBottom = max(
            topInset,
            visibleBounds.minY + visibleBounds.height * 0.34 - 24
        )
        let targetPoint = CGPoint(
            x: visibleBounds.midX,
            y: topInset + (exposedBottom - topInset) / 2
        )

        let targetCoordinate = mapView.mapboxMap.coordinate(for: targetPoint)
        let translatedCenter = MapEdgeZoomController.anchoredCenter(
            initial: mapView.mapboxMap.cameraState.center,
            anchor: coordinate,
            scale: 1,
            offsetOrigin: targetCoordinate
        )
        mapView.camera.ease(to: CameraOptions(center: translatedCenter), duration: 0.35)
        return true
    }

    private func fitCityBoundary(on mapView: MapboxMaps.MapView) -> Bool {
        let inset = max(24, min(mapView.bounds.width, mapView.bounds.height) * 0.15)
        guard let camera = try? mapView.mapboxMap.camera(
            for: cityBoundaryCoordinates,
            camera: CameraOptions(bearing: 0, pitch: 0),
            coordinatesPadding: UIEdgeInsets(
                top: inset, left: inset, bottom: inset, right: inset
            ),
            maxZoom: 15,
            offset: nil
        ) else { return false }
        guard camera.center != nil, camera.zoom != nil else { return false }
        mapView.mapboxMap.setCamera(to: camera)
        return true
    }

    private func setFocusedRegion(
        on mapView: MapboxMaps.MapView,
        center: CLLocationCoordinate2D,
        animated: Bool
    ) {
        let camera = MapUserCameraController.focusedCamera(at: center, on: mapView)
        if animated {
            mapView.camera.ease(to: camera, duration: 0.35)
        } else {
            mapView.mapboxMap.setCamera(to: camera)
        }
    }

    private func resetCameraOrientation(on mapView: MapboxMaps.MapView) {
        mapView.camera.ease(to: CameraOptions(bearing: 0, pitch: 0), duration: 0.35)
    }

    private func synchronizeDetailSelection(
        on mapView: MapboxMaps.MapView,
        context: Context
    ) {
        let requested: MapSocialClusterMemberID?
        if let eventID = selectedOutingPlanEventID {
            requested = .outing(eventID)
        } else {
            switch selectedMapProfile {
            case .currentUser: requested = .currentUser
            case .friend(let userID): requested = .friend(userID)
            case nil: requested = nil
            }
        }

        context.coordinator.synchronizeDetailSelection(
            requested, on: mapView, silently: selectedOutingPlanEventID != nil
        )
    }

    private func centerMap(
        onFriend userID: String,
        on mapView: MapboxMaps.MapView,
        friendLocations: [String: FriendLocation],
        coordinator: Coordinator
    ) {
        coordinator.userCamera.stopFollowing()

        if let coordinate = friendLocations[userID]?.coordinate {
            guard CLLocationCoordinate2DIsValid(coordinate) else { return }
            coordinator.clearImmediateSocialSelection()
            coordinator.socialProximityController.center(
                on: .friend(userID),
                on: mapView
            )
        }
    }

    private func centerMap(
        onOutingPlan eventID: String,
        on mapView: MapboxMaps.MapView,
        coordinator: Coordinator
    ) {
        guard let annotation = coordinator
            .outingPlanAnnotations[eventID] else {
            return
        }

        coordinator.userCamera.stopFollowing()
        coordinator.clearImmediateSocialSelection()
        setFocusedRegion(
            on: mapView,
            center: annotation.coordinate,
            animated: true
        )
        coordinator.socialProximityController.select(
            .outing(eventID),
            on: mapView,
            silently: true
        )
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UIGestureRecognizerDelegate, GestureManagerDelegate {
        weak var viewport: MapViewportView?
        var edgeZoom: MapEdgeZoomController?
        let fogColor: UIColor
        private(set) var annotationStore: MapAnnotationStore!
        var fogRenderer: MapboxFogRenderer!
        fileprivate var mapSubscriptions: Set<AnyCancelable> = []
        var didSetInitialRegion = false
        var didCenterOnUser = false
        var isConsumingRecenterRequest = false
        fileprivate var pendingCameraUpdate: (() -> Bool)?
        let userCamera = MapUserCameraController()
        var userLocationAnnotation: UserLocationAnnotation?
        private var userDisplayName = ""
        private var userAvatarID = ""
        private var userProfileColorHex = ""
        private var userPresenceInfo: MapUserPresenceInfo?
        var friendAnnotations: [String: FriendLocationAnnotation] = [:]
        var friendAvatarIDByUserID: [String: String] = [:]
        var friendProfileColorHexByUserID: [String: String] = [:]
        var friendPresenceInfoByUserID: [String: MapUserPresenceInfo] = [:]
        var refreshingFriendUserIDs: Set<String> = []
        fileprivate var outingPlanAnnotations: [String: OutingPlanAnnotation] = [:]
        fileprivate var draftOutingAnnotation: DraftOutingAnnotation?
        fileprivate var lastFocusedDraftCoordinate: MapUserCoordinate?
        private var lastRequestedDetailSelection: MapSocialClusterMemberID?
        let friendCamera = MapFriendCameraController()
        var onSelectOwnProfile: () -> Void = {}
        var onSelectFriend: (String) -> Void
        var onSelectOutingPlan: (String) -> Void
        var onDeselectOutingPlan: (String) -> Void
        var onCreateEvent: (CLLocationCoordinate2D) -> Void
        private weak var longPressRecognizer: UILongPressGestureRecognizer?
        private weak var immediateSocialAnnotationRecognizer:
            PassiveMapTapObserver?
        private weak var pressedSocialAnnotationView: MapAnnotationView?
        private var pressedSocialAnnotationOriginalAlpha: CGFloat?
        private var pressedSocialAnnotationWasSelected = false
        private var isPressingMapBackground = false
        private var socialPressGeneration: UInt64 = 0
        private struct ImmediateSocialSelection {
            let annotation: MapAnnotation
            var isCommitted = false
        }
        private var immediateSocialSelection: ImmediateSocialSelection?
        private var immediateSocialSelectionResetWorkItem: DispatchWorkItem?
        private weak var mapOffscreenIndicatorContainer:
            MapOffscreenIndicatorContainerView?
        private var friendOffscreenIndicatorViews:
            [String: FriendOffscreenIndicatorView] = [:]
        private var outingOffscreenIndicatorViews:
            [String: OutingOffscreenIndicatorView] = [:]
        fileprivate lazy var socialProximityController = MapSocialProximityController(
            annotationStore: annotationStore,
            presentation: { [weak self] group in
                self?.socialClusterPresentation(for: group)
                    ?? MapSocialClusterPresentation(people: [], outings: [])
            },
            setFocusAppearance: { isFocused, view in
                if let locationView = view as? UserLocationAnnotationView {
                    locationView.setSocialClusterFocus(isFocused)
                } else if let outingView = view as? OutingPlanAnnotationView {
                    outingView.setSocialClusterFocus(isFocused)
                }
            },
            onDeselectMember: { [weak self] memberID in
                if case .outing(let eventID) = memberID {
                    self?.onDeselectOutingPlan(eventID)
                }
            },
            onRequestOwnProfile: { [weak self] in
                self?.clearImmediateSocialSelection()
                self?.friendCamera.cancel()
                self?.userCamera.stopFollowing()
                self?.onSelectOwnProfile()
            },
            onRequestFriendProfile: { [weak self] userID in
                self?.clearImmediateSocialSelection()
                self?.friendCamera.cancel()
                self?.userCamera.stopFollowing()
                self?.onSelectFriend(userID)
            },
            visibleBounds: { [weak self] mapView in
                self?.visibleSafeBounds(on: mapView)
                    ?? mapView.bounds.inset(by: mapView.safeAreaInsets)
            }
        )
        private let eventCreationFeedback = UIImpactFeedbackGenerator(
            style: .medium
        )
        private static let friendPinSize: CGFloat = 88

        private enum OffscreenTarget {
            case friend(String)
            case outing(String)
        }

        init(
            fogColor: UIColor,
            onSelectFriend: @escaping (String) -> Void,
            onSelectOutingPlan: @escaping (String) -> Void,
            onDeselectOutingPlan: @escaping (String) -> Void,
            onCreateEvent: @escaping (CLLocationCoordinate2D) -> Void
        ) {
            self.fogColor = fogColor
            self.onSelectFriend = onSelectFriend
            self.onSelectOutingPlan = onSelectOutingPlan
            self.onDeselectOutingPlan = onDeselectOutingPlan
            self.onCreateEvent = onCreateEvent
        }

        func applyPendingCameraUpdate() {
            guard let update = pendingCameraUpdate else { return }
            pendingCameraUpdate = nil
            if !update() { pendingCameraUpdate = update }
        }

        func install(on mapView: MapboxMaps.MapView) {
            annotationStore = MapAnnotationStore(mapView: mapView)
            annotationStore.makeView = { [weak self, weak mapView] annotation in
                guard let self, let mapView else { return nil }
                return self.mapView(mapView, viewFor: annotation)
            }
            annotationStore.onSelect = { [weak self, weak mapView] view in
                guard let self, let mapView else { return }
                self.mapView(mapView, didSelect: view)
            }
            annotationStore.onDeselect = { [weak self, weak mapView] view in
                guard let self, let mapView else { return }
                self.mapView(mapView, didDeselect: view)
            }
            annotationStore.onDidAdd = { [weak self, weak mapView] views in
                guard let self, let mapView else { return }
                self.mapView(mapView, didAdd: views)
            }
            fogRenderer = MapboxFogRenderer(mapView: mapView, fogColor: fogColor)
            mapView.gestures.delegate = self
            mapView.mapboxMap.onCameraChanged.observe { [weak self, weak mapView] _ in
                guard let self, let mapView else { return }
                self.cameraDidChange(on: mapView)
            }.store(in: &mapSubscriptions)
            mapView.mapboxMap.onMapIdle.observe { [weak self, weak mapView] _ in
                guard let self, let mapView else { return }
                self.cameraDidFinish(on: mapView)
            }.store(in: &mapSubscriptions)
        }

        func gestureManager(_ gestureManager: GestureManager, didBegin gestureType: GestureType) {
            guard gestureType != .singleTap, let mapView = viewport?.mapView else { return }
            clearImmediateSocialSelection()
            friendCamera.cancel()
            userCamera.stopFollowing()
            socialProximityController.regionWillChange(
                on: mapView, userInitiated: socialProximityController.hasActivePresentation
            )
        }

        func gestureManager(
            _ gestureManager: GestureManager,
            didEnd gestureType: GestureType,
            willAnimate: Bool
        ) {
            guard !willAnimate, let mapView = viewport?.mapView else { return }
            cameraDidFinish(on: mapView)
        }

        func gestureManager(
            _ gestureManager: GestureManager,
            didEndAnimatingFor gestureType: GestureType
        ) {
            guard let mapView = viewport?.mapView else { return }
            cameraDidFinish(on: mapView)
        }

        func installLongPressRecognizer(on mapView: MapboxMaps.MapView) {
            guard longPressRecognizer == nil else { return }

            let recognizer = UILongPressGestureRecognizer(
                target: self,
                action: #selector(handleLongPress(_:))
            )
            recognizer.minimumPressDuration = 0.5
            recognizer.allowableMovement = 10
            recognizer.numberOfTouchesRequired = 1
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            mapView.addGestureRecognizer(recognizer)
            longPressRecognizer = recognizer
        }

        func removeLongPressRecognizer(from mapView: MapboxMaps.MapView) {
            guard let longPressRecognizer else { return }
            mapView.removeGestureRecognizer(longPressRecognizer)
            self.longPressRecognizer = nil
        }

        func setEventCreationEnabled(_ isEnabled: Bool) {
            longPressRecognizer?.isEnabled = isEnabled
        }

        func installImmediateSocialAnnotationRecognizer(on mapView: MapboxMaps.MapView) {
            guard immediateSocialAnnotationRecognizer == nil else { return }

            let recognizer = PassiveMapTapObserver(maximumMovement: 10)
            recognizer.onTouchBegan = { [weak self, weak mapView] point in
                guard let self, let mapView else { return }
                self.beginImmediateSocialPress(at: point, on: mapView)
            }
            recognizer.onTapEnded = { [weak self, weak mapView] point in
                guard let self, let mapView else { return }
                self.endImmediateSocialPress(at: point, on: mapView)
            }
            recognizer.onTouchCancelled = { [weak self] in
                self?.clearImmediateSocialSelection()
                self?.restorePressedSocialAnnotationAppearance(animated: true)
            }
            recognizer.delegate = self
            mapView.addGestureRecognizer(recognizer)
            immediateSocialAnnotationRecognizer = recognizer
        }

        func removeImmediateSocialAnnotationRecognizer(from mapView: MapboxMaps.MapView) {
            guard let immediateSocialAnnotationRecognizer else { return }
            restorePressedSocialAnnotationAppearance(animated: false)
            clearImmediateSocialSelection()
            mapView.removeGestureRecognizer(immediateSocialAnnotationRecognizer)
            self.immediateSocialAnnotationRecognizer = nil
        }

        func synchronizeSocialProximityAnnotations(on mapView: MapboxMaps.MapView) {
            var sources: [MapSocialClusterMemberID: MapAnnotation] = [:]
            for (userID, annotation) in friendAnnotations {
                sources[.friend(userID)] = annotation
            }
            for (eventID, annotation) in outingPlanAnnotations {
                sources[.outing(eventID)] = annotation
            }
            if let userLocationAnnotation {
                sources[.currentUser] = userLocationAnnotation
            }
            socialProximityController.update(sources: sources, on: mapView)
        }

        func synchronizeDetailSelection(
            _ requested: MapSocialClusterMemberID?,
            on mapView: MapboxMaps.MapView,
            silently: Bool = false
        ) {
            guard requested != lastRequestedDetailSelection else { return }
            // Keep protection when SwiftUI echoes this tap; a different product
            // selection explicitly takes ownership before Mapbox receives it.
            let touchedMember: MapSocialClusterMemberID?
            switch immediateSocialSelection?.annotation {
            case let friend as FriendLocationAnnotation: touchedMember = .friend(friend.userID)
            case is UserLocationAnnotation: touchedMember = .currentUser
            case let outing as OutingPlanAnnotation: touchedMember = .outing(outing.eventID)
            default: touchedMember = nil
            }
            if requested == nil || requested != touchedMember {
                clearImmediateSocialSelection()
            }
            // Publish before selection can synchronously call the native delegate.
            friendCamera.cancel()
            lastRequestedDetailSelection = requested
            if let requested {
                userCamera.stopFollowing()
                socialProximityController.select(requested, on: mapView, silently: silently)
            } else {
                socialProximityController.collapse(on: mapView)
            }
        }

        func edgeZoomTargets(on mapView: MapboxMaps.MapView) -> [MapEdgeZoomController.Target] {
            annotationStore.annotations.compactMap { annotation in
                guard let id = Self.edgeZoomTargetID(for: annotation),
                      let view = annotationStore.view(for: annotation),
                      view.isDescendant(of: mapView), !view.isHidden, view.alpha > 0.01 else { return nil }
                return MapEdgeZoomController.Target(
                    id: id,
                    coordinate: annotation.coordinate,
                    screenPoint: mapView.mapboxMap.point(for: annotation.coordinate)
                )
            }
        }

        static func edgeZoomTargetID(for annotation: MapAnnotation) -> String? {
            if annotation is UserLocationAnnotation {
                return "current-user"
            }
            if let friend = annotation as? FriendLocationAnnotation {
                return "friend:\(friend.userID)"
            }
            if let outing = annotation as? OutingPlanAnnotation {
                return "outing:\(outing.eventID)"
            }
            if let group = annotation as? MapSocialProximityGroupAnnotation,
               group.memberAnnotations.contains(where: {
                   $0 is UserLocationAnnotation || $0 is FriendLocationAnnotation || $0 is OutingPlanAnnotation
               }) {
                return "group:\(group.identifier)"
            }
            return nil
        }

        private func socialClusterPresentation(
            for cluster: MapSocialProximityGroupAnnotation
        ) -> MapSocialClusterPresentation {
            var people: [MapSocialClusterPersonPresentation] = []
            var outings: [MapSocialClusterOutingPresentation] = []

            for member in cluster.memberAnnotations {
                if member is UserLocationAnnotation {
                    people.append(
                        MapSocialClusterPersonPresentation(
                            id: "current-user",
                            displayName: userDisplayName,
                            avatarID: userAvatarID,
                            profileColorHex: userProfileColorHex,
                            isCurrentUser: true
                        )
                    )
                    continue
                }

                if let friend = member as? FriendLocationAnnotation {
                    let info = friendPresenceInfoByUserID[friend.userID]
                    people.append(
                        MapSocialClusterPersonPresentation(
                            id: friend.userID,
                            displayName: info?.displayName
                                ?? friend.title
                                ?? "Explorer",
                            avatarID: friendAvatarIDByUserID[friend.userID]
                                ?? ProfileAvatar.generatedID(
                                    seed: friend.userID
                                ),
                            profileColorHex:
                                friendProfileColorHexByUserID[friend.userID]
                                ?? ProfileColor.generatedHex(
                                    seed: friend.userID
                                ),
                            isCurrentUser: false
                        )
                    )
                    continue
                }

                if let outing = member as? OutingPlanAnnotation {
                    outings.append(
                        MapSocialClusterOutingPresentation(
                            id: outing.eventID,
                            placeName: outing.title
                                ?? "Lieu sans nom",
                            category: outing.category,
                            profileColorHex: outing.profileColorHex,
                            isCurrentUser: outing.isCurrentUser,
                            participantAvatarIDs: outing.participantAvatarIDs
                        )
                    )
                }
            }

            people.sort {
                if $0.isCurrentUser != $1.isCurrentUser {
                    return $0.isCurrentUser
                }
                let comparison = $0.displayName.localizedStandardCompare(
                    $1.displayName
                )
                return comparison == .orderedSame
                    ? $0.id < $1.id
                    : comparison == .orderedAscending
            }
            outings.sort {
                let comparison = $0.placeName.localizedStandardCompare(
                    $1.placeName
                )
                return comparison == .orderedSame
                    ? $0.id < $1.id
                    : comparison == .orderedAscending
            }
            return MapSocialClusterPresentation(
                people: people,
                outings: outings
            )
        }

        func installMapOffscreenIndicatorContainer(on mapView: MapboxMaps.MapView) {
            guard mapOffscreenIndicatorContainer == nil else { return }

            let container = MapOffscreenIndicatorContainerView(
                frame: mapView.bounds
            )
            container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            container.backgroundColor = .clear
            container.isAccessibilityElement = false
            mapView.addSubview(container)
            mapOffscreenIndicatorContainer = container
        }

        func removeMapOffscreenIndicatorContainer() {
            mapOffscreenIndicatorContainer?.removeFromSuperview()
            friendOffscreenIndicatorViews.removeAll()
            outingOffscreenIndicatorViews.removeAll()
            mapOffscreenIndicatorContainer = nil
        }

        func visibleSafeBounds(on mapView: MapboxMaps.MapView) -> CGRect {
            viewport?.visibleSafeMapRect
                ?? mapView.bounds.inset(by: mapView.safeAreaInsets)
        }

        func refreshMapOffscreenIndicators(on mapView: MapboxMaps.MapView) {
            guard let container = mapOffscreenIndicatorContainer else {
                return
            }

            container.frame = mapView.bounds
            let safeBounds = visibleSafeBounds(on: mapView)
            guard let indicatorBounds = MapOffscreenIndicatorLayout
                .indicatorBounds(
                    in: safeBounds,
                    safeAreaInsets: .zero
                ) else {
                removeAllMapOffscreenIndicatorViews()
                return
            }

            guard safeBounds.width > 0, safeBounds.height > 0 else {
                removeAllMapOffscreenIndicatorViews()
                return
            }

            var candidates: [MapOffscreenIndicatorCandidate] = []
            var targetByCandidateID: [String: OffscreenTarget] = [:]

            for userID in friendAnnotations.keys.sorted() {
                guard let annotation = friendAnnotations[userID],
                      let targetPoint = projectedPoint(
                        for: annotation.coordinate,
                        on: mapView
                      ) else {
                    continue
                }

                let pinFrame = CGRect(
                    x: targetPoint.x - Self.friendPinSize / 2,
                    y: targetPoint.y - Self.friendPinSize / 2,
                    width: Self.friendPinSize,
                    height: Self.friendPinSize
                )
                guard !safeBounds.intersects(pinFrame) else { continue }

                let candidateID = "friend:\(userID)"
                candidates.append(
                    MapOffscreenIndicatorCandidate(
                        id: candidateID,
                        targetPoint: targetPoint
                    )
                )
                targetByCandidateID[candidateID] = .friend(userID)
            }

            for eventID in outingPlanAnnotations.keys.sorted() {
                guard let annotation = outingPlanAnnotations[eventID],
                      let targetPoint = projectedPoint(
                        for: annotation.coordinate,
                        on: mapView
                      ) else {
                    continue
                }

                let markerFrame = OutingPlanAnnotationView.projectedFrame(
                    at: targetPoint
                )
                guard !safeBounds.intersects(markerFrame) else { continue }

                let candidateID = "outing:\(eventID)"
                candidates.append(
                    MapOffscreenIndicatorCandidate(
                        id: candidateID,
                        targetPoint: targetPoint
                    )
                )
                targetByCandidateID[candidateID] = .outing(eventID)
            }

            let placements = MapOffscreenIndicatorLayout.placements(
                for: candidates,
                in: indicatorBounds
            )
            var desiredFriendIDs: Set<String> = []
            var desiredEventIDs: Set<String> = []

            for placement in placements {
                guard let target = targetByCandidateID[placement.id] else {
                    continue
                }

                switch target {
                case .friend(let userID):
                    guard let presenceInfo = friendPresenceInfoByUserID[userID]
                    else {
                        continue
                    }

                    desiredFriendIDs.insert(userID)
                    let indicatorView = friendOffscreenIndicatorView(
                        for: userID,
                        in: container,
                        mapView: mapView
                    )
                    indicatorView.configure(
                        displayName: presenceInfo.displayName,
                        avatarID: friendAvatarIDByUserID[userID]
                            ?? ProfileAvatar.generatedID(seed: userID),
                        profileColorHex: friendProfileColorHexByUserID[userID]
                            ?? ProfileColor.generatedHex(seed: userID),
                        isLocationFresh: presenceInfo.isLocationFresh,
                        directionName: placement.directionName,
                        pointerAngle: placement.pointerAngle
                    )
                    indicatorView.center = placement.center

                case .outing(let eventID):
                    guard let annotation = outingPlanAnnotations[eventID]
                    else {
                        continue
                    }

                    desiredEventIDs.insert(eventID)
                    let indicatorView = outingOffscreenIndicatorView(
                        for: eventID,
                        in: container,
                        mapView: mapView
                    )
                    indicatorView.configure(
                        placeName: annotation.title ?? "Lieu sans nom",
                        category: annotation.category,
                        profileColorHex: annotation.profileColorHex,
                        isCurrentUser: annotation.isCurrentUser,
                        participantAvatarIDs: annotation.participantAvatarIDs,
                        directionName: placement.directionName,
                        pointerAngle: placement.pointerAngle
                    )
                    indicatorView.center = placement.center
                }
            }

            removeObsoleteOffscreenIndicatorViews(
                desiredFriendIDs: desiredFriendIDs,
                desiredEventIDs: desiredEventIDs
            )
            mapView.bringSubviewToFront(container)
        }

        private func friendOffscreenIndicatorView(
            for userID: String,
            in container: MapOffscreenIndicatorContainerView,
            mapView: MapboxMaps.MapView
        ) -> FriendOffscreenIndicatorView {
            if let existing = friendOffscreenIndicatorViews[userID] {
                return existing
            }

            let indicatorView = FriendOffscreenIndicatorView(userID: userID)
            indicatorView.onActivate = { [weak self, weak mapView] userID in
                guard let self, let mapView else { return }
                self.clearImmediateSocialSelection()
                self.userCamera.stopFollowing()
                self.socialProximityController.center(on: .friend(userID), on: mapView)
            }
            container.addSubview(indicatorView)
            friendOffscreenIndicatorViews[userID] = indicatorView
            return indicatorView
        }

        private func outingOffscreenIndicatorView(
            for eventID: String,
            in container: MapOffscreenIndicatorContainerView,
            mapView: MapboxMaps.MapView
        ) -> OutingOffscreenIndicatorView {
            if let existing = outingOffscreenIndicatorViews[eventID] {
                return existing
            }

            let indicatorView = OutingOffscreenIndicatorView(eventID: eventID)
            indicatorView.onActivate = { [weak self, weak mapView] eventID in
                guard let self, let mapView else { return }
                self.clearImmediateSocialSelection()
                self.userCamera.stopFollowing()
                self.socialProximityController.center(on: .outing(eventID), on: mapView)
            }
            container.addSubview(indicatorView)
            outingOffscreenIndicatorViews[eventID] = indicatorView
            return indicatorView
        }

        private func removeObsoleteOffscreenIndicatorViews(
            desiredFriendIDs: Set<String>,
            desiredEventIDs: Set<String>
        ) {
            let obsoleteUserIDs = friendOffscreenIndicatorViews.keys.filter {
                !desiredFriendIDs.contains($0)
            }
            for userID in obsoleteUserIDs {
                friendOffscreenIndicatorViews[userID]?.removeFromSuperview()
                friendOffscreenIndicatorViews.removeValue(forKey: userID)
            }

            let obsoleteEventIDs = outingOffscreenIndicatorViews.keys.filter {
                !desiredEventIDs.contains($0)
            }
            for eventID in obsoleteEventIDs {
                outingOffscreenIndicatorViews[eventID]?.removeFromSuperview()
                outingOffscreenIndicatorViews.removeValue(forKey: eventID)
            }
        }

        private func removeAllMapOffscreenIndicatorViews() {
            for indicatorView in friendOffscreenIndicatorViews.values {
                indicatorView.removeFromSuperview()
            }
            friendOffscreenIndicatorViews.removeAll()

            for indicatorView in outingOffscreenIndicatorViews.values {
                indicatorView.removeFromSuperview()
            }
            outingOffscreenIndicatorViews.removeAll()
        }

        private func projectedPoint(
            for coordinate: CLLocationCoordinate2D,
            on mapView: MapboxMaps.MapView
        ) -> CGPoint? {
            let point = mapView.mapboxMap.point(for: coordinate)
            // Mapbox uses this finite sentinel when the coordinate is offscreen.
            if point.x.isFinite, point.y.isFinite, point != CGPoint(x: -1, y: -1) {
                return point
            }

            return fallbackProjectedPoint(
                for: coordinate,
                on: mapView
            )
        }

        private func fallbackProjectedPoint(
            for coordinate: CLLocationCoordinate2D,
            on mapView: MapboxMaps.MapView
        ) -> CGPoint? {
            let centerCoordinate = mapView.mapboxMap.cameraState.center
            guard CLLocationCoordinate2DIsValid(centerCoordinate),
                  CLLocationCoordinate2DIsValid(coordinate) else {
                return nil
            }

            let startLatitude: Double = centerCoordinate.latitude
                * Double.pi / 180
            let endLatitude: Double = coordinate.latitude * Double.pi / 180
            let longitudeDelta: Double = (
                coordinate.longitude - centerCoordinate.longitude
            ) * Double.pi / 180
            let y: Double = sin(longitudeDelta) * cos(endLatitude)
            let x: Double = cos(startLatitude) * sin(endLatitude)
                - sin(startLatitude) * cos(endLatitude) * cos(longitudeDelta)
            let bearing: Double = atan2(y, x) * 180 / Double.pi
            let relativeBearing: Double = (
                bearing - mapView.mapboxMap.cameraState.bearing
            ) * Double.pi / 180
            let visibleBounds = visibleSafeBounds(on: mapView)
            let distance = max(visibleBounds.width, visibleBounds.height) * 2

            return CGPoint(
                x: visibleBounds.midX
                    + CGFloat(sin(relativeBearing)) * distance,
                y: visibleBounds.midY
                    - CGFloat(cos(relativeBearing)) * distance
            )
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            if edgeZoom?.owns(gestureRecognizer) == true
                || edgeZoom?.owns(otherGestureRecognizer) == true {
                return false
            }
            guard let longPressRecognizer,
                  gestureRecognizer === longPressRecognizer
                    || otherGestureRecognizer === longPressRecognizer else {
                return true
            }

            let competingRecognizer = gestureRecognizer === longPressRecognizer
                ? otherGestureRecognizer
                : gestureRecognizer
            if competingRecognizer is UIPanGestureRecognizer
                || competingRecognizer is UIPinchGestureRecognizer
                || competingRecognizer is UIRotationGestureRecognizer {
                return false
            }
            return true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            if gestureRecognizer === immediateSocialAnnotationRecognizer {
                // Controls and group rows also start a new interaction, even
                // though this observer will not handle their touches.
                clearImmediateSocialSelection()
                // Assistive activation uses the annotation view’s activation handler.
                guard !UIAccessibility.isVoiceOverRunning,
                      !UIAccessibility.isSwitchControlRunning else { return false }
                return immediateSocialPressTarget(from: touch.view) != nil
            }

            guard gestureRecognizer === longPressRecognizer else {
                return true
            }

            var touchedView = touch.view

            while let view = touchedView {
                if excludesEventCreation(from: view) {
                    return false
                }
                if view === gestureRecognizer.view {
                    break
                }
                touchedView = view.superview
            }

            eventCreationFeedback.prepare()
            return true
        }

        private enum ImmediateSocialPressTarget {
            case annotation(MapAnnotationView)
            case mapBackground
        }

        private func immediateSocialPressTarget(
            from touchedView: UIView?
        ) -> ImmediateSocialPressTarget? {
            var currentView = touchedView

            while let view = currentView {
                if view is UIControl {
                    return nil
                }
                if let annotationView = view as? MapAnnotationView {
                    return supportsImmediateActivation(annotationView)
                        ? .annotation(annotationView)
                        : nil
                }
                if view.accessibilityTraits.contains(.button) {
                    return nil
                }
                if view === immediateSocialAnnotationRecognizer?.view {
                    return .mapBackground
                }
                currentView = view.superview
            }

            return nil
        }

        private func supportsImmediateActivation(
            _ annotationView: MapAnnotationView
        ) -> Bool {
            if annotationView.annotation is UserLocationAnnotation
                || annotationView.annotation is FriendLocationAnnotation
                || annotationView.annotation is OutingPlanAnnotation {
                return true
            }
            guard annotationView.annotation
                    is MapSocialProximityGroupAnnotation,
                  let clusterView = annotationView
                    as? MapSocialClusterAnnotationView else {
                return false
            }
            return !clusterView.isExpanded
        }

        private func beginImmediateSocialPress(
            at point: CGPoint,
            on mapView: MapboxMaps.MapView
        ) {
            socialPressGeneration &+= 1
            clearImmediateSocialSelection()
            let touchedView = mapView.hitTest(point, with: nil)
            guard let pressTarget = immediateSocialPressTarget(
                from: touchedView
            ) else {
                return
            }

            switch pressTarget {
            case .annotation(let annotationView):
                if let annotation = annotationView.annotation {
                    immediateSocialSelection = ImmediateSocialSelection(annotation: annotation)
                }
                pressedSocialAnnotationView = annotationView
                pressedSocialAnnotationOriginalAlpha = annotationView.alpha
                pressedSocialAnnotationWasSelected = annotationView.isSelected
                UIView.animate(
                    withDuration: 0.06,
                    delay: 0,
                    options: [.beginFromCurrentState, .allowUserInteraction]
                ) {
                    annotationView.alpha *= 0.72
                }
            case .mapBackground:
                isPressingMapBackground = true
            }
        }

        private func endImmediateSocialPress(
            at mapPoint: CGPoint,
            on mapView: MapboxMaps.MapView
        ) {
            if isPressingMapBackground {
                isPressingMapBackground = false
                // Apply dismissal after annotation tap handlers finish this event.
                let generation = socialPressGeneration
                let presentationRevision = socialProximityController.presentationRevision
                DispatchQueue.main.async { [weak self, weak mapView] in
                    guard let self, let mapView,
                          self.socialPressGeneration == generation,
                          self.socialProximityController.presentationRevision
                            == presentationRevision else { return }
                    self.dismissSelectedSocialAnnotations(on: mapView)
                }
                return
            }

            guard let annotationView = pressedSocialAnnotationView,
                  let annotation = annotationView.annotation,
                  annotationStore.view(for: annotation) === annotationView else {
                clearImmediateSocialSelection()
                restorePressedSocialAnnotationAppearance(animated: true)
                return
            }

            let annotationPoint = annotationView.convert(
                mapPoint,
                from: mapView
            )
            guard annotationView.point(inside: annotationPoint, with: nil) else {
                clearImmediateSocialSelection()
                restorePressedSocialAnnotationAppearance(animated: true)
                return
            }

            let wasSelectedAtTouchStart = pressedSocialAnnotationWasSelected
            restorePressedSocialAnnotationAppearance(animated: true)
            protectCommittedSocialSelection(annotation)
            if wasSelectedAtTouchStart, socialProximityController.isFocused(annotation) {
                // Preserve repeated event taps without reopening an existing friend.
                if let outing = annotation as? OutingPlanAnnotation {
                    onSelectOutingPlan(outing.eventID)
                }
                restoreImmediateSocialSelection(on: mapView)
                return
            }
            activateSocialAnnotation(
                annotation,
                view: annotationView,
                on: mapView
            )
            restoreImmediateSocialSelection(on: mapView)
        }

        private func restorePressedSocialAnnotationAppearance(animated: Bool) {
            isPressingMapBackground = false
            pressedSocialAnnotationWasSelected = false
            guard let annotationView = pressedSocialAnnotationView,
                  let originalAlpha = pressedSocialAnnotationOriginalAlpha else {
                pressedSocialAnnotationView = nil
                pressedSocialAnnotationOriginalAlpha = nil
                return
            }

            pressedSocialAnnotationView = nil
            pressedSocialAnnotationOriginalAlpha = nil
            let changes = {
                annotationView.alpha = originalAlpha
            }
            if animated {
                UIView.animate(
                    withDuration: 0.08,
                    delay: 0,
                    options: [.beginFromCurrentState, .allowUserInteraction],
                    animations: changes
                )
            } else {
                changes()
            }
        }

        private func dismissSelectedSocialAnnotations(on mapView: MapboxMaps.MapView) {
            let selectedSocialAnnotations = annotationStore.selectedAnnotations.filter {
                $0 is UserLocationAnnotation
                    || $0 is FriendLocationAnnotation
                    || $0 is OutingPlanAnnotation
                    || $0 is MapSocialProximityGroupAnnotation
            }

            // Cancel pending selection even when Mapbox has not selected its view yet.
            socialProximityController.collapse(on: mapView)
            for annotation in selectedSocialAnnotations {
                annotationStore.deselectAnnotation(annotation, animated: false)
            }
        }

        private func protectCommittedSocialSelection(_ annotation: MapAnnotation) {
            immediateSocialSelectionResetWorkItem?.cancel()
            immediateSocialSelection = ImmediateSocialSelection(annotation: annotation, isCommitted: true)
            let generation = socialPressGeneration
            let workItem = DispatchWorkItem { [weak self] in
                guard self?.socialPressGeneration == generation else { return }
                self?.clearImmediateSocialSelection()
            }
            immediateSocialSelectionResetWorkItem = workItem
            // Keep ownership until other tap handlers finish this interaction.
            // A new touch or explicit selection releases this protection.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: workItem)
        }

        fileprivate func clearImmediateSocialSelection() {
            immediateSocialSelectionResetWorkItem?.cancel()
            immediateSocialSelectionResetWorkItem = nil
            immediateSocialSelection = nil
        }

        private func restoreImmediateSocialSelection(on mapView: MapboxMaps.MapView) {
            guard let selection = immediateSocialSelection, selection.isCommitted,
                  !annotationStore.selectedAnnotations.contains(where: {
                      ($0 as AnyObject) === (selection.annotation as AnyObject)
                  }),
                  annotationStore.view(for: selection.annotation) != nil,
                  annotationStore.annotations.contains(where: {
                      ($0 as AnyObject) === (selection.annotation as AnyObject)
                  }) else { return }
            annotationStore.selectAnnotation(selection.annotation, animated: false)
        }

        private func excludesEventCreation(from view: UIView) -> Bool {
            view is MapAnnotationView
                || view is UIControl
                || view.accessibilityTraits.contains(.button)
        }

        @objc private func handleLongPress(
            _ recognizer: UILongPressGestureRecognizer
        ) {
            guard recognizer.state == .began,
                  let mapView = recognizer.view as? MapboxMaps.MapView else {
                return
            }

            let point = recognizer.location(in: mapView)
            let coordinate = mapView.mapboxMap.coordinate(for: point)
            guard CLLocationCoordinate2DIsValid(coordinate) else { return }

            eventCreationFeedback.impactOccurred()
            onCreateEvent(coordinate)
        }

        private func cameraDidChange(on mapView: MapboxMaps.MapView) {
            let userInitiated = hasActiveMapGesture(in: mapView)
            if userInitiated {
                clearImmediateSocialSelection()
                friendCamera.cancel()
                userCamera.stopFollowing()
            }
            socialProximityController.visibleRegionDidChange(
                on: mapView,
                userInitiated: socialProximityController.hasActivePresentation
                    && userInitiated
            )
            refreshMapOffscreenIndicators(on: mapView)
        }

        func applyFriendCameraRequest(
            _ request: MapFriendCameraRequest,
            coordinate: CLLocationCoordinate2D?,
            viewport: MapViewportView,
            isAllowed: Bool
        ) {
            guard isAllowed, let coordinate,
                  CLLocationCoordinate2DIsValid(coordinate) else {
                friendCamera.cancel(consuming: request)
                return
            }
            guard friendCamera.lastRequestID != request.id else { return }
            guard !hasActiveMapGesture(in: viewport.mapView) else {
                friendCamera.cancel(consuming: request)
                return
            }
            viewport.layoutIfNeeded()
            userCamera.stopFollowing()
            friendCamera.apply(request, coordinate: coordinate, viewport: viewport)
        }

        private func hasActiveMapGesture(in view: UIView) -> Bool {
            // Scrolling a group's list or touching its controls is not a map gesture.
            guard !(view is MapAnnotationView), !(view is UIControl) else { return false }
            if view.gestureRecognizers?.contains(where: {
                guard $0 !== immediateSocialAnnotationRecognizer,
                      $0 !== longPressRecognizer else { return false }
                if let tap = $0 as? UITapGestureRecognizer {
                    // An ordinary annotation tap can itself trigger a recentre.
                    return tap.state == .ended
                        && (tap.numberOfTapsRequired > 1 || tap.numberOfTouchesRequired > 1)
                }
                return $0.state == .began || $0.state == .changed
            }) == true {
                return true
            }
            return view.subviews.contains { hasActiveMapGesture(in: $0) }
        }

        private func cameraDidFinish(on mapView: MapboxMaps.MapView) {
            socialProximityController.regionDidChange(on: mapView)
            refreshMapOffscreenIndicators(on: mapView)
            applyPendingCameraUpdate()
        }

        func mapView(_ mapView: MapboxMaps.MapView, viewFor annotation: MapAnnotation) -> MapAnnotationView? {
            if annotation is UserLocationAnnotation {
                let annotationView = UserLocationAnnotationView(
                        annotation: annotation,
                        reuseIdentifier: UserLocationAnnotationView.reuseIdentifier
                    )
                annotationView.annotation = annotation

                annotationView.configure(
                    avatarID: userAvatarID,
                    profileColorHex: userProfileColorHex,
                    presenceInfo: userPresenceInfo ?? MapUserPresenceInfo(
                        displayName: userDisplayName,
                        relationshipText: "Vous",
                        locationSampledAt: nil,
                        spotEnteredAt: nil,
                        isLocationFresh: true,
                        keepsSpotDurationVisible: false
                    )
                )
                annotationView.accessibilityHint = "Ouvrir mon profil"
                annotationView.setSocialClusterFocus(
                    socialProximityController.isFocused(annotation)
                )
                return annotationView
            }

            if let cluster = annotation
                as? MapSocialProximityGroupAnnotation {
                let annotationView = MapSocialClusterAnnotationView(
                        annotation: annotation,
                        reuseIdentifier: MapSocialClusterAnnotationView
                            .reuseIdentifier
                    )
                annotationView.annotation = annotation
                socialProximityController.configure(
                    annotationView,
                    for: cluster,
                    on: mapView
                )
                return annotationView
            }

            if annotation is DraftOutingAnnotation {
                return DraftOutingAnnotationView(annotation: annotation, reuseIdentifier: "DraftOutingAnnotation")
            }

            if let outingPlanAnnotation = annotation as? OutingPlanAnnotation {
                let annotationView = OutingPlanAnnotationView(
                        annotation: annotation,
                        reuseIdentifier: OutingPlanAnnotationView.reuseIdentifier
                )
                annotationView.annotation = annotation
                annotationView.configure(with: outingPlanAnnotation)
                annotationView.setSocialClusterFocus(
                    socialProximityController.isFocused(annotation)
                )
                return annotationView
            }

            guard let friendAnnotation = annotation as? FriendLocationAnnotation else {
                return nil
            }

            let annotationView = UserLocationAnnotationView(
                    annotation: annotation,
                    reuseIdentifier: UserLocationAnnotationView.friendReuseIdentifier
                )
            annotationView.annotation = annotation

            let displayName = annotation.title ?? "Explorer"
            let userID = friendAnnotation.userID
            let avatarID = friendAvatarIDByUserID[userID]
                ?? ProfileAvatar.generatedID(seed: userID)
            let profileColorHex = friendProfileColorHexByUserID[userID]
                ?? ProfileColor.generatedHex(seed: userID)
            let presenceInfo = friendPresenceInfoByUserID[userID]
                ?? MapUserPresenceInfo(
                    displayName: displayName,
                    relationshipText: "Ami",
                    locationSampledAt: nil,
                    spotEnteredAt: nil,
                    isLocationFresh: false,
                    keepsSpotDurationVisible: false
                )
            configureFriendAnnotationView(
                annotationView,
                avatarID: avatarID,
                profileColorHex: profileColorHex,
                presenceInfo: presenceInfo,
                isRefreshingLocation: refreshingFriendUserIDs.contains(userID)
            )
            annotationView.setSocialClusterFocus(
                socialProximityController.isFocused(annotation)
            )
            return annotationView
        }

        func mapView(_ mapView: MapboxMaps.MapView, didAdd views: [MapAnnotationView]) {
            socialProximityController.didAddViews(on: mapView)
        }

        func mapView(_ mapView: MapboxMaps.MapView, didSelect view: MapAnnotationView) {
            guard let annotation = view.annotation,
                  annotationStore.view(for: annotation) === view,
                  annotationStore.selectedAnnotations.contains(where: {
                      ($0 as AnyObject) === (annotation as AnyObject)
                  }) else { return }
            if let selection = immediateSocialSelection {
                // The passive observer owns this touch, including its target annotation.
                if (annotation as AnyObject) !== (selection.annotation as AnyObject) {
                    annotationStore.deselectAnnotation(annotation, animated: false)
                    restoreImmediateSocialSelection(on: mapView)
                }
                return
            }
            let isProgrammaticOutingSelection = annotation is OutingPlanAnnotation
                && socialProximityController.isSilentPendingSelection(annotation)
            activateSocialAnnotation(
                annotation, view: view, on: mapView,
                notifyOutingSelection: !isProgrammaticOutingSelection
            )
        }

        private func activateSocialAnnotation(
            _ annotation: MapAnnotation,
            view: MapAnnotationView,
            on mapView: MapboxMaps.MapView,
            notifyOutingSelection: Bool = true
        ) {
            // A queued selection can complete when the friend enters the viewport.
            if !socialProximityController.isFocused(annotation) {
                friendCamera.cancel()
            }
            userCamera.stopFollowing()
            guard let memberID = socialProximityController.activate(
                annotation,
                view: view,
                on: mapView
            ) else { return }
            switch memberID {
            case .currentUser:
                onSelectOwnProfile()
            case .friend(let userID):
                onSelectFriend(userID)
            case .outing(let eventID):
                if notifyOutingSelection { onSelectOutingPlan(eventID) }
            }
        }

        func mapView(_ mapView: MapboxMaps.MapView, didDeselect view: MapAnnotationView) {
            guard let annotation = view.annotation else { return }
            socialProximityController.didDeselect(annotation, on: mapView)
        }

        func updateUserMarkerAppearance(
            displayName: String,
            avatarID: String,
            profileColorHex: String,
            presenceInfo: MapUserPresenceInfo,
            on mapView: MapboxMaps.MapView
        ) {
            let normalizedAvatarID = ProfileAvatar.normalizedID(avatarID)
                ?? ProfileAvatar.cyclopsHorns.id
            let normalizedProfileColorHex = ProfileColor.normalizedHex(
                profileColorHex
            ) ?? ProfileColor.generatedHex(seed: profileColorHex)

            guard userDisplayName != displayName ||
                    userAvatarID != normalizedAvatarID ||
                    userProfileColorHex != normalizedProfileColorHex ||
                    userPresenceInfo != presenceInfo else { return }

            userDisplayName = displayName
            userAvatarID = normalizedAvatarID
            userProfileColorHex = normalizedProfileColorHex
            userPresenceInfo = presenceInfo

            guard let annotation = userLocationAnnotation,
                  let annotationView = annotationStore.view(for: annotation)
                    as? UserLocationAnnotationView else { return }

            annotationView.configure(
                avatarID: normalizedAvatarID,
                profileColorHex: normalizedProfileColorHex,
                presenceInfo: presenceInfo
            )
            annotationView.accessibilityHint = "Ouvrir mon profil"
        }

        func configureFriendAnnotationView(
            _ annotationView: MapAnnotationView,
            avatarID: String,
            profileColorHex: String,
            presenceInfo: MapUserPresenceInfo,
            isRefreshingLocation: Bool
        ) {
            guard let annotationView = annotationView as? UserLocationAnnotationView,
                  annotationView.annotation is FriendLocationAnnotation else {
                return
            }

            annotationView.configure(
                avatarID: avatarID,
                profileColorHex: profileColorHex,
                presenceInfo: presenceInfo,
                isRefreshingLocation: isRefreshingLocation
            )
            annotationView.accessibilityHint = "Afficher le profil de cet ami"
        }
    }
}

// MARK: - User camera

/// Follows CoreLocation updates while preserving the user's map orientation.
@MainActor
final class MapUserCameraController {
    // Avoid synthesized isolated deinit on older Swift runtimes (swiftlang/swift#88036).
    // Animation cleanup remains in stopFollowing() on the main actor.
    nonisolated deinit {}

    private(set) var isFollowing = false
    private(set) var isAnimating = false
    private var latestCoordinate: CLLocationCoordinate2D?
    private var lastAppliedCoordinate: CLLocationCoordinate2D?
    private var animationGeneration = 0
    private var animation: Cancelable?

    static func hasUsableBounds(on mapView: MapboxMaps.MapView) -> Bool {
        let size = mapView.bounds.size
        return size.width.isFinite && size.height.isFinite
            && size.width > 0 && size.height > 0
    }

    static func focusedCamera(
        at coordinate: CLLocationCoordinate2D,
        on mapView: MapboxMaps.MapView
    ) -> CameraOptions {
        guard hasUsableBounds(on: mapView) else { return CameraOptions(center: coordinate) }
        // Fit an 800-metre square using the map's rendered dimensions.
        let latitudeRadians = coordinate.latitude * .pi / 180
        let metersPerPointAtZero = cos(latitudeRadians) * 40_075_016.686 / 512
        let points = min(mapView.bounds.width, mapView.bounds.height)
        let zoom = log2(max(1, metersPerPointAtZero * Double(points) / 800))
        return CameraOptions(center: coordinate, zoom: zoom)
    }

    func recenter(on mapView: MapboxMaps.MapView, at coordinate: CLLocationCoordinate2D) {
        guard CLLocationCoordinate2DIsValid(coordinate),
              Self.hasUsableBounds(on: mapView) else { return }
        latestCoordinate = coordinate
        isFollowing = true
        guard !isAnimating else { return }

        let target = Self.focusedCamera(at: coordinate, on: mapView)
        let current = mapView.mapboxMap.cameraState
        let isAtTarget = distance(current.center, coordinate) <= 5
            && abs(current.zoom - (target.zoom ?? current.zoom)) <= 0.01
        lastAppliedCoordinate = coordinate
        guard !isAtTarget else { return }
        animate(to: target, on: mapView)
    }

    func updateLocation(_ coordinate: CLLocationCoordinate2D, on mapView: MapboxMaps.MapView) {
        guard CLLocationCoordinate2DIsValid(coordinate) else { return }
        latestCoordinate = coordinate
        followLatestLocation(on: mapView)
    }

    func stopFollowing() {
        isFollowing = false
        isAnimating = false
        latestCoordinate = nil
        lastAppliedCoordinate = nil
        animationGeneration &+= 1
        animation?.cancel()
        animation = nil
    }

    private func animate(to camera: CameraOptions, on mapView: MapboxMaps.MapView) {
        isAnimating = true
        animationGeneration &+= 1
        let generation = animationGeneration
        animation = mapView.camera.ease(to: camera, duration: 0.35) { [weak self, weak mapView] _ in
            guard let self, let mapView, generation == self.animationGeneration else { return }
            self.animation = nil
            self.isAnimating = false
            self.followLatestLocation(on: mapView)
        }
    }

    private func followLatestLocation(on mapView: MapboxMaps.MapView) {
        guard isFollowing, !isAnimating,
              let coordinate = latestCoordinate,
              let lastAppliedCoordinate,
              distance(lastAppliedCoordinate, coordinate) > 5 else { return }
        self.lastAppliedCoordinate = coordinate
        animate(to: CameraOptions(center: coordinate), on: mapView)
    }

    private func distance(
        _ first: CLLocationCoordinate2D,
        _ second: CLLocationCoordinate2D
    ) -> CLLocationDistance {
        CLLocation(latitude: first.latitude, longitude: first.longitude).distance(
            from: CLLocation(latitude: second.latitude, longitude: second.longitude)
        )
    }
}
