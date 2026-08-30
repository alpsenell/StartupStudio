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

    public init(
        topics: [String: TopicMarket],
        history: [String: [Double]] = [:],
        recentEvents: [MarketEvent] = []
    ) {
        self.topics = topics
        self.history = history
        self.recentEvents = recentEvents
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
}

// MARK: - Codable

// Hand-written so the per-topic history encodes as an array of entries
// sorted by topic id — byte-identical for identical states whatever the
// encoder's key ordering (Foundation's JSONEncoder only orders object keys
// under `.sortedKeys`) — and so saves written before the history existed
// keep loading with an empty history and event log.

extension MarketState {
    private enum CodingKeys: String, CodingKey {
        case topics, history, recentEvents
    }

    private struct HistoryEntry: Codable {
        var topicID: String
        var values: [Double]
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entries = try container.decodeIfPresent([HistoryEntry].self, forKey: .history) ?? []
        self.init(
            topics: try container.decode([String: TopicMarket].self, forKey: .topics),
            history: Dictionary(entries.map { ($0.topicID, $0.values) }, uniquingKeysWith: { _, last in last }),
            recentEvents: try container.decodeIfPresent([MarketEvent].self, forKey: .recentEvents) ?? []
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
    }
}
