import Foundation
import Testing
import TycoonContent
import TycoonEngine

@Suite("Research state")
struct ResearchStateTests {
    @Test func newGameStartsWithEmptyResearchState() {
        let state = GameState.newGame(companyName: "Acme", seed: 7, balance: TestBalance.standard)
        #expect(state.research == ResearchState(
            banked: 0, unlocked: [], activeNodeID: nil, activeProgress: 0
        ))
    }

    @Test func unlockedSetEncodesCanonicallyAndRoundTrips() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        var a = ResearchState(banked: 1.5, unlocked: [], activeNodeID: "x", activeProgress: 2.5)
        a.unlocked.insert("zeta")
        a.unlocked.insert("alpha")
        a.unlocked.insert("mid")

        var b = ResearchState(banked: 1.5, unlocked: [], activeNodeID: "x", activeProgress: 2.5)
        b.unlocked.insert("mid")
        b.unlocked.insert("zeta")
        b.unlocked.insert("alpha")

        let dataA = try encoder.encode(a)
        let dataB = try encoder.encode(b)
        #expect(dataA == dataB)

        let decoded = try JSONDecoder().decode(ResearchState.self, from: dataA)
        #expect(decoded == a)
    }
}

@Suite("Research points")
struct ResearchPointTests {
    private let content = TestContent.tiny(
        techTree: [TestTech.node(id: "big", researchCost: 100, effect: .qualityMultiplier(bonus: 0.05))]
    )

    @Test func researcherRPMatchesFormulaAndAccruesInBanked() throws {
        let balance = TestBalance.make(skillGrowthRate: 0, life: TestBalance.quietLife)
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        TestLife.pinPeak(&state) // founder output multiplier exactly 1
        // Founder stays idle; one researcher with coding 40 / design 80:
        //   rp = 0.5 + 40/40 + 80/80 = 2.5 per day.
        state.employees.append(TestPeople.employee(coding: 40, design: 80, assignment: .research))

        Reducer.tick(&state, balance: balance, content: content)
        #expect(abs(state.research.banked - 2.5) < 1e-9)
        #expect(state.research.activeNodeID == nil)
        #expect(state.research.activeProgress == 0)

        // A second researcher (the founder, coding 40 / design 30) adds
        // 0.5 + 40/40 + 30/80 = 1.875 per day on top.
        let founderID = try #require(state.employees.first).id
        Reducer.apply(
            .assign(employeeID: founderID, to: .research),
            to: &state, balance: balance, content: content
        )
        Reducer.tick(&state, balance: balance, content: content)
        #expect(abs(state.research.banked - (2.5 + 2.5 + 1.875)) < 1e-9)
    }

    @Test func rpFlowsIntoActiveNodeProgressInsteadOfBanked() {
        let balance = TestBalance.make(skillGrowthRate: 0)
        var state = GameState.newGame(companyName: "Acme", seed: 2, balance: balance)
        state.employees.append(TestPeople.employee(coding: 40, design: 80, assignment: .research))

        Reducer.apply(
            .startResearch(nodeID: "big"), to: &state, balance: balance, content: content
        )
        #expect(state.research.activeNodeID == "big")
        #expect(state.research.activeProgress == 0)

        Reducer.tick(&state, balance: balance, content: content)
        #expect(abs(state.research.activeProgress - 2.5) < 1e-9)
        #expect(state.research.banked == 0)
    }

    @Test func noResearchersGenerateNothing() throws {
        let balance = TestBalance.standard
        var state = GameState.newGame(companyName: "Acme", seed: 3, balance: balance)
        state.employees.append(TestPeople.employee())

        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        for _ in 0..<5 { Reducer.tick(&state, balance: balance, content: content) }

        #expect(state.research.banked == 0)
        #expect(state.research.activeProgress == 0)
    }

    @Test func researchDayGrowsCodingAndDesignButNotMarketing() {
        let balance = TestBalance.make(skillGrowthRate: 0.08)
        var state = GameState.newGame(companyName: "Acme", seed: 4, balance: balance)
        let worker = TestPeople.employee(coding: 40, design: 30, marketing: 20, assignment: .research)
        state.employees.append(worker)

        Reducer.tick(&state, balance: balance, content: content)

        let skills = state.employees[1].skills
        #expect(abs(skills.coding - (40 + 0.08 * (1 - 40.0 / 100))) < 1e-9)
        #expect(abs(skills.design - (30 + 0.08 * (1 - 30.0 / 100))) < 1e-9)
        #expect(skills.marketing == 20)
    }

