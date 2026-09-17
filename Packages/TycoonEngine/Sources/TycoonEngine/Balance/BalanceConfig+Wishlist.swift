import Foundation

extension BalanceConfig {
    /// The `"wishlist"` block of `Balance.json`: how loudly a live
    /// product's users ask for the cards it doesn't have, and what
    /// shipping one in an update is worth.
    ///
    /// **Neutrality.** The demand numbers feed a pure read
    /// (`Wishlist.wishes`) that only the app renders, and the two update
    /// bonuses are keyed on `ProductUpdate.featureCardID`, which only the
    /// player's own `.startUpdate(productID:featureCardID:)` ever sets —
    /// a bot's plain update reads none of this and lands the patch it
    /// always did.
    ///
    /// Every field has a default (the shipped value), and the decoder
    /// reads each `IfPresent`, so an older balance file still decodes.
    public struct WishlistBalance: Codable, Equatable, Sendable {
        // MARK: The asks

        /// Wishes shown per live product.
        public var wishCount: Int
        /// Where every eligible card's demand starts, in percent of the
        /// audience.
        public var demandBase: Double
        /// Added when the card rides the quarter's appetite.
        public var demandAppetite: Double
        /// Added per synergy partner already on the board.
        public var demandSynergy: Double
        /// Added when a rival's live clone already shipped the card —
        /// "everyone has it now".
        public var demandCopied: Double
        /// Deterministic texture, 0..<this, hashed from the seed, the
        /// quarter, the product and the card.
        public var demandJitter: Double
        /// Demand never reads above this: a wish is a share of the
        /// audience, not the audience.
        public var demandCap: Double

        // MARK: The update that answers one

        /// Flat quality on top of the routine patch's decaying bonus when
        /// the update carries a wished card.
        public var featureQualityBonus: Double
        /// Multiplier on `economy.updateReviewWeight` for that update's
        /// re-review: shipping a thing earns a longer second look.
        public var featureReviewWeightFactor: Double

        public init(
            wishCount: Int = 3,
            demandBase: Double = 12,
            demandAppetite: Double = 18,
            demandSynergy: Double = 7,
            demandCopied: Double = 15,
            demandJitter: Double = 8,
            demandCap: Double = 70,
            featureQualityBonus: Double = 3,
            featureReviewWeightFactor: Double = 1.5
        ) {
            self.wishCount = wishCount
            self.demandBase = demandBase
            self.demandAppetite = demandAppetite
            self.demandSynergy = demandSynergy
            self.demandCopied = demandCopied
            self.demandJitter = demandJitter
            self.demandCap = demandCap
            self.featureQualityBonus = featureQualityBonus
            self.featureReviewWeightFactor = featureReviewWeightFactor
        }

        public static let `default` = WishlistBalance()

        // MARK: Codable

        private enum CodingKeys: String, CodingKey {
            case wishCount, demandBase, demandAppetite, demandSynergy
            case demandCopied, demandJitter, demandCap
            case featureQualityBonus, featureReviewWeightFactor
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let shipped = WishlistBalance()
            self.init(
                wishCount: try container.decodeIfPresent(Int.self, forKey: .wishCount)
                    ?? shipped.wishCount,
                demandBase: try container.decodeIfPresent(Double.self, forKey: .demandBase)
                    ?? shipped.demandBase,
                demandAppetite: try container.decodeIfPresent(Double.self, forKey: .demandAppetite)
                    ?? shipped.demandAppetite,
                demandSynergy: try container.decodeIfPresent(Double.self, forKey: .demandSynergy)
                    ?? shipped.demandSynergy,
                demandCopied: try container.decodeIfPresent(Double.self, forKey: .demandCopied)
                    ?? shipped.demandCopied,
                demandJitter: try container.decodeIfPresent(Double.self, forKey: .demandJitter)
                    ?? shipped.demandJitter,
                demandCap: try container.decodeIfPresent(Double.self, forKey: .demandCap)
                    ?? shipped.demandCap,
                featureQualityBonus: try container.decodeIfPresent(
                    Double.self, forKey: .featureQualityBonus
                ) ?? shipped.featureQualityBonus,
                featureReviewWeightFactor: try container.decodeIfPresent(
                    Double.self, forKey: .featureReviewWeightFactor
                ) ?? shipped.featureReviewWeightFactor
            )
        }
    }
}
