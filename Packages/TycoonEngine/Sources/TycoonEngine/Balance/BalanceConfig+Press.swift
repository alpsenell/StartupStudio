import Foundation

// Iteration 17 — T7 (press and stakes).
//
// `press`: the exclusive and the outlets' standing with the studio
// (`Press.swift`). Every number here is read only once
// `Company.pressStanding` holds something, which takes the player's own
// `.grantExclusive` — no bot sends it, so on every bot and fixture the map is
// empty and the review offset is exactly 0.
//
// - The outlet given the exclusive warms by `exclusiveGain`; every other
//   outlet cools by `snub` (1, not the spec's 2: the coordinator's call, so
//   an exclusive nets +2 standing and the rotation is worth managing).
//   Standing is clamped to ±`cap`.
// - The other outlets' verdicts are embargoed for `embargoDays`; launch
//   week's buyers read the exclusive's score alone.
// - Every launch, every standing drifts `driftPerLaunch` toward 0.
// - An outlet's score on a launch moves by `standing / standingDivisor`.
//   The spec's 0.2 per point (±4 at the cap) was measured first and lost
//   to the noise: `reviewNoiseSigma` is 6.0 and each outlet sits 5.19
//   points (SD, 544 fixture reviews) off its product's mean. Its remedy
//   applies: the divisor is 3 (±6.7 at the cap) and the byline says the
//   standing in words.
//
// `stakes`: a minority stake in a rival (`RivalStakes.swift`), read only behind
// `.buyRivalStake`, which no bot sends.
//
// Both keys are appended at the end of `Balance.json`; a balance file
// without them reads these defaults.

extension BalanceConfig {

    // MARK: - Press

    public struct PressBalance: Codable, Equatable, Sendable {
        /// Standing the outlet given the exclusive gains.
        public var exclusiveGain: Double
        /// Standing every other outlet loses: they read that they were second.
        public var snub: Double
        /// Standing points per review point: an outlet's score moves by
        /// `standing / standingDivisor`.
        public var standingDivisor: Double
        /// How far every standing moves toward 0 with each launch.
        public var driftPerLaunch: Double
        /// The most (and, negated, the least) an outlet can think of you.
        public var cap: Double
        /// Days the other outlets' verdicts wait behind an exclusive.
        public var embargoDays: Int

        public init(
            exclusiveGain: Double = 5,
            snub: Double = 1,
            standingDivisor: Double = 3,
            driftPerLaunch: Double = 1,
            cap: Double = 20,
            embargoDays: Int = 7
        ) {
            self.exclusiveGain = exclusiveGain
            self.snub = snub
            self.standingDivisor = standingDivisor
            self.driftPerLaunch = driftPerLaunch
            self.cap = cap
            self.embargoDays = embargoDays
        }

        /// The shipped numbers.
        public static let `default` = PressBalance()

        private enum CodingKeys: String, CodingKey {
            case exclusiveGain, snub, standingDivisor, driftPerLaunch, cap, embargoDays
        }

        /// Every key optional, falling back to the default.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let fallback = Self.default
            self.init(
                exclusiveGain: try container.decodeIfPresent(Double.self, forKey: .exclusiveGain)
                    ?? fallback.exclusiveGain,
                snub: try container.decodeIfPresent(Double.self, forKey: .snub) ?? fallback.snub,
                standingDivisor: try container.decodeIfPresent(Double.self, forKey: .standingDivisor)
                    ?? fallback.standingDivisor,
                driftPerLaunch: try container.decodeIfPresent(Double.self, forKey: .driftPerLaunch)
                    ?? fallback.driftPerLaunch,
                cap: try container.decodeIfPresent(Double.self, forKey: .cap) ?? fallback.cap,
                embargoDays: try container.decodeIfPresent(Int.self, forKey: .embargoDays)
                    ?? fallback.embargoDays
            )
        }
    }

    // MARK: - Stakes

    public struct StakeBalance: Codable, Equatable, Sendable {
        /// The sizes on offer, as fractions of the rival.
        public var percents: [Double]
        /// A stake costs `valuation × premium × percent`.
        public var premium: Double
        /// And sells back for `valuation × sellBack × percent`.
        public var sellBack: Double
        /// The share of the price that becomes the rival's strength, at
        /// `rivals.valuationPerStrength` dollars a point: your money made
        /// them stronger.
        public var strengthShare: Double
        /// From this stake up, their next topic is on the profile.
        public var roadmapFrom: Double
        /// Their poaching odds against a studio that owns part of them.
        public var poachFactor: Double
        /// Whether the dividend also counts their products off the market.
        /// The spec's remedy if the on-market dividend is too thin.
        public var countOffMarket: Bool
        /// The share of their weekly takings a studio pays out. Not in the
        /// spec, which paid the stake its percent of *revenue*: measured
        /// that returned 90–280% of the price a year on the pacing seeds
        /// and 255% on the campus's Vantage Point — a rival's valuation
        /// (`strength × 4000 × (1 + rep/100)`) is small beside what it
        /// sells. At 0.2 the stake pays back in years, not months.
        public var dividendPayout: Double

        public init(
            percents: [Double] = [0.05, 0.10, 0.25],
            premium: Double = 1.1,
            sellBack: Double = 0.9,
            strengthShare: Double = 0.25,
            roadmapFrom: Double = 0.10,
            poachFactor: Double = 0.5,
            countOffMarket: Bool = false,
            dividendPayout: Double = 0.2
        ) {
            self.percents = percents
            self.premium = premium
            self.sellBack = sellBack
            self.strengthShare = strengthShare
            self.roadmapFrom = roadmapFrom
            self.poachFactor = poachFactor
            self.countOffMarket = countOffMarket
            self.dividendPayout = dividendPayout
        }

        /// The shipped numbers.
        public static let `default` = StakeBalance()

        private enum CodingKeys: String, CodingKey {
            case percents, premium, sellBack, strengthShare, roadmapFrom, poachFactor, countOffMarket
            case dividendPayout
        }

        /// Every key optional, falling back to the default.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let fallback = Self.default
            self.init(
                percents: try container.decodeIfPresent([Double].self, forKey: .percents)
                    ?? fallback.percents,
                premium: try container.decodeIfPresent(Double.self, forKey: .premium) ?? fallback.premium,
                sellBack: try container.decodeIfPresent(Double.self, forKey: .sellBack) ?? fallback.sellBack,
                strengthShare: try container.decodeIfPresent(Double.self, forKey: .strengthShare)
                    ?? fallback.strengthShare,
                roadmapFrom: try container.decodeIfPresent(Double.self, forKey: .roadmapFrom)
                    ?? fallback.roadmapFrom,
                poachFactor: try container.decodeIfPresent(Double.self, forKey: .poachFactor)
                    ?? fallback.poachFactor,
                countOffMarket: try container.decodeIfPresent(Bool.self, forKey: .countOffMarket)
                    ?? fallback.countOffMarket,
                dividendPayout: try container.decodeIfPresent(Double.self, forKey: .dividendPayout)
                    ?? fallback.dividendPayout
            )
        }
    }
}