    @Test func rpGenerationIsNotBoostedByDevSpeedTech() {
        let speedContent = TestContent.tiny(
            techTree: [TestTech.node(id: "speed", researchCost: 10, effect: .devSpeedMultiplier(bonus: 0.5))]
        )
        let balance = TestBalance.make(skillGrowthRate: 0)
        var state = GameState.newGame(companyName: "Acme", seed: 5, balance: balance)
        state.research.unlocked.insert("speed")
        state.employees.append(TestPeople.employee(coding: 40, design: 80, assignment: .research))

        Reducer.tick(&state, balance: balance, content: speedContent)
        #expect(abs(state.research.banked - 2.5) < 1e-9)
    }
}

@Suite("startResearch & cancelResearch")
struct StartResearchTests {
    private let content = TestContent.tiny(techTree: [
        TestTech.node(id: "a", researchCost: 20, effect: .qualityMultiplier(bonus: 0.05)),
        TestTech.node(
            id: "b", tier: 2, researchCost: 30, prerequisites: ["a"],
            effect: .devSpeedMultiplier(bonus: 0.10)
        ),
        TestTech.node(
            id: "paid", name: "Paid Node", researchCost: 50, cashCost: 5000,
            effect: .qualityMultiplier(bonus: 0.05)
        ),
    ])
    private let balance = TestBalance.standard

