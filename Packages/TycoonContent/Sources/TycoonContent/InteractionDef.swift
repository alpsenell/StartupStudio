/// Iteration 11 — N2. One row of the people menu, as content.
///
/// Pure data: `TycoonContent` knows nothing about `GameState`, so the
/// strings here ("partner", "nice", "evening") are resolved into the
/// engine's own enums by `InteractionRule`. Everything except `id`,
/// `title` and `targets` has a default, so a row in `Interactions.json`
/// only lists what it actually changes.
///
/// JSON:
///
///     {
///       "id": "compliment",
///       "title": "Pay them a compliment",
///       "icon": "hand.thumbsup.fill",
///       "group": "nice",
///       "targets": ["partner", "child", "friend", "employee", "contact"],
///       "good": 4, "bad": -1, "baseChance": 0.82, "cooldownDays": 3,
///       "lines": {
///         "partner": { "good": ["…"], "bad": ["…"] }
///       }
///     }
public struct InteractionDef: Codable, Equatable, Sendable, Identifiable {
    /// The two bar deltas a rule can carry, either as its default pair or
    /// as a per-target-kind override.
    public struct Deltas: Codable, Equatable, Sendable {
        public var good: Double
        public var bad: Double

        public init(good: Double, bad: Double) {
            self.good = good
            self.bad = bad
        }
    }

    /// The outcome lines for one kind of person: what they say when it
    /// lands, and what they say when it does not.
    public struct Lines: Codable, Equatable, Sendable {
        public var good: [String]
        public var bad: [String]

        public init(good: [String] = [], bad: [String] = []) {
            self.good = good
            self.bad = bad
        }

        private enum CodingKeys: String, CodingKey { case good, bad }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
                good: try container.decodeIfPresent([String].self, forKey: .good) ?? [],
                bad: try container.decodeIfPresent([String].self, forKey: .bad) ?? []
            )
        }
    }

    /// Stable string id, e.g. "compliment". Also the second half of the
    /// cooldown key the engine writes into the save.
    public var id: String
    /// The words on the button, e.g. "Pay them a compliment".
    public var title: String
    /// SF Symbol for the row.
    public var icon: String
    /// "nice" / "mean" / "money" / "serious".
    public var group: String
    /// The target kinds this applies to: "partner", "child", "friend",
    /// "employee", "contact", "rival".
    public var targets: [String]
    /// Bar delta on a good roll, and on a bad one. A mean interaction is
    /// negative on both sides — the question is how negative.
    public var good: Double
    public var bad: Double
    /// Per-target-kind overrides, so one row can be worth +4 bond to a
    /// friend and +9 grudge to a rival.
    public var overrides: [String: Deltas]
    /// The chance of the good roll before the founder's conversation
    /// attribute and the current bar are read into it.
    public var baseChance: Double
    /// "free" / "evening". Money is `wallet`, and the two combine.
    public var cost: String
    /// Wallet delta, in dollars. Negative is money coming in.
    public var wallet: Int
    /// Days before this can be done to the same person again.
    public var cooldownDays: Int
    /// The bar window this is offered in: an affair needs rapport, an
    /// apology is pointless at a hundred.
    public var minBar: Double?
    public var maxBar: Double?
    /// Minimum relationship stage, for the partner's serious rows.
    public var minStage: String?
    /// Minimum child stage, for disowning one.
    public var minChildStage: String?
    /// Whether the app asks before doing it.
    public var confirms: Bool
    /// One line under the title, saying what this actually is.
    public var note: String?
    /// Outcome lines, keyed by target kind.
    public var lines: [String: Lines]

    public init(
        id: String,
        title: String,
        icon: String = "bubble.left.fill",
        group: String = "nice",
        targets: [String] = [],
        good: Double = 0,
        bad: Double = 0,
        overrides: [String: Deltas] = [:],
        baseChance: Double = 0.75,
        cost: String = "free",
        wallet: Int = 0,
        cooldownDays: Int = 0,
        minBar: Double? = nil,
        maxBar: Double? = nil,
        minStage: String? = nil,
        minChildStage: String? = nil,
        confirms: Bool = false,
        note: String? = nil,
        lines: [String: Lines] = [:]
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.group = group
        self.targets = targets
        self.good = good
        self.bad = bad
        self.overrides = overrides
        self.baseChance = baseChance
        self.cost = cost
        self.wallet = wallet
        self.cooldownDays = cooldownDays
        self.minBar = minBar
        self.maxBar = maxBar
        self.minStage = minStage
        self.minChildStage = minChildStage
        self.confirms = confirms
        self.note = note
        self.lines = lines
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, icon, group, targets, good, bad, overrides, baseChance
        case cost, wallet, cooldownDays, minBar, maxBar, minStage, minChildStage
        case confirms, note, lines
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            title: try container.decode(String.self, forKey: .title),
            icon: try container.decodeIfPresent(String.self, forKey: .icon) ?? "bubble.left.fill",
            group: try container.decodeIfPresent(String.self, forKey: .group) ?? "nice",
            targets: try container.decodeIfPresent([String].self, forKey: .targets) ?? [],
            good: try container.decodeIfPresent(Double.self, forKey: .good) ?? 0,
            bad: try container.decodeIfPresent(Double.self, forKey: .bad) ?? 0,
            overrides: try container.decodeIfPresent(
                [String: Deltas].self, forKey: .overrides
            ) ?? [:],
            baseChance: try container.decodeIfPresent(Double.self, forKey: .baseChance) ?? 0.75,
            cost: try container.decodeIfPresent(String.self, forKey: .cost) ?? "free",
            wallet: try container.decodeIfPresent(Int.self, forKey: .wallet) ?? 0,
            cooldownDays: try container.decodeIfPresent(Int.self, forKey: .cooldownDays) ?? 0,
            minBar: try container.decodeIfPresent(Double.self, forKey: .minBar),
            maxBar: try container.decodeIfPresent(Double.self, forKey: .maxBar),
            minStage: try container.decodeIfPresent(String.self, forKey: .minStage),
            minChildStage: try container.decodeIfPresent(String.self, forKey: .minChildStage),
            confirms: try container.decodeIfPresent(Bool.self, forKey: .confirms) ?? false,
            note: try container.decodeIfPresent(String.self, forKey: .note),
            lines: try container.decodeIfPresent([String: Lines].self, forKey: .lines) ?? [:]
        )
    }
}

/// The whole of `Interactions.json`.
public struct InteractionCatalog: Codable, Equatable, Sendable {
    public var interactions: [InteractionDef]

    public init(interactions: [InteractionDef] = []) {
        self.interactions = interactions
    }

    public static let empty = InteractionCatalog()

    /// O(n) is fine: the catalog is twenty-odd rows and the menu reads it
    /// once per sheet.
    public func interaction(_ id: String) -> InteractionDef? {
        interactions.first { $0.id == id }
    }
}
