import Foundation
import Testing
import TycoonContent
import TycoonEngine

/// The skill ceiling on quality: a product is only ever as good as the
/// people who built it, and the press expects more from an ambitious kind of
/// product than from a to-do app.
@Suite("Quality skill ceiling")
struct QualityCeilingTests {
    /// A ceiling economy at the shipped numbers (base 0.35).
    static func economy(
        qualityCeilingBase: Double = 0.35,
        expectationPerComplexity: Double = 8
    ) -> BalanceConfig.EconomyBalance {
        var economy = TestBalance.neutralEconomy
        economy.qualityCeilingBase = qualityCeilingBase
        economy.expectationPerComplexity = expectationPerComplexity
        return economy
    }

    /// A state with one full-pool, bug-free product ready to ship, whose
    /// recorded crew skill is exactly `skillIndex`.
    static func readyToShip(
        skillIndex: Double,
        balance: BalanceConfig,
        content: ContentCatalog,
        seed: UInt64 = 11
    ) throws -> (GameState, UUID) {
        var state = GameState.newGame(companyName: "Acme", seed: seed, balance: balance)
        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        let id = try #require(state.products.first?.id)
        state.products[0].stage = .development(DevProgress(
            designPts: 10, codePts: 10, polishPts: 10,
            openBugs: 0, focus: .balanced, hype: 0,
            crewSkillDaySum: skillIndex, crewSkillDays: 1
        ))
        return (state, id)
    }

