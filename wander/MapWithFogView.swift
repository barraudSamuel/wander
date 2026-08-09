//
//  MapWithFogView.swift
//  wander
//
//  UIViewRepresentable bridge around MKMapView that renders a uniform fog of war.
//  A world-sized overlay fills the visible map with semi-transparent grey, and
//  every discovered H3 cell is punched through so Apple Maps shows where the
//  user has been.
//

import SwiftUI
import MapKit
import CoreLocation

private func markerForegroundColor(for backgroundColor: UIColor) -> UIColor {
    ProfileColor.contrastingUIColor(for: backgroundColor)
}

struct MapUserCalloutInfo: Equatable {
    let displayName: String
    let relationshipText: String
    let isExplorationLoaded: Bool
    let cityProgress: CityProgress?
    let totalExploredCellCount: Int
    let coordinate: MapUserCoordinate?
    let locationSampledAt: Date?
    let spotEnteredAt: Date?
    let keepsSpotDurationVisible: Bool
}

private struct FriendCalloutActions {
    let join: () -> Void
    let viewProfile: () -> Void
}

private enum UserLocationCalloutContent {
    case information
    case friendActions(FriendCalloutActions)

    var showsFriendActions: Bool {
        if case .friendActions = self {
            return true
        }
        return false
    }
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

    func distance(to other: MapUserCoordinate) -> CLLocationDistance {
        location.distance(from: other.location)
    }

    var cacheKey: NSString {
        let roundedLatitude = Int((latitude * 10_000).rounded())
        let roundedLongitude = Int((longitude * 10_000).rounded())
        return "\(roundedLatitude):\(roundedLongitude)" as NSString
    }
}

final class UserLocationAnnotation: MKPointAnnotation {}

final class FriendLocationAnnotation: MKPointAnnotation {
    var userID = ""
}

private final class CircularDurationView: UIView {
    private static let rotationAnimationKey = "wander.circularDuration.rotation"
    private var isRotationRequested = false

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

    private func configureView() {
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        contentMode = .redraw
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reduceMotionStatusDidChange),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateRotationAnimation()
    }

    func setRotationEnabled(_ isEnabled: Bool) {
        guard isRotationRequested != isEnabled else { return }
        isRotationRequested = isEnabled
        updateRotationAnimation()
    }

    @objc private func reduceMotionStatusDidChange() {
        updateRotationAnimation()
    }

    private func updateRotationAnimation() {
        let shouldRotate = isRotationRequested
            && window != nil
            && !UIAccessibility.isReduceMotionEnabled

        guard shouldRotate else {
            layer.removeAnimation(forKey: Self.rotationAnimationKey)
            return
        }
        guard layer.animation(forKey: Self.rotationAnimationKey) == nil else {
            return
        }

        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = 2 * CGFloat.pi
        rotation.duration = 24
        rotation.repeatCount = .infinity
        rotation.timingFunction = CAMediaTimingFunction(name: .linear)
        layer.add(rotation, forKey: Self.rotationAnimationKey)
    }

    override func draw(_ rect: CGRect) {
        guard let text, !text.isEmpty else { return }

        let baseFont = UIFont.systemFont(ofSize: 11, weight: .black)
        let font = baseFont.fontDescriptor.withDesign(.rounded).map {
            UIFont(descriptor: $0, size: 11)
        } ?? baseFont
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(
                red: 0.08,
                green: 0.08,
                blue: 0.12,
                alpha: 1
            ),
            .strokeColor: UIColor.white.withAlphaComponent(0.94),
            .strokeWidth: -4.5,
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

            guard let context = UIGraphicsGetCurrentContext() else { return }
            context.saveGState()
            context.translateBy(x: glyphCenter.x, y: glyphCenter.y)
            context.rotate(by: angle + CGFloat.pi / 2)
            context.setShadow(
                offset: CGSize(width: 0, height: 1),
                blur: 1.5,
                color: UIColor.black.withAlphaComponent(0.22).cgColor
            )
            (glyph as NSString).draw(at: drawingPoint, withAttributes: attributes)
            context.restoreGState()

            angle += advance / 2
        }
    }
}

