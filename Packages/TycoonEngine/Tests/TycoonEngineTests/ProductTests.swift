import Foundation
import Testing
import TycoonContent
import TycoonEngine

@Suite("Product actions")
struct ProductActionTests {
    // MARK: - startProduct

    @Test func startProductCreatesDevelopmentProductAndEmitsEvent() throws {
        let balance = TestBalance.standard
        let content = TestContent.bundled
        var state = GameState.newGame(companyName: "Acme", seed: 42, balance: balance)

        let events = Reducer.apply(
            .startProduct(typeID: "mobile_app", topicID: "fitness", name: "FitTrack", focus: .balanced),
            to: &state, balance: balance, content: content
        )

        let product = try #require(state.products.first)
        #expect(state.products.count == 1)
        #expect(product.name == "FitTrack")
        #expect(product.typeID == "mobile_app")
        #expect(product.topicID == "fitness")
        #expect(state.productInDevelopment?.id == product.id)
        #expect(state.product(id: product.id) == product)

        guard case .development(let dev) = product.stage else {
            Issue.record("expected a development stage")
            return
        }
        #expect(dev.designPts == 0)
        #expect(dev.codePts == 0)
        #expect(dev.polishPts == 0)
        #expect(dev.openBugs == 0)
        #expect(dev.hype == 0)

        #expect(events == [.productStarted(productID: product.id, day: 0)])
        #expect(state.eventLog == [.productStarted(productID: product.id, day: 0)])
    }

    @Test func startProductIDIsDeterministicFromSeed() throws {
        let balance = TestBalance.standard
        let content = TestContent.bundled

        func startedID(seed: UInt64) throws -> UUID {
            var state = GameState.newGame(companyName: "Acme", seed: seed, balance: balance)
            Reducer.apply(
                .startProduct(typeID: "mobile_app", topicID: "fitness", name: "FitTrack", focus: .balanced),
                to: &state, balance: balance, content: content
            )
            return try #require(state.products.first?.id)
        }

        #expect(try startedID(seed: 42) == startedID(seed: 42))
        #expect(try startedID(seed: 42) != startedID(seed: 43))
    }

    @Test func secondStartProductWhileOneIsInDevelopmentIsIgnored() {
        let balance = TestBalance.standard
        let content = TestContent.bundled
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)

