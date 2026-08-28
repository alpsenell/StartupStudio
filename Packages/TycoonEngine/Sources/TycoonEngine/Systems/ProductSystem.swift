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
        var hostingBill = 0

        for index in state.products.indices {
            guard case .released(var info) = state.products[index].stage,
                  !info.offMarket,
                  let type = content.productType(state.products[index].typeID)
            else { continue }

            let productID = state.products[index].id
            let economy = balance.economy
            let qHat = Double(info.averageReviewScore) / 100.0
            let hypeBoost = 1 + info.hypeAtLaunch * balance.hypeLaunchCarryFraction / balance.salesHypeDivisor
            let marketMultiplier = state.market.multiplier(for: state.products[index].topicID)
            // WS-F's rival products dent the player's slice of a topic
            // through this accessor; 1.0 until their data exists.
            let shareMultiplier = state.market.shareMultiplier(for: state.products[index].topicID)
            let pricing = economy.priceTier(info.priceTier)
            // A premium price the reviews don't back up drives people away.
            let overpriced = info.priceTier == .premium
                && Double(info.averageReviewScore) < economy.premiumQualityThreshold
            // Bugs players hit in the wild cost sales and subscribers alike.
            let liveBugDrag = 1 - min(
                economy.liveBugPenaltyCap,
                Double(info.liveBugs) * economy.liveBugSalesPenalty
            )
            let week = info.weeklySales.count
            let rampWeeks = max(1, info.adoptionWeeks)
            let adoption = min(1, (Double(week) + 1) / rampWeeks)
            // A patch buys one bumper week.
            let updateBump = info.lastUpdateDay.map {
                state.day - $0 <= economy.updateBumpDays ? economy.updateSalesBump : 1
            } ?? 1
            let demand = type.marketSize * balance.marketSizeScale
                * (balance.salesBaseFactor + balance.salesQualityFactor * qHat)
                * hypeBoost
                * info.launchMarketScale
                * pricing.demandFactor
            let price = type.unitPrice * pricing.priceFactor
            let world = marketMultiplier * shareMultiplier * liveBugDrag * updateBump

            let units: Int
            let delisted: Bool
            if info.isSubscription {
                // Recurring revenue: every week signs some of the
                // addressable market up and loses a slice of the book.
                let acquired = demand / max(1, economy.subscriberAcquisitionWeeks)
                    * adoption * world
                var churnRate = max(0, economy.churnBase - economy.churnQualityFactor * qHat)
                if overpriced { churnRate *= economy.premiumChurnPenalty }
                churnRate *= 1 - supportChurnRelief(
                    productID: productID, state: state, balance: balance
                )
                let book = Double(info.subscribers)
                let next = max(0, book + acquired - book * churnRate)
                info.subscribers = Int(next.rounded())
                units = info.subscribers
                delisted = adoption >= 1 && units < economy.subscriptionFloorSubscribers
            } else {
                // One-off sales: a launch spike that decays week by week.
                let decay = balance.salesDecayBase + balance.salesDecayQualityFactor * qHat
                let decayWeeks = max(0, Double(week) - (rampWeeks - 1))
                units = Int(demand * adoption * pow(decay, decayWeeks) * world)
                delisted = units == 0
                    || (adoption >= 1 && Double(units) < balance.delistFraction * demand)
            }

            if delisted {
                info.offMarket = true
                info.subscribers = 0
                state.products[index].stage = .released(info)
                events.append(.productOffMarket(productID: productID, day: state.day))
                continue
            }

            let revenue = Int(Double(units) * price)
            info.weeklySales.append(WeeklySale(weekIndex: week, units: units, revenue: revenue))
            hostingBill += weeklyHostingCost(for: info, type: type, balance: balance)
            state.products[index].stage = .released(info)
            state.company.cash += revenue
            state.ledger.post(LedgerEntry(
                day: state.day,
                amount: revenue,
                category: .sales,
                label: state.products[index].name
            ))
        }

        // The cost of success: everything on the market needs servers,
        // bandwidth and a support desk, billed as one line.
        if hostingBill > 0 {
            state.company.cash -= hostingBill
            state.ledger.post(LedgerEntry(
                day: state.day,
                amount: -hostingBill,
                category: .hosting,
                label: "Hosting & support"
            ))
        }

        return events
    }

    /// What one on-market release costs to keep running for a week: its
    /// type's flat bill plus a per-subscriber slice for subscription
    /// products.
    static func weeklyHostingCost(
        for info: ReleaseInfo,
        type: ProductTypeDef,
        balance: BalanceConfig
    ) -> Int {
        let perSubscriber = info.isSubscription
            ? Double(info.subscribers) * balance.economy.hostingCostPerSubscriber
            : 0
        return Int((type.hostingCostPerWeek + perSubscriber).rounded())
    }

    /// How much the people on a product's support desk hold churn down,
    /// 0...1: `supportChurnRelief` per supporter, capped just short of
    /// eliminating churn entirely.
    static func supportChurnRelief(
        productID: UUID,
        state: GameState,
        balance: BalanceConfig
    ) -> Double {
        let supporters = state.employees.count { $0.assignment == .support(productID) }
        guard supporters > 0 else { return 0 }
        return min(0.75, Double(supporters) * balance.economy.supportChurnRelief)
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

    /// Starts a new product. Ignored once every development slot the office
    /// tier grants is taken, for unknown type/topic ids, and for types that are neither unlocked
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
        guard state.hasFreeDevSlot,
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
        // The skill ceiling: a product can only be as good as the people who
        // built it. A crew of complete beginners tops out at
        // `qualityCeilingBase`; the rest is earned point by point, and tech
        // (already capped) sharpens a good team rather than rescuing a bad
        // one — it multiplies *under* the ceiling.
        let ceiling = qualityCeiling(skillIndex: dev.crewSkillIndex, balance: balance)
        let quality = min(100, max(0,
            100 * completion * topicFit * bugFactor * techMultiplier * ceiling
        ))

        // Full review model: the press expects more from an older, more
        // reputable studio and from a more ambitious kind of product, docks
        // a fraction of any shortfall, and grants a hype bonus. Reputation
        // here is the pre-nudge value.
        let hypeAtLaunch = dev.hype
        let expected = balance.reviewExpectationBase
            + balance.reviewExpectationPerYear * Double(state.year - 1)
            + balance.reviewExpectationRepFactor * state.company.reputation
            + balance.economy.expectationPerComplexity * (type.complexity - 1)
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
            // WS-B computes the same discount once, above, for the review
            // context; reuse it rather than calling it twice.
            launchMarketScale: marketScale,
            liveBugs: Int((Double(dev.openBugs) * balance.economy.liveBugSeedFraction).rounded()),
            isSubscription: type.revenueModel == .subscription
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

    /// The fraction of full quality a crew with this average pool-weighted
    /// skill can reach: `base + (1 − base) × skillIndex / 100`, clamped to
    /// `base...1`. A base of 1 (the neutral test economy) restores the
    /// pre-ceiling behavior exactly.
    static func qualityCeiling(skillIndex: Double, balance: BalanceConfig) -> Double {
        let base = min(1, max(0, balance.economy.qualityCeilingBase))
        return base + (1 - base) * min(100, max(0, skillIndex)) / 100
    }

    /// The pool-weighted skill of one day's crew: the design pool draws on
    /// design, the code pool on coding, and the polish pool on the mean of
    /// both, weighted by the same `qualityWeights` the quality itself is
    /// computed from. An empty crew reads 0.
    static func crewSkillSample(
        designSkillSum: Double,
        codingSkillSum: Double,
        crewCount: Int,
        balance: BalanceConfig
    ) -> Double {
        guard crewCount > 0 else { return 0 }
        let design = designSkillSum / Double(crewCount)
        let coding = codingSkillSum / Double(crewCount)
        let weights = balance.qualityWeights
        return weights.design * design
            + weights.code * coding
            + weights.polish * (design + coding) / 2
    }

    // MARK: - Live-ops actions

    /// Repositions a released, on-market product on the price ladder.
    /// Ignored for unknown ids, products still in development, delisted
    /// products, and a no-op tier.
    static func setPriceTier(
        productID: UUID,
        tier: PriceTier,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard let index = state.products.firstIndex(where: { $0.id == productID }),
              case .released(var info) = state.products[index].stage,
              !info.offMarket,
              info.priceTier != tier
        else { return [] }

        info.priceTier = tier
        state.products[index].stage = .released(info)
        return [.priceChanged(productID: productID, tier: tier, day: state.day)]
    }

    /// Puts a released, on-market product back into a short patch cycle
    /// sized at `economy.updatePoolFraction` of its original point pools.
    /// Everyone idle joins the patch, mirroring `startProduct`. Ignored for
    /// unknown ids, unreleased or delisted products, and while a patch is
    /// already running on the same product.
    static func startUpdate(
        productID: UUID,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard let index = state.products.firstIndex(where: { $0.id == productID }),
              case .released(let info) = state.products[index].stage,
              !info.offMarket,
              state.economy.update(for: productID) == nil,
              let type = content.productType(state.products[index].typeID)
        else { return [] }

        let fraction = balance.economy.updatePoolFraction
        state.economy.updates.append(ProductUpdate(
            productID: productID,
            startedDay: state.day,
            designPts: type.designPts * fraction,
            codePts: type.codePts * fraction,
            polishPts: type.polishPts * fraction
        ))
        for employeeIndex in state.employees.indices
        where state.employees[employeeIndex].assignment == .idle {
            state.employees[employeeIndex].assignment = .product(productID)
        }
        return []
    }
}
