import Foundation

extension BalanceConfig {
    /// The `"clientBook"` block of `Balance.json`: what a settled job
    /// does to a client's trust, when a client counts as trusted or
    /// cold, and what a trusted client's warmed offer is worth.
    ///
    /// **Neutrality.** Every number here is read behind
    /// `ClientBook.noticed`, which only `.noticeClientBookOpened` sets
    /// and only the app sends — so the pacing bots, which accept and
    /// settle contracts all run long, never read a value from it. The
    /// warmed offer itself draws nothing: it rewrites a rolled offer
    /// after the sheet's documented draws, the `sponsorOneOffer` trick.
    ///
    /// Every field has a default (the shipped value), and the decoder
    /// reads each `IfPresent`, so an older balance file still decodes.
    public struct ClientBookBalance: Codable, Equatable, Sendable {
        // MARK: Trust

        /// Where a client the studio has just met starts.
        public var trustBase: Double
        /// Trust gained delivering at or above
        /// `contractQuality.greatThreshold` — full pay, full credit.
        public var trustGreatGain: Double
        /// Trust gained on an okay delivery: they paid less, but the
        /// thing shipped.
        public var trustOkayGain: Double
        /// Trust lost on a poor delivery — the grade that already costs
        /// half the pay and a little reputation.
        public var trustPoorLoss: Double
        /// Trust lost blowing the deadline entirely.
        public var trustFailLoss: Double

        // MARK: Warm and cold

        /// Trust at or above this warms the client's next offers.
        public var trustedThreshold: Double
        /// Days a botched or failed job leaves the client cold: no
        /// warmed offers until it passes.
        public var coldDays: Int
        /// How many offers per sheet known clients may claim.
        public var warmedOffersPerSheet: Int
        /// A warmed offer's payout bonus runs this span, scaled by how
        /// far past `trustedThreshold` the client's trust sits.
        public var warmPayoutBonusMin: Double
        public var warmPayoutBonusMax: Double
        /// A trusted client is patient: multiplier on the rolled
        /// deadline, rounded up like the sponsor's.
        public var warmDeadlineFactor: Double

        public init(
            trustBase: Double = 40,
            trustGreatGain: Double = 12,
            trustOkayGain: Double = 5,
            trustPoorLoss: Double = 15,
            trustFailLoss: Double = 20,
            trustedThreshold: Double = 70,
            coldDays: Int = 91,
            warmedOffersPerSheet: Int = 2,
            warmPayoutBonusMin: Double = 0.10,
            warmPayoutBonusMax: Double = 0.25,
            warmDeadlineFactor: Double = 1.25
        ) {
            self.trustBase = trustBase
            self.trustGreatGain = trustGreatGain
            self.trustOkayGain = trustOkayGain
            self.trustPoorLoss = trustPoorLoss
            self.trustFailLoss = trustFailLoss
            self.trustedThreshold = trustedThreshold
            self.coldDays = coldDays
            self.warmedOffersPerSheet = warmedOffersPerSheet
            self.warmPayoutBonusMin = warmPayoutBonusMin
            self.warmPayoutBonusMax = warmPayoutBonusMax
            self.warmDeadlineFactor = warmDeadlineFactor
        }

        public static let `default` = ClientBookBalance()

        /// The payout bonus a client of `trust` earns: the minimum at
        /// the threshold, the maximum at 100, linear between.
        public func warmPayoutBonus(forTrust trust: Double) -> Double {
            guard trustedThreshold < 100 else { return warmPayoutBonusMin }
            let reach = min(1, max(0, (trust - trustedThreshold) / (100 - trustedThreshold)))
            return warmPayoutBonusMin + reach * (warmPayoutBonusMax - warmPayoutBonusMin)
        }

        // MARK: Codable

        private enum CodingKeys: String, CodingKey {
            case trustBase, trustGreatGain, trustOkayGain, trustPoorLoss, trustFailLoss
            case trustedThreshold, coldDays, warmedOffersPerSheet
            case warmPayoutBonusMin, warmPayoutBonusMax, warmDeadlineFactor
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let shipped = ClientBookBalance()
            self.init(
                trustBase: try container.decodeIfPresent(Double.self, forKey: .trustBase)
                    ?? shipped.trustBase,
                trustGreatGain: try container.decodeIfPresent(Double.self, forKey: .trustGreatGain)
                    ?? shipped.trustGreatGain,
                trustOkayGain: try container.decodeIfPresent(Double.self, forKey: .trustOkayGain)
                    ?? shipped.trustOkayGain,
                trustPoorLoss: try container.decodeIfPresent(Double.self, forKey: .trustPoorLoss)
                    ?? shipped.trustPoorLoss,
                trustFailLoss: try container.decodeIfPresent(Double.self, forKey: .trustFailLoss)
                    ?? shipped.trustFailLoss,
                trustedThreshold: try container.decodeIfPresent(Double.self, forKey: .trustedThreshold)
                    ?? shipped.trustedThreshold,
                coldDays: try container.decodeIfPresent(Int.self, forKey: .coldDays)
                    ?? shipped.coldDays,
                warmedOffersPerSheet: try container.decodeIfPresent(Int.self, forKey: .warmedOffersPerSheet)
                    ?? shipped.warmedOffersPerSheet,
                warmPayoutBonusMin: try container.decodeIfPresent(Double.self, forKey: .warmPayoutBonusMin)
                    ?? shipped.warmPayoutBonusMin,
                warmPayoutBonusMax: try container.decodeIfPresent(Double.self, forKey: .warmPayoutBonusMax)
                    ?? shipped.warmPayoutBonusMax,
                warmDeadlineFactor: try container.decodeIfPresent(Double.self, forKey: .warmDeadlineFactor)
                    ?? shipped.warmDeadlineFactor
            )
        }
    }
}

// The concrete overload wins over the generic `decode(_:forKey:)` in
// `BalanceConfig`'s synthesized decoder, so a balance file without the key
// still loads, with the defaults.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.ClientBookBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.ClientBookBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}
