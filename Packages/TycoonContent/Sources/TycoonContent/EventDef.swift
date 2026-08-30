/// A company event: something that happens to the studio, with or without
/// a decision attached.
///
/// Version 2 is a strict superset of version 1. A def written before
/// choices existed —
///
///     { "id": "blog_feature", "headline": "...",
///       "impact": { "type": "hypeDeltaOnActiveProduct", "amount": 10 },
///       "weight": 4 }
///
/// — still decodes, is eligible everywhere, and applies exactly the same
/// single impact. Everything below `weight` is optional.
///
/// Static content: game saves reference events by their stable `id`.
public struct EventDef: Codable, Equatable, Sendable, Identifiable {
    /// The version-1 single impact. Kept verbatim so old catalogs decode;
    /// new defs use `effects` instead, which is a superset.
    ///
    ///     { "type": "cashDelta",                 "amount": -800 }
    ///     { "type": "reputationDelta",           "amount": 3 }
    ///     { "type": "hypeDeltaOnActiveProduct",  "amount": 10 }
    ///
    /// Unknown `"type"` values fail decoding with a `DecodingError`.
    public enum Impact: Codable, Equatable, Sendable {
        case cashDelta(amount: Int)
        case reputationDelta(amount: Double)
        case hypeDeltaOnActiveProduct(amount: Double)

