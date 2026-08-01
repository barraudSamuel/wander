//
//  DiscoveredCellStore.swift
//  wander
//
//  SwiftData-backed store for discovered H3 cells. Loads once, then keeps an
//  in-memory index for incremental writes while exposing cells as @Published.
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
    private(set) var cellIDs: Set<String> = []

    private var modelContext: ModelContext?
    private var cellsByID: [String: DiscoveredCell] = [:]

    // MARK: - Configuration

    func configure(with context: ModelContext) {
        if let modelContext, modelContext === context {
            return
        }

        modelContext = context
        load()
    }

    // MARK: - Query

    func load() {
        guard let context = modelContext else { return }
        var descriptor = FetchDescriptor<DiscoveredCell>()
        descriptor.sortBy = [SortDescriptor(\.firstSeenAt)]
        do {
            let loadedCells = try context.fetch(descriptor)
            cellsByID = Dictionary(
                uniqueKeysWithValues: loadedCells.map { ($0.id, $0) }
            )
            cellIDs = Set(cellsByID.keys)
            cells = loadedCells
        } catch {
            print("[DiscoveredCellStore] failed to fetch: \(error.localizedDescription)")
            cellsByID = [:]
            cellIDs = []
            cells = []
        }
    }

    // MARK: - Upsert

    /// Single-cell upsert. Delegates to `upsertMany` then returns the stored cell.
    @discardableResult
    func upsert(cellID: String, resolution: Int, seenAt: Date) -> DiscoveredCell {
        upsertMany(cellIDs: [cellID], resolution: resolution, seenAt: seenAt)
        return cellsByID[cellID]
            ?? DiscoveredCell(id: cellID, resolution: resolution, firstSeenAt: seenAt, lastSeenAt: seenAt)
    }

    @discardableResult
    func upsertMany(cellIDs: Set<String>, resolution: Int, seenAt: Date) -> Int {
        guard let context = modelContext else { return 0 }

        var insertedCells: [DiscoveredCell] = []
        insertedCells.reserveCapacity(cellIDs.count)

        for cellID in cellIDs.sorted() {
            if let existing = cellsByID[cellID] {
                existing.lastSeenAt = seenAt
            } else {
                let cell = DiscoveredCell(
                    id: cellID,
                    resolution: resolution,
                    firstSeenAt: seenAt,
                    lastSeenAt: seenAt
                )
                context.insert(cell)
                cellsByID[cellID] = cell
                self.cellIDs.insert(cellID)
                insertedCells.append(cell)
            }
        }

        try? context.save()
        publishCells(adding: insertedCells)
        return insertedCells.count
    }

    /// Accumulates duration and visit count updates into matching cells.
    /// Cells that don't exist yet are created in the same persistence pass.
    func applyHeatMapUpdates(_ updates: [CellHeatMapUpdate], resolution: Int, seenAt: Date) {
        guard let context = modelContext, !updates.isEmpty else { return }

        var insertedCells: [DiscoveredCell] = []
        insertedCells.reserveCapacity(updates.count)

        for update in updates {
            let cell: DiscoveredCell
            if let existing = cellsByID[update.cellID] {
                cell = existing
            } else {
                cell = DiscoveredCell(
                    id: update.cellID,
                    resolution: resolution,
                    firstSeenAt: seenAt,
                    lastSeenAt: seenAt
                )
                context.insert(cell)
                cellsByID[update.cellID] = cell
                cellIDs.insert(update.cellID)
                insertedCells.append(cell)
            }

            cell.duration += update.duration
            cell.visitCount += update.visitIncrement
        }

        try? context.save()
        publishCells(adding: insertedCells)
    }

    func contains(_ cellID: String) -> Bool {
        cellIDs.contains(cellID)
    }

    private func publishCells(adding insertedCells: [DiscoveredCell]) {
        guard !insertedCells.isEmpty else {
            cells = Array(cells)
            return
        }

        let additions = insertedCells.sorted {
            if $0.firstSeenAt == $1.firstSeenAt {
                return $0.id < $1.id
            }
            return $0.firstSeenAt < $1.firstSeenAt
        }
        var merged: [DiscoveredCell] = []
        merged.reserveCapacity(cells.count + additions.count)
        var existingIndex = cells.startIndex
        var additionIndex = additions.startIndex

        while existingIndex < cells.endIndex, additionIndex < additions.endIndex {
            if cells[existingIndex].firstSeenAt <= additions[additionIndex].firstSeenAt {
                merged.append(cells[existingIndex])
                existingIndex += 1
            } else {
                merged.append(additions[additionIndex])
                additionIndex += 1
            }
        }

        if existingIndex < cells.endIndex {
            merged.append(contentsOf: cells[existingIndex...])
        }
        if additionIndex < additions.endIndex {
            merged.append(contentsOf: additions[additionIndex...])
        }

        cells = merged
    }

    // MARK: - Deletion

    func deleteAll() throws {
        guard let context = modelContext else { return }

        for cell in cells {
            context.delete(cell)
        }

        try context.save()
        cellsByID = [:]
        cellIDs = []
        cells = []
    }
}
