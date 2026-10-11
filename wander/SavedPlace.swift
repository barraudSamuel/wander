import CoreLocation
import Foundation
import SwiftData

@Model
final class SavedPlace {
    @Attribute(.unique) var id: String
    var ownerID: String
    var sourceID: String
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    var naverURLString: String
    var isUnavailable: Bool
    var hasLocationWarning: Bool
    var listName: String
    var categoryCode: String?
    var categoryName: String?

    var categoryLabel: String {
        NaverPlaceCategory.label(for: categoryCode, name: categoryName)
    }

    var outingCategory: OutingCategory? {
        switch categoryCode {
        case "CAFE": .coffee
        case "DINING": .meal
        default: nil
        }
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var naverURL: URL? { URL(string: naverURLString) }

    init(place: NaverImportedPlace, ownerID: String, listName: String) {
        // Length prefix keeps account/source pairs unique even when identifiers contain separators.
        self.id = "\(ownerID.utf8.count):\(ownerID):\(place.id)"
        self.ownerID = ownerID
        self.sourceID = place.id
        self.name = place.name
        self.address = place.address
        self.latitude = place.latitude
        self.longitude = place.longitude
        self.naverURLString = place.naverURL.absoluteString
        self.isUnavailable = place.isUnavailable
        self.hasLocationWarning = place.hasLocationWarning
        self.listName = listName
        self.categoryCode = place.categoryCode
        self.categoryName = place.categoryName
    }

    @MainActor
    static func importList(_ list: NaverImportedList, ownerID: String, into context: ModelContext) throws -> Int {
        guard !ownerID.isEmpty else { throw NaverListImportError.invalidData }
        let transaction = ModelContext(context.container)
        transaction.autosaveEnabled = false
        let existing = try transaction.fetch(FetchDescriptor<SavedPlace>(predicate: #Predicate { $0.ownerID == ownerID }))
        var bySourceID = Dictionary(uniqueKeysWithValues: existing.map { ($0.sourceID, $0) })
        var insertedCount = 0
        for place in list.places {
            guard CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)),
                  !place.id.isEmpty, !place.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw NaverListImportError.invalidData
            }
            if let saved = bySourceID[place.id] {
                saved.name = place.name
                saved.address = place.address
                saved.latitude = place.latitude
                saved.longitude = place.longitude
                saved.naverURLString = place.naverURL.absoluteString
                saved.isUnavailable = place.isUnavailable
                saved.hasLocationWarning = place.hasLocationWarning
                saved.listName = list.name
                saved.categoryCode = place.categoryCode
                saved.categoryName = place.categoryName
            } else {
                let saved = SavedPlace(place: place, ownerID: ownerID, listName: list.name)
                transaction.insert(saved)
                bySourceID[place.id] = saved
                insertedCount += 1
            }
        }
        try transaction.save()
        return insertedCount
    }
}
