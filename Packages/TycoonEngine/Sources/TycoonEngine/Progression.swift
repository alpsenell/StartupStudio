import Foundation

// MARK: - Founder identity

/// The founder's starting identity, chosen in the new-game flow.
///
/// The profile is fixed for the life of a run: it names the founder
/// `Employee`, pins their pixel-art look, and picks the archetype whose
/// skill spread they start with. `ProgressionState.founder` keeps it so
/// every later screen (the goals card, the board room, the closing
/// biography) can speak to the person the player made.
public struct FounderProfile: Codable, Equatable, Sendable {
    public var name: String
    public var archetype: FounderArchetype
    /// Pins the founder's pixel-art look. `nil` draws it from the game's
    /// seeded RNG, which is what every game did before archetypes existed.
    public var appearanceSeed: UInt64?
    /// Whether the archetype's skill spread applies at new game.
    ///
    /// `true` for every profile a player builds in the new-game flow — the
    /// point of choosing an archetype is to start with its skills. `false`
    /// only for `.default`, the nameless founder handed to callers that
    /// never asked a question (the balance harness bots, a "New game" with
    /// no setup step): they keep the balance's flat founder skills, so an
    /// unattended run is byte-identical to the pre-archetype game.
    public var usesArchetypeSkills: Bool

    public init(
        name: String,
        archetype: FounderArchetype,
        appearanceSeed: UInt64? = nil,
        usesArchetypeSkills: Bool = true
    ) {
        self.name = name
        self.archetype = archetype
        self.appearanceSeed = appearanceSeed
        self.usesArchetypeSkills = usesArchetypeSkills
    }

    /// The nameless default founder: a hacker called "Founder" whose
    /// appearance is drawn from the game seed. What a save written before
    /// profiles existed reads as, and what `GameEngine.newGame` uses when
    /// the caller offers no choice.
    public static let `default` = FounderProfile(
        name: "Founder", archetype: .hacker, appearanceSeed: nil,
        usesArchetypeSkills: false
    )

    /// The starting skills this profile's founder gets: the archetype's
    /// spread from the balance, or `fallback` (the balance's flat founder
    /// skills) for the default founder and for an archetype the balance
    /// does not list.
    public func startingSkills(
        balance: BalanceConfig, fallback: SkillSet
    ) -> SkillSet {
        guard usesArchetypeSkills else { return fallback }
        return balance.progression.founderSkills(for: archetype, fallback: fallback)
    }

    /// The name with surrounding whitespace trimmed, falling back to
    /// "Founder" when the player left the field empty.
    public var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? FounderProfile.default.name : trimmed
    }
}

/// What the founder is good at. The archetype sets the starting skill
/// spread (roughly 100 points however it is split, so no archetype is
/// strictly stronger) and colors the opening of the run: a hacker's first
/// build is fast and ugly, a designer's is pretty and late, a hustler's
/// sells before it works.
public enum FounderArchetype: String, Codable, Equatable, Sendable, CaseIterable {
    case hacker, designer, hustler

    public var displayName: String {
        switch self {
        case .hacker: "Hacker"
        case .designer: "Designer"
        case .hustler: "Hustler"
        }
    }

    /// One line of character for the archetype picker.
    public var blurb: String {
        switch self {
        case .hacker: "You ship code at 2am. Design can wait; the build can't."
        case .designer: "You sweat every pixel. It will be beautiful, and it will be late."
        case .hustler: "You sold it before you built it. Now somebody has to build it."
        }
    }

    /// SF Symbol used by the archetype picker and the founder biography.
    public var systemImageName: String {
        switch self {
        case .hacker: "chevron.left.forwardslash.chevron.right"
        case .designer: "paintbrush.pointed.fill"
        case .hustler: "megaphone.fill"
        }
    }

    /// The strongest of the three skills, for one-line summaries.
    public var headlineSkill: String {
        switch self {
        case .hacker: "Coding"
        case .designer: "Design"
        case .hustler: "Marketing"
        }
    }
}

// MARK: - Goals

/// One active goal, ready to render: title, one-line detail, and how far
/// along the player is. Persisted inside `ProgressionState` (refreshed
/// every day by `ProgressionSystem`) so the UI never has to re-evaluate
/// conditions or reach into the content catalog.
public struct GoalProgress: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var detail: String
    /// How far along, in the condition's own units (already clamped to
    /// `0...target`).
    public var progress: Double
    /// What `progress` has to reach. Always > 0.
    public var target: Double
    /// 1-based chapter the goal belongs to.
    public var chapter: Int

    public init(
        id: String, title: String, detail: String,
        progress: Double, target: Double, chapter: Int
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.progress = progress
        self.target = target
        self.chapter = chapter
    }

    /// 0...1 completion, safe against a zero target.
    public var fraction: Double {
        guard target > 0 else { return 0 }
        return min(1, max(0, progress / target))
    }

    /// "2 / 3" for counted goals, "$40,000 / $150,000" is left to the UI —
    /// this is the plain numeric form the card shows.
    public var countLabel: String {
        "\(Self.trim(progress)) / \(Self.trim(target))"
    }

    private static func trim(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value.rounded())) : String(format: "%.1f", value)
    }
}

