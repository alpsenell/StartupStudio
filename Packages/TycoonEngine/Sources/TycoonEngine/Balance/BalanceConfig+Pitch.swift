import Foundation

// Iteration 10 — M2. The pitch room's dials.
//
// Every span below is a *swing around zero*: `PitchRoom.swing` reads
// `1 + warmth/100 × span`, which is exactly 1 when warmth is 0. So none
// of these numbers can move a run in which nobody sits down, however they
// are set — the identity is in the shape of the arithmetic, not in the
// defaults. `Balance.json` carries a `"pitch"` object matching these
// defaults; a file without one still decodes (see the shim at the
// bottom).

extension BalanceConfig {

    // MARK: - Pitch room

    public struct PitchBalance: Codable, Equatable, Sendable {
        // MARK: The room

        /// Exchanges a conversation gets before it settles itself, before
        /// the founder's conversation attribute is counted.
        public var exchangesBase: Int
        /// Attribute points per extra exchange. A founder who can talk
        /// gets a fourth and a fifth.
        public var exchangesPerConversationPoint: Double
        /// The most any conversation can run to.
        public var exchangesMax: Int

        // MARK: What each topic is worth

        /// Warmth a landed exchange is worth, before the topic's own
        /// multiplier and the founder's charm.
        public var warmthPerLandedTurn: Double
        /// Small talk is safe and small.
        public var smallTalkFactor: Double
        /// Listening buys a little warmth and the want.
        public var listenFactor: Double
        /// Talking shop is graded, and worth more than small talk.
        public var shopTalkFactor: Double
        /// The pitch is the swing.
        public var pitchFactor: Double
        /// Warmth a missed exchange costs, as a multiple of what landing
        /// it would have paid.
        public var missFactor: Double
        /// The multiplier on a topic that is the counterpart's revealed
        /// want. Aim at what they came for and it pays double.
        public var wantFactor: Double
        /// Base chance a graded exchange lands, before the attribute.
        public var landBase: Double
        /// The attribute is divided by this before it is added to the
        /// chance: 100 points of finance is +0.5 at 200.
        public var landSkillDivisor: Double
        /// The most any exchange can be relied on to land.
        public var landCeiling: Double

        // MARK: What the room costs the founder

        public var energyPerTurn: Double
        public var moodPerGoodTurn: Double

        // MARK: What each counterpart can move

        /// Fraction the cheque swings at full warmth (0.25 = ±25%).
        public var investorAmountSpan: Double
        /// Fraction the equity ask swings, the other way.
        public var investorEquitySpan: Double
        /// Fraction the board's patience swings.
        public var investorPatienceSpan: Double
        /// Fraction the fee swings.
        public var clientPayoutSpan: Double
        /// Fraction the deadline swings.
        public var clientDeadlineSpan: Double
        /// Fraction the crew bar swings, the other way.
        public var clientSkillBarSpan: Double
        /// Warmth an interview needs before the review moves a band.
        public var pressNotchWarmth: Double
        /// Review points one notch is worth, applied to the outlet the
        /// interview was with.
        public var pressNotchPoints: Int
        /// Hype the interview itself swings at full warmth.
        public var pressHypeSwing: Double
        /// Board pressure points the meeting swings at full warmth.
        public var boardPressureSwing: Double

        public init(
            exchangesBase: Int = 3,
            exchangesPerConversationPoint: Double = 40,
            exchangesMax: Int = 5,
            warmthPerLandedTurn: Double = 16,
            smallTalkFactor: Double = 0.55,
            listenFactor: Double = 0.45,
            shopTalkFactor: Double = 1.2,
            pitchFactor: Double = 2.0,
            missFactor: Double = 0.85,
            wantFactor: Double = 2.0,
            landBase: Double = 0.5,
            landSkillDivisor: Double = 200,
            landCeiling: Double = 0.95,
            energyPerTurn: Double = 1.5,
            moodPerGoodTurn: Double = 1.0,
            investorAmountSpan: Double = 0.25,
            investorEquitySpan: Double = 0.20,
            investorPatienceSpan: Double = 0.30,
            clientPayoutSpan: Double = 0.20,
            clientDeadlineSpan: Double = 0.25,
            clientSkillBarSpan: Double = 0.25,
            pressNotchWarmth: Double = 40,
            pressNotchPoints: Int = 20,
            pressHypeSwing: Double = 12,
            boardPressureSwing: Double = 12
        ) {
            self.exchangesBase = exchangesBase
            self.exchangesPerConversationPoint = exchangesPerConversationPoint
            self.exchangesMax = exchangesMax
            self.warmthPerLandedTurn = warmthPerLandedTurn
            self.smallTalkFactor = smallTalkFactor
            self.listenFactor = listenFactor
            self.shopTalkFactor = shopTalkFactor
            self.pitchFactor = pitchFactor
            self.missFactor = missFactor
            self.wantFactor = wantFactor
            self.landBase = landBase
            self.landSkillDivisor = landSkillDivisor
            self.landCeiling = landCeiling
            self.energyPerTurn = energyPerTurn
            self.moodPerGoodTurn = moodPerGoodTurn
            self.investorAmountSpan = investorAmountSpan
            self.investorEquitySpan = investorEquitySpan
            self.investorPatienceSpan = investorPatienceSpan
            self.clientPayoutSpan = clientPayoutSpan
            self.clientDeadlineSpan = clientDeadlineSpan
            self.clientSkillBarSpan = clientSkillBarSpan
            self.pressNotchWarmth = pressNotchWarmth
            self.pressNotchPoints = pressNotchPoints
            self.pressHypeSwing = pressHypeSwing
            self.boardPressureSwing = boardPressureSwing
        }

        /// The shipped room. Not "off" — there is nothing to switch off
        /// until the player presses *Talk first* — but every span is a
        /// swing around an identity, so the default is neutral in the way
        /// rule 1 asks for.
        public static let `default` = PitchBalance()
    }
}

// Lets `BalanceConfig`'s synthesized decoder read a balance file with no
// `"pitch"` object.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.PitchBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.PitchBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}
