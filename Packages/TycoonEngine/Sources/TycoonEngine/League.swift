import Foundation

// Iteration 10 — M4 owns this file and may reshape it freely. Weekly
// leagues on one seed with promotion and relegation, and "Beat my
// company" challenges carried by a seed code plus a year grid. The run
// side is `RunMode.league(week:)` (M4's marker in `RunMode.swift`); the
// standings and the tier live in the ledger (M4's markers in
// `Legacy.swift`) and in the app.
//
// Everything here is pure. A week's world is a function of the week
// number alone, the way `DailyChallenge` is a function of the day, so
// two phones in the same week found the same company with no server in
// the middle; the tier and the table are functions of the scores the app
// hands in, so promotion is computed on the client from a recurring
// leaderboard (or, signed out, from the ghost field) and nothing is
// collected.

// MARK: - The week

/// The company a whole tier founds for one calendar week.
///
/// Weeks run Monday to Sunday UTC. `DailyChallenge.epoch` (2026-01-01) is
/// a Thursday, so the week index is `floor((day + 3) / 7)`: week 0 is the
/// week that epoch fell in, week 1 starts Monday 5 January 2026.
public struct LeagueWeek: Codable, Equatable, Hashable, Sendable {
    /// Weeks since the epoch's own week, 0-based.
    public var week: Int
    public var seed: UInt64
    public var origin: FoundingOrigin
    public var difficulty: Difficulty

    public init(week: Int, seed: UInt64, origin: FoundingOrigin = .garage, difficulty: Difficulty = .normal) {
        self.week = week
        self.seed = seed
        self.origin = origin
        self.difficulty = difficulty
    }

    public static let daysPerWeek = 7

    /// The horizon a league run is scored at: one game year, the daily's
    /// rule, so the week's table compares like with like.
    public static let horizonDays = GameState.daysPerYear

    /// The world week `n` deals. Pure, and pinned by the shape the daily
    /// and the season already use: one discarded draw, then the seed.
    public static func forWeek(_ n: Int) -> LeagueWeek {
        var rng = SeededRNG(seed: UInt64(bitPattern: Int64(n)) ^ 0x1EA6_0E5E_ED00_0001)
        _ = rng.next()
        let seed = rng.next()
        let origins = FoundingOrigin.allCases
        let difficulties = Difficulty.allCases
        return LeagueWeek(
            week: n,
            seed: seed,
            origin: origins[Int(seed % UInt64(origins.count))],
            difficulty: difficulties[Int((seed >> 8) % UInt64(difficulties.count))]
        )
    }

    /// The week index a daily day number falls in.
    public static func weekNumber(forDay day: Int) -> Int {
        let shifted = day + 3
        return shifted >= 0 ? shifted / daysPerWeek : -((-shifted + daysPerWeek - 1) / daysPerWeek)
    }

    /// The week index a wall-clock instant falls in, in UTC.
    public static func weekNumber(for date: Date) -> Int {
        weekNumber(forDay: DailyChallenge.dayNumber(for: date))
    }

    /// This week's league.
    public static func current(now: Date = Date()) -> LeagueWeek {
        forWeek(weekNumber(for: now))
    }

    /// The daily day number the week's Monday falls on.
    public var firstDayNumber: Int { week * Self.daysPerWeek - 3 }

    /// The Monday the week opens on, 00:00 UTC.
    public var firstDay: Date {
        DailyChallenge.epoch.addingTimeInterval(TimeInterval(firstDayNumber) * 86_400)
    }

    /// The last instant of the week's Sunday.
    public var lastDay: Date {
        firstDay.addingTimeInterval(TimeInterval(Self.daysPerWeek) * 86_400 - 1)
    }

    /// Whole days left in the week from `now`, 0 on the last day.
    public func daysLeft(now: Date = Date()) -> Int {
        max(0, firstDayNumber + Self.daysPerWeek - DailyChallenge.dayNumber(for: now))
    }

    /// The code that founds this week's company on any phone.
    public var seedCode: SeedCode {
        SeedCode(seed: seed, origin: origin, difficulty: difficulty)
    }
}

// MARK: - The tiers

/// The four rungs a player climbs. Everyone starts in bronze; the top of
/// a tier goes up, the bottom goes down, and the founders' tier has
/// nowhere left to climb.
public enum LeagueTier: String, Codable, CaseIterable, Sendable, Comparable {
    case bronze, silver, gold, founders

    public var index: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    public static func < (lhs: LeagueTier, rhs: LeagueTier) -> Bool { lhs.index < rhs.index }

    public var displayName: String {
        switch self {
        case .bronze: "Bronze"
        case .silver: "Silver"
        case .gold: "Gold"
        case .founders: "Founders"
        }
    }

    /// One line for the card: what this rung is.
    public var blurb: String {
        switch self {
        case .bronze: "Where everybody starts. Finish in the top four and you go up."
        case .silver: "The second rung. Four up, four down, every Monday."
        case .gold: "One rung from the top. The bottom four go back to silver."
        case .founders: "The top table. Nothing above it — only the fall."
        }
    }

