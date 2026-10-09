import CoreData
import SwiftData
import XCTest
@testable import wander

@MainActor
final class WanderMigrationPlanTests: XCTestCase {
    private let originalCells = [
        (id: "891fb466257ffff", resolution: 9,
         firstSeenAt: Date(timeIntervalSince1970: 1_700_000_000),
         lastSeenAt: Date(timeIntervalSince1970: 1_700_000_123)),
        (id: "8a1fb4662577fff", resolution: 10,
         firstSeenAt: Date(timeIntervalSince1970: 1_700_001_000),
         lastSeenAt: Date(timeIntervalSince1970: 1_700_009_999))
    ]

    func testV1MigrationPreservesExplorationAfterReopening() throws {
        let url = try makeStoreURL()
        try autoreleasepool {
            let schema = Schema(versionedSchema: WanderSchemaV1.self)
            let container = try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)]
            )
            for cell in originalCells {
                container.mainContext.insert(WanderSchemaV1.DiscoveredCell(
                    id: cell.id, resolution: cell.resolution,
                    firstSeenAt: cell.firstSeenAt, lastSeenAt: cell.lastSeenAt
                ))
            }
            try container.mainContext.save()
        }

        try assertOriginalCells(at: url)
        try assertOriginalCells(at: url)
    }

    func testV2MigrationPreservesVersionedAndUnversionedStoresAfterReopening() throws {
        // The shipped model-only container used the default schema version, 1.0.0.
        for schema in [
            Schema(versionedSchema: WanderSchemaV2.self),
            Schema([WanderSchemaV2.DiscoveredCell.self])
        ] {
            let url = try makeStoreURL()
            try autoreleasepool {
                let container = try ModelContainer(
                    for: schema,
                    configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)]
                )
                for original in originalCells {
                    let cell = WanderSchemaV2.DiscoveredCell(
                        id: original.id, resolution: original.resolution,
                        firstSeenAt: original.firstSeenAt, lastSeenAt: original.lastSeenAt
                    )
                    cell.duration = 3_600
                    cell.visitCount = 12
                    container.mainContext.insert(cell)
                }
                try container.mainContext.save()
            }

            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType, at: url, options: nil
            )
            let hashes = try XCTUnwrap(metadata[NSStoreModelVersionHashesKey] as? [String: Data])
            // Captured from the installed app's store before removing the heatmap.
            XCTAssertEqual(hashes["DiscoveredCell"]?.map { String(format: "%02x", $0) }.joined(),
                           "0a78012c72e441cf13c70efe67c904b2713126c194b40f347456ce153a846619")
            try assertOriginalCells(at: url)
            try assertOriginalCells(at: url)
        }
    }

    // Store teardown also needs a Swift task context on the test runner.
    func testFreshStorePersistsUpsertsAndRemoteRestoration() async throws {
        let url = try makeStoreURL()
        let original = originalCells[0]
        let later = original.lastSeenAt.addingTimeInterval(60)
        let remoteDate = Date(timeIntervalSince1970: 1_600_000_000)
        let fallbackDate = Date(timeIntervalSince1970: 1_500_000_000)

        try autoreleasepool {
            let container = try currentContainer(at: url)
            let attributes = try XCTUnwrap(container.schema.entities.first).attributesByName
            XCTAssertEqual(Set(attributes.keys), ["id", "resolution", "firstSeenAt", "lastSeenAt"])

            let store = DiscoveredCellStore()
            store.configure(with: container.mainContext)
            XCTAssertEqual(store.upsertMany(
                cellIDs: [original.id], resolution: original.resolution, seenAt: original.firstSeenAt
            ), 1)
            XCTAssertEqual(store.upsertMany(
                cellIDs: [original.id], resolution: original.resolution, seenAt: later
            ), 0)
            XCTAssertEqual(try store.mergeRemoteCells(
                [
                    RemoteDiscoveredCell(id: original.id, sharedAt: remoteDate),
                    RemoteDiscoveredCell(id: "remote-dated", sharedAt: remoteDate),
                    RemoteDiscoveredCell(id: "remote-undated", sharedAt: nil),
                    RemoteDiscoveredCell(id: "remote-dated", sharedAt: remoteDate)
                ],
                resolution: 9, fallbackSeenAt: fallbackDate
            ), 2)
            try container.mainContext.save()
            XCTAssertEqual(store.cellIDs, [original.id, "remote-dated", "remote-undated"])
        }

        try autoreleasepool {
            let container = try currentContainer(at: url)
            let cells = try container.mainContext.fetch(FetchDescriptor<DiscoveredCell>())
            XCTAssertEqual(cells.count, 3)
            let local = try XCTUnwrap(cells.first { $0.id == original.id })
            XCTAssertEqual(local.resolution, original.resolution)
            XCTAssertEqual(local.firstSeenAt, original.firstSeenAt)
            XCTAssertEqual(local.lastSeenAt, later)
            let dated = try XCTUnwrap(cells.first { $0.id == "remote-dated" })
            XCTAssertEqual(dated.resolution, 9)
            XCTAssertEqual(dated.firstSeenAt, remoteDate)
            XCTAssertEqual(dated.lastSeenAt, remoteDate)
            let undated = try XCTUnwrap(cells.first { $0.id == "remote-undated" })
            XCTAssertEqual(undated.resolution, 9)
            XCTAssertEqual(undated.firstSeenAt, fallbackDate)
            XCTAssertEqual(undated.lastSeenAt, fallbackDate)
        }
    }

    private func makeStoreURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WanderMigrationPlanTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try FileManager.default.removeItem(at: directory)
        }
        return directory.appendingPathComponent("exploration.store")
    }

    private func currentContainer(at url: URL) throws -> ModelContainer {
        try ModelContainer(
            for: DiscoveredCell.self,
            migrationPlan: WanderMigrationPlan.self,
            configurations: ModelConfiguration(url: url, cloudKitDatabase: .none)
        )
    }

    private func assertOriginalCells(at url: URL, file: StaticString = #filePath, line: UInt = #line) throws {
        try autoreleasepool {
            let container = try currentContainer(at: url)
            let cells = try container.mainContext.fetch(FetchDescriptor<DiscoveredCell>())
            XCTAssertEqual(cells.count, originalCells.count, file: file, line: line)
            XCTAssertEqual(Set(cells.map(\.id)), Set(originalCells.map(\.id)), file: file, line: line)
            for original in originalCells {
                let cell = try XCTUnwrap(cells.first { $0.id == original.id }, file: file, line: line)
                XCTAssertEqual(cell.resolution, original.resolution, file: file, line: line)
                XCTAssertEqual(cell.firstSeenAt, original.firstSeenAt, file: file, line: line)
                XCTAssertEqual(cell.lastSeenAt, original.lastSeenAt, file: file, line: line)
            }
        }
    }
}
