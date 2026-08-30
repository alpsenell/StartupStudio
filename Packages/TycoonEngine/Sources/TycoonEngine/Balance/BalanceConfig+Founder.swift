import Foundation

// The founder-as-a-person layer: the five attributes and what training
// them costs (`"founder"`), the networking floor (`"networking"`), and the
// people the founder is close to — a partner who needs tending and a team
// that can become friends rather than payroll (`"relationships"`).
//
// Each block decodes as a whole from its own object in `Balance.json`
// (which therefore has to carry every key, like `"life"` and `"social"`
// do), and an absent block decodes as `.default` — a `.default` chosen so
// that a balance file written before any of this existed still produces
// exactly the pre-founder simulation.

extension BalanceConfig {

    // MARK: - Founder attributes

    /// The founder's own attributes: where they start, what training
    /// costs, and how much each attribute is actually worth.
    public struct FounderBalance: Codable, Equatable, Sendable {
        /// One rung of the training ladder.
        public struct TrainingDef: Codable, Equatable, Sendable {
            /// Wallet money, not company cash — the founder pays to learn.
            public var cost: Int
            /// Energy the session costs.
            public var energy: Double
            /// Mood it costs (self-study) or pays (a coach who is good).
            public var mood: Double
            /// Raw points before the diminishing-returns curve.
            public var gain: Double
            public var cooldownDays: Int

            public init(cost: Int, energy: Double, mood: Double, gain: Double, cooldownDays: Int) {
                self.cost = cost
                self.energy = energy
                self.mood = mood
                self.gain = gain
                self.cooldownDays = cooldownDays
            }
        }

        /// What a first-time founder walks in with. The shipped sheet is
        /// flat at `skillMidpoint`, which is deliberate: it makes every
        /// attribute's effect exactly neutral on day one, so the whole
        /// balance the pacing suite pins is the balance an untrained
        /// founder plays, and every point of training is a gain the player
        /// earned rather than a hole they were born in.
        public var starting: FounderSkillSet
        /// The attribute value that reads as exactly neutral, so a fresh
        /// game's numbers are unchanged until the founder trains.
        public var skillMidpoint: Double
        /// Keyed by `TrainingMethod` raw value.
        public var training: [String: TrainingDef]
        /// Training sessions the founder can fit into one day.
        public var maxTrainingsPerDay: Int
        /// Points an attribute picks up just from being used — a weekend
        /// of networking teaches you to talk to people.
        public var practiceGain: Double

        /// Strength of each attribute's effect. Read through
        /// `factor(for:strength:)`, so `0.4` means ×0.8 at zero skill and
        /// ×1.2 at a hundred.
        public var technicalOutputFactor: Double
        public var marketSalesFactor: Double
        public var financeDealFactor: Double
        public var conversationFactor: Double
        /// Morale-target points per point of leadership away from the
        /// midpoint (so this one is a flat delta, not a factor).
        public var leadershipMoraleFactor: Double
        /// Divisor turning technical skill into a reduction of the
        /// founder's bug rate. Zero disables it.
        public var technicalBugDivisor: Double

        public init(
            starting: FounderSkillSet = FounderSkillSet(
                conversation: 50, technical: 50, marketKnowledge: 50, leadership: 50, finance: 50
            ),
            skillMidpoint: Double = 50,
            training: [String: TrainingDef] = [:],
            maxTrainingsPerDay: Int = 1,
            practiceGain: Double = 0,
            technicalOutputFactor: Double = 0,
            marketSalesFactor: Double = 0,
            financeDealFactor: Double = 0,
            conversationFactor: Double = 0,
            leadershipMoraleFactor: Double = 0,
            technicalBugDivisor: Double = 0
        ) {
            self.starting = starting
            self.skillMidpoint = skillMidpoint
            self.training = training
            self.maxTrainingsPerDay = maxTrainingsPerDay
            self.practiceGain = practiceGain
            self.technicalOutputFactor = technicalOutputFactor
            self.marketSalesFactor = marketSalesFactor
            self.financeDealFactor = financeDealFactor
            self.conversationFactor = conversationFactor
            self.leadershipMoraleFactor = leadershipMoraleFactor
            self.technicalBugDivisor = technicalBugDivisor
        }

        public func training(_ method: TrainingMethod) -> TrainingDef? {
            training[method.rawValue]
        }

        /// `1 + strength × (value − midpoint) / 100`, floored at zero so a
        /// wild balance can never invert a multiplier.
        public func factor(for value: Double, strength: Double) -> Double {
            max(0, 1 + strength * (value - skillMidpoint) / 100)
        }

