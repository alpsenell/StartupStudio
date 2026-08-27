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
    /// fixes `bugFixMultiplier` open bugs (1 without QA on the crew; the
    /// day's total rounds to the nearest bug).
    static func applyDailyProgress(
        design: Double,
        code: Double,
        polish: Double,
        averageCoding: Double,
        bugChanceMultiplier: Double,
        bugFixMultiplier: Double = 1,
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
            let fixed = Int((Double(polishPointsCrossed) * bugFixMultiplier).rounded())
            dev.openBugs = max(0, dev.openBugs - fixed)
        }

        state.products[productIndex].stage = .development(dev)
    }

    // MARK: - Weekly sales

    /// Posts one sales week for every on-market release. The decayed unit
    /// curve uses w = the number of already-recorded sales weeks, which is 0
    /// on the first weekly post after launch and matches full weeks since
    /// launch thereafter (a row is appended every on-market weekly post).
    ///
    /// Two dynamics shape the curve beyond quality:
    /// - the adoption ramp: sales reach the peak only after
    ///   `info.adoptionWeeks` (set at ship from marketing skill and hype),
    ///   and decay starts counting after the ramp completes;
    /// - the topic's market multiplier, read live each week, so a booming
    ///   market lifts every on-market product in that topic and a crash
    ///   drags them down;
    /// - `info.launchMarketScale`, the saturation / genre-fatigue discount
    ///   fixed at ship (see `launchMarketScale(for:state:balance:)`).
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
            let marketMultiplier = state.market.multiplier(for: state.products[index].topicID)
            // WS-F's rival products dent the player's slice of a topic
            // through this accessor; 1.0 until their data exists.
            let shareMultiplier = state.market.shareMultiplier(for: state.products[index].topicID)
            let peak = type.marketSize * balance.marketSizeScale
                * (balance.salesBaseFactor + balance.salesQualityFactor * qHat)
                * hypeBoost
                * info.launchMarketScale
            let week = info.weeklySales.count
            let rampWeeks = max(1, info.adoptionWeeks)
            let adoption = min(1, (Double(week) + 1) / rampWeeks)
            let decay = balance.salesDecayBase + balance.salesDecayQualityFactor * qHat
            let decayWeeks = max(0, Double(week) - (rampWeeks - 1))
            let units = Int(peak * adoption * pow(decay, decayWeeks) * marketMultiplier * shareMultiplier)

            if units == 0 || (adoption >= 1 && Double(units) < balance.delistFraction * peak) {
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

    /// The launch-time market discount for a product about to ship: every
    /// other release of the studio's in the same topic launched less than
    /// `saturationWindowDays` ago multiplies the peak by
    /// `saturationPerRelease`, and every release of the same product type
    /// launched less than `genreFatigueWindowDays` ago multiplies it by
    /// `genreFatigueFactor`; each term is floored at `saturationFloor`.
    /// Off-market releases still count — the audience remembers them.
    static func launchMarketScale(
        for product: Product,
        state: GameState,
        balance: BalanceConfig
    ) -> Double {
        var sameTopic = 0
        var sameType = 0
        for other in state.products where other.id != product.id {
            guard case .released(let info) = other.stage else { continue }
            let age = state.day - info.launchDay
            if other.topicID == product.topicID, age < balance.saturationWindowDays {
                sameTopic += 1
            }
            if other.typeID == product.typeID, age < balance.genreFatigueWindowDays {
                sameType += 1
            }
        }
        let saturation = max(balance.saturationFloor, pow(balance.saturationPerRelease, Double(sameTopic)))
        let fatigue = max(balance.saturationFloor, pow(balance.genreFatigueFactor, Double(sameType)))
        return saturation * fatigue
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
    /// weekly sales peak, and the launch saturation / genre fatigue into
    /// `ReleaseInfo.launchMarketScale` to shrink it.
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

        // What the outlets have to work with: the product's own name, its
        // type and topic, and the three things that make a launch worth a
        // remark — bugs, polish, and hype the release cannot cash.
        let marketScale = launchMarketScale(
            for: state.products[index], state: state, balance: balance
        )
        let reviewContext = ReviewContext(
            productName: state.products[index].name,
            typeName: type.name,
            topicName: content.topic(state.products[index].topicID)?.name
                ?? state.products[index].topicID,
            bugRatio: type.codePts > 0 ? Double(dev.openBugs) / type.codePts : 0,
            polishRatio: type.polishPts > 0 ? min(1, dev.polishPts / type.polishPts) : 1,
            hype: hypeAtLaunch,
            marketScale: marketScale
        )

        var reviews: [Review] = []
        for outlet in balance.reviewOutlets {
            let noise = state.rng.nextGaussian(sigma: balance.reviewNoiseSigma)
            let score = min(balance.reviewCeiling, max(balance.reviewFloor, Int(baseScore + noise)))
            reviews.append(Review(
                outlet: outlet,
                score: score,
                blurb: ReviewBlurbs.pick(
                    for: score, rng: &state.rng,
                    outlet: outlet, context: reviewContext, catalog: content.reviews
                )
            ))
        }

        // Adoption ramp: a marketing-savvy team (and launch hype) reaches
        // the sales peak faster. The average is over the whole payroll —
        // whoever is around sells the launch.
        let marketingAvg = state.employees.isEmpty
            ? 0
            : state.employees.reduce(0.0) { $0 + $1.skills.marketing } / Double(state.employees.count)
        let adoptionConfig = balance.adoption
        let adoptionWeeks = max(adoptionConfig.rampWeeksMin,
            adoptionConfig.rampWeeksMax
                - marketingAvg / adoptionConfig.marketingDivisor
                - hypeAtLaunch / adoptionConfig.hypeDivisor)

        let info = ReleaseInfo(
            launchDay: state.day,
            quality: quality,
            reviews: reviews,
            weeklySales: [],
            offMarket: false,
            hypeAtLaunch: hypeAtLaunch,
            adoptionWeeks: adoptionWeeks,
            launchMarketScale: marketScale
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
