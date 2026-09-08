import Foundation

// Iteration 10 — M1. What a feature board is worth.
//
// Every number here is read through `FeatureBoard.reading`, and the one
// that reaches the simulation, `qualityMultiplier`, is built as
// `1 + qualitySwing × (total ÷ slots)`. An empty board has a total of
// exactly zero, so the multiplier is exactly 1.0 whatever these numbers
// say — the identity is structural, not a tuned coincidence. A run that
// never places a card (every pacing bot, every fixture) ships the game
// that shipped.

extension BalanceConfig {

    // MARK: - The feature board

    public struct FeatureBoardBalance: Codable, Equatable, Sendable {
        // MARK: Slots

        /// The smallest board any product type gives.
        public var slotsMin: Int
        /// The largest.
        public var slotsMax: Int
        /// How much `ProductTypeDef.complexity` above 1.0 buys one more
        /// slot. At 0.3 the shipped types read 4, 4, 5, 5, 6, 6.
        public var slotsComplexityStep: Double
        /// How many cards the hand offers at once.
        public var handSize: Int
        /// How full the design pool has to be before the board locks. The
        /// board is a *plan*: you argue with it while the thing is being
        /// designed, and then you live with it.
        public var lockDesignFraction: Double

        // MARK: What a card is worth

        /// A card that belongs on both the type and the topic is worth
        /// this; one that belongs on neither costs it.
        public var fitValue: Double
        /// What one pair of cards that were written for each other adds.
        public var synergyValue: Double
        /// What riding the quarter's appetite adds.
        public var appetiteValue: Double

        // MARK: The market's appetite

        /// Days in an appetite quarter. The tags roll over on this beat.
        public var appetiteQuarterDays: Int
        /// How many tags the quarter wants before booms are counted.
        public var appetiteTagCount: Int
        /// A topic at or above this multiplier pushes its own tag into the
        /// quarter's appetite.
        public var boomAppetiteThreshold: Double
        /// The most tags the quarter can want at once, booms included. A
        /// market where everything is hot is a market that wants nothing
        /// in particular, so the hottest topics win and the rest wait.
        public var appetiteMaxTags: Int

        // MARK: What it does to quality

        /// Quality multiplier per unit of average card value per slot.
        public var qualitySwing: Double
        /// The most a perfect board can add.
        public var qualityBonusCap: Double
        /// The most a wrong-headed one can cost.
        public var qualityPenaltyCap: Double

        public init(
            slotsMin: Int = 4,
            slotsMax: Int = 6,
            slotsComplexityStep: Double = 0.3,
            handSize: Int = 10,
            lockDesignFraction: Double = 0.9,
            fitValue: Double = 1.0,
            synergyValue: Double = 0.5,
            appetiteValue: Double = 0.5,
            appetiteQuarterDays: Int = 91,
            appetiteTagCount: Int = 2,
            boomAppetiteThreshold: Double = 1.35,
            appetiteMaxTags: Int = 4,
            qualitySwing: Double = 0.10,
            qualityBonusCap: Double = 0.12,
            qualityPenaltyCap: Double = 0.10
        ) {
            self.slotsMin = slotsMin
            self.slotsMax = slotsMax
            self.slotsComplexityStep = slotsComplexityStep
            self.handSize = handSize
            self.lockDesignFraction = lockDesignFraction
            self.fitValue = fitValue
            self.synergyValue = synergyValue
            self.appetiteValue = appetiteValue
            self.appetiteQuarterDays = appetiteQuarterDays
            self.appetiteTagCount = appetiteTagCount
            self.boomAppetiteThreshold = boomAppetiteThreshold
            self.appetiteMaxTags = appetiteMaxTags
            self.qualitySwing = qualitySwing
            self.qualityBonusCap = qualityBonusCap
            self.qualityPenaltyCap = qualityPenaltyCap
        }

        /// The shipped board. Like `sabbatical`, the default is not
        /// "switched off": there is nothing to switch off until a card is
        /// placed, and a balance file with no `"featureBoard"` object
        /// should still be able to offer one.
        public static let `default` = FeatureBoardBalance()
    }
}

// Lets `BalanceConfig`'s synthesized decoder read a balance file with no
// `"featureBoard"` object.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.FeatureBoardBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.FeatureBoardBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}
