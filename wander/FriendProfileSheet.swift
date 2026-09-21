//
//  FriendProfileSheet.swift
//  wander
//
//  Friend profile and shared avatar presentation.
//

import SwiftUI
import UIKit

struct FriendAvatarBadge: View {
    private let avatarID: String
    private let profileColorHex: String
    private let size: CGFloat

    init(avatarID: String, profileColorHex: String, size: CGFloat) {
        self.avatarID = avatarID
        self.profileColorHex = profileColorHex
        self.size = size
    }

    var body: some View {
        ProfileAvatarView(avatarID: avatarID, size: size)
            .overlay {
                Circle()
                    .stroke(
                        ProfileColor.color(hex: profileColorHex),
                        lineWidth: max(2, size * 0.055)
                    )
            }
    }
}

struct FriendProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var service: FriendSyncService

    private let userID: String
    private let onOpenDirections: () -> Void
    private let onPreparePresentation: (CGFloat) -> Void

    init(
        userID: String,
        service: FriendSyncService,
        onOpenDirections: @escaping () -> Void,
        onPreparePresentation: @escaping (CGFloat) -> Void
    ) {
        self.userID = userID
        self.service = service
        self.onOpenDirections = onOpenDirections
        self.onPreparePresentation = onPreparePresentation
    }

    var body: some View {
        let profile = FriendProfileData(userID: userID, service: service)
        FriendProfileContentView(
            displayName: profile.displayName,
            avatarID: profile.avatarID,
            profileColorHex: profile.profileColorHex,
            isGhostModeEnabled: profile.isGhostModeEnabled,
            location: profile.location,
            isLocationFresh: profile.isLocationFresh,
            onOpenDirections: {
                guard FriendProfileData(userID: userID, service: service).canOpenDirections else {
                    return
                }
                onOpenDirections()
            },
            onPreparePresentation: onPreparePresentation
        )
        .onChange(of: profile.isFriendAccepted, initial: true) { _, isAccepted in
            if !isAccepted {
                dismiss()
            }
        }
    }
}

// MARK: - Shared bottom sheet

struct FriendProfileContentView: View {
    let displayName: String
    let avatarID: String
    let profileColorHex: String
    let isGhostModeEnabled: Bool
    let location: FriendLocation?
    let isLocationFresh: Bool
    let onOpenDirections: () -> Void
    let onPreparePresentation: (CGFloat) -> Void

    var body: some View {
        FriendProfileNativeContent(
            content: FriendProfileBody(
                displayName: displayName, avatarID: avatarID,
                profileColorHex: profileColorHex, isGhostModeEnabled: isGhostModeEnabled,
                location: location, isLocationFresh: isLocationFresh,
                onOpenDirections: onOpenDirections
            ),
            onPreparePresentation: onPreparePresentation
        )
    }
}

/// The same content is used for preflight sizing and the visible scroll view.
struct FriendProfileBody: View {
    @ScaledMetric(relativeTo: .title3) private var nameFontSize: CGFloat = 17

    let displayName: String
    let avatarID: String
    let profileColorHex: String
    let isGhostModeEnabled: Bool
    let location: FriendLocation?
    let isLocationFresh: Bool
    let onOpenDirections: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            identity

            if !isGhostModeEnabled, let location {
                locationDetails(location)
            }

            Button {
                guard canOpenDirections else { return }
                onOpenDirections()
            } label: {
                Label("Itinéraire", systemImage: "map")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canOpenDirections)
            .accessibilityHint("Choisir une application pour rejoindre cet ami")

