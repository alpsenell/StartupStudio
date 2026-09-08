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
    /// M1: what the feature board multiplies the score by. Exactly 1 for a
    /// product nobody placed a card on, which is what the term reads as
    /// for every build before the board existed.
    public var featureMultiplier: Double = 1
    /// M1: the board in one line ("4 of 5 slots, 2 synergies"), or `nil`
    /// when there is no board to talk about.
    public var featureSummary: String?

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
        // M1: a board actively costing the product is worth saying before
        // the generic "keep working" — it is the one thing here the player
        // can fix in ten seconds.
        if featureMultiplier < 0.99 {
            return "The feature board is costing \(Int(((1 - featureMultiplier) * 100).rounded()))% of the score."
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
        // M1: the board's contribution, shown before the player commits.
        // Exactly 1 and `nil` on an empty board, so the card says nothing
        // new to a player who never opened it.
        let board = FeatureBoard.reading(
            for: product, state: self, content: content, balance: balance
        )
        let boardMultiplier = product.features.isEmpty ? 1 : board.qualityMultiplier

        return ShipForecast(
            quality: min(100, max(0,
                100 * completion * topicFit * bugFactor * techMultiplier * ceiling
                    * codebaseCeiling * boardMultiplier
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
            canShip: dev.codePts >= balance.shipCodeThreshold * type.codePts,
            featureMultiplier: boardMultiplier,
            featureSummary: product.features.isEmpty ? nil : board.summary
        )
    }
}

// MARK: - Before the first line of code, and after the last

/// The forecast's terms as they stood the day a product shipped, kept on
/// the release so launch day can say *why* the score was what it was —
/// "your crew capped this at 61", "open bugs cost 12 points" — at the one
/// moment the player is ready to hear it. A pure record; nothing reads it
/// back into the simulation.
public struct LaunchForecast: Codable, Equatable, Sendable {
    public var crewCeiling: Double
    public var skillCeiling: Double
    public var codebaseCeiling: Double
    public var topicFit: Double
    public var bugFactor: Double
    public var marketScale: Double
    /// `ShipForecast.limitingFactor` at ship, in the player's words.
    public var limitingFactor: String?

    public init(
        crewCeiling: Double,
        skillCeiling: Double,
        codebaseCeiling: Double,
        topicFit: Double,
        bugFactor: Double,
        marketScale: Double,
        limitingFactor: String?
    ) {
        self.crewCeiling = crewCeiling
        self.skillCeiling = skillCeiling
        self.codebaseCeiling = codebaseCeiling
        self.topicFit = topicFit
        self.bugFactor = bugFactor
        self.marketScale = marketScale
        self.limitingFactor = limitingFactor
    }

    /// Which screen fixes the thing that held the score down.
    public enum Fix: Sendable, Equatable {
        case hiring, refactor, bugs, market
    }

    /// The biggest lever, in the same order `limitingFactor` names them.
    public var fix: Fix? {
        if codebaseCeiling < 0.99, codebaseCeiling < skillCeiling { return .refactor }
        if skillCeiling < 0.95 { return .hiring }
        if bugFactor < 0.95 { return .bugs }
        if topicFit < 0.95 { return .market }
        return nil
    }
}

extension ShipForecast {
    /// This forecast, frozen for the release.
    public var snapshot: LaunchForecast {
        LaunchForecast(
            crewCeiling: crewCeiling,
            skillCeiling: skillCeiling,
            codebaseCeiling: codebaseCeiling,
            topicFit: topicFit,
            bugFactor: bugFactor,
            marketScale: marketScale,
            limitingFactor: limitingFactor
        )
    }

    /// What a product of this type and topic could reach if the people who
    /// would join it today built it with every pool full and no bugs.
    ///
    /// The number that decides whether a product is worth starting, shown
    /// *before* the player commits rather than one step after. The crew is
    /// whoever is idle — the founder included — because that is exactly who
    /// `startProduct` puts on a new build; its skill goes through the same
    /// `crewSkillSample` the daily tick uses, so the ceiling here equals
    /// the ceiling the detail screen shows on day one. The market term is
    /// left at 1: saturation is a property of the launch, not the plan.
    public static func preStart(
        typeID: String,
        topicID: String?,
        codebaseID: String?,
        state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> ShipForecast? {
        guard content.productType(typeID) != nil else { return nil }
        let crew = state.employees.filter { $0.assignment == .idle }
        let skillIndex = ProductSystem.crewSkillSample(
            designSkillSum: crew.reduce(0) { $0 + $1.skills.design },
            codingSkillSum: crew.reduce(0) { $0 + $1.skills.coding },
            crewCount: crew.count,
            balance: balance
        )
        let ceiling = ProductSystem.qualityCeiling(skillIndex: skillIndex, balance: balance)
        let topicFit = topicID.flatMap { content.topic($0)?.fitByType[typeID] } ?? 1
        let techMultiplier = state.qualityTechMultiplier(
            content: content, cap: balance.techQualityMultiplierCap
        )
        let codebase = codebaseID.flatMap { state.codebase(id: $0) }
        let codebaseDebt = codebase?.debt ?? 0
        let codebaseCeiling = balance.codebase.debtCeiling(codebaseDebt)
        let crewCeiling = min(1, topicFit * techMultiplier * ceiling * codebaseCeiling)
        return ShipForecast(
            quality: min(100, max(0, 100 * crewCeiling)),
            crewCeiling: crewCeiling,
            skillCeiling: ceiling,
            codebaseCeiling: codebaseCeiling,
            codebaseDebt: codebaseDebt,
            codebaseName: codebase?.name,
            topicFit: topicFit,
            bugFactor: 1,
            marketScale: 1,
            canShip: false
        )
    }
}

extension PhaseFocus {
    /// A split matching what a build still needs: each pool weighted by
    /// the points it is short, so nobody pours a third of their days into
    /// a pool that is already full. With nothing left it falls back to
    /// balanced. The engine's own pacing bots have played this way from
    /// the start; now the screen can offer it in one tap.
    public static func matching(progress: DevProgress, type: ProductTypeDef) -> PhaseFocus {
        let design = max(0, type.designPts - progress.designPts)
        let code = max(0, type.codePts - progress.codePts)
        let polish = max(0, type.polishPts - progress.polishPts)
        guard design + code + polish > 0 else { return .balanced }
        return PhaseFocus(design: design, code: code, polish: polish)
    }

    /// The split a fresh build of `type` should start on: the pools in the
    /// proportion the type demands.
    public static func matching(type: ProductTypeDef) -> PhaseFocus {
        PhaseFocus(design: type.designPts, code: type.codePts, polish: type.polishPts)
    }
}