    /// The rung above, or `nil` at the top.
    public var promoted: LeagueTier? {
        Self.allCases.indices.contains(index + 1) ? Self.allCases[index + 1] : nil
    }

    /// The rung below, or `nil` at the bottom.
    public var relegated: LeagueTier? {
        index > 0 ? Self.allCases[index - 1] : nil
    }
}

/// What a finished week did to the player's tier.
public enum LeagueOutcome: String, Codable, Sendable {
    /// Top of the table: up a tier (or held at the top).
    case promoted
    /// The middle: the same tier next week.
    case held
    /// The bottom: down a tier (or held at the bottom).
    case relegated
    /// The week was never played, or there was no table to place in.
    case unplaced

    public var headline: String {
        switch self {
        case .promoted: "Promoted"
        case .held: "Held your place"
        case .relegated: "Relegated"
        case .unplaced: "Unplaced"
        }
    }
}

/// How a week's table is read. No server decides any of this: the app
/// hands in the tier's scores and these rules say what happened.
public enum LeagueRules {
    /// The field a tier is meant to hold. The table is read against the
    /// scores that actually turned up, so a thinner week still settles.
    public static let fieldSize = 20
    /// The top four go up.
    public static let promotionPlaces = 4
    /// The bottom four go down.
    public static let relegationPlaces = 4

    /// How many places go up in a field of `fieldSize`. A small field
    /// never promotes and relegates the same player: at most half the
    /// field minus one goes either way.
    public static func promoting(in fieldSize: Int) -> Int {
        guard fieldSize > 1 else { return 0 }
        return max(1, min(promotionPlaces, (fieldSize - 1) / 2))
    }

    /// How many places go down in a field of `fieldSize`.
    public static func relegating(in fieldSize: Int) -> Int {
        guard fieldSize > 1 else { return 0 }
        return max(1, min(relegationPlaces, (fieldSize - 1) / 2))
    }

    /// What finishing `rank` of `fieldSize` means.
    public static func outcome(rank: Int, fieldSize: Int) -> LeagueOutcome {
        guard rank >= 1, rank <= fieldSize else { return .unplaced }
        guard fieldSize > 1 else { return .held }
        if rank <= promoting(in: fieldSize) { return .promoted }
        if rank > fieldSize - relegating(in: fieldSize) { return .relegated }
        return .held
    }
}

// MARK: - The table

/// One row of a tier's week: who, what they were worth at the horizon,
/// and whether it is you.
public struct LeagueStanding: Equatable, Sendable, Identifiable {
    public var name: String
    public var score: Int
    public var isYou: Bool

    public init(name: String, score: Int, isYou: Bool = false) {
        self.name = name
        self.score = score
        self.isYou = isYou
    }

    public var id: String { "\(name)#\(score)#\(isYou)" }
}

/// The week's table, built from whatever scores the app could find: the
/// tier's recurring leaderboard when Game Center is there, the week's
/// ghost field when it is not.
public enum LeagueTable {
    /// The rows sorted best first, with the player's own row folded in.
    /// A tie puts the player above the row they tied with — the table is
    /// theirs to read, and a tie is not a relegation.
    public static func standings(you: String, score: Int?, others: [LeagueStanding]) -> [LeagueStanding] {
        var rows = others.map { LeagueStanding(name: $0.name, score: $0.score, isYou: false) }
        if let score {
            rows.removeAll { $0.name == you }
            rows.append(LeagueStanding(name: you, score: score, isYou: true))
        }
        return rows.sorted { left, right in
            if left.score != right.score { return left.score > right.score }
            if left.isYou != right.isYou { return left.isYou }
            return left.name < right.name
        }
    }

    /// Where the player came in the sorted table, 1-based; `nil` when
    /// they are not in it.
    public static func rank(inStandings standings: [LeagueStanding]) -> Int? {
        standings.firstIndex(where: \.isYou).map { $0 + 1 }
    }

    /// "3rd of 20", the way the ghosts already read.
    public static func placeText(rank: Int, fieldSize: Int) -> String {
        let suffix: String = switch (rank % 100, rank % 10) {
        case (11, _), (12, _), (13, _): "th"
        case (_, 1): "st"
        case (_, 2): "nd"
        case (_, 3): "rd"
        default: "th"
        }
        return "\(rank)\(suffix) of \(fieldSize)"
    }
}

// MARK: - The ledger's record

/// What the ledger remembers about the player's league: which rung they
/// are on, the last week that settled, and how it went.
///
/// Absent on a ledger from before iteration 10, and it decodes as a
/// bronze player who has never played (`LeagueRecord()` is the default).
public struct LeagueRecord: Codable, Equatable, Sendable {
    public var tier: LeagueTier
    /// The last week whose table was read and applied. `nil` before the
    /// first one settles.
    public var settledWeek: Int?
    /// Where the player came in that week, 1-based; 0 when unplaced.
    public var lastRank: Int
    /// How big the field was that week.
    public var lastFieldSize: Int
    public var lastOutcome: LeagueOutcome
    /// The highest rung ever held, for the card's one boast.
    public var bestTier: LeagueTier
    /// How many league weeks have been played at all.
    public var weeksPlayed: Int

