import SwiftUI
import UIKit

enum MapBottomList: Equatable {
    case events
    case friends
}

private enum ListSeparatorMetrics {
    static let height: CGFloat = 20
    static let hitHeight: CGFloat = 44
    static let overlap = (hitHeight - height) / 2
}

struct MapDetailSplitView<Events: View, Friends: View, MapContent: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.mapNavigationBottomInset) private var navigationBottomInset
    @ScaledMetric(relativeTo: .body) private var minimumPaneHeight = 140
    @State private var eventsPosition: Position = .third
    @State private var friendsPosition: Position = .custom(0.5)
    @State private var listDragOrigin: DragOrigin?
    @GestureState private var isListDragging = false
    @State private var isListDragCancelled = false
    @State private var didEmitListClosingFeedback = false

    private let areListsObscured: Bool
    @Binding private var bottomList: MapBottomList?
    private let events: Events
    private let friends: Friends
    private let mapContent: MapContent

    init(
        bottomList: Binding<MapBottomList?>,
        areListsObscured: Bool = false,
        @ViewBuilder events: () -> Events,
        @ViewBuilder friends: () -> Friends,
        @ViewBuilder map: () -> MapContent
    ) {
        self._bottomList = bottomList
        self.areListsObscured = areListsObscured
        self.events = events()
        self.friends = friends()
        self.mapContent = map()
    }

    var body: some View {
        GeometryReader { safeGeometry in
            GeometryReader { geometry in
                let swiftUIInsets = safeGeometry.safeAreaInsets
                let safeInsets = EdgeInsets(
                    top: swiftUIInsets.top,
                    leading: swiftUIInsets.leading,
                    bottom: max(swiftUIInsets.bottom, navigationBottomInset),
                    trailing: swiftUIInsets.trailing
                )
                let listSeparatorHeight = min(ListSeparatorMetrics.height, max(0, geometry.size.height))
                let listAvailableHeight = max(
                    0, geometry.size.height - safeInsets.top - safeInsets.bottom - listSeparatorHeight
                )
                let showsListPane = bottomList != nil && !areListsObscured

                MapDetailArrangement(
                    listHeight: showsListPane
                        ? listHeight(availableHeight: listAvailableHeight)
                        : 0,
                    listSeparatorHeight: showsListPane ? listSeparatorHeight : 0,
                    windowSize: geometry.size,
                    safeInsets: safeInsets,
                    lists: lists,
                    listKind: bottomList,
                    mapContent: mapContent
                ) { displayedHeight in
                    listResizeHandle(availableHeight: listAvailableHeight, displayedHeight: displayedHeight)
                }
                .animation(resizeAnimation, value: bottomList)
                .animation(resizeAnimation, value: areListsObscured)
                .onChange(of: isListDragging) { _, dragging in
                    if !dragging {
                        listDragOrigin = nil
                        isListDragCancelled = false
                        didEmitListClosingFeedback = false
                    }
                }
                .onChange(of: geometry.size) { _, _ in
                    cancelDrags()
                }
            }
            .ignoresSafeArea(.container)
        }
        .onChange(of: areListsObscured) { _, _ in
            cancelDrags()
        }
        .onChange(of: bottomList) { previous, current in
            cancelDrags()
            if current == nil {
                if previous == .friends {
                    friendsPosition = .custom(0.5)
                } else {
                    eventsPosition = .third
                }
            }
        }
    }

    private var lists: some View {
        ZStack {
            events
                .opacity(bottomList == .events ? 1 : 0)
                .accessibilityHidden(bottomList != .events || areListsObscured)
                .allowsHitTesting(bottomList == .events && !areListsObscured)
            friends
                .opacity(bottomList == .friends ? 1 : 0)
                .accessibilityHidden(bottomList != .friends || areListsObscured)
                .allowsHitTesting(bottomList == .friends && !areListsObscured)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 0, for: .scrollContent)
        .contentMargins(.bottom, navigationBottomInset, for: .scrollContent)
        .scrollDismissesKeyboard(.interactively)
    }

    private var listPosition: Position {
        get { bottomList == .friends ? friendsPosition : eventsPosition }
        nonmutating set {
            if bottomList == .friends {
                friendsPosition = newValue
            } else {
                eventsPosition = newValue
            }
        }
    }

    // MARK: - Resizing

    private var resizeAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.25)
    }

    private func listResizeHandle(availableHeight: CGFloat, displayedHeight: CGFloat) -> some View {
        Button {
            let expandedHeight = height(for: .expanded, availableHeight: availableHeight)
            withAnimation(resizeAnimation) {
                if displayedHeight < expandedHeight - 1 {
                    listPosition = .expanded
                } else {
                    bottomList = nil
                }
            }
        } label: {
            Image(systemName: "minus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: ListSeparatorMetrics.hitHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(bottomList == .friends
            ? "Taille de la liste des amis" : "Taille de la liste des événements")
        .accessibilityValue(listPosition.accessibilityValue(
            displayedFraction: availableHeight > 0 ? displayedHeight / availableHeight : 0
        ))
        .accessibilityHint("Faites glisser pour redimensionner. Touchez deux fois pour agrandir, puis replier.")
        .accessibilityIdentifier(bottomList == .friends
            ? "map-friends-resize-handle" : "map-events-resize-handle")
        .accessibilityAdjustableAction { direction in
            guard availableHeight > 0 else { return }
            switch direction {
            case .increment:
                selectListHeight(displayedHeight + 0.05 * availableHeight, availableHeight: availableHeight)
            case .decrement:
                selectListHeight(displayedHeight - 0.05 * availableHeight, availableHeight: availableHeight)
            @unknown default:
                break
            }
        }
        .highPriorityGesture(
            DragGesture(minimumDistance: 8, coordinateSpace: .global)
                .updating($isListDragging) { _, dragging, transaction in
                    dragging = true
                    transaction.animation = nil
                }
                .onChanged { value in
                    guard availableHeight > 0, !isListDragCancelled else { return }
                    let origin = listDragOrigin
                        ?? DragOrigin(height: displayedHeight, availableHeight: availableHeight)
                    guard origin.availableHeight == availableHeight else { return }
                    let proposedHeight = origin.height - value.translation.height
                    if !didEmitListClosingFeedback,
                       proposedHeight < listClosingThreshold(availableHeight: availableHeight) {
                        didEmitListClosingFeedback = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    withTransaction(Transaction(animation: nil)) {
                        listDragOrigin = origin
                        listPosition = .custom(min(
                            availableHeight * 0.85,
                            max(0, proposedHeight)
                        ) / availableHeight)
                    }
                }
                .onEnded { value in
                    guard !isListDragCancelled, let origin = listDragOrigin, availableHeight > 0,
                          origin.availableHeight == availableHeight else {
                        listDragOrigin = nil
                        return
                    }
                    listDragOrigin = nil
                    selectListHeight(origin.height - value.translation.height, availableHeight: availableHeight)
                }
        )
    }

    private func selectListHeight(_ height: CGFloat, availableHeight: CGFloat) {
        guard availableHeight > 0 else { return }
        listDragOrigin = nil
        withAnimation(resizeAnimation) {
            if height < listClosingThreshold(availableHeight: availableHeight) {
                bottomList = nil
            } else {
                listPosition = .custom(min(availableHeight * 0.85, height) / availableHeight)
            }
        }
    }

    private func listClosingThreshold(availableHeight: CGFloat) -> CGFloat {
        min(120, availableHeight * 0.1)
    }

    private func listHeight(availableHeight: CGFloat) -> CGFloat {
        if case .custom(let fraction) = listPosition {
            return min(availableHeight * 0.85, max(0, availableHeight * fraction))
        }
        return height(for: listPosition, availableHeight: availableHeight)
    }

    private func cancelDrags() {
        isListDragCancelled = isListDragging
        listDragOrigin = nil
        didEmitListClosingFeedback = false
    }

    private func height(for position: Position, availableHeight: CGFloat) -> CGFloat {
        clampedHeight(availableHeight * position.fraction, availableHeight: availableHeight)
    }

    private func clampedHeight(_ height: CGFloat, availableHeight: CGFloat) -> CGFloat {
        let maximum = availableHeight * 0.85
        let minimum = min(minimumPaneHeight + 80, maximum)
        return min(maximum, max(minimum, height))
    }

    private struct DragOrigin {
        let height: CGFloat
        let availableHeight: CGFloat
    }

    private enum Position {
        case third
        case expanded
        case custom(CGFloat)

        var fraction: CGFloat {
            switch self {
            case .third: 1.0 / 3.0
            case .expanded: 1
            case .custom(let fraction): fraction
            }
        }

        func accessibilityValue(displayedFraction: CGFloat) -> String {
            switch self {
            case .third: "Un tiers de l’écran"
            case .expanded: "Fiche agrandie"
            case .custom: "\(Int((displayedFraction * 100).rounded())) %"
            }
        }
    }
}

/// Animate the list geometry while keeping the map at its native rendering size.
private struct MapDetailArrangement<Lists: View, MapContent: View, ListHandle: View>:
    View, Animatable {
    var listHeight: CGFloat
    var listSeparatorHeight: CGFloat
    let windowSize: CGSize
    let safeInsets: EdgeInsets
    let lists: Lists
    let listKind: MapBottomList?
    let mapContent: MapContent
    @ViewBuilder let listHandle: (CGFloat) -> ListHandle

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(listHeight, listSeparatorHeight) }
        set {
            listHeight = newValue.first
            listSeparatorHeight = newValue.second
        }
    }

    var body: some View {
        let expansion = min(1, max(0, listSeparatorHeight / ListSeparatorMetrics.height))
        let listPaneHeight = (listHeight + safeInsets.bottom) * expansion
        let displayedListHeight = max(0, listHeight * expansion)
        let mapHeight = max(
            0, windowSize.height - listSeparatorHeight - listPaneHeight
        )
        let mapShape = UnevenRoundedRectangle(
            bottomLeadingRadius: cornerRadius(height: mapHeight) * expansion,
            bottomTrailingRadius: cornerRadius(height: mapHeight) * expansion,
            style: .continuous
        )

        // Preserve the map's structural slot and its full native rendering size.
        VStack(spacing: 0) {
            mapContent
                .environment(\.mapRenderSize, windowSize)
                .environment(\.mapContentInsets, EdgeInsets(
                    top: safeInsets.top,
                    leading: safeInsets.leading,
                    bottom: max(safeInsets.bottom * (1 - expansion), ListSeparatorMetrics.overlap * expansion),
                    trailing: safeInsets.trailing
                ))
                .frame(maxWidth: .infinity)
                .frame(height: mapHeight)
                .clipShape(mapShape)
                .contentShape(mapShape)

            Color.black
                .frame(height: max(0, listSeparatorHeight))
                .accessibilityHidden(true)

            Color.clear.frame(height: max(0, listPaneHeight))
        }
        .background(.black)
        .overlay(alignment: .bottom) {
            // Keep both lists mounted while their pane is closed.
            lists
                .frame(height: max(0, listPaneHeight))
                .padding(EdgeInsets(
                    top: 0, leading: safeInsets.leading,
                    bottom: 0, trailing: safeInsets.trailing
                ))
                .background(Color(.secondarySystemGroupedBackground).opacity(expansion))
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: cornerRadius(height: listPaneHeight) * expansion,
                    topTrailingRadius: cornerRadius(height: listPaneHeight) * expansion,
                    style: .continuous
                ))
                .opacity(expansion)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(listKind == .friends ? "map-friends-pane" : "map-events-pane")
                .accessibilityHidden(listSeparatorHeight == 0)
                .allowsHitTesting(listSeparatorHeight > 0)
        }
        .overlay(alignment: .top) {
            if listSeparatorHeight > 0 {
                // Keep the hit target larger than the visible black separator.
                listHandle(displayedListHeight)
                    .frame(height: ListSeparatorMetrics.hitHeight)
                    .offset(y: windowSize.height - listPaneHeight
                        - listSeparatorHeight / 2 - ListSeparatorMetrics.hitHeight / 2)
                    .opacity(expansion)
            }
        }
        .transaction { $0.animation = nil }
    }

    private func cornerRadius(height: CGFloat) -> CGFloat {
        min(32, max(0, min(windowSize.width, height)) / 4)
    }
}

/// Keeps interactive overlays clear of system bars while their map fills the screen.
struct MapContentSafeArea: ViewModifier {
    @Environment(\.mapContentInsets) private var insets
    var edges: Edge.Set = .all

    func body(content: Content) -> some View {
        content.padding(EdgeInsets(
            top: edges.contains(.top) ? insets.top : 0,
            leading: edges.contains(.leading) ? insets.leading : 0,
            bottom: edges.contains(.bottom) ? insets.bottom : 0,
            trailing: edges.contains(.trailing) ? insets.trailing : 0
        ))
    }
}
