import SwiftUI

enum MotionDockSelection: String, CaseIterable {
    case explore
    case friends

    var title: String {
        switch self {
        case .explore: "Explorer"
        case .friends: "Amis"
        }
    }

    var assetName: String {
        switch self {
        case .explore: "TabIconExplore"
        case .friends: "TabIconFriends"
        }
    }
}

/// Keeps the map mounted while panels open above the system tab bar.
struct MotionDockView<MapContent: View, Friends: View>: View {
    @Binding var selection: MotionDockSelection
    let isEventsPresented: Bool
    let onToggleEvents: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AccessibilityFocusState private var focusedPanel: MotionDockSelection?
    @ScaledMetric(relativeTo: .body) private var preferredFriendsHeight = 430

    @ViewBuilder let map: () -> MapContent
    @ViewBuilder let friends: () -> Friends

    private var isOpen: Bool { selection != .explore }

    var body: some View {
        NativeMapTabView(
            selection: $selection,
            isEventsPresented: isEventsPresented,
            onToggleEvents: onToggleEvents
        ) {
            GeometryReader { geometry in
                ZStack {
                    map()
                        .ignoresSafeArea(.keyboard)
                        .allowsHitTesting(!isOpen)
                        .accessibilityHidden(isOpen)

                    panelOverlay
                }
                // The full-bleed map must not enlarge the panel's safe viewport.
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .ignoresSafeArea(.container)
        .onChange(of: selection) { _, newSelection in
            focusedPanel = newSelection == .explore ? nil : newSelection
        }
    }

    private var panelOverlay: some View {
        GeometryReader { geometry in
            let width = min(max(0, geometry.size.width - 32), 440)
            let availableHeight = max(0, geometry.size.height - 24)

            ZStack(alignment: .bottom) {
                if isOpen {
                    Button(action: close) {
                        Color.clear.contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Fermer le panneau")
                    .accessibilityIdentifier("motion-dock-dismiss")
                    .ignoresSafeArea(.container)

                    panel
                        .frame(width: width, height: min(preferredFriendsHeight, availableHeight))
                        .modifier(DockPanelSurface(reduceTransparency: reduceTransparency))
                        .padding(.bottom, 12)
                        .accessibilityIdentifier("motion-dock-panel")
                        .accessibilityAction(.escape, close)
                        .transition(reduceMotion ? .identity : .move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            // The native tab bar is outside this animation's view hierarchy.
            .animation(reduceMotion ? nil : .smooth(duration: 0.28), value: selection)
        }
    }

    private var panel: some View {
        VStack(spacing: 0) {
            Text(selection.title)
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("motion-dock-heading")
                .accessibilityFocused($focusedPanel, equals: selection)

            Group {
                switch selection {
                case .friends: friends()
                case .explore: EmptyView()
                }
            }
        }
        .id(selection)
        .transition(reduceMotion ? .identity : .opacity)
        .accessibilityElement(children: .contain)
    }

    private func close() {
        selection = .explore
    }
}

private struct DockPanelSurface: ViewModifier {
    let reduceTransparency: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        if reduceTransparency {
            content
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: shape)
                .clipShape(shape)
        } else {
            content
                .glassEffect(.regular, in: shape)
                .clipShape(shape)
        }
    }
}