    public init(
        tier: LeagueTier = .bronze,
        settledWeek: Int? = nil,
        lastRank: Int = 0,
        lastFieldSize: Int = 0,
        lastOutcome: LeagueOutcome = .unplaced,
        bestTier: LeagueTier = .bronze,
        weeksPlayed: Int = 0
    ) {
        self.tier = tier
        self.settledWeek = settledWeek
        self.lastRank = lastRank
        self.lastFieldSize = lastFieldSize
        self.lastOutcome = lastOutcome
        self.bestTier = bestTier
        self.weeksPlayed = weeksPlayed
    }

    public static let starting = LeagueRecord()

    /// The record after a week's table settled: the tier moves, the best
    /// is remembered, and the week is marked so it never settles twice.
    public func settling(week: Int, rank: Int, fieldSize: Int) -> LeagueRecord {
        var copy = self
        let outcome = LeagueRules.outcome(rank: rank, fieldSize: fieldSize)
        copy.settledWeek = week
        copy.lastRank = rank
        copy.lastFieldSize = fieldSize
        copy.lastOutcome = outcome
        switch outcome {
        case .promoted: copy.tier = tier.promoted ?? tier
        case .relegated: copy.tier = tier.relegated ?? tier
        case .held, .unplaced: break
        }
        copy.bestTier = max(copy.bestTier, copy.tier)
        return copy
    }

    /// The record after a week was played (before it settles).
    public func played() -> LeagueRecord {
        var copy = self
        copy.weeksPlayed += 1
        return copy
    }

    /// One line under the tier on the card.
    public var lastWeekLine: String? {
        guard settledWeek != nil, lastRank > 0 else { return nil }
        return "Last week: \(LeagueTable.placeText(rank: lastRank, fieldSize: lastFieldSize)) · \(lastOutcome.headline)."
    }
}

// MARK: - Beat my company

/// A challenge one player hands another: the seed that founds their
/// company, the year they had, and what they walked away with.
///
/// The wire form is one line a player can paste anywhere:
///
///     BEAT1|SS1-XXXXXXXX-XXXXXXXX-X|ULUQQDDR…|184500|Mira
///
/// — the marker, the seed code, the year grid in letters (M4's marked
/// region in `YearGrid` maps squares to letters and back), the score as a
/// decimal, and the challenger's name last, so a name with anything odd
/// in it cannot break the fields before it. Nothing here draws, so the
/// same link founds the same company on both phones.
public struct LeagueChallenge: Equatable, Sendable, Identifiable {
    public var code: SeedCode
    /// The year grid in letters (`YearGrid.Square` ↔ letters, app side).
    public var grid: String
    public var score: Int
    public var challenger: String

    public init(code: SeedCode, grid: String, score: Int, challenger: String) {
        self.code = code
        self.grid = grid
        self.score = score
        self.challenger = Self.cleaned(challenger)
    }

    public var id: String { encoded }

    /// The marker every challenge line starts with.
    public static let marker = "BEAT1"
    public static let separator: Character = "|"
    /// Names are trimmed to this on the way in and out; a challenge is a
    /// link, not a profile.
    public static let nameLimit = 24
    /// The letters a grid may be spelled with, so a decode can refuse a
    /// line somebody typed over.
    public static let gridAlphabet = Set("ULCRQD")

    public var encoded: String {
        [Self.marker, code.encoded, grid, "\(score)", challenger]
            .joined(separator: String(Self.separator))
    }

    /// Parses a challenge line; `nil` on a bad marker, a bad code, a grid
    /// with a letter that is not one of ours, or a score that is not a
    /// number.
    public static func decode(_ text: String) -> LeagueChallenge? {
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = line.split(separator: separator, maxSplits: 4, omittingEmptySubsequences: false)
        guard parts.count == 5, parts[0].uppercased() == marker else { return nil }
        guard let code = SeedCode.decode(String(parts[1])) else { return nil }
        let grid = parts[2].uppercased()
        guard grid.allSatisfy({ gridAlphabet.contains($0) }) else { return nil }
        guard let score = Int(parts[3].trimmingCharacters(in: .whitespaces)) else { return nil }
        return LeagueChallenge(
            code: code, grid: String(grid), score: score, challenger: String(parts[4])
        )
    }

    /// The name as a challenge carries it: no separators, no newlines, no
    /// more than `nameLimit` characters, and never empty.
    public static func cleaned(_ name: String) -> String {
        let stripped = name
            .replacingOccurrences(of: String(separator), with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
        let short = String(stripped.prefix(nameLimit)).trimmingCharacters(in: .whitespaces)
        return short.isEmpty ? "A founder" : short
    }
}
