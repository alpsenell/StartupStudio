import Foundation

/// The live condition of one topic's market.
public struct TopicMarket: Codable, Equatable, Sendable {
    /// Demand multiplier applied to weekly sales, clamped to the balance's
    /// `multiplierMin...multiplierMax`.
    public var multiplier: Double
    /// The delta applied by the most recent market shift (drives the UI
    /// trend arrow). 0 until the first shift.
    public var lastChange: Double
    /// The player's slice of this topic's demand, 0.3...1.0. Owned by
    /// `RivalSystem` (WS-F), which recomputes it weekly from the quality of
    /// every product on the market and re-mirrors it here every day — so a
    /// weekly market shift rebuilding this struct never loses it. 1.0 means
    /// nobody is competing, which is what every topic reads as until a
    /// rival ships something into it.
    public var playerShare: Double

    public init(multiplier: Double, lastChange: Double, playerShare: Double = 1.0) {
        self.multiplier = multiplier
        self.lastChange = lastChange
        self.playerShare = playerShare
    }

    public static let neutral = TopicMarket(multiplier: 1.0, lastChange: 0)
}

// MARK: - Codable

// Hand-written so a save written before market share existed decodes with
// an uncontested market rather than failing to load.

extension TopicMarket {
    private enum CodingKeys: String, CodingKey {
        case multiplier, lastChange, playerShare
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            multiplier: try container.decode(Double.self, forKey: .multiplier),
            lastChange: try container.decode(Double.self, forKey: .lastChange),
            playerShare: try container.decodeIfPresent(Double.self, forKey: .playerShare) ?? 1.0
        )
    }
}

/// A boom or crash recorded by `MarketSystem` for the market screen.
public struct MarketEvent: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case boom, crash
    }

    public var day: Int
    public var topicID: String
    public var kind: Kind

    public init(day: Int, topicID: String, kind: Kind) {
        self.day = day
        self.topicID = topicID
        self.kind = kind
    }
}

/// What a studio that holds a category can see coming: where the topic's
/// multiplier is likely to be `weeksAhead` shifts from now, and how likely
/// it is that a boom or a crash lands inside that window.
///
/// This is a *read*, not a prophecy, and deliberately so. The market walk
/// is drawn from the same RNG stream as everything else in the sim, so the
/// only way to know a future draw would be to make it early — which
/// reshuffles the walk and moves the pacing table (measured; see
/// `MarketBalance.defaultForecastHorizonWeeks`). What the walk *does* offer
/// for free is its own shape: a known step sigma, a known jump size and
/// rate, and hard clamps at either end. A topic sitting at ×1.7 is not
/// equally likely to rise as to fall, and a studio with standing in the
/// category is the one that knows it.
///
/// So: no draws, no state, nothing the bots can feel — and a number the
/// player only gets in the categories they hold.
public struct MarketForecast: Equatable, Sendable {
    public var topicID: String
    /// Shifts ahead this projection looks (`market.forecastHorizonWeeks`).
    public var weeksAhead: Int
    /// The multiplier now.
    public var current: Double
    /// The centre of the projected band, clamped to the market's bounds.
    public var expected: Double
    /// One standard deviation either side of `expected`, clamped.
    public var low: Double
    public var high: Double
    /// The chance at least one boom or crash lands inside the window.
    public var jumpChance: Double

    public init(
        topicID: String, weeksAhead: Int, current: Double,
        expected: Double, low: Double, high: Double, jumpChance: Double
    ) {
        self.topicID = topicID
        self.weeksAhead = weeksAhead
        self.current = current
        self.expected = expected
        self.low = low
        self.high = high
        self.jumpChance = jumpChance
    }

    /// Where the band sits against today's number. The clamps do the work:
    /// with equal room either side the band is symmetric and the read is
    /// `.steady`, but a topic near a bound has more room to move one way
    /// than the other, and that asymmetry is real information.
    public enum Lean: String, Equatable, Sendable {
        case cooling, steady, warming
    }

    /// Half a step of drift is the smallest lean worth naming.
    public func lean(threshold: Double) -> Lean {
        let midpoint = (low + high) / 2
        if midpoint > current + threshold { return .warming }
        if midpoint < current - threshold { return .cooling }
        return .steady
    }

    /// Projects a topic `weeks` shifts forward from `current`.
    ///
    /// The walk's variance over N shifts is N × (drift variance + the
    /// variance the jumps contribute), and its mean drift per shift is the
    /// boom's expected contribution less the crash's — zero at the shipped
    /// balance, where the two are mirror images, and honoured anyway so a
    /// tuned-asymmetric market still reads correctly.
    public static func project(
        topicID: String,
        current: Double,
        weeks: Int,
        market: BalanceConfig.MarketBalance
    ) -> MarketForecast {
        let weeks = max(0, weeks)
        let span = Double(weeks)
        let meanPerWeek = market.boomChance * market.boomJump
            - market.crashChance * market.crashJump
        let variancePerWeek = market.driftSigma * market.driftSigma
            + market.boomChance * market.boomJump * market.boomJump
            + market.crashChance * market.crashJump * market.crashJump
        let sigma = (span * variancePerWeek).squareRoot()

        func clamp(_ value: Double) -> Double {
            min(market.multiplierMax, max(market.multiplierMin, value))
        }
        let expected = clamp(current + span * meanPerWeek)
        let quietWeek = max(0, 1 - market.boomChance - market.crashChance)

        return MarketForecast(
            topicID: topicID,
            weeksAhead: weeks,
            current: current,
            expected: expected,
            low: clamp(expected - sigma),
            high: clamp(expected + sigma),
            jumpChance: 1 - pow(quietWeek, span)
        )
    }
}

