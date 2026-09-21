import SwiftUI
import UIKit

struct MapDetailSplitView<Detail: View, Events: View, MapContent: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var minimumPaneHeight = 140
    @State private var position: Position = .third
    @State private var dragOrigin: DragOrigin?
    @GestureState private var isDragging = false
    @State private var eventsPosition: Position = .third
    @State private var eventsDragOrigin: DragOrigin?
    @GestureState private var isEventsDragging = false
    @State private var isDragCancelled = false
    @State private var isEventsDragCancelled = false
    @State private var didEmitEventsClosingFeedback = false

    let isPresented: Bool
    @Binding private var isEventsExpanded: Bool
    private let detail: Detail
    private let events: Events
    private let mapContent: MapContent

    init(
        isPresented: Bool,
        isEventsExpanded: Binding<Bool>,
        @ViewBuilder detail: () -> Detail,
        @ViewBuilder events: () -> Events,
        @ViewBuilder map: () -> MapContent
    ) {
        self.isPresented = isPresented
        self._isEventsExpanded = isEventsExpanded
        self.detail = detail()
        self.events = events()
        self.mapContent = map()
    }

    var body: some View {
        GeometryReader { safeGeometry in
            GeometryReader { geometry in
                let safeInsets = safeGeometry.safeAreaInsets
                let separatorHeight = min(44, max(0, geometry.size.height))
                let availableHeight = max(
                    0,
                    geometry.size.height - safeInsets.top - safeInsets.bottom - separatorHeight
                )
                let detailHeight = isPresented
                    ? safeInsets.top + height(for: position, availableHeight: availableHeight)
                    : 0
                let showsEventsPane = isEventsExpanded && !isPresented

                MapDetailArrangement(
                    detailHeight: detailHeight,
                    separatorHeight: isPresented ? separatorHeight : 0,
                    eventsHeight: showsEventsPane
                        ? eventsHeight(availableHeight: availableHeight)
                        : 0,
                    eventsSeparatorHeight: showsEventsPane ? separatorHeight : 0,
                    windowSize: geometry.size,
                    safeInsets: safeInsets,
                    isPresented: isPresented,
                    detail: detail,
                    events: events,
                    mapContent: mapContent
                ) { displayedHeight in
                    resizeHandle(availableHeight: availableHeight, displayedHeight: displayedHeight)
                } eventsHandle: { displayedHeight in
                    eventsResizeHandle(availableHeight: availableHeight, displayedHeight: displayedHeight)
                }
                .animation(resizeAnimation, value: isPresented)
                .animation(resizeAnimation, value: isEventsExpanded)
                .onChange(of: isDragging) { _, dragging in
                    if !dragging {
                        dragOrigin = nil
                        isDragCancelled = false
                    }
                }
                .onChange(of: isEventsDragging) { _, dragging in
                    if !dragging {
                        eventsDragOrigin = nil
                        isEventsDragCancelled = false
                        didEmitEventsClosingFeedback = false
                    }
                }
                .onChange(of: geometry.size) { _, _ in
                    cancelDrags()
                }
            }
            .ignoresSafeArea(.container)
        }
        .onChange(of: isPresented) { _, _ in
            cancelDrags()
            position = .third
        }
        .onChange(of: isEventsExpanded) { _, _ in
            cancelDrags()
            eventsPosition = .third
        }
    }

    // MARK: - Resizing

    private var resizeAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.25)
    }

    private func resizeHandle(availableHeight: CGFloat, displayedHeight: CGFloat) -> some View {
        Button {
            let next: Position = switch position {
            case .compact: .third
            case .third: .expanded
            case .expanded: .compact
            case .custom:
                if displayedHeight < height(for: .third, availableHeight: availableHeight) - 1 {
                    .third
                } else if displayedHeight < height(for: .expanded, availableHeight: availableHeight) - 1 {
                    .expanded
                } else {
                    .compact
                }
            }
            select(next)
        } label: {
            Image(systemName: "minus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(.black)
        .accessibilityLabel("Taille du panneau")
        .accessibilityValue(position.accessibilityValue(
            displayedFraction: availableHeight > 0 ? displayedHeight / availableHeight : 0
        ))
        .accessibilityHint("Touchez deux fois pour passer à la taille suivante.")
        .accessibilityIdentifier("map-detail-resize-handle")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                adjustHeight(by: 0.05, displayedHeight: displayedHeight, availableHeight: availableHeight)
            case .decrement:
                adjustHeight(by: -0.05, displayedHeight: displayedHeight, availableHeight: availableHeight)
            @unknown default:
                break
            }
        }
        .highPriorityGesture(
            DragGesture(minimumDistance: 8, coordinateSpace: .global)
                .updating($isDragging) { _, dragging, transaction in
                    dragging = true
                    transaction.animation = nil
                }
                .onChanged { value in
                    guard availableHeight > 0, !isDragCancelled else { return }
                    // Use the displayed height when interrupting an animated shortcut.
                    let origin = dragOrigin ?? DragOrigin(height: displayedHeight, availableHeight: availableHeight)
                    // A rotation invalidates the gesture's original coordinate space.
                    guard origin.availableHeight == availableHeight else { return }
                    withTransaction(Transaction(animation: nil)) {
                        dragOrigin = origin
                        position = .custom(clampedHeight(
                            origin.height + value.translation.height,
                            availableHeight: availableHeight
                        ) / availableHeight)
                    }
                }
                .onEnded { value in
                    guard !isDragCancelled, let origin = dragOrigin, availableHeight > 0,
                          origin.availableHeight == availableHeight else {
                        dragOrigin = nil
                        return
                    }
                    withTransaction(Transaction(animation: nil)) {
                        position = .custom(clampedHeight(
                            origin.height + value.translation.height,
                            availableHeight: availableHeight
                        ) / availableHeight)
                        dragOrigin = nil
                    }
                }
        )
    }

    private func eventsResizeHandle(availableHeight: CGFloat, displayedHeight: CGFloat) -> some View {
        Button {
            let expandedHeight = height(for: .expanded, availableHeight: availableHeight)
            withAnimation(resizeAnimation) {
                if displayedHeight < expandedHeight - 1 {
                    eventsPosition = .expanded
                } else {
                    isEventsExpanded = false
                }
            }
        } label: {
            Image(systemName: "minus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(.black)
        .accessibilityLabel("Taille de la liste des événements")
        .accessibilityValue(eventsPosition.accessibilityValue(
            displayedFraction: availableHeight > 0 ? displayedHeight / availableHeight : 0
        ))
        .accessibilityHint("Faites glisser pour redimensionner. Touchez deux fois pour agrandir, puis replier.")
        .accessibilityIdentifier("map-events-resize-handle")
        .accessibilityAdjustableAction { direction in
            guard availableHeight > 0 else { return }
            switch direction {
            case .increment:
                selectEventsHeight(displayedHeight + 0.05 * availableHeight, availableHeight: availableHeight)
            case .decrement:
                selectEventsHeight(displayedHeight - 0.05 * availableHeight, availableHeight: availableHeight)
            @unknown default:
                break
            }
        }
        .highPriorityGesture(
            DragGesture(minimumDistance: 8, coordinateSpace: .global)
                .updating($isEventsDragging) { _, dragging, transaction in
                    dragging = true
                    transaction.animation = nil
                }
                .onChanged { value in
                    guard availableHeight > 0, !isEventsDragCancelled else { return }
                    let origin = eventsDragOrigin
                        ?? DragOrigin(height: displayedHeight, availableHeight: availableHeight)
                    guard origin.availableHeight == availableHeight else { return }
                    let proposedHeight = origin.height - value.translation.height
                    if !didEmitEventsClosingFeedback,
                       proposedHeight < eventsClosingThreshold(availableHeight: availableHeight) {
                        didEmitEventsClosingFeedback = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    withTransaction(Transaction(animation: nil)) {
                        eventsDragOrigin = origin
                        eventsPosition = .custom(min(
                            availableHeight * 0.85,
                            max(0, proposedHeight)
                        ) / availableHeight)
                    }
                }
                .onEnded { value in
                    guard !isEventsDragCancelled, let origin = eventsDragOrigin, availableHeight > 0,
                          origin.availableHeight == availableHeight else {
                        eventsDragOrigin = nil
                        return
                    }
                    eventsDragOrigin = nil
                    selectEventsHeight(origin.height - value.translation.height, availableHeight: availableHeight)
                }
        )
    }

    private func selectEventsHeight(_ height: CGFloat, availableHeight: CGFloat) {
        guard availableHeight > 0 else { return }
        eventsDragOrigin = nil
        withAnimation(resizeAnimation) {
            if height < eventsClosingThreshold(availableHeight: availableHeight) {
                isEventsExpanded = false
            } else {
                eventsPosition = .custom(min(availableHeight * 0.85, height) / availableHeight)
            }
        }
    }

    private func eventsClosingThreshold(availableHeight: CGFloat) -> CGFloat {
        min(120, availableHeight * 0.1)
    }

    private func eventsHeight(availableHeight: CGFloat) -> CGFloat {
        if case .custom(let fraction) = eventsPosition {
            return min(availableHeight * 0.85, max(0, availableHeight * fraction))
        }
        return height(for: eventsPosition, availableHeight: availableHeight)
    }

    private func cancelDrags() {
        isDragCancelled = isDragging
        isEventsDragCancelled = isEventsDragging
        dragOrigin = nil
        eventsDragOrigin = nil
        didEmitEventsClosingFeedback = false
    }

    private func adjustHeight(by fraction: CGFloat, displayedHeight: CGFloat, availableHeight: CGFloat) {
        guard availableHeight > 0 else { return }
        let height = clampedHeight(displayedHeight + fraction * availableHeight, availableHeight: availableHeight)
        guard abs(height - displayedHeight) > 0.5 else { return }
        select(.custom(height / availableHeight))
    }

    private func select(_ newPosition: Position) {
        dragOrigin = nil
        withAnimation(resizeAnimation) {
            position = newPosition
        }
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
        case compact
        case third
        case expanded
        case custom(CGFloat)

        var fraction: CGFloat {
            switch self {
            case .compact: 0.25
            case .third: 1.0 / 3.0
            case .expanded: 1
            case .custom(let fraction): fraction
            }
        }

        func accessibilityValue(displayedFraction: CGFloat) -> String {
            switch self {
            case .compact: "Fiche réduite"
            case .third: "Un tiers de l’écran"
            case .expanded: "Fiche agrandie"
            case .custom: "\(Int((displayedFraction * 100).rounded())) %"
            }
        }
    }
}

/// Interpolate the geometry once, then lay out each frame without another
/// animation on text runs, attachment positions or line breaks.
private struct MapDetailArrangement<Detail: View, Events: View, MapContent: View, Handle: View, EventsHandle: View>:
    View, Animatable {
    var detailHeight: CGFloat
    var separatorHeight: CGFloat
    var eventsHeight: CGFloat
    var eventsSeparatorHeight: CGFloat
    let windowSize: CGSize
    let safeInsets: EdgeInsets
    let isPresented: Bool
    let detail: Detail
    let events: Events
    let mapContent: MapContent
    @ViewBuilder let handle: (CGFloat) -> Handle
    @ViewBuilder let eventsHandle: (CGFloat) -> EventsHandle

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get {
            AnimatablePair(
                AnimatablePair(detailHeight, separatorHeight),
                AnimatablePair(eventsHeight, eventsSeparatorHeight)
            )
        }
        set {
            detailHeight = newValue.first.first
            separatorHeight = newValue.first.second
            eventsHeight = newValue.second.first
            eventsSeparatorHeight = newValue.second.second
        }
    }

    var body: some View {
        let expansion = min(1, max(0, eventsSeparatorHeight / 44))
        let eventsBottomInset = safeInsets.bottom * expansion
        let eventsPaneHeight = (eventsHeight + safeInsets.bottom) * expansion
        let mapHeight = max(
            0, windowSize.height - detailHeight - separatorHeight - eventsSeparatorHeight - eventsPaneHeight
        )
        let detailRadius = cornerRadius(height: detailHeight)
        let mapRadius = isPresented ? cornerRadius(height: mapHeight) : 0
        let detailShape = UnevenRoundedRectangle(
            bottomLeadingRadius: detailRadius,
            bottomTrailingRadius: detailRadius,
            style: .continuous
        )
        let mapShape = UnevenRoundedRectangle(
            topLeadingRadius: mapRadius,
            bottomLeadingRadius: cornerRadius(height: mapHeight) * expansion,
            bottomTrailingRadius: cornerRadius(height: mapHeight) * expansion,
            topTrailingRadius: mapRadius,
            style: .continuous
        )

        // Preserve the map's structural slot and its full native rendering size.
        VStack(spacing: 0) {
            detail
                .padding(EdgeInsets(
                    top: safeInsets.top, leading: safeInsets.leading,
                    bottom: 0, trailing: safeInsets.trailing
                ))
                .frame(maxWidth: .infinity)
                .frame(height: max(0, detailHeight), alignment: .top)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(detailShape)
                .contentShape(detailShape)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("map-detail-pane")
                .accessibilityHidden(!isPresented)
                .allowsHitTesting(isPresented)

            handle(max(0, detailHeight - safeInsets.top))
                .frame(height: max(0, separatorHeight))
                .clipped()
                .accessibilityHidden(!isPresented)
                .allowsHitTesting(isPresented)

            mapContent
                .environment(\.mapRenderSize, windowSize)
                .environment(\.mapContentInsets, EdgeInsets(
                    top: isPresented ? 0 : safeInsets.top,
                    leading: safeInsets.leading,
                    bottom: safeInsets.bottom * (1 - expansion),
                    trailing: safeInsets.trailing
                ))
                .frame(maxWidth: .infinity)
                .frame(height: mapHeight)
                .clipShape(mapShape)
                .contentShape(mapShape)

            eventsHandle(eventsHeight)
                .frame(height: max(0, eventsSeparatorHeight))
                .clipped()
                .accessibilityHidden(isPresented || eventsSeparatorHeight == 0)
                .allowsHitTesting(!isPresented && eventsSeparatorHeight > 0)

            Color.clear.frame(height: max(0, eventsPaneHeight))
        }
        .background(.black)
        .overlay(alignment: .bottom) {
            // Keep the list mounted while its pane is closed.
            events
                .frame(height: max(0, eventsHeight))
                .padding(EdgeInsets(
                    top: 0, leading: safeInsets.leading,
                    bottom: eventsBottomInset, trailing: safeInsets.trailing
                ))
                .background(Color(.secondarySystemGroupedBackground).opacity(expansion))
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: cornerRadius(height: eventsPaneHeight) * expansion,
                    topTrailingRadius: cornerRadius(height: eventsPaneHeight) * expansion,
                    style: .continuous
                ))
                .opacity(expansion)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("map-events-pane")
                .accessibilityHidden(isPresented || eventsSeparatorHeight == 0)
                .allowsHitTesting(!isPresented && eventsSeparatorHeight > 0)
        }
        .transaction { $0.animation = nil }
    }

    private func cornerRadius(height: CGFloat) -> CGFloat {
        min(32, max(0, min(windowSize.width, height)) / 4)
    }
}

