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

/// Keeps one map scene mounted above the native navigation.
struct MotionDockView<MapContent: View>: View {
    @Binding var selection: MotionDockSelection
    let isEventsPresented: Bool
    let onToggleEvents: () -> Void
    @ViewBuilder let map: () -> MapContent

    var body: some View {
        NativeMapTabView(
            selection: $selection,
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
