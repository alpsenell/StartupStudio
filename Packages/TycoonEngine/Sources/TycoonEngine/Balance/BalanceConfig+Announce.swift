import Foundation

// MARK: J5 (announce)

/// Iteration 12 — J5. What a ship date said out loud is worth, and what
/// missing it costs (`"announce"` in `Balance.json`), plus the premium
/// review curve that lives beside the price tiers
/// (`"economy.premiumReviewCurve"`).
///
/// Announcing is a new action no bot sends, so the block's defaults are the
/// feature's own numbers; nothing reads them until a founder names a day.
/// The premium curve is the other way round: its default is *off* (a slope
/// of zero is the flat 0.6 every test economy was written against), and the
/// shipped balance turns it on. No bot ever prices premium, so neither
/// moves a pacing gate.
extension BalanceConfig {
    public struct AnnounceBalance: Codable, Equatable, Sendable {
        /// The least notice an announcement can give, in days. Three weeks,
        /// or it is not an announcement, it is a launch.
        public var minLeadDays: Int
        /// The most slack a date can have over today's ship-gate ETA. The
        /// check found ETA + 28 never missed (100% of 521 builds), which is
        /// no promise at all; at + 14 the gate held for 94–99%.
        public var maxSlackDays: Int
        /// Today's ship-gate ETA must be at least this far away for a date
        /// to be given at all. The "how it fails" check found the ETA is
        /// right to the day (median error 0 at 50% progress) and a sheet
        /// date at ETA + 14 held for 94–99% of builds — so a date for a
        /// build that could nearly ship now, three weeks out, was all
        /// upside. Only an early announcement earns the hype.
        public var earlyLeadDays: Int
        /// Daily hype decay on an announced build, in place of
        /// `hypeDecayRate` (0.02). Over thirty days 0.99³⁰ keeps 74% of the
        /// hype where 0.98³⁰ keeps 55%.
        public var hypeDecayRate: Double
        /// Every campaign on an announced build lands this much harder.
        public var campaignFactor: Double
        /// The first missed date: reputation lost, and what hype is left.
        public var firstSlipReputation: Double
        public var firstSlipHypeFactor: Double
        /// The second: worse, and the announcement is void.
        public var secondSlipReputation: Double
        public var secondSlipHypeFactor: Double
        /// After a first slip the press prints a new date: today's ETA plus
        /// this many days.
        public var redateDays: Int
        /// An announced product is ripe for the copycat this many weeks
        /// after launch, where `RivalDepthTuning.copycatDelayWeeks` is 8.
        public var copycatDelayWeeks: Int
        /// Warmth the launch-week interview starts with when the date
        /// holds; the same taken away when today's ETA is past it.
        public var interviewWarmth: Double

        public init(
            minLeadDays: Int = 21,
            maxSlackDays: Int = 182,
            earlyLeadDays: Int = 14,
            hypeDecayRate: Double = 0.01,
            campaignFactor: Double = 1.25,
            firstSlipReputation: Double = 4,
            firstSlipHypeFactor: Double = 0.6,
            secondSlipReputation: Double = 8,
            secondSlipHypeFactor: Double = 0.4,
            redateDays: Int = 14,
            copycatDelayWeeks: Int = 4,
            interviewWarmth: Double = 12
        ) {
            self.minLeadDays = minLeadDays
            self.maxSlackDays = maxSlackDays
            self.earlyLeadDays = earlyLeadDays
            self.hypeDecayRate = hypeDecayRate
            self.campaignFactor = campaignFactor
            self.firstSlipReputation = firstSlipReputation
            self.firstSlipHypeFactor = firstSlipHypeFactor
            self.secondSlipReputation = secondSlipReputation
            self.secondSlipHypeFactor = secondSlipHypeFactor
            self.redateDays = redateDays
            self.copycatDelayWeeks = copycatDelayWeeks
            self.interviewWarmth = interviewWarmth
        }

        public static let `default` = AnnounceBalance()

        private enum CodingKeys: String, CodingKey {
            case minLeadDays, maxSlackDays, earlyLeadDays, hypeDecayRate, campaignFactor
            case firstSlipReputation, firstSlipHypeFactor
            case secondSlipReputation, secondSlipHypeFactor
            case redateDays, copycatDelayWeeks, interviewWarmth
        }

