import Foundation

/// How a rival studio behaves. Fixed at founding and visible in the
/// rivals screen, because a competitor you can read is a competitor you
/// can plan against.
public enum RivalPersonality: String, Codable, Equatable, Sendable, CaseIterable {
    /// Watches what you ship and clones your best topic a couple of months
    /// later.
    case copycat
    /// Spends its time hiring your people.
    case poacher
    /// Backed by somebody patient — never folds, just keeps coming.
    case deepPockets
    /// Ships rarely, and what it ships is very good.
    case visionary

    public var displayName: String {
        switch self {
        case .copycat: "Copycat"
        case .poacher: "Poacher"
        case .deepPockets: "Deep Pockets"
        case .visionary: "Visionary"
        }
    }

    public var blurb: String {
        switch self {
        case .copycat: "Ships your idea back at you, two months later."
        case .poacher: "Buys your people lunch. Then buys your people."
        case .deepPockets: "Somebody rich is patient about this one."
        case .visionary: "Quiet for a year, then something excellent."
        }
    }

    public var systemImageName: String {
        switch self {
        case .copycat: "doc.on.doc.fill"
        case .poacher: "person.crop.circle.badge.minus"
        case .deepPockets: "banknote.fill"
        case .visionary: "sparkles"
        }
    }

    /// A line the rival card shows when this studio is beating the player
    /// in a shared topic.
    public var taunt: String {
        switch self {
        case .copycat: "\"Great minds. Ours just ships faster.\""
        case .poacher: "\"Lovely team you've got. We've met a few of them.\""
        case .deepPockets: "\"We can lose money on this longer than you can.\""
        case .visionary: "\"We weren't in a hurry. You'll see why.\""
        }
    }
}

/// One product a rival actually shipped, with a name you can lose to.
public struct RivalProduct: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var topicID: String
    public var typeID: String
    /// 0...100, rolled from the rival's strength at launch.
    public var quality: Double
    public var launchDay: Int
    /// A rough weekly unit figure for the head-to-head panel.
    public var weeklyUnits: Int

    public init(
        id: UUID,
        name: String,
        topicID: String,
        typeID: String,
        quality: Double,
        launchDay: Int,
        weeklyUnits: Int
    ) {
        self.id = id
        self.name = name
        self.topicID = topicID
        self.typeID = typeID
        self.quality = quality
        self.launchDay = launchDay
        self.weeklyUnits = weeklyUnits
    }

    /// Whether the product is still fighting for share on a given day.
    /// Products older than `RivalDepthTuning.relevanceWeeks` have faded.
    public func isCompeting(on day: Int) -> Bool {
        day - launchDay < RivalDepthTuning.relevanceWeeks * GameState.daysPerWeek
    }
}

/// The constants behind rival depth: named products, per-topic share and
/// price wars.
///
/// Deliberately not in `Balance.json`: `RivalBalance` lives in
/// `BalanceConfig.swift`, which WS-A owns and is retuning this iteration,
/// and WS-F's three balance objects are progression / investors / traits.
/// Folding these in belongs to whoever opens a `rivalDepth` block.
public enum RivalDepthTuning {
    /// How long a launched product keeps competing for share.
    public static let relevanceWeeks = 26
    /// Chance per weekly evolution that a rival ships a named product,
    /// before the personality modifier.
    public static let launchChance = 0.10
    /// The visionary ships this much less often, and this much better.
    public static let visionaryLaunchFactor = 0.45
    public static let visionaryQualityBonus = 18.0
    /// Quality is `strength × qualityPerStrength` plus a roll of
    /// ±`qualityJitter`, clamped to 20...95.
    public static let qualityPerStrength = 0.85
    public static let qualityJitter = 12.0
    public static let qualityMin = 20.0
    public static let qualityMax = 95.0
    /// The player's share never falls below this or rises above this, so a
    /// topic is never hopeless and never free.
    public static let shareMin = 0.30
    public static let shareMax = 1.00
    /// How strongly quality decides share: the player's weight is
    /// `quality ^ shareExponent`.
    public static let shareExponent = 2.0
    /// A copycat clones the player's best topic this many weeks after the
    /// launch it copied.
    public static let copycatDelayWeeks = 8
    /// Beating a rival this many weeks running in a shared topic provokes
    /// a price war.
    public static let priceWarTrigger = 2
    /// A price war lasts this many weeks and takes this much share.
    public static let priceWarWeeks = 4
    public static let priceWarSharePenalty = 0.10
    /// The share above which the player counts as owning a topic.
    public static let dominanceShare = 0.65
    /// The poacher's multiplier on the poach chance.
    public static let poacherChanceFactor = 2.0
    /// How many products one rival keeps on its shelf.
    public static let maxProductsPerRival = 6
}

