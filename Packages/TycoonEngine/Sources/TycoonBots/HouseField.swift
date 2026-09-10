import Foundation
import TycoonContent
import TycoonEngine

// MARK: J4 (house field)
//
// Iteration 12 — J4. The house: nineteen named founders per league tier
// who play every league week's seed, and a cross-section of them who play
// every daily day's, with the bots the balance suites already measure the
// economy with. Everything here is a pure function of the seed, the
// bundled balance and the roster, so every phone computes the same house
// scores and nothing is fetched. The app runs it off the main actor and
// writes each result as an ordinary `GhostLog`.

/// How a house founder plays: one of the harness's bots.
public enum HouseFieldStrategy: String, Codable, Hashable, Sendable, CaseIterable {
    /// `ContractGrinderBot`.
    case grinder
    /// `BalancedBot`.
    case saver
    /// `SoloSlowBot`.
    case solo
    /// `NeglectfulBot`.
    case crunchBoss
    /// `CrunchHireBot`.
    case blitz
    /// `SaaSBuilderBot`.
    case platform
    /// `InvestorBot`.
    case funded
    /// `InvestorBot.ignoresTheBoard`.
    case deafToTheBoard
    /// `InvestorBot.bootstrapper`.
    case bootstrapper
    /// `InvestorBot.coasts`.
    case coaster
    /// `AcquirerBot`.
    case seller
    /// `BuybackBot`.
    case buyback

    /// The one word the table and the result card call it.
    public var label: String {
        switch self {
        case .grinder: "Grinder"
        case .saver: "Saver"
        case .solo: "Solo"
        case .crunchBoss: "Crunch boss"
        case .blitz: "Blitz"
        case .platform: "Platform"
        case .funded: "Funded"
        case .deafToTheBoard: "Deaf ear"
        case .bootstrapper: "Bootstrapper"
        case .coaster: "Coaster"
        case .seller: "Seller"
        case .buyback: "Buyback"
        }
    }

    /// How they play, in a clause.
    public var style: String {
        switch self {
        case .grinder: "contracts only, never hired"
        case .saver: "contracts until there's $20,000, then one app at a time"
        case .solo: "one app at a time, never hired, never crunched"
        case .crunchBoss: "hires the cheapest, crunches everyone, ships half-done"
        case .blitz: "crunches, hires to the ceiling, pays over the odds"
        case .platform: "researches to SaaS, then lives on subscriptions"
        case .funded: "takes the cheque and plays to the board"
        case .deafToTheBoard: "takes the cheque, never reads the board"
        case .bootstrapper: "turns every cheque down"
        case .coaster: "raises the big round, then stops growing"
        case .seller: "takes the first strategic offer"
        case .buyback: "buys the board out the moment it can"
        }
    }
}

/// One named house founder: a face, a strategy, and the small twists that
/// keep two founders with the same strategy from being one founder twice.
public struct HouseFieldFounder: Codable, Hashable, Sendable, Identifiable {
    /// `"<tier>-<nn>.v<roster version>"`: a slot in a table, for one
    /// version of the roster.
    public var id: String
    public var name: String
    public var strategy: HouseFieldStrategy
    /// Rotates the topics the bot builds in (`BotHelp.topics`).
    public var topicShift: Int
    /// Also takes one weekend a month (`BotHelp.weekendPlan`), for the
    /// bots that do not already.
    public var weekends: Bool
    /// The bot's hiring runway in weeks, where it has one; `nil` is the
    /// bot's own.
    public var runwayWeeks: Int?

    public init(
        id: String, name: String, strategy: HouseFieldStrategy,
        topicShift: Int = 0, weekends: Bool = false, runwayWeeks: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.strategy = strategy
        self.topicShift = topicShift
        self.weekends = weekends
        self.runwayWeeks = runwayWeeks
    }

