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
    /// when the founder worked today, the work pace, and the crew's `bugMult`
    /// traits — each exactly 1 when it does not apply); each completed polish point
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
        // MARK: K6 (home and rooms) — the day after a called break, every build's work × `home.breakDayFactor`; × 1.0 (no bit moves) on every other day
        let breakFactor = state.roomBreakDayFactor(balance)
        let (design, code, polish) = (design * breakFactor, code * breakFactor, polish * breakFactor)
        // MARK: end K6

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
            // MARK: T7 (press and stakes) — under an exclusive, launch week's
            // buyers read the one verdict that is out (`demandReviewScore`).
            // Exactly the average on every release nobody gave an exclusive
            // — every bot, every fixture — and read by the two lines below
            // that used to read the average.
            let pressDemandScore = info.demandReviewScore(on: state.day)
            let qHat = Double(pressDemandScore) / 100.0
            // MARK: end T7
            // Launch hype carries at a fraction, because it is months old
            // by now; a campaign run *since* launch counts at full weight
            // and fades on its own. That is the trade the marketing tab is
            // now actually offering: money before launch buys reviews and
            // keeps paying, money after buys a few weeks of attention.
            let hypeBoost = 1
                + info.hypeAtLaunch * balance.hypeLaunchCarryFraction / balance.salesHypeDivisor
                + info.liveHype * economy.liveHypeSalesFactor / balance.salesHypeDivisor
            let marketMultiplier = state.market.multiplier(for: state.products[index].topicID)
            // WS-F's rival products dent the player's slice of a topic
            // through this accessor; 1.0 until their data exists.
            let shareMultiplier = state.market.shareMultiplier(for: state.products[index].topicID)
            let pricing = economy.priceTier(info.priceTier)
            // A premium price the reviews don't back up drives people away.
            let overpriced = info.priceTier == .premium
                && Double(pressDemandScore) < economy.premiumQualityThreshold // T7: the demand score
            // Bugs players hit in the wild cost sales and subscribers alike.
            // MARK: J5 (announce) — I1: premium buyers notice bugs twice as
            // much. The standard penalty, untouched, for every other tier.
            let liveBugDrag = 1 - min(
                economy.liveBugPenaltyCap,
                Double(info.liveBugs) * economy.liveBugSalesPenalty(for: info.priceTier)
            )
            // MARK: end J5
            let week = info.weeklySales.count
            let rampWeeks = max(1, info.adoptionWeeks)
            let adoption = min(1, (Double(week) + 1) / rampWeeks)
            // A patch buys one bumper week.
            let updateBump = info.lastUpdateDay.map {
                state.day - $0 <= economy.updateBumpDays ? economy.updateSalesBump : 1
            } ?? 1
            // MARK: K2 (product lifecycle) — the sale's bumper week (the
            // better of it and a patch's, never both) and a rise's waiting
            // weeks. Read only off the fields the priced price change
            // writes: a product nobody re-priced takes the old path.
            let lifecycle = balance.lifecycle
            let bump: Double = info.lastSaleDay.map { saleDay in
                max(updateBump, state.day - saleDay <= economy.updateBumpDays ? lifecycle.saleBump : 1)
            } ?? updateBump
            let riseDrag: Double = info.priceRiseUntilDay.map {
                state.day <= $0 ? lifecycle.riseUnitsFactor : 1
            } ?? 1
            // MARK: end K2
            // MARK: T2 (the build) — J4: the old version. `(1, 1)` unless a
            // v2 declared on this product sells beside it.
            let parentDecay = state.buildParentDecay(productID: productID, balance: balance)
            // MARK: end T2
            let demand = type.marketSize * balance.marketSizeScale
                * (balance.salesBaseFactor + balance.salesQualityFactor * qHat)
                * hypeBoost
                * info.launchMarketScale
                // MARK: J5 (announce) — I1: premium demand follows the
                // reviews. The table's factor, untouched, for every other
                // tier and for premium with the curve off.
                * economy.demandFactor(for: info.priceTier, reviewScore: pressDemandScore) // T7: the demand score
                // MARK: end J5
                // A founder who knows the market puts the product in front
                // of the people who want it. Neutral until they train it.
                * state.founderMarketFactor(balance)
            let price = type.unitPrice * pricing.priceFactor
            // K2: `bump` is `updateBump` unless a sale was ever held.
            let world = marketMultiplier * shareMultiplier * liveBugDrag * bump

            let units: Int
            let delisted: Bool
            if info.isSubscription {
                // Recurring revenue: every week signs some of the
                // addressable market up and loses a slice of the book.
                let acquired = demand / max(1, economy.subscriberAcquisitionWeeks)
                    * adoption * world
                    // MARK: T2 (the build) — J4: exactly ×1 with no live v2.
                    * parentDecay.acquisition
                    // MARK: end T2
                var churnRate = max(0, economy.churnBase - economy.churnQualityFactor * qHat)
                if overpriced { churnRate *= economy.premiumChurnPenalty }
                // MARK: T2 (the build) — J4: exactly ×1 with no live v2.
                churnRate *= parentDecay.churn
                // MARK: end T2
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
                // A premium price the reviews do not carry costs sales
                // here, the way it costs subscribers above. Until this
                // existed the `overpriced` flag was computed for every
                // product and read only in the subscription branch, so
                // four of the six product types could charge premium for
                // a poorly reviewed product at no cost whatever.
                let overpricedDrag = overpriced ? economy.premiumOverpricedSalesFactor : 1
                let decay = balance.salesDecayBase + balance.salesDecayQualityFactor * qHat
                let decayWeeks = max(0, Double(week) - (rampWeeks - 1))
                // K2: `riseDrag` is exactly 1 unless the player raised the
                // price of a one-time product in the last `riseWeeks`.
                units = Int(demand * adoption * pow(decay, decayWeeks) * world * overpricedDrag * riseDrag
                    // MARK: T2 (the build) — J4: exactly ×1 with no live v2.
                    * parentDecay.acquisition
                    // MARK: end T2
                )
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
            // MARK: T4 (publisher) — the publisher's share of the week just
            // posted, as its own ledger line. Returns at once for a product
            // nobody published.
            PublisherSystem.postShare(at: index, revenue: revenue, state: &state)
            // MARK: end T4
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
    ///
    /// K2: `excluding` leaves one more product out of both counts — the
    /// parent a replacing successor retires the day it ships. `nil`, the
    /// default and every caller but `shipReplacing`, excludes nothing.
    static func launchMarketScale(
        for product: Product,
        state: GameState,
        balance: BalanceConfig,
        excluding: UUID? = nil
    ) -> Double {
        var sameTopic = 0
        var sameType = 0
        for other in state.products where other.id != product.id && other.id != excluding {
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
        codebaseID: String? = nil,
        // MARK: T2 (the build) — J4: the "v2 of…" chip's parent; `nil`
        // from both start actions, which is every bot's start.
        parentID: UUID? = nil,
        // MARK: end T2
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard state.hasFreeDevSlot,
              let type = content.productType(typeID),
              state.isProductTypeUnlocked(typeID, content: content),
              content.topic(topicID) != nil,
              // A spin-out's non-compete (WS-H): refused until the day.
              !state.isTopicLocked(topicID)
        else { return [] }

        // The head start. A codebase of a different type is not one you can
        // build on, and an unknown id is simply greenfield — both fall
        // through to the zeroed pools the game has always started with.
        let codebase = state.codebase(id: codebaseID).flatMap { $0.id == typeID ? $0 : nil }
        let id = UUID(from: &state.rng)
        let progress = DevProgress(
            // Clamped to the type's own pools: a shrunken content table
            // must never hand the player a product that is finished on
            // day one.
            designPts: min(type.designPts, codebase?.designPts ?? 0),
            codePts: min(type.codePts, codebase?.codePts ?? 0),
            polishPts: min(type.polishPts, codebase?.polishPts ?? 0),
            openBugs: 0, focus: focus.normalized, hype: 0
        )
        // M1: a sequel starts with its parent's board already laid out —
        // the features you built last time are the ones the codebase you
        // are reusing already has. Greenfield, and every save from before
        // boards existed, inherits an empty board, which is neutral.
        let inherited = FeatureBoard.inheritedBoard(
            codebaseID: codebase?.id, typeID: typeID,
            state: state, content: content, balance: balance
        )
        // MARK: T2 (the build) — J4: a declared v2 names a released parent
        // of its own type and topic, or nothing.
        let declaredParent = parentID.flatMap { id -> UUID? in
            guard let parent = state.product(id: id), parent.releaseInfo != nil,
                  parent.typeID == typeID, parent.topicID == topicID
            else { return nil }
            return id
        }
        // MARK: end T2
        state.products.append(Product(
            id: id, name: name, typeID: typeID, topicID: topicID,
            stage: .development(progress),
            codebaseID: codebase?.id,
            features: inherited,
            // MARK: T2 (the build)
            parentID: declaredParent
            // MARK: end T2
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
    ///
    /// K2: `excludingFromSaturation` is the parent `shipReplacing` is about
    /// to retire, left out of the launch saturation and genre fatigue.
    /// `nil` for the `.ship` action, which is every ship a bot makes.
    static func ship(
        productID: UUID,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog,
        excludingFromSaturation: UUID? = nil,
        // MARK: T2 (the build) — P1: the price named on the ship sheet;
        // `.standard` for `.ship`, which is every bot's ship.
        tier: PriceTier = .standard
        // MARK: end T2
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
        // And the ceiling the *codebase* imposes: a quality you cannot
        // polish past, however good the crew is, because the foundations
        // are what they are. Exactly 1 for a greenfield build.
        let codebaseCeiling = balance.codebase.debtCeiling(
            state.inheritedDebt(for: state.products[index])
        )
        // M1: and what the board is worth. Exactly 1.0 for a product
        // nobody placed a card on, which is every product the pacing bots
        // and the byte-identical fixtures ever build.
        let board = FeatureBoard.reading(
            for: state.products[index], state: state, content: content, balance: balance
        )
        let boardMultiplier = state.products[index].features.isEmpty ? 1 : board.qualityMultiplier
        let quality = min(100, max(0,
            100 * completion * topicFit * bugFactor * techMultiplier * ceiling * codebaseCeiling
                * boardMultiplier
        ))

        // Full review model: the press expects more from an older, more
        // reputable studio and from a more ambitious kind of product, docks
        // a fraction of any shortfall, and grants a hype bonus. Reputation
        // here is the pre-nudge value.
        // MARK: K4 (deals and exits)
        // A company with a for-sale sign up launches to a shrug. Exactly
        // ×1 while no sign stands.
        let hypeAtLaunch = (dev.hype * state.dealLaunchHypeFactor(balance: balance)
            // MARK: T4 (publisher) — the publisher's name on launch day;
            // + exactly 0 for a build nobody published.
            + state.publisherLaunchHype(for: state.products[index], balance: balance))
            // MARK: end T4
            // MARK: T6 (away) — the founder away on ship day (doors armed): ×0.85, and the log keeps it for the party and the launch sheet. Exactly ×1 at the desk and on every bot.
            * state.awayLaunchHypeFactor(balance: balance)
        AwaySystem.noteLaunch(productID: productID, state: &state, balance: balance)
        // MARK: end T6
        // MARK: end K4
        let expected = balance.reviewExpectationBase
            + balance.reviewExpectationPerYear * Double(state.year - 1)
            + balance.reviewExpectationRepFactor * state.company.reputation
            + balance.economy.expectationPerComplexity * (type.complexity - 1)
            // MARK: T5 (expo and pre-orders) — the press saw the demo: +3 for
            // a build shown at the expo, exactly +0 for every other.
            + ExpoRules.expectationBump(for: state.products[index], balance: balance)
            // MARK: end T5
        let baseScore = quality
            - balance.reviewShortfallPenalty * max(0, expected - quality)
            + hypeAtLaunch / balance.reviewHypeDivisor

        // What the outlets have to work with: the product's own name, its
        // type and topic, and the three things that make a launch worth a
        // remark — bugs, polish, and hype the release cannot cash.
        let marketScale = launchMarketScale(
            for: state.products[index], state: state, balance: balance,
            excluding: excludingFromSaturation
        )
        let reviewContext = ReviewContext(
            productName: state.products[index].name,
            typeName: type.name,
            topicName: content.topic(state.products[index].topicID)?.name
                ?? state.products[index].topicID,
            bugRatio: type.codePts > 0 ? Double(dev.openBugs) / type.codePts : 0,
            polishRatio: type.polishPts > 0 ? min(1, dev.polishPts / type.polishPts) : 1,
            hype: hypeAtLaunch,
            marketScale: marketScale,
            // M1: the two words a review can quote. Empty on an empty
            // board, and `ReviewBlurbs` only reaches for the token when a
            // feature callout fires, so a boardless launch reads exactly
            // as it always did.
            bestFeature: board.bestCard?.name ?? "",
            worstFeature: board.worstCard?.name ?? "",
            // MARK: J3 (rivals and the market)
            bestFeatureCopied: board.bestCard?.copiedBy != nil
            // MARK: end J3
        )

        var reviews: [Review] = []
        for outlet in balance.reviewOutlets {
            // MARK: T7 (press and stakes) — the outlet's standing with the
            // studio. Exactly 0.0 with an empty map (every bot, every
            // fixture); the one gaussian is drawn either way.
            let noise = state.rng.nextGaussian(sigma: balance.reviewNoiseSigma)
                + state.company.pressScoreOffset(for: outlet, balance: balance)
            // MARK: end T7
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
        // MARK: T7 (press and stakes) — every standing drifts toward 0 with
        // each launch, after the loop has read it. Returns on its first line
        // with an empty map (every bot, every fixture); draws nothing.
        PressSystem.driftAfterLaunch(&state, balance)
        // MARK: end T7

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

        // The forecast as it stood this morning, frozen for launch day.
        let launchForecast = state.shipForecast(
            productID: productID, balance: balance, content: content
        )?.snapshot

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
            isSubscription: type.revenueModel == .subscription,
            launchForecast: launchForecast
        )
        let averageScore = info.averageReviewScore

        state.company.reputation = min(100, max(0,
            state.company.reputation
                + (Double(averageScore) - state.company.reputation) * balance.reputationReviewNudge
        ))
        // What this product leaves behind for the next one: the carried
        // share of its pools, and the debt of the build plus the bugs that
        // went out with it. Recorded before the stage flips so the
        // in-development progress is still readable.
        CodebaseSystem.recordShip(
            product: state.products[index], dev: dev, type: type,
            state: &state, balance: balance
        )
        state.products[index].stage = .released(info)
        // MARK: T2 (the build) — P1: a launch priced off standard writes
        // the tier and starts K2's 28-day clock; standard, the bots' only
        // price, writes nothing.
        if tier != .standard, case .released(var priced) = state.products[index].stage {
            priced.priceTier = tier
            priced.lastPriceChangeDay = state.day
            state.products[index].stage = .released(priced)
        }
        // MARK: end T2

        // The category ledger: a launch is the biggest single thing the
        // studio can do for its name in a topic, and the press decides how
        // much of it counts.
        StandingSystem.recordLaunch(
            topicID: state.products[index].topicID,
            averageReviewScore: averageScore,
            &state, balance
        )

        // MARK: K7 (partner and diary) — a launch on a diary date raises the clash.
        DiaryRoadmap.noteLaunch(&state, balance: balance, content: content)
        // MARK: end K7
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
    ///
    /// `featureCardID` (the wishlist) rides a defaulted argument, so every
    /// old caller — the bots, the rival fight, the tests — starts the
    /// plain patch it always did. Named, the update carries that card to
    /// `Product.features` when it lands (`LiveOpsSystem.completeUpdates`).
    /// A card the catalog doesn't know, the studio hasn't researched, the
    /// product already has, or that belongs on neither its type nor its
    /// topic refuses the whole update — no partial state, like every
    /// other refused action here.
    static func startUpdate(
        productID: UUID,
        featureCardID: String? = nil,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard let index = state.products.firstIndex(where: { $0.id == productID }),
              case .released(let info) = state.products[index].stage,
              !info.offMarket,
              state.economy.update(for: productID) == nil,
              // A patch is a build and takes a build slot, exactly as
              // `startProduct` does. In a two-slot loft, patching the last
              // product means not starting the next one.
              state.hasFreeDevSlot,
              let type = content.productType(state.products[index].typeID)
        else { return [] }

        if let featureCardID {
            guard let card = content.featureCard(featureCardID),
                  FeatureBoard.isUnlocked(card, state: state),
                  !state.products[index].features.contains(featureCardID),
                  card.fits(typeID: state.products[index].typeID)
                    || card.fits(topicID: state.products[index].topicID)
            else { return [] }
        }

        let fraction = balance.economy.updatePoolFraction
        state.economy.updates.append(ProductUpdate(
            productID: productID,
            startedDay: state.day,
            designPts: type.designPts * fraction,
            codePts: type.codePts * fraction,
            polishPts: type.polishPts * fraction,
            featureCardID: featureCardID
        ))
        for employeeIndex in state.employees.indices
        where state.employees[employeeIndex].assignment == .idle {
            state.employees[employeeIndex].assignment = .product(productID)
        }
        return []
    }

    // MARK: Iteration 10 — M6

    /// Takes one bug off a build in flight, because the player put a thumb
    /// on it in the office.
    ///
    /// The only way into this function is `.squashBug`, which only the
    /// office scene's tap gesture sends: no system calls it, no bot taps,
    /// and nothing here draws from `rng` or `worldRNG`. A run that never
    /// hunts is the run that shipped.
    ///
    /// Every gate lives in `BugHunt.refusal` so the sentence the player
    /// reads is the reason the engine used. A refusal returns no events,
    /// which is how the app's toast layer knows to say why.
    static func squash(
        productID: UUID,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard BugHunt.refusal(productID: productID, in: state, balance: balance) == nil,
              let index = state.products.firstIndex(where: { $0.id == productID }),
              case .development(var dev) = state.products[index].stage
        else { return [] }

        dev.openBugs = max(0, dev.openBugs - 1)
        state.products[index].stage = .development(dev)
        return [.bugSquashed(productID: productID, remaining: dev.openBugs, day: state.day)]
    }
}