        Reducer.apply(
            .startProduct(typeID: "mobile_app", topicID: "fitness", name: "First", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        let events = Reducer.apply(
            .startProduct(typeID: "web_app", topicID: "social", name: "Second", focus: .balanced),
            to: &state, balance: balance, content: content
        )

        #expect(events.isEmpty)
        #expect(state.products.count == 1)
        #expect(state.products.first?.name == "First")
    }

    @Test func startProductWithUnknownTypeOrTopicIsIgnored() {
        let balance = TestBalance.standard
        let content = TestContent.bundled
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)

        let unknownType = Reducer.apply(
            .startProduct(typeID: "hologram", topicID: "fitness", name: "Nope", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        #expect(unknownType.isEmpty)
        #expect(state.products.isEmpty)

        let unknownTopic = Reducer.apply(
            .startProduct(typeID: "mobile_app", topicID: "underwater_basket_weaving", name: "Nope", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        #expect(unknownTopic.isEmpty)
        #expect(state.products.isEmpty)
        #expect(state.eventLog.isEmpty)
    }

    @Test func startProductWithLockedTypeIsIgnored() {
        let balance = TestBalance.standard
        let content = TestContent.bundled
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)

        // "game" is unlockedFromStart: false in the bundled catalog.
        let events = Reducer.apply(
            .startProduct(typeID: "game", topicID: "gaming", name: "Locked", focus: .balanced),
            to: &state, balance: balance, content: content
        )

        #expect(events.isEmpty)
        #expect(state.products.isEmpty)
        #expect(state.eventLog.isEmpty)
    }

    // MARK: - Focus split & normalization

    @Test func dailyFounderPointsSplitByFocus() throws {
        let balance = TestBalance.make(bugChanceBase: 0, skillGrowthRate: 0, life: TestBalance.quietLife)
        let content = TestContent.tiny(designPts: 100, codePts: 100, polishPts: 100)
        var state = GameState.newGame(companyName: "Acme", seed: 9, balance: balance)
        TestLife.pinPeak(&state) // founder output multiplier exactly 1

        Reducer.apply(
            .startProduct(
                typeID: "tool", topicID: "testing", name: "T",
                focus: PhaseFocus(design: 0.5, code: 0.3, polish: 0.2)
            ),
            to: &state, balance: balance, content: content
        )
        for _ in 0..<10 {
            Reducer.tick(&state, balance: balance, content: content)
        }

        guard case .development(let dev) = try #require(state.products.first).stage else {
            Issue.record("expected a development stage")
            return
        }
        // The auto-assigned founder (coding 40, design 30), 10 days, focus
        // 0.5/0.3/0.2, growth disabled:
        //   design = 10 * 0.5 * (1 + 30/25)     = 11.0
        //   code   = 10 * 0.3 * (1 + 40/25)     = 7.8
        //   polish = 10 * 0.2 * (1 + (70/2)/25) = 4.8
        #expect(abs(dev.designPts - 11.0) < 1e-9)
        #expect(abs(dev.codePts - 7.8) < 1e-9)
        #expect(abs(dev.polishPts - 4.8) < 1e-9)
    }

    @Test func setPhaseFocusChangesSplitFromNextTick() throws {
        let balance = TestBalance.make(bugChanceBase: 0, skillGrowthRate: 0, life: TestBalance.quietLife)
        let content = TestContent.tiny(designPts: 100, codePts: 100, polishPts: 100)
        var state = GameState.newGame(companyName: "Acme", seed: 9, balance: balance)
        TestLife.pinPeak(&state) // founder output multiplier exactly 1

        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        let id = try #require(state.products.first?.id)
        for _ in 0..<3 {
            Reducer.tick(&state, balance: balance, content: content)
        }

        let events = Reducer.apply(
            .setPhaseFocus(productID: id, focus: PhaseFocus(design: 0, code: 1, polish: 0)),
            to: &state, balance: balance, content: content
        )
        #expect(events.isEmpty)
        for _ in 0..<2 {
            Reducer.tick(&state, balance: balance, content: content)
        }

        guard case .development(let dev) = try #require(state.products.first).stage else {
            Issue.record("expected a development stage")
            return
        }
        // Founder yields (growth off): balanced days give design 2.2/3,
        // code 2.6/3, polish 2.4/3; all-code days give 2.6 code points.
        // 3 balanced days then 2 all-code days:
        #expect(abs(dev.designPts - 2.2) < 1e-9)
        #expect(abs(dev.codePts - (2.6 + 5.2)) < 1e-9)
        #expect(abs(dev.polishPts - 2.4) < 1e-9)
    }

    @Test func focusNormalization() throws {
        let balance = TestBalance.standard
        let content = TestContent.tiny()

        func appliedFocus(_ focus: PhaseFocus) throws -> PhaseFocus {
            var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
            Reducer.apply(
                .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: focus),
                to: &state, balance: balance, content: content
            )
            guard case .development(let dev) = try #require(state.products.first).stage else {
                Issue.record("expected a development stage")
                throw CancellationError()
            }
            return dev.focus
        }

        // Already normalized input stays (within floating accuracy).
        let kept = try appliedFocus(PhaseFocus(design: 0.5, code: 0.3, polish: 0.2))
        #expect(abs(kept.design - 0.5) < 1e-9)
        #expect(abs(kept.code - 0.3) < 1e-9)
        #expect(abs(kept.polish - 0.2) < 1e-9)

