import Foundation
import Testing
import TycoonContent
import TycoonEngine

/// Shipping is not the end of a product's story: bugs surface in the wild,
/// a support desk clears them, the price can move, a patch can lift a
/// disappointing launch, and a bigger office runs more than one build.
@Suite("Live ops")
struct LiveOpsTests {
    /// A live-ops economy at the shipped numbers, everything else neutral.
    static func economy(
        liveBugSeedFraction: Double = 0.5,
        liveBugUnitsPerDiscovery: Double = 2_000,
        liveBugSalesPenalty: Double = 0.015,
        liveBugAlarmThreshold: Int = 12,
        supportBugFixMultiplier: Double = 1.5,
        updatePoolFraction: Double = 0.30,
        updateQualityBonus: Double = 8,
        updateReviewWeight: Double = 0.5,
        updateSalesBump: Double = 1.5
    ) -> BalanceConfig.EconomyBalance {
        var economy = TestBalance.neutralEconomy
        economy.liveBugSeedFraction = liveBugSeedFraction
        economy.liveBugUnitsPerDiscovery = liveBugUnitsPerDiscovery
        economy.liveBugSalesPenalty = liveBugSalesPenalty
        economy.liveBugAlarmThreshold = liveBugAlarmThreshold
        economy.supportBugFixMultiplier = supportBugFixMultiplier
        economy.updatePoolFraction = updatePoolFraction
        economy.updateQualityBonus = updateQualityBonus
        economy.updateReviewWeight = updateReviewWeight
        economy.updateSalesBump = updateSalesBump
        economy.priceTiers = BalanceConfig.EconomyBalance.PriceTierDef.standardTable
        return economy
    }

    static func content(marketSize: Double = 100_000) -> ContentCatalog {
        TestContent.tiny(
            designPts: 100, codePts: 100, polishPts: 100,
            unitPrice: 1, marketSize: marketSize
        )
    }

    /// A state with one released product at `score`, `liveBugs` bugs, and
    /// nobody assigned.
    static func withRelease(
        balance: BalanceConfig,
        content: ContentCatalog,
        score: Int = 80,
        liveBugs: Int = 0,
        seed: UInt64 = 31
    ) throws -> (GameState, UUID) {
        var state = GameState.newGame(companyName: "Acme", seed: seed, balance: balance)
        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        let id = try #require(state.products.first?.id)
        state.products[0].stage = .released(ReleaseInfo(
            launchDay: 0,
            quality: Double(score),
            reviews: [Review(outlet: "Test", score: score, blurb: "")],
            weeklySales: [],
            offMarket: false,
            liveBugs: liveBugs
        ))
        for index in state.employees.indices {
            state.employees[index].assignment = .idle
        }
        return (state, id)
    }

    static func release(_ state: GameState, _ id: UUID) throws -> ReleaseInfo {
        guard case .released(let info)? = state.product(id: id)?.stage else {
            Issue.record("expected a released stage")
            return ReleaseInfo(
                launchDay: 0, quality: 0, reviews: [], weeklySales: [], offMarket: true
            )
        }
        return info
    }

    // MARK: - Live bugs

    @Test func shippingWithOpenBugsLeavesHalfOfThemInTheWild() throws {
        let balance = TestBalance.make(reviewNoiseSigma: 0, economy: Self.economy())
        let content = TestContent.tiny(designPts: 10, codePts: 10, polishPts: 10)
        var state = GameState.newGame(companyName: "Acme", seed: 9, balance: balance)
        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        let id = try #require(state.products.first?.id)
        state.products[0].stage = .development(DevProgress(
            designPts: 10, codePts: 10, polishPts: 10,
            openBugs: 7, focus: .balanced, hype: 0,
            crewSkillDaySum: 50, crewSkillDays: 1
        ))
        Reducer.apply(.ship(productID: id), to: &state, balance: balance, content: content)

        // 7 × 0.5 = 3.5, rounded to 4.
        #expect(try Self.release(state, id).liveBugs == 4)
    }

    @Test func theWildFindsBugsInProportionToUse() throws {
        let balance = TestBalance.make(
            life: TestBalance.quietLife,
            economy: Self.economy(liveBugUnitsPerDiscovery: 500)
        )
        // A huge market so a week reliably sells thousands of units.
        var (state, id) = try Self.withRelease(
            balance: balance, content: Self.content(marketSize: 100_000)
        )
        for _ in 0..<21 {
            Reducer.tick(&state, balance: balance, content: Self.content(marketSize: 100_000))
        }
        let info = try Self.release(state, id)
        #expect(info.weeklySales.count == 3)
        #expect(info.liveBugs > 20, "three busy weeks should surface bugs, found \(info.liveBugs)")
    }

