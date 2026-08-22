import TycoonContent

/// Research progress: banked points, completed tech, and the node being
/// researched. Tech effects are always derived from `unlocked` on demand —
/// never cached anywhere in state.
public struct ResearchState: Codable, Equatable, Sendable {
    /// RP generated but not yet invested in a node.
    public var banked: Double
    /// Completed `TechNode` ids.
    public var unlocked: Set<String>
    /// The node currently being researched, if any.
    public var activeNodeID: String?
    /// RP invested in the active node.
    public var activeProgress: Double

    public init(banked: Double, unlocked: Set<String>, activeNodeID: String?, activeProgress: Double) {
        self.banked = banked
        self.unlocked = unlocked
        self.activeNodeID = activeNodeID
        self.activeProgress = activeProgress
    }

    /// A fresh, empty research state for `GameState.newGame`.
    static let initial = ResearchState(banked: 0, unlocked: [], activeNodeID: nil, activeProgress: 0)

    // MARK: - Codable

    // Hand-written so `unlocked` encodes in sorted order: `Set` iteration
    // order is not stable across processes, and saves (like the determinism
    // tests) rely on byte-identical JSON for identical states.

    private enum CodingKeys: String, CodingKey {
        case banked, unlocked, activeNodeID, activeProgress
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        banked = try container.decode(Double.self, forKey: .banked)
        unlocked = Set(try container.decode([String].self, forKey: .unlocked))
        activeNodeID = try container.decodeIfPresent(String.self, forKey: .activeNodeID)
        activeProgress = try container.decode(Double.self, forKey: .activeProgress)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(banked, forKey: .banked)
        try container.encode(unlocked.sorted(), forKey: .unlocked)
        try container.encodeIfPresent(activeNodeID, forKey: .activeNodeID)
        try container.encode(activeProgress, forKey: .activeProgress)
    }
}

// MARK: - Derived tech effects

extension GameState {
    /// Whether a product type can be started: available from the start, or
    /// unlocked by a completed tech node with `.unlockProductType(id:)`.
    public func isProductTypeUnlocked(_ typeID: String, content: ContentCatalog) -> Bool {
        if content.productType(typeID)?.unlockedFromStart == true { return true }
        return content.techTree.contains { node in
            guard research.unlocked.contains(node.id),
                  case .unlockProductType(let id) = node.effect else { return false }
            return id == typeID
        }
    }

    /// Whether a marketing campaign kind has been unlocked by a completed
    /// tech node with `.unlockCampaignKind(id:)` (consumed in Milestone 5).
    public func isCampaignKindUnlocked(_ kindID: String, content: ContentCatalog) -> Bool {
        content.techTree.contains { node in
            guard research.unlocked.contains(node.id),
                  case .unlockCampaignKind(let id) = node.effect else { return false }
            return id == kindID
        }
    }

    /// 1 + the summed `qualityMultiplier` bonuses of every unlocked tech
    /// node, capped at `cap` (`balance.techQualityMultiplierCap`; the
    /// default mirrors the shipped `Balance.json`).
    public func qualityTechMultiplier(content: ContentCatalog, cap: Double = 1.5) -> Double {
        var bonus = 0.0
        for node in content.techTree where research.unlocked.contains(node.id) {
            if case .qualityMultiplier(let value) = node.effect { bonus += value }
        }
        return min(cap, 1 + bonus)
    }

    /// 1 + the summed `devSpeedMultiplier` bonuses of every unlocked tech
    /// node. Uncapped. Boosts product and contract point output — never RP
    /// generation itself.
    public func devSpeedTechMultiplier(content: ContentCatalog) -> Double {
        var bonus = 0.0
        for node in content.techTree where research.unlocked.contains(node.id) {
            if case .devSpeedMultiplier(let value) = node.effect { bonus += value }
        }
        return 1 + bonus
    }
}
