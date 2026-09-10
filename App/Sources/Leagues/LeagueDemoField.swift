import Foundation
import TycoonEngine

// MARK: Iteration 10 — M4 (leagues)

/// `-autoLeague demo`: a tier's field in the ghost cache, so the table can
/// be seen on a phone with no Game Center account and no other players.
///
/// Iteration 12 (J4): this used to write twelve made-up names with random
/// scores. The house field replaced it — nineteen founders who actually
/// played the week's seed — and the table plays that field on its own
/// when it opens, so the flag now only starts it a moment earlier. Never
/// in a release build, and never read by the engine's balance.
@MainActor
enum LeagueDemoField {
    static func seed(into session: GameSession, week: LeagueWeek, tier: LeagueTier, now: Date = Date()) {
        #if DEBUG
        // MARK: J4 (house field)
        Task { await session.ensureHouseField(week: week, tier: tier) }
        // MARK: end J4
        #endif
    }
}