final class UserLocationAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "UserLocationAnnotation"
    static let friendReuseIdentifier = "FriendLocationAnnotation"

    private let markerRingView = UIView()
    private let presenceHaloView = UIView()
    private let circularDurationView = CircularDurationView()
    private let avatarImageView = UIImageView()
    private let fallbackLabel = UILabel()
    private var configuredAvatarImageData: Data?
    private var configuredDisplayName: String?
    private var configuredProfileColorHex: String?
    private var configuredCalloutInfo: MapUserCalloutInfo?
    private var calloutContent = UserLocationCalloutContent.information
    private var presenceRefreshTimer: Timer?
    private var showsPresenceDuration = false
    private var addressRequest: MKReverseGeocodingRequest?
    private var addressCoordinate: MapUserCoordinate?
    private var addressResolutionState = AddressResolutionState.idle
    private var copyConfirmationResetWorkItem: DispatchWorkItem?
    private lazy var copyAddressButton: UIButton = {
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        button.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        button.accessibilityLabel = "Copier l’adresse"
        button.accessibilityHint = "Copie la dernière adresse connue"
        return button
    }()

    private static let addressCache: NSCache<NSString, NSString> = {
        let cache = NSCache<NSString, NSString>()
        cache.countLimit = 200
        return cache
    }()
    private static let addressRefreshDistance: CLLocationDistance = 20

    private enum AddressResolutionState {
        case idle
        case loading
        case resolved(String)
        case unavailable
    }

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        circularDurationView.frame = bounds

        let markerSize: CGFloat = showsPresenceDuration ? 48 : 32
        let haloSize: CGFloat = showsPresenceDuration ? 66 : markerSize
        presenceHaloView.frame = CGRect(
            x: (bounds.width - haloSize) / 2,
            y: (bounds.height - haloSize) / 2,
            width: haloSize,
            height: haloSize
        )
        presenceHaloView.layer.cornerRadius = haloSize / 2
        presenceHaloView.layer.shadowPath = UIBezierPath(
            ovalIn: presenceHaloView.bounds
        ).cgPath

        markerRingView.frame = CGRect(
            x: (bounds.width - markerSize) / 2,
            y: (bounds.height - markerSize) / 2,
            width: markerSize,
            height: markerSize
        )
        markerRingView.layer.cornerRadius = markerSize / 2
        markerRingView.layer.shadowPath = UIBezierPath(
            ovalIn: markerRingView.bounds
        ).cgPath

        let avatarInset: CGFloat = 3
        avatarImageView.frame = markerRingView.bounds.insetBy(
            dx: avatarInset,
            dy: avatarInset
        )
        avatarImageView.layer.cornerRadius = avatarImageView.bounds.width / 2
        fallbackLabel.frame = avatarImageView.frame
        fallbackLabel.layer.cornerRadius = fallbackLabel.bounds.width / 2
        fallbackLabel.font = .systemFont(
            ofSize: showsPresenceDuration ? 22 : 18,
            weight: .black
        )
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        let wasSelected = isSelected
        super.setSelected(selected, animated: animated)
        guard selected != wasSelected else { return }

        if selected {
            refreshPresencePresentation()
            refreshCallout()
        } else {
            pauseAddressResolution()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        stopPresenceRefreshTimer()
        resetAddressResolution()
        configuredCalloutInfo = nil
        calloutContent = .information
        setCircularDurationText(nil)
    }

    deinit {
        presenceRefreshTimer?.invalidate()
        addressRequest?.cancel()
        copyConfirmationResetWorkItem?.cancel()
    }

    fileprivate func configure(
        avatarImageData: Data,
        displayName: String,
        profileColorHex: String,
        calloutInfo: MapUserCalloutInfo,
        calloutContent: UserLocationCalloutContent = .information
    ) {
        let calloutModeChanged = self.calloutContent.showsFriendActions
            != calloutContent.showsFriendActions
        self.calloutContent = calloutContent

        if configuredAvatarImageData != avatarImageData
            || configuredDisplayName != displayName
            || configuredProfileColorHex != profileColorHex {
            let profileColor = ProfileColor.uiColor(hex: profileColorHex)
            markerRingView.backgroundColor = profileColor
            markerRingView.layer.shadowColor = profileColor.cgColor
            presenceHaloView.backgroundColor = profileColor.withAlphaComponent(0.16)
            presenceHaloView.layer.borderColor = profileColor.withAlphaComponent(0.62).cgColor
            presenceHaloView.layer.shadowColor = profileColor.cgColor
            fallbackLabel.backgroundColor = profileColor
            fallbackLabel.textColor = markerForegroundColor(for: profileColor)

            if let image = UIImage(data: avatarImageData) {
                avatarImageView.image = image
                avatarImageView.isHidden = false
                fallbackLabel.isHidden = true
            } else {
                let trimmedName = displayName.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                fallbackLabel.text = trimmedName.isEmpty
                    ? "W"
                    : String(trimmedName.prefix(1)).uppercased()
                avatarImageView.image = nil
                avatarImageView.isHidden = true
                fallbackLabel.isHidden = false
            }

            configuredAvatarImageData = avatarImageData
            configuredDisplayName = displayName
            configuredProfileColorHex = profileColorHex
        }

        if configuredCalloutInfo != calloutInfo || calloutModeChanged {
            if shouldResetAddress(for: calloutInfo.coordinate) {
                resetAddressResolution()
            }
            configuredCalloutInfo = calloutInfo
            refreshPresencePresentation()
            refreshCallout()
            accessibilityLabel = "\(calloutInfo.displayName), \(calloutInfo.relationshipText)"
            accessibilityHint = calloutContent.showsFriendActions
                ? "Touchez pour afficher les actions de cet ami"
                : "Touchez pour afficher l’adresse et les informations d’exploration"
            accessibilityTraits = .button
        }
    }

    private func shouldResetAddress(
        for coordinate: MapUserCoordinate?
    ) -> Bool {
        guard let addressCoordinate else { return false }
        guard let coordinate else { return true }
        return addressCoordinate.distance(to: coordinate)
            >= Self.addressRefreshDistance
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
        guard let configuredCalloutInfo else {
            setCircularDurationText(nil)
            stopPresenceRefreshTimer()
            return
        }

        let referenceDate = Date()
        let circularText = Self.circularDurationText(
            enteredAt: configuredCalloutInfo.spotEnteredAt,
            sampledAt: configuredCalloutInfo.locationSampledAt,
            relativeTo: referenceDate,
            keepsSpotDurationVisible: configuredCalloutInfo.keepsSpotDurationVisible
        )
        let didChange = circularDurationView.text != circularText
        setCircularDurationText(circularText)
        accessibilityValue = Self.presenceText(
            enteredAt: configuredCalloutInfo.spotEnteredAt,
            sampledAt: configuredCalloutInfo.locationSampledAt,
            relativeTo: referenceDate,
            keepsSpotDurationVisible: configuredCalloutInfo.keepsSpotDurationVisible
        )

        if circularText == nil {
            stopPresenceRefreshTimer()
        } else {
            ensurePresenceRefreshTimer()
        }

        if isSelected, didChange {
            refreshCallout()
        }
    }

    private func setCircularDurationText(_ text: String?) {
        let shouldShow = text != nil
        circularDurationView.text = text
        circularDurationView.isHidden = !shouldShow
        circularDurationView.setRotationEnabled(shouldShow)
        presenceHaloView.isHidden = !shouldShow

        guard showsPresenceDuration != shouldShow else { return }
        showsPresenceDuration = shouldShow
        let viewSize: CGFloat = shouldShow ? 112 : 44
        bounds = CGRect(x: 0, y: 0, width: viewSize, height: viewSize)
        setNeedsLayout()
    }

    private func refreshCallout() {
        guard let configuredCalloutInfo else { return }
        detailCalloutAccessoryView = makeCalloutDetailView(
            for: configuredCalloutInfo,
            addressText: addressText
        )

        if calloutContent.showsFriendActions {
            rightCalloutAccessoryView = nil
            return
        }

        updateCopyAddressAccessory()
        resolveAddressIfNeeded(for: configuredCalloutInfo)
    }

    func copyResolvedAddressToPasteboard() {
        guard case .resolved(let address) = addressResolutionState else {
            return
        }

        UIPasteboard.general.string = address
        copyConfirmationResetWorkItem?.cancel()
        copyAddressButton.setImage(
            UIImage(systemName: "checkmark"),
            for: .normal
        )
        copyAddressButton.accessibilityLabel = "Adresse copiée"
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        UIAccessibility.post(
            notification: .announcement,
            argument: "Adresse copiée"
        )

        let resetWorkItem = DispatchWorkItem { [weak self] in
            self?.resetCopyAddressButtonAppearance()
        }
        copyConfirmationResetWorkItem = resetWorkItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 1.5,
            execute: resetWorkItem
        )
    }

    private func updateCopyAddressAccessory() {
        guard case .resolved = addressResolutionState else {
            copyConfirmationResetWorkItem?.cancel()
            copyConfirmationResetWorkItem = nil
            resetCopyAddressButtonAppearance()
            rightCalloutAccessoryView = nil
            return
        }

        if rightCalloutAccessoryView !== copyAddressButton {
            resetCopyAddressButtonAppearance()
            rightCalloutAccessoryView = copyAddressButton
        }
    }

    private func resetCopyAddressButtonAppearance() {
        copyAddressButton.setImage(
            UIImage(systemName: "doc.on.doc"),
            for: .normal
        )
        copyAddressButton.accessibilityLabel = "Copier l’adresse"
    }

    private var addressText: String? {
        switch addressResolutionState {
        case .idle:
            nil
        case .loading:
            "Recherche de la dernière adresse…"
        case .resolved(let address):
            "Dernière adresse connue : \(address)"
        case .unavailable:
            "Adresse de la dernière position indisponible"
        }
    }

    private func resolveAddressIfNeeded(for info: MapUserCalloutInfo) {
        guard isSelected,
              case .idle = addressResolutionState,
              let coordinate = info.coordinate else {
            return
        }

        if let cachedAddress = Self.addressCache.object(
            forKey: coordinate.cacheKey
        ) {
            addressCoordinate = coordinate
            addressResolutionState = .resolved(cachedAddress as String)
            refreshCallout()
            return
        }

        guard let request = MKReverseGeocodingRequest(
            location: coordinate.location
        ) else {
            addressResolutionState = .unavailable
            refreshCallout()
            return
        }

        addressCoordinate = coordinate
        addressResolutionState = .loading
        addressRequest = request
        refreshCallout()

        request.getMapItems { [weak self] mapItems, _ in
            guard let self,
                  self.addressRequest === request,
                  self.addressCoordinate == coordinate else {
                return
            }

            self.addressRequest = nil
            if let address = Self.formattedAddress(from: mapItems) {
                Self.addressCache.setObject(
                    address as NSString,
                    forKey: coordinate.cacheKey
                )
                self.addressResolutionState = .resolved(address)
            } else {
                self.addressResolutionState = .unavailable
            }

            if self.isSelected {
                self.refreshCallout()
            }
        }
    }

    private func pauseAddressResolution() {
        if case .loading = addressResolutionState {
            addressRequest?.cancel()
            addressRequest = nil
            addressResolutionState = .idle
        } else if case .unavailable = addressResolutionState {
            addressResolutionState = .idle
        }
    }

    private func resetAddressResolution() {
        addressRequest?.cancel()
        addressRequest = nil
        addressCoordinate = nil
        addressResolutionState = .idle
        copyConfirmationResetWorkItem?.cancel()
        copyConfirmationResetWorkItem = nil
        resetCopyAddressButtonAppearance()
        rightCalloutAccessoryView = nil
    }

    private static func formattedAddress(
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

    private func configureView() {
        frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        backgroundColor = .clear
        clipsToBounds = false
        canShowCallout = true
        collisionMode = .none
        displayPriority = .required
        isAccessibilityElement = true

        circularDurationView.isHidden = true
        addSubview(circularDurationView)

        presenceHaloView.isHidden = true
        presenceHaloView.isUserInteractionEnabled = false
        presenceHaloView.layer.borderWidth = 2
        presenceHaloView.layer.shadowOpacity = 0.34
        presenceHaloView.layer.shadowRadius = 10
        presenceHaloView.layer.shadowOffset = .zero
        addSubview(presenceHaloView)

        markerRingView.layer.borderColor = UIColor.white.cgColor
        markerRingView.layer.borderWidth = 1.5
        markerRingView.layer.shadowOpacity = 0.38
        markerRingView.layer.shadowRadius = 8
        markerRingView.layer.shadowOffset = .zero
        markerRingView.isUserInteractionEnabled = false
        addSubview(markerRingView)

        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarImageView.layer.borderColor = UIColor.white.withAlphaComponent(0.85).cgColor
        avatarImageView.layer.borderWidth = 1
        markerRingView.addSubview(avatarImageView)

        fallbackLabel.backgroundColor = UIColor.systemBlue
        fallbackLabel.font = .systemFont(ofSize: 18, weight: .black)
        fallbackLabel.textAlignment = .center
        fallbackLabel.clipsToBounds = true
        fallbackLabel.layer.borderColor = UIColor.white.withAlphaComponent(0.85).cgColor
        fallbackLabel.layer.borderWidth = 1
        markerRingView.addSubview(fallbackLabel)

        setNeedsLayout()
    }

    private func makeCalloutDetailView(
        for info: MapUserCalloutInfo,
        addressText: String?
    ) -> UIView {
        if calloutContent.showsFriendActions {
            return makeFriendActionView(for: info)
        }

        let label = UILabel()
        label.numberOfLines = 0
        label.preferredMaxLayoutWidth = 230
        label.adjustsFontForContentSizeCategory = true

        let content = NSMutableAttributedString()
        content.append(
            NSAttributedString(
                string: info.relationshipText.uppercased(),
                attributes: [
                    .font: UIFont.preferredFont(forTextStyle: .caption2),
                    .foregroundColor: UIColor.secondaryLabel
                ]
            )
        )
        content.append(NSAttributedString(string: "\n"))

        let progressText: String
        let progressDetailText: String
        if !info.isExplorationLoaded {
            progressText = "Exploration indisponible"
            progressDetailText = "La progression n’a pas encore été chargée"
        } else if let progress = info.cityProgress {
            let percentage = progress.percentage.formatted(
                .percent.precision(.fractionLength(1))
            )
            progressText = "\(percentage) exploré"
            progressDetailText = [
                progress.cityName,
                "\(progress.exploredCells.formatted()) / \(progress.totalCells.formatted()) zones"
            ].joined(separator: " · ")
        } else {
            progressText = Self.exploredZoneText(info.totalExploredCellCount)
            progressDetailText = "Progression par ville indisponible"
        }

        content.append(
            NSAttributedString(
                string: progressText,
                attributes: [
                    .font: UIFont.preferredFont(forTextStyle: .headline),
                    .foregroundColor: UIColor.label
                ]
            )
        )
        content.append(NSAttributedString(string: "\n"))
        content.append(
            NSAttributedString(
                string: progressDetailText,
                attributes: [
                    .font: UIFont.preferredFont(forTextStyle: .caption1),
                    .foregroundColor: UIColor.secondaryLabel
                ]
            )
        )

        if let addressText {
            content.append(NSAttributedString(string: "\n"))
            content.append(
                NSAttributedString(
                    string: addressText,
                    attributes: [
                        .font: UIFont.preferredFont(forTextStyle: .caption1),
                        .foregroundColor: UIColor.label
                    ]
                )
            )
        }

        let presenceText = Self.presenceText(
            enteredAt: info.spotEnteredAt,
            sampledAt: info.locationSampledAt,
            relativeTo: Date(),
            keepsSpotDurationVisible: info.keepsSpotDurationVisible
        )
        if let presenceText {
            content.append(NSAttributedString(string: "\n"))
            content.append(
                NSAttributedString(
                    string: presenceText,
                    attributes: [
                        .font: UIFont.preferredFont(forTextStyle: .caption1),
                        .foregroundColor: UIColor.secondaryLabel
                    ]
                )
            )
        }

        if let locationText = Self.locationText(sampledAt: info.locationSampledAt) {
            content.append(NSAttributedString(string: "\n"))
            content.append(
                NSAttributedString(
                    string: locationText,
                    attributes: [
                        .font: UIFont.preferredFont(forTextStyle: .caption1),
                        .foregroundColor: UIColor.tertiaryLabel
                    ]
                )
            )
        }

        label.attributedText = content
        label.accessibilityLabel = [
            info.relationshipText,
            progressText,
            progressDetailText,
            addressText,
            presenceText,
            Self.locationText(sampledAt: info.locationSampledAt)
        ]
        .compactMap { $0 }
        .joined(separator: ", ")

        return label
    }

    private func makeFriendActionView(for info: MapUserCalloutInfo) -> UIView {
        let joinButton = UIButton(type: .system)
        var joinConfiguration = UIButton.Configuration.plain()
        joinConfiguration.image = UIImage(systemName: "figure.walk")
        joinConfiguration.baseForegroundColor = .label
        joinConfiguration.preferredSymbolConfigurationForImage =
            UIImage.SymbolConfiguration(pointSize: 19, weight: .medium)
        joinConfiguration.contentInsets = .zero
        joinButton.configuration = joinConfiguration
        joinButton.isEnabled = info.coordinate != nil
        joinButton.accessibilityLabel = "Rejoindre \(info.displayName)"
        joinButton.accessibilityHint = "Choisir une application pour afficher l’itinéraire"
        joinButton.addTarget(
            self,
            action: #selector(joinButtonTapped),
            for: .touchUpInside
        )

        let profileButton = UIButton(type: .system)
        var profileConfiguration = UIButton.Configuration.plain()
        profileConfiguration.image = UIImage(systemName: "person.crop.circle")
        profileConfiguration.baseForegroundColor = .label
        profileConfiguration.preferredSymbolConfigurationForImage =
            UIImage.SymbolConfiguration(pointSize: 19, weight: .medium)
        profileConfiguration.contentInsets = .zero
        profileButton.configuration = profileConfiguration
        profileButton.accessibilityLabel = "Voir le profil de \(info.displayName)"
        profileButton.accessibilityHint = "Afficher les informations de cet ami"
        profileButton.addTarget(
            self,
            action: #selector(profileButtonTapped),
            for: .touchUpInside
        )

        let separator = UIView()
        separator.backgroundColor = .separator
        separator.widthAnchor.constraint(equalToConstant: 0.5).isActive = true
        separator.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let stack = UIStackView(
            arrangedSubviews: [joinButton, separator, profileButton]
        )
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 0
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 4,
            leading: 2,
            bottom: 4,
            trailing: 2
        )

        for button in [joinButton, profileButton] {
            button.widthAnchor.constraint(equalToConstant: 44).isActive = true
            button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        }

        return stack
    }

    @objc private func joinButtonTapped() {
        guard let configuredCalloutInfo,
              configuredCalloutInfo.coordinate != nil else {
            return
        }
        guard case .friendActions(let actions) = calloutContent else { return }
        actions.join()
    }

    @objc private func profileButtonTapped() {
        guard configuredCalloutInfo != nil else { return }
        guard case .friendActions(let actions) = calloutContent else { return }
        actions.viewProfile()
    }

    private static func exploredZoneText(_ count: Int) -> String {
        switch count {
        case 0:
            "Aucune zone explorée"
        case 1:
            "1 zone explorée"
        default:
            "\(count.formatted()) zones explorées"
        }
    }

    private static func locationText(sampledAt: Date?) -> String? {
        guard let sampledAt else { return nil }

        if Calendar.autoupdatingCurrent.isDateInToday(sampledAt) {
            return "Dernière position à \(positionTimeFormatter.string(from: sampledAt))"
        }

        return "Dernière position le \(positionDateTimeFormatter.string(from: sampledAt))"
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
        return "Au même endroit depuis \(durationText(duration))"
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

    private static func durationText(_ duration: TimeInterval) -> String {
        let totalMinutes = max(0, Int(duration / 60))
        guard totalMinutes > 0 else { return "moins d’1 min" }

        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60

        if days > 0 {
            return hours > 0 ? "\(days) j \(hours) h" : "\(days) j"
        }
        if hours > 0 {
            return minutes > 0 ? "\(hours) h \(minutes) min" : "\(hours) h"
        }
        return "\(minutes) min"
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

struct FriendScratchCellPolygon {
    let coordinates: [CLLocationCoordinate2D]
    let mapRect: MKMapRect
}

final class FriendScratchOverlay: NSObject, MKOverlay {
    let userID: String
    let color: UIColor
    let boundingMapRect: MKMapRect
    let coordinate: CLLocationCoordinate2D
    let cellPolygons: [String: FriendScratchCellPolygon]

    init(
        userID: String,
        cellIDs: Set<String>,
        color: UIColor,
        explorationEngine: ExplorationEngine
    ) {
        self.userID = userID
        self.color = color

        var polygons: [String: FriendScratchCellPolygon] = [:]
        var minLat = 90.0
        var maxLat = -90.0
        var minLng = 180.0
        var maxLng = -180.0

        for cellID in cellIDs.sorted() {
            let coordinates = explorationEngine.boundaryCoordinates(for: cellID)
            guard coordinates.count >= 3 else { continue }

            polygons[cellID] = FriendScratchCellPolygon(
                coordinates: coordinates,
                mapRect: Self.mapRect(for: coordinates)
            )

            for coordinate in coordinates {
                minLat = min(minLat, coordinate.latitude)
                maxLat = max(maxLat, coordinate.latitude)
                minLng = min(minLng, coordinate.longitude)
                maxLng = max(maxLng, coordinate.longitude)
            }
        }

        cellPolygons = polygons

        if polygons.isEmpty {
            coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
            boundingMapRect = .null
        } else {
            coordinate = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLng + maxLng) / 2
            )

            let topLeft = MKMapPoint(
                CLLocationCoordinate2D(latitude: maxLat, longitude: minLng)
            )
            let bottomRight = MKMapPoint(
                CLLocationCoordinate2D(latitude: minLat, longitude: maxLng)
            )
            let padding = 1_000.0
            boundingMapRect = MKMapRect(
                x: topLeft.x - padding,
                y: topLeft.y - padding,
                width: bottomRight.x - topLeft.x + padding * 2,
                height: bottomRight.y - topLeft.y + padding * 2
            )
        }

        super.init()
    }

    private static func mapRect(
        for coordinates: [CLLocationCoordinate2D]
    ) -> MKMapRect {
        coordinates.reduce(.null) { partialResult, coordinate in
            let point = MKMapPoint(coordinate)
            return partialResult.union(
                MKMapRect(x: point.x, y: point.y, width: 1, height: 1)
            )
        }
    }
}