/// A permanent bonus earned by finishing a goal. Perks never expire and
/// never stack with themselves — `ProgressionState.perks` is a set.
public enum ProgressionPerk: String, Codable, Equatable, Sendable, CaseIterable {
    /// Journalists take your calls: every marketing campaign generates
    /// extra hype.
    case pressContacts
    /// Word gets around: candidates arrive a little more skilled.
    case talentMagnet
    /// You know which partner to email: investor offers arrive sooner.
    case investorRolodex
    /// Your crew has been through it: everyone's morale floor is higher.
    case veteranCrew
    /// A reputation for shipping: rivals think twice before a price war.
    case marketDarling

    public var displayName: String {
        switch self {
        case .pressContacts: "Press Contacts"
        case .talentMagnet: "Talent Magnet"
        case .investorRolodex: "Investor Rolodex"
        case .veteranCrew: "Veteran Crew"
        case .marketDarling: "Market Darling"
        }
    }

    public var blurb: String {
        switch self {
        case .pressContacts: "Campaigns generate extra hype."
        case .talentMagnet: "Candidates show up more skilled."
        case .investorRolodex: "Investors come knocking sooner."
        case .veteranCrew: "Everyone's morale sits a little higher."
        case .marketDarling: "Rivals think twice before starting a price war."
        }
    }

    public var systemImageName: String {
        switch self {
        case .pressContacts: "newspaper.fill"
        case .talentMagnet: "sparkles"
        case .investorRolodex: "book.closed.fill"
        case .veteranCrew: "shield.lefthalf.filled"
        case .marketDarling: "star.fill"
        }
    }
}

/// Monotonic run counters that no other part of the state records.
///
/// Every field only ever grows, and every field is written by
/// `ProgressionSystem` from state it can see at the end of a day (or, for
/// the two acquisition/round counters, by the system that performs the
/// action). Keeping them here means goal conditions never have to scan a
/// capped log.
public struct ProgressionStats: Codable, Equatable, Sendable {
    /// Largest headcount (founder included) the company ever reached.
    public var peakHeadcount: Int
    /// Distinct departments that have ever been staffed.
    public var departmentsEverFormed: Int
    /// Contracts ever accepted.
    public var contractsAccepted: Int
    /// Contracts ever settled (delivered or failed).
    public var contractsSettled: Int
    /// Weeks that ended with cash above zero.
    public var cashPositiveWeeks: Int
    /// Weekends actually spent on something other than resting.
    public var weekendsOff: Int
    /// Market crashes that happened while the company was trading.
    public var crashesWeathered: Int
    /// Marketing campaigns ever started.
    public var campaignsRun: Int
    /// Rival studios bought outright.
    public var rivalsAcquired: Int
    /// Funding rounds closed.
    public var roundsRaised: Int
    /// Best average review score of any shipped product.
    public var bestReviewScore: Int
    /// Highest lifetime revenue of any single product.
    public var bestProductRevenue: Int
    /// Topics where the player's share beat every rival for a full week.
    public var topicsDominated: Int
    /// The day the last contract count was taken, so the daily sweep only
    /// counts each contract once.
    public var lastContractScanDay: Int

    public init(
        peakHeadcount: Int = 1,
        departmentsEverFormed: Int = 0,
        contractsAccepted: Int = 0,
        contractsSettled: Int = 0,
        cashPositiveWeeks: Int = 0,
        weekendsOff: Int = 0,
        crashesWeathered: Int = 0,
        campaignsRun: Int = 0,
        rivalsAcquired: Int = 0,
        roundsRaised: Int = 0,
        bestReviewScore: Int = 0,
        bestProductRevenue: Int = 0,
        topicsDominated: Int = 0,
        lastContractScanDay: Int = 0
    ) {
        self.peakHeadcount = peakHeadcount
        self.departmentsEverFormed = departmentsEverFormed
        self.contractsAccepted = contractsAccepted
        self.contractsSettled = contractsSettled
        self.cashPositiveWeeks = cashPositiveWeeks
        self.weekendsOff = weekendsOff
        self.crashesWeathered = crashesWeathered
        self.campaignsRun = campaignsRun
        self.rivalsAcquired = rivalsAcquired
        self.roundsRaised = roundsRaised
        self.bestReviewScore = bestReviewScore
        self.bestProductRevenue = bestProductRevenue
        self.topicsDominated = topicsDominated
        self.lastContractScanDay = lastContractScanDay
    }

