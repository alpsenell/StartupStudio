/// A random news event that can hit the studio.
///
/// Static content — game saves reference events by their stable `id`.
public struct EventDef: Codable, Equatable, Sendable, Identifiable {
    /// What the event does to the studio when it fires.
    ///
    /// JSON format (human-editable, discriminated by a `"type"` field):
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
    }

    /// Stable string id, e.g. "server_outage".
    public var id: String
    /// Newsfeed headline, e.g. "A tech blog features your studio!".
    public var headline: String
    /// What happens when the event fires.
    public var impact: Impact
    /// Relative pick probability, >= 1.
    public var weight: Int

    public init(id: String, headline: String, impact: Impact, weight: Int) {
        self.id = id
        self.headline = headline
        self.impact = impact
        self.weight = weight
    }
}
