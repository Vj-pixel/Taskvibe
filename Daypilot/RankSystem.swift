// RankSystem.swift
// Rank-progression logic extracted from ProfileView for testability.

import Foundation

struct RankTier {
    let name: String
    let icon: String
    let rangeStart: Int
    let nextAt: Int?

    var isMaxRank: Bool { nextAt == nil }

    func progress(for completed: Int) -> Double {
        guard let next = nextAt, next > rangeStart else { return 1.0 }
        let progress = Double(completed - rangeStart) / Double(next - rangeStart)
        return min(max(progress, 0), 1)
    }
}

struct RankSystem {
    // Ordered from lowest to highest threshold.
    static let tiers: [(threshold: Int, name: String, icon: String)] = [
        (0,   "Cautious Cadet",   "airplane"),
        (5,   "Persistent Pilot", "airplane.departure"),
        (15,  "Bold Barnstormer", "wind"),
        (30,  "Capable Copilot",  "person.2.fill"),
        (50,  "Daring Drifter",   "cloud.fill"),
        (75,  "Fearless Flier",   "bolt.fill"),
        (100, "Stellar Skydiver", "star.fill"),
        (150, "Master Maverick",  "crown.fill"),
        (200, "Legendary Lancer", "trophy.fill"),
    ]

    /// Returns the rank tier for the given completed-task count.
    static func rank(for completed: Int) -> RankTier {
        var currentIndex = 0
        for (i, tier) in tiers.enumerated() {
            if completed >= tier.threshold { currentIndex = i }
        }
        let current = tiers[currentIndex]
        let nextAt: Int? = currentIndex + 1 < tiers.count
            ? tiers[currentIndex + 1].threshold
            : nil
        return RankTier(
            name: current.name,
            icon: current.icon,
            rangeStart: current.threshold,
            nextAt: nextAt
        )
    }
}
