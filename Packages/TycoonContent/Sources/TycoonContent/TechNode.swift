/// One node of the research tech tree.
///
/// Static content — game saves reference tech nodes by their stable `id`.
public struct TechNode: Codable, Equatable, Sendable, Identifiable {
    /// What researching this node does.
    ///
    /// JSON format (human-editable, discriminated by a `"type"` field):
    ///
    ///     { "type": "unlockProductType",  "id": "desktop_tool" }
    ///     { "type": "qualityMultiplier",  "bonus": 0.05 }
    ///     { "type": "devSpeedMultiplier", "bonus": 0.10 }
    ///     { "type": "unlockCampaignKind", "id": "press_release" }
    ///
    /// Unknown `"type"` values fail decoding with a `DecodingError`.
    public enum Effect: Codable, Equatable, Sendable {
        case unlockProductType(id: String)
        case qualityMultiplier(bonus: Double)
        case devSpeedMultiplier(bonus: Double)
        case unlockCampaignKind(id: String)

        private enum CodingKeys: String, CodingKey {
            case type
            case id
            case bonus
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            switch type {
            case "unlockProductType":
                self = .unlockProductType(id: try container.decode(String.self, forKey: .id))
            case "qualityMultiplier":
                self = .qualityMultiplier(bonus: try container.decode(Double.self, forKey: .bonus))
            case "devSpeedMultiplier":
                self = .devSpeedMultiplier(bonus: try container.decode(Double.self, forKey: .bonus))
            case "unlockCampaignKind":
                self = .unlockCampaignKind(id: try container.decode(String.self, forKey: .id))
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "Unknown TechNode.Effect type \"\(type)\""
                )
            }
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .unlockProductType(let id):
                try container.encode("unlockProductType", forKey: .type)
                try container.encode(id, forKey: .id)
            case .qualityMultiplier(let bonus):
                try container.encode("qualityMultiplier", forKey: .type)
                try container.encode(bonus, forKey: .bonus)
            case .devSpeedMultiplier(let bonus):
                try container.encode("devSpeedMultiplier", forKey: .type)
                try container.encode(bonus, forKey: .bonus)
            case .unlockCampaignKind(let id):
                try container.encode("unlockCampaignKind", forKey: .type)
                try container.encode(id, forKey: .id)
            }
        }
    }

    /// Stable string id, e.g. "game_engine".
    public var id: String
    /// Display name.
    public var name: String
    /// Display grouping, 1...5.
    public var tier: Int
    /// Research point cost.
    public var researchCost: Double
    /// Extra dollar cost, often 0.
    public var cashCost: Int
    /// Ids of TechNodes that must be researched first; each on a strictly lower tier.
    public var prerequisites: [String]
    /// The payoff for researching this node.
    public var effect: Effect
    /// One-line flavor text.
    public var blurb: String

    public init(
        id: String,
        name: String,
        tier: Int,
        researchCost: Double,
        cashCost: Int,
        prerequisites: [String],
        effect: Effect,
        blurb: String
    ) {
        self.id = id
        self.name = name
        self.tier = tier
        self.researchCost = researchCost
        self.cashCost = cashCost
        self.prerequisites = prerequisites
        self.effect = effect
        self.blurb = blurb
    }
}