    @Test func guardsIgnoreInvalidStartRequests() {
        var state = GameState.newGame(companyName: "Acme", seed: 10, balance: balance)
        let untouched = state.research

        // Unknown node.
        #expect(Reducer.apply(
            .startResearch(nodeID: "nope"), to: &state, balance: balance, content: content
        ).isEmpty)
        #expect(state.research == untouched)

        // Prerequisite not unlocked.
        #expect(Reducer.apply(
            .startResearch(nodeID: "b"), to: &state, balance: balance, content: content
        ).isEmpty)
        #expect(state.research == untouched)

        // Already unlocked.
        state.research.unlocked.insert("a")
        #expect(Reducer.apply(
            .startResearch(nodeID: "a"), to: &state, balance: balance, content: content
        ).isEmpty)
        #expect(state.research.activeNodeID == nil)

        // Cash short.
        state.company.cash = 4_999
        #expect(Reducer.apply(
            .startResearch(nodeID: "paid"), to: &state, balance: balance, content: content
        ).isEmpty)
        #expect(state.research.activeNodeID == nil)
        #expect(state.company.cash == 4_999)

        #expect(state.eventLog.isEmpty)
        #expect(state.ledger.entries.isEmpty)
    }

    @Test func startDeductsCashPostsLedgerEntryAndEmitsEvent() throws {
        var state = GameState.newGame(companyName: "Acme", seed: 11, balance: balance)

        let events = Reducer.apply(
            .startResearch(nodeID: "paid"), to: &state, balance: balance, content: content
        )

        #expect(events == [.researchStarted(nodeID: "paid", day: 0)])
        #expect(state.eventLog == events)
        #expect(state.company.cash == balance.startingCash - 5000)
        #expect(state.ledger.entries == [
            LedgerEntry(day: 0, amount: -5000, category: .research, label: "Paid Node")
        ])
        #expect(state.research.activeNodeID == "paid")
        #expect(state.research.activeProgress == 0)
    }

    @Test func freeNodePostsNoLedgerEntry() {
        var state = GameState.newGame(companyName: "Acme", seed: 12, balance: balance)

        let events = Reducer.apply(
            .startResearch(nodeID: "a"), to: &state, balance: balance, content: content
        )

        #expect(events == [.researchStarted(nodeID: "a", day: 0)])
        #expect(state.company.cash == balance.startingCash)
        #expect(state.ledger.entries.isEmpty)
    }

    @Test func restartingTheActiveNodeIsIgnoredWithoutSecondCharge() {
        var state = GameState.newGame(companyName: "Acme", seed: 13, balance: balance)

        Reducer.apply(.startResearch(nodeID: "paid"), to: &state, balance: balance, content: content)
        #expect(state.company.cash == balance.startingCash - 5000)

        let again = Reducer.apply(
            .startResearch(nodeID: "paid"), to: &state, balance: balance, content: content
        )
        #expect(again.isEmpty)
        #expect(state.company.cash == balance.startingCash - 5000)
        #expect(state.ledger.entries.count == 1)
        #expect(state.eventLog == [.researchStarted(nodeID: "paid", day: 0)])
    }

    @Test func bankedRPIsPouredIntoTheStartedNode() {
        var state = GameState.newGame(companyName: "Acme", seed: 14, balance: balance)
        state.research.banked = 12.5

        Reducer.apply(.startResearch(nodeID: "a"), to: &state, balance: balance, content: content)

        #expect(state.research.activeNodeID == "a")
        #expect(abs(state.research.activeProgress - 12.5) < 1e-9)
        #expect(state.research.banked == 0)
    }

    @Test func bankedCoveringTheCostCompletesImmediatelyAndKeepsOvershootBanked() {
        var state = GameState.newGame(companyName: "Acme", seed: 15, balance: balance)
        state.research.banked = 25 // node "a" costs 20

        let events = Reducer.apply(
            .startResearch(nodeID: "a"), to: &state, balance: balance, content: content
        )

        #expect(events == [
            .researchStarted(nodeID: "a", day: 0),
            .researchCompleted(nodeID: "a", day: 0),
        ])
        #expect(state.research.unlocked.contains("a"))
        #expect(abs(state.research.banked - 5) < 1e-9)
        #expect(state.research.activeNodeID == nil)
        #expect(state.research.activeProgress == 0)
    }

    @Test func switchingActiveNodesRefundsProgressButNeverCash() {
        var state = GameState.newGame(companyName: "Acme", seed: 16, balance: balance)

        Reducer.apply(.startResearch(nodeID: "paid"), to: &state, balance: balance, content: content)
        state.research.activeProgress = 7 // simulate accrued RP

        let events = Reducer.apply(
            .startResearch(nodeID: "a"), to: &state, balance: balance, content: content
        )

        #expect(events == [.researchStarted(nodeID: "a", day: 0)])
        #expect(state.research.activeNodeID == "a")
        // The 7 refunded points are immediately poured into the new node.
        #expect(abs(state.research.activeProgress - 7) < 1e-9)
        #expect(state.research.banked == 0)
        // The paid node's cash cost is not refunded.
        #expect(state.company.cash == balance.startingCash - 5000)
    }

    @Test func cancelRefundsProgressToBankedAndClearsActive() {
        var state = GameState.newGame(companyName: "Acme", seed: 17, balance: balance)

        Reducer.apply(.startResearch(nodeID: "a"), to: &state, balance: balance, content: content)
        state.research.activeProgress = 7
        state.research.banked = 1

        let events = Reducer.apply(
            .cancelResearch, to: &state, balance: balance, content: content
        )
        #expect(events.isEmpty)
        #expect(abs(state.research.banked - 8) < 1e-9)
        #expect(state.research.activeNodeID == nil)
        #expect(state.research.activeProgress == 0)

        // Cancelling with nothing active is a no-op.
        let frozen = state
        #expect(Reducer.apply(
            .cancelResearch, to: &state, balance: balance, content: content
        ).isEmpty)
        #expect(state == frozen)
        #expect(state.eventLog == [.researchStarted(nodeID: "a", day: 0)])
    }
}