/// A simulated competitor studio. Rivals carry a strength score, a
/// reputation, one or two focus topics, a personality that shapes how they
/// play, and the named products they have actually shipped — evolved by
/// `RivalSystem` on a weekly cadence.
public struct Rival: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    /// Abstract size/health score, clamped to 5...100. Drives valuation,
    /// poach priority, and folding.
    public var strength: Double
    /// 0...100, like the player's company reputation.
    public var reputation: Double
    /// `TopicDef.id`s this rival ships in (1-2, fixed at founding).
    public var focusTopicIDs: [String]
    /// City district raw value once the city exists; nil until then.
    public var hqDistrict: String?
    public var lastShippedDay: Int?
    public var foundedDay: Int
    /// Drives the pixel-art look of the rival's founder avatar.
    public var appearanceSeed: UInt64
    /// Named products this studio has shipped, oldest first, capped at
    /// `RivalDepthTuning.maxProductsPerRival`.
    public var products: [RivalProduct]
    /// How this studio plays. Fixed at founding.
    public var personality: RivalPersonality
    /// Consecutive weeks the player has out-shared this rival in a topic
    /// they both ship into. At `priceWarTrigger` the rival retaliates.
    public var weeksBeaten: Int
    /// While set, this studio is running a price war in `priceWarTopicID`
    /// until this day.
    public var priceWarUntilDay: Int?
    public var priceWarTopicID: String?
    /// The Incumbent (WS-A, iteration 5): the deep-pockets giant founded
    /// into the player's two best markets once the company is worth
    /// having. True while it is still fighting for them; a retreat clears
    /// it and leaves an ordinary — large — rival on the board.
    public var isIncumbent: Bool

    public init(
        id: UUID,
        name: String,
        strength: Double,
        reputation: Double,
        focusTopicIDs: [String],
        hqDistrict: String? = nil,
        lastShippedDay: Int? = nil,
        foundedDay: Int,
        appearanceSeed: UInt64,
        products: [RivalProduct] = [],
        personality: RivalPersonality = .deepPockets,
        weeksBeaten: Int = 0,
        priceWarUntilDay: Int? = nil,
        priceWarTopicID: String? = nil,
        isIncumbent: Bool = false
    ) {
        self.id = id
        self.name = name
        self.strength = strength
        self.reputation = reputation
        self.focusTopicIDs = focusTopicIDs
        self.hqDistrict = hqDistrict
        self.lastShippedDay = lastShippedDay
        self.foundedDay = foundedDay
        self.appearanceSeed = appearanceSeed
        self.products = products
        self.personality = personality
        self.weeksBeaten = weeksBeaten
        self.priceWarUntilDay = priceWarUntilDay
        self.priceWarTopicID = priceWarTopicID
        self.isIncumbent = isIncumbent
    }

    /// The products still fighting for share on a given day.
    public func competingProducts(on day: Int) -> [RivalProduct] {
        products.filter { $0.isCompeting(on: day) }
    }

    /// The best thing this studio currently has in a topic, if anything.
    public func bestProduct(in topicID: String, on day: Int) -> RivalProduct? {
        competingProducts(on: day)
            .filter { $0.topicID == topicID }
            .max { $0.quality < $1.quality }
    }

    /// Whether this studio is running a price war on a given day.
    public func isInPriceWar(on day: Int) -> Bool {
        priceWarUntilDay.map { day < $0 } ?? false
    }

    /// Rough headcount shown in the UI, derived from strength.
    public var headcount: Int { max(2, Int((strength / 5).rounded())) }

    /// What buying this rival's company is worth on the open market.
    public func valuation(balance: BalanceConfig) -> Int {
        Int((strength * balance.rivals.valuationPerStrength * (1 + reputation / 100)).rounded())
    }
}

// MARK: - Codable

// Hand-written decode so a save written before rival depth existed keeps
// loading: products read as none, the personality falls back to the
// patient one, and no price war is in progress.

