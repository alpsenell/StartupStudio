import Foundation

/// The five things a founder is personally good — or bad — at.
///
/// These are *the founder's own* attributes, distinct from `SkillSet`,
/// which is what a hired employee brings to a build. An employee's coding
/// skill turns into code points; a founder's `technical` turns into how
/// much their own day is worth and how much of what the team does they can
/// actually judge. Each is 0...100 and starts low: a first-time founder is
/// not good at any of this yet.
///
/// Every attribute has exactly one job in the simulation, so a player can
/// read the sheet and know what training it buys them:
///
/// - `conversation` — talking to people. Networking rapport, how far a
///   coffee with an employee goes, whether the person at the party takes
///   your call.
/// - `technical` — building. Scales the founder's own output and takes the
///   edge off the bugs they write.
/// - `marketKnowledge` — knowing what sells. Scales the sales a released
///   product finds.
/// - `leadership` — running a team. Raises the morale the whole roster
///   settles at.
/// - `finance` — money and terms. Scales what a delivered contract pays.
public enum FounderSkill: String, Codable, Equatable, Sendable, CaseIterable {
    case conversation, technical, marketKnowledge, leadership, finance

    public var displayName: String {
        switch self {
        case .conversation: "Conversation"
        case .technical: "Technical"
        case .marketKnowledge: "Market Sense"
        case .leadership: "Leadership"
        case .finance: "Finance"
        }
    }

    /// One line saying what training this buys, in the player's terms.
    public var effectSummary: String {
        switch self {
        case .conversation: "Rapport at events, and how far a chat with your team goes"
        case .technical: "Your own build output, and fewer bugs in your code"
        case .marketKnowledge: "Sales your released products find"
        case .leadership: "The morale your whole team settles at"
        case .finance: "What a delivered contract actually pays"
        }
    }
}

/// The founder's five attributes, each 0...100.
public struct FounderSkillSet: Codable, Equatable, Sendable {
    public var conversation: Double
    public var technical: Double
    public var marketKnowledge: Double
    public var leadership: Double
    public var finance: Double

    public init(
        conversation: Double,
        technical: Double,
        marketKnowledge: Double,
        leadership: Double,
        finance: Double
    ) {
        self.conversation = conversation
        self.technical = technical
        self.marketKnowledge = marketKnowledge
        self.leadership = leadership
        self.finance = finance
    }

    public subscript(skill: FounderSkill) -> Double {
        get {
            switch skill {
            case .conversation: conversation
            case .technical: technical
            case .marketKnowledge: marketKnowledge
            case .leadership: leadership
            case .finance: finance
            }
        }
        set {
            let clamped = min(100, max(0, newValue))
            switch skill {
            case .conversation: conversation = clamped
            case .technical: technical = clamped
            case .marketKnowledge: marketKnowledge = clamped
            case .leadership: leadership = clamped
            case .finance: finance = clamped
            }
        }
    }

    public var total: Double {
        conversation + technical + marketKnowledge + leadership + finance
    }

    /// Adds `amount` to `skill` with diminishing returns: the closer to
    /// 100, the less of the gain actually lands. A founder goes from
    /// hopeless to competent quickly and from competent to excellent
    /// slowly, which is how it works.
    public mutating func grow(_ skill: FounderSkill, by amount: Double) {
        guard amount > 0 else { return }
        self[skill] += amount * (1 - self[skill] / 100)
    }
}

/// How the founder spends the day getting better at something. The three
/// rungs trade money for time: reading is free but eats the evening, a
/// course costs a few hundred, and a coach costs real money and works.
public enum TrainingMethod: String, Codable, Equatable, Sendable, CaseIterable {
    case selfStudy, course, coach

    public var displayName: String {
        switch self {
        case .selfStudy: "Self-study"
        case .course: "Online course"
        case .coach: "Private coach"
        }
    }
}

// MARK: - Founder multipliers

extension GameState {
    /// The founder's technical talent as an output multiplier, centred on
    /// the balance's `skillMidpoint` so a mid-table founder is exactly
    /// neutral and the existing balance is unchanged for a fresh game that
    /// never trains.
    public func founderTalentFactor(_ balance: BalanceConfig) -> Double {
        balance.founder.factor(
            for: life.skills.technical, strength: balance.founder.technicalOutputFactor
        )
    }

    /// What the founder's market sense does to a released product's sales.
    public func founderMarketFactor(_ balance: BalanceConfig) -> Double {
        balance.founder.factor(
            for: life.skills.marketKnowledge, strength: balance.founder.marketSalesFactor
        )
    }

    /// What the founder's head for terms does to a contract payout.
    public func founderDealFactor(_ balance: BalanceConfig) -> Double {
        balance.founder.factor(
            for: life.skills.finance, strength: balance.founder.financeDealFactor
        )
    }

    /// Points added to every hired employee's morale target by the
    /// founder's leadership. Negative for a founder who is bad at it.
    public func founderLeadershipMoraleDelta(_ balance: BalanceConfig) -> Double {
        (life.skills.leadership - balance.founder.skillMidpoint)
            * balance.founder.leadershipMoraleFactor
    }

    /// What the founder's conversation does to a social gesture, a
    /// networking exchange, or a partner's afternoon.
    public func founderCharmFactor(_ balance: BalanceConfig) -> Double {
        balance.founder.factor(
            for: life.skills.conversation, strength: balance.founder.conversationFactor
        )
    }
}