            if let explanation {
                Text(explanation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    private var identity: some View {
        VStack(spacing: 12) {
            VStack(spacing: 0) {
                FriendAvatarBadge(
                    avatarID: avatarID,
                    profileColorHex: profileColorHex,
                    size: 128
                )
                .accessibilityHidden(true)
                .frame(maxWidth: .infinity)
                .frame(height: 176)

                Text(displayName)
                    .font(.system(size: nameFontSize, weight: .bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 10)
                    .anchorPreference(key: ProfileNameBoundsKey.self, value: .bounds) { $0 }
                    .padding(.horizontal, 16)
                    .accessibilityAddTraits(.isHeader)
            }
            .backgroundPreferenceValue(ProfileNameBoundsKey.self) { nameBounds in
                GeometryReader { geometry in
                    Image("ProfileCardBackground")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .mask {
                            if let nameBounds {
                                ProfileCardBackgroundShape(nameBounds: geometry[nameBounds])
                                    .fill(.white)
                            } else {
                                Rectangle().fill(.white)
                            }
                        }
                        .accessibilityHidden(true)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            Label(statusTitle, systemImage: statusSymbol)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func locationDetails(_ location: FriendLocation) -> some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Position reçue")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(location.sampledAt, style: .relative)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                if isLocationFresh,
                   let enteredAt = location.spotEnteredAt,
                   enteredAt <= location.sampledAt {
                    Text("Au même endroit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(enteredAt, style: .relative)
                        .font(.subheadline.weight(.semibold))
                } else {
                    Text("Reçue le")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(location.sampledAt.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                        .font(.subheadline.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 4)
    }

    private var canOpenDirections: Bool {
        !isGhostModeEnabled && location != nil
    }

    private var statusTitle: String {
        if isGhostModeEnabled { return "Mode fantôme" }
        guard location != nil else { return "Position indisponible" }
        return isLocationFresh ? "Position actualisée" : "Position ancienne"
    }

    private var statusSymbol: String {
        if isGhostModeEnabled { return "eye.slash" }
        guard location != nil else { return "location.slash" }
        return isLocationFresh ? "location" : "clock"
    }

    private var explanation: String? {
        if isGhostModeEnabled {
            return "Sa position est masquée. L’itinéraire sera disponible à son retour."
        }
        guard location != nil else {
            return "L’itinéraire sera disponible dès qu’une position sera partagée."
        }
        return isLocationFresh ? nil : "L’itinéraire utilise la dernière position connue."
    }
}

private struct ProfileNameBoundsKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? { nil }

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

private struct ProfileCardBackgroundShape: Shape {
    let nameBounds: CGRect

    func path(in rect: CGRect) -> Path {
        let radius = min(18, min(nameBounds.width / 4, (rect.maxY - nameBounds.minY) / 2))
        let left = nameBounds.minX + radius
        let right = nameBounds.maxX - radius

        // A single contour avoids a shared closing edge beneath the name.
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: nameBounds.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: left, y: rect.maxY - radius),
            control: CGPoint(x: left, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: left, y: nameBounds.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: left + radius, y: nameBounds.minY),
            control: CGPoint(x: left, y: nameBounds.minY)
        )
        path.addLine(to: CGPoint(x: right - radius, y: nameBounds.minY))
        path.addQuadCurve(
            to: CGPoint(x: right, y: nameBounds.minY + radius),
            control: CGPoint(x: right, y: nameBounds.minY)
        )
        path.addLine(to: CGPoint(x: right, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: nameBounds.maxX, y: rect.maxY),
            control: CGPoint(x: right, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

private struct FriendProfileNativeContent: UIViewControllerRepresentable {
    let content: FriendProfileBody
    let onPreparePresentation: (CGFloat) -> Void

    func makeUIViewController(context: Context) -> FriendProfilePresentationController {
        let controller = FriendProfilePresentationController()
        updateUIViewController(controller, context: context)
        return controller
    }

    func updateUIViewController(_ controller: FriendProfilePresentationController, context: Context) {
        let environment = context.environment
        let body = AnyView(content
            .environment(\.locale, environment.locale)
            .environment(\.dynamicTypeSize, environment.dynamicTypeSize)
            .environment(\.layoutDirection, environment.layoutDirection)
            .environment(\.colorScheme, environment.colorScheme))
        let scroll = AnyView(ScrollView { content }
            .scrollBounceBehavior(.basedOnSize)
            .accessibilityIdentifier("friend-profile-scroll")
            .environment(\.locale, environment.locale)
            .environment(\.dynamicTypeSize, environment.dynamicTypeSize)
            .environment(\.layoutDirection, environment.layoutDirection)
            .environment(\.colorScheme, environment.colorScheme))
        controller.update(content: body, scroll: scroll, onPrepare: onPreparePresentation)
    }
}

/// Prepares the native detent in the first appearance transaction, before rendering.
/// Later layout passes, detent changes and live data updates never reframe the map.
final class FriendProfilePresentationController: UIViewController {
    static let compactDetent = UISheetPresentationController.Detent.Identifier("friend-profile-compact")
    private let measurementHost = UIHostingController(rootView: AnyView(EmptyView()))
    private let visibleHost = UIHostingController(rootView: AnyView(EmptyView()))
    private var onPrepare: (CGFloat) -> Void = { _ in }
    private(set) var preparedHeight: CGFloat?

    func update(content: AnyView, scroll: AnyView, onPrepare: @escaping (CGFloat) -> Void) {
        if preparedHeight == nil { measurementHost.rootView = content }
        visibleHost.rootView = scroll
        self.onPrepare = onPrepare
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        for host in [measurementHost, visibleHost] {
            addChild(host)
            host.view.backgroundColor = .clear
            host.view.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(host.view)
            NSLayoutConstraint.activate([
                host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                host.view.topAnchor.constraint(equalTo: view.topAnchor),
                host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            host.didMove(toParent: self)
        }
        measurementHost.safeAreaRegions = []
        measurementHost.view.isHidden = true
        measurementHost.view.isAccessibilityElement = false
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        guard preparedHeight == nil else { return }
        var ancestor = parent
        while let controller = ancestor {
            if let sheet = controller.presentationController as? UISheetPresentationController {
                prepare(sheet: sheet)
                return
            }
            ancestor = controller.parent
        }
    }

    func prepare(sheet: UISheetPresentationController) {
        guard preparedHeight == nil,
              let container = sheet.containerView, let window = container.window else { return }
        view.layoutIfNeeded()
        let width = view.bounds.width - view.safeAreaInsets.left - view.safeAreaInsets.right
        guard width.isFinite, width > 0 else { return }
        let measured = measurementHost.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
        guard measured.height.isFinite, measured.height > 0 else { return }
        let height = ceil(measured.height) + 20
        preparedHeight = height
        measurementHost.rootView = AnyView(EmptyView())
        // UIKit resolves the safe-area and floating-sheet margins. Configure and
        // lay out before the appearance transaction commits, never in viewDidAppear.
        UIView.performWithoutAnimation {
            sheet.animateChanges {
                sheet.detents = [
                    .custom(identifier: Self.compactDetent) { min(height, $0.maximumDetentValue) },
                    .large()
                ]
                sheet.selectedDetentIdentifier = Self.compactDetent
                sheet.largestUndimmedDetentIdentifier = Self.compactDetent
                sheet.prefersGrabberVisible = true
                sheet.prefersScrollingExpandsWhenScrolledToEdge = true
            }
        }
        let frame = container.convert(sheet.frameOfPresentedViewInContainerView, to: window)
        guard frame.minY.isFinite, frame.height > 0 else { return }
        onPrepare(frame.minY)
    }
}

private struct FriendProfileData {
    let friend: FriendContact?
    let location: FriendLocation?
    let isGhostModeEnabled: Bool
    let isLocationFresh: Bool
    let profileColorHex: String

    init(userID: String, service: FriendSyncService) {
        friend = service.acceptedFriends.first { $0.userID == userID }
        isGhostModeEnabled = friend?.isGhostModeEnabled == true
            || service.ghostFriendUserIDs.contains(userID)
        location = isGhostModeEnabled ? nil : service.friendLocation(for: userID)
        isLocationFresh = service.freshFriendLocationUserIDs.contains(userID)
        profileColorHex = ProfileColor.normalizedHex(
            location?.profileColorHex ?? friend?.profileColorHex ?? ""
        ) ?? ProfileColor.generatedHex(seed: userID)
    }

    var isFriendAccepted: Bool {
        friend != nil
    }

    var canOpenDirections: Bool {
        isFriendAccepted && !isGhostModeEnabled && location != nil
    }

    var displayName: String {
        location?.displayName ?? friend?.displayName ?? "Ami"
    }

    var avatarID: String {
        friend?.avatarID ?? ""
    }
}