extension Rival {
    private enum CodingKeys: String, CodingKey {
        case id, name, strength, reputation, focusTopicIDs, hqDistrict
        case lastShippedDay, foundedDay, appearanceSeed
        case products, personality, weeksBeaten, priceWarUntilDay, priceWarTopicID
        case isIncumbent
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            strength: try container.decode(Double.self, forKey: .strength),
            reputation: try container.decode(Double.self, forKey: .reputation),
            focusTopicIDs: try container.decode([String].self, forKey: .focusTopicIDs),
            hqDistrict: try container.decodeIfPresent(String.self, forKey: .hqDistrict),
            lastShippedDay: try container.decodeIfPresent(Int.self, forKey: .lastShippedDay),
            foundedDay: try container.decode(Int.self, forKey: .foundedDay),
            appearanceSeed: try container.decode(UInt64.self, forKey: .appearanceSeed),
            products: try container.decodeIfPresent([RivalProduct].self, forKey: .products) ?? [],
            personality: try container.decodeIfPresent(RivalPersonality.self, forKey: .personality)
                ?? .deepPockets,
            weeksBeaten: try container.decodeIfPresent(Int.self, forKey: .weeksBeaten) ?? 0,
            priceWarUntilDay: try container.decodeIfPresent(Int.self, forKey: .priceWarUntilDay),
            priceWarTopicID: try container.decodeIfPresent(String.self, forKey: .priceWarTopicID),
            isIncumbent: try container.decodeIfPresent(Bool.self, forKey: .isIncumbent) ?? false
        )
    }
}

/// A rival's standing offer to hire away one of the player's employees.
/// Stored in state until the player responds or `respondByDay` passes.
public struct PoachOffer: Codable, Equatable, Sendable {
    public var rivalID: UUID
    public var employeeID: UUID
    public var offeredWeeklySalary: Int
    /// Last day the player can respond; the next rival tick past this day
    /// auto-resolves the offer against the employee's loyalty.
    public var respondByDay: Int

    public init(rivalID: UUID, employeeID: UUID, offeredWeeklySalary: Int, respondByDay: Int) {
        self.rivalID = rivalID
        self.employeeID = employeeID
        self.offeredWeeklySalary = offeredWeeklySalary
        self.respondByDay = respondByDay
    }
}

/// A rival's standing offer to buy the player's company outright.
public struct BuyoutOffer: Codable, Equatable, Sendable {
    public var rivalID: UUID
    public var amount: Int
    /// Last day the player can respond; the offer is silently withdrawn on
    /// the next rival tick past this day.
    public var respondByDay: Int

    public init(rivalID: UUID, amount: Int, respondByDay: Int) {
        self.rivalID = rivalID
        self.amount = amount
        self.respondByDay = respondByDay
    }
}

/// A rival's launch into a category the player holds — "The Category
/// Fight" (WS-A, iteration 5). Opened by `RivalSystem` when a launch lands
/// in a topic where the player's standing clears
/// `rivals.depth.challengeMinStanding` and the product scores inside the
/// quality window; settled `challengeWeeks` later on the share the player
/// holds then. Until it is answered — a defence routed through
/// `GameAction.defendCategory`, or `concedeCategory` — it is the pending
/// decision the app puts on a sheet.
public struct CategoryChallenge: Codable, Equatable, Sendable, Identifiable {
    public var rivalID: UUID
    public var topicID: String
    /// The launch that opened it, and what it scored.
    public var productName: String
    public var quality: Double
    public var startedDay: Int
    /// The day the fight is decided: share at or above
    /// `rivals.depth.challengeHoldShare` holds the category.
    public var settlesDay: Int
    /// The day the player answered, `nil` while the sheet is still up.
    /// The settlement runs either way.
    public var answeredDay: Int?
    /// Whether the answer was "let it go".
    public var conceded: Bool

    public init(
        rivalID: UUID,
        topicID: String,
        productName: String,
        quality: Double,
        startedDay: Int,
        settlesDay: Int,
        answeredDay: Int? = nil,
        conceded: Bool = false
    ) {
        self.rivalID = rivalID
        self.topicID = topicID
        self.productName = productName
        self.quality = quality
        self.startedDay = startedDay
        self.settlesDay = settlesDay
        self.answeredDay = answeredDay
        self.conceded = conceded
    }

    /// Stable across the fight, and different for the next one in the
    /// same topic, so the sheet re-presents exactly once per challenge.
    public var id: String { "\(topicID)-\(startedDay)-\(rivalID.uuidString)" }

    /// Whether the player still owes an answer.
    public var isPending: Bool { answeredDay == nil }