        // 2/1/1 normalizes to 0.5/0.25/0.25.
        let scaled = try appliedFocus(PhaseFocus(design: 2, code: 1, polish: 1))
        #expect(abs(scaled.design - 0.5) < 1e-9)
        #expect(abs(scaled.code - 0.25) < 1e-9)
        #expect(abs(scaled.polish - 0.25) < 1e-9)

        // All-zero becomes equal thirds.
        let thirds = try appliedFocus(PhaseFocus(design: 0, code: 0, polish: 0))
        #expect(abs(thirds.design - 1.0 / 3.0) < 1e-9)
        #expect(abs(thirds.code - 1.0 / 3.0) < 1e-9)
        #expect(abs(thirds.polish - 1.0 / 3.0) < 1e-9)
    }

    // MARK: - Ship gate

    @Test func shipBeforeCodeThresholdIsIgnoredAndWorksAtThreshold() throws {
        let balance = TestBalance.make(
            bugChanceBase: 0, shipCodeThreshold: 0.5, skillGrowthRate: 0, life: TestBalance.quietLife
        )
        let content = TestContent.tiny(designPts: 10, codePts: 10, polishPts: 10)
        var state = GameState.newGame(companyName: "Acme", seed: 3, balance: balance)
        TestLife.pinPeak(&state) // founder output multiplier exactly 1

        Reducer.apply(
            .startProduct(
                typeID: "tool", topicID: "testing", name: "T",
                focus: PhaseFocus(design: 0, code: 1, polish: 0)
            ),
            to: &state, balance: balance, content: content
        )
        let id = try #require(state.products.first?.id)

        // Day 1: 2.6 founder code points < 0.5 * 10 = 5 required. Ship is ignored.
        Reducer.tick(&state, balance: balance, content: content)
        let early = Reducer.apply(.ship(productID: id), to: &state, balance: balance, content: content)
        #expect(early.isEmpty)
        guard case .development = try #require(state.products.first).stage else {
            Issue.record("product must still be in development after a rejected ship")
            return
        }

        // Day 2: 5.2 code points >= threshold. Ship succeeds.
        Reducer.tick(&state, balance: balance, content: content)
        let events = Reducer.apply(.ship(productID: id), to: &state, balance: balance, content: content)
        guard case .released(let info) = try #require(state.products.first).stage else {
            Issue.record("expected a released stage")
            return
        }
        #expect(info.launchDay == 2)
        #expect(info.offMarket == false)
        #expect(info.weeklySales.isEmpty)
        #expect(events.count == 2)
        #expect(events.first == .shipped(productID: id, day: 2))
        #expect(events.last == .reviewsIn(productID: id, averageScore: info.averageReviewScore, day: 2))
    }

    // MARK: - Quality formula

    @Test func shipQualityMatchesHandComputedFormula() throws {
        // Founder skills pinned to 25/25 (growth off) make every pool yield
        // exactly 2 * focusShare per day. Focus 0.5/0.3/0.2 over 5 days:
        // design 5/5 (capped 1.0), code 3/5, polish 2/5.
        // completion = 0.35*1 + 0.45*0.6 + 0.20*0.4 = 0.70
        // quality = 100 * 0.70 * 1.15 (fit) * 1.0 (no bugs) = 80.5
        let balance = TestBalance.make(
            bugChanceBase: 0, founderCoding: 25,
            founderDesign: 25, skillGrowthRate: 0, reviewNoiseSigma: 0,
            life: TestBalance.quietLife
        )
        let content = TestContent.tiny(designPts: 5, codePts: 5, polishPts: 5, topicFit: 1.15)
        var state = GameState.newGame(companyName: "Acme", seed: 8, balance: balance)
        TestLife.pinPeak(&state) // founder output multiplier exactly 1

        Reducer.apply(
            .startProduct(
                typeID: "tool", topicID: "testing", name: "T",
                focus: PhaseFocus(design: 0.5, code: 0.3, polish: 0.2)
            ),
            to: &state, balance: balance, content: content
        )
        let id = try #require(state.products.first?.id)
        for _ in 0..<5 {
            Reducer.tick(&state, balance: balance, content: content)
        }
        Reducer.apply(.ship(productID: id), to: &state, balance: balance, content: content)

        guard case .released(let info) = try #require(state.products.first).stage else {
            Issue.record("expected a released stage")
            return
        }
        #expect(abs(info.quality - 80.5) < 1e-9)
    }

    @Test func shipQualityAppliesBugPenalty() throws {
        let balance = TestBalance.make(bugChanceBase: 0, reviewNoiseSigma: 0)
        let content = TestContent.tiny(designPts: 10, codePts: 10, polishPts: 10)
        var state = GameState.newGame(companyName: "Acme", seed: 8, balance: balance)

        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        let id = try #require(state.products.first?.id)
        // Hand-craft complete pools with 2 open bugs: penalty = 1 - min(0.4, 2/10) = 0.8.
        state.products[0].stage = .development(DevProgress(
            designPts: 10, codePts: 10, polishPts: 10,
            openBugs: 2, focus: .balanced, hype: 0
        ))
        Reducer.apply(.ship(productID: id), to: &state, balance: balance, content: content)

        guard case .released(let info) = try #require(state.products.first).stage else {
            Issue.record("expected a released stage")
            return
        }
        // quality = 100 * 1.0 * 1.0 * 0.8 = 80
        #expect(abs(info.quality - 80.0) < 1e-9)
    }

    // MARK: - Reviews

    @Test func shipGeneratesFourBoundedDeterministicReviewsAndNudgesReputation() throws {
        let balance = try BalanceConfig.loadBundled()
        let content = TestContent.bundled

        func shippedState(seed: UInt64) -> GameState {
            var state = GameState.newGame(companyName: "Acme", seed: seed, balance: balance)
            Reducer.apply(
                .startProduct(
                    typeID: "mobile_app", topicID: "fitness", name: "FitTrack",
                    focus: PhaseFocus(design: 0, code: 1, polish: 0)
                ),
                to: &state, balance: balance, content: content
            )
            let id = state.products[0].id
            // 28 all-code founder days (~2.6 points each, slowly growing,
            // scaled by the ~0.9 life multiplier at the starting meters —
            // with slack for a scripted cold or absence) clear the gate:
            // > 60 code points >= 0.6 * 90 = 54.
            for _ in 0..<28 {
                Reducer.tick(&state, balance: balance, content: content)
            }
            Reducer.apply(.ship(productID: id), to: &state, balance: balance, content: content)
            return state
        }

        let state = shippedState(seed: 7)
        guard case .released(let info) = try #require(state.products.first).stage else {
            Issue.record("expected a released stage")
            return
        }

        #expect(info.reviews.count == 4)
        #expect(info.reviews.map(\.outlet) == balance.reviewOutlets)
        for review in info.reviews {
            #expect(review.score >= balance.reviewFloor)
            #expect(review.score <= balance.reviewCeiling)
            #expect(!review.blurb.isEmpty)
        }

        // averageReviewScore is the rounded mean.
        let mean = Double(info.reviews.map(\.score).reduce(0, +)) / 4.0
        #expect(info.averageReviewScore == Int(mean.rounded()))

        // Deterministic for a fixed seed.
        let rerun = shippedState(seed: 7)
        guard case .released(let rerunInfo) = try #require(rerun.products.first).stage else {
            Issue.record("expected a released stage")
            return
        }
        #expect(rerunInfo.reviews == info.reviews)

        // Reputation nudged from 10 toward the average score.
        let expectedReputation = 10.0 + (Double(info.averageReviewScore) - 10.0) * balance.reputationReviewNudge
        #expect(abs(state.company.reputation - expectedReputation) < 1e-9)
    }

    @Test func averageReviewScoreIsZeroWithoutReviews() {
        let info = ReleaseInfo(launchDay: 0, quality: 50, reviews: [], weeklySales: [], offMarket: false)
        #expect(info.averageReviewScore == 0)
        #expect(info.totalRevenue == 0)
    }
}
