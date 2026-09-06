import Foundation

extension BalanceConfig {
    /// The `"lifeScore"` block of `Balance.json` (iteration 9, L2): what
    /// the founder's life is graded out of, component by component.
    ///
    /// **Neutrality.** Nothing in the simulation reads a life score. It is
    /// a *display* number — the second figure next to net worth — and the
    /// only place it feeds back into the game at all is the gate on the
    /// *Walked away* ending, which the founder has to press. So there is
    /// no "identity at the default" to protect here in the usual sense:
    /// every knob below could be any number at all and a run that never
    /// walks away would tick identically. The defaults are still the
    /// shipped values, and the decoder reads every key `IfPresent`, so an
    /// older `Balance.json` — or none at all — decodes.
    ///
    /// The six component maxima sum to 100 by construction; `LifeScore`
    /// clamps the total to 0...100 after the penalty, so a rebalanced file
    /// that does not sum to 100 still produces a legal score.
    public struct LifeScoreBalance: Codable, Equatable, Sendable {
        // MARK: The six components

        /// Partner: stage on the single → married ladder × affection.
        public var partnerMax: Double
        /// What each rung of the ladder is worth as a fraction of
        /// `partnerMax`, keyed by `RelationshipStage` raw value. Single is
        /// zero: there is nobody to have a number about.
        public var partnerStageWeight: [String: Double]

        /// Children: how many, and whether their days were kept.
        public var childrenMax: Double
        /// Full marks at this many children; more is not more.
        public var childrenForFullMarks: Int
        /// The bond proxy floor. A founder who missed a family date
        /// yesterday still scores this fraction of the children component
        /// — the child exists, and the day is recoverable.
        public var missedDateFloor: Double
        /// How long a missed family date keeps costing: the proxy climbs
        /// back to 1 over this many days.
        public var missedDateRecoveryDays: Int

        /// Health and energy, the two meters a body has.
        public var bodyMax: Double
        /// Health's share of the body component; energy takes the rest.
        public var healthShare: Double

        /// Friends: the sum of every friend's bond (L4).
        public var friendsMax: Double
        /// The bond sum that earns full marks — three friends at 80.
        public var friendsBondForFullMarks: Double

        /// Evenings spent on people over the last year.
        public var eveningsMax: Double
        /// Evenings on people in the last year for full marks.
        public var eveningsForFullMarks: Int
        /// How far back "the last year" reaches.
        public var eveningsWindowDays: Int

        /// Home: where the founder actually lives.
        public var homeMax: Double

        // MARK: The penalty

        /// Points off per burnout inside the economy's health window.
        public var burnoutPenalty: Double
        /// Points off per hospital stay inside the same window.
        public var hospitalPenalty: Double
        /// Points off for living with a chronic condition.
        public var chronicPenalty: Double
        /// The most the body can take off in total.
        public var penaltyCap: Double

        // MARK: Walked away

        /// No walking away before this day: a year and a half. Leaving a
        /// company nobody has heard of is not an ending, it is a Tuesday.
        public var walkAwayMinDay: Int
        /// The life score the founder needs to be walking *towards*
        /// something rather than away from everything.
        public var walkAwayMinLifeScore: Int
        /// The net worth the founder needs behind them to stop working.
        public var walkAwayMinNetWorth: Int

        public init(
            partnerMax: Double = 22,
            partnerStageWeight: [String: Double] = [
                "single": 0, "dating": 0.5, "partner": 0.8, "married": 1.0,
            ],
            childrenMax: Double = 15,
            childrenForFullMarks: Int = 2,
            missedDateFloor: Double = 0.45,
            missedDateRecoveryDays: Int = 364,
            bodyMax: Double = 22,
            healthShare: Double = 0.6,
            friendsMax: Double = 12,
            friendsBondForFullMarks: Double = 240,
            eveningsMax: Double = 19,
            eveningsForFullMarks: Int = 24,
            eveningsWindowDays: Int = 364,
            homeMax: Double = 10,
            burnoutPenalty: Double = 4,
            hospitalPenalty: Double = 3,
            chronicPenalty: Double = 8,
            penaltyCap: Double = 15,
            walkAwayMinDay: Int = 546,
            walkAwayMinLifeScore: Int = 60,
            walkAwayMinNetWorth: Int = 250_000
        ) {
            self.partnerMax = partnerMax
            self.partnerStageWeight = partnerStageWeight
            self.childrenMax = childrenMax
            self.childrenForFullMarks = childrenForFullMarks
            self.missedDateFloor = missedDateFloor
            self.missedDateRecoveryDays = missedDateRecoveryDays
            self.bodyMax = bodyMax
            self.healthShare = healthShare
            self.friendsMax = friendsMax
            self.friendsBondForFullMarks = friendsBondForFullMarks
            self.eveningsMax = eveningsMax
            self.eveningsForFullMarks = eveningsForFullMarks
            self.eveningsWindowDays = eveningsWindowDays
            self.homeMax = homeMax
            self.burnoutPenalty = burnoutPenalty
            self.hospitalPenalty = hospitalPenalty
            self.chronicPenalty = chronicPenalty
            self.penaltyCap = penaltyCap
            self.walkAwayMinDay = walkAwayMinDay
            self.walkAwayMinLifeScore = walkAwayMinLifeScore
            self.walkAwayMinNetWorth = walkAwayMinNetWorth
        }

