import Foundation

// MARK: Iteration 7 — per-run rules, modes and the epilogue

/// What kind of run this is. Everything a run *is* — its seed, origin and
/// difficulty — lives on `GameState` already; the mode says how it was
/// entered, which decides what it may post.
///
/// - `standard`: a company founded from the new-game flow, ranked.
/// - `custom`: a typed seed or a non-standard `GameRules` (R4). Earns
///   achievements, never posts to a leaderboard.
/// - `daily(day:)`: the shared company of one UTC day (R3), played in its
///   own store, scored at a fixed horizon.
public enum RunMode: Codable, Equatable, Hashable, Sendable {
    case standard
    case custom
    case daily(day: Int)
    /// Iteration 8: an authored start with an objective and a deadline
    /// (`id` names it; `startDay` is the fixture's day when it began).
    case scenario(id: String, startDay: Int)

    /// Whether an ending in this mode may post to the ranked boards. An
    /// heirloom (R2) makes a standard run unranked too; that check lives
    /// with the state, see `GameState.isRanked`.
    public var isRanked: Bool {
        switch self {
        case .standard, .daily: true
        case .custom, .scenario: false
        }
    }

    public var isDaily: Bool {
        if case .daily = self { return true }
        return false
    }

    public var isScenario: Bool {
        if case .scenario = self { return true }
        return false
    }
}

/// Per-run overrides a custom company (R4) can set. Applied to the balance
/// exactly the way `Difficulty` is — once, in `GameEngine.newGame` and
/// `resume`, after `adjusted(for:)` — so the engine's numbers are never
/// touched and `.standard` is the identity by construction (asserted in
/// `ScaffoldContractTests`).
public struct GameRules: Codable, Equatable, Hashable, Sendable {
    /// Off: the field is founded empty and stays empty (`rivals.rivalCount = 0`).
    public var rivalsEnabled: Bool
    /// Off: the deep-pockets giant never founds (`rivals.depth.incumbentEnabled = false`).
    public var incumbentEnabled: Bool
    /// A starting balance instead of the difficulty's own. `nil` keeps it.
    public var startingCash: Int?
    /// Iteration 8: the stake, 0–10 (`StakeLadder`). Saves from before
    /// stakes decode as 0.
    public var stake: Int

    public init(
        rivalsEnabled: Bool = true, incumbentEnabled: Bool = true, startingCash: Int? = nil,
        stake: Int = 0
    ) {
        self.rivalsEnabled = rivalsEnabled
        self.incumbentEnabled = incumbentEnabled
        self.startingCash = startingCash
        self.stake = min(max(0, stake), StakeLadder.count)
    }

    public static let standard = GameRules()

    public var isStandard: Bool { self == .standard }

    /// Standard in everything but the stake: still ranked, the way a
    /// harder difficulty is.
    public var isStakeOnly: Bool {
        stake > 0 && GameRules(stake: stake) == self
    }

    private enum CodingKeys: String, CodingKey {
        case rivalsEnabled, incumbentEnabled, startingCash, stake
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            rivalsEnabled: try container.decodeIfPresent(Bool.self, forKey: .rivalsEnabled) ?? true,
            incumbentEnabled: try container.decodeIfPresent(Bool.self, forKey: .incumbentEnabled) ?? true,
            startingCash: try container.decodeIfPresent(Int.self, forKey: .startingCash),
            stake: try container.decodeIfPresent(Int.self, forKey: .stake) ?? 0
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rivalsEnabled, forKey: .rivalsEnabled)
        try container.encode(incumbentEnabled, forKey: .incumbentEnabled)
        try container.encodeIfPresent(startingCash, forKey: .startingCash)
        if stake > 0 {
            try container.encode(stake, forKey: .stake)
        }
    }
}

extension BalanceConfig {
    /// The balance with `rules` applied. Identity for `.standard`.
    public func applying(_ rules: GameRules) -> BalanceConfig {
        guard !rules.isStandard else { return self }
        var copy = self
        if !rules.rivalsEnabled {
            copy.rivals.rivalCount = 0
        }
        if !rules.incumbentEnabled {
            copy.rivals.depth.incumbentEnabled = false
        }
        if let cash = rules.startingCash {
            copy.startingCash = cash
        }
        StakeLadder.apply(level: rules.stake, to: &copy)
        return copy
    }
}

/// Set when the founder kept running the company after an ending that
/// let them (R5: IPO, *Still yours*). With an epilogue set the run has no
/// board, no term sheets and no buyout offers; everything else carries on
/// and bankruptcy is still possible.
public struct Epilogue: Codable, Equatable, Hashable, Sendable {
    /// The ending the company played past.
    public var ending: EndingKind
    /// The day the founder chose to keep going.
    public var day: Int

    public init(ending: EndingKind, day: Int) {
        self.ending = ending
        self.day = day
    }
}
