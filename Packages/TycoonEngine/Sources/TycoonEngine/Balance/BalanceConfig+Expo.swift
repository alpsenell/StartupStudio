import Foundation

// MARK: T5 (expo and pre-orders)

// Iteration 17 — T5. The expo (genre G2) and pre-orders on an announced
// date (genre G6 merged with player P4), in one block: `"expo"` in
// `Balance.json`, appended at the end, with `"preorders"` inside it.
//
// Every number here is read only behind `.showAtExpo`, `.skipExpo` and
// `.openPreorders`, which no bot sends, or by state those actions write.
// A run that never books a booth or opens pre-orders reads none of them; a
// balance file without the key reads these defaults.

extension BalanceConfig {
    public struct ExpoBalance: Codable, Equatable, Sendable {
        /// The show's day of the year, like `AwardsJudge.ceremonyDayOfYear`
        /// (350): the ceremony's opposite, in June.
        public var dayOfYear: Int
        /// From this many days before the show the Now card and the queue
        /// say *Expo in N days*, and a booth can be booked.
        public var noticeDays: Int
        /// A booth by office tier (`OfficeTier` raw value → dollars). A tier
        /// that is not listed (the garage) cannot take a booth; the
        /// hallway is open to anyone.
        public var boothByTier: [String: Int]
        /// Working the hallway: a laptop and a lanyard.
        public var hallway: Int
        /// The hype a shown build gets at a booth, before the marketing
        /// team's trait factor and the factors below.
        public var hype: Double
        /// The hallway, or a booth nobody staffed, works at this share of
        /// everything: the hype and the reputation, good or bad.
        public var hallwayFactor: Double
        /// More open bugs than this and the demo crashes.
        public var crashBugs: Int
        /// What a crash leaves of the hype.
        public var crashHypeFactor: Double
        /// Reputation for a demo whose quality so far is at least
        /// `goodQuality` (`ShipForecast.quality`), and for a crash (taken
        /// away).
        public var reputationGood: Double
        public var goodQuality: Double
        public var reputationCrash: Double
        /// The press saw the demo: the shown build's review expectation
        /// rises this much at ship.
        public var expectationBump: Double
        /// A marketer at the booth instead of the founder pitches at this
        /// share of the hype.
        public var marketerFactor: Double
        /// What the founder's day at the show costs in energy, on top of
        /// the evening.
        public var founderEnergy: Double
        /// A build shown at the expo is ripe for the copycat this many
        /// weeks after launch, where `RivalDepthTuning.copycatDelayWeeks`
        /// is 8 — the same head start J5 gives an announced date.
        public var copycatDelayWeeks: Int
        /// Pre-orders on an announced date.
        public var preorders: PreorderBalance

        public init(
            dayOfYear: Int = 182,
            noticeDays: Int = 28,
            boothByTier: [String: Int] = ["loft": 2_500, "studio": 7_500, "campus": 15_000],
            hallway: Int = 900,
            hype: Double = 30,
            hallwayFactor: Double = 0.5,
            crashBugs: Int = 25,
            crashHypeFactor: Double = 0.5,
            reputationGood: Double = 3,
            goodQuality: Double = 60,
            reputationCrash: Double = 3,
            expectationBump: Double = 3,
            marketerFactor: Double = 0.7,
            founderEnergy: Double = 8,
            copycatDelayWeeks: Int = 3,
            preorders: PreorderBalance = .default
        ) {
            self.dayOfYear = dayOfYear
            self.noticeDays = noticeDays
            self.boothByTier = boothByTier
            self.hallway = hallway
            self.hype = hype
            self.hallwayFactor = hallwayFactor
            self.crashBugs = crashBugs
            self.crashHypeFactor = crashHypeFactor
            self.reputationGood = reputationGood
            self.goodQuality = goodQuality
            self.reputationCrash = reputationCrash
            self.expectationBump = expectationBump
            self.marketerFactor = marketerFactor
            self.founderEnergy = founderEnergy
            self.copycatDelayWeeks = copycatDelayWeeks
            self.preorders = preorders
        }

        /// The shipped numbers.
        public static let `default` = ExpoBalance()

        private enum CodingKeys: String, CodingKey {
            case dayOfYear, noticeDays, boothByTier, hallway, hype, hallwayFactor
            case crashBugs, crashHypeFactor, reputationGood, goodQuality, reputationCrash
            case expectationBump, marketerFactor, founderEnergy, copycatDelayWeeks
            case preorders
        }