        public static let `default` = LifeScoreBalance()

        private enum CodingKeys: String, CodingKey {
            case partnerMax, partnerStageWeight
            case childrenMax, childrenForFullMarks, missedDateFloor, missedDateRecoveryDays
            case bodyMax, healthShare
            case friendsMax, friendsBondForFullMarks
            case eveningsMax, eveningsForFullMarks, eveningsWindowDays
            case homeMax
            case burnoutPenalty, hospitalPenalty, chronicPenalty, penaltyCap
            case walkAwayMinDay, walkAwayMinLifeScore, walkAwayMinNetWorth
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let fallback = LifeScoreBalance()
            self.init(
                partnerMax: try container.decodeIfPresent(Double.self, forKey: .partnerMax)
                    ?? fallback.partnerMax,
                partnerStageWeight: try container.decodeIfPresent(
                    [String: Double].self, forKey: .partnerStageWeight
                ) ?? fallback.partnerStageWeight,
                childrenMax: try container.decodeIfPresent(Double.self, forKey: .childrenMax)
                    ?? fallback.childrenMax,
                childrenForFullMarks: try container.decodeIfPresent(
                    Int.self, forKey: .childrenForFullMarks
                ) ?? fallback.childrenForFullMarks,
                missedDateFloor: try container.decodeIfPresent(Double.self, forKey: .missedDateFloor)
                    ?? fallback.missedDateFloor,
                missedDateRecoveryDays: try container.decodeIfPresent(
                    Int.self, forKey: .missedDateRecoveryDays
                ) ?? fallback.missedDateRecoveryDays,
                bodyMax: try container.decodeIfPresent(Double.self, forKey: .bodyMax)
                    ?? fallback.bodyMax,
                healthShare: try container.decodeIfPresent(Double.self, forKey: .healthShare)
                    ?? fallback.healthShare,
                friendsMax: try container.decodeIfPresent(Double.self, forKey: .friendsMax)
                    ?? fallback.friendsMax,
                friendsBondForFullMarks: try container.decodeIfPresent(
                    Double.self, forKey: .friendsBondForFullMarks
                ) ?? fallback.friendsBondForFullMarks,
                eveningsMax: try container.decodeIfPresent(Double.self, forKey: .eveningsMax)
                    ?? fallback.eveningsMax,
                eveningsForFullMarks: try container.decodeIfPresent(
                    Int.self, forKey: .eveningsForFullMarks
                ) ?? fallback.eveningsForFullMarks,
                eveningsWindowDays: try container.decodeIfPresent(
                    Int.self, forKey: .eveningsWindowDays
                ) ?? fallback.eveningsWindowDays,
                homeMax: try container.decodeIfPresent(Double.self, forKey: .homeMax)
                    ?? fallback.homeMax,
                burnoutPenalty: try container.decodeIfPresent(Double.self, forKey: .burnoutPenalty)
                    ?? fallback.burnoutPenalty,
                hospitalPenalty: try container.decodeIfPresent(Double.self, forKey: .hospitalPenalty)
                    ?? fallback.hospitalPenalty,
                chronicPenalty: try container.decodeIfPresent(Double.self, forKey: .chronicPenalty)
                    ?? fallback.chronicPenalty,
                penaltyCap: try container.decodeIfPresent(Double.self, forKey: .penaltyCap)
                    ?? fallback.penaltyCap,
                walkAwayMinDay: try container.decodeIfPresent(Int.self, forKey: .walkAwayMinDay)
                    ?? fallback.walkAwayMinDay,
                walkAwayMinLifeScore: try container.decodeIfPresent(
                    Int.self, forKey: .walkAwayMinLifeScore
                ) ?? fallback.walkAwayMinLifeScore,
                walkAwayMinNetWorth: try container.decodeIfPresent(
                    Int.self, forKey: .walkAwayMinNetWorth
                ) ?? fallback.walkAwayMinNetWorth
            )
        }
    }
}