    /// The face: a stable word off the id, never a draw.
    public var appearanceSeed: UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in "house-\(id)".utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }

    /// "Grinder — contracts only, never hired".
    public var line: String { "\(strategy.label) — \(strategy.style)" }

    /// The bot that plays for them.
    public func bot() -> any BotPolicy {
        let base: any BotPolicy = switch strategy {
        case .grinder: ContractGrinderBot()
        case .saver: BalancedBot()
        case .solo: SoloSlowBot()
        case .crunchBoss: NeglectfulBot()
        case .blitz: CrunchHireBot(hireRunwayWeeks: runwayWeeks ?? 12)
        case .platform: SaaSBuilderBot()
        case .funded: InvestorBot(hireRunwayWeeks: runwayWeeks ?? 12)
        case .deafToTheBoard: InvestorBot(
            name: "ignores-board", hireRunwayWeeks: runwayWeeks ?? 12, playsToTheBoard: false
        )
        case .bootstrapper: InvestorBot(
            name: "bootstrapper", takesTheMoney: false, hireRunwayWeeks: runwayWeeks ?? 12
        )
        case .coaster: InvestorBot(
            name: "coasts", hireRunwayWeeks: runwayWeeks ?? 12, growsAfterFunding: false
        )
        case .seller: AcquirerBot(base: InvestorBot(hireRunwayWeeks: runwayWeeks ?? 12))
        case .buyback: BuybackBot(base: InvestorBot(hireRunwayWeeks: runwayWeeks ?? 12))
        }
        return HouseFieldBot(name: id, base: base, topicShift: topicShift, weekends: weekends)
    }
}

/// A harness bot with the house's two twists on top: the topics rotated,
/// and a weekend a month for a bot that never plans one.
struct HouseFieldBot: BotPolicy {
    let name: String
    let base: any BotPolicy
    let topicShift: Int
    let weekends: Bool

    func actions(
        for state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameAction] {
        var actions = base.actions(for: state, balance: balance, content: content)
        if topicShift != 0 {
            actions = actions.map { action in
                guard case let .startProduct(typeID, topicID, name, focus) = action,
                      let index = BotHelp.topics.firstIndex(of: topicID)
                else { return action }
                let shifted = BotHelp.topics[(index + topicShift) % BotHelp.topics.count]
                return .startProduct(typeID: typeID, topicID: shifted, name: name, focus: focus)
            }
        }
        if weekends, !actions.contains(where: { if case .planWeekend = $0 { true } else { false } }) {
            actions = BotHelp.weekendPlan(state) + actions
        }
        return actions
    }
}

/// Who plays where. Bronze is the harness's one-idea founders, silver the
/// growth bots, gold the funded ones, and the founders' table the best
/// variant of each.
public enum HouseFieldRoster {
    /// House founders in a full table: `LeagueRules.fieldSize` less the
    /// player. Cut this (and only this) to shrink the field.
    public static let fieldSize = LeagueRules.fieldSize - 1

    /// Bumped whenever a table's strategies change, so a phone that filed
    /// a week under the old roster plays it again rather than showing
    /// somebody's name beside somebody else's way of playing.
    public static let version = 1

    // Tuned on the Mac over the eight league weeks before 10 September
    // 2026 (weeks 29–36): 230 variants pooled, each table's strategies
    // chosen so the share of all variants that beat its fourth place
    // falls rung by rung (bronze 0.31, silver 0.27, gold 0.18, founders
    // 0.14 before the bronze and founders hand edits). See the J4 report.

    public static func founders(for tier: LeagueTier) -> [HouseFieldFounder] {
        let all: [HouseFieldFounder] = switch tier {
        case .bronze: bronze
        case .silver: silver
        case .gold: gold
        case .founders: foundersTable
        }
        return Array(all.prefix(fieldSize))
    }

    /// The daily's nineteen: a cross-section of the four tables, the same
    /// people with the same strategies, so the house is one cast.
    public static var daily: [HouseFieldFounder] {
        let picks: [(LeagueTier, [Int])] = [
            (.bronze, [0, 7, 9, 14, 16]),
            (.silver, [0, 4, 6, 11, 15]),
            (.gold, [0, 4, 8, 12, 16]),
            (.founders, [1, 5, 10, 15]),
        ]
        let chosen = picks.flatMap { tier, indices in
            let table = founders(for: tier)
            return indices.filter { $0 < table.count }.map { table[$0] }
        }
        return Array(chosen.prefix(fieldSize))
    }

    /// Every founder in every table, by id.
    public static func founder(id: String) -> HouseFieldFounder? {
        (bronze + silver + gold + foundersTable).first { $0.id == id }
    }

