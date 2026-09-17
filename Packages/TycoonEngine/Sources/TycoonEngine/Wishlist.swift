import Foundation
import TycoonContent

// MARK: The wishlist

// A live product accumulates concrete asks: feature cards from the
// catalog that are not on its board, ranked by what the market wants
// this quarter (`FeatureBoard.appetite`), what pairs with the cards
// already placed, and what a rival's clone already shipped
// (`RivalMarket.copiedBy`). Wishes are derived on demand, never stored,
// and draw nothing from any stream — the same discipline as
// `FeatureBoardReading` — so a save holds no wishlist and every pinned
// suite keeps its bytes. Acting on one is
// `.startUpdate(productID:featureCardID:)`, which only the player's own
// tap sends; a bot's plain `.startUpdate` is the patch it always was.

/// One wish on a live product's card, ready to render.
public struct WishReading: Equatable, Sendable, Identifiable {
    public var id: String { cardID }
    /// The wished card.
    public var cardID: String
    /// Its face, for the row and the update button.
    public var name: String
    /// The share of the audience asking for it — derived and
    /// deterministic, so two players on the same seed read the same
    /// number all quarter.
    public var demandPercent: Int
    /// Why they want it, in the player's words.
    public var reason: String

    public init(cardID: String, name: String, demandPercent: Int, reason: String) {
        self.cardID = cardID
        self.name = name
        self.demandPercent = demandPercent
        self.reason = reason
    }
}

/// The derivation: a pure read of the catalog against one product.
public enum Wishlist {
    /// The wishes on `product` today, loudest first. Empty for a product
    /// still in development or off the market, and for a board that
    /// already holds everything the studio can build here.
    public static func wishes(
        for product: Product,
        state: GameState,
        content: ContentCatalog,
        balance: BalanceConfig
    ) -> [WishReading] {
        guard case .released(let info) = product.stage, !info.offMarket else { return [] }
        let config = balance.wishlist
        guard config.wishCount > 0 else { return [] }

        let appetite = Set(FeatureBoard.appetite(state: state, balance: balance))
        let placedIDs = Set(product.features)
        let placedCards = product.features.compactMap { content.featureCard($0) }
        let quarter = state.day / max(1, balance.featureBoard.appetiteQuarterDays)

        let readings: [WishReading] = content.features.compactMap { card in
            guard !placedIDs.contains(card.id),
                  FeatureBoard.isUnlocked(card, state: state),
                  card.fits(typeID: product.typeID) || card.fits(topicID: product.topicID)
            else { return nil }

            let partners = placedCards.filter {
                $0.synergies.contains(card.id) || card.synergies.contains($0.id)
            }
            let rides = card.appetiteTag.map { appetite.contains($0) } ?? false
            let copier = RivalMarket.copiedBy(
                cardName: card.name, topicID: product.topicID, state: state
            )

            var demand = config.demandBase
            if rides { demand += config.demandAppetite }
            demand += Double(partners.count) * config.demandSynergy
            if copier != nil { demand += config.demandCopied }
            // A few deterministic points of texture, re-rolled with the
            // quarter, so two products' wishlists don't read identically.
            // A stateless hash, not a stream: nothing here can move a
            // draw.
            demand += Double(jitter(
                seed: state.seed, quarter: quarter, productID: product.id, cardID: card.id
            ) % UInt64(max(1, Int(config.demandJitter))))
            let percent = Int(min(config.demandCap, max(1, demand)).rounded())

            let reason: String
            if let copier {
                reason = "\(copier.name) shipped it first — your users want it too."
            } else if rides, let tag = card.appetiteTag {
                reason = "The market wants \(tag) this quarter."
            } else if let partner = partners.first {
                reason = "Pairs with \(partner.name), which you already have."
            } else {
                reason = "A steady ask from the people using it."
            }

            return WishReading(
                cardID: card.id, name: card.name, demandPercent: percent, reason: reason
            )
        }

        return readings
            .sorted { lhs, rhs in
                if lhs.demandPercent != rhs.demandPercent {
                    return lhs.demandPercent > rhs.demandPercent
                }
                return lhs.cardID < rhs.cardID
            }
            .prefix(max(0, config.wishCount))
            .map { $0 }
    }

    /// SplitMix64's finalizer over the seed, the quarter, the product and
    /// the card — the same stateless trick `FeatureBoard.appetite` uses.
    private static func jitter(
        seed: UInt64, quarter: Int, productID: UUID, cardID: String
    ) -> UInt64 {
        var folded = seed &+ UInt64(bitPattern: Int64(quarter)) &* 0x9E37_79B9_7F4A_7C15
        folded = productID.uuidString.utf8.reduce(folded) { $0 &* 31 &+ UInt64($1) }
        folded = cardID.utf8.reduce(folded) { $0 &* 31 &+ UInt64($1) }
        return mix(folded)
    }

    private static func mix(_ value: UInt64) -> UInt64 {
        var z = value &+ 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