    static func shippedQuality(skillIndex: Double, base: Double = 0.35) throws -> Double {
        let balance = TestBalance.make(reviewNoiseSigma: 0, economy: economy(qualityCeilingBase: base))
        let content = TestContent.tiny(designPts: 10, codePts: 10, polishPts: 10)
        var (state, id) = try readyToShip(skillIndex: skillIndex, balance: balance, content: content)
        Reducer.apply(.ship(productID: id), to: &state, balance: balance, content: content)
        guard case .released(let info) = try #require(state.products.first).stage else {
            Issue.record("expected a released stage")
            return 0
        }
        return info.quality
    }

    @Test func aBeginnerCrewCannotShipAMasterpiece() throws {
        // ceiling = 0.35 + 0.65 * 0 = 0.35, so full pools cap at 35.
        #expect(abs(try Self.shippedQuality(skillIndex: 0) - 35.0) < 1e-9)
    }

    @Test func theCeilingRisesLinearlyWithCrewSkill() throws {
        // ceiling = 0.35 + 0.65 * 0.5 = 0.675
        #expect(abs(try Self.shippedQuality(skillIndex: 50) - 67.5) < 1e-9)
        // ceiling = 0.35 + 0.65 * 0.85 = 0.9025
        #expect(abs(try Self.shippedQuality(skillIndex: 85) - 90.25) < 1e-9)
    }

    @Test func onlyAWorldClassCrewReachesAHundred() throws {
        #expect(abs(try Self.shippedQuality(skillIndex: 100) - 100.0) < 1e-9)
        #expect(try Self.shippedQuality(skillIndex: 70) < 90)
    }

    @Test func aCeilingBaseOfOneRestoresTheOldFormula() throws {
        #expect(abs(try Self.shippedQuality(skillIndex: 0, base: 1) - 100.0) < 1e-9)
    }

    // MARK: - Recording the crew

    @Test func buildingRecordsThePoolWeightedCrewSkillEveryWorkedDay() throws {
        let balance = TestBalance.make(
            skillGrowthRate: 0, life: TestBalance.quietLife, economy: Self.economy()
        )
        let content = TestContent.tiny(designPts: 500, codePts: 500, polishPts: 500)
        var state = GameState.newGame(companyName: "Acme", seed: 3, balance: balance)
        TestLife.pinPeak(&state)
        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        for _ in 0..<4 {
            Reducer.tick(&state, balance: balance, content: content)
        }

        guard case .development(let dev) = try #require(state.products.first).stage else {
            Issue.record("expected a development stage")
            return
        }
        #expect(dev.crewSkillDays == 4)
        // The lone founder: coding 40, design 30 →
        // 0.35*30 + 0.45*40 + 0.20*35 = 35.5, every day.
        #expect(abs(dev.crewSkillIndex - 35.5) < 1e-9)
    }

    @Test func aProductNobodyEverWorkedHasNoCrewSkill() {
        let dev = DevProgress(
            designPts: 0, codePts: 0, polishPts: 0, openBugs: 0, focus: .balanced, hype: 0
        )
        #expect(dev.crewSkillIndex == 0)
    }

    /// A stronger colleague lifts the recorded index the day they join.
    @Test func aStrongerCrewRaisesTheIndex() throws {
        let balance = TestBalance.make(
            skillGrowthRate: 0, life: TestBalance.quietLife, economy: Self.economy()
        )
        let content = TestContent.tiny(designPts: 500, codePts: 500, polishPts: 500)
        var state = GameState.newGame(companyName: "Acme", seed: 3, balance: balance)
        TestLife.pinPeak(&state)
        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        let productID = try #require(state.products.first?.id)
        state.employees.append(TestPeople.employee(
            coding: 90, design: 90, assignment: .product(productID)
        ))
        Reducer.tick(&state, balance: balance, content: content)

        guard case .development(let dev) = try #require(state.products.first).stage else {
            Issue.record("expected a development stage")
            return
        }
        // means: design (30+90)/2 = 60, coding (40+90)/2 = 65 →
        // 0.35*60 + 0.45*65 + 0.20*62.5 = 62.75
        #expect(abs(dev.crewSkillIndex - 62.75) < 1e-9)
    }

    // MARK: - Expectations by complexity

    @Test func anAmbitiousProductIsHeldToAHigherStandard() throws {
        // The same beginner-built product: expectation is
        // 35 + 0.25·rep + 8·(complexity − 1), and 60% of every point of
        // shortfall comes off the score, so the ambitious one reviews worse.
        let simple = try Self.weakScore(complexity: 1.0)
        let hard = try Self.weakScore(complexity: 1.7)
        #expect(hard < simple, "complex \(hard) should undercut simple \(simple)")
    }

    /// The score a beginner crew gets for a full-pool product of a given
    /// complexity. Quality is ceiling-capped at 41.5, so raising the
    /// expectation past it costs `reviewShortfallPenalty` per point.
    static func weakScore(complexity: Double) throws -> Int {
        let balance = TestBalance.make(
            reviewNoiseSigma: 0,
            reviewExpectationBase: 35,
            reviewExpectationRepFactor: 0.25,
            reviewShortfallPenalty: 0.6,
            economy: economy()
        )
        let content = TestContent.tiny(
            designPts: 10, codePts: 10, polishPts: 10,
            extraProductTypes: [ProductTypeDef(
                id: "beast", name: "Beast", iconSystemName: "hammer",
                designPts: 10, codePts: 10, polishPts: 10,
                unitPrice: 2, marketSize: 1_000, unlockedFromStart: true,
                blurb: "A hard one.", complexity: complexity
            )]
        )
        var state = GameState.newGame(companyName: "Acme", seed: 5, balance: balance)
        Reducer.apply(
            .startProduct(typeID: "beast", topicID: "testing", name: "B", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        let id = try #require(state.products.first?.id)
        state.products[0].stage = .development(DevProgress(
            designPts: 10, codePts: 10, polishPts: 10,
            openBugs: 0, focus: .balanced, hype: 0,
            crewSkillDaySum: 10, crewSkillDays: 1
        ))
        Reducer.apply(.ship(productID: id), to: &state, balance: balance, content: content)
        guard case .released(let info) = try #require(state.products.first).stage else {
            Issue.record("expected a released stage")
            return 0
        }
        return info.averageReviewScore
    }

    // MARK: - Save compatibility

    @Test func devProgressDecodesWithoutTheCrewSkillKeys() throws {
        let json = """
        {"designPts":5,"codePts":6,"polishPts":7,"openBugs":1,\
        "focus":{"design":0.5,"code":0.3,"polish":0.2},"hype":4}
        """
        let dev = try JSONDecoder().decode(DevProgress.self, from: Data(json.utf8))
        #expect(dev.crewSkillDaySum == 0)
        #expect(dev.crewSkillDays == 0)
        #expect(dev.crewSkillIndex == 0)
        #expect(dev.designPts == 5)
    }

    @Test func productTypeDecodesWithoutTheEconomyKeys() throws {
        let json = """
        {"id":"t","name":"T","iconSystemName":"hammer","designPts":1,"codePts":2,\
        "polishPts":3,"unitPrice":1.0,"marketSize":10,"unlockedFromStart":true,"blurb":"b"}
        """
        let type = try JSONDecoder().decode(ProductTypeDef.self, from: Data(json.utf8))
        #expect(type.revenueModel == .oneTime)
        #expect(type.complexity == 1.0)
        #expect(type.hostingCostPerWeek == 0)
    }
}
