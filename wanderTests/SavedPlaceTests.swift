import SwiftData
import XCTest
@testable import wander

@MainActor
final class SavedPlaceTests: XCTestCase {
    func testReimportUpdatesWithoutDuplicatesAndSeparatesAccounts() throws {
        let container = try ModelContainer(for: SavedPlace.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let list = NaverImportedList(name: "Cafés", places: [place(), place()])
        XCTAssertEqual(try SavedPlace.importList(list, ownerID: "first", into: context), 1)
        XCTAssertEqual(try SavedPlace.importList(NaverImportedList(name: "Updated", places: [place(name: "New name")]), ownerID: "first", into: context), 0)
        XCTAssertEqual(try SavedPlace.importList(list, ownerID: "second", into: context), 1)
        let places = try ModelContext(container).fetch(FetchDescriptor<SavedPlace>())
        XCTAssertEqual(places.count, 2)
        XCTAssertEqual(Set(places.map(\.id)).count, 2)
        XCTAssertEqual(places.first { $0.ownerID == "first" }?.name, "New name")
        XCTAssertEqual(places.first { $0.ownerID == "first" }?.listName, "Updated")
        XCTAssertEqual(places.first { $0.ownerID == "second" }?.name, "Café")
    }

    func testReimportRefreshesAlreadyFetchedMainContextPlace() throws {
        let container = try ModelContainer(for: SavedPlace.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let original = NaverImportedList(name: "Cafés", places: [place()])
        XCTAssertEqual(try SavedPlace.importList(original, ownerID: "first", into: context), 1)
        let displayedPlace = try XCTUnwrap(context.fetch(FetchDescriptor<SavedPlace>()).first)
        XCTAssertEqual(displayedPlace.name, "Café")
        XCTAssertEqual(displayedPlace.coordinate.latitude, 37)

        let revised = NaverImportedList(name: "Updated", places: [place(name: "Moved café", latitude: 38, categoryCode: "DINING")])
        XCTAssertEqual(try SavedPlace.importList(revised, ownerID: "first", into: context), 0)
        let refreshedPlace = try XCTUnwrap(context.fetch(FetchDescriptor<SavedPlace>()).first)
        XCTAssertEqual(refreshedPlace.name, "Moved café")
        XCTAssertEqual(refreshedPlace.coordinate.latitude, 38)
        XCTAssertEqual(displayedPlace.name, "Moved café")
        XCTAssertEqual(displayedPlace.coordinate.latitude, 38)
        XCTAssertEqual(displayedPlace.categoryCode, "DINING")
        XCTAssertEqual(displayedPlace.categoryLabel, "Restaurant")
    }

    func testFailedImportDoesNotSavePartialResultsOrChangeCallingContext() throws {
        let container = try ModelContainer(for: SavedPlace.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        context.autosaveEnabled = false
        let pending = SavedPlace(place: place(id: "pending"), ownerID: "first", listName: "Pending")
        context.insert(pending)
        let invalidList = NaverImportedList(name: "Invalid", places: [place(), place(id: "bad", latitude: 100)])
        XCTAssertThrowsError(try SavedPlace.importList(invalidList, ownerID: "first", into: context))
        XCTAssertTrue(context.hasChanges)
        XCTAssertEqual(pending.listName, "Pending")
        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<SavedPlace>()), 0)
    }

    func testSavedPlacesSurviveReopening() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("places.store")
        let schema = Schema(versionedSchema: WanderSchemaV5.self)
        try autoreleasepool {
            let container = try ModelContainer(for: schema, migrationPlan: WanderMigrationPlan.self,
                                               configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
            XCTAssertEqual(try SavedPlace.importList(NaverImportedList(name: "Cafés", places: [place()]), ownerID: "first", into: container.mainContext), 1)
        }
        try autoreleasepool {
            let container = try ModelContainer(for: schema, migrationPlan: WanderMigrationPlan.self,
                                               configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
            let places = try container.mainContext.fetch(FetchDescriptor<SavedPlace>())
            XCTAssertEqual(places.count, 1)
            XCTAssertEqual(places[0].ownerID, "first")
            XCTAssertEqual(places[0].coordinate.latitude, 37)
            XCTAssertTrue(places[0].isUnavailable)
            XCTAssertTrue(places[0].hasLocationWarning)
            XCTAssertEqual(places[0].categoryCode, "CAFE")
            XCTAssertEqual(places[0].categoryName, "카페")
            XCTAssertEqual(places[0].categoryLabel, "Café")
        }
    }

    private func place(id: String = "place:1", name: String = "Café", latitude: Double = 37,
                       categoryCode: String = "CAFE") -> NaverImportedPlace {
        NaverImportedPlace(id: id, name: name, address: "Synthetic address", latitude: latitude, longitude: 127,
                           naverURL: URL(string: "https://map.naver.com/p/entry/place/1")!, isUnavailable: true, hasLocationWarning: true,
                           categoryCode: categoryCode, categoryName: "카페")
    }
}
