//
//  FriendEdgeRailView.swift
//  wander
//
//  A compact, resistant social rail revealed from the map's right edge.
//

import SwiftUI
import UIKit

struct FriendEdgeRailView<Content: View>: View {
    let friends: [FriendMapSummary]
    let onSelect: (FriendMapSummary) -> Void
    private let content: Content

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    @State private var isOpen = false
    @State private var edgeRevealProgress: CGFloat = 0
    @State private var closingTranslation: CGFloat = 0
    @State private var isTrackingClose = false
    @State private var didLatchDuringCurrentGesture = false
    @State private var focusedFriendID: String?
    @State private var focusedFriendCenterY: CGFloat?
    @State private var railCenterY: CGFloat?
    @State private var openingFeedback = UIImpactFeedbackGenerator(style: .rigid)

    private let railWidth: CGFloat = 70
    private let minimumRailHeight: CGFloat = 150
    private let maximumRailHeight: CGFloat = 260
    private let edgeTouchWidth: CGFloat = 14
    private let openingDeadZone: CGFloat = 5
    private let openingResistance: CGFloat = 0.62
    private let openingThreshold: CGFloat = 38
    private let openingFlickVelocity: CGFloat = -650
    private let openingPreviewProgress: CGFloat = 0.68

    init(
        friends: [FriendMapSummary],
        onSelect: @escaping (FriendMapSummary) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.friends = friends
        self.onSelect = onSelect
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            content

            GeometryReader { geometry in
                let revealProgress = currentRevealProgress(railWidth: railWidth)
                let displayedRailCenterY = resolvedRailCenterY(
                    defaultCenterY: geometry.size.height / 2
                )

                ZStack(alignment: .trailing) {
                    ZStack(alignment: .trailing) {
                        railBackground(
                            width: railWidth,
                            height: railHeight,
                            progress: revealProgress
                        )

                        focusedFriendName(
                            railWidth: railWidth,
                            progress: revealProgress,
                            verticalOffset: (focusedFriendCenterY
                                ?? railHeight / 2)
                                - railHeight / 2
                        )

                        FriendRailAvatarList(
                            friends: friends,
                            focusedFriendID: $focusedFriendID,
                            focusedFriendCenterY: $focusedFriendCenterY,
                            onActivate: activate
                        )
                        .frame(width: railWidth, height: railHeight)
                        .mask {
                            FriendRailShape()
                                .frame(width: railWidth, height: railHeight)
                        }
                        .offset(x: railWidth * (1 - revealProgress))
                        .opacity(revealProgress)
                        .allowsHitTesting(isOpen)
                        .simultaneousGesture(closeGesture(railWidth: railWidth))
                        .accessibilityAction(.escape) {
                            closeRail()
                        }
                    }
                    .frame(
                        width: geometry.size.width,
                        height: railHeight,
                        alignment: .trailing
                    )
                    .clipped()
                    .position(
                        x: geometry.size.width / 2,
                        y: displayedRailCenterY
                    )
                    .animation(railHeightAnimation, value: railHeight)

                    if !isOpen {
                        RightEdgePanGestureView { event in
                            handleEdgePan(event)
                        }
                        .frame(
                            width: edgeTouchWidth,
                            height: geometry.size.height
                        )
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .accessibilityHidden(true)
                    }
                }
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height,
                    alignment: .trailing
                )
                .onChange(of: friends.map(\.id), initial: true) { _, friendIDs in
                    reconcileFocus(with: friendIDs)
                }
            }
            .ignoresSafeArea()
        }
    }

    private func railBackground(
        width: CGFloat,
        height: CGFloat,
        progress: CGFloat
    ) -> some View {
        FriendRailShape()
            .fill(.black)
            .frame(width: width, height: height)
            .offset(x: width * (1 - progress))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func focusedFriendName(
        railWidth: CGFloat,
        progress: CGFloat,
        verticalOffset: CGFloat
    ) -> some View {
        if let focusedFriend {
            Text(focusedFriend.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .shadow(color: .black.opacity(0.8), radius: 1, y: 1)
                .contentTransition(.opacity)
                .padding(.trailing, railWidth + 10)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .opacity(progress)
                .offset(x: railWidth * (1 - progress))
                .offset(y: verticalOffset)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private func currentRevealProgress(railWidth: CGFloat) -> CGFloat {
        guard isOpen else {
            return min(max(edgeRevealProgress, 0), 1)
        }

        let closingDistance = max(0, closingTranslation)
        return min(max(1 - (closingDistance / railWidth), 0), 1)
    }

    private func handleEdgePan(_ event: RightEdgePanEvent) {
        switch event {
        case .began(let locationY):
            updateRailCenter(locationY)
            didLatchDuringCurrentGesture = false
            edgeRevealProgress = 0
            openingFeedback.prepare()

        case .changed(let translationX, _, let locationY):
            guard !isOpen else { return }
            updateRailCenter(locationY)
            let pullDistance = max(0, -translationX)

            if pullDistance >= openingThreshold {
                latchOpenWithFeedback()
            } else {
                let openingRange = max(
                    1,
                    openingThreshold - openingDeadZone
                )
                let normalizedProgress = min(
                    max(0, pullDistance - openingDeadZone) / openingRange,
                    1
                )
                let resistedProgress = normalizedProgress * (
                    openingResistance
                        + (1 - openingResistance) * normalizedProgress
                )
                edgeRevealProgress = resistedProgress
                    * openingPreviewProgress
            }

        case .ended(let translationX, let velocityX, let locationY):
            guard !isOpen else {
                didLatchDuringCurrentGesture = false
                return
            }

            updateRailCenter(locationY)
            let pullDistance = max(0, -translationX)
            if pullDistance >= openingThreshold
                || (pullDistance > openingDeadZone * 2
                    && velocityX <= openingFlickVelocity) {
                latchOpenWithFeedback()
            } else {
                resetClosedProgress()
            }

        case .cancelled:
            guard !isOpen else { return }
            resetClosedProgress()
        }
    }

    private func updateRailCenter(_ locationY: CGFloat) {
        guard locationY.isFinite else { return }
        railCenterY = locationY
    }

    private func resolvedRailCenterY(
        defaultCenterY: CGFloat
    ) -> CGFloat {
        guard let railCenterY, railCenterY.isFinite else {
            return defaultCenterY
        }
        return railCenterY
    }

    private func latchOpenWithFeedback() {
        guard !didLatchDuringCurrentGesture else { return }
        didLatchDuringCurrentGesture = true

        openingFeedback.impactOccurred(intensity: 0.9)
        openingFeedback.prepare()

        withAnimation(snapAnimation) {
            isOpen = true
            edgeRevealProgress = 0
            closingTranslation = 0
        }
    }

    private func resetClosedProgress() {
        withAnimation(snapAnimation) {
            edgeRevealProgress = 0
        }
        didLatchDuringCurrentGesture = false
    }

    private func closeRail() {
        withAnimation(snapAnimation) {
            isOpen = false
            edgeRevealProgress = 0
            closingTranslation = 0
            isTrackingClose = false
        }
    }

    private func closeGesture(railWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                let horizontalDistance = value.translation.width
                let verticalDistance = abs(value.translation.height)

                if !isTrackingClose {
                    guard horizontalDistance > 6,
                          horizontalDistance > verticalDistance * 1.2 else {
                        return
                    }
                    isTrackingClose = true
                }

                closingTranslation = min(max(horizontalDistance, 0), railWidth)
            }
            .onEnded { value in
                guard isTrackingClose else { return }

                let shouldClose = value.translation.width > railWidth * 0.34
                    || value.predictedEndTranslation.width > railWidth * 0.56

                if shouldClose {
                    closeRail()
                } else {
                    withAnimation(snapAnimation) {
                        closingTranslation = 0
                        isTrackingClose = false
                    }
                }
            }
    }

    private func activate(_ friend: FriendMapSummary) {
        onSelect(friend)
    }

    private func reconcileFocus(with friendIDs: [String]) {
        guard let focusedFriendID else { return }
        guard !friendIDs.contains(focusedFriendID) else { return }

        self.focusedFriendID = nil
    }

    private var focusedFriend: FriendMapSummary? {
        guard let focusedFriendID else { return nil }
        return friends.first { $0.userID == focusedFriendID }
    }

    private var railHeight: CGFloat {
        guard !friends.isEmpty else { return minimumRailHeight }

        let contentHeight = FriendRailMetrics.contentHeight(
            for: friends.count
        )

        return min(
            max(contentHeight, minimumRailHeight),
            maximumRailHeight
        )
    }

    private var snapAnimation: Animation? {
        accessibilityReduceMotion
            ? nil
            : .spring(response: 0.30, dampingFraction: 0.86)
    }

    private var railHeightAnimation: Animation? {
        accessibilityReduceMotion
            ? nil
            : .spring(response: 0.30, dampingFraction: 0.88)
    }
}

private struct FriendRailAvatarList: View {
    let friends: [FriendMapSummary]
    @Binding var focusedFriendID: String?
    @Binding var focusedFriendCenterY: CGFloat?
    let onActivate: (FriendMapSummary) -> Void

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var focusFeedback = UISelectionFeedbackGenerator()
    @State private var scrolledFriendID: String?
    @State private var hasUserInteracted = false

    var body: some View {
        GeometryReader { geometry in
            if friends.isEmpty {
                Image(systemName: "person.2.slash")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("Aucun ami")
            } else {
                let verticalPadding = max(
                    0,
                    (geometry.size.height
                        - FriendRailMetrics.avatarSlotHeight) / 2
                )

                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        LazyVStack(spacing: FriendRailMetrics.avatarSpacing) {
                            ForEach(friends) { friend in
                                friendButton(friend) {
                                    focusOrActivate(friend, proxy: proxy)
                                }
                                .id(friend.userID)
                            }
                        }
                        .padding(.vertical, verticalPadding)
                        .frame(
                            minHeight: geometry.size.height,
                            alignment: .center
                        )
                        .frame(maxWidth: .infinity, alignment: .center)
                        .scrollTargetLayout()
                    }
                    .scrollIndicators(.hidden)
                    .scrollTargetBehavior(.viewAligned(anchor: .center))
                    .scrollPosition(id: $scrolledFriendID, anchor: .center)
                    .coordinateSpace(name: FriendRailScrollCoordinateSpace.name)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { _ in
                                beginUserInteraction()
                            }
                    )
                    .onPreferenceChange(
                        SelectedFriendCenterPreferenceKey.self
                    ) { centerY in
                        guard let centerY, centerY.isFinite else { return }
                        focusedFriendCenterY = centerY
                    }
                    .onChange(of: scrolledFriendID) { _, newID in
                        guard hasUserInteracted,
                              let newID,
                              focusedFriendID != newID else {
                            return
                        }

                        focusedFriendID = newID
                        playFocusFeedback()
                    }
                    .onAppear {
                        focusFeedback.prepare()
                    }
                }
            }
        }
    }

    private func friendButton(
        _ friend: FriendMapSummary,
        onTap: @escaping () -> Void
    ) -> some View {
        let isFocused = focusedFriendID == friend.userID

        return Button(action: onTap) {
            FriendAvatarBadge(
                avatarID: friend.avatarID,
                profileColorHex: friend.profileColorHex,
                size: isFocused ? 42 : 30
            )
            .overlay {
                if isFocused {
                    Circle()
                        .stroke(.white, lineWidth: 2)
                }
            }
            .frame(
                width: FriendRailMetrics.avatarSlotHeight,
                height: FriendRailMetrics.avatarSlotHeight
            )
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(friend.displayName)
        .accessibilityHint(
            accessibilityHint(for: friend, isFocused: isFocused)
        )
        .accessibilityAddTraits(isFocused ? .isSelected : [])
        .background {
            if isFocused {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: SelectedFriendCenterPreferenceKey.self,
                        value: geometry.frame(
                            in: .named(FriendRailScrollCoordinateSpace.name)
                        ).midY
                    )
                }
            }
        }
    }

    private func focusOrActivate(
        _ friend: FriendMapSummary,
        proxy: ScrollViewProxy
    ) {
        guard focusedFriendID != friend.userID else {
            onActivate(friend)
            return
        }

        hasUserInteracted = true
        withAnimation(focusAnimation) {
            focusedFriendID = friend.userID
            scrolledFriendID = friend.userID
            proxy.scrollTo(friend.userID, anchor: .center)
        }
        playFocusFeedback()
    }

    private func beginUserInteraction() {
        guard !hasUserInteracted else { return }
        hasUserInteracted = true

        guard let scrolledFriendID,
              focusedFriendID != scrolledFriendID else {
            return
        }

        focusedFriendID = scrolledFriendID
        playFocusFeedback()
    }

    private func playFocusFeedback() {
        focusFeedback.selectionChanged()
        focusFeedback.prepare()
    }

    private var focusAnimation: Animation? {
        accessibilityReduceMotion
            ? nil
            : .easeInOut(duration: 0.20)
    }

    private func accessibilityHint(
        for friend: FriendMapSummary,
        isFocused: Bool
    ) -> String {
        guard isFocused else {
            return "Mettre cet ami au centre du rail"
        }

        return friend.canShowOnMap
            ? "Centrer cet ami sur la carte"
            : "Position cartographique indisponible"
    }
}