    @Test func liveBugsEatIntoWeeklySales() throws {
        func firstWeekUnits(liveBugs: Int) throws -> Int {
            let balance = TestBalance.make(life: TestBalance.quietLife, economy: Self.economy(
                liveBugUnitsPerDiscovery: .infinity
            ))
            let content = Self.content(marketSize: 10_000)
            var (state, id) = try Self.withRelease(
                balance: balance, content: content, liveBugs: liveBugs
            )
            for _ in 0..<7 {
                Reducer.tick(&state, balance: balance, content: content)
            }
            return try #require(try Self.release(state, id).weeklySales.first).units
        }

        let clean = try firstWeekUnits(liveBugs: 0)
        let buggy = try firstWeekUnits(liveBugs: 10)
        // 10 bugs × 1.5% = 15% off the week.
        #expect(abs(Double(buggy) - Double(clean) * 0.85) < 2)
    }

    @Test func liveBugsCrossingTheAlarmThresholdRaiseAnEvent() throws {
        let balance = TestBalance.make(
            life: TestBalance.quietLife,
            economy: Self.economy(liveBugUnitsPerDiscovery: 100, liveBugAlarmThreshold: 12)
        )
        let content = Self.content(marketSize: 100_000)
        var (state, _) = try Self.withRelease(balance: balance, content: content)
        var spikes = 0
        for _ in 0..<70 {
            for event in Reducer.tick(&state, balance: balance, content: content) {
                if case .liveBugsSpiking = event { spikes += 1 }
            }
        }
        #expect(spikes == 1, "the alarm should sound once per run of trouble, not weekly")
    }

    // MARK: - Support

    @Test func aSupportDeskClearsBugsAndHoldsChurnDown() throws {
        let balance = TestBalance.make(
            life: TestBalance.quietLife,
            economy: Self.economy(liveBugUnitsPerDiscovery: .infinity)
        )
        let content = Self.content(marketSize: 1_000)
        var (state, id) = try Self.withRelease(
            balance: balance, content: content, liveBugs: 40
        )
        state.employees[0].assignment = .support(id)
        for _ in 0..<7 {
            Reducer.tick(&state, balance: balance, content: content)
        }
        let after = try Self.release(state, id).liveBugs
        #expect(after < 40, "a week on support should clear bugs, still \(after)")
        #expect(after > 0, "one founder should not clear forty bugs in a week")
    }

    @Test func supportAssignmentsClearWhenTheProductLeavesTheMarket() throws {
        let balance = TestBalance.make(life: TestBalance.quietLife, economy: Self.economy())
        let content = Self.content(marketSize: 1_000)
        var (state, id) = try Self.withRelease(balance: balance, content: content)
        state.employees[0].assignment = .support(id)
        if case .released(var info) = state.products[0].stage {
            info.offMarket = true
            state.products[0].stage = .released(info)
        }
        Reducer.tick(&state, balance: balance, content: content)
        #expect(state.employees[0].assignment == .idle)
    }

    // MARK: - Price tiers

