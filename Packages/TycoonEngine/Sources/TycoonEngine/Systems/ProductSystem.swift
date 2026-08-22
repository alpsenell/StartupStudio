import Foundation
import TycoonContent

/// Daily product system: applies development output produced by
/// `EmployeeSystem`, posts sales on weekly days. Also hosts the
/// product-related action handlers used by `Reducer.apply`.
enum ProductSystem {
    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        if state.day % GameState.daysPerWeek == 0 {
            return postWeeklySales(&state, balance, content)
        }
        return []
    }

    // MARK: - Daily development

    /// Applies one day of employee output to the in-development product.
    /// Bug rolls happen per completed code point (fractional progress
    /// accumulates), with the chance scaled by the producers' average coding
    /// skill and by `bugChanceMultiplier` (the founder's low-energy penalty
    /// when the founder worked today, else 1); each completed polish point
    /// fixes one open bug.
    static func applyDailyProgress(
        design: Double,
        code: Double,
        polish: Double,
        averageCoding: Double,
        bugChanceMultiplier: Double,
        productIndex: Int,
        state: inout GameState,
        balance: BalanceConfig
    ) {
        guard case .development(var dev) = state.products[productIndex].stage else { return }

        dev.designPts += design

        let wholeCodeBefore = Int(dev.codePts)
        dev.codePts += code
        let codePointsCrossed = Int(dev.codePts) - wholeCodeBefore
        if codePointsCrossed > 0 {
            let bugChance = balance.bugChanceBase
                * (1 - averageCoding / balance.bugChanceSkillDivisor)
                * bugChanceMultiplier
            for _ in 0..<codePointsCrossed where state.rng.nextUniform() < bugChance {
                dev.openBugs += 1
            }
        }

        let wholePolishBefore = Int(dev.polishPts)
        dev.polishPts += polish
        let polishPointsCrossed = Int(dev.polishPts) - wholePolishBefore
        if polishPointsCrossed > 0 {
            dev.openBugs = max(0, dev.openBugs - polishPointsCrossed)
        }

        state.products[productIndex].stage = .development(dev)
    }

    // MARK: - Weekly sales

    /// Posts one sales week for every on-market release. The decayed unit
    /// curve uses w = the number of already-recorded sales weeks, which is 0
    /// on the first weekly post after launch and matches full weeks since
    /// launch thereafter (a row is appended every on-market weekly post).
    private static func postWeeklySales(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        var events: [GameEvent] = []

        for index in state.products.indices {
            guard case .released(var info) = state.products[index].stage,
                  !info.offMarket,
                  let type = content.productType(state.products[index].typeID)
            else { continue }

            let qHat = Double(info.averageReviewScore) / 100.0
            let hypeBoost = 1 + info.hypeAtLaunch * balance.hypeLaunchCarryFraction / balance.salesHypeDivisor
            let peak = type.marketSize
                * (balance.salesBaseFactor + balance.salesQualityFactor * qHat)
                * hypeBoost
            let week = info.weeklySales.count
            let decay = balance.salesDecayBase + balance.salesDecayQualityFactor * qHat
            let units = Int(peak * pow(decay, Double(week)))

            if units == 0 || Double(units) < balance.delistFraction * peak {
                info.offMarket = true
                state.products[index].stage = .released(info)
                events.append(.productOffMarket(productID: state.products[index].id, day: state.day))
                continue
            }

            let revenue = Int(Double(units) * type.unitPrice)
            info.weeklySales.append(WeeklySale(weekIndex: week, units: units, revenue: revenue))
            state.products[index].stage = .released(info)
            state.company.cash += revenue
            state.ledger.post(LedgerEntry(
                day: state.day,
                amount: revenue,
                category: .sales,
                label: state.products[index].name
            ))
        }

        return events
    }

    // MARK: - Actions

    /// Starts a new product. Ignored while another product is in development,
    /// for unknown type/topic ids, and for types that are neither unlocked
    /// from the start nor unlocked by completed research. The product id is
    /// drawn from the state RNG so runs replay identically. Every currently
    /// idle employee (founder included) is auto-assigned to the new product,
    /// so solo play needs no micromanagement; `assign`/`fire` can change it
    /// afterwards.
    static func startProduct(
        typeID: String,
        topicID: String,
        name: String,
        focus: PhaseFocus,
        state: inout GameState,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard state.productInDevelopment == nil,
              content.productType(typeID) != nil,
              state.isProductTypeUnlocked(typeID, content: content),
              content.topic(topicID) != nil
        else { return [] }

        let id = UUID(from: &state.rng)
        let progress = DevProgress(
            designPts: 0, codePts: 0, polishPts: 0,
            openBugs: 0, focus: focus.normalized, hype: 0
        )
        state.products.append(Product(
            id: id, name: name, typeID: typeID, topicID: topicID,
            stage: .development(progress)
        ))
        for index in state.employees.indices where state.employees[index].assignment == .idle {
            state.employees[index].assignment = .product(id)
        }
        return [.productStarted(productID: id, day: state.day)]
    }

    /// Updates the focus split on an in-development product. No event.
    static func setPhaseFocus(
        productID: UUID,
        focus: PhaseFocus,
        state: inout GameState
    ) -> [GameEvent] {
        guard let index = state.products.firstIndex(where: { $0.id == productID }),
              case .development(var dev) = state.products[index].stage
        else { return [] }

        dev.focus = focus.normalized
        state.products[index].stage = .development(dev)
        return []
    }

    /// Ships an in-development product once it clears the code gate:
    /// quality is computed from pool completion, topic fit, open bugs, and
    /// the capped tech quality multiplier; reviews are generated immediately
    /// (graded against expectations that rise with studio age and
    /// reputation, lifted by launch hype) and reputation is nudged. The
    /// hype at ship is captured into `ReleaseInfo.hypeAtLaunch` to boost the
    /// weekly sales peak.
    static func ship(
        productID: UUID,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard let index = state.products.firstIndex(where: { $0.id == productID }),
              case .development(let dev) = state.products[index].stage,
              let type = content.productType(state.products[index].typeID),
              dev.codePts >= balance.shipCodeThreshold * type.codePts
        else { return [] }

        let topicFit = content.topic(state.products[index].topicID)?
            .fitByType[state.products[index].typeID] ?? 1.0

        let weights = balance.qualityWeights
        let completion = weights.design * min(1, dev.designPts / type.designPts)
            + weights.code * min(1, dev.codePts / type.codePts)
            + weights.polish * min(1, dev.polishPts / type.polishPts)
        let bugFactor = 1 - min(balance.bugPenaltyCap, Double(dev.openBugs) / type.codePts)
        let techMultiplier = state.qualityTechMultiplier(
            content: content, cap: balance.techQualityMultiplierCap
        )
        let quality = min(100, max(0, 100 * completion * topicFit * bugFactor * techMultiplier))

        // Full review model: the press expects more from an older, more
        // reputable studio, docks a fraction of any shortfall, and grants a
        // hype bonus. Reputation here is the pre-nudge value.
        let hypeAtLaunch = dev.hype
        let expected = balance.reviewExpectationBase
            + balance.reviewExpectationPerYear * Double(state.year - 1)
            + balance.reviewExpectationRepFactor * state.company.reputation
        let baseScore = quality
            - balance.reviewShortfallPenalty * max(0, expected - quality)
            + hypeAtLaunch / balance.reviewHypeDivisor

        var reviews: [Review] = []
        for outlet in balance.reviewOutlets {
            let noise = state.rng.nextGaussian(sigma: balance.reviewNoiseSigma)
            let score = min(balance.reviewCeiling, max(balance.reviewFloor, Int(baseScore + noise)))
            reviews.append(Review(
                outlet: outlet,
                score: score,
                blurb: ReviewBlurbs.pick(for: score, rng: &state.rng)
            ))
        }

        let info = ReleaseInfo(
            launchDay: state.day,
            quality: quality,
            reviews: reviews,
            weeklySales: [],
            offMarket: false,
            hypeAtLaunch: hypeAtLaunch
        )
        let averageScore = info.averageReviewScore

        state.company.reputation = min(100, max(0,
            state.company.reputation
                + (Double(averageScore) - state.company.reputation) * balance.reputationReviewNudge
        ))
        state.products[index].stage = .released(info)

        return [
            .shipped(productID: productID, day: state.day),
            .reviewsIn(productID: productID, averageScore: averageScore, day: state.day),
        ]
    }

}