final class FriendScratchOverlayRenderer: MKOverlayRenderer {
    override func canDraw(_ mapRect: MKMapRect, zoomScale: MKZoomScale) -> Bool {
        true
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let overlay = overlay as? FriendScratchOverlay,
              !overlay.cellPolygons.isEmpty else { return }

        let color = overlay.color
        context.setLineWidth(1 / zoomScale)
        context.setFillColor(color.withAlphaComponent(0.34).cgColor)
        context.setStrokeColor(color.withAlphaComponent(0.75).cgColor)

        for polygon in overlay.cellPolygons.values
            where polygon.mapRect.intersects(mapRect) {

            context.beginPath()
            for (index, coordinate) in polygon.coordinates.enumerated() {
                let point = point(for: MKMapPoint(coordinate))
                if index == 0 {
                    context.move(to: point)
                } else {
                    context.addLine(to: point)
                }
            }
            context.closePath()
            context.drawPath(using: .fillStroke)
        }
    }
}

struct FogCellPolygon {
    let coordinates: [CLLocationCoordinate2D]
    let mapRect: MKMapRect
}

final class FogOfWarOverlay: NSObject, MKOverlay {
    let coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    let boundingMapRect = MKMapRect.world
    let cellPolygons: [FogCellPolygon]

    init(cellIDs: Set<String>, explorationEngine: ExplorationEngine) {
        self.cellPolygons = cellIDs.sorted().compactMap { cellID in
            let coords = explorationEngine.boundaryCoordinates(for: cellID)
            guard coords.count >= 3 else { return nil }
            return FogCellPolygon(
                coordinates: coords,
                mapRect: Self.mapRect(for: coords)
            )
        }
        super.init()
    }

