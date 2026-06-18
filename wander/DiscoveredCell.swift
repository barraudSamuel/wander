//
//  DiscoveredCell.swift
//  wander
//
//  Created by Samuel Barraud on 17/06/2026.
//

import Foundation
import SwiftData

@Model
final class DiscoveredCell {
    @Attribute(.unique) var id: String
    var resolution: Int
    var firstSeenAt: Date
    var lastSeenAt: Date

    init(id: String, resolution: Int, firstSeenAt: Date, lastSeenAt: Date) {
        self.id = id
        self.resolution = resolution
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
    }
}
