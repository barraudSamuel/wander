import UIKit

/// Fictional venue illustrations requested for the saved-address pins.
/// A stable hash keeps the same crop through reimports and app restarts.
enum SavedPlaceIllustration {
    static func image(for sourceID: String) -> UIImage? {
        let assets = ["SavedPlaceCafe", "SavedPlaceGarden", "SavedPlaceFood"]
        let hash = sourceID.utf8.reduce(UInt64(14695981039346656037)) {
            ($0 ^ UInt64($1)) &* 1099511628211
        }
        return UIImage(named: assets[Int(hash % UInt64(assets.count))])
    }
}