    private static func mapRect(for coordinates: [CLLocationCoordinate2D]) -> MKMapRect {
        coordinates.reduce(MKMapRect.null) { partialResult, coordinate in
            let point = MKMapPoint(coordinate)
            let pointRect = MKMapRect(
                x: point.x,
                y: point.y,
                width: 1,
                height: 1
            )
            return partialResult.union(pointRect)
        }
    }
}

final class FogOfWarOverlayRenderer: MKOverlayRenderer {
    private let fogColor: UIColor

    init(overlay: FogOfWarOverlay, fogColor: UIColor) {
        self.fogColor = fogColor
        super.init(overlay: overlay)
    }

    override func canDraw(_ mapRect: MKMapRect, zoomScale: MKZoomScale) -> Bool {
        true
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let overlay = overlay as? FogOfWarOverlay else { return }

        let path = CGMutablePath()
        path.addRect(rect(for: mapRect))

        for cell in overlay.cellPolygons where cell.mapRect.intersects(mapRect) {
            for (index, coordinate) in cell.coordinates.enumerated() {
                let point = self.point(for: MKMapPoint(coordinate))
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.closeSubpath()
        }

        context.addPath(path)
        context.setFillColor(fogColor.cgColor)
        context.drawPath(using: .eoFill)
    }
}

struct MapWithFogView: UIViewRepresentable {
    @ObservedObject var locationTracker: LocationTracker

