import SwiftUI

/// An image control shared by the map's profile and events actions.
struct MapImageButton: View {
    static let side: CGFloat = 44

    let assetName: String
    let label: String
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(assetName)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: Self.side, height: Self.side)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.35), radius: 5, x: 0, y: 2)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
