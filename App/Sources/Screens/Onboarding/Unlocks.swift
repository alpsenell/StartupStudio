import Foundation
import TycoonEngine

// MARK: Iteration 7 — what the ledger unlocks (R4)

/// The looks and the origin the ledger's endings earn. Read-only on the
/// ledger: the engine never checks a lock, and every bot keeps founding
/// with any origin and any face. What is locked is locked in the
/// new-game flow alone.
enum Unlocks {
    /// The origins a player with these endings cannot pick yet: the
    /// mortgaged start waits for a first ending of any kind, so a first
    /// company is never founded against the flat.
    static func lockedOrigins(endingsReached: Set<EndingKind>) -> Set<FoundingOrigin> {
        endingsReached.isEmpty ? [.mortgaged] : []
    }

    /// The line under a padlocked origin.
    static let originLockReason = "Reach an ending"

    /// One earned look per ending, in the order the ribbons list them.
    /// The seeds are curated by eye: six faces the 24 base looks do not
    /// have, one per ending, appended to the picker as each is earned.
    static let earnedLooks: [(ending: EndingKind, seed: UInt64)] = [
        (.bankruptcy, 0xB0A7_0001_5EED_0A11),
        (.soldUp, 0x50D1_0002_5EED_0B22),
        (.oustedByBoard, 0x0057_0003_5EED_0C33),
        (.acquired, 0xACC1_0004_5EED_0D44),
        (.ipo, 0x1B0E_0005_5EED_0E55),
        (.independent, 0x1DE9_0006_5EED_0F66),
    ]

    /// The seeds a player with these endings has earned, in ribbon order.
    static func earnedLookSeeds(endingsReached: Set<EndingKind>) -> [(ending: EndingKind, seed: UInt64)] {
        earnedLooks.filter { endingsReached.contains($0.ending) }
    }

    /// The ribbon's word for the look an ending earned.
    static func ribbon(for ending: EndingKind) -> String {
        "Earned · \(ending.headline)"
    }

    // MARK: Iteration 10 — M5 (morning desk)

    /// The faces a run of mornings earns. The rungs themselves live in
    /// `DeskRewards`, so the desk's table is the only place a streak
    /// length is written down; this only turns them into seeds the
    /// founder picker can append, exactly the way a finished season does.
    static func earnedDeskLookSeeds(bestStreak: Int) -> [UInt64] {
        DeskRewards.looks.filter { $0.days <= bestStreak }.map(\.seed)
    }

    // MARK: end of Iteration 10 — M5
}