@Suite("Research completion")
struct ResearchCompletionTests {
    @Test func dailyCompletionUnlocksEmitsEventAndRefundsOvershoot() {
        let content = TestContent.tiny(
            techTree: [TestTech.node(id: "cheap", researchCost: 6, effect: .qualityMultiplier(bonus: 0.05))]
        )
        let balance = TestBalance.make(skillGrowthRate: 0)
        var state = GameState.newGame(companyName: "Acme", seed: 20, balance: balance)
        // 2.5 RP/day researcher; the founder stays idle.
        state.employees.append(TestPeople.employee(coding: 40, design: 80, assignment: .research))

        Reducer.apply(.startResearch(nodeID: "cheap"), to: &state, balance: balance, content: content)

        // Days 1-2: 5.0 RP invested, not yet complete.
        Reducer.tick(&state, balance: balance, content: content)
        Reducer.tick(&state, balance: balance, content: content)
        #expect(abs(state.research.activeProgress - 5.0) < 1e-9)
        #expect(state.research.unlocked.isEmpty)

        // Day 3 crosses 6 RP: completed, overshoot 1.5 refunded to banked.
        let events = Reducer.tick(&state, balance: balance, content: content)
        #expect(events.contains(.researchCompleted(nodeID: "cheap", day: 3)))
        #expect(state.eventLog.contains(.researchCompleted(nodeID: "cheap", day: 3)))
        #expect(state.research.unlocked.contains("cheap"))
        #expect(abs(state.research.banked - 1.5) < 1e-9)
        #expect(state.research.activeNodeID == nil)
        #expect(state.research.activeProgress == 0)

        // With nothing active, further RP accrues in banked again.
        Reducer.tick(&state, balance: balance, content: content)
        #expect(abs(state.research.banked - 4.0) < 1e-9)
    }
}

