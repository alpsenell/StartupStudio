/// One chapter goal, loaded from `Goals.json`.
///
/// Goals are the run's spine: five chapters of six, each one a concrete
/// thing to do next, each one evaluated every day by the engine's
/// `ProgressionSystem` against a closed set of conditions. Finishing them
/// pays out reputation, cash, or a permanent perk, and four out of six
/// opens the next chapter.
public struct GoalDef: Codable, Equatable, Sendable, Identifiable {
    /// What has to become true. A closed set: the engine switches over
    /// `Kind` exhaustively, so a goal can never ask for something no system
    /// can measure.
    public struct Condition: Codable, Equatable, Sendable {
        public enum Kind: String, Codable, Equatable, Sendable, CaseIterable {
            /// Products ever started (naming one counts).
            case productsStarted
            /// Products ever shipped.
            case productsShipped
            /// Best average review score of any shipped product.
            case bestReviewScore
            /// Largest headcount ever reached, founder included.
            case peakHeadcount
            /// Office tier reached; `text` is the tier's raw value.
            case officeTierReached
            /// Home tier reached; `text` is the tier's raw value.
            case homeTierReached
            /// Contracts ever accepted.
            case contractsAccepted
            /// Contracts ever settled — delivered or failed.
            case contractsSettled
            /// Weeks that ended with cash above zero.
            case cashPositiveWeeks
            /// Cash on hand right now.
            case cashOnHand
            /// Company reputation right now.
            case reputation
            /// Technologies researched.
            case techsResearched
            /// Technologies researched at or above tier `amount`.
            case techTierResearched
            /// Weekends spent on something other than resting.
            case weekendsOff
            /// Relationship reached; `text` is the stage's raw value.
            case relationshipReached
            /// Children born.
            case children
            /// Distinct departments ever staffed.
            case departmentsFormed
            /// Office amenities built.
            case amenitiesBuilt
            /// Marketing campaigns ever started.
            case campaignsRun
            /// Market crashes weathered without going under.
            case crashesWeathered
            /// Lifetime revenue of the best single product.
            case bestProductRevenue
            /// Topics where the player's share beat every rival.
            case topicsDominated
            /// Rival studios bought outright.
            case rivalsAcquired
            /// Funding rounds closed.
            case roundsRaised
            /// Founder net worth: wallet plus their slice of the valuation.
            case founderNetWorth
            /// Company valuation right now.
            case companyValuation
            /// Everything an IPO needs is in place (1 when ready).
            case readyToGoPublic

            // MARK: Iteration 5 — the independent ladder (WS-G)

            /// Consecutive quarters the company finished in profit, as the
            /// board room already counts them.
            case profitableQuarters
            /// Weeks that ended with at least two products on the market at
            /// once.
            case liveProductsWeeks
            /// The company owns its office outright (1 when it does).
            case officeOwned
            /// People, founder excluded, who have each been with the
            /// company for a year.
            case tenuredStaff
            /// Everything the *Still yours* ending needs is in place (1 when
            /// ready).
            case readyToStayIndependent
            /// Years the company has been trading, to one decimal.
            case yearsTrading
        }

        public var kind: Kind
        /// What the measurement has to reach. Counts, dollars and scores
        /// all live here; tier-style goals use 1 and put the tier in
        /// `text`.
        public var amount: Double
        /// The tier / stage / topic the condition refers to, when it needs
        /// one.
        public var text: String?

        public init(kind: Kind, amount: Double = 1, text: String? = nil) {
            self.kind = kind
            self.amount = amount
            self.text = text
        }
    }

    /// What finishing a goal pays out. All optional; a goal whose reward is
    /// simply "the next chapter" lists none.
    public struct Reward: Codable, Equatable, Sendable {
        /// Company reputation points.
        public var reputation: Double?
        /// Cash into the company account.
        public var cash: Int?
        /// A permanent perk (`ProgressionPerk` raw value in the engine).
        public var perk: String?

        public init(reputation: Double? = nil, cash: Int? = nil, perk: String? = nil) {
            self.reputation = reputation
            self.cash = cash
            self.perk = perk
        }
    }

    public var id: String
    public var title: String
    /// One-line explanation shown under the title.
    public var detail: String?
    /// 1-based chapter this goal belongs to.
    public var chapter: Int
    public var condition: Condition
    public var reward: Reward?
    /// Which ladder the goal is on (`GoalTrack` raw value), or `nil` for
    /// both. Chapters 1–2 carry no track; from chapter 3 the catalog
    /// splits into a funded ladder and an independent one, and a goal
    /// both ladders share (score 75, three children) stays `nil`.
    public var track: String?

    public init(
        id: String,
        title: String,
        detail: String? = nil,
        chapter: Int,
        condition: Condition = Condition(kind: .productsShipped),
        reward: Reward? = nil,
        track: String? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.chapter = chapter
        self.condition = condition
        self.reward = reward
        self.track = track
    }

    /// Whether the goal is on `track` — a goal with no track is on every
    /// one.
    public func isOn(_ track: GoalTrack) -> Bool {
        self.track == nil || self.track == track.rawValue
    }
}

/// The two ladders the late chapters split into (WS-G, iteration 5).
///
/// The funded ladder is today's catalog: a round, a campus, an
/// acquisition, the bell. The independent ladder asks for a company that
/// lasts instead of one that grows, and ends in *Still yours*. Which one
/// is active is the engine's call (`GameState.goalTrack`), not content's.
public enum GoalTrack: String, Codable, Equatable, Sendable, CaseIterable {
    case funded
    case independent

