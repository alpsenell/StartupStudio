import Foundation

// Iteration 12 — J3. Rivals follow the money, the price war gets an answer,
// and the copycat takes the card.
//
// Every knob here is read behind a gate the player raises: the topic
// weights, the boom recruit and the crash drop only once
// `state.rivalMarket.noticed` (the market board has been opened — no bot
// ever opens it); the three price-war answers only once one has been
// tapped; the copied card only once a rival has lifted a card off a board,
// which needs a board somebody placed a card on. So a run that does none
// of those plays the game that shipped whatever these numbers say.
//
// The boom line is not here: it is the feature board's
// `boomAppetiteThreshold`, so "the market wants it" and "a rival moves in"
// can never disagree about what a boom is.

extension BalanceConfig {

    // MARK: - Rivals and the market

    public struct RivalMarketBalance: Codable, Equatable, Sendable {
        // MARK: Rivals follow the money

        /// A rival's launch topic is weighted by the topic's multiplier to
        /// this power: at 2, a ×1.4 topic is 1.96 times as likely as a
        /// ×1.0 one and a ×0.6 topic 0.36 times.
        public var topicWeightExponent: Double
        /// Only a studio stronger than this moves into a boom.
        public var entrantMinStrength: Double
        /// A focus topic under this multiplier…
        public var crashDropMultiplier: Double
        /// …for this many weekly shifts running is dropped.
        public var crashDropShifts: Int
        /// How many moves the market remembers, for the forecast line, the
        /// profile and the paper.
        public var moveLogCap: Int

        // MARK: Answer the price war

        /// Days from the war's first day in which it can still be
        /// answered. After that it is outlasted, which is what it always
        /// was.
        public var answerWindowDays: Int
        /// A matched rival loses this much strength every week of the war.
        public var matchStrengthPerWeek: Double
        /// …and holds this much more of a grudge. Two matches pass
        /// `espionage.rivalGrudgeToAct`.
        public var matchGrudge: Double
        /// A patch that lands inside the war ends it and earns this much
        /// standing in the topic.
        public var outshipStanding: Double

        // MARK: The copycat takes the card

        /// While a clone that lifted a card competes, that card's fit on
        /// your products in the topic is worth this fraction of itself.
        public var copiedFitFactor: Double
        /// The clone is this much better for having copied something good.
        public var copiedCloneQualityBonus: Double

        public init(
            topicWeightExponent: Double = 2,
            entrantMinStrength: Double = 40,
            crashDropMultiplier: Double = 0.7,
            crashDropShifts: Int = 4,
            moveLogCap: Int = 24,
            answerWindowDays: Int = 7,
            matchStrengthPerWeek: Double = 1.5,
            matchGrudge: Double = 25,
            outshipStanding: Double = 8,
            copiedFitFactor: Double = 0.5,
            copiedCloneQualityBonus: Double = 4
        ) {
            self.topicWeightExponent = topicWeightExponent
            self.entrantMinStrength = entrantMinStrength
            self.crashDropMultiplier = crashDropMultiplier
            self.crashDropShifts = crashDropShifts
            self.moveLogCap = moveLogCap
            self.answerWindowDays = answerWindowDays
            self.matchStrengthPerWeek = matchStrengthPerWeek
            self.matchGrudge = matchGrudge
            self.outshipStanding = outshipStanding
            self.copiedFitFactor = copiedFitFactor
            self.copiedCloneQualityBonus = copiedCloneQualityBonus
        }

        /// The shipped numbers — and what a balance file with no
        /// `"rivalMarket"` object reads.
        public static let `default` = RivalMarketBalance()

        private enum CodingKeys: String, CodingKey {
            case topicWeightExponent, entrantMinStrength, crashDropMultiplier, crashDropShifts
            case moveLogCap, answerWindowDays, matchStrengthPerWeek, matchGrudge, outshipStanding
            case copiedFitFactor, copiedCloneQualityBonus
        }

        // Decode-if-present on every field, so a balance file written
        // before this block existed reads exactly the shipped numbers.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let fallback = RivalMarketBalance()
            func int(_ key: CodingKeys, _ value: Int) throws -> Int {
                try container.decodeIfPresent(Int.self, forKey: key) ?? value
            }
            func double(_ key: CodingKeys, _ value: Double) throws -> Double {
                try container.decodeIfPresent(Double.self, forKey: key) ?? value
            }
            self.init(
                topicWeightExponent: try double(.topicWeightExponent, fallback.topicWeightExponent),
                entrantMinStrength: try double(.entrantMinStrength, fallback.entrantMinStrength),
                crashDropMultiplier: try double(.crashDropMultiplier, fallback.crashDropMultiplier),
                crashDropShifts: try int(.crashDropShifts, fallback.crashDropShifts),
                moveLogCap: try int(.moveLogCap, fallback.moveLogCap),
                answerWindowDays: try int(.answerWindowDays, fallback.answerWindowDays),
                matchStrengthPerWeek: try double(.matchStrengthPerWeek, fallback.matchStrengthPerWeek),
                matchGrudge: try double(.matchGrudge, fallback.matchGrudge),
                outshipStanding: try double(.outshipStanding, fallback.outshipStanding),
                copiedFitFactor: try double(.copiedFitFactor, fallback.copiedFitFactor),
                copiedCloneQualityBonus: try double(
                    .copiedCloneQualityBonus, fallback.copiedCloneQualityBonus
                )
            )
        }
    }
}

/// The top-level `"rivalMarket"` key is optional: the synthesized
/// `BalanceConfig` decoder calls `decode`, and this overload answers a
/// missing key with the shipped block.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.RivalMarketBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.RivalMarketBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}