        /// Every key optional, falling back to the default.
        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let d = Self.default
            self.init(
                dayOfYear: try c.decodeIfPresent(Int.self, forKey: .dayOfYear) ?? d.dayOfYear,
                noticeDays: try c.decodeIfPresent(Int.self, forKey: .noticeDays) ?? d.noticeDays,
                boothByTier: try c.decodeIfPresent([String: Int].self, forKey: .boothByTier) ?? d.boothByTier,
                hallway: try c.decodeIfPresent(Int.self, forKey: .hallway) ?? d.hallway,
                hype: try c.decodeIfPresent(Double.self, forKey: .hype) ?? d.hype,
                hallwayFactor: try c.decodeIfPresent(Double.self, forKey: .hallwayFactor) ?? d.hallwayFactor,
                crashBugs: try c.decodeIfPresent(Int.self, forKey: .crashBugs) ?? d.crashBugs,
                crashHypeFactor: try c.decodeIfPresent(Double.self, forKey: .crashHypeFactor) ?? d.crashHypeFactor,
                reputationGood: try c.decodeIfPresent(Double.self, forKey: .reputationGood) ?? d.reputationGood,
                goodQuality: try c.decodeIfPresent(Double.self, forKey: .goodQuality) ?? d.goodQuality,
                reputationCrash: try c.decodeIfPresent(Double.self, forKey: .reputationCrash) ?? d.reputationCrash,
                expectationBump: try c.decodeIfPresent(Double.self, forKey: .expectationBump) ?? d.expectationBump,
                marketerFactor: try c.decodeIfPresent(Double.self, forKey: .marketerFactor) ?? d.marketerFactor,
                founderEnergy: try c.decodeIfPresent(Double.self, forKey: .founderEnergy) ?? d.founderEnergy,
                copycatDelayWeeks: try c.decodeIfPresent(Int.self, forKey: .copycatDelayWeeks)
                    ?? d.copycatDelayWeeks,
                preorders: try c.decodeIfPresent(PreorderBalance.self, forKey: .preorders) ?? d.preorders
            )
        }

        /// The booth's price at `tier`, `nil` where there is no booth to
        /// take (the garage).
        public func boothPrice(for tier: OfficeTier) -> Int? {
            boothByTier[tier.rawValue]
        }
    }

    /// Pre-orders: launch-week units sold early against an announced date.
    public struct PreorderBalance: Codable, Equatable, Sendable {
        /// The share of the forecast's launch-week units sold early.
        public var fraction: Double
        /// What a pre-order costs, as a share of the standard price.
        public var price: Double
        /// The least time between opening and the announced date.
        public var minDaysBefore: Int
        /// The first slip refunds this share of the units sold.
        public var refundPerSlip: Double
        /// The second slip refunds the rest, and costs this much
        /// reputation on top of J5's own.
        public var voidReputation: Double

        public init(
            fraction: Double = 0.3,
            price: Double = 0.65,
            minDaysBefore: Int = 21,
            refundPerSlip: Double = 0.34,
            voidReputation: Double = 4
        ) {
            self.fraction = fraction
            self.price = price
            self.minDaysBefore = minDaysBefore
            self.refundPerSlip = refundPerSlip
            self.voidReputation = voidReputation
        }

        public static let `default` = PreorderBalance()

        private enum CodingKeys: String, CodingKey {
            case fraction, price, minDaysBefore, refundPerSlip, voidReputation
        }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let d = Self.default
            self.init(
                fraction: try c.decodeIfPresent(Double.self, forKey: .fraction) ?? d.fraction,
                price: try c.decodeIfPresent(Double.self, forKey: .price) ?? d.price,
                minDaysBefore: try c.decodeIfPresent(Int.self, forKey: .minDaysBefore) ?? d.minDaysBefore,
                refundPerSlip: try c.decodeIfPresent(Double.self, forKey: .refundPerSlip) ?? d.refundPerSlip,
                voidReputation: try c.decodeIfPresent(Double.self, forKey: .voidReputation) ?? d.voidReputation
            )
        }
    }
}

// Lets `BalanceConfig`'s synthesized decoder read a balance file with no
// `"expo"` object.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.ExpoBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.ExpoBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}

// MARK: end T5