/// Short review one-liners, picked by score band (variety comes from the
/// seeded RNG so runs stay reproducible).
enum ReviewBlurbs {
    private static let dire = [
        "We want our afternoon back.",
        "Crashes faster than it launches.",
        "A bold experiment in user punishment.",
        "The loading spinner is the best feature.",
        "Uninstalled before the tutorial ended.",
    ]
    private static let poor = [
        "Rough edges as far as the eye can see.",
        "Needed six more months in the oven.",
        "Promising idea, painful execution.",
        "Works, in the way a squeaky door works.",
        "We kept waiting for it to get good.",
    ]
    private static let mixed = [
        "Fine. Perfectly, stubbornly fine.",
        "Half brilliant, half baffling.",
        "Does the job, rarely with grace.",
        "You could do worse. You could do better.",
        "A solid maybe from our review desk.",
    ]
    private static let good = [
        "Polished where it counts.",
        "Quietly excellent in daily use.",
        "A confident, capable release.",
        "Easy to recommend, hard to put down.",
        "Small studio, big craftsmanship.",
    ]
    private static let stellar = [
        "An instant classic of the genre.",
        "Set the bar; everyone else, take notes.",
        "We forgot we were reviewing it.",
        "Flawless victory for a tiny team.",
        "The rare app that feels inevitable.",
    ]

    /// Picks a blurb from the band matching `score` using the state RNG.
    static func pick(for score: Int, rng: inout SeededRNG) -> String {
        let band: [String] = switch score {
        case ..<20: dire
        case ..<40: poor
        case ..<60: mixed
        case ..<80: good
        default: stellar
        }
        return band[Int(rng.next() % UInt64(band.count))]
    }
}