        /// Every key optional, falling back to the default.
        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let d = AnnounceBalance.default
            self.init(
                minLeadDays: try c.decodeIfPresent(Int.self, forKey: .minLeadDays) ?? d.minLeadDays,
                maxSlackDays: try c.decodeIfPresent(Int.self, forKey: .maxSlackDays) ?? d.maxSlackDays,
                earlyLeadDays: try c.decodeIfPresent(Int.self, forKey: .earlyLeadDays) ?? d.earlyLeadDays,
                hypeDecayRate: try c.decodeIfPresent(Double.self, forKey: .hypeDecayRate) ?? d.hypeDecayRate,
                campaignFactor: try c.decodeIfPresent(Double.self, forKey: .campaignFactor) ?? d.campaignFactor,
                firstSlipReputation: try c.decodeIfPresent(Double.self, forKey: .firstSlipReputation)
                    ?? d.firstSlipReputation,
                firstSlipHypeFactor: try c.decodeIfPresent(Double.self, forKey: .firstSlipHypeFactor)
                    ?? d.firstSlipHypeFactor,
                secondSlipReputation: try c.decodeIfPresent(Double.self, forKey: .secondSlipReputation)
                    ?? d.secondSlipReputation,
                secondSlipHypeFactor: try c.decodeIfPresent(Double.self, forKey: .secondSlipHypeFactor)
                    ?? d.secondSlipHypeFactor,
                redateDays: try c.decodeIfPresent(Int.self, forKey: .redateDays) ?? d.redateDays,
                copycatDelayWeeks: try c.decodeIfPresent(Int.self, forKey: .copycatDelayWeeks)
                    ?? d.copycatDelayWeeks,
                interviewWarmth: try c.decodeIfPresent(Double.self, forKey: .interviewWarmth) ?? d.interviewWarmth
            )
        }
    }

    /// I1. Premium demand read off the reviews:
    /// `min(cap, max(floor, tierDemand + slope × (review − pivot)))`.
    /// With the shipped 0.02 / 75 / 0.8 a review of 85 reaches 0.8, which
    /// at ×1.6 the price is 1.28 of standard's revenue per buyer reached;
    /// the break-even with standard is a review of about 76.
    ///
    /// `off` (slope 0, bug factor 1) is the default, and reads back the
    /// flat `priceTiers.premium.demandFactor` exactly.
    public struct AnnouncePremiumCurve: Codable, Equatable, Sendable {
        /// Demand per review point above (or below) the pivot.
        public var slope: Double
        /// The review score at which premium demand is the tier's own.
        public var pivot: Double
        /// The most demand premium can reach, however good the reviews.
        public var cap: Double
        /// The least: a badly reviewed premium product still has buyers.
        public var floor: Double
        /// Live bugs cost a premium product this many times the usual
        /// `liveBugSalesPenalty` each. People who paid more notice more.
        public var liveBugFactor: Double

        public init(
            slope: Double = 0,
            pivot: Double = 75,
            cap: Double = 1,
            floor: Double = 0,
            liveBugFactor: Double = 1
        ) {
            self.slope = slope
            self.pivot = pivot
            self.cap = cap
            self.floor = floor
            self.liveBugFactor = liveBugFactor
        }

        public static let off = AnnouncePremiumCurve()

        private enum CodingKeys: String, CodingKey {
            case slope, pivot, cap, floor, liveBugFactor
        }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let d = AnnouncePremiumCurve.off
            self.init(
                slope: try c.decodeIfPresent(Double.self, forKey: .slope) ?? d.slope,
                pivot: try c.decodeIfPresent(Double.self, forKey: .pivot) ?? d.pivot,
                cap: try c.decodeIfPresent(Double.self, forKey: .cap) ?? d.cap,
                floor: try c.decodeIfPresent(Double.self, forKey: .floor) ?? d.floor,
                liveBugFactor: try c.decodeIfPresent(Double.self, forKey: .liveBugFactor) ?? d.liveBugFactor
            )
        }
    }
}

extension BalanceConfig.EconomyBalance {
    /// I1. The demand a tier earns at this review score. Every tier but
    /// premium, and premium with the curve off, is the table's number.
    public func demandFactor(for tier: PriceTier, reviewScore: Int) -> Double {
        let base = priceTier(tier).demandFactor
        let curve = premiumReviewCurve
        guard tier == .premium, curve.slope != 0 else { return base }
        let raw = base + curve.slope * (Double(reviewScore) - curve.pivot)
        return min(curve.cap, max(curve.floor, raw))
    }

    /// I1. What one live bug costs this tier in sales.
    public func liveBugSalesPenalty(for tier: PriceTier) -> Double {
        let factor = premiumReviewCurve.liveBugFactor
        guard tier == .premium, factor != 1 else { return liveBugSalesPenalty }
        return liveBugSalesPenalty * factor
    }

    /// Revenue per buyer reached against standard's list price, at this
    /// review score: price × demand. The number the live-ops caption says.
    public func revenueFactor(for tier: PriceTier, reviewScore: Int) -> Double {
        priceTier(tier).priceFactor * demandFactor(for: tier, reviewScore: reviewScore)
    }
}

// The concrete overloads win over the generic `decode(_:forKey:)` in the
// synthesized decoders of `BalanceConfig` and `EconomyBalance`, so a balance
// file without either key still loads — with the feature's defaults and the
// curve off.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.AnnounceBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.AnnounceBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }

    func decode(
        _ type: BalanceConfig.AnnouncePremiumCurve.Type,
        forKey key: Key
    ) throws -> BalanceConfig.AnnouncePremiumCurve {
        try decodeIfPresent(type, forKey: key) ?? .off
    }
}

// MARK: end J5
