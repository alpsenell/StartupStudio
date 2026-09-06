import Foundation
import TycoonEngine

// MARK: Iteration 8 — scenarios

/// An authored start: a company already in a situation, an objective, a
/// deadline, and three stars for how well it went.
///
/// Every scenario is one of the three bundled fixture saves with a few
/// facts changed on day one (`prepare`) — the cash, a build's bugs, a
/// topic's market, the rules — so no new saves have to be generated and
/// the engine never learns what a scenario is: it plays a resumed state.
struct Scenario: Identifiable, Sendable {
    enum Objective: Sendable {
        /// Make `check` true before the deadline; stars for speed.
        case reachBy
        /// Keep `check` true until the deadline; stars for the money left.
        case holdUntil
    }

    let id: String
    let title: String
    /// The situation, in one or two sentences.
    let brief: String
    /// What has to be true, in the player's words.
    let goal: String
    let fixture: String
    /// Days from the start to the deadline.
    let days: Int
    let objective: Objective
    /// Day-one changes to the fixture. Draws nothing.
    let prepare: @Sendable (inout GameState) -> Void
    /// The objective, against the live state and the state on day one.
    let check: @Sendable (_ state: GameState, _ start: GameState) -> Bool

    var deadlineText: String {
        days % 7 == 0 ? "\(days / 7) weeks" : "\(days) days"
    }
}

/// The ten, in the order the room lists them.
enum ScenarioCatalog {
    static let all: [Scenario] = [
        Scenario(
            id: "turnaround", title: "The turnaround",
            brief: "Day 900. Fourteen people, a campus, a board — and the bank balance of a garage.",
            goal: "Cash of $250,000 within six months.",
            fixture: "release-campus-day900", days: 182, objective: .reachBy,
            prepare: { $0.company.cash = 20_000 },
            check: { state, _ in state.company.cash >= 250_000 }
        ),
        Scenario(
            id: "launch-week", title: "Launch week",
            brief: "A build a week from shipping, and the bug tracker just lit up.",
            goal: "Ship it within three weeks.",
            fixture: "release-studio-day400", days: 21, objective: .reachBy,
            prepare: { state in
                for index in state.products.indices {
                    if case .development(var progress) = state.products[index].stage {
                        progress.openBugs += 40
                        state.products[index].stage = .development(progress)
                    }
                }
            },
            check: { state, start in Self.shippedCount(state) > Self.shippedCount(start) }
        ),
        Scenario(
            id: "empty-chairs", title: "Empty chairs",
            brief: "Three of your people have had enough. Nobody has resigned yet.",
            goal: "Lose nobody for ninety days.",
            fixture: "release-campus-day900", days: 90, objective: .holdUntil,
            prepare: { state in
                let unhappy = state.employees.indices
                    .filter { !state.employees[$0].isFounder }
                    .sorted { state.employees[$0].morale < state.employees[$1].morale }
                    .prefix(3)
                for index in unhappy { state.employees[index].morale = 5 }
            },
            check: { state, start in state.employees.count >= start.employees.count }
        ),
        Scenario(
            id: "the-crash", title: "The crash",
            brief: "Your best market just fell through the floor.",
            goal: "Ship into a different topic within six months.",
            fixture: "release-studio-day400", days: 182, objective: .reachBy,
            prepare: { state in
                guard let topic = Self.bestTopic(state) else { return }
                state.market.topics[topic]?.multiplier = 0.4
            },
            check: { state, start in
                let crashed = Self.bestTopic(start)
                return state.products.contains { (product: Product) -> Bool in
                    guard case .released(let release) = product.stage else { return false }
                    return product.topicID != crashed && release.launchDay > start.day
                }
            }
        ),
        Scenario(
            id: "garage-hard", title: "Garage, hard",
            brief: "Six weeks in, alone, on the hard market.",
            goal: "Ship your first product within sixty days.",
            fixture: "release-garage-day40", days: 60, objective: .reachBy,
            prepare: { $0.difficulty = .hard },
            check: { state, start in Self.shippedCount(state) > Self.shippedCount(start) }
        ),
        Scenario(
            id: "deep-pockets", title: "Deep pockets, no time",
            brief: "Half a million in the bank, one desk, and a clock.",
            goal: "Reach the studio within four months.",
            fixture: "release-garage-day40", days: 120, objective: .reachBy,
            prepare: { $0.company.cash = 500_000 },
            check: { state, _ in state.company.officeTier == .studio || state.company.officeTier == .campus }
        ),
        Scenario(
            id: "the-board", title: "The board",
            brief: "A funded campus and a board that reads the quarterly numbers.",
            goal: "Twelve weeks in the black within four months.",
            fixture: "release-campus-day900", days: 120, objective: .reachBy,
            prepare: { _ in },
            check: { state, start in state.progression.stats.cashPositiveWeeks >= start.progression.stats.cashPositiveWeeks + 12 }
        ),
        Scenario(
            id: "bootstrapped", title: "Bootstrapped",
            brief: "No credit. The bank will not take your call.",
            goal: "Cash of $150,000 within a year, on sales alone.",
            fixture: "release-garage-day40", days: 364, objective: .reachBy,
            prepare: { $0.rules = GameRules(stake: 2) },
            check: { state, _ in state.company.cash >= 150_000 }
        ),
        Scenario(
            id: "the-inheritance", title: "The inheritance",
            brief: "A campus, forty desks, and a founder who has just burned out.",
            goal: "Keep everyone for four months.",
            fixture: "release-campus-day900", days: 120, objective: .holdUntil,
            prepare: { state in
                state.life.meters.energy = 10
                state.life.meters.health = 25
                state.life.meters.mood = 20
            },
            check: { state, start in state.employees.count >= start.employees.count }
        ),
        Scenario(
            id: "copycat-war", title: "The copycat war",
            brief: "The strongest studio in town is coming for your shelf.",
            goal: "Keep your reputation for six months.",
            fixture: "release-studio-day400", days: 182, objective: .holdUntil,
            prepare: { state in
                state.rules = GameRules(stake: 3)
                if let index = state.rivals.rivals.indices.max(by: {
                    state.rivals.rivals[$0].strength < state.rivals.rivals[$1].strength
                }) {
                    state.rivals.rivals[index].strength = 95
                }
            },
            check: { state, start in state.company.reputation >= start.company.reputation - 5 }
        ),
    ]