    public static let initial = ProgressionStats()
}

// MARK: - Codable

// Hand-written so every counter decodes with `decodeIfPresent`: a save
// written before a counter existed reads it as its fresh-run value instead
// of failing to load.

extension ProgressionStats {
    private enum CodingKeys: String, CodingKey {
        case peakHeadcount, departmentsEverFormed, contractsAccepted, contractsSettled
        case cashPositiveWeeks, weekendsOff, crashesWeathered, campaignsRun
        case rivalsAcquired, roundsRaised, bestReviewScore, bestProductRevenue
        case topicsDominated, lastContractScanDay
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            peakHeadcount: try container.decodeIfPresent(Int.self, forKey: .peakHeadcount) ?? 1,
            departmentsEverFormed: try container.decodeIfPresent(Int.self, forKey: .departmentsEverFormed) ?? 0,
            contractsAccepted: try container.decodeIfPresent(Int.self, forKey: .contractsAccepted) ?? 0,
            contractsSettled: try container.decodeIfPresent(Int.self, forKey: .contractsSettled) ?? 0,
            cashPositiveWeeks: try container.decodeIfPresent(Int.self, forKey: .cashPositiveWeeks) ?? 0,
            weekendsOff: try container.decodeIfPresent(Int.self, forKey: .weekendsOff) ?? 0,
            crashesWeathered: try container.decodeIfPresent(Int.self, forKey: .crashesWeathered) ?? 0,
            campaignsRun: try container.decodeIfPresent(Int.self, forKey: .campaignsRun) ?? 0,
            rivalsAcquired: try container.decodeIfPresent(Int.self, forKey: .rivalsAcquired) ?? 0,
            roundsRaised: try container.decodeIfPresent(Int.self, forKey: .roundsRaised) ?? 0,
            bestReviewScore: try container.decodeIfPresent(Int.self, forKey: .bestReviewScore) ?? 0,
            bestProductRevenue: try container.decodeIfPresent(Int.self, forKey: .bestProductRevenue) ?? 0,
            topicsDominated: try container.decodeIfPresent(Int.self, forKey: .topicsDominated) ?? 0,
            lastContractScanDay: try container.decodeIfPresent(Int.self, forKey: .lastContractScanDay) ?? 0
        )
    }
}

/// One chapter the run has reached, and the day it happened. The founder
/// biography reads this as the run's spine.
public struct ChapterEntry: Codable, Equatable, Sendable {
    public var chapter: Int
    public var day: Int

    public init(chapter: Int, day: Int) {
        self.chapter = chapter
        self.day = day
    }
}

// MARK: - Progression state

/// Everything the progression layer persists: who the founder is, which
/// chapter the run is in, which goals are done, how far the active ones
/// are, and which permanent perks have been earned.
///
/// Advanced only by `ProgressionSystem`, which is pure and draws no
/// randomness — the same seed and the same actions always complete the
/// same goals on the same days.
public struct ProgressionState: Codable, Equatable, Sendable {
    /// The identity chosen at new game.
    public var founder: FounderProfile
    /// 1-based chapter, 1...`ProgressionState.chapterCount`.
    public var chapter: Int
    /// Title of the current chapter, refreshed daily from the catalog so
    /// the UI needs no content lookup.
    public var chapterTitle: String
    /// Goal ids already completed. Never shrinks; a goal can only ever
    /// complete once.
    public var completedGoalIDs: Set<String>
    /// The goals the card is showing, in catalog order, with live
    /// progress. At most `activeGoalLimit` entries.
    public var activeGoals: [GoalProgress]
    /// Raw progress per goal id, kept so a bar can animate between days.
    public var goalProgress: [String: Double]
    /// Earned permanent perks (`ProgressionPerk` raw values).
    public var perks: Set<String>
    /// When each chapter was reached, oldest first.
    public var chapterLog: [ChapterEntry]
    /// Run counters no other state records.
    public var stats: ProgressionStats

    /// How many chapters `Goals.json` ships.
    public static let chapterCount = 5
    /// How many goals the card shows at once.
    public static let activeGoalLimit = 3