        /// Every effect switched off and the shipped starting attributes:
        /// what a balance file with no `"founder"` object gets. The
        /// founder still *has* attributes (so the Life tab has something
        /// to show and training still works), they simply move nothing —
        /// exactly the pre-attribute simulation.
        public static let `default` = FounderBalance()
    }

    // MARK: - Networking

    /// The Friday-night floor: how many people are there, how many
    /// exchanges the founder has in them, and what each kind of deal
    /// costs.
    public struct NetworkingBalance: Codable, Equatable, Sendable {
        /// How many contacts a venue puts in the room.
        public var contactsPerEventMin: Int
        public var contactsPerEventMax: Int
        /// Base exchanges before the conversation bonus.
        public var conversationsPerEvent: Int
        /// Conversation skill divided by this adds exchanges.
        public var conversationTurnsDivisor: Double
        /// Days the room stays open after the weekend resolves.
        public var eventDurationDays: Int
        /// Rapport a good chat adds, before the charm factor.
        public var talkRapport: Double
        /// Rapport a chat that lands badly costs.
        public var talkRapportMiss: Double
        /// Chance a chat lands at all, before charm.
        public var talkSuccessBase: Double
        /// Rapport and interest a pitch moves.
        public var pitchRapport: Double
        public var pitchInterest: Double
        /// Energy each exchange costs the founder.
        public var energyPerTurn: Double
        /// Mood a good exchange pays.
        public var moodPerGoodTurn: Double
        /// Relationships the whole evening pays, on top of the weekend's.
        public var relationshipsPerEvent: Double

        /// Rapport gates on each offer.
        public var recruitMinRapport: Double
        public var equityHireMinRapport: Double
        public var investMinRapport: Double
        public var angelMinRapport: Double
        public var romanceMinRapport: Double
        /// Interest the contact needs in *your* company before they will
        /// join it or put money into it.
        public var joinMinInterest: Double

        /// An equity hire trades salary for company points: they take
        /// `equityHireEquityPerSkillPoint` per point of total skill,
        /// clamped, and work for `equityHireSalaryFactor` of their ask.
        public var equityHireEquityPerSkillPoint: Double
        public var equityHireEquityMin: Double
        public var equityHireEquityMax: Double
        public var equityHireSalaryFactor: Double
        /// The morale and loyalty an owner walks in with.
        public var equityHireMorale: Double
        public var equityHireLoyalty: Double

        /// The slice of their own company a contact will part with: this
        /// many points, plus `investStakePerRapportPoint` per point of
        /// rapport, capped at `investStakeMax`. They price it at their own
        /// valuation, less a friends-and-family discount worth
        /// `investDiscountPerRapportPoint` per point of rapport.
        public var investStakeBase: Double
        public var investStakePerRapportPoint: Double
        public var investStakeMax: Double
        public var investDiscountPerRapportPoint: Double
        /// Weekly drift of a holding's valuation, and the chance per week
        /// that it either exits (paying `exitMultipleMin...Max`) or folds.
        public var holdingWeeklyGrowth: Double
        public var holdingWeeklyVolatility: Double
        public var holdingExitChance: Double
        public var holdingFoldChance: Double
        public var holdingExitMultipleMin: Double
        public var holdingExitMultipleMax: Double

        /// An angel round from a contact: cash per point of equity, scaled
        /// by rapport.
        public var angelCashPerEquityPoint: Int
        public var angelMaxEquity: Double

        /// How far rapport slides per day with no contact at all.
        public var rapportDecayPerDay: Double
        /// Contacts the address book keeps.
        public var maxContacts: Int

