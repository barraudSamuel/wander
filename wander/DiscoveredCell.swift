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
    // V3 must have a different checksum from V1, which has the same fields.
    @Attribute(.unique, hashModifier: "WanderSchemaV3") var id: String
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