    public init(
        founder: FounderProfile = .default,
        chapter: Int = 1,
        chapterTitle: String = "",
        completedGoalIDs: Set<String> = [],
        activeGoals: [GoalProgress] = [],
        goalProgress: [String: Double] = [:],
        perks: Set<String> = [],
        chapterLog: [ChapterEntry] = [ChapterEntry(chapter: 1, day: 0)],
        stats: ProgressionStats = .initial
    ) {
        self.founder = founder
        self.chapter = chapter
        self.chapterTitle = chapterTitle
        self.completedGoalIDs = completedGoalIDs
        self.activeGoals = activeGoals
        self.goalProgress = goalProgress
        self.perks = perks
        self.chapterLog = chapterLog
        self.stats = stats
    }

    /// A fresh company's progression state: the default founder, chapter 1,
    /// nothing done.
    public static let initial = ProgressionState()

    /// A fresh company's progression state for a chosen founder.
    public static func initial(founder: FounderProfile) -> ProgressionState {
        ProgressionState(founder: founder)
    }

    /// Whether a permanent perk has been earned.
    public func hasPerk(_ perk: ProgressionPerk) -> Bool {
        perks.contains(perk.rawValue)
    }

    /// Earned perks in `ProgressionPerk` declaration order (set iteration
    /// order is not stable).
    public var earnedPerks: [ProgressionPerk] {
        ProgressionPerk.allCases.filter { perks.contains($0.rawValue) }
    }

    /// The day a chapter was first reached, if it ever was.
    public func dayReached(chapter: Int) -> Int? {
        chapterLog.first { $0.chapter == chapter }?.day
    }
}

// MARK: - Codable

// Hand-written so the set and dictionary members encode in sorted order —
// `Set` and `Dictionary` iteration order is not stable across processes and
// the determinism tests compare bytes — and so every field decodes with a
// default: a save written before progression existed decodes as `.initial`.

extension ProgressionState {
    private enum CodingKeys: String, CodingKey {
        case founder, chapter, chapterTitle, completedGoalIDs, activeGoals
        case goalProgress, perks, chapterLog, stats
    }

    private struct ProgressEntry: Codable {
        var goalID: String
        var value: Double
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entries = try container.decodeIfPresent([ProgressEntry].self, forKey: .goalProgress) ?? []
        self.init(
            founder: try container.decodeIfPresent(FounderProfile.self, forKey: .founder) ?? .default,
            chapter: try container.decodeIfPresent(Int.self, forKey: .chapter) ?? 1,
            chapterTitle: try container.decodeIfPresent(String.self, forKey: .chapterTitle) ?? "",
            completedGoalIDs: Set(
                try container.decodeIfPresent([String].self, forKey: .completedGoalIDs) ?? []
            ),
            activeGoals: try container.decodeIfPresent([GoalProgress].self, forKey: .activeGoals) ?? [],
            goalProgress: Dictionary(
                entries.map { ($0.goalID, $0.value) }, uniquingKeysWith: { _, last in last }
            ),
            perks: Set(try container.decodeIfPresent([String].self, forKey: .perks) ?? []),
            chapterLog: try container.decodeIfPresent([ChapterEntry].self, forKey: .chapterLog)
                ?? [ChapterEntry(chapter: 1, day: 0)],
            stats: try container.decodeIfPresent(ProgressionStats.self, forKey: .stats) ?? .initial
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(founder, forKey: .founder)
        try container.encode(chapter, forKey: .chapter)
        try container.encode(chapterTitle, forKey: .chapterTitle)
        try container.encode(completedGoalIDs.sorted(), forKey: .completedGoalIDs)
        try container.encode(activeGoals, forKey: .activeGoals)
        try container.encode(
            goalProgress.keys.sorted().map { ProgressEntry(goalID: $0, value: goalProgress[$0] ?? 0) },
            forKey: .goalProgress
        )
        try container.encode(perks.sorted(), forKey: .perks)
        try container.encode(chapterLog, forKey: .chapterLog)
        try container.encode(stats, forKey: .stats)
    }
}

// MARK: - FounderProfile Codable

// Hand-written so a profile saved before `usesArchetypeSkills` existed
// decodes as a chosen founder: any profile already in a save came from a
// new-game flow that asked, and its founder's skills were baked into the
// employee at day 0 anyway.

extension FounderProfile {
    private enum CodingKeys: String, CodingKey {
        case name, archetype, appearanceSeed, usesArchetypeSkills
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            name: try container.decode(String.self, forKey: .name),
            archetype: try container.decodeIfPresent(FounderArchetype.self, forKey: .archetype) ?? .hacker,
            appearanceSeed: try container.decodeIfPresent(UInt64.self, forKey: .appearanceSeed),
            usesArchetypeSkills: try container.decodeIfPresent(
                Bool.self, forKey: .usesArchetypeSkills
            ) ?? true
        )
    }
}