        public init(
            contactsPerEventMin: Int = 3,
            contactsPerEventMax: Int = 5,
            conversationsPerEvent: Int = 3,
            conversationTurnsDivisor: Double = 40,
            eventDurationDays: Int = 2,
            talkRapport: Double = 14,
            talkRapportMiss: Double = 4,
            talkSuccessBase: Double = 0.55,
            pitchRapport: Double = 6,
            pitchInterest: Double = 18,
            energyPerTurn: Double = 3,
            moodPerGoodTurn: Double = 1,
            relationshipsPerEvent: Double = 0,
            recruitMinRapport: Double = 55,
            equityHireMinRapport: Double = 70,
            investMinRapport: Double = 45,
            angelMinRapport: Double = 65,
            romanceMinRapport: Double = 75,
            joinMinInterest: Double = 50,
            equityHireEquityPerSkillPoint: Double = 0.03,
            equityHireEquityMin: Double = 1,
            equityHireEquityMax: Double = 8,
            equityHireSalaryFactor: Double = 0.35,
            equityHireMorale: Double = 90,
            equityHireLoyalty: Double = 85,
            investStakeBase: Double = 4,
            investStakePerRapportPoint: Double = 0.08,
            investStakeMax: Double = 20,
            investDiscountPerRapportPoint: Double = 0.0025,
            holdingWeeklyGrowth: Double = 0.015,
            holdingWeeklyVolatility: Double = 0.09,
            holdingExitChance: Double = 0.006,
            holdingFoldChance: Double = 0.005,
            holdingExitMultipleMin: Double = 1.5,
            holdingExitMultipleMax: Double = 6,
            angelCashPerEquityPoint: Int = 9000,
            angelMaxEquity: Double = 6,
            rapportDecayPerDay: Double = 0.15,
            maxContacts: Int = 40
        ) {
            self.contactsPerEventMin = contactsPerEventMin
            self.contactsPerEventMax = contactsPerEventMax
            self.conversationsPerEvent = conversationsPerEvent
            self.conversationTurnsDivisor = conversationTurnsDivisor
            self.eventDurationDays = eventDurationDays
            self.talkRapport = talkRapport
            self.talkRapportMiss = talkRapportMiss
            self.talkSuccessBase = talkSuccessBase
            self.pitchRapport = pitchRapport
            self.pitchInterest = pitchInterest
            self.energyPerTurn = energyPerTurn
            self.moodPerGoodTurn = moodPerGoodTurn
            self.relationshipsPerEvent = relationshipsPerEvent
            self.recruitMinRapport = recruitMinRapport
            self.equityHireMinRapport = equityHireMinRapport
            self.investMinRapport = investMinRapport
            self.angelMinRapport = angelMinRapport
            self.romanceMinRapport = romanceMinRapport
            self.joinMinInterest = joinMinInterest
            self.equityHireEquityPerSkillPoint = equityHireEquityPerSkillPoint
            self.equityHireEquityMin = equityHireEquityMin
            self.equityHireEquityMax = equityHireEquityMax
            self.equityHireSalaryFactor = equityHireSalaryFactor
            self.equityHireMorale = equityHireMorale
            self.equityHireLoyalty = equityHireLoyalty
            self.investStakeBase = investStakeBase
            self.investStakePerRapportPoint = investStakePerRapportPoint
            self.investStakeMax = investStakeMax
            self.investDiscountPerRapportPoint = investDiscountPerRapportPoint
            self.holdingWeeklyGrowth = holdingWeeklyGrowth
            self.holdingWeeklyVolatility = holdingWeeklyVolatility
            self.holdingExitChance = holdingExitChance
            self.holdingFoldChance = holdingFoldChance
            self.holdingExitMultipleMin = holdingExitMultipleMin
            self.holdingExitMultipleMax = holdingExitMultipleMax
            self.angelCashPerEquityPoint = angelCashPerEquityPoint
            self.angelMaxEquity = angelMaxEquity
            self.rapportDecayPerDay = rapportDecayPerDay
            self.maxContacts = maxContacts
        }

        /// A balance file with no `"networking"` object gets a floor that
        /// never opens: `contactsPerEventMax` of zero means a networking
        /// weekend resolves exactly as it did before — meters only.
        public static let `default` = NetworkingBalance(
            contactsPerEventMin: 0, contactsPerEventMax: 0
        )

        /// Whether this balance has a networking floor at all.
        public var isEnabled: Bool { contactsPerEventMax > 0 }
    }

    // MARK: - Relationships

    /// The people the founder is close to: a partner who notices being
    /// ignored, and a team that can become friends.
    public struct RelationshipBalance: Codable, Equatable, Sendable {
        /// One thing the founder can do with their partner.
        public struct PartnerActivityDef: Codable, Equatable, Sendable {
            public var cost: Int
            public var affection: Double
            public var energy: Double
            public var mood: Double
            public var relationships: Double
            public var cooldownDays: Int

            public init(
                cost: Int,
                affection: Double,
                energy: Double = 0,
                mood: Double = 0,
                relationships: Double = 0,
                cooldownDays: Int
            ) {
                self.cost = cost
                self.affection = affection
                self.energy = energy
                self.mood = mood
                self.relationships = relationships
                self.cooldownDays = cooldownDays
            }
        }