    private enum CodingKeys: String, CodingKey {
        case rivalID, topicID, productName, quality, startedDay, settlesDay, answeredDay, conceded
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            rivalID: try container.decode(UUID.self, forKey: .rivalID),
            topicID: try container.decode(String.self, forKey: .topicID),
            productName: try container.decode(String.self, forKey: .productName),
            quality: try container.decode(Double.self, forKey: .quality),
            startedDay: try container.decode(Int.self, forKey: .startedDay),
            settlesDay: try container.decode(Int.self, forKey: .settlesDay),
            answeredDay: try container.decodeIfPresent(Int.self, forKey: .answeredDay),
            conceded: try container.decodeIfPresent(Bool.self, forKey: .conceded) ?? false
        )
    }
}

/// The three answers to a challenge that the game already had as actions.
/// `GameAction.defendCategory` routes one of these to the player's best
/// live product in the challenged topic — the sheet offers them, and so
/// can a bot — and marks the challenge answered when it took effect.
public enum CategoryDefense: String, Codable, Equatable, Sendable, CaseIterable {
    /// `setPriceTier(.budget)`: more of the market, less per sale.
    case budgetPrice
    /// `startUpdate`: a build slot for a few weeks and another look from
    /// the press.
    case patch
    /// `startCampaign(.socialPush)`: cash for hype.
    case campaign
}

/// Everything about the competitive landscape, advanced by `RivalSystem`.
public struct RivalsState: Codable, Equatable, Sendable {
    public var rivals: [Rival]
    public var pendingPoach: PoachOffer?
    public var pendingBuyout: BuyoutOffer?
    /// The last day a poach attempt fired (global cooldown across rivals).
    public var lastPoachDay: Int?
    public var lastBuyoutDay: Int?
    /// The player's slice of each topic's demand, 0.3...1.0, recomputed
    /// weekly by `RivalSystem` from the quality of everything on the
    /// market. Mirrored into `MarketState` every day so
    /// `ProductSystem`'s sales read it through
    /// `MarketState.shareMultiplier(for:)`. A topic with no entry reads
    /// 1.0 — the whole market, exactly as before rivals shipped products.
    public var playerShare: [String: Double]
    /// Whether the last buyout offer was a strategic approach (a premium
    /// for a company worth having) rather than a distress bid.
    public var lastBuyoutWasStrategic: Bool
    /// The category fights in progress, one per topic at most, oldest
    /// first. Settled and removed by `RivalSystem` on `settlesDay`.
    public var challenges: [CategoryChallenge]
    /// The day each topic was last challenged, for the per-topic cooldown.
    public var lastChallengeDay: [String: Int]
    /// The day the incumbent was founded, `nil` until it is. One per run.
    public var incumbentFoundedDay: Int?
    /// The first weekly check on which the player held both of the
    /// incumbent's topics; `nil` whenever they do not. Its retreat clock.
    public var incumbentHeldSinceDay: Int?

    public init(
        rivals: [Rival],
        pendingPoach: PoachOffer? = nil,
        pendingBuyout: BuyoutOffer? = nil,
        lastPoachDay: Int? = nil,
        lastBuyoutDay: Int? = nil,
        playerShare: [String: Double] = [:],
        lastBuyoutWasStrategic: Bool = false,
        challenges: [CategoryChallenge] = [],
        lastChallengeDay: [String: Int] = [:],
        incumbentFoundedDay: Int? = nil,
        incumbentHeldSinceDay: Int? = nil
    ) {
        self.rivals = rivals
        self.pendingPoach = pendingPoach
        self.pendingBuyout = pendingBuyout
        self.lastPoachDay = lastPoachDay
        self.lastBuyoutDay = lastBuyoutDay
        self.playerShare = playerShare
        self.lastBuyoutWasStrategic = lastBuyoutWasStrategic
        self.challenges = challenges
        self.lastChallengeDay = lastChallengeDay
        self.incumbentFoundedDay = incumbentFoundedDay
        self.incumbentHeldSinceDay = incumbentHeldSinceDay
    }

    /// Pre-rivals saves start here; `RivalSystem` founds the field on its
    /// first tick.
    public static let empty = RivalsState(rivals: [])

    public func rival(id: UUID) -> Rival? {
        rivals.first { $0.id == id }
    }

    /// The challenge still waiting for an answer — the shape of
    /// `pendingPoach`, for the decision sheet. Oldest first.
    public var pendingChallenge: CategoryChallenge? {
        challenges.first { $0.isPending }
    }

    /// The fight in progress in a topic, if any.
    public func challenge(in topicID: String) -> CategoryChallenge? {
        challenges.first { $0.topicID == topicID }
    }

    /// The deep-pockets giant in the player's best markets, while it is
    /// still fighting for them.
    public var incumbent: Rival? {
        rivals.first { $0.isIncumbent }
    }

