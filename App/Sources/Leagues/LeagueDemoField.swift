import Foundation
import TycoonEngine

// MARK: Iteration 10 — M4 (leagues)

/// `-autoLeague demo`: a tier's field, written straight into the ghost
/// cache so the table can be seen on a phone with no Game Center account
/// and no other players.
///
/// Display data for the screenshot pass, in the spirit of `LegacyLedger.
/// sample`: it is written through the ordinary ghost store, so what the
/// table draws is the real ghost path, not a stubbed view. Never in a
/// release build, and never read by the engine's balance.
@MainActor
enum LeagueDemoField {
    /// The names and numbers a demo tier is filled with. Deterministic:
    /// the same screenshot twice.
    static let names = [
        "Rune Adeyemi", "Petra Vaszary", "Kit Okafor", "Sol Marchetti",
        "Ines Halloran", "Dov Bergström", "Nina Achebe", "Casper Lund",
        "Wren Ferreira", "Otto Salveson", "June Baptiste", "Milo Kranz",
    ]

    static func seed(into session: GameSession, week: LeagueWeek, tier: LeagueTier, now: Date = Date()) {
        #if DEBUG
        var rng = SeededRNG(seed: week.seed ^ 0xDEF0_0000 ^ UInt64(tier.index))
        _ = rng.next()
        let store = session.ghostStore
        let key = LeagueGhostKey.key(week: week.week, tier: tier)
        for name in names {
            let draw = Int(rng.next() % 380_000)
            store.save(GhostLog(
                day: key,
                player: name,
                companyName: name,
                appearanceSeed: rng.next(),
                focusTopicIDs: [],
                launches: [],
                finalNetWorth: draw - 40_000,
                recordedAt: now
            ))
        }
        #endif
    }
}
