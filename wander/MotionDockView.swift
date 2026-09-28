import SwiftUI

/// Keeps one map scene mounted beneath the events button.
struct MotionDockView<MapContent: View>: View {
    let isEventsPresented: Bool
    let onToggleEvents: () -> Void
    @ViewBuilder let map: () -> MapContent

    var body: some View {
        NativeMapTabView(
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