    /// Set of H3 cell IDs that should be punched through the fog.
    var discoveredCellIDs: Set<String>

    /// City boundary used only for the initial map fit. Fog is global.
    var cityBoundaryCoordinates: [CLLocationCoordinate2D]

    /// Fresh locations belonging to accepted friends.
    var friendLocations: [String: FriendLocation] = [:]

    /// Selected friends whose explored cells are visible on the map.
    var friendExplorations: [String: FriendExploration] = [:]

    /// All accepted-friend exploration data, including maps not currently visible.
    var allFriendExplorations: [String: FriendExploration] = [:]

    /// Exploration progress for the city containing each visible user marker.
    var userExplorationProgress: CityProgress?
    var friendExplorationProgress: [String: CityProgress] = [:]
    var loadedFriendExplorationUserIDs: Set<String> = []

    var userDisplayName = ""
    var userAvatarImageData = Data()
    var userProfileColorHex = ""

    /// Fog colour — used by the polygon renderer.
    var fogColor: UIColor = UIColor.black.withAlphaComponent(0.45)

    /// When toggled, follows the user's location while keeping north at the top.
    @Binding var centerOnUser: Bool

    /// When toggled, resets the map camera to a north-up, flat orientation.
    @Binding var resetMapOrientation: Bool

    /// When set, centers the map on the selected friend once.
    @Binding var centerOnFriendUserID: String?

    var showsHeatMap = false
    var heatMapCellData: [String: (duration: TimeInterval, visitCount: Int)] = [:]
    /// Monotonic token that must change whenever heat-map values change.
    var heatMapRevision: Int = 0

    /// Presents external navigation choices for the selected friend.
    var onJoinFriend: (String) -> Void = { _ in }

    /// Presents the native profile sheet for the selected friend.
    var onViewFriendProfile: (String) -> Void = { _ in }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.preferredConfiguration = MKStandardMapConfiguration(
            elevationStyle: .flat,
            emphasisStyle: .muted
        )
        mapView.showsUserLocation = true
        mapView.showsCompass = true
        mapView.userTrackingMode = .none

