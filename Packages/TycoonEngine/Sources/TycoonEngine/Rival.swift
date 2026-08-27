import Foundation

/// A simulated competitor studio. Rivals are deliberately abstract — a
/// strength score, a reputation, and one or two focus topics — evolved by
/// `RivalSystem` on a weekly cadence rather than simulated in detail.
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

    public init(
        id: UUID,
        name: String,
        strength: Double,
        reputation: Double,
        focusTopicIDs: [String],
        hqDistrict: String? = nil,
        lastShippedDay: Int? = nil,
        foundedDay: Int,
        appearanceSeed: UInt64
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
    }

    /// Rough headcount shown in the UI, derived from strength.
    public var headcount: Int { max(2, Int((strength / 5).rounded())) }

    /// What buying this rival's company is worth on the open market.
    public func valuation(balance: BalanceConfig) -> Int {
        Int((strength * balance.rivals.valuationPerStrength * (1 + reputation / 100)).rounded())
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

/// Everything about the competitive landscape, advanced by `RivalSystem`.
public struct RivalsState: Codable, Equatable, Sendable {
    public var rivals: [Rival]
    public var pendingPoach: PoachOffer?
    public var pendingBuyout: BuyoutOffer?
    /// The last day a poach attempt fired (global cooldown across rivals).
    public var lastPoachDay: Int?
    public var lastBuyoutDay: Int?

    public init(
        rivals: [Rival],
        pendingPoach: PoachOffer? = nil,
        pendingBuyout: BuyoutOffer? = nil,
        lastPoachDay: Int? = nil,
        lastBuyoutDay: Int? = nil
    ) {
        self.rivals = rivals
        self.pendingPoach = pendingPoach
        self.pendingBuyout = pendingBuyout
        self.lastPoachDay = lastPoachDay
        self.lastBuyoutDay = lastBuyoutDay
    }

    /// Pre-rivals saves start here; `RivalSystem` founds the field on its
    /// first tick.
    public static let empty = RivalsState(rivals: [])

    public func rival(id: UUID) -> Rival? {
        rivals.first { $0.id == id }
    }
}
