import Foundation

extension BalanceConfig {
    /// The `"sponsoredContracts"` block of `Balance.json`: rival-sponsored
    /// white-label contracts (WS-C, iteration 5). On a refresh day, when a
    /// rival exists, one offer on the sheet may be *sponsored* — it wears
    /// the rival's name, pays well over the sheet's rate, asks a high
    /// skill, and on delivery the rival ships what you built into a
    /// category, at the quality you built it.
    ///
    /// **Neutrality.** Every knob here is gated on a rival existing: the
    /// sponsored roll never draws when `state.rivals.rivals` is empty, and
    /// the pacing suite runs at `rivals.rivalCount == 0`, so the baseline
    /// table cannot move whatever these read. The roll itself draws from
    /// `worldRNG`, never `rng`, so the sheet's documented per-offer draw
    /// groups stay byte-identical with rivals on as well.
    ///
    /// Every field has a default (the shipped value), and the decoder
    /// reads each `IfPresent`, so an older balance file — or the empty
    /// `{}` the scaffold keyed — still decodes.
    public struct SponsoredContractBalance: Codable, Equatable, Sendable {
        // MARK: The roll

        /// Chance, per refresh, that one offer on the sheet is sponsored.
        /// At 0.25 a rival comes calling roughly once a month — often
        /// enough to be a real part of the contract game, rare enough
        /// that the sheet is not a rival's shop window.
        public var sponsorChance: Double
        /// No sponsored offer before this day. The first eight weeks are
        /// the player's own: nobody has anything worth white-labelling
        /// yet, and the first rival launch lands around month two.
        public var earliestDay: Int
        /// When the player holds any standing, the chance the sponsor
        /// asks for the player's best category rather than one of its
        /// own focus topics — the sharp version, where the offer names a
        /// topic you hold.
        public var playerTopicChance: Double

        // MARK: The offer

        /// Multiplier on the rolled offer's payout: the biggest contract
        /// on the sheet, by design, so the money is a real temptation.
        public var payoutFactor: Double
        /// The skill a sponsor expects: `strength × skillPerStrength +
        /// skillBase`, capped at `contractQuality.skillCap`. A 40-strength
        /// studio wants a 52 crew; a 90-strength one wants 90.
        public var skillPerStrength: Double
        public var skillBase: Double
        /// Multiplier on the rolled deadline: a white-label build is a
        /// long job, and the sponsor is patient about it.
        public var deadlineFactor: Double

        // MARK: Delivery

        /// The rival's product ships at `projectedQuality × this`, clamped
        /// to `RivalDepthTuning.qualityMin...qualityMax`: their app is a
        /// little worse than what you handed over, which is what a
        /// white-label integration does to anything.
        public var productQualityFactor: Double
        /// Strength the sponsor gains on delivery — a launch it did not
        /// have to build.
        public var rivalStrengthGain: Double
        /// Standing the player loses in the delivered topic: the trade
        /// press knows whose app that was. Only applies to a topic the
        /// player has standing in — you cannot lose what you never held.
        public var standingLoss: Double

        public init(
            sponsorChance: Double = 0.25,
            earliestDay: Int = 56,
            playerTopicChance: Double = 0.5,
            payoutFactor: Double = 1.8,
            skillPerStrength: Double = 0.8,
            skillBase: Double = 20,
            deadlineFactor: Double = 1.5,
            productQualityFactor: Double = 0.9,
            rivalStrengthGain: Double = 6,
            standingLoss: Double = 5
        ) {
            self.sponsorChance = sponsorChance
            self.earliestDay = earliestDay
            self.playerTopicChance = playerTopicChance
            self.payoutFactor = payoutFactor
            self.skillPerStrength = skillPerStrength
            self.skillBase = skillBase
            self.deadlineFactor = deadlineFactor
            self.productQualityFactor = productQualityFactor
            self.rivalStrengthGain = rivalStrengthGain
            self.standingLoss = standingLoss
        }

        public static let `default` = SponsoredContractBalance()

        /// The skill a sponsor of `strength` expects, before the cap.
        public func requiredSkill(forStrength strength: Double) -> Double {
            strength * skillPerStrength + skillBase
        }

        /// The quality the sponsor's product ships at for a job graded
        /// `projectedQuality`. The same arithmetic the contract card shows
        /// before delivery and `ContractSystem` applies on it.
        public func productQuality(forProjected projectedQuality: Int) -> Double {
            min(
                RivalDepthTuning.qualityMax,
                max(RivalDepthTuning.qualityMin, Double(projectedQuality) * productQualityFactor)
            )
        }

        // MARK: Codable

        private enum CodingKeys: String, CodingKey {
            case sponsorChance, earliestDay, playerTopicChance
            case payoutFactor, skillPerStrength, skillBase, deadlineFactor
            case productQualityFactor, rivalStrengthGain, standingLoss
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let shipped = SponsoredContractBalance()
            self.init(
                sponsorChance: try container.decodeIfPresent(Double.self, forKey: .sponsorChance)
                    ?? shipped.sponsorChance,
                earliestDay: try container.decodeIfPresent(Int.self, forKey: .earliestDay)
                    ?? shipped.earliestDay,
                playerTopicChance: try container.decodeIfPresent(Double.self, forKey: .playerTopicChance)
                    ?? shipped.playerTopicChance,
                payoutFactor: try container.decodeIfPresent(Double.self, forKey: .payoutFactor)
                    ?? shipped.payoutFactor,
                skillPerStrength: try container.decodeIfPresent(Double.self, forKey: .skillPerStrength)
                    ?? shipped.skillPerStrength,
                skillBase: try container.decodeIfPresent(Double.self, forKey: .skillBase)
                    ?? shipped.skillBase,
                deadlineFactor: try container.decodeIfPresent(Double.self, forKey: .deadlineFactor)
                    ?? shipped.deadlineFactor,
                productQualityFactor: try container.decodeIfPresent(Double.self, forKey: .productQualityFactor)
                    ?? shipped.productQualityFactor,
                rivalStrengthGain: try container.decodeIfPresent(Double.self, forKey: .rivalStrengthGain)
                    ?? shipped.rivalStrengthGain,
                standingLoss: try container.decodeIfPresent(Double.self, forKey: .standingLoss)
                    ?? shipped.standingLoss
            )
        }
    }
}
