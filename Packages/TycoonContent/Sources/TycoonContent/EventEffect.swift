/// Who an employee-scoped effect lands on.
///
/// The pick is resolved by the engine against the current roster. `random`
/// is the only one that draws an RNG word — the others are pure functions
/// of the roster, so a def that avoids `random` costs no determinism
/// budget.
public enum EmployeePick: String, Codable, Equatable, Sendable, CaseIterable {
    /// One hired employee, drawn from the seeded stream.
    case random
    /// The unhappiest hired employee (ties broken by id).
    case lowestMorale
    /// The most skilled hired employee (ties broken by id).
    case highestSkill
    /// The longest-serving hired employee (ties broken by id).
    case longestServing
    /// Everyone on payroll except the founder.
    case everyone
}

/// One consequence an event, a choice, or a follow-up applies to the game
/// state.
///
/// JSON format (human-editable, discriminated by a `"type"` field). Every
/// field beyond `"type"` is optional and defaults to zero / `nil`, so a
/// hand-written catalog stays terse:
///
///     { "type": "cash",           "amount": -800 }
///     { "type": "reputation",     "amount": 3 }
///     { "type": "hype",           "amount": 10 }
///     { "type": "moraleAll",      "amount": -6 }
///     { "type": "morale",         "amount": -10, "pick": "lowestMorale" }
///     { "type": "market",         "topicID": "fitness", "amount": 0.15 }
///     { "type": "loan",           "amount": 5000 }
///     { "type": "founderMeters",  "mood": -8, "energy": -5, "wallet": -400 }
///     { "type": "away",           "days": 3, "reason": "Deposition" }
///     { "type": "cold",           "days": 4 }
///     { "type": "flag",           "flag": "journalist_friendly" }
///     { "type": "skill",          "skill": "coding", "amount": 4, "pick": "everyone" }
///
/// Unknown `"type"` values fail decoding with a `DecodingError` — a typo in
/// a catalog is a build-time-ish failure, not a silent no-op.
public enum EventEffect: Codable, Equatable, Sendable {
    /// Company cash, posted to the ledger under `.other`.
    case cash(amount: Int)
    /// Company reputation, clamped to 0...100.
    case reputation(amount: Double)
    /// Hype on the product in development; a silent no-op with none.
    case hype(amount: Double)
    /// Morale for every hired employee.
    case moraleAll(amount: Double)
    /// Morale for one picked employee.
    case morale(amount: Double, pick: EmployeePick)
    /// Loyalty for one picked employee.
    case loyalty(amount: Double, pick: EmployeePick)
    /// A nudge to one topic's market multiplier.
    case market(topicID: String, amount: Double)
    /// Takes on (positive) or forgives (negative) company debt. Cash moves
    /// with it.
    case loan(amount: Int)
    /// The founder's meters and personal wallet.
    case founderMeters(
        energy: Double, health: Double, mood: Double, relationships: Double, wallet: Int
    )
    /// The founder is out of the office for `days`.
    case away(days: Int, reason: String)
    /// The founder catches something for `days`.
    case cold(days: Int)
    /// Raises a narrative flag other events can require.
    case flag(String)
    /// Clears a narrative flag.
    case clearFlag(String)
    /// A skill bump for one picked employee (or everyone).
    case skill(skill: SkillName, amount: Double, pick: EmployeePick)
    /// Banked research points.
    case research(amount: Double)

    /// Which skill a `skill` effect moves.
    public enum SkillName: String, Codable, Equatable, Sendable, CaseIterable {
        case coding, design, marketing
    }

