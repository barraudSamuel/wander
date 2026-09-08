import SwiftUI

struct MapDetailSplitView<Detail: View, MapContent: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var minimumDetailHeight = 140
    @State private var position: Position = .half
    @GestureState(resetTransaction: Transaction(animation: .snappy(duration: 0.25)))
    private var dragTranslation: CGFloat = 0

    let isPresented: Bool
    private let detail: Detail
    private let mapContent: MapContent

    init(
        isPresented: Bool,
        @ViewBuilder detail: () -> Detail,
        @ViewBuilder map: () -> MapContent
    ) {
        self.isPresented = isPresented
        self.detail = detail()
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
                    ? safeInsets.top + clampedHeight(
                        height(for: position, availableHeight: availableHeight)
                            + dragTranslation,
                        availableHeight: availableHeight
                    )
                    : 0
                let visibleSeparatorHeight = isPresented ? separatorHeight : 0
                let mapHeight = max(
                    0,
                    geometry.size.height - detailHeight - visibleSeparatorHeight
                )
                let detailRadius = cornerRadius(
                    width: geometry.size.width,
                    height: detailHeight
                )
                let mapRadius = isPresented
                    ? cornerRadius(width: geometry.size.width, height: mapHeight)
                    : 0
                let detailShape = UnevenRoundedRectangle(
                    bottomLeadingRadius: detailRadius,
                    bottomTrailingRadius: detailRadius,
                    style: .continuous
                )
                let mapShape = UnevenRoundedRectangle(
                    topLeadingRadius: mapRadius,
                    topTrailingRadius: mapRadius,
                    style: .continuous
                )

                // Keep the map in the same structural slot as the pane opens and closes.
                VStack(spacing: 0) {
                    detail
                        .padding(EdgeInsets(
                            top: safeInsets.top,
                            leading: safeInsets.leading,
                            bottom: 0,
                            trailing: safeInsets.trailing
                        ))
                        .frame(maxWidth: .infinity)
                        .frame(height: detailHeight, alignment: .top)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(detailShape)
                        .contentShape(detailShape)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("map-detail-pane")
                        .accessibilityHidden(!isPresented)
                        .allowsHitTesting(isPresented)

                    if isPresented {
                        resizeHandle(availableHeight: availableHeight)
                            .frame(height: visibleSeparatorHeight)
                            .clipped()
                            .transition(.identity)
                    }

                    mapContent
                        .environment(\.mapRenderSize, geometry.size)
                        .environment(\.mapContentInsets, EdgeInsets(
                            top: isPresented ? 0 : safeInsets.top,
                            leading: safeInsets.leading,
                            bottom: safeInsets.bottom,
                            trailing: safeInsets.trailing
                        ))
                        .frame(maxWidth: .infinity)
                        .frame(height: mapHeight)
                        .clipShape(mapShape)
                        .contentShape(mapShape)
                }
                .background(.black)
                .transaction { transaction in
                    if reduceMotion {
                        transaction.animation = nil
                    }
                }
                .animation(resizeAnimation, value: isPresented)
                .animation(resizeAnimation, value: position)
            }
            .ignoresSafeArea(.container)
        }
        .onChange(of: isPresented) { _, presented in
            if presented {
                position = .half
            }
        }
    }

    // MARK: - Resizing

    private var resizeAnimation: Animation? {
        reduceMotion ? nil : .snappy(duration: 0.25)
    }

    private func cornerRadius(width: CGFloat, height: CGFloat) -> CGFloat {
        min(32, max(0, min(width, height)) / 4)
    }

    private func resizeHandle(availableHeight: CGFloat) -> some View {
        Button {
            switch position {
            case .compact: position = .half
            case .half: position = .expanded
            case .expanded: position = .compact
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
        .accessibilityLabel("Taille de la fiche")
        .accessibilityValue(position.accessibilityValue)
        .accessibilityHint("Touchez deux fois pour passer à la taille suivante.")
        .accessibilityIdentifier("map-detail-resize-handle")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                position = position == .compact ? .half : .expanded
            case .decrement:
                position = position == .expanded ? .half : .compact
            @unknown default:
                break
            }
        }
        .highPriorityGesture(
            DragGesture(minimumDistance: 8, coordinateSpace: .global)
                .updating($dragTranslation) { value, translation, transaction in
                    translation = value.translation.height
                    transaction.animation = nil
                }
                .onEnded { value in
                    let destination = height(
                        for: position,
                        availableHeight: availableHeight
                    ) + value.predictedEndTranslation.height
                    position = Position.allCases.min {
                        abs(height(for: $0, availableHeight: availableHeight) - destination)
                            < abs(height(for: $1, availableHeight: availableHeight) - destination)
                    } ?? .half
                }
        )
    }

    private func height(for position: Position, availableHeight: CGFloat) -> CGFloat {
        clampedHeight(
            availableHeight * position.fraction,
            availableHeight: availableHeight
        )
    }

    private func clampedHeight(_ height: CGFloat, availableHeight: CGFloat) -> CGFloat {
        let minimum = min(minimumDetailHeight, availableHeight * 0.4)
        let minimumMapHeight = min(140, availableHeight * 0.3)
        let maximum = availableHeight - minimumMapHeight
        return min(maximum, max(minimum, height))
    }

    private enum Position: CaseIterable {
        case compact
        case half
        case expanded

        var fraction: CGFloat {
            switch self {
            case .compact: 0.25
            case .half: 0.5
            case .expanded: 0.75
            }
        }

        var accessibilityValue: String {
            switch self {
            case .compact: "Fiche réduite"
            case .half: "Moitié de l’écran"
            case .expanded: "Fiche agrandie"
            }
        }
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