        /// Affection a new partner starts at.
        public var startingAffection: Double
        /// Daily affection drift while the founder does nothing.
        public var affectionDrift: Double
        /// Extra daily drift once `neglectDays` have passed with no
        /// contact at all.
        public var neglectDrift: Double
        public var neglectDays: Int
        /// Affection above the midpoint feeds the relationships meter, and
        /// below it drains it, at this rate per day per point.
        public var affectionRelationshipFactor: Double
        /// Keyed by `PartnerActivity` raw value.
        public var partnerActivities: [String: PartnerActivityDef]
        /// Affection each rung of the ladder needs on top of the
        /// relationship-meter gates in `life`.
        public var stageMinAffection: [String: Double]

        /// Bond the founder has with a new hire.
        public var startingBond: Double
        /// Daily bond decay when the founder does nothing.
        public var bondDecayPerDay: Double
        /// Bond a coffee / one-on-one / gift adds, before the charm factor.
        public var bondPerSocialAction: Double
        /// A hang-out is the founder's own time and money: bigger, and it
        /// pays the founder's own relationships meter too.
        public var hangOut: PartnerActivityDef
        /// Mentoring: the founder's own day, spent on somebody else's
        /// skill. Points added scale with the founder's technical and
        /// leadership.
        public var mentorSkillGain: Double
        public var mentorEnergyCost: Double
        public var mentorCooldownDays: Int
        /// A strong bond is worth output, morale and staying put.
        public var bondOutputFactor: Double
        public var bondMoraleTargetFactor: Double
        public var bondLoyaltyPerDay: Double

        public init(
            startingAffection: Double = 55,
            affectionDrift: Double = -0.3,
            neglectDrift: Double = -0.5,
            neglectDays: Int = 14,
            affectionRelationshipFactor: Double = 0.01,
            partnerActivities: [String: PartnerActivityDef] = [:],
            stageMinAffection: [String: Double] = [:],
            startingBond: Double = 10,
            bondDecayPerDay: Double = 0.1,
            bondPerSocialAction: Double = 6,
            hangOut: PartnerActivityDef = PartnerActivityDef(
                cost: 60, affection: 0, energy: -4, mood: 4, relationships: 3, cooldownDays: 5
            ),
            mentorSkillGain: Double = 4,
            mentorEnergyCost: Double = 8,
            mentorCooldownDays: Int = 7,
            bondOutputFactor: Double = 0,
            bondMoraleTargetFactor: Double = 0,
            bondLoyaltyPerDay: Double = 0
        ) {
            self.startingAffection = startingAffection
            self.affectionDrift = affectionDrift
            self.neglectDrift = neglectDrift
            self.neglectDays = neglectDays
            self.affectionRelationshipFactor = affectionRelationshipFactor
            self.partnerActivities = partnerActivities
            self.stageMinAffection = stageMinAffection
            self.startingBond = startingBond
            self.bondDecayPerDay = bondDecayPerDay
            self.bondPerSocialAction = bondPerSocialAction
            self.hangOut = hangOut
            self.mentorSkillGain = mentorSkillGain
            self.mentorEnergyCost = mentorEnergyCost
            self.mentorCooldownDays = mentorCooldownDays
            self.bondOutputFactor = bondOutputFactor
            self.bondMoraleTargetFactor = bondMoraleTargetFactor
            self.bondLoyaltyPerDay = bondLoyaltyPerDay
        }

        public func partnerActivity(_ activity: PartnerActivity) -> PartnerActivityDef? {
            partnerActivities[activity.rawValue]
        }

        /// Affection the stage needs, 0 when the balance says nothing.
        public func minAffection(for stage: RelationshipStage) -> Double {
            stageMinAffection[stage.rawValue] ?? 0
        }

        /// Every effect at zero: partner affection sits still and a bond
        /// is worth nothing, which is exactly the pre-relationship
        /// simulation.
        public static let `default` = RelationshipBalance(
            affectionDrift: 0, neglectDrift: 0, affectionRelationshipFactor: 0,
            bondDecayPerDay: 0
        )
    }
}

// Lets `BalanceConfig`'s synthesized decoder read a balance file that has
// none of these objects: the concrete overloads win over the generic
// `decode(_:forKey:)`, turning each required key into
// `decodeIfPresent ?? .default`.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.FounderBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.FounderBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }

    func decode(
        _ type: BalanceConfig.NetworkingBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.NetworkingBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }

    func decode(
        _ type: BalanceConfig.RelationshipBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.RelationshipBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}