    private static func table(
        _ prefix: String, _ names: [String], _ plays: [(HouseFieldStrategy, Int, Bool, Int?)]
    ) -> [HouseFieldFounder] {
        zip(names, plays).enumerated().map { index, pair in
            let (name, play) = pair
            return HouseFieldFounder(
                id: String(format: "%@-%02d.v%d", prefix, index, version), name: name, strategy: play.0,
                topicShift: play.1, weekends: play.2, runwayWeeks: play.3
            )
        }
    }

    // (strategy, topic shift, weekends, runway weeks)

    static let bronze = table("bronze", [
        "Dale Pruitt", "Mona Keegan", "Otis Wren", "Bea Lindahl", "Hal Dorsey",
        "Tova Brisk", "Ray Quinlan", "Iris Mbeki", "Gus Tamm", "Lena Voss",
        "Abe Kowal", "Nell Farago", "Cy Oduya", "Wynn Hale", "Pia Sorensen",
        "Lou Vargas", "Edie Marsh", "Nico Brandt", "Fay Ossai",
    ], [
        (.solo, 0, false, nil), (.solo, 1, false, nil), (.solo, 0, true, nil),
        (.solo, 2, false, nil), (.solo, 3, true, nil), (.solo, 5, true, nil), (.solo, 3, false, nil),
        (.grinder, 0, false, nil), (.grinder, 0, true, nil),
        (.saver, 4, true, nil), (.saver, 5, true, nil), (.saver, 5, false, nil),
        (.saver, 3, true, nil), (.saver, 4, false, nil),
        (.crunchBoss, 5, false, nil), (.crunchBoss, 1, false, nil), (.crunchBoss, 2, false, nil),
        (.crunchBoss, 4, false, nil), (.crunchBoss, 5, true, nil),
    ])

    static let silver = table("silver", [
        "Rune Adeyemi", "Petra Vaszary", "Kit Okafor", "Sol Marchetti", "Ines Halloran",
        "Dov Bergström", "Nina Achebe", "Casper Lund", "Wren Ferreira", "Otto Salveson",
        "June Baptiste", "Milo Kranz", "Anouk Reyes", "Tariq Novak", "Signe Ahn",
        "Bram Castell", "Leila Ruiz", "Joss Whitlow", "Mina Oyelaran",
    ], [
        (.platform, 0, false, nil), (.platform, 5, false, nil), (.platform, 4, false, nil),
        (.platform, 3, false, nil),
        (.blitz, 5, false, 20), (.blitz, 5, false, 9), (.blitz, 5, false, 16), (.blitz, 3, false, nil),
        (.blitz, 5, false, nil), (.blitz, 1, false, 20), (.blitz, 3, false, 9), (.blitz, 0, false, nil),
        (.blitz, 4, false, 20), (.blitz, 3, false, 16), (.blitz, 0, false, 26), (.blitz, 2, false, 9),
        (.blitz, 0, false, 20), (.blitz, 4, false, 16), (.blitz, 1, false, nil),
    ])

    static let gold = table("gold", [
        "Ada Kerrigan", "Viktor Sato", "Priya Lindqvist", "Hugo Mensah", "Odile Park",
        "Emeka Strand", "Saskia Moreau", "Theo Nakamura", "Yara Haddad", "Felix Obi",
        "Greta Holm", "Ravi Castellano", "Mei Fontaine", "Jonah Adler", "Zuri Kamau",
        "Pascal Weiss", "Inga Soto", "Arlo Benedek", "Noor Qasim",
    ], [
        (.seller, 4, false, 9), (.deafToTheBoard, 4, false, 9), (.deafToTheBoard, 5, false, 9),
        (.seller, 0, false, 9), (.bootstrapper, 0, false, nil), (.seller, 5, false, 9),
        (.deafToTheBoard, 0, false, 9), (.buyback, 5, false, 9), (.funded, 5, false, nil),
        (.funded, 5, false, 9), (.buyback, 2, false, 20), (.seller, 4, false, nil),
        (.buyback, 3, false, 20), (.buyback, 4, false, 16), (.buyback, 4, false, 26),
        (.bootstrapper, 0, false, 26), (.deafToTheBoard, 4, false, nil), (.buyback, 1, false, 9),
        (.buyback, 3, false, nil),
    ])

