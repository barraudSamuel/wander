//
//  DiscoveredCellStore.swift
//  wander
//
//  Created by Samuel Barraud on 17/06/2026.
//

import Foundation
import Combine

final class DiscoveredCellStore: ObservableObject {
    @Published private(set) var cells: [DiscoveredCell] = []

    private var fileURL: URL {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = urls.first!
            .appendingPathComponent("wander", isDirectory: true)

        if !FileManager.default.fileExists(atPath: appSupport.path) {
            try? FileManager.default.createDirectory(
                at: appSupport,
                withIntermediateDirectories: true
            )
        }

        return appSupport.appendingPathComponent("discovered_cells.json")
    }

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            cells = []
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([DiscoveredCell].self, from: data)
            cells = decoded
        } catch {
            print("[DiscoveredCellStore] failed to load: \(error.localizedDescription)")
            cells = []
        }
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(cells)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[DiscoveredCellStore] failed to save: \(error.localizedDescription)")
        }
    }

    @discardableResult
    func upsert(cellID: String, resolution: Int, seenAt: Date) -> DiscoveredCell {
        if let index = cells.firstIndex(where: { $0.id == cellID }) {
            cells[index].lastSeenAt = seenAt
            return cells[index]
        } else {
            let cell = DiscoveredCell(
                id: cellID,
                resolution: resolution,
                firstSeenAt: seenAt,
                lastSeenAt: seenAt
            )
            cells.append(cell)
            return cell
        }
    }

    func contains(_ cellID: String) -> Bool {
        cells.contains(where: { $0.id == cellID })
    }
}
