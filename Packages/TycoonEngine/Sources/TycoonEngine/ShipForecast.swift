import Foundation
import TycoonContent

/// What shipping this today would actually get you.
///
/// The real decision on a product in development is *ship or keep working*,
/// and until now the screen showed three completion bars and nothing else —
/// so "100% on all three" could mean a quality of 58 and the player had no
/// way to know. Two of the three terms that decide the number are invisible
/// in the UI and always have been, and a third arrived with the codebase:
///
/// - **The crew ceiling.** A product can only be as good as the people who
///   built it. A crew of beginners tops out at `qualityCeilingBase` — 0.35
///   in the shipped balance, and about 0.58 for a founder working alone —
///   and no amount of extra time moves it. It is the single biggest reason
///   a "finished" product reviews badly, and it was nowhere on screen.
/// - **Topic fit.** A type-topic pairing the content catalog dislikes
///   multiplies the whole thing by as little as 0.8.
/// - **The codebase.** A build started on an existing codebase inherits its
///   technical debt, and debt is a quality you cannot polish past however
///   good the crew is. Greenfield builds read exactly 1 here, which is why
///   this term was invisible until there was something to inherit.
///
/// A fourth, `launchMarketScale`, is not a quality term but decides how much
/// of the market is left to sell to: two launches of the same type inside a
/// quarter cut the peak to about 0.61, and that number appears nowhere at
/// all.
///
/// This is a pure projection — it moves nothing and draws nothing.
public struct ShipForecast: Equatable, Sendable {
    /// Quality if shipped today, 0...100.
    public var quality: Double
    /// The quality this product could reach if every pool were full and the
    /// bugs were gone: every ceiling term multiplied together.
    public var crewCeiling: Double
    /// The crew's own share of that ceiling — what this team's skill
    /// allows, before topic fit, tech and the codebase.
    public var skillCeiling: Double
    /// What the inherited codebase's debt allows, 1 for a greenfield
    /// build. The term that lets the sheet say *the codebase caps this at
    /// 61*, which is the whole reason a studio ever refactors.
    public var codebaseCeiling: Double
    /// The debt of the codebase this product is being built on, 0 when
    /// there isn't one.
    public var codebaseDebt: Double
    /// The name of the codebase this product is being built on, `nil` for
    /// a greenfield build.
    public var codebaseName: String?
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
            let cap = Int((crewCeiling * 100).rounded())
            // At the ceiling, and there are two of them. Name whichever is
            // actually holding the number down — telling a studio to hire
            // better people when the problem is the foundations they
            // insisted on reusing is the one piece of advice that would
            // cost them a second bad product.
            if codebaseCeiling < 0.99, codebaseCeiling < skillCeiling {
                return "The codebase caps this at \(cap). Refactoring is the only way past it."
            }
            return crewCeiling < 0.95
                ? "Your crew caps this at \(cap). Better people, not more time."
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
        let codebase = self.codebase(id: product.codebaseID)
        let codebaseDebt = codebase?.debt ?? 0
        let codebaseCeiling = balance.codebase.debtCeiling(codebaseDebt)

        return ShipForecast(
            quality: min(100, max(0,
                100 * completion * topicFit * bugFactor * techMultiplier * ceiling
                    * codebaseCeiling
            )),
            crewCeiling: min(1, topicFit * techMultiplier * ceiling * codebaseCeiling),
            skillCeiling: ceiling,
            codebaseCeiling: codebaseCeiling,
            codebaseDebt: codebaseDebt,
            codebaseName: codebase?.name,
            topicFit: topicFit,
            bugFactor: bugFactor,
            marketScale: ProductSystem.launchMarketScale(
                for: product, state: self, balance: balance
            ),
            canShip: dev.codePts >= balance.shipCodeThreshold * type.codePts
        )
    }
}