    static func scenario(_ id: String) -> Scenario? {
        all.first { $0.id == id }
    }

    /// This week's featured scenario — the one with a board. Derived from
    /// the date like the daily, so every phone features the same one.
    static func featured(now: Date = Date()) -> Scenario {
        let week = max(0, DailyChallenge.dayNumber(for: now) / 7)
        return all[week % all.count]
    }

    /// Products that have shipped.
    static func shippedCount(_ state: GameState) -> Int {
        state.products.filter { if case .released = $0.stage { true } else { false } }.count
    }

    /// The topic of the best-reviewed shipped product, or the first topic
    /// any product is in.
    static func bestTopic(_ state: GameState) -> String? {
        let shipped = state.products.compactMap { product -> (String, Double)? in
            guard case .released(let release) = product.stage else { return nil }
            return (product.topicID, release.quality)
        }
        if let best = shipped.max(by: { $0.1 < $1.1 }) { return best.0 }
        return state.products.first?.topicID
    }
}

/// How a scenario ended: won with stars, or lost.
enum ScenarioOutcome: Equatable, Codable {
    case won(stars: Int)
    case lost

    var stars: Int {
        if case .won(let stars) = self { return stars }
        return 0
    }
}

enum ScenarioProgress {
    /// The outcome on `state`, or `nil` while the scenario is still open.
    static func outcome(of scenario: Scenario, state: GameState, start: GameState, startDay: Int) -> ScenarioOutcome? {
        let deadline = startDay + scenario.days
        if state.gameOver != nil { return .lost }
        switch scenario.objective {
        case .reachBy:
            if scenario.check(state, start) {
                let used = state.day - startDay
                let stars = used * 2 <= scenario.days ? 3 : (used * 4 <= scenario.days * 3 ? 2 : 1)
                return .won(stars: stars)
            }
            return state.day >= deadline ? .lost : nil
        case .holdUntil:
            if !scenario.check(state, start) { return .lost }
            guard state.day >= deadline else { return nil }
            let cash = state.company.cash
            let stars = cash >= start.company.cash + 100_000 ? 3 : (cash >= start.company.cash ? 2 : 1)
            return .won(stars: stars)
        }
    }

    /// The board's number: stars first, then the days to spare or the
    /// cash left.
    static func score(_ outcome: ScenarioOutcome, scenario: Scenario, state: GameState, startDay: Int) -> Int {
        guard case .won(let stars) = outcome else { return 0 }
        let extra: Int
        switch scenario.objective {
        case .reachBy: extra = max(0, startDay + scenario.days - state.day)
        case .holdUntil: extra = max(0, min(999, state.company.cash / 1_000))
        }
        return stars * 10_000 + extra
    }
}
