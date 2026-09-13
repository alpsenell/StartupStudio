import Foundation
import TycoonContent

// MARK: T2 (the build)

/// Iteration 17 — T2. The build's ways out, read: whether a build in
/// development can be shelved, taken off the shelf or scrapped now, what
/// each costs, and what a declared v2 does to its parent — in the numbers
/// the engine will use. The app prints these on the buttons; the actions
/// (`ProductSystem+Build`) gate on the same functions, so the sentence the
/// player reads is the reason the engine used.
///
/// **The shelf.** A shelved build leaves `products` for `GameState.shelf`.
/// Every read of "builds in development" — the slots (`buildsInFlight`,
/// `hasFreeDevSlot`), the Now card, the daily output, the hype decay, the
/// announce pass, the move-down refusal, the bots — iterates `products`,
/// so none of them sees a shelved build and none of them needed a filter.
///
/// Pure reads over `GameState`; no draws.
public enum BuildRefusal: Equatable, Sendable {
    /// Not a build in development (shipped, unknown, or on the shelf when
    /// the action wants it in a slot).
    case notABuild
    /// Taking it off the shelf needs it to be on the shelf.
    case notShelved
    /// Every build slot the office has is taken.
    case noSlot(slots: Int)
    /// P2: it is this close to done; ship it or don't.
    case weekFromDone(days: Int)
    /// P2: the press has a date that has not slipped yet.
    case announcedDate(day: Int)

    public var sentence: String {
        switch self {
        case .notABuild:
            "It is not a build in development."
        case .notShelved:
            "It is not on the shelf."
        case .noSlot(let slots):
            "Every build slot is busy: this office runs \(slots) at a time."
        case .weekFromDone(let days):
            days <= 0
                ? "It is done. Ship it or don't."
                : "It is \(days) day\(days == 1 ? "" : "s") from done. Ship it or don't."
        case .announcedDate:
            "The press has a date for it. Shelve it first, which is the slip, or ship it."
        }
    }
}

/// What shelving a build does today.
public struct BuildShelveQuote: Equatable, Sendable {
    /// The hype the build holds, all of which goes.
    public var hype: Double
    /// The build has an announced date, and shelving slips it.
    public var slipsDate: Bool
    /// The slip's reputation cost (0 when there is no date).
    public var slipReputation: Double
    /// The slip is the second, which voids the date.
    public var voidsDate: Bool
    /// People on it now; they go idle.
    public var crew: Int
    public var crewMorale: Double
    /// Share of the type's pools the build has filled, 0...1: what keeps.
    public var completion: Double
    /// Share of the points lost per quarter in the drawer.
    public var decayPerQuarter: Double
}

/// What scrapping a build does today.
public struct BuildScrapQuote: Equatable, Sendable {
    /// Points the type's codebase gains, per pool.
    public var design: Double
    public var code: Double
    public var polish: Double
    public var fraction: Double
    /// The lineage it banks into; `nil` when the scrap founds one.
    public var codebaseName: String?
    /// The debt the build accrued, which the codebase takes with it.
    public var debt: Double
    /// People on it now (0 for a shelved build); they go idle.
    public var crew: Int
    public var crewMorale: Double
    /// Every point the build had.
    public var buildPoints: Double

    public var banked: Double { design + code + polish }
}

/// J4: what running a declared v2 beside its live parent costs the parent.
public struct BuildRunBothQuote: Equatable, Sendable {
    public var parentID: UUID
    public var parentName: String
    public var isSubscription: Bool
    public var parentSubscribers: Int
    /// About how many subscribers (one-time: units) a week the parent
    /// loses to its v2, at this week's numbers.
    public var weeklyLoss: Int
    public var acquisition: Double
    public var churn: Double
}

extension GameState {
    /// A build in the drawer.
    public func shelvedBuild(id: UUID) -> Product? {
        shelf.first { $0.id == id }
    }

    /// Why `shelveBuild` would be refused now; `nil` when it would land.
    public func buildShelveRefusal(productID: UUID) -> BuildRefusal? {
        guard let product = product(id: productID), case .development = product.stage else {
            return .notABuild
        }
        return nil
    }

