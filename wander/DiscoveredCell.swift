//
//  DiscoveredCell.swift
//  wander
//
//  Created by Samuel Barraud on 17/06/2026.
//

import Foundation

struct DiscoveredCell: Identifiable, Codable, Hashable {
    let id: String
    let resolution: Int
    let firstSeenAt: Date
    var lastSeenAt: Date
}