    static let foundersTable = table("founders", [
        "Magnus Ekwueme", "Celeste Varga", "Idris Hartmann", "Solveig Abara", "Lucian Mori",
        "Farah Delacroix", "Oren Blackwood", "Tamsin Oyelowo", "Kenji Albrecht", "Marisol Ekdahl",
        "Anselm Greer", "Delphine Okoro", "Stellan Ruiz", "Amara Lindgren", "Cormac Asante",
        "Liesel Nakashima", "Dmitri Achterberg", "Esme Valdivia", "Tobias Nwosu",
    ], [
        (.seller, 4, false, 9), (.bootstrapper, 0, false, 9), (.buyback, 5, false, 20),
        (.deafToTheBoard, 5, false, nil), (.deafToTheBoard, 4, false, 9), (.funded, 4, false, 9),
        (.bootstrapper, 5, false, 9), (.deafToTheBoard, 5, false, 20), (.deafToTheBoard, 5, false, 9),
        (.seller, 5, false, 20), (.bootstrapper, 3, false, 20), (.seller, 0, false, 9),
        (.bootstrapper, 5, false, 16), (.solo, 0, false, nil), (.funded, 5, false, 20),
        (.buyback, 4, false, 9), (.seller, 5, false, 9), (.funded, 0, false, 9),
        (.blitz, 5, false, 20),
    ])
}

/// The company a house founder founds: exactly the player's — the same
/// seed, origin, difficulty, founder, name and mode — with no ghosts in
/// it, so every phone founds the same world.
public struct HouseFieldSetup: Codable, Hashable, Sendable {
    public var seed: UInt64
    public var origin: FoundingOrigin
    public var difficulty: Difficulty
    public var mode: RunMode
    public var companyName: String
    public var founderName: String
    public var founderAppearanceSeed: UInt64
    public var horizonDays: Int

    public init(
        seed: UInt64, origin: FoundingOrigin, difficulty: Difficulty, mode: RunMode,
        companyName: String, founderName: String, founderAppearanceSeed: UInt64,
        horizonDays: Int = LeagueWeek.horizonDays
    ) {
        self.seed = seed
        self.origin = origin
        self.difficulty = difficulty
        self.mode = mode
        self.companyName = companyName
        self.founderName = founderName
        self.founderAppearanceSeed = founderAppearanceSeed
        self.horizonDays = horizonDays
    }
}

/// What one house founder walked away with.
public struct HouseFieldResult: Codable, Hashable, Sendable {
    public var founder: HouseFieldFounder
    /// `GameState.founderNetWorth` at the horizon (or the ending) — the
    /// number the league, the daily and the season all score.
    public var finalNetWorth: Int
    public var launches: [GhostLaunch]
    public var ending: EndingKind?
    public var daysRun: Int
}

public enum HouseFieldRun {
    /// Plays one founder through `setup` to the horizon. Pure: the same
    /// founder, setup and bundled balance give the same result anywhere.
    public static func play(
        _ founder: HouseFieldFounder,
        setup: HouseFieldSetup,
        bundled: BalanceConfig,
        content: ContentCatalog
    ) -> HouseFieldResult {
        // `GameEngine.newGame`'s own order: difficulty, then the rules.
        let balance = bundled.adjusted(for: setup.difficulty).applying(GameRules.standard)
        let profile = FounderProfile(
            name: setup.founderName, archetype: .hacker,
            appearanceSeed: setup.founderAppearanceSeed, usesArchetypeSkills: false
        )
        let start = GameState.newGame(
            companyName: setup.companyName, seed: setup.seed, balance: balance,
            difficulty: setup.difficulty, founder: profile, origin: setup.origin,
            content: content, mode: setup.mode
        )
        let run = SimRunner.run(
            from: start, days: max(0, setup.horizonDays - start.day),
            bot: founder.bot(), balance: balance, content: content
        )
        let launches = run.state.products.compactMap { product -> GhostLaunch? in
            guard case .released(let release) = product.stage else { return nil }
            // The review average, the way the app's ghosts record it.
            let score = release.reviews.isEmpty
                ? Int(release.quality.rounded())
                : release.reviews.reduce(0) { $0 + $1.score } / release.reviews.count
            return GhostLaunch(
                day: release.launchDay, topicID: product.topicID, typeID: product.typeID,
                name: product.name, quality: Double(score)
            )
        }
        return HouseFieldResult(
            founder: founder,
            finalNetWorth: run.state.founderNetWorth(balance: balance),
            launches: launches,
            ending: run.endingKind,
            daysRun: run.daysRun
        )
    }
}

// MARK: end J4