    /// What shelving `productID` would do today.
    public func buildShelveQuote(
        productID: UUID,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> BuildShelveQuote? {
        guard let product = product(id: productID),
              case .development(let dev) = product.stage,
              let type = content.productType(product.typeID)
        else { return nil }
        let slip = Announce.slipCost(slipNumber: product.slips + 1, balance: balance)
        return BuildShelveQuote(
            hype: dev.hype,
            slipsDate: product.isAnnounced,
            slipReputation: product.isAnnounced ? slip.reputation : 0,
            voidsDate: product.isAnnounced && product.slips + 1 >= Announce.voidAfterSlips,
            crew: buildCrew(productID).count,
            crewMorale: balance.build.shelveCrewMorale,
            completion: dev.completion(of: type),
            decayPerQuarter: balance.build.shelveDecayPerQuarter
        )
    }

    /// Why `unshelveBuild` would be refused now; `nil` when it would land.
    public func buildUnshelveRefusal(productID: UUID) -> BuildRefusal? {
        guard shelvedBuild(id: productID) != nil else { return .notShelved }
        guard hasFreeDevSlot else { return .noSlot(slots: devSlots) }
        return nil
    }

    /// Why `scrapBuild` would be refused now; `nil` when it would land. A
    /// shelved build can always be scrapped: it already paid the slip,
    /// the hype and the crew's morale on the way into the drawer.
    public func buildScrapRefusal(
        productID: UUID,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> BuildRefusal? {
        if shelvedBuild(id: productID) != nil { return nil }
        guard let product = product(id: productID), case .development = product.stage else {
            return .notABuild
        }
        if let day = product.announcedDay, product.slips == 0 { return .announcedDate(day: day) }
        if let days = buildETA(productID: productID, balance: balance, content: content)?.daysToComplete,
           days <= balance.build.scrapLastDays {
            return .weekFromDone(days: days)
        }
        return nil
    }

    /// What scrapping `productID` (in a slot or on the shelf) would do
    /// today.
    ///
    /// The bank: each pool of the type's codebase is raised to
    /// `scrapBankFraction` of the build's points in that pool (never past
    /// the type's pool), and never *stacked* on the points it already has
    /// — the codebase keeps the better of the two, which is how
    /// `CodebaseSystem.recordShip` treats a lineage (the pools reflect the
    /// last build, they do not ratchet). A lineage already holding more
    /// than half this build gets nothing but its debt; a type with no
    /// codebase has one founded under the scrapped build's name.
    public func buildScrapQuote(
        productID: UUID,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> BuildScrapQuote? {
        let inFlight = product(id: productID)
        guard let product = inFlight ?? shelvedBuild(id: productID),
              case .development(let dev) = product.stage,
              let type = content.productType(product.typeID)
        else { return nil }
        let fraction = balance.build.scrapBankFraction
        let lineage = codebases.first { $0.id == product.typeID }
        func gain(_ points: Double, _ pool: Double, _ held: Double) -> Double {
            max(0, min(pool, points * fraction) - held)
        }
        return BuildScrapQuote(
            design: gain(dev.designPts, type.designPts, lineage?.designPts ?? 0),
            code: gain(dev.codePts, type.codePts, lineage?.codePts ?? 0),
            polish: gain(dev.polishPts, type.polishPts, lineage?.polishPts ?? 0),
            fraction: fraction,
            codebaseName: lineage?.name,
            debt: dev.debtAccrued,
            crew: inFlight == nil ? 0 : buildCrew(productID).count,
            crewMorale: balance.build.scrapCrewMorale,
            buildPoints: dev.designPts + dev.codePts + dev.polishPts
        )
    }

    /// J4: the factors a live product's weekly acquisition and churn take
    /// while a v2 declared on it (a product whose `parentID` is this one)
    /// is on the market beside it. Exactly `(1, 1)` otherwise — which is
    /// every product in every run that never pressed the "v2 of…" chip,
    /// since the only other writer of `parentID` (`shipReplacing`) retires
    /// the parent the day it ships.
    public func buildParentDecay(
        productID: UUID,
        balance: BalanceConfig
    ) -> (acquisition: Double, churn: Double) {
        let liveV2 = products.contains { other in
            guard other.parentID == productID, case .released(let info) = other.stage else { return false }
            return !info.offMarket
        }
        return liveV2 ? (balance.build.parentAcquisition, balance.build.parentChurn) : (1, 1)
    }

    /// The live product a build (or product) was declared a v2 of, `nil`
    /// when it has none or the parent is off the market.
    public func buildDeclaredParent(of productID: UUID) -> Product? {
        guard let parentID = (product(id: productID) ?? shelvedBuild(id: productID))?.parentID,
              let parent = product(id: parentID),
              case .released(let info) = parent.stage, !info.offMarket
        else { return nil }
        return parent
    }

    /// J4: what shipping `buildID` beside its declared, live parent would
    /// cost the parent each week, at this week's numbers. The acquisition
    /// is read back off the parent's last two weeks (the book's change
    /// plus what churned), so the estimate uses the numbers the engine
    /// actually posted rather than re-deriving demand.
    public func buildRunBothQuote(buildID: UUID, balance: BalanceConfig) -> BuildRunBothQuote? {
        guard let parent = buildDeclaredParent(of: buildID),
              case .released(let info) = parent.stage
        else { return nil }
        let config = balance.build
        let economy = balance.economy
        let loss: Double
        if info.isSubscription {
            let qHat = Double(info.averageReviewScore) / 100
            var churn = max(0, economy.churnBase - economy.churnQualityFactor * qHat)
            if info.priceTier == .premium, Double(info.averageReviewScore) < economy.premiumQualityThreshold {
                churn *= economy.premiumChurnPenalty
            }
            churn *= 1 - ProductSystem.supportChurnRelief(productID: parent.id, state: self, balance: balance)
            let book = Double(info.subscribers)
            let sales = info.weeklySales
            let previous = sales.count >= 2 ? Double(sales[sales.count - 2].units) : 0
            let acquired = max(0, book - previous + previous * churn)
            loss = acquired * (1 - config.parentAcquisition) + book * churn * (config.parentChurn - 1)
        } else {
            loss = Double(info.weeklySales.last?.units ?? 0) * (1 - config.parentAcquisition)
        }
        return BuildRunBothQuote(
            parentID: parent.id,
            parentName: parent.name,
            isSubscription: info.isSubscription,
            parentSubscribers: info.subscribers,
            weeklyLoss: max(0, Int(loss.rounded())),
            acquisition: config.parentAcquisition,
            churn: config.parentChurn
        )
    }

    /// Indices of the people on a build.
    func buildCrew(_ productID: UUID) -> [Int] {
        employees.indices.filter { employees[$0].assignment == .product(productID) }
    }
}

extension DevProgress {
    /// Share of the type's pools filled, 0...1 (points past a pool do not
    /// count twice).
    public func completion(of type: ProductTypeDef) -> Double {
        let total = type.designPts + type.codePts + type.polishPts
        guard total > 0 else { return 0 }
        let filled = min(designPts, type.designPts) + min(codePts, type.codePts)
            + min(polishPts, type.polishPts)
        return min(1, filled / total)
    }
}

// MARK: end T2