    public var displayName: String {
        switch self {
        case .funded: "Funded"
        case .independent: "Independent"
        }
    }
}

/// The name and one-line promise of a chapter, loaded from `Goals.json`
/// alongside its goals.
public struct ChapterDef: Codable, Equatable, Sendable, Identifiable {
    /// 1-based chapter number, and the identity.
    public var chapter: Int
    public var title: String
    /// The teaser shown while the chapter is still locked.
    public var teaser: String
    public var goals: [GoalDef]

    public var id: Int { chapter }

    public init(chapter: Int, title: String, teaser: String, goals: [GoalDef]) {
        self.chapter = chapter
        self.title = title
        self.teaser = teaser
        self.goals = goals
    }
}

// MARK: - Codable

// Hand-written so a goal that lists no reward, or a condition that needs no
// `text`, still decodes, and so a `chapter` written on the goal itself
// (rather than inherited from its ChapterDef) is honored.

extension GoalDef {
    private enum CodingKeys: String, CodingKey {
        case id, title, detail, chapter, condition, reward, track
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            title: try container.decode(String.self, forKey: .title),
            detail: try container.decodeIfPresent(String.self, forKey: .detail),
            chapter: try container.decodeIfPresent(Int.self, forKey: .chapter) ?? 1,
            condition: try container.decode(Condition.self, forKey: .condition),
            reward: try container.decodeIfPresent(Reward.self, forKey: .reward),
            // Absent means both ladders, so a catalog written before the
            // split reads exactly as it did.
            track: try container.decodeIfPresent(String.self, forKey: .track)
        )
    }
}

extension GoalDef.Condition {
    private enum CodingKeys: String, CodingKey {
        case kind, amount, text
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            kind: try container.decode(Kind.self, forKey: .kind),
            amount: try container.decodeIfPresent(Double.self, forKey: .amount) ?? 1,
            text: try container.decodeIfPresent(String.self, forKey: .text)
        )
    }
}

extension ChapterDef {
    /// The five chapters' names and teasers.
    ///
    /// `Goals.json` is a flat array of goals — that is the shape
    /// `ContentCatalog` loads — so the prose that frames them lives here,
    /// next to the type that carries it. A chapter the table doesn't name
    /// falls back to "Chapter N".
    public static let titles: [Int: (title: String, teaser: String)] = [
        1: ("Garage", "One person, one product, and a bank balance you can count in your head."),
        2: ("Loft", "Two desks became six. Payroll is a thing that happens on Fridays now."),
        3: ("Studio", "Fourteen people, a department that runs itself, and a market that notices you."),
        4: ("Scale", "Somebody else's money, forty desks, and rivals who have heard of you."),
        5: ("Legacy", "The part where you find out what all of it was for."),
    ]

    /// The title for a chapter number.
    public static func title(for chapter: Int) -> String {
        titles[chapter]?.title ?? "Chapter \(chapter)"
    }

    /// The teaser for a chapter number, shown while it is still locked.
    public static func teaser(for chapter: Int) -> String {
        titles[chapter]?.teaser ?? ""
    }

    /// The independent ladder's own teasers for the chapters that split.
    /// The funded ladder keeps `titles`; a chapter with no entry here
    /// reads the same on both.
    public static let independentTeasers: [Int: String] = [
        3: "Fourteen people who stay, four quarters in the black, and an office with your name on the deeds.",
        4: "Nobody else's money. Two things on sale at once, and a company that runs without you on a Tuesday.",
        5: "Still yours. The part where you find out what all of it was for.",
    ]

    /// The teaser for a chapter on a ladder, shown while it is still
    /// locked. `nil` — no ladder declared yet — reads the funded copy,
    /// which is what every chapter said before the split.
    public static func teaser(for chapter: Int, track: GoalTrack?) -> String {
        if track == .independent, let teaser = independentTeasers[chapter] {
            return teaser
        }
        return teaser(for: chapter)
    }
}

extension ContentCatalog {
    /// The goals of one chapter, in catalog order — every ladder's.
    public func goals(inChapter chapter: Int) -> [GoalDef] {
        goals.filter { $0.chapter == chapter }
    }

    /// The goals of one chapter on one ladder, in catalog order: the
    /// ladder's own plus the ones both ladders share.
    public func goals(inChapter chapter: Int, track: GoalTrack) -> [GoalDef] {
        goals.filter { $0.chapter == chapter && $0.isOn(track) }
    }

    /// Every chapter the goal catalog defines, lowest first, each with its
    /// title, teaser and goals.
    public var chapters: [ChapterDef] {
        Set(goals.map(\.chapter)).sorted().map { chapter in
            ChapterDef(
                chapter: chapter,
                title: ChapterDef.title(for: chapter),
                teaser: ChapterDef.teaser(for: chapter),
                goals: goals(inChapter: chapter)
            )
        }
    }

    /// Lookup of a goal by id. Linear over a 30-entry catalog.
    public func goal(_ id: String) -> GoalDef? {
        goals.first { $0.id == id }
    }
}

extension ChapterDef {
    private enum CodingKeys: String, CodingKey {
        case chapter, title, teaser, goals
    }

    /// Goals inherit their chapter number from the chapter that lists them,
    /// so `Goals.json` never repeats it.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let chapter = try container.decode(Int.self, forKey: .chapter)
        self.init(
            chapter: chapter,
            title: try container.decode(String.self, forKey: .title),
            teaser: try container.decodeIfPresent(String.self, forKey: .teaser) ?? "",
            goals: try container.decode([GoalDef].self, forKey: .goals).map { goal in
                var goal = goal
                goal.chapter = chapter
                return goal
            }
        )
    }
}