    @Test func settingAPriceTierIsGatedAndAnnounced() throws {
        let balance = TestBalance.make(economy: Self.economy())
        let content = Self.content()
        var (state, id) = try Self.withRelease(balance: balance, content: content)

        let events = Reducer.apply(
            .setPriceTier(productID: id, tier: .premium),
            to: &state, balance: balance, content: content
        )
        #expect(events.count == 1)
        if case .priceChanged(let productID, let tier, _) = events[0] {
            #expect(productID == id)
            #expect(tier == .premium)
        } else {
            Issue.record("expected .priceChanged, got \(events)")
        }
        #expect(try Self.release(state, id).priceTier == .premium)

        // Setting the same tier again is a no-op.
        #expect(Reducer.apply(
            .setPriceTier(productID: id, tier: .premium),
            to: &state, balance: balance, content: content
        ).isEmpty)

        // A delisted product cannot be repriced.
        if case .released(var info) = state.products[0].stage {
            info.offMarket = true
            state.products[0].stage = .released(info)
        }
        #expect(Reducer.apply(
            .setPriceTier(productID: id, tier: .budget),
            to: &state, balance: balance, content: content
        ).isEmpty)
    }

    @Test func pricingAProductStillInDevelopmentIsIgnored() throws {
        let balance = TestBalance.make(economy: Self.economy())
        let content = Self.content()
        var state = GameState.newGame(companyName: "Acme", seed: 2, balance: balance)
        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        let id = try #require(state.products.first?.id)
        #expect(Reducer.apply(
            .setPriceTier(productID: id, tier: .budget),
            to: &state, balance: balance, content: content
        ).isEmpty)
    }

    // MARK: - Updates

    @Test func aPatchIsShorterThanTheOriginalBuildAndPullsInIdleHands() throws {
        let balance = TestBalance.make(economy: Self.economy())
        let content = Self.content()
        var (state, id) = try Self.withRelease(balance: balance, content: content)

        Reducer.apply(.startUpdate(productID: id), to: &state, balance: balance, content: content)
        let update = try #require(state.economy.update(for: id))
        // 30% of 100/100/100.
        #expect(update.designPts == 30)
        #expect(update.codePts == 30)
        #expect(update.polishPts == 30)
        #expect(state.employees[0].assignment == .product(id))

        // Starting a second patch on the same product is ignored.
        Reducer.apply(.startUpdate(productID: id), to: &state, balance: balance, content: content)
        #expect(state.economy.updates.count == 1)
    }

    /// The daily sweep frees people from *released* products — a patch has
    /// to be the exception, or its crew is swept off every morning and the
    /// patch never moves.
    @Test func aPatchCrewIsNotSweptOffTheReleasedProduct() throws {
        let balance = TestBalance.make(life: TestBalance.quietLife, economy: Self.economy())
        let content = Self.content()
        var (state, id) = try Self.withRelease(balance: balance, content: content)
        TestLife.pinPeak(&state)
        Reducer.apply(.startUpdate(productID: id), to: &state, balance: balance, content: content)

        for _ in 0..<5 {
            Reducer.tick(&state, balance: balance, content: content)
        }
        #expect(state.employees[0].assignment == .product(id), "the founder was swept off the patch")
        let update = try #require(state.economy.update(for: id))
        #expect(update.completion > 0, "five days of work should move the patch")
        #expect(update.progressCode > 0)
    }

    /// Left alone, a patch finishes on its own and lands.
    @Test func aPatchFinishesUnderItsOwnSteam() throws {
        let balance = TestBalance.make(life: TestBalance.quietLife, economy: Self.economy())
        // Small pools so a lone founder can finish the 30% patch.
        let content = TestContent.tiny(designPts: 10, codePts: 10, polishPts: 10, marketSize: 1_000)
        var (state, id) = try Self.withRelease(balance: balance, content: content)
        TestLife.pinPeak(&state)
        Reducer.apply(.startUpdate(productID: id), to: &state, balance: balance, content: content)

        var landed = false
        for _ in 0..<40 {
            for event in Reducer.tick(&state, balance: balance, content: content) {
                if case .updateShipped = event { landed = true }
            }
            if landed { break }
        }
        #expect(landed, "a patch left running should land")
        #expect(state.economy.updates.isEmpty)
    }

    @Test func aFinishedPatchLiftsQualityBugsAndReviews() throws {
        let balance = TestBalance.make(
            reviewNoiseSigma: 0, life: TestBalance.quietLife, economy: Self.economy()
        )
        let content = Self.content()
        var (state, id) = try Self.withRelease(
            balance: balance, content: content, score: 50, liveBugs: 10
        )
        Reducer.apply(.startUpdate(productID: id), to: &state, balance: balance, content: content)
        // Hand the patch its finished pools and let the day land it.
        state.economy.updates[0].progressDesign = 30
        state.economy.updates[0].progressCode = 30
        state.economy.updates[0].progressPolish = 30

        var shipped: (UUID, Int)?
        for event in Reducer.tick(&state, balance: balance, content: content) {
            if case .updateShipped(let productID, let newScore, _) = event {
                shipped = (productID, newScore)
            }
        }
        let landed = try #require(shipped)
        #expect(landed.0 == id)

        let info = try Self.release(state, id)
        #expect(info.quality == 58, "quality should gain the patch bonus, got \(info.quality)")
        #expect(info.liveBugs == 5, "a patch should clear half the wild's backlog")
        #expect(info.updateCount == 1)
        #expect(info.lastUpdateDay == state.day)
        // Re-review at half weight: (50 + 0.5 × 58) / 1.5 = 52.67 → 53.
        #expect(info.averageReviewScore == 53)
        #expect(landed.1 == 53)
        #expect(state.economy.updates.isEmpty)
        // The crew comes off the patch.
        #expect(state.employees[0].assignment == .idle)
    }

    @Test func aPatchBuysOneBumperSalesWeek() throws {
        func unitsAfterPatch(_ patched: Bool) throws -> Int {
            let balance = TestBalance.make(
                life: TestBalance.quietLife,
                economy: Self.economy(liveBugUnitsPerDiscovery: .infinity)
            )
            let content = Self.content(marketSize: 10_000)
            var (state, id) = try Self.withRelease(balance: balance, content: content)
            if patched, case .released(var info) = state.products[0].stage {
                info.lastUpdateDay = 1
                state.products[0].stage = .released(info)
            }
            for _ in 0..<7 {
                Reducer.tick(&state, balance: balance, content: content)
            }
            return try #require(try Self.release(state, id).weeklySales.first).units
        }
        let plain = try unitsAfterPatch(false)
        let bumped = try unitsAfterPatch(true)
        #expect(abs(Double(bumped) - Double(plain) * 1.5) < 2)
    }

    @Test func patchingADelistedOrUnreleasedProductIsIgnored() throws {
        let balance = TestBalance.make(economy: Self.economy())
        let content = Self.content()
        var (state, id) = try Self.withRelease(balance: balance, content: content)
        if case .released(var info) = state.products[0].stage {
            info.offMarket = true
            state.products[0].stage = .released(info)
        }
        Reducer.apply(.startUpdate(productID: id), to: &state, balance: balance, content: content)
        #expect(state.economy.updates.isEmpty)

        Reducer.apply(
            .startUpdate(productID: UUID()), to: &state, balance: balance, content: content
        )
        #expect(state.economy.updates.isEmpty)
    }

    // MARK: - Development slots

    @Test func theOfficeSetsHowManyBuildsRunAtOnce() throws {
        let balance = TestBalance.make(economy: Self.economy())
        let content = Self.content()
        var state = GameState.newGame(companyName: "Acme", seed: 6, balance: balance)

        #expect(state.devSlots == 1)
        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "A", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "B", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        #expect(state.productsInDevelopment.count == 1, "a garage builds one thing")

        state.company.officeTier = .loft
        #expect(state.devSlots == 2)
        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "B", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        #expect(state.productsInDevelopment.count == 2)
        #expect(state.productInDevelopment?.name == "A", "the shorthand stays the first build")

        state.company.officeTier = .campus
        #expect(state.devSlots == 5)
    }

    @Test func twoBuildsEachGetTheirOwnCrewAndTheirOwnDay() throws {
        let balance = TestBalance.make(
            skillGrowthRate: 0, life: TestBalance.quietLife, economy: Self.economy()
        )
        let content = TestContent.tiny(designPts: 500, codePts: 500, polishPts: 500)
        var state = GameState.newGame(companyName: "Acme", seed: 7, balance: balance)
        state.company.officeTier = .loft
        TestLife.pinPeak(&state)

        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "A", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "B", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        let second = try #require(state.products.last?.id)
        state.employees.append(TestPeople.employee(
            coding: 50, design: 50, assignment: .product(second)
        ))
        Reducer.tick(&state, balance: balance, content: content)

        for product in state.products {
            guard case .development(let dev) = product.stage else {
                Issue.record("expected two builds in development")
                return
            }
            #expect(dev.codePts > 0, "\(product.name) got no work")
            #expect(dev.crewSkillDays == 1)
        }
    }

    // MARK: - Save compatibility

    @Test func economyStateDecodesWhenTheKeyIsAbsent() throws {
        let economy = try JSONDecoder().decode(EconomyState.self, from: Data("{}".utf8))
        #expect(economy == .initial)
        #expect(economy.workPace == .normal)
        #expect(economy.updates.isEmpty)
        #expect(economy.pendingResignation == nil)
    }

    @Test func economyStateRoundTripsAndEncodesDeterministically() throws {
        var economy = EconomyState.initial
        economy.workPace = .crunch
        economy.updates = [ProductUpdate(
            productID: UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!,
            startedDay: 4, designPts: 3, codePts: 4, polishPts: 5
        )]
        economy.lastRecognitionDay = [
            UUID(uuidString: "00000000-0000-0000-0000-0000000000FF")!: 9,
            UUID(uuidString: "00000000-0000-0000-0000-000000000011")!: 3,
        ]
        economy.hospitalizationDays = [10, 200]

        // The save path encodes with sorted keys (see
        // `FullLoopDeterminismTests`); what matters here is that the array
        // *values* are ordered by the encoder, not by `Set`/`Dictionary`
        // iteration order.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let first = try encoder.encode(economy)
        let second = try encoder.encode(economy)
        #expect(first == second)
        // Sorted by id, so the JSON is stable across processes.
        let text = String(decoding: first, as: UTF8.self)
        let firstIndex = try #require(text.range(of: "000000000011"))
        let secondIndex = try #require(text.range(of: "0000000000FF"))
        #expect(firstIndex.lowerBound < secondIndex.lowerBound)
        #expect(try JSONDecoder().decode(EconomyState.self, from: first) == economy)
    }
}