/// Per-topic market conditions, advanced by `MarketSystem` on its weekly
/// cadence. Topics missing from `topics` read as neutral, so saves written
/// before the market existed (and topics added by content updates) behave
/// exactly like the old flat market until the next shift fills them in.
public struct MarketState: Codable, Equatable, Sendable {
    /// Keyed by `TopicDef.id`.
    public var topics: [String: TopicMarket]
    /// Weekly multipliers per topic, oldest first, appended on every shift
    /// and capped at `BalanceConfig.marketHistoryWeeks`.
    public var history: [String: [Double]]
    /// Booms and crashes, newest last, capped at
    /// `BalanceConfig.marketEventLogCap`.
    public var recentEvents: [MarketEvent]
    /// The studio's standing in each topic, 0...`standing.maxStanding`,
    /// keyed by `TopicDef.id`. Built by everything the studio already does
    /// in a category — shipping into it, what the press made of that,
    /// patches, campaigns — and worn down every week the studio has
    /// nothing on the market there. A topic missing from the dictionary
    /// reads as 0, so a save written before standing existed starts every
    /// category from scratch.
    ///
    /// Lives on `MarketState` rather than `TopicMarket` deliberately:
    /// `MarketSystem` rebuilds the whole `TopicMarket` on every shift, and
    /// two years of a category is not something to hang off that.
    public var standing: [String: Double]

    public init(
        topics: [String: TopicMarket],
        history: [String: [Double]] = [:],
        recentEvents: [MarketEvent] = [],
        standing: [String: Double] = [:]
    ) {
        self.topics = topics
        self.history = history
        self.recentEvents = recentEvents
        self.standing = standing
    }

    /// Every topic starts neutral.
    public static let neutral = MarketState(topics: [:])

    /// The sales multiplier for a topic (1.0 when the topic is unknown).
    public func multiplier(for topicID: String) -> Double {
        topics[topicID]?.multiplier ?? 1.0
    }

    /// The player's slice of a topic's demand, multiplied into weekly
    /// sales by `ProductSystem`. 1.0 — the whole market — for any topic no
    /// rival is currently selling into, so a game with no rival products
    /// prices exactly as it always did.
    public func shareMultiplier(for topicID: String) -> Double {
        topics[topicID]?.playerShare ?? 1.0
    }

    /// The last shift delta for a topic (0 when the topic is unknown).
    public func lastChange(for topicID: String) -> Double {
        topics[topicID]?.lastChange ?? 0
    }

    /// The latest recorded multiplier minus the one four weeks earlier
    /// (0 with fewer than five weeks of history).
    public func trend(for topicID: String) -> Double {
        guard let samples = history[topicID], samples.count >= 5 else { return 0 }
        return samples[samples.count - 1] - samples[samples.count - 5]
    }

    /// The studio's standing in a topic (0 for a topic it has never
    /// touched).
    public func standing(for topicID: String) -> Double {
        self.standing[topicID] ?? 0
    }

    /// Whether the studio holds this category well enough to read its
    /// forward book — `standing.forecastThreshold` in the balance.
    public func holdsCategory(_ topicID: String, above threshold: Double) -> Bool {
        standing(for: topicID) >= threshold
    }

    /// The forward read on a topic, or nil where the studio has not earned
    /// one. This is the whole of what standing buys in phase one: the
    /// market walk becomes information you own, in the categories you hold
    /// and nowhere else.
    public func forecast(
        for topicID: String,
        market: BalanceConfig.MarketBalance
    ) -> MarketForecast? {
        guard holdsCategory(topicID, above: market.standing.forecastThreshold) else { return nil }
        return MarketForecast.project(
            topicID: topicID,
            current: multiplier(for: topicID),
            weeks: market.forecastHorizonWeeks,
            market: market
        )
    }
}

// MARK: - Codable

// Hand-written so the per-topic history encodes as an array of entries
// sorted by topic id — byte-identical for identical states whatever the
// encoder's key ordering (Foundation's JSONEncoder only orders object keys
// under `.sortedKeys`) — and so saves written before the history existed
// keep loading with an empty history and event log.

extension MarketState {
    private enum CodingKeys: String, CodingKey {
        case topics, history, recentEvents, standing
    }

    private struct HistoryEntry: Codable {
        var topicID: String
        var values: [Double]
    }

    private struct StandingEntry: Codable {
        var topicID: String
        var value: Double
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entries = try container.decodeIfPresent([HistoryEntry].self, forKey: .history) ?? []
        let standings = try container.decodeIfPresent([StandingEntry].self, forKey: .standing) ?? []
        self.init(
            topics: try container.decode([String: TopicMarket].self, forKey: .topics),
            history: Dictionary(entries.map { ($0.topicID, $0.values) }, uniquingKeysWith: { _, last in last }),
            recentEvents: try container.decodeIfPresent([MarketEvent].self, forKey: .recentEvents) ?? [],
            standing: Dictionary(standings.map { ($0.topicID, $0.value) }, uniquingKeysWith: { _, last in last })
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(topics, forKey: .topics)
        try container.encode(
            history.keys.sorted().map { HistoryEntry(topicID: $0, values: history[$0] ?? []) },
            forKey: .history
        )
        try container.encode(recentEvents, forKey: .recentEvents)
        // Sorted for the same reason as the history: identical states must
        // encode to identical bytes whatever the encoder's key ordering.
        try container.encode(
            standing.keys.sorted().map { StandingEntry(topicID: $0, value: standing[$0] ?? 0) },
            forKey: .standing
        )
    }
}
