//
//  DiscoveredCellStore.swift
//  wander
//
//  Created by Samuel Barraud on 17/06/2026.
//

import Foundation
import Combine
import SwiftData

final class DiscoveredCellStore: ObservableObject {
    @Published private(set) var cells: [DiscoveredCell] = []

    private var modelContext: ModelContext?

    func configure(with context: ModelContext) {
        modelContext = context
        load()
    }

    func load() {
        guard let context = modelContext else { return }
        var descriptor = FetchDescriptor<DiscoveredCell>()
        descriptor.sortBy = [SortDescriptor(\.firstSeenAt)]
        do {
            cells = try context.fetch(descriptor)
        } catch {
            print("[DiscoveredCellStore] failed to fetch: \(error.localizedDescription)")
            cells = []
        }
    }

    @discardableResult
    func upsert(cellID: String, resolution: Int, seenAt: Date) -> DiscoveredCell {
        upsertMany(cellIDs: [cellID], resolution: resolution, seenAt: seenAt)
        if let cell = cells.first(where: { $0.id == cellID }) {
            return cell
        }
        let cell = DiscoveredCell(id: cellID, resolution: resolution, firstSeenAt: seenAt, lastSeenAt: seenAt)
        cells.append(cell)
        return cell
    }

    @discardableResult
    func upsertMany(cellIDs: Set<String>, resolution: Int, seenAt: Date) -> Int {
        guard let context = modelContext else { return 0 }
        var addedCount = 0

        for cellID in cellIDs {
            let id = cellID
            let predicate = #Predicate<DiscoveredCell> { $0.id == id }
            var descriptor = FetchDescriptor<DiscoveredCell>(predicate: predicate)
            descriptor.fetchLimit = 1

            if let existing = try? context.fetch(descriptor).first {
                existing.lastSeenAt = seenAt
            } else {
                let cell = DiscoveredCell(
                    id: cellID,
                    resolution: resolution,
                    firstSeenAt: seenAt,
                    lastSeenAt: seenAt
                )
                context.insert(cell)
                addedCount += 1
            }
        }

        try? context.save()
        load()
        return addedCount
    }

    func contains(_ cellID: String) -> Bool {
        cells.contains(where: { $0.id == cellID })
    }
}
