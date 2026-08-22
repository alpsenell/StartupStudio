import Foundation

/// A client job on the weekly offer sheet. `ContractSystem` rolls a fresh
/// sheet every `contractOfferRefreshDays`; an un-accepted offer vanishes
/// after `expiresDay` (which coincides with the next refresh).
public struct ContractOffer: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public var clientName: String
    public var requiredCodePts: Double
    public var requiredDesignPts: Double
    public var payout: Int
    public var penalty: Int
    /// Days allowed AFTER acceptance.
    public var deadlineDays: Int
    /// Offer vanishes after this absolute day.
    public var expiresDay: Int

    public init(
        id: UUID,
        clientName: String,
        requiredCodePts: Double,
        requiredDesignPts: Double,
        payout: Int,
        penalty: Int,
        deadlineDays: Int,
        expiresDay: Int
    ) {
        self.id = id
        self.clientName = clientName
        self.requiredCodePts = requiredCodePts
        self.requiredDesignPts = requiredDesignPts
        self.payout = payout
        self.penalty = penalty
        self.deadlineDays = deadlineDays
        self.expiresDay = expiresDay
    }
}

/// An accepted contract, worked by employees assigned `.contract(id)`.
/// It keeps the offer's id. Completion pays out the day both point pools
/// clear; blowing past `deadlineDay` costs the penalty instead.
public struct ContractJob: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public var clientName: String
    public var requiredCodePts: Double
    public var requiredDesignPts: Double
    public var progressCode: Double
    public var progressDesign: Double
    /// Absolute day.
    public var deadlineDay: Int
    public var payout: Int
    public var penalty: Int
    public var acceptedDay: Int

    public init(
        id: UUID,
        clientName: String,
        requiredCodePts: Double,
        requiredDesignPts: Double,
        progressCode: Double,
        progressDesign: Double,
        deadlineDay: Int,
        payout: Int,
        penalty: Int,
        acceptedDay: Int
    ) {
        self.id = id
        self.clientName = clientName
        self.requiredCodePts = requiredCodePts
        self.requiredDesignPts = requiredDesignPts
        self.progressCode = progressCode
        self.progressDesign = progressDesign
        self.deadlineDay = deadlineDay
        self.payout = payout
        self.penalty = penalty
        self.acceptedDay = acceptedDay
    }
}