private enum FriendRailMetrics {
    static let avatarSlotHeight: CGFloat = 46
    static let avatarSpacing: CGFloat = 7
    static let verticalPadding: CGFloat = 16

    static func contentHeight(for avatarCount: Int) -> CGFloat {
        guard avatarCount > 0 else { return 0 }

        let avatarsHeight = CGFloat(avatarCount) * avatarSlotHeight
        let spacingsHeight = CGFloat(avatarCount - 1) * avatarSpacing
        return avatarsHeight + spacingsHeight + verticalPadding
    }
}

private enum FriendRailScrollCoordinateSpace {
    static let name = "friendRailScrollViewport"
}

private struct SelectedFriendCenterPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat?

    static func reduce(
        value: inout CGFloat?,
        nextValue: () -> CGFloat?
    ) {
        if let nextValue = nextValue() {
            value = nextValue
        }
    }
}

private struct FriendRailShape: Shape {
    func path(in rect: CGRect) -> Path {
        let upperFullWidthY = rect.minY + rect.height * 0.26
        let lowerFullWidthY = rect.minY + rect.height * 0.74

        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: upperFullWidthY),
            control1: CGPoint(
                x: rect.maxX,
                y: rect.minY + rect.height * 0.08
            ),
            control2: CGPoint(
                x: rect.minX,
                y: rect.minY + rect.height * 0.12
            )
        )
        path.addCurve(
            to: CGPoint(x: rect.minX, y: lowerFullWidthY),
            control1: CGPoint(
                x: rect.minX,
                y: rect.minY + rect.height * 0.40
            ),
            control2: CGPoint(
                x: rect.minX,
                y: rect.minY + rect.height * 0.60
            )
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control1: CGPoint(
                x: rect.minX,
                y: rect.minY + rect.height * 0.88
            ),
            control2: CGPoint(
                x: rect.maxX,
                y: rect.minY + rect.height * 0.92
            )
        )
        path.closeSubpath()
        return path
    }
}