    private enum CodingKeys: String, CodingKey {
        case type, amount, pick, topicID, days, reason, flag, skill
        case energy, health, mood, relationships, wallet
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        func amount() throws -> Double {
            try container.decodeIfPresent(Double.self, forKey: .amount) ?? 0
        }
        func pick() throws -> EmployeePick {
            try container.decodeIfPresent(EmployeePick.self, forKey: .pick) ?? .random
        }
        switch type {
        case "cash":
            self = .cash(amount: try container.decodeIfPresent(Int.self, forKey: .amount) ?? 0)
        case "reputation":
            self = .reputation(amount: try amount())
        case "hype":
            self = .hype(amount: try amount())
        case "moraleAll":
            self = .moraleAll(amount: try amount())
        case "morale":
            self = .morale(amount: try amount(), pick: try pick())
        case "loyalty":
            self = .loyalty(amount: try amount(), pick: try pick())
        case "market":
            self = .market(
                topicID: try container.decode(String.self, forKey: .topicID),
                amount: try amount()
            )
        case "loan":
            self = .loan(amount: try container.decodeIfPresent(Int.self, forKey: .amount) ?? 0)
        case "founderMeters":
            self = .founderMeters(
                energy: try container.decodeIfPresent(Double.self, forKey: .energy) ?? 0,
                health: try container.decodeIfPresent(Double.self, forKey: .health) ?? 0,
                mood: try container.decodeIfPresent(Double.self, forKey: .mood) ?? 0,
                relationships: try container.decodeIfPresent(Double.self, forKey: .relationships) ?? 0,
                wallet: try container.decodeIfPresent(Int.self, forKey: .wallet) ?? 0
            )
        case "away":
            self = .away(
                days: try container.decodeIfPresent(Int.self, forKey: .days) ?? 0,
                reason: try container.decodeIfPresent(String.self, forKey: .reason) ?? "Away"
            )
        case "cold":
            self = .cold(days: try container.decodeIfPresent(Int.self, forKey: .days) ?? 0)
        case "flag":
            self = .flag(try container.decode(String.self, forKey: .flag))
        case "clearFlag":
            self = .clearFlag(try container.decode(String.self, forKey: .flag))
        case "skill":
            self = .skill(
                skill: try container.decode(SkillName.self, forKey: .skill),
                amount: try amount(),
                pick: try pick()
            )
        case "research":
            self = .research(amount: try amount())
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Unknown EventEffect type \"\(type)\""
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .cash(let amount):
            try container.encode("cash", forKey: .type)
            try container.encode(amount, forKey: .amount)
        case .reputation(let amount):
            try container.encode("reputation", forKey: .type)
            try container.encode(amount, forKey: .amount)
        case .hype(let amount):
            try container.encode("hype", forKey: .type)
            try container.encode(amount, forKey: .amount)
        case .moraleAll(let amount):
            try container.encode("moraleAll", forKey: .type)
            try container.encode(amount, forKey: .amount)
        case .morale(let amount, let pick):
            try container.encode("morale", forKey: .type)
            try container.encode(amount, forKey: .amount)
            try container.encode(pick, forKey: .pick)
        case .loyalty(let amount, let pick):
            try container.encode("loyalty", forKey: .type)
            try container.encode(amount, forKey: .amount)
            try container.encode(pick, forKey: .pick)
        case .market(let topicID, let amount):
            try container.encode("market", forKey: .type)
            try container.encode(topicID, forKey: .topicID)
            try container.encode(amount, forKey: .amount)
        case .loan(let amount):
            try container.encode("loan", forKey: .type)
            try container.encode(amount, forKey: .amount)
        case .founderMeters(let energy, let health, let mood, let relationships, let wallet):
            try container.encode("founderMeters", forKey: .type)
            try container.encode(energy, forKey: .energy)
            try container.encode(health, forKey: .health)
            try container.encode(mood, forKey: .mood)
            try container.encode(relationships, forKey: .relationships)
            try container.encode(wallet, forKey: .wallet)
        case .away(let days, let reason):
            try container.encode("away", forKey: .type)
            try container.encode(days, forKey: .days)
            try container.encode(reason, forKey: .reason)
        case .cold(let days):
            try container.encode("cold", forKey: .type)
            try container.encode(days, forKey: .days)
        case .flag(let flag):
            try container.encode("flag", forKey: .type)
            try container.encode(flag, forKey: .flag)
        case .clearFlag(let flag):
            try container.encode("clearFlag", forKey: .type)
            try container.encode(flag, forKey: .flag)
        case .skill(let skill, let amount, let pick):
            try container.encode("skill", forKey: .type)
            try container.encode(skill, forKey: .skill)
            try container.encode(amount, forKey: .amount)
            try container.encode(pick, forKey: .pick)
        case .research(let amount):
            try container.encode("research", forKey: .type)
            try container.encode(amount, forKey: .amount)
        }
    }
}

extension EventEffect {
    /// Whether applying this effect draws a word from the seeded stream.
    /// The narrative system uses it to keep the draw count of a purely
    /// legacy-shaped catalog at exactly what it was before choices
    /// existed.
    public var drawsRandomly: Bool {
        switch self {
        case .morale(_, let pick), .loyalty(_, let pick), .skill(_, _, let pick):
            pick == .random
        default:
            false
        }
    }

    /// A one-line, player-facing summary, e.g. "−$800" or "Team morale +6".
    /// Used by the content tests and by the app when a choice has no
    /// hand-written `detail`.
    public var summary: String {
        switch self {
        case .cash(let amount):
            "\(amount < 0 ? "−" : "+")$\(abs(amount))"
        case .reputation(let amount):
            "Reputation \(signed(amount))"
        case .hype(let amount):
            "Hype \(signed(amount))"
        case .moraleAll(let amount):
            "Team morale \(signed(amount))"
        case .morale(let amount, _):
            "Morale \(signed(amount))"
        case .loyalty(let amount, _):
            "Loyalty \(signed(amount))"
        case .market(let topicID, let amount):
            "\(topicID) demand \(signed(amount * 100))%"
        case .loan(let amount):
            amount >= 0 ? "Debt +$\(amount)" : "Debt −$\(abs(amount))"
        case .founderMeters(let energy, let health, let mood, let relationships, let wallet):
            founderSummary(energy, health, mood, relationships, wallet)
        case .away(let days, _):
            "Away \(days) day\(days == 1 ? "" : "s")"
        case .cold(let days):
            "Under the weather \(days) day\(days == 1 ? "" : "s")"
        case .flag, .clearFlag:
            "Changes what happens next"
        case .skill(let skill, let amount, _):
            "\(skill.rawValue.capitalized) \(signed(amount))"
        case .research(let amount):
            "Research \(signed(amount))"
        }
    }

    private func signed(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        let text = rounded == rounded.rounded()
            ? String(Int(rounded.rounded()))
            : String(format: "%.1f", rounded)
        return rounded < 0 ? "−\(text.dropFirst())" : "+\(text)"
    }

    private func founderSummary(
        _ energy: Double, _ health: Double, _ mood: Double,
        _ relationships: Double, _ wallet: Int
    ) -> String {
        var parts: [String] = []
        if energy != 0 { parts.append("Energy \(signed(energy))") }
        if health != 0 { parts.append("Health \(signed(health))") }
        if mood != 0 { parts.append("Mood \(signed(mood))") }
        if relationships != 0 { parts.append("Relationships \(signed(relationships))") }
        if wallet != 0 { parts.append("Wallet \(wallet < 0 ? "−" : "+")$\(abs(wallet))") }
        return parts.isEmpty ? "No change" : parts.joined(separator: " · ")
    }
}
