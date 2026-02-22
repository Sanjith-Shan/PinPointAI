// TrackedItem.swift
// Data model representing a physical item being tracked in 3D space

import SwiftUI
import simd
import UIKit

struct TrackedItem: Identifiable {
    let id: UUID
    var name: String
    var position: SIMD3<Float>
    var color: Color
    var uiColor: UIColor
    var lastSeen: Date
    var isActivelyTracked: Bool

    // Predefined color palette for items
    private static let palette: [(Color, UIColor)] = [
        (.red, .systemRed),
        (.blue, .systemBlue),
        (.green, .systemGreen),
        (.orange, .systemOrange),
        (.purple, .systemPurple),
        (.pink, .systemPink),
        (.cyan, .systemCyan),
        (.yellow, .systemYellow)
    ]

    init(name: String, position: SIMD3<Float>, colorIndex: Int) {
        self.id = UUID()
        self.name = name
        self.position = position
        self.lastSeen = Date()
        self.isActivelyTracked = true

        let pair = TrackedItem.palette[colorIndex % TrackedItem.palette.count]
        self.color = pair.0
        self.uiColor = pair.1
    }

    /// Formatted string showing how long ago the item was last seen
    var lastSeenDescription: String {
        let interval = Date().timeIntervalSince(lastSeen)
        if interval < 5 { return "Now" }
        if interval < 60 { return "\(Int(interval))s ago" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        return "\(Int(interval / 3600))h ago"
    }
}