        // Failsafe initial view over Ho Chi Minh City before the boundary loads.
        mapView.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 10.76, longitude: 106.66),
            span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
        )

        updateFogOverlay(
            on: mapView,
            context: context,
            visibleDiscoveredCellIDs: visibleDiscoveredCellIDs
        )
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        context.coordinator.onJoinFriend = onJoinFriend
        context.coordinator.onViewFriendProfile = onViewFriendProfile

        let visibleCellIDs = visibleDiscoveredCellIDs
        let boundaryChanged = context.coordinator.lastBoundaryLength != cityBoundaryCoordinates.count
        let discoveredChanged = context.coordinator.lastDiscoveredIDs != visibleCellIDs
        let heatMapVisibilityChanged = context.coordinator.lastShowsHeatMap != showsHeatMap
        let friendExplorationsChanged =
            context.coordinator.lastFriendExplorations != friendExplorations
        let heatMapDataChanged =
            context.coordinator.lastHeatMapRevision != heatMapRevision

        if boundaryChanged || discoveredChanged {
            updateFogOverlay(
                on: uiView,
                context: context,
                visibleDiscoveredCellIDs: visibleCellIDs
            )
        }

        if heatMapVisibilityChanged || heatMapDataChanged {
            updateHeatMapOverlay(on: uiView, context: context)
        }

        if friendExplorationsChanged {
            updateFriendScratchOverlays(on: uiView, context: context)
        }

        updateFriendAnnotations(on: uiView, context: context)
        updateUserLocationAnnotation(on: uiView, context: context)
        context.coordinator.lastShowsHeatMap = showsHeatMap

        // A loaded city boundary is only a temporary starting region. Always
        // let the first valid user location take precedence, then leave later
        // camera movement under the user's control.
        if let coordinate = locationTracker.lastLocation?.coordinate,
           !context.coordinator.didCenterOnUser {
            context.coordinator.didCenterOnUser = true
            context.coordinator.didSetInitialRegion = true
            setFocusedRegion(on: uiView, center: coordinate, animated: true)
        } else if !context.coordinator.didSetInitialRegion,
                  cityBoundaryCoordinates.count >= 3 {
            context.coordinator.didSetInitialRegion = true
            let region = coordinateRegion(for: cityBoundaryCoordinates)
            uiView.setRegion(region, animated: true)
        }

        if centerOnUser, locationTracker.lastLocation != nil {
            DispatchQueue.main.async { centerOnUser = false }
            uiView.setUserTrackingMode(.follow, animated: true)
        }

        if resetMapOrientation {
            DispatchQueue.main.async { resetMapOrientation = false }
            resetCameraOrientation(on: uiView)
        }

        if let friendUserID = centerOnFriendUserID {
            DispatchQueue.main.async { centerOnFriendUserID = nil }
            centerMap(
                onFriend: friendUserID,
                on: uiView,
                friendLocations: friendLocations,
                context: context
            )
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            fogColor: fogColor,
            onJoinFriend: onJoinFriend,
            onViewFriendProfile: onViewFriendProfile
        )
    }

    private var visibleDiscoveredCellIDs: Set<String> {
        friendExplorations.values.reduce(into: discoveredCellIDs) { result, exploration in
            result.formUnion(exploration.cellIDs)
        }
    }

    // MARK: - User location

    private func updateUserLocationAnnotation(on mapView: MKMapView, context: Context) {
        let coordinator = context.coordinator
        let trimmedDisplayName = userDisplayName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let resolvedDisplayName = trimmedDisplayName.isEmpty
            ? "Explorer"
            : trimmedDisplayName
        let calloutInfo = MapUserCalloutInfo(
            displayName: resolvedDisplayName,
            relationshipText: "Vous",
            isExplorationLoaded: true,
            cityProgress: userExplorationProgress,
            totalExploredCellCount: discoveredCellIDs.count,
            coordinate: locationTracker.lastLocation.map {
                MapUserCoordinate($0.coordinate)
            },
            locationSampledAt: locationTracker.lastLocation?.timestamp,
            spotEnteredAt: locationTracker.currentSpotEnteredAt,
            keepsSpotDurationVisible:
                locationTracker.trackingEnabled && locationTracker.isTracking
        )
        coordinator.updateUserMarkerAppearance(
            avatarImageData: userAvatarImageData,
            displayName: resolvedDisplayName,
            profileColorHex: userProfileColorHex,
            calloutInfo: calloutInfo,
            on: mapView
        )

        guard let coordinate = locationTracker.lastLocation?.coordinate else {
            if let annotation = coordinator.userLocationAnnotation {
                mapView.removeAnnotation(annotation)
                coordinator.userLocationAnnotation = nil
            }
            mapView.view(for: mapView.userLocation)?.isHidden = false
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
            mapView.addAnnotation(annotation)
        }

        annotation.title = resolvedDisplayName
        annotation.subtitle = nil

        mapView.view(for: mapView.userLocation)?.isHidden = true
    }

    // MARK: - Friend annotations

    private func updateFriendAnnotations(
        on mapView: MKMapView,
        context: Context
    ) {
        let coordinator = context.coordinator

        // Remove annotations when a friendship ends or its fresh location expires.
        let currentIDs = Set(friendLocations.keys)
        let removedIDs = coordinator.friendAnnotations.keys
            .filter { !currentIDs.contains($0) }
            .sorted()
        for userID in removedIDs {
            if let annotation = coordinator.friendAnnotations.removeValue(forKey: userID) {
                mapView.removeAnnotation(annotation)
            }
            coordinator.friendProfileColorHexByUserID.removeValue(forKey: userID)
            coordinator.friendCalloutInfoByUserID.removeValue(forKey: userID)
        }

        // Incrementally add or move annotations for fresh accepted-friend locations.
        for userID in friendLocations.keys.sorted() {
            guard let friendLocation = friendLocations[userID] else { continue }

            coordinator.friendProfileColorHexByUserID[friendLocation.userID] =
                friendLocation.profileColorHex
            let friendExploration = allFriendExplorations[friendLocation.userID]
            let calloutInfo = MapUserCalloutInfo(
                displayName: friendLocation.displayName,
                relationshipText: "Ami",
                isExplorationLoaded: loadedFriendExplorationUserIDs.contains(
                    friendLocation.userID
                ),
                cityProgress: friendExplorationProgress[friendLocation.userID],
                totalExploredCellCount: friendExploration?.cellIDs.count ?? 0,
                coordinate: MapUserCoordinate(friendLocation.coordinate),
                locationSampledAt: friendLocation.sampledAt,
                spotEnteredAt: friendLocation.spotEnteredAt,
                keepsSpotDurationVisible: false
            )
            coordinator.friendCalloutInfoByUserID[friendLocation.userID] = calloutInfo

            if let existing = coordinator.friendAnnotations[friendLocation.userID] {
                if existing.coordinate.latitude != friendLocation.coordinate.latitude
                    || existing.coordinate.longitude != friendLocation.coordinate.longitude {
                    UIView.animate(withDuration: 0.5) {
                        existing.coordinate = friendLocation.coordinate
                    }
                }

                existing.title = friendLocation.displayName
                existing.subtitle = nil
                if let annotationView = mapView.view(for: existing) {
                    coordinator.configureFriendAnnotationView(
                        annotationView,
                        displayName: friendLocation.displayName,
                        profileColorHex: friendLocation.profileColorHex,
                        calloutInfo: calloutInfo
                    )
                }
            } else {
                let annotation = FriendLocationAnnotation()
                annotation.userID = friendLocation.userID
                annotation.coordinate = friendLocation.coordinate
                annotation.title = friendLocation.displayName
                annotation.subtitle = nil
                coordinator.friendAnnotations[friendLocation.userID] = annotation
                mapView.addAnnotation(annotation)
            }
        }
    }

    // MARK: - Fog overlay

    private func updateFogOverlay(
        on mapView: MKMapView,
        context: Context,
        visibleDiscoveredCellIDs: Set<String>
    ) {
        let coordinator = context.coordinator

        let overlay = FogOfWarOverlay(
            cellIDs: visibleDiscoveredCellIDs,
            explorationEngine: coordinator.explorationEngine
        )

        coordinator.fogOverlay = overlay
        coordinator.lastDiscoveredIDs = visibleDiscoveredCellIDs
        coordinator.lastBoundaryLength = cityBoundaryCoordinates.count
        applyManagedOverlayOrder(on: mapView, context: context)
    }

    private func coordinateRegion(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard let first = coordinates.first else {
            return MKCoordinateRegion()
        }

        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude

        for coordinate in coordinates.dropFirst() {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.01),
            longitudeDelta: max((maxLon - minLon) * 1.4, 0.01)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    private func setFocusedRegion(
        on mapView: MKMapView,
        center: CLLocationCoordinate2D,
        animated: Bool
    ) {
        let region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: 800,
            longitudinalMeters: 800
        )
        mapView.setRegion(region, animated: animated)
    }

    private func resetCameraOrientation(on mapView: MKMapView) {
        let camera = mapView.camera.copy() as! MKMapCamera
        camera.heading = 0
        camera.pitch = 0
        mapView.setCamera(camera, animated: true)
    }

    private func centerMap(
        onFriend userID: String,
        on mapView: MKMapView,
        friendLocations: [String: FriendLocation],
        context: Context
    ) {
        mapView.setUserTrackingMode(.none, animated: false)

        if let coordinate = friendLocations[userID]?.coordinate {
            setFocusedRegion(on: mapView, center: coordinate, animated: true)
            if let annotation = context.coordinator.friendAnnotations[userID] {
                mapView.selectAnnotation(annotation, animated: true)
            }
            return
        }

        if let overlay = friendScratchOverlay(for: userID, context: context) {
            setVisibleRegion(for: overlay, on: mapView)
        }
    }

    private func friendScratchOverlay(
        for userID: String,
        context: Context
    ) -> FriendScratchOverlay? {
        if let overlay = context.coordinator.friendScratchOverlays.first(
            where: { $0.userID == userID }
        ), !overlay.cellPolygons.isEmpty {
            return overlay
        }

        guard let exploration = allFriendExplorations[userID],
              !exploration.cellIDs.isEmpty else {
            return nil
        }

        let overlay = FriendScratchOverlay(
            userID: exploration.userID,
            cellIDs: exploration.cellIDs,
            color: ProfileColor.uiColor(hex: exploration.profileColorHex),
            explorationEngine: context.coordinator.explorationEngine
        )

        return overlay.cellPolygons.isEmpty ? nil : overlay
    }

    private func setVisibleRegion(
        for overlay: FriendScratchOverlay,
        on mapView: MKMapView
    ) {
        guard !overlay.boundingMapRect.isNull else { return }

        let pointsPerMeter = MKMapPointsPerMeterAtLatitude(
            overlay.coordinate.latitude
        )
        let minimumHalfWidth = 400 * pointsPerMeter
        let minimumMapRect = MKMapRect(
            x: MKMapPoint(overlay.coordinate).x - minimumHalfWidth,
            y: MKMapPoint(overlay.coordinate).y - minimumHalfWidth,
            width: minimumHalfWidth * 2,
            height: minimumHalfWidth * 2
        )
        let visibleMapRect = overlay.boundingMapRect.union(minimumMapRect)

        mapView.setVisibleMapRect(
            visibleMapRect,
            edgePadding: UIEdgeInsets(
                top: 64,
                left: 32,
                bottom: 120,
                right: 32
            ),
            animated: true
        )
    }

    // MARK: - Heat map overlay

    private func updateHeatMapOverlay(on mapView: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.lastHeatMapRevision = heatMapRevision

        guard showsHeatMap else {
            coordinator.heatMapOverlay = nil
            applyManagedOverlayOrder(on: mapView, context: context)
            return
        }

        guard !heatMapCellData.isEmpty else {
            coordinator.heatMapOverlay = nil
            applyManagedOverlayOrder(on: mapView, context: context)
            return
        }

        let overlay = HeatMapOverlay(
            cellData: heatMapCellData,
            explorationEngine: coordinator.explorationEngine
        )

        coordinator.heatMapOverlay =
            overlay.cellPolygons.isEmpty ? nil : overlay

        applyManagedOverlayOrder(on: mapView, context: context)
    }

    // MARK: - Friend scratch overlays

    private func updateFriendScratchOverlays(
        on mapView: MKMapView,
        context: Context
    ) {
        let coordinator = context.coordinator

        let overlays = friendExplorations
            .filter { !$0.value.cellIDs.isEmpty }
            .sorted { $0.key < $1.key }
            .compactMap { _, exploration -> FriendScratchOverlay? in
                let overlay = FriendScratchOverlay(
                    userID: exploration.userID,
                    cellIDs: exploration.cellIDs,
                    color: ProfileColor.uiColor(hex: exploration.profileColorHex),
                    explorationEngine: coordinator.explorationEngine
                )
                return overlay.cellPolygons.isEmpty ? nil : overlay
            }

        coordinator.friendScratchOverlays = overlays
        coordinator.lastFriendExplorations = friendExplorations
        applyManagedOverlayOrder(on: mapView, context: context)
    }

    /// Keeps the visual stack deterministic regardless of which filter changed
    /// most recently: fog first, then the local heat map, then friend colors.
    private func applyManagedOverlayOrder(
        on mapView: MKMapView,
        context: Context
    ) {
        let coordinator = context.coordinator
        var desiredManagedOverlays: [MKOverlay] = []
        if let fogOverlay = coordinator.fogOverlay {
            desiredManagedOverlays.append(fogOverlay)
        }
        if let heatMapOverlay = coordinator.heatMapOverlay {
            desiredManagedOverlays.append(heatMapOverlay)
        }
        desiredManagedOverlays.append(contentsOf: coordinator.friendScratchOverlays)

        let desiredIdentifiers = Set(desiredManagedOverlays.map {
            ObjectIdentifier($0 as AnyObject)
        })
        let attachedManagedOverlays = mapView.overlays.filter {
            $0 is FogOfWarOverlay
                || $0 is HeatMapOverlay
                || $0 is FriendScratchOverlay
        }
        let staleOverlays = attachedManagedOverlays.filter {
            !desiredIdentifiers.contains(ObjectIdentifier($0 as AnyObject))
        }
        if !staleOverlays.isEmpty {
            mapView.removeOverlays(staleOverlays)
        }

        // Keep renderers for unchanged overlays alive. A fog update should not
        // recreate the heat-map and every friend renderer (and vice versa).
        var attachedIdentifiers = Set(mapView.overlays.map {
            ObjectIdentifier($0 as AnyObject)
        })

        for (index, overlay) in desiredManagedOverlays.enumerated() {
            let identifier = ObjectIdentifier(overlay as AnyObject)
            guard !attachedIdentifiers.contains(identifier) else { continue }

            let followingOverlay = desiredManagedOverlays
                .dropFirst(index + 1)
                .first {
                    attachedIdentifiers.contains(ObjectIdentifier($0 as AnyObject))
                }
            let precedingOverlay = desiredManagedOverlays[..<index]
                .reversed()
                .first {
                    attachedIdentifiers.contains(ObjectIdentifier($0 as AnyObject))
                }

            if let followingOverlay {
                mapView.insertOverlay(overlay, below: followingOverlay)
            } else if let precedingOverlay {
                mapView.insertOverlay(overlay, above: precedingOverlay)
            } else {
                mapView.addOverlay(overlay, level: .aboveRoads)
            }
            attachedIdentifiers.insert(identifier)
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        let explorationEngine = ExplorationEngine()
        let fogColor: UIColor
        var fogOverlay: FogOfWarOverlay?
        var heatMapOverlay: HeatMapOverlay?
        var friendScratchOverlays: [FriendScratchOverlay] = []
        var lastDiscoveredIDs: Set<String> = []
        var lastBoundaryLength: Int = 0
        var lastShowsHeatMap = false
        var lastHeatMapRevision = 0
        var lastFriendExplorations: [String: FriendExploration] = [:]
        var didSetInitialRegion = false
        var didCenterOnUser = false
        var userLocationAnnotation: UserLocationAnnotation?
        private var userAvatarImageData = Data()
        private var userDisplayName = ""
        private var userProfileColorHex = ""
        private var userCalloutInfo: MapUserCalloutInfo?
        var friendAnnotations: [String: FriendLocationAnnotation] = [:]
        var friendProfileColorHexByUserID: [String: String] = [:]
        var friendCalloutInfoByUserID: [String: MapUserCalloutInfo] = [:]
        var onJoinFriend: (String) -> Void
        var onViewFriendProfile: (String) -> Void

        init(
            fogColor: UIColor,
            onJoinFriend: @escaping (String) -> Void,
            onViewFriendProfile: @escaping (String) -> Void
        ) {
            self.fogColor = fogColor
            self.onJoinFriend = onJoinFriend
            self.onViewFriendProfile = onViewFriendProfile
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let fogOverlay = overlay as? FogOfWarOverlay {
                return FogOfWarOverlayRenderer(overlay: fogOverlay, fogColor: fogColor)
            }
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = fogColor
                renderer.strokeColor = nil
                renderer.lineWidth = 0
                return renderer
            }
            if overlay is FriendScratchOverlay {
                return FriendScratchOverlayRenderer(overlay: overlay)
            }
            if overlay is HeatMapOverlay {
                return HeatMapOverlayRenderer(overlay: overlay)
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is UserLocationAnnotation {
                let annotationView = mapView.dequeueReusableAnnotationView(
                    withIdentifier: UserLocationAnnotationView.reuseIdentifier
                ) as? UserLocationAnnotationView
                    ?? UserLocationAnnotationView(
                        annotation: annotation,
                        reuseIdentifier: UserLocationAnnotationView.reuseIdentifier
                    )
                annotationView.annotation = annotation
                annotationView.configure(
                    avatarImageData: userAvatarImageData,
                    displayName: userDisplayName,
                    profileColorHex: userProfileColorHex,
                    calloutInfo: userCalloutInfo ?? MapUserCalloutInfo(
                        displayName: userDisplayName,
                        relationshipText: "Vous",
                        isExplorationLoaded: true,
                        cityProgress: nil,
                        totalExploredCellCount: 0,
                        coordinate: nil,
                        locationSampledAt: nil,
                        spotEnteredAt: nil,
                        keepsSpotDurationVisible: false
                    )
                )
                return annotationView
            }

            guard !(annotation is MKUserLocation) else { return nil }
            guard let friendAnnotation = annotation as? FriendLocationAnnotation else {
                return nil
            }

            let annotationView = mapView.dequeueReusableAnnotationView(
                withIdentifier: UserLocationAnnotationView.friendReuseIdentifier
            ) as? UserLocationAnnotationView
                ?? UserLocationAnnotationView(
                    annotation: annotation,
                    reuseIdentifier: UserLocationAnnotationView.friendReuseIdentifier
                )
            annotationView.annotation = annotation

            let displayName = annotation.title.flatMap { $0 } ?? "Explorer"
            let userID = friendAnnotation.userID
            let profileColorHex =
                friendProfileColorHexByUserID[userID]
                ?? ProfileColor.generatedHex(seed: userID)
            let calloutInfo = friendCalloutInfoByUserID[userID]
                ?? MapUserCalloutInfo(
                    displayName: displayName,
                    relationshipText: "Ami",
                    isExplorationLoaded: false,
                    cityProgress: nil,
                    totalExploredCellCount: 0,
                    coordinate: nil,
                    locationSampledAt: nil,
                    spotEnteredAt: nil,
                    keepsSpotDurationVisible: false
                )
            configureFriendAnnotationView(
                annotationView,
                displayName: displayName,
                profileColorHex: profileColorHex,
                calloutInfo: calloutInfo
            )
            return annotationView
        }

        func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
            for view in views where view.annotation is MKUserLocation {
                view.isHidden = userLocationAnnotation != nil
            }
        }

        func mapView(
            _ mapView: MKMapView,
            annotationView view: MKAnnotationView,
            calloutAccessoryControlTapped control: UIControl
        ) {
            guard control === view.rightCalloutAccessoryView,
                  let annotationView = view as? UserLocationAnnotationView else {
                return
            }
            annotationView.copyResolvedAddressToPasteboard()
        }

        func updateUserMarkerAppearance(
            avatarImageData: Data,
            displayName: String,
            profileColorHex: String,
            calloutInfo: MapUserCalloutInfo,
            on mapView: MKMapView
        ) {
            let normalizedProfileColorHex =
                ProfileColor.normalizedHex(profileColorHex)
                ?? ProfileColor.storedOrGeneratedHex()

            guard userAvatarImageData != avatarImageData ||
                    userDisplayName != displayName ||
                    userProfileColorHex != normalizedProfileColorHex ||
                    userCalloutInfo != calloutInfo else { return }

            userAvatarImageData = avatarImageData
            userDisplayName = displayName
            userProfileColorHex = normalizedProfileColorHex
            userCalloutInfo = calloutInfo

            guard let annotation = userLocationAnnotation,
                  let annotationView = mapView.view(for: annotation)
                    as? UserLocationAnnotationView else { return }

            annotationView.configure(
                avatarImageData: avatarImageData,
                displayName: displayName,
                profileColorHex: normalizedProfileColorHex,
                calloutInfo: calloutInfo
            )
        }

        func configureFriendAnnotationView(
            _ annotationView: MKAnnotationView,
            displayName: String,
            profileColorHex: String,
            calloutInfo: MapUserCalloutInfo
        ) {
            guard let annotationView = annotationView as? UserLocationAnnotationView,
                  let friendAnnotation = annotationView.annotation
                    as? FriendLocationAnnotation else {
                return
            }
            let userID = friendAnnotation.userID

            annotationView.configure(
                avatarImageData: Data(),
                displayName: displayName,
                profileColorHex: profileColorHex,
                calloutInfo: calloutInfo,
                calloutContent: .friendActions(
                    FriendCalloutActions(
                        join: { [weak self] in
                            self?.onJoinFriend(userID)
                        },
                        viewProfile: { [weak self] in
                            self?.onViewFriendProfile(userID)
                        }
                    )
                )
            )
        }
    }
}