// MARK: - Shared detail presentation

struct MapDetailPanel<Supporting: View, Actions: View>: View {
    @ScaledMetric(relativeTo: .body) private var minimumTextSize = 16

    let title: String
    let closeLabel: String
    var showsBackButton = false
    let scrollIdentifier: String
    let narrativeIdentifier: String
    let content: MapDetailTextContent
    let onDismiss: () -> Void
    @ViewBuilder let supporting: () -> Supporting
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if showsBackButton {
                    dismissButton
                }

                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)

                if !showsBackButton {
                    dismissButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .layoutPriority(1)

            GeometryReader { geometry in
                ScrollView {
                    MapDetailSummaryLayout(availableHeight: max(0, geometry.size.height - 12)) {
                        MapDetailFittingText(
                            content: content,
                            minimumFontSize: minimumTextSize,
                            identifier: narrativeIdentifier
                        )
                        supporting()
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
                .scrollBounceBehavior(.basedOnSize)
                .accessibilityIdentifier(scrollIdentifier)
            }

            actions()
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .layoutPriority(1)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .accessibilityElement(children: .contain)
    }

    private var dismissButton: some View {
        Button(action: onDismiss) {
            Image(systemName: showsBackButton ? "chevron.backward" : "xmark")
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel(closeLabel)
    }
}

/// Reserve the native status/footer's intrinsic height before fitting the text.
/// No geometry state or measurement feedback is needed during a drag.
private struct MapDetailSummaryLayout: Layout {
    let availableHeight: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let layout = measurements(width: proposal.width ?? 0, subviews: subviews)
        return CGSize(width: layout.width, height: layout.text.height + layout.spacing + layout.supporting.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let text = subviews.first else { return }
        let layout = measurements(width: bounds.width, subviews: subviews)
        text.place(at: bounds.origin, anchor: .topLeading, proposal: layout.textProposal)
        if subviews.count > 1 {
            subviews[1].place(
                at: CGPoint(x: bounds.minX, y: bounds.minY + layout.text.height + layout.spacing),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: bounds.width, height: layout.supporting.height)
            )
        }
    }

    private func measurements(width: CGFloat, subviews: Subviews) -> (
        width: CGFloat, text: CGSize, supporting: CGSize, spacing: CGFloat, textProposal: ProposedViewSize
    ) {
        let supporting = subviews.count > 1
            ? subviews[1].sizeThatFits(ProposedViewSize(width: width, height: nil))
            : .zero
        let spacing: CGFloat = supporting.height > 0 ? 6 : 0
        let textProposal = ProposedViewSize(
            width: width,
            height: max(0, availableHeight - supporting.height - spacing)
        )
        let text = subviews.first?.sizeThatFits(textProposal) ?? .zero
        return (width, text, supporting, spacing, textProposal)
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
