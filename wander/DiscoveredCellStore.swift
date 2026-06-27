//
//  DiscoveredCellStore.swift
//  wander
//
//  SwiftData-backed store for discovered H3 cells. Offers batch upsert
//  with a single fetch (instead of N+1) and exposes cells as @Published.
//
//  Created by Samuel Barraud on 17/06/2026.
//

import Foundation
import Combine
import SwiftData

struct CellHeatMapUpdate {
    let cellID: String
    let duration: TimeInterval
    let visitIncrement: Int
}

final class DiscoveredCellStore: ObservableObject {
    @Published private(set) var cells: [DiscoveredCell] = []

    private var modelContext: ModelContext?

    // MARK: - Configuration

    func configure(with context: ModelContext) {
        modelContext = context
        load()
    }

    // MARK: - Query

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

    // MARK: - Upsert

    /// Single-cell upsert. Delegates to `upsertMany` then returns the stored cell.
    @discardableResult
    func upsert(cellID: String, resolution: Int, seenAt: Date) -> DiscoveredCell {
        upsertMany(cellIDs: [cellID], resolution: resolution, seenAt: seenAt)
        return cells.first(where: { $0.id == cellID })
            ?? DiscoveredCell(id: cellID, resolution: resolution, firstSeenAt: seenAt, lastSeenAt: seenAt)
    }

    @discardableResult
    func upsertMany(cellIDs: Set<String>, resolution: Int, seenAt: Date) -> Int {
        guard let context = modelContext else { return 0 }

        let allExisting = (try? context.fetch(FetchDescriptor<DiscoveredCell>())) ?? []
        let existingByID = Dictionary(uniqueKeysWithValues: allExisting.map { ($0.id, $0) })

        var addedCount = 0

        for cellID in cellIDs {
            if let existing = existingByID[cellID] {
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

    /// Accumulates duration and visit count updates into matching cells.
    /// Cells that don't exist yet are created first via upsertMany.
    func applyHeatMapUpdates(_ updates: [CellHeatMapUpdate], resolution: Int, seenAt: Date) {
        guard let context = modelContext, !updates.isEmpty else { return }

        let allExisting = (try? context.fetch(FetchDescriptor<DiscoveredCell>())) ?? []
        let existingByID = Dictionary(uniqueKeysWithValues: allExisting.map { ($0.id, $0) })

        var needsLoad = false

        for update in updates {
            let cell: DiscoveredCell
            if let existing = existingByID[update.cellID] {
                cell = existing
            } else {
                cell = DiscoveredCell(
                    id: update.cellID,
                    resolution: resolution,
                    firstSeenAt: seenAt,
                    lastSeenAt: seenAt
                )
                context.insert(cell)
                needsLoad = true
            }

            cell.duration += update.duration
            cell.visitCount += update.visitIncrement
        }

        try? context.save()
        if needsLoad {
            load()
        } else {
            cells = allExisting
        }
    }

    func contains(_ cellID: String) -> Bool {
        cells.contains(where: { $0.id == cellID })
    }
}
