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
    /// Average (coding+design)/2 skill the client expects from the people
    /// working the job. Delivering with a weaker crew reduces the payout
    /// (0 = the client has no expectations, the pre-quality behavior).
    public var requiredSkill: Double

    public init(
        id: UUID,
        clientName: String,
        requiredCodePts: Double,
        requiredDesignPts: Double,
        payout: Int,
        penalty: Int,
        deadlineDays: Int,
        expiresDay: Int,
        requiredSkill: Double = 0
    ) {
        self.id = id
        self.clientName = clientName
        self.requiredCodePts = requiredCodePts
        self.requiredDesignPts = requiredDesignPts
        self.payout = payout
        self.penalty = penalty
        self.deadlineDays = deadlineDays
        self.expiresDay = expiresDay
        self.requiredSkill = requiredSkill
    }
}

extension ContractOffer {
    private enum CodingKeys: String, CodingKey {
        case id, clientName, requiredCodePts, requiredDesignPts, payout, penalty
        case deadlineDays, expiresDay, requiredSkill
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            clientName: try container.decode(String.self, forKey: .clientName),
            requiredCodePts: try container.decode(Double.self, forKey: .requiredCodePts),
            requiredDesignPts: try container.decode(Double.self, forKey: .requiredDesignPts),
            payout: try container.decode(Int.self, forKey: .payout),
            penalty: try container.decode(Int.self, forKey: .penalty),
            deadlineDays: try container.decode(Int.self, forKey: .deadlineDays),
            expiresDay: try container.decode(Int.self, forKey: .expiresDay),
            requiredSkill: try container.decodeIfPresent(Double.self, forKey: .requiredSkill) ?? 0
        )
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
    /// Carried over from the offer (0 = no expectations).
    public var requiredSkill: Double
    /// Sum of each worker-day's (coding+design)/2 skill, and the number of
    /// worker-days recorded — their ratio is the crew's average skill on
    /// this job, graded against `requiredSkill` at delivery.
    public var skillDaySum: Double
    public var skillDays: Double

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
        acceptedDay: Int,
        requiredSkill: Double = 0,
        skillDaySum: Double = 0,
        skillDays: Double = 0
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
        self.requiredSkill = requiredSkill
        self.skillDaySum = skillDaySum
        self.skillDays = skillDays
    }

    /// Average skill of the crew so far (0 with no recorded worker-days).
    public var averageCrewSkill: Double {
        skillDays > 0 ? skillDaySum / skillDays : 0
    }

    /// Projected delivery quality 0...100 given the crew so far: the
    /// skill-to-expectation ratio scaled so meeting expectations scores 80
    /// and exceeding them by 25% scores 100. No expectations grade 100.
    public var projectedQuality: Int {
        guard requiredSkill > 0 else { return 100 }
        guard skillDays > 0 else { return 0 }
        return min(100, max(0, Int((averageCrewSkill / requiredSkill * 80).rounded())))
    }
}

extension ContractJob {
    private enum CodingKeys: String, CodingKey {
        case id, clientName, requiredCodePts, requiredDesignPts, progressCode, progressDesign
        case deadlineDay, payout, penalty, acceptedDay, requiredSkill, skillDaySum, skillDays
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            clientName: try container.decode(String.self, forKey: .clientName),
            requiredCodePts: try container.decode(Double.self, forKey: .requiredCodePts),
            requiredDesignPts: try container.decode(Double.self, forKey: .requiredDesignPts),
            progressCode: try container.decode(Double.self, forKey: .progressCode),
            progressDesign: try container.decode(Double.self, forKey: .progressDesign),
            deadlineDay: try container.decode(Int.self, forKey: .deadlineDay),
            payout: try container.decode(Int.self, forKey: .payout),
            penalty: try container.decode(Int.self, forKey: .penalty),
            acceptedDay: try container.decode(Int.self, forKey: .acceptedDay),
            requiredSkill: try container.decodeIfPresent(Double.self, forKey: .requiredSkill) ?? 0,
            skillDaySum: try container.decodeIfPresent(Double.self, forKey: .skillDaySum) ?? 0,
            skillDays: try container.decodeIfPresent(Double.self, forKey: .skillDays) ?? 0
        )
    }
}
