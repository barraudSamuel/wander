import SwiftUI

struct MapDockActions {
    let isCreationEnabled: Bool
    let onRecenter: () -> Void
    let onCreate: () -> Void
}

/// Keeps one map scene mounted beneath the events button.
struct MotionDockView<MapContent: View>: View {
    let isEventsPresented: Bool
    let onToggleEvents: () -> Void
    var mapActions: MapDockActions? = nil
    @ViewBuilder let map: () -> MapContent

    var body: some View {
        NativeMapTabView(
            isEventsPresented: isEventsPresented,
            onToggleEvents: onToggleEvents,
            mapActions: mapActions
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
