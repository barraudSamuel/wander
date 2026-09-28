import SwiftUI

/// Keeps one map scene mounted above the native navigation.
struct MotionDockView<MapContent: View>: View {
    let onExplore: () -> Void
    let isEventsPresented: Bool
    let onToggleEvents: () -> Void
    @ViewBuilder let map: () -> MapContent

    var body: some View {
        NativeMapTabView(
            onExplore: onExplore,
            isEventsPresented: isEventsPresented,
            onToggleEvents: onToggleEvents
        ) {
            GeometryReader { geometry in
                map()
                    .ignoresSafeArea(.keyboard)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .ignoresSafeArea(.container)
    }
}