@Suite("Tech effects")
struct TechEffectTests {
    @Test func lockedProductTypeIsRejectedUntilItsNodeIsUnlocked() throws {
        let locked = ProductTypeDef(
            id: "pro", name: "Pro Tool", iconSystemName: "hammer.fill",
            designPts: 10, codePts: 10, polishPts: 10,
            unitPrice: 5, marketSize: 100,
            unlockedFromStart: false, blurb: "Locked behind research."
        )
        let content = TestContent.tiny(
            techTree: [TestTech.node(id: "pro_kit", researchCost: 10, effect: .unlockProductType(id: "pro"))],
            extraProductTypes: [locked]
        )
        let balance = TestBalance.standard
        var state = GameState.newGame(companyName: "Acme", seed: 30, balance: balance)

        #expect(state.isProductTypeUnlocked("tool", content: content)) // unlockedFromStart
        #expect(!state.isProductTypeUnlocked("pro", content: content))

        let rejected = Reducer.apply(
            .startProduct(typeID: "pro", topicID: "testing", name: "Nope", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        #expect(rejected.isEmpty)
        #expect(state.products.isEmpty)

        state.research.unlocked.insert("pro_kit")
        #expect(state.isProductTypeUnlocked("pro", content: content))

        let accepted = Reducer.apply(
            .startProduct(typeID: "pro", topicID: "testing", name: "Yep", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        let product = try #require(state.products.first)
        #expect(accepted == [.productStarted(productID: product.id, day: 0)])
        #expect(product.typeID == "pro")
    }

    @Test func qualityTechMultiplierScalesShipQuality() throws {
        let content = TestContent.tiny(
            designPts: 10, codePts: 10, polishPts: 10,
            techTree: [
                TestTech.node(id: "q1", researchCost: 10, effect: .qualityMultiplier(bonus: 0.10)),
                TestTech.node(id: "q2", researchCost: 10, effect: .qualityMultiplier(bonus: 0.05)),
            ]
        )
        let balance = TestBalance.make(bugChanceBase: 0, reviewNoiseSigma: 0)
        var state = GameState.newGame(companyName: "Acme", seed: 31, balance: balance)
        state.research.unlocked = ["q1", "q2"]
        #expect(abs(state.qualityTechMultiplier(content: content) - 1.15) < 1e-9)

        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        let id = try #require(state.products.first?.id)
        // Hand-crafted pools: completion = 0.35*0.5 + 0.45*0.6 + 0.20*0.4 = 0.525.
        state.products[0].stage = .development(DevProgress(
            designPts: 5, codePts: 6, polishPts: 4,
            openBugs: 0, focus: .balanced, hype: 0
        ))
        Reducer.apply(.ship(productID: id), to: &state, balance: balance, content: content)

        guard case .released(let info) = try #require(state.products.first).stage else {
            Issue.record("expected a released stage")
            return
        }
        // quality = 100 * 0.525 * 1.0 (fit) * 1.0 (no bugs) * 1.15 = 60.375.
        #expect(abs(info.quality - 100 * 0.525 * 1.15) < 1e-9)
    }

    @Test func qualityTechMultiplierIsCappedWithManyNodes() throws {
        let manyNodes = (0..<15).map {
            TestTech.node(id: "q\($0)", researchCost: 10, effect: .qualityMultiplier(bonus: 0.05))
        }
        let content = TestContent.tiny(
            designPts: 10, codePts: 10, polishPts: 10, techTree: manyNodes
        )
        let balance = TestBalance.make(bugChanceBase: 0, reviewNoiseSigma: 0)
        var state = GameState.newGame(companyName: "Acme", seed: 32, balance: balance)
        state.research.unlocked = Set(manyNodes.map(\.id))

        // 1 + 15 * 0.05 = 1.75, capped at techQualityMultiplierCap (1.5).
        #expect(state.qualityTechMultiplier(content: content) == 1.5)

        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        let id = try #require(state.products.first?.id)
        state.products[0].stage = .development(DevProgress(
            designPts: 5, codePts: 6, polishPts: 4,
            openBugs: 0, focus: .balanced, hype: 0
        ))
        Reducer.apply(.ship(productID: id), to: &state, balance: balance, content: content)

        guard case .released(let info) = try #require(state.products.first).stage else {
            Issue.record("expected a released stage")
            return
        }
        #expect(abs(info.quality - 100 * 0.525 * 1.5) < 1e-9)
    }

    @Test func devSpeedTechMultiplierScalesDailyPoolOutputExactly() throws {
        let content = TestContent.tiny(
            designPts: 100, codePts: 100, polishPts: 100,
            techTree: [TestTech.node(id: "speed", researchCost: 10, effect: .devSpeedMultiplier(bonus: 0.25))]
        )
        let balance = TestBalance.make(bugChanceBase: 0, skillGrowthRate: 0, life: TestBalance.quietLife)
        var state = GameState.newGame(companyName: "Acme", seed: 33, balance: balance)
        TestLife.pinPeak(&state) // founder output multiplier exactly 1
        state.research.unlocked.insert("speed")
        #expect(abs(state.devSpeedTechMultiplier(content: content) - 1.25) < 1e-9)

        Reducer.apply(
            .startProduct(
                typeID: "tool", topicID: "testing", name: "T",
                focus: PhaseFocus(design: 0.5, code: 0.3, polish: 0.2)
            ),
            to: &state, balance: balance, content: content
        )
        Reducer.tick(&state, balance: balance, content: content)

        guard case .development(let dev) = try #require(state.products.first).stage else {
            Issue.record("expected a development stage")
            return
        }
        // The auto-assigned founder's plain daily yields (design 1.1,
        // code 0.78, polish 0.48) each gain the exact x1.25 boost.
        #expect(abs(dev.designPts - 1.1 * 1.25) < 1e-9)
        #expect(abs(dev.codePts - 0.78 * 1.25) < 1e-9)
        #expect(abs(dev.polishPts - 0.48 * 1.25) < 1e-9)
    }

    @Test func devSpeedTechMultiplierHasNoCap() {
        let manyNodes = (0..<10).map {
            TestTech.node(id: "s\($0)", researchCost: 10, effect: .devSpeedMultiplier(bonus: 0.15))
        }
        let content = TestContent.tiny(techTree: manyNodes)
        var state = GameState.newGame(companyName: "Acme", seed: 34, balance: TestBalance.standard)
        state.research.unlocked = Set(manyNodes.map(\.id))

        #expect(abs(state.devSpeedTechMultiplier(content: content) - 2.5) < 1e-9)
    }

    @Test func campaignKindUnlockFeedsIsCampaignKindUnlocked() {
        let content = TestContent.tiny(
            techTree: [TestTech.node(
                id: "press_kit", researchCost: 10,
                effect: .unlockCampaignKind(id: "press_release")
            )]
        )
        var state = GameState.newGame(companyName: "Acme", seed: 35, balance: TestBalance.standard)

        #expect(!state.isCampaignKindUnlocked("press_release", content: content))
        state.research.unlocked.insert("press_kit")
        #expect(state.isCampaignKindUnlocked("press_release", content: content))
        #expect(!state.isCampaignKindUnlocked("launch_event", content: content))
    }

    @Test func multipliersAreOneWithNothingUnlocked() {
        let content = TestContent.bundled
        let state = GameState.newGame(companyName: "Acme", seed: 36, balance: TestBalance.standard)

        #expect(state.qualityTechMultiplier(content: content) == 1.0)
        #expect(state.devSpeedTechMultiplier(content: content) == 1.0)
    }
}
