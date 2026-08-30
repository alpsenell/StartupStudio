import Foundation
import TycoonContent

/// What shipping this today would actually get you.
///
/// The real decision on a product in development is *ship or keep working*,
/// and until now the screen showed three completion bars and nothing else —
/// so "100% on all three" could mean a quality of 58 and the player had no
/// way to know. Two of the three terms that decide the number are invisible
/// in the UI and always have been:
///
/// - **The crew ceiling.** A product can only be as good as the people who
///   built it. A crew of beginners tops out at `qualityCeilingBase` — 0.35
///   in the shipped balance, and about 0.58 for a founder working alone —
///   and no amount of extra time moves it. It is the single biggest reason
///   a "finished" product reviews badly, and it was nowhere on screen.
/// - **Topic fit.** A type-topic pairing the content catalog dislikes
///   multiplies the whole thing by as little as 0.8.
///
/// A third, `launchMarketScale`, is not a quality term but decides how much
/// of the market is left to sell to: two launches of the same type inside a
/// quarter cut the peak to about 0.61, and that number appears nowhere at
/// all.
///
/// This is a pure projection — it moves nothing and draws nothing.
public struct ShipForecast: Equatable, Sendable {
    /// Quality if shipped today, 0...100.
    public var quality: Double
    /// The quality this crew could reach if every pool were full and the
    /// bugs were gone: the ceiling the team itself imposes.
    public var crewCeiling: Double
    /// `fitByType` for this pairing, 1 when the catalog is neutral.
    public var topicFit: Double
    /// What open bugs are costing right now, as a multiplier.
    public var bugFactor: Double
    /// The share of the launch peak still available after saturation and
    /// genre fatigue.
    public var marketScale: Double
    /// Whether the code pool has passed `shipCodeThreshold`.
    public var canShip: Bool

    /// The biggest thing standing between this product and a better score,
    /// in the player's words — or `nil` when it is as good as it will get.
    public var limitingFactor: String? {
        if quality >= crewCeiling * 100 - 1 {
            return crewCeiling < 0.95
                ? "Your crew caps this at \(Int((crewCeiling * 100).rounded())). Better people, not more time."
                : nil
        }
        if bugFactor < 0.95 {
            return "Open bugs are costing \(Int(((1 - bugFactor) * 100).rounded()))% of the score."
        }
        if topicFit < 0.95 {
            return "This type and topic are a poor match (×\(topicFit.formatted(.number.precision(.fractionLength(2)))))."
        }
        return "More work still pays — the pools aren't full."
    }
}

extension GameState {
    /// Projects what `productID` would ship as today. `nil` for anything
    /// not in development.
    public func shipForecast(
        productID: UUID,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> ShipForecast? {
        guard let product = product(id: productID),
              case .development(let dev) = product.stage,
              let type = content.productType(product.typeID)
        else { return nil }

        // The same arithmetic `ProductSystem.ship` performs, so the sheet
        // cannot promise a number the launch will not produce.
        let topicFit = content.topic(product.topicID)?.fitByType[product.typeID] ?? 1
        let weights = balance.qualityWeights
        let completion = weights.design * min(1, dev.designPts / type.designPts)
            + weights.code * min(1, dev.codePts / type.codePts)
            + weights.polish * min(1, dev.polishPts / type.polishPts)
        let bugFactor = 1 - min(balance.bugPenaltyCap, Double(dev.openBugs) / type.codePts)
        let techMultiplier = qualityTechMultiplier(
            content: content, cap: balance.techQualityMultiplierCap
        )
        let ceiling = ProductSystem.qualityCeiling(
            skillIndex: dev.crewSkillIndex, balance: balance
        )

        return ShipForecast(
            quality: min(100, max(0,
                100 * completion * topicFit * bugFactor * techMultiplier * ceiling
            )),
            crewCeiling: min(1, topicFit * techMultiplier * ceiling),
            topicFit: topicFit,
            bugFactor: bugFactor,
            marketScale: ProductSystem.launchMarketScale(
                for: product, state: self, balance: balance
            ),
            canShip: dev.codePts >= balance.shipCodeThreshold * type.codePts
        )
    }
}