    /// The player's slice of a topic, 1.0 for a topic nobody contests.
    public func share(for topicID: String) -> Double {
        playerShare[topicID] ?? 1.0
    }

    /// Topics the player owns outright — share above
    /// `RivalDepthTuning.dominanceShare` while a rival is actually in the
    /// market. Feeds the "own a topic" chapter goal.
    public var dominatedTopicCount: Int {
        playerShare.count { $0.value >= RivalDepthTuning.dominanceShare && $0.value < 1.0 }
    }

    /// Every rival currently selling something in a topic, strongest
    /// product first.
    public func competitors(in topicID: String, on day: Int) -> [(rival: Rival, product: RivalProduct)] {
        rivals
            .compactMap { rival in
                rival.bestProduct(in: topicID, on: day).map { (rival, $0) }
            }
            .sorted { lhs, rhs in
                if lhs.product.quality != rhs.product.quality {
                    return lhs.product.quality > rhs.product.quality
                }
                return lhs.rival.id.uuidString < rhs.rival.id.uuidString
            }
    }
}

// MARK: - Codable

// Hand-written so `playerShare` encodes as an array sorted by topic id
// (dictionary iteration order is not stable and the determinism tests
// compare bytes), and so a save written before rival depth existed decodes
// with an uncontested market.

extension RivalsState {
    private enum CodingKeys: String, CodingKey {
        case rivals, pendingPoach, pendingBuyout, lastPoachDay, lastBuyoutDay
        case playerShare, lastBuyoutWasStrategic
        case challenges, lastChallengeDay, incumbentFoundedDay, incumbentHeldSinceDay
    }

    private struct ShareEntry: Codable {
        var topicID: String
        var share: Double
    }

    private struct DayEntry: Codable {
        var topicID: String
        var day: Int
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entries = try container.decodeIfPresent([ShareEntry].self, forKey: .playerShare) ?? []
        let challengeDays = try container.decodeIfPresent([DayEntry].self, forKey: .lastChallengeDay) ?? []
        self.init(
            rivals: try container.decode([Rival].self, forKey: .rivals),
            pendingPoach: try container.decodeIfPresent(PoachOffer.self, forKey: .pendingPoach),
            pendingBuyout: try container.decodeIfPresent(BuyoutOffer.self, forKey: .pendingBuyout),
            lastPoachDay: try container.decodeIfPresent(Int.self, forKey: .lastPoachDay),
            lastBuyoutDay: try container.decodeIfPresent(Int.self, forKey: .lastBuyoutDay),
            playerShare: Dictionary(
                entries.map { ($0.topicID, $0.share) }, uniquingKeysWith: { _, last in last }
            ),
            lastBuyoutWasStrategic: try container.decodeIfPresent(
                Bool.self, forKey: .lastBuyoutWasStrategic
            ) ?? false,
            challenges: try container.decodeIfPresent([CategoryChallenge].self, forKey: .challenges) ?? [],
            lastChallengeDay: Dictionary(
                challengeDays.map { ($0.topicID, $0.day) }, uniquingKeysWith: { _, last in last }
            ),
            incumbentFoundedDay: try container.decodeIfPresent(Int.self, forKey: .incumbentFoundedDay),
            incumbentHeldSinceDay: try container.decodeIfPresent(Int.self, forKey: .incumbentHeldSinceDay)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rivals, forKey: .rivals)
        try container.encodeIfPresent(pendingPoach, forKey: .pendingPoach)
        try container.encodeIfPresent(pendingBuyout, forKey: .pendingBuyout)
        try container.encodeIfPresent(lastPoachDay, forKey: .lastPoachDay)
        try container.encodeIfPresent(lastBuyoutDay, forKey: .lastBuyoutDay)
        try container.encode(
            playerShare.keys.sorted().map { ShareEntry(topicID: $0, share: playerShare[$0] ?? 1) },
            forKey: .playerShare
        )
        try container.encode(lastBuyoutWasStrategic, forKey: .lastBuyoutWasStrategic)
        try container.encode(challenges, forKey: .challenges)
        // Sorted for the same reason as the share table: identical states
        // must encode to identical bytes whatever the dictionary's order.
        try container.encode(
            lastChallengeDay.keys.sorted().map { DayEntry(topicID: $0, day: lastChallengeDay[$0] ?? 0) },
            forKey: .lastChallengeDay
        )
        try container.encodeIfPresent(incumbentFoundedDay, forKey: .incumbentFoundedDay)
        try container.encodeIfPresent(incumbentHeldSinceDay, forKey: .incumbentHeldSinceDay)
    }
}