        private enum CodingKeys: String, CodingKey {
            case type
            case amount
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            switch type {
            case "cashDelta":
                self = .cashDelta(amount: try container.decode(Int.self, forKey: .amount))
            case "reputationDelta":
                self = .reputationDelta(amount: try container.decode(Double.self, forKey: .amount))
            case "hypeDeltaOnActiveProduct":
                self = .hypeDeltaOnActiveProduct(amount: try container.decode(Double.self, forKey: .amount))
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "Unknown EventDef.Impact type \"\(type)\""
                )
            }
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .cashDelta(let amount):
                try container.encode("cashDelta", forKey: .type)
                try container.encode(amount, forKey: .amount)
            case .reputationDelta(let amount):
                try container.encode("reputationDelta", forKey: .type)
                try container.encode(amount, forKey: .amount)
            case .hypeDeltaOnActiveProduct(let amount):
                try container.encode("hypeDeltaOnActiveProduct", forKey: .type)
                try container.encode(amount, forKey: .amount)
            }
        }

        /// The version-2 effect this version-1 impact is shorthand for.
        public var asEffect: EventEffect {
            switch self {
            case .cashDelta(let amount): .cash(amount: amount)
            case .reputationDelta(let amount): .reputation(amount: amount)
            case .hypeDeltaOnActiveProduct(let amount): .hype(amount: amount)
            }
        }
    }

    /// Stable string id, e.g. "server_outage".
    public var id: String
    /// The headline the journal shows, e.g. "Your hosting provider has a
    /// very bad Tuesday."
    public var headline: String
    /// The paragraph shown in the decision sheet. Choice-less events don't
    /// need one.
    public var body: String?
    /// The version-1 single impact, applied before `effects`.
    public var impact: Impact?
    /// Everything else this event does when it fires with no choices, or
    /// unconditionally before the chosen option's effects.
    public var effects: [EventEffect]
    /// Relative pick probability among the eligible defs, >= 1.
    public var weight: Int
    /// What has to be true for this event to be drawn.
    public var requires: EventRequirements?
    /// The answers offered. Empty means the event just happens.
    public var choices: [EventChoice]
    /// Days before this event can be drawn again. 0 = no cooldown.
    public var cooldownDays: Int
    /// Fires at most once per run.
    public var once: Bool
    /// Icon/tint/journal bucket.
    public var category: EventCategory
    /// How loudly it interrupts: "quiet", "info", "notable", "critical".
    /// Absent means the engine grades it (choices are critical, the rest
    /// notable).
    public var severity: String?
    /// How long the player has to answer a choice. Default 5 days.
    public var respondByDays: Int
    /// Which option the deadline picks for a player who never answered.
    /// Defaults to the last one, which is written to be the passive one.
    public var autoChoiceIndex: Int?
    /// Set to true on the follow-up halves of a storyline so the roll
    /// never draws them directly — they arrive only when an earlier choice
    /// schedules them.
    public var followUpOnly: Bool

    public init(
        id: String,
        headline: String,
        body: String? = nil,
        impact: Impact? = nil,
        effects: [EventEffect] = [],
        weight: Int,
        requires: EventRequirements? = nil,
        choices: [EventChoice] = [],
        cooldownDays: Int = 0,
        once: Bool = false,
        category: EventCategory = .press,
        severity: String? = nil,
        respondByDays: Int = 5,
        autoChoiceIndex: Int? = nil,
        followUpOnly: Bool = false
    ) {
        self.id = id
        self.headline = headline
        self.body = body
        self.impact = impact
        self.effects = effects
        self.weight = weight
        self.requires = requires
        self.choices = choices
        self.cooldownDays = cooldownDays
        self.once = once
        self.category = category
        self.severity = severity
        self.respondByDays = respondByDays
        self.autoChoiceIndex = autoChoiceIndex
        self.followUpOnly = followUpOnly
    }

    /// Every effect the event applies on its own, version-1 impact first.
    public var unconditionalEffects: [EventEffect] {
        (impact.map { [$0.asEffect] } ?? []) + effects
    }

    private enum CodingKeys: String, CodingKey {
        case id, headline, body, impact, effects, weight, requires, choices
        case cooldownDays, once, category, severity, respondByDays, autoChoiceIndex
        case followUpOnly
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            headline: try container.decode(String.self, forKey: .headline),
            body: try container.decodeIfPresent(String.self, forKey: .body),
            impact: try container.decodeIfPresent(Impact.self, forKey: .impact),
            effects: try container.decodeIfPresent([EventEffect].self, forKey: .effects) ?? [],
            weight: try container.decode(Int.self, forKey: .weight),
            requires: try container.decodeIfPresent(EventRequirements.self, forKey: .requires),
            choices: try container.decodeIfPresent([EventChoice].self, forKey: .choices) ?? [],
            cooldownDays: try container.decodeIfPresent(Int.self, forKey: .cooldownDays) ?? 0,
            once: try container.decodeIfPresent(Bool.self, forKey: .once) ?? false,
            category: try container.decodeIfPresent(EventCategory.self, forKey: .category) ?? .press,
            severity: try container.decodeIfPresent(String.self, forKey: .severity),
            respondByDays: try container.decodeIfPresent(Int.self, forKey: .respondByDays) ?? 5,
            autoChoiceIndex: try container.decodeIfPresent(Int.self, forKey: .autoChoiceIndex),
            followUpOnly: try container.decodeIfPresent(Bool.self, forKey: .followUpOnly) ?? false
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(headline, forKey: .headline)
        try container.encodeIfPresent(body, forKey: .body)
        try container.encodeIfPresent(impact, forKey: .impact)
        if !effects.isEmpty { try container.encode(effects, forKey: .effects) }
        try container.encode(weight, forKey: .weight)
        try container.encodeIfPresent(requires, forKey: .requires)
        if !choices.isEmpty { try container.encode(choices, forKey: .choices) }
        if cooldownDays != 0 { try container.encode(cooldownDays, forKey: .cooldownDays) }
        if once { try container.encode(once, forKey: .once) }
        try container.encode(category, forKey: .category)
        try container.encodeIfPresent(severity, forKey: .severity)
        try container.encode(respondByDays, forKey: .respondByDays)
        try container.encodeIfPresent(autoChoiceIndex, forKey: .autoChoiceIndex)
        if followUpOnly { try container.encode(followUpOnly, forKey: .followUpOnly) }
    }
}
