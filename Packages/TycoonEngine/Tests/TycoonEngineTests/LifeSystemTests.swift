import Foundation
import Testing
import TycoonContent
import TycoonEngine

/// A balance where nothing but the life system touches the RNG, cash, or
/// the ledger on the days under test: candidate and contract-offer
/// refreshes and random events are pushed past every test window.
private func lifeBalance(
    weeklyOperatingCost: Int = 400,
    bugChanceBase: Double = 0,
    skillGrowthRate: Double = 0,
    life: BalanceConfig.LifeBalance = TestBalance.quietLife
) -> BalanceConfig {
    TestBalance.make(
        weeklyOperatingCost: weeklyOperatingCost,
        bugChanceBase: bugChanceBase,
        skillGrowthRate: skillGrowthRate,
        candidateRefreshDays: 10_000,
        contractOfferRefreshDays: 10_000,
        eventCheckIntervalDays: 10_000,
        life: life
    )
}

private func near(_ value: Double, _ expected: Double) -> Bool {
    abs(value - expected) < 1e-9
}

private func devProgress(_ state: GameState) throws -> DevProgress {
    guard case .development(let dev) = try #require(state.productInDevelopment).stage else {
        Issue.record("expected a product in development")
        throw CancellationError()
    }
    return dev
}

// MARK: - Life state

@Suite("Life state")
struct LifeStateTests {
    @Test func newGameSeedsTheDefaultLife() {
        let balance = TestBalance.standard
        let state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        let life = state.life

        #expect(life.meters == LifeMeters(energy: 80, health: 80, mood: 70, relationships: 50))
        #expect(life.schedule == .normal)
        #expect(life.plannedActivity == .rest)
        #expect(life.wallet == balance.life.startingWallet)
        #expect(life.wallet == 2_000)
        #expect(life.founderSalary == balance.life.defaultFounderSalary)
        #expect(life.founderSalary == 0)
        #expect(life.home == .studioFlat)
        #expect(life.family == FamilyState(
            stage: .single, stageSinceDay: 0, partnerName: nil, partnerAppearanceSeed: nil,
            children: [], lastChildDay: nil
        ))
        #expect(life.awayUntilDay == nil)
        #expect(life.awayReason == nil)
        #expect(life.coldUntilDay == nil)
        #expect(life.lowRelationshipStreakDays == 0)
        #expect(!life.isAway(day: 0))
        #expect(!life.hasCold(day: 0))
    }

    @Test func awayAndColdWindowsAreHalfOpen() {
        var life = GameState.newGame(companyName: "Acme", seed: 1, balance: TestBalance.standard).life
        life.awayUntilDay = 10
        life.coldUntilDay = 5
        #expect(life.isAway(day: 3))
        #expect(life.isAway(day: 9))
        #expect(!life.isAway(day: 10))
        #expect(life.hasCold(day: 4))
        #expect(!life.hasCold(day: 5))
    }

    @Test func laddersAndMetadata() {
        #expect(WorkSchedule.allCases == [.chill, .normal, .crunch])
        #expect(WeekendActivity.allCases == [
            .rest, .gym, .dateNight, .friends, .hobby, .familyTime, .vacation, .doctor,
        ])
        #expect(RelationshipStage.allCases == [.single, .dating, .partner, .married])
        #expect(RelationshipStage.single.next == .dating)
        #expect(RelationshipStage.dating.next == .partner)
        #expect(RelationshipStage.partner.next == .married)
        #expect(RelationshipStage.married.next == nil)
        #expect(HomeTier.allCases == [.studioFlat, .apartment, .house, .penthouse])
        #expect(HomeTier.studioFlat.next == .apartment)
        #expect(HomeTier.apartment.next == .house)
        #expect(HomeTier.house.next == .penthouse)
        #expect(HomeTier.penthouse.next == nil)
        #expect(HomeTier.studioFlat.displayName == "Studio Flat")
        #expect(HomeTier.apartment.displayName == "Apartment")
        #expect(HomeTier.house.displayName == "House")
        #expect(HomeTier.penthouse.displayName == "Penthouse")
    }

    @Test func lifeRoundTripsThroughGameStateJSON() throws {
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: TestBalance.standard)
        state.life.schedule = .crunch
        state.life.plannedActivity = .gym
        state.life.wallet = -300
        state.life.founderSalary = 900
        state.life.home = .house
        TestLife.setPartner(&state, stage: .married, sinceDay: 40)
        state.life.family.children = [TestLife.child(name: "Kit", bornDay: 90)]
        state.life.family.lastChildDay = 90
        state.life.awayUntilDay = 120
        state.life.awayReason = "Vacation"
        state.life.coldUntilDay = 115
        state.life.lowRelationshipStreakDays = 3

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(state)
        let decoded = try JSONDecoder().decode(GameState.self, from: data)
        #expect(decoded == state)
        #expect(try encoder.encode(decoded) == data)
    }

    @Test func savesWithoutALifeBlockStillLoad() throws {
        let state = GameState.newGame(companyName: "Acme", seed: 1, balance: TestBalance.standard)
        let data = try JSONEncoder().encode(state)
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["life"] = nil
        let stripped = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(GameState.self, from: stripped)
        #expect(decoded.life.meters == LifeMeters(energy: 80, health: 80, mood: 70, relationships: 50))
        #expect(decoded.life.wallet == 0)
        #expect(decoded.life.founderSalary == 0)
        #expect(decoded.life.family.stage == .single)
    }
}

// MARK: - Meter drift

@Suite("Life meter drift")
struct LifeDriftTests {
    private let content = TestContent.tiny()
    /// Real drift, no life events; six ticks stay clear of the weekly day.
    private let balance = lifeBalance(life: TestBalance.life(lifeEventIntervalDays: 10_000))

    @Test func driftPerScheduleIsExact() {
        let expectations: [(WorkSchedule, energy: Double, health: Double, mood: Double, rel: Double)] = [
            (.chill, 1.5, 0.3, 0.5, 0.3),
            (.normal, -0.4, -0.2, 0, -0.3),
            (.crunch, -2.0, -0.8, -0.6, -1.2),
        ]
        for (schedule, energy, health, mood, rel) in expectations {
            var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
            state.life.schedule = schedule
            for _ in 0..<6 { Reducer.tick(&state, balance: balance, content: content) }
            let meters = state.life.meters
            #expect(near(meters.energy, 80 + 6 * energy), "\(schedule) energy")
            #expect(near(meters.health, 80 + 6 * health), "\(schedule) health")
            #expect(near(meters.mood, 70 + 6 * mood), "\(schedule) mood")
            #expect(near(meters.relationships, 50 + 6 * rel), "\(schedule) relationships")
        }
    }

    @Test func stageDrainChildrenHomeBonusAndDebtStackOnTopOfSchedule() {
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        TestLife.setPartner(&state, stage: .married)
        state.life.family.children = [TestLife.child(name: "Kit"), TestLife.child(name: "Juno")]
        state.life.home = .house
        state.life.wallet = -1

        Reducer.tick(&state, balance: balance, content: content)

        // normal drift + married −0.4 rel + 2 × child (−0.3 energy, +0.2
        // mood, +0.1 rel) + house mood +0.2 + debt mood −1.
        let meters = state.life.meters
        #expect(near(meters.energy, 80 - 0.4 - 0.6))
        #expect(near(meters.health, 80 - 0.2))
        #expect(near(meters.mood, 70 + 0 + 0.4 + 0.2 - 1))
        #expect(near(meters.relationships, 50 - 0.3 - 0.4 + 0.2))
    }

    @Test func eachStageHasItsOwnDrain() {
        for (stage, drain) in [(RelationshipStage.dating, 0.2), (.partner, 0.3), (.married, 0.4)] {
            var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
            TestLife.setPartner(&state, stage: stage)
            Reducer.tick(&state, balance: balance, content: content)
            #expect(near(state.life.meters.relationships, 50 - 0.3 - drain), "\(stage)")
        }
    }

    @Test func penthouseMoodBonus() {
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        state.life.home = .penthouse
        Reducer.tick(&state, balance: balance, content: content)
        #expect(near(state.life.meters.mood, 70.5))
    }

    @Test func metersClampToTheirBounds() {
        // Ceiling: chill drift on full meters stays pinned at 100.
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        state.life.schedule = .chill
        state.life.meters = LifeMeters(energy: 100, health: 100, mood: 100, relationships: 100)
        for _ in 0..<6 { Reducer.tick(&state, balance: balance, content: content) }
        #expect(state.life.meters == LifeMeters(energy: 100, health: 100, mood: 100, relationships: 100))

        // Floor: crunch drift on near-empty meters stops at 0 (thresholds
        // disabled so burnout / hospital don't intervene).
        let noThresholds = lifeBalance(life: TestBalance.life(
            burnoutEnergyThreshold: -1, hospitalHealthThreshold: -1, lifeEventIntervalDays: 10_000
        ))
        state = GameState.newGame(companyName: "Acme", seed: 1, balance: noThresholds)
        state.life.schedule = .crunch
        state.life.meters = LifeMeters(energy: 1, health: 0.5, mood: 0.1, relationships: 0)
        Reducer.tick(&state, balance: noThresholds, content: content)
        #expect(state.life.meters == LifeMeters(energy: 0, health: 0, mood: 0, relationships: 0))
    }

    @Test func anAwayFounderRestsOnChillDriftRegardlessOfSchedule() {
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        state.life.schedule = .crunch
        state.life.awayUntilDay = 100
        Reducer.tick(&state, balance: balance, content: content)
        #expect(near(state.life.meters.energy, 81.5))
        #expect(near(state.life.meters.health, 80.3))
        #expect(near(state.life.meters.mood, 70.5))
        #expect(near(state.life.meters.relationships, 50.3))
    }
}

// MARK: - Founder output

@Suite("Founder output multiplier")
struct FounderOutputTests {
    private let balance = lifeBalance()
    private let content = TestContent.tiny(designPts: 1_000, codePts: 1_000, polishPts: 1_000)

    private func started(seed: UInt64 = 1, focus: PhaseFocus = PhaseFocus(design: 0.5, code: 0.3, polish: 0.2)) -> GameState {
        var state = GameState.newGame(companyName: "Acme", seed: seed, balance: balance)
        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: focus),
            to: &state, balance: balance, content: content
        )
        return state
    }

    @Test func multiplierMatchesTheFormula() {
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        // wellbeing = (0.4·50 + 0.3·50 + 0.3·50)/100 = 0.5 → 0.5 + 0.5·0.5 = 0.75
        state.life.meters = LifeMeters(energy: 50, health: 50, mood: 50, relationships: 0)
        #expect(near(state.founderOutputMultiplier(balance: balance), 0.75))
        state.life.schedule = .crunch
        #expect(near(state.founderOutputMultiplier(balance: balance), 0.975))
        state.life.schedule = .chill
        #expect(near(state.founderOutputMultiplier(balance: balance), 0.6))
        state.life.coldUntilDay = 10
        #expect(near(state.founderOutputMultiplier(balance: balance), 0.36))
        state.life.awayUntilDay = 10
        #expect(state.founderOutputMultiplier(balance: balance) == 0)

        // The shipped starting meters (80/80/70) give 0.885 on a normal week.
        let fresh = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        #expect(near(fresh.founderOutputMultiplier(balance: balance), 0.885))
        // Meters weigh 0.4 / 0.3 / 0.3: energy matters most.
        var lopsided = fresh
        lopsided.life.meters = LifeMeters(energy: 100, health: 0, mood: 0, relationships: 0)
        #expect(near(lopsided.founderOutputMultiplier(balance: balance), 0.7))
    }

    @Test func productOutputScalesByTheMultiplier() throws {
        var state = started()
        state.life.meters = LifeMeters(energy: 50, health: 50, mood: 50, relationships: 0)

        Reducer.tick(&state, balance: balance, content: content)

        // Founder (coding 40, design 30), focus 0.5/0.3/0.2, × 0.75:
        let dev = try devProgress(state)
        #expect(near(dev.designPts, 0.75 * 0.5 * 2.2))
        #expect(near(dev.codePts, 0.75 * 0.3 * 2.6))
        #expect(near(dev.polishPts, 0.75 * 0.2 * 2.4))
    }

    @Test func crunchAndChillScheduleFactors() throws {
        var state = started()
        TestLife.pinPeak(&state)
        state.life.schedule = .crunch
        Reducer.tick(&state, balance: balance, content: content)
        var dev = try devProgress(state)
        #expect(near(dev.designPts, 1.3 * 1.1))
        #expect(near(dev.codePts, 1.3 * 0.78))
        #expect(near(dev.polishPts, 1.3 * 0.48))

        state = started()
        TestLife.pinPeak(&state)
        state.life.schedule = .chill
        Reducer.tick(&state, balance: balance, content: content)
        dev = try devProgress(state)
        #expect(near(dev.designPts, 0.8 * 1.1))
        #expect(near(dev.codePts, 0.8 * 0.78))
        #expect(near(dev.polishPts, 0.8 * 0.48))
    }

    @Test func aColdCutsOutputUntilItExpires() throws {
        var state = started()
        TestLife.pinPeak(&state)
        state.life.coldUntilDay = 2

        Reducer.tick(&state, balance: balance, content: content) // day 1: cold
        var dev = try devProgress(state)
        #expect(near(dev.designPts, 0.6 * 1.1))
        #expect(near(dev.codePts, 0.6 * 0.78))

        Reducer.tick(&state, balance: balance, content: content) // day 2: cleared first thing
        #expect(state.life.coldUntilDay == nil)
        dev = try devProgress(state)
        #expect(near(dev.designPts, 0.6 * 1.1 + 1.1))
        #expect(near(dev.codePts, 0.6 * 0.78 + 0.78))
    }

    @Test func anAwayFounderProducesNothingButKeepsAssignmentAndCountsForHeadcount() throws {
        let growing = lifeBalance(skillGrowthRate: 0.08)
        var state = started()
        let productID = try #require(state.productInDevelopment?.id)
        state.life.awayUntilDay = 10

        for _ in 0..<3 { Reducer.tick(&state, balance: growing, content: content) }

        let dev = try devProgress(state)
        #expect(dev.designPts == 0)
        #expect(dev.codePts == 0)
        #expect(dev.polishPts == 0)
        let founder = try #require(state.employees.first)
        #expect(founder.assignment == .product(productID))
        #expect(founder.skills == SkillSet(coding: 40, design: 30, marketing: 20))
        #expect(state.headcount == 1)
    }

    @Test func otherEmployeesAreNeverScaled() throws {
        var state = started()
        state.life.meters = LifeMeters(energy: 50, health: 50, mood: 50, relationships: 0)
        let productID = try #require(state.productInDevelopment?.id)
        state.employees.append(TestPeople.employee(coding: 50, design: 25, assignment: .product(productID)))

        Reducer.tick(&state, balance: balance, content: content)

        // Founder × 0.75 plus an unscaled worker (design 1.0, code 0.9, polish 0.5).
        let dev = try devProgress(state)
        #expect(near(dev.designPts, 0.75 * 1.1 + 1.0))
        #expect(near(dev.codePts, 0.75 * 0.78 + 0.9))
        #expect(near(dev.polishPts, 0.75 * 0.48 + 0.5))
    }

    @Test func contractOutputScalesAndStopsWhileAway() throws {
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        TestLife.pinPeak(&state)
        state.life.schedule = .crunch
        let job = ContractJob(
            id: UUID(), clientName: "TestCo", requiredCodePts: 500, requiredDesignPts: 500,
            progressCode: 0, progressDesign: 0, deadlineDay: 100, payout: 100, penalty: 10, acceptedDay: 0
        )
        state.activeContracts = [job]
        let founderID = try #require(state.employees.first).id
        Reducer.apply(.assign(employeeID: founderID, to: .contract(job.id)), to: &state, balance: balance, content: content)

        Reducer.tick(&state, balance: balance, content: content)
        var updated = try #require(state.activeContract(id: job.id))
        #expect(near(updated.progressCode, 1.3 * 2.6))
        #expect(near(updated.progressDesign, 1.3 * 2.2))

        state.life.awayUntilDay = 10
        Reducer.tick(&state, balance: balance, content: content)
        updated = try #require(state.activeContract(id: job.id))
        #expect(near(updated.progressCode, 1.3 * 2.6))
        #expect(near(updated.progressDesign, 1.3 * 2.2))
        #expect(try #require(state.employees.first).assignment == .contract(job.id))
    }

    @Test func researchOutputScalesAndStopsWhileAway() throws {
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        TestLife.pinPeak(&state)
        state.life.schedule = .chill
        let founderID = try #require(state.employees.first).id
        Reducer.apply(.assign(employeeID: founderID, to: .research), to: &state, balance: balance, content: content)

        Reducer.tick(&state, balance: balance, content: content)
        // Founder RP 0.5 + 40/40 + 30/80 = 1.875, × 0.8.
        #expect(near(state.research.banked, 0.8 * 1.875))

        state.life.awayUntilDay = 10
        Reducer.tick(&state, balance: balance, content: content)
        #expect(near(state.research.banked, 0.8 * 1.875))
    }

    @Test func bugChanceMultiplierMatchesTheFormula() {
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        state.life.meters.energy = 0
        #expect(near(state.founderBugChanceMultiplier(balance: balance), 1.5))
        state.life.meters.energy = 15
        #expect(near(state.founderBugChanceMultiplier(balance: balance), 1.25))
        state.life.meters.energy = 30
        #expect(state.founderBugChanceMultiplier(balance: balance) == 1)
        state.life.meters.energy = 80
        #expect(state.founderBugChanceMultiplier(balance: balance) == 1)
    }

    @Test func lowEnergyFounderBugsEveryCodePointWhenTheScaledChanceReachesOne() throws {
        // base 1.0 × (1 − 40/120) = 2/3; × 1.5 at energy 0 = 1.0: every
        // completed code point rolls a bug. Burnout is disabled so the
        // zero-energy founder keeps working.
        let buggy = lifeBalance(bugChanceBase: 1.0, life: TestBalance.life(
            chillDrift: .zero, normalDrift: .zero, crunchDrift: .zero,
            stageRelationshipDrain: [:], childDrift: .zero,
            burnoutEnergyThreshold: -1, lifeEventIntervalDays: 10_000
        ))
        var state = GameState.newGame(companyName: "Acme", seed: 5, balance: buggy)
        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: PhaseFocus(design: 0, code: 1, polish: 0)),
            to: &state, balance: buggy, content: content
        )
        state.life.meters = LifeMeters(energy: 0, health: 100, mood: 100, relationships: 0)

        for _ in 0..<5 { Reducer.tick(&state, balance: buggy, content: content) }
        let dev = try devProgress(state)
        #expect(dev.openBugs == Int(dev.codePts))
        #expect(dev.openBugs > 0)

        // At full energy the multiplier is 1 and the 2/3 chance is rolled
        // exactly as before: replay the draws from a probe generator.
        state = GameState.newGame(companyName: "Acme", seed: 5, balance: buggy)
        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: PhaseFocus(design: 0, code: 1, polish: 0)),
            to: &state, balance: buggy, content: content
        )
        TestLife.pinPeak(&state)
        var probe = state.rng
        Reducer.tick(&state, balance: buggy, content: content)
        let rested = try devProgress(state)
        var expectedBugs = 0
        for _ in 0..<Int(rested.codePts) where Double(probe.next() >> 11) * 0x1.0p-53 < 2.0 / 3.0 {
            expectedBugs += 1
        }
        #expect(rested.openBugs == expectedBugs)
        #expect(state.rng == probe)
    }
}

// MARK: - Burnout, hospital, breakup

@Suite("Burnout and hospital")
struct BurnoutHospitalTests {
    private let content = TestContent.tiny(designPts: 1_000, codePts: 1_000, polishPts: 1_000)
    private let balance = lifeBalance(life: TestBalance.life(lifeEventIntervalDays: 10_000))

    @Test func burnoutSendsTheFounderAwayResetsEnergyAndComesBack() throws {
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        state.life.meters.energy = 10 // 9.6 after today's drift
        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: .balanced),
            to: &state, balance: balance, content: content
        )

        let day1 = Reducer.tick(&state, balance: balance, content: content)
        #expect(day1 == [.founderAway(reason: "Burnout", untilDay: 8, day: 1)])
        #expect(state.life.awayUntilDay == 8)
        #expect(state.life.awayReason == "Burnout")
        #expect(state.life.meters.energy == 50)
        #expect(state.life.isAway(day: 1))
        // Away from the first system of the day: nothing was produced.
        #expect(try devProgress(state).codePts == 0)

        for _ in 0..<6 { Reducer.tick(&state, balance: balance, content: content) } // days 2-7
        #expect(state.life.isAway(day: 7))
        #expect(near(state.life.meters.energy, 50 + 6 * 1.5)) // resting on chill drift
        #expect(try devProgress(state).codePts == 0)

        let day8 = Reducer.tick(&state, balance: balance, content: content)
        #expect(day8.contains(.founderBack(day: 8)))
        #expect(!state.life.isAway(day: 8))
        #expect(state.life.awayUntilDay == nil)
        #expect(state.life.awayReason == nil)
        #expect(near(state.life.meters.energy, 59 - 0.4))
        #expect(try devProgress(state).codePts > 0)
    }

    @Test func hospitalSendsTheFounderAwayBillsTheWalletAndResetsHealth() {
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        state.life.meters.health = 5 // 4.8 after today's drift

        let day1 = Reducer.tick(&state, balance: balance, content: content)
        #expect(day1 == [.founderAway(reason: "Hospital", untilDay: 15, day: 1)])
        #expect(state.life.awayUntilDay == 15)
        #expect(state.life.awayReason == "Hospital")
        #expect(state.life.meters.health == 40)
        #expect(state.life.wallet == 2_000 - 5_000)

        for _ in 0..<13 { Reducer.tick(&state, balance: balance, content: content) } // days 2-14
        #expect(state.life.isAway(day: 14))
        let day15 = Reducer.tick(&state, balance: balance, content: content)
        #expect(day15.contains(.founderBack(day: 15)))
        #expect(!state.life.isAway(day: 15))
    }

    @Test func burnoutWinsWhenBothThresholdsTripOnTheSameDay() {
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        state.life.meters.energy = 10
        state.life.meters.health = 5

        let day1 = Reducer.tick(&state, balance: balance, content: content)
        #expect(day1 == [.founderAway(reason: "Burnout", untilDay: 8, day: 1)])
        #expect(near(state.life.meters.health, 4.8))
        #expect(state.life.wallet == 2_000)
    }

    @Test func thresholdsNeverRetriggerWhileAlreadyAway() {
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        state.life.meters.energy = 10
        state.life.meters.health = 5
        state.life.awayUntilDay = 50
        state.life.awayReason = "Vacation"

        let events = Reducer.tick(&state, balance: balance, content: content)
        #expect(events.isEmpty)
        #expect(state.life.awayUntilDay == 50)
        #expect(state.life.awayReason == "Vacation")
        #expect(near(state.life.meters.energy, 11.5))
        #expect(near(state.life.meters.health, 5.3))
        #expect(state.life.wallet == 2_000)
    }
}

@Suite("Breakup streak")
struct BreakupTests {
    private let content = TestContent.tiny()
    private let balance = lifeBalance()

    @Test func fourteenConsecutiveLowDaysEndTheRelationshipButKeepTheChildren() {
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        TestLife.setPartner(&state, stage: .married, sinceDay: 0)
        state.life.family.children = [TestLife.child(name: "Kit")]
        state.life.meters.relationships = 5

        for day in 1...13 {
            let events = Reducer.tick(&state, balance: balance, content: content)
            #expect(!events.contains(.breakup(day: day)))
            #expect(state.life.lowRelationshipStreakDays == day, "day \(day)")
            #expect(state.life.family.stage == .married)
        }

        let day14 = Reducer.tick(&state, balance: balance, content: content)
        #expect(day14.contains(.breakup(day: 14)))
        #expect(state.life.family.stage == .single)
        #expect(state.life.family.stageSinceDay == 14)
        #expect(state.life.family.partnerName == nil)
        #expect(state.life.family.partnerAppearanceSeed == nil)
        #expect(state.life.family.children.count == 1)
        #expect(state.life.meters.mood == 70 + 2 * 5 - 25) // two rest weekends, then the breakup
        #expect(state.life.lowRelationshipStreakDays == 0)
    }

    @Test func recoveringAboveTheThresholdResetsTheStreak() {
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        TestLife.setPartner(&state, stage: .dating)
        state.life.meters.relationships = 5

        for _ in 0..<5 { Reducer.tick(&state, balance: balance, content: content) }
        #expect(state.life.lowRelationshipStreakDays == 5)

        state.life.meters.relationships = 15 // not strictly below the threshold
        Reducer.tick(&state, balance: balance, content: content)
        #expect(state.life.lowRelationshipStreakDays == 0)
        #expect(state.life.family.stage == .dating)
    }

    @Test func aSingleFounderNeverAccumulatesAStreak() {
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        state.life.meters.relationships = 0
        for _ in 0..<20 { Reducer.tick(&state, balance: balance, content: content) }
        #expect(state.life.lowRelationshipStreakDays == 0)
        #expect(state.life.family.stage == .single)
        #expect(!state.eventLog.contains { if case .breakup = $0 { return true } else { return false } })
    }

    @Test func breakupMoodPenaltyClampsAtZero() {
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        TestLife.setPartner(&state, stage: .dating)
        state.life.meters.relationships = 0
        state.life.meters.mood = 10
        state.life.plannedActivity = .gym // no weekend mood to muddy the clamp
        for _ in 0..<14 { Reducer.tick(&state, balance: balance, content: content) }
        #expect(state.life.family.stage == .single)
        #expect(state.life.meters.mood == 0)
    }
}

// MARK: - Weekly flows

@Suite("Weekly life flows")
struct WeeklyLifeTests {
    private let content = TestContent.tiny()
    private let balance = lifeBalance()

    private func weekendEvents(_ events: [GameEvent]) -> [GameEvent] {
        events.filter { if case .weekendSpent = $0 { return true } else { return false } }
    }

    @Test func founderSalaryMovesCompanyCashIntoTheWalletAndPostsPayroll() throws {
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        Reducer.apply(.setFounderSalary(500), to: &state, balance: balance, content: content)

        for _ in 0..<6 { Reducer.tick(&state, balance: balance, content: content) }
        #expect(state.company.cash == balance.startingCash)
        #expect(state.life.wallet == 2_000)

        Reducer.tick(&state, balance: balance, content: content) // day 7
        #expect(state.company.cash == balance.startingCash - 500 - balance.weeklyOperatingCost)
        #expect(state.life.wallet == 2_000 + 500 - 120)
        let salaryEntry = try #require(state.ledger.entries.first)
        #expect(salaryEntry == LedgerEntry(day: 7, amount: -500, category: .payroll, label: "Founder salary"))
        #expect(state.ledger.entries.count == 2) // + operating costs
    }

    @Test func aZeroSalaryPostsNothing() {
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        for _ in 0..<7 { Reducer.tick(&state, balance: balance, content: content) }
        #expect(state.company.cash == balance.startingCash - balance.weeklyOperatingCost)
        #expect(state.ledger.entries.allSatisfy { $0.category != .payroll })
    }

    @Test func rentAndChildCostsDebitTheWalletWeekly() {
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        state.life.home = .house
        state.life.family.children = [TestLife.child(name: "Kit"), TestLife.child(name: "Juno")]

        for _ in 0..<14 { Reducer.tick(&state, balance: balance, content: content) }
        #expect(state.life.wallet == 2_000 - 2 * (700 + 2 * 80))
        #expect(state.company.cash == balance.startingCash - 2 * balance.weeklyOperatingCost)
    }

    @Test func eachActivityAppliesItsEffectsAndCost() throws {
        struct Case {
            var activity: WeekendActivity
            var energy: Double, health: Double, mood: Double, rel: Double
            var cost: Int
        }
        let cases = [
            Case(activity: .rest, energy: 15, health: 0, mood: 5, rel: 0, cost: 0),
            Case(activity: .gym, energy: -3, health: 12, mood: 0, rel: 0, cost: 60),
            Case(activity: .dateNight, energy: 0, health: 0, mood: 8, rel: 15, cost: 120),
            Case(activity: .friends, energy: 0, health: 0, mood: 10, rel: 8, cost: 80),
            Case(activity: .hobby, energy: 0, health: 0, mood: 15, rel: 0, cost: 50),
            Case(activity: .familyTime, energy: 0, health: 0, mood: 6, rel: 12, cost: 40),
            Case(activity: .doctor, energy: 0, health: 15, mood: 0, rel: 0, cost: 200),
        ]
        for c in cases {
            var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
            TestLife.setPartner(&state, stage: .married)
            state.life.meters = LifeMeters(energy: 50, health: 50, mood: 50, relationships: 50)
            Reducer.apply(.planWeekend(c.activity), to: &state, balance: balance, content: content)
            #expect(state.life.plannedActivity == c.activity)

            for _ in 0..<6 { Reducer.tick(&state, balance: balance, content: content) }
            #expect(state.life.meters == LifeMeters(energy: 50, health: 50, mood: 50, relationships: 50), "\(c.activity)")

            let day7 = Reducer.tick(&state, balance: balance, content: content)
            #expect(weekendEvents(day7) == [.weekendSpent(activity: c.activity, day: 7)], "\(c.activity)")
            #expect(near(state.life.meters.energy, 50 + c.energy), "\(c.activity) energy")
            #expect(near(state.life.meters.health, 50 + c.health), "\(c.activity) health")
            #expect(near(state.life.meters.mood, 50 + c.mood), "\(c.activity) mood")
            #expect(near(state.life.meters.relationships, 50 + c.rel), "\(c.activity) relationships")
            #expect(state.life.wallet == 2_000 - 120 - c.cost, "\(c.activity) cost")
            #expect(state.life.plannedActivity == c.activity, "\(c.activity) persists")
            #expect(state.life.awayUntilDay == nil)
        }
    }

    @Test func activityEffectsClampAtOneHundred() {
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        state.life.meters = LifeMeters(energy: 95, health: 50, mood: 99, relationships: 50)
        for _ in 0..<7 { Reducer.tick(&state, balance: balance, content: content) }
        #expect(state.life.meters.energy == 100)
        #expect(state.life.meters.mood == 100)
    }

    @Test func vacationSendsTheFounderAwayAndResetsThePlanToRest() {
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        state.life.meters = LifeMeters(energy: 50, health: 50, mood: 50, relationships: 50)
        Reducer.apply(.planWeekend(.vacation), to: &state, balance: balance, content: content)

        for _ in 0..<6 { Reducer.tick(&state, balance: balance, content: content) }
        let day7 = Reducer.tick(&state, balance: balance, content: content)

        #expect(day7 == [
            .weekendSpent(activity: .vacation, day: 7),
            .founderAway(reason: "Vacation", untilDay: 14, day: 7),
        ])
        #expect(state.life.awayUntilDay == 14)
        #expect(state.life.awayReason == "Vacation")
        #expect(state.life.isAway(day: 7))
        #expect(state.life.meters == LifeMeters(energy: 90, health: 60, mood: 70, relationships: 60))
        #expect(state.life.wallet == 2_000 - 120 - 1_500)
        #expect(state.life.plannedActivity == .rest)

        // Day 14: back first thing, so the (reset) rest weekend resolves.
        for _ in 0..<6 { Reducer.tick(&state, balance: balance, content: content) }
        let day14 = Reducer.tick(&state, balance: balance, content: content)
        #expect(day14 == [.founderBack(day: 14), .weekendSpent(activity: .rest, day: 14)])
        #expect(!state.life.isAway(day: 14))
        #expect(state.life.meters == LifeMeters(energy: 100, health: 60, mood: 75, relationships: 60))
    }

    @Test func doctorClearsAColdOnTopOfItsHealthBoost() {
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        state.life.coldUntilDay = 30
        Reducer.apply(.planWeekend(.doctor), to: &state, balance: balance, content: content)
        for _ in 0..<7 { Reducer.tick(&state, balance: balance, content: content) }
        #expect(state.life.coldUntilDay == nil)
        #expect(!state.life.hasCold(day: 7))
        #expect(state.life.meters.health == 95)
        #expect(state.life.wallet == 2_000 - 120 - 200)
    }

    @Test func dateNightWhileSingleActsLikeFriends() {
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        state.life.meters = LifeMeters(energy: 50, health: 50, mood: 50, relationships: 50)
        Reducer.apply(.planWeekend(.dateNight), to: &state, balance: balance, content: content)
        for _ in 0..<6 { Reducer.tick(&state, balance: balance, content: content) }
        let day7 = Reducer.tick(&state, balance: balance, content: content)
        #expect(weekendEvents(day7) == [.weekendSpent(activity: .friends, day: 7)])
        #expect(state.life.meters == LifeMeters(energy: 50, health: 50, mood: 60, relationships: 58))
        #expect(state.life.wallet == 2_000 - 120 - 80)
        #expect(state.life.plannedActivity == .dateNight)
    }

    @Test func familyTimeWithoutAFamilyActsLikeRest() {
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        state.life.meters = LifeMeters(energy: 50, health: 50, mood: 50, relationships: 50)
        Reducer.apply(.planWeekend(.familyTime), to: &state, balance: balance, content: content)
        for _ in 0..<6 { Reducer.tick(&state, balance: balance, content: content) }
        let day7 = Reducer.tick(&state, balance: balance, content: content)
        #expect(weekendEvents(day7) == [.weekendSpent(activity: .rest, day: 7)])
        #expect(state.life.meters == LifeMeters(energy: 65, health: 50, mood: 55, relationships: 50))
        #expect(state.life.wallet == 2_000 - 120)

        // A child (no partner) is family enough.
        state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        state.life.meters = LifeMeters(energy: 50, health: 50, mood: 50, relationships: 50)
        state.life.family.children = [TestLife.child()]
        Reducer.apply(.planWeekend(.familyTime), to: &state, balance: balance, content: content)
        for _ in 0..<6 { Reducer.tick(&state, balance: balance, content: content) }
        let withKid = Reducer.tick(&state, balance: balance, content: content)
        #expect(weekendEvents(withKid) == [.weekendSpent(activity: .familyTime, day: 7)])
        #expect(state.life.meters == LifeMeters(energy: 50, health: 50, mood: 56, relationships: 62))
    }

    @Test func theWeekendIsSkippedWhileAwayButRentStillFalls() {
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        state.life.meters = LifeMeters(energy: 50, health: 50, mood: 50, relationships: 50)
        state.life.awayUntilDay = 20
        state.life.awayReason = "Hospital"
        Reducer.apply(.planWeekend(.hobby), to: &state, balance: balance, content: content)

        for _ in 0..<7 { Reducer.tick(&state, balance: balance, content: content) }
        #expect(weekendEvents(state.eventLog).isEmpty)
        #expect(state.life.meters == LifeMeters(energy: 50, health: 50, mood: 50, relationships: 50))
        #expect(state.life.wallet == 2_000 - 120)
        #expect(state.life.plannedActivity == .hobby)
    }

    @Test func costsDebitTheWalletEvenIntoTheNegative() {
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        state.life.wallet = 0
        Reducer.apply(.planWeekend(.vacation), to: &state, balance: balance, content: content)
        for _ in 0..<7 { Reducer.tick(&state, balance: balance, content: content) }
        #expect(state.life.wallet == -120 - 1_500)
    }
}

// MARK: - Actions

@Suite("Life actions")
struct LifeActionTests {
    private let content = TestContent.tiny()
    private let balance = lifeBalance()

    @Test func scheduleSalaryAndPlanUpdateStateWithoutEvents() {
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)

        #expect(Reducer.apply(.setWorkSchedule(.crunch), to: &state, balance: balance, content: content).isEmpty)
        #expect(state.life.schedule == .crunch)
        #expect(Reducer.apply(.planWeekend(.gym), to: &state, balance: balance, content: content).isEmpty)
        #expect(state.life.plannedActivity == .gym)
        #expect(Reducer.apply(.setFounderSalary(1_234), to: &state, balance: balance, content: content).isEmpty)
        #expect(state.life.founderSalary == 1_234)
        #expect(state.eventLog.isEmpty)
    }

    @Test func founderSalaryClampsToZeroAndTheMaximum() {
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        Reducer.apply(.setFounderSalary(-5), to: &state, balance: balance, content: content)
        #expect(state.life.founderSalary == 0)
        Reducer.apply(.setFounderSalary(99_999), to: &state, balance: balance, content: content)
        #expect(state.life.founderSalary == 5_000)
        Reducer.apply(.setFounderSalary(5_000), to: &state, balance: balance, content: content)
        #expect(state.life.founderSalary == 5_000)
    }

    @Test func upgradeHomeGatesOnAffordabilityAndTheLadderTop() {
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        state.life.wallet = 5_999
        #expect(Reducer.apply(.upgradeHome, to: &state, balance: balance, content: content).isEmpty)
        #expect(state.life.home == .studioFlat)
        #expect(state.life.wallet == 5_999)

        state.life.wallet = 6_000
        let events = Reducer.apply(.upgradeHome, to: &state, balance: balance, content: content)
        #expect(events == [.homeUpgraded(tier: .apartment, day: 0)])
        #expect(state.eventLog == events)
        #expect(state.life.home == .apartment)
        #expect(state.life.wallet == 0)

        state.life.home = .penthouse
        state.life.wallet = 10_000_000
        #expect(Reducer.apply(.upgradeHome, to: &state, balance: balance, content: content).isEmpty)
        #expect(state.life.wallet == 10_000_000)
    }

    @Test func upgradedHomeRentAndBonusApplyFromTheNextWeek() {
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        state.life.wallet = 40_000
        state.life.home = .apartment
        Reducer.apply(.upgradeHome, to: &state, balance: balance, content: content)
        #expect(state.life.home == .house)
        for _ in 0..<7 { Reducer.tick(&state, balance: balance, content: content) }
        #expect(state.life.wallet == 40_000 - 40_000 - 700)
        #expect(near(state.life.meters.mood, 70 + 7 * 0.2 + 5))
    }

    @Test func singleToDatingNeedsRelationshipsAndDrawsAPartnerFromTheRNG() {
        var state = GameState.newGame(companyName: "Acme", seed: 3, balance: balance)
        state.day = 12
        state.life.meters.relationships = 39.9
        let untouched = state.rng
        #expect(Reducer.apply(.advanceRelationship, to: &state, balance: balance, content: content).isEmpty)
        #expect(state.life.family.stage == .single)
        #expect(state.rng == untouched)

        state.life.meters.relationships = 40
        var probe = state.rng
        let names = content.names.partnerNames
        let expectedName = names[Int(probe.next() % UInt64(names.count))]
        let expectedSeed = probe.next()

        let events = Reducer.apply(.advanceRelationship, to: &state, balance: balance, content: content)
        #expect(events == [.relationshipChanged(stage: .dating, day: 12)])
        #expect(state.life.family.stage == .dating)
        #expect(state.life.family.stageSinceDay == 12)
        #expect(state.life.family.partnerName == expectedName)
        #expect(state.life.family.partnerAppearanceSeed == expectedSeed)
        #expect(state.rng == probe)
    }

    @Test func datingToPartnerNeedsRelationshipsAndTimeAtStage() {
        var state = GameState.newGame(companyName: "Acme", seed: 3, balance: balance)
        TestLife.setPartner(&state, stage: .dating, sinceDay: 10)
        state.day = 66 // 56 days at stage
        state.life.meters.relationships = 59.9
        #expect(Reducer.apply(.advanceRelationship, to: &state, balance: balance, content: content).isEmpty)

        state.life.meters.relationships = 60
        state.day = 65
        #expect(Reducer.apply(.advanceRelationship, to: &state, balance: balance, content: content).isEmpty)
        #expect(state.life.family.stage == .dating)

        state.day = 66
        let untouched = state.rng
        let events = Reducer.apply(.advanceRelationship, to: &state, balance: balance, content: content)
        #expect(events == [.relationshipChanged(stage: .partner, day: 66)])
        #expect(state.life.family.stage == .partner)
        #expect(state.life.family.stageSinceDay == 66)
        #expect(state.life.family.partnerName == "Sam") // the partner carries over
        #expect(state.rng == untouched)
    }

    @Test func partnerToMarriedNeedsRelationshipsTimeAndTheWeddingBudget() {
        var state = GameState.newGame(companyName: "Acme", seed: 3, balance: balance)
        TestLife.setPartner(&state, stage: .partner, sinceDay: 100)
        state.day = 184 // 84 days at stage
        state.life.meters.relationships = 75
        state.life.wallet = 7_999
        #expect(Reducer.apply(.advanceRelationship, to: &state, balance: balance, content: content).isEmpty)
        #expect(state.life.wallet == 7_999)

        state.life.wallet = 8_000
        state.life.meters.relationships = 74.9
        #expect(Reducer.apply(.advanceRelationship, to: &state, balance: balance, content: content).isEmpty)

        state.life.meters.relationships = 75
        state.day = 183
        #expect(Reducer.apply(.advanceRelationship, to: &state, balance: balance, content: content).isEmpty)

        state.day = 184
        let events = Reducer.apply(.advanceRelationship, to: &state, balance: balance, content: content)
        #expect(events == [.relationshipChanged(stage: .married, day: 184)])
        #expect(state.life.family.stage == .married)
        #expect(state.life.family.stageSinceDay == 184)
        #expect(state.life.wallet == 0)

        // Married is the top of the ladder.
        state.life.wallet = 100_000
        state.life.meters.relationships = 100
        #expect(Reducer.apply(.advanceRelationship, to: &state, balance: balance, content: content).isEmpty)
        #expect(state.life.wallet == 100_000)
    }

    @Test func haveChildRejectsEveryUnmetGate() {
        func ready(seed: UInt64 = 4) -> GameState {
            var state = GameState.newGame(companyName: "Acme", seed: seed, balance: balance)
            TestLife.setPartner(&state, stage: .married, sinceDay: 0)
            state.day = 200
            state.life.meters.relationships = 70
            state.life.wallet = 5_000
            state.life.home = .apartment
            return state
        }

        var state = ready()
        TestLife.setPartner(&state, stage: .partner)
        #expect(Reducer.apply(.haveChild, to: &state, balance: balance, content: content).isEmpty)

        state = ready()
        state.life.meters.relationships = 69.9
        #expect(Reducer.apply(.haveChild, to: &state, balance: balance, content: content).isEmpty)

        state = ready()
        state.life.wallet = 4_999
        #expect(Reducer.apply(.haveChild, to: &state, balance: balance, content: content).isEmpty)

        state = ready()
        state.life.home = .studioFlat
        #expect(Reducer.apply(.haveChild, to: &state, balance: balance, content: content).isEmpty)

        state = ready()
        state.life.family.children = [TestLife.child(), TestLife.child(), TestLife.child()]
        #expect(Reducer.apply(.haveChild, to: &state, balance: balance, content: content).isEmpty)

        state = ready()
        state.life.family.lastChildDay = 61 // 139 days ago
        #expect(Reducer.apply(.haveChild, to: &state, balance: balance, content: content).isEmpty)
        #expect(state.life.family.children.isEmpty)
        #expect(state.life.wallet == 5_000)
        #expect(state.eventLog.isEmpty)
    }

    @Test func haveChildDrawsIdNameAndSeedInOrderAndPaysTheCost() {
        var state = GameState.newGame(companyName: "Acme", seed: 4, balance: balance)
        TestLife.setPartner(&state, stage: .married, sinceDay: 0)
        state.day = 200
        state.life.meters.relationships = 70
        state.life.meters.mood = 90
        state.life.wallet = 5_000
        state.life.home = .apartment
        state.life.family.lastChildDay = 60 // exactly 140 days ago

        var probe = state.rng
        _ = probe.next() // 1. id, high word
        _ = probe.next() //    id, low word
        let names = content.names.childNames
        let expectedName = names[Int(probe.next() % UInt64(names.count))] // 2. name
        let expectedSeed = probe.next() // 3. appearance seed

        let events = Reducer.apply(.haveChild, to: &state, balance: balance, content: content)
        #expect(events == [.childBorn(name: expectedName, day: 200)])
        #expect(state.rng == probe)
        let child = state.life.family.children.first
        #expect(state.life.family.children.count == 1)
        #expect(child?.name == expectedName)
        #expect(child?.bornDay == 200)
        #expect(child?.appearanceSeed == expectedSeed)
        #expect(state.life.family.lastChildDay == 200)
        #expect(state.life.wallet == 0)
        #expect(state.life.meters.mood == 100) // 90 + 20, clamped

        // A second child right away is blocked by spacing (and the wallet).
        state.life.wallet = 5_000
        #expect(Reducer.apply(.haveChild, to: &state, balance: balance, content: content).isEmpty)
    }

    @Test func lifeActionsAreIgnoredOnceTheGameIsOver() {
        // Bankrupt on the first weekly posting with no grace period.
        let doomed = TestBalance.make(
            startingCash: 0, weeklyOperatingCost: 1, bankruptcyGraceDays: 0, life: TestBalance.quietLife
        )
        var state = GameState.newGame(companyName: "Doomed", seed: 1, balance: doomed)
        for _ in 0..<7 { Reducer.tick(&state, balance: doomed, content: content) }
        #expect(state.gameOver != nil)

        state.life.wallet = 100_000
        #expect(Reducer.apply(.upgradeHome, to: &state, balance: doomed, content: content).isEmpty)
        #expect(Reducer.apply(.setWorkSchedule(.crunch), to: &state, balance: doomed, content: content).isEmpty)
        #expect(state.life.home == .studioFlat)
        #expect(state.life.schedule == .normal)
    }
}

// MARK: - Life events

@Suite("Life events")
struct LifeEventTests {
    private func balance(interval: Int = 14, chance: Double) -> BalanceConfig {
        lifeBalance(life: TestBalance.life(
            chillDrift: .zero, normalDrift: .zero, crunchDrift: .zero,
            stageRelationshipDrain: [:], childDrift: .zero,
            lifeEventIntervalDays: interval, lifeEventChance: chance
        ))
    }

    private static let viral = LifeEventDef(
        id: "viral", headline: "A joke goes viral.", weight: 1, impact: LifeEventDef.Impact(mood: 8)
    )

    private func lifeEvents(_ events: [GameEvent]) -> [GameEvent] {
        events.filter { if case .lifeEvent = $0 { return true } else { return false } }
    }

    private static func uniform(_ rng: inout SeededRNG) -> Double {
        Double(rng.next() >> 11) * 0x1.0p-53
    }

    @Test func noRollOffTheIntervalAndAHitOnIt() {
        let balance = balance(chance: 1.0)
        let content = TestContent.tiny(lifeEvents: [Self.viral])
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        let initialRNG = state.rng

        for _ in 0..<13 {
            let events = Reducer.tick(&state, balance: balance, content: content)
            #expect(lifeEvents(events).isEmpty)
        }
        #expect(state.rng == initialRNG)
        #expect(state.life.meters.mood == 75) // + the day-7 rest weekend

        let day14 = Reducer.tick(&state, balance: balance, content: content)
        #expect(lifeEvents(day14) == [.lifeEvent(eventID: "viral", day: 14)])
        #expect(state.life.meters.mood == 75 + 8 + 5) // the event, then the day-14 rest
    }

    @Test func aMissConsumesExactlyTheRoll() {
        let balance = balance(chance: 0.0)
        let content = TestContent.tiny(lifeEvents: [Self.viral])
        var state = GameState.newGame(companyName: "Acme", seed: 2, balance: balance)
        for _ in 0..<13 { Reducer.tick(&state, balance: balance, content: content) }
        var expected = state.rng
        _ = expected.next()

        let day14 = Reducer.tick(&state, balance: balance, content: content)
        #expect(lifeEvents(day14).isEmpty)
        #expect(state.rng == expected)
    }

    @Test func aHitConsumesRollPlusPickAndTheImpactDrawsNothing() {
        let balance = balance(chance: 1.0)
        let content = TestContent.tiny(lifeEvents: [Self.viral])
        var state = GameState.newGame(companyName: "Acme", seed: 3, balance: balance)
        for _ in 0..<13 { Reducer.tick(&state, balance: balance, content: content) }
        var expected = state.rng
        _ = expected.next() // 1. the roll
        _ = expected.next() // 2. the weighted pick

        Reducer.tick(&state, balance: balance, content: content)
        #expect(state.rng == expected)
    }

    @Test func anEmptyCatalogDrawsNothing() {
        let balance = balance(chance: 1.0)
        let content = TestContent.tiny(lifeEvents: [])
        var state = GameState.newGame(companyName: "Acme", seed: 4, balance: balance)
        let initialRNG = state.rng
        for _ in 0..<28 { Reducer.tick(&state, balance: balance, content: content) }
        #expect(state.rng == initialRNG)
        #expect(lifeEvents(state.eventLog).isEmpty)
    }

    @Test func customIntervalIsHonored() {
        let balance = balance(interval: 5, chance: 1.0)
        let content = TestContent.tiny(lifeEvents: [Self.viral])
        var state = GameState.newGame(companyName: "Acme", seed: 5, balance: balance)
        var hitDays: [Int] = []
        for _ in 0..<20 {
            if !lifeEvents(Reducer.tick(&state, balance: balance, content: content)).isEmpty {
                hitDays.append(state.day)
            }
        }
        #expect(hitDays == [5, 10, 15, 20])
    }

    @Test func hitOrMissIsDeterministicPerSeed() {
        let balance = balance(chance: 0.35)
        let content = TestContent.tiny(lifeEvents: [Self.viral])
        var outcomes = Set<Bool>()
        for seed in 1...UInt64(30) {
            func fires() -> Bool {
                var state = GameState.newGame(companyName: "Acme", seed: seed, balance: balance)
                var probe = state.rng
                let predicted = Self.uniform(&probe) < 0.35
                for _ in 0..<14 { Reducer.tick(&state, balance: balance, content: content) }
                let fired = !lifeEvents(state.eventLog).isEmpty
                #expect(fired == predicted, "seed \(seed)")
                return fired
            }
            let first = fires()
            #expect(first == fires())
            outcomes.insert(first)
        }
        #expect(outcomes == [true, false])
    }

    @Test func gatesFilterTheEligiblePool() {
        let needsPartner = LifeEventDef(
            id: "promo", headline: "Partner promoted.", weight: 1, minStage: "dating",
            impact: LifeEventDef.Impact(wallet: 300)
        )
        let needsKids = LifeEventDef(
            id: "first_word", headline: "First word.", weight: 1, requiresChildren: true,
            impact: LifeEventDef.Impact(mood: 12)
        )
        let needsLowRel = LifeEventDef(
            id: "complains", headline: "Partner complains.", weight: 1, minStage: "dating",
            maxRelationships: 40, impact: LifeEventDef.Impact(mood: -8)
        )
        let unknownStage = LifeEventDef(
            id: "weird", headline: "Never.", weight: 1, minStage: "divorced",
            impact: LifeEventDef.Impact(mood: 1)
        )
        let balance = balance(chance: 1.0)
        let content = TestContent.tiny(lifeEvents: [needsPartner, needsKids, needsLowRel, unknownStage])

        // A single, childless founder with good relationships: nothing is
        // eligible, so the interval day draws only the roll and emits nothing.
        var state = GameState.newGame(companyName: "Acme", seed: 6, balance: balance)
        for _ in 0..<13 { Reducer.tick(&state, balance: balance, content: content) }
        var expected = state.rng
        _ = expected.next()
        let quiet = Reducer.tick(&state, balance: balance, content: content)
        #expect(lifeEvents(quiet).isEmpty)
        #expect(state.rng == expected)
        #expect(state.life.wallet == 2_000 - 2 * 120) // rent only, on days 7 and 14

        // Dating at 50 relationships: only the promotion qualifies.
        state = GameState.newGame(companyName: "Acme", seed: 6, balance: balance)
        TestLife.setPartner(&state, stage: .dating)
        for _ in 0..<14 { Reducer.tick(&state, balance: balance, content: content) }
        #expect(lifeEvents(state.eventLog) == [.lifeEvent(eventID: "promo", day: 14)])

        // Married at 39.9 relationships with a child: all three real gates
        // pass; the unknown stage never does. Predict the pick over the
        // cumulative weights [promo, first_word, complains].
        for seed in 1...UInt64(12) {
            state = GameState.newGame(companyName: "Acme", seed: seed, balance: balance)
            TestLife.setPartner(&state, stage: .married)
            state.life.family.children = [TestLife.child()]
            state.life.meters.relationships = 39.9
            var probe = state.rng
            _ = probe.next()
            let expectedID = ["promo", "first_word", "complains"][Int(probe.next() % 3)]
            for _ in 0..<14 { Reducer.tick(&state, balance: balance, content: content) }
            #expect(lifeEvents(state.eventLog) == [.lifeEvent(eventID: expectedID, day: 14)], "seed \(seed)")
        }
    }

    @Test func maxRelationshipsIsAStrictUpperBound() {
        let complains = LifeEventDef(
            id: "complains", headline: "Partner complains.", weight: 1,
            maxRelationships: 40, impact: LifeEventDef.Impact(mood: -8)
        )
        let balance = balance(chance: 1.0)
        let content = TestContent.tiny(lifeEvents: [complains])
        var state = GameState.newGame(companyName: "Acme", seed: 7, balance: balance)
        state.life.meters.relationships = 40
        for _ in 0..<14 { Reducer.tick(&state, balance: balance, content: content) }
        #expect(lifeEvents(state.eventLog).isEmpty)
    }

    @Test func weightedPickIsDeterministicAndFollowsTheCumulativeWeights() {
        let light = LifeEventDef(id: "light", headline: "Light.", weight: 1, impact: LifeEventDef.Impact(mood: 1))
        let heavy = LifeEventDef(id: "heavy", headline: "Heavy.", weight: 3, impact: LifeEventDef.Impact(mood: -1))
        let balance = balance(chance: 1.0)
        let content = TestContent.tiny(lifeEvents: [light, heavy])

        var lightPicks = 0
        for seed in 1...UInt64(40) {
            var state = GameState.newGame(companyName: "Acme", seed: seed, balance: balance)
            var probe = state.rng
            _ = probe.next()
            let expectedID = Int(probe.next() % 4) == 0 ? "light" : "heavy"
            for _ in 0..<14 { Reducer.tick(&state, balance: balance, content: content) }
            #expect(lifeEvents(state.eventLog) == [.lifeEvent(eventID: expectedID, day: 14)], "seed \(seed)")
            if expectedID == "light" { lightPicks += 1 }
        }
        #expect(lightPicks > 0)
        #expect(lightPicks < 40)
    }

    @Test func impactAppliesMeterDeltasWithClampsAndTheWallet() {
        let wedding = LifeEventDef(
            id: "wedding", headline: "Wedding weekend.", weight: 1,
            impact: LifeEventDef.Impact(energy: -8, health: 50, mood: 12, relationships: -60, wallet: -350)
        )
        let balance = balance(chance: 1.0)
        let content = TestContent.tiny(lifeEvents: [wedding])
        var state = GameState.newGame(companyName: "Acme", seed: 8, balance: balance)
        state.life.meters = LifeMeters(energy: 50, health: 60, mood: 50, relationships: 50)
        for _ in 0..<14 { Reducer.tick(&state, balance: balance, content: content) }
        // Weekly rest (+15 energy, +5 mood) lands after the event on days 7 and 14.
        #expect(state.life.meters == LifeMeters(energy: 50 - 8 + 30, health: 100, mood: 50 + 12 + 10, relationships: 0))
        #expect(state.life.wallet == 2_000 - 2 * 120 - 350)
        #expect(state.ledger.entries.allSatisfy { $0.category != .other }) // personal money never hits the company ledger
    }

    @Test func aColdImpactSetsTheColdWindow() {
        let cold = LifeEventDef(
            id: "cold", headline: "You caught a cold.", weight: 1,
            impact: LifeEventDef.Impact(energy: -10, coldDays: 5)
        )
        let balance = balance(chance: 1.0)
        let content = TestContent.tiny(lifeEvents: [cold])
        var state = GameState.newGame(companyName: "Acme", seed: 9, balance: balance)
        for _ in 0..<14 { Reducer.tick(&state, balance: balance, content: content) }
        #expect(state.life.coldUntilDay == 19)
        #expect(state.life.hasCold(day: 14))
        #expect(state.life.hasCold(day: 18))
        #expect(!state.life.hasCold(day: 19))
        #expect(near(state.founderOutputMultiplier(balance: balance), 0.6 * (0.5 + 0.5 * (0.4 * 100 + 0.3 * 80 + 0.3 * 80) / 100)))

        for _ in 0..<5 { Reducer.tick(&state, balance: balance, content: content) } // day 19 clears it
        #expect(state.life.coldUntilDay == nil)
    }

    @Test func anAwayImpactSendsTheFounderAwayUnlessAlreadyAway() {
        let emergency = LifeEventDef(
            id: "emergency", headline: "Family emergency.", weight: 1,
            impact: LifeEventDef.Impact(mood: -6, awayDays: 3, awayReason: "Family emergency")
        )
        let balance = balance(chance: 1.0)
        let content = TestContent.tiny(lifeEvents: [emergency])
        var state = GameState.newGame(companyName: "Acme", seed: 10, balance: balance)
        for _ in 0..<13 { Reducer.tick(&state, balance: balance, content: content) }

        let day14 = Reducer.tick(&state, balance: balance, content: content)
        #expect(day14 == [
            .lifeEvent(eventID: "emergency", day: 14),
            .founderAway(reason: "Family emergency", untilDay: 17, day: 14),
        ])
        #expect(state.life.awayUntilDay == 17)
        #expect(state.life.awayReason == "Family emergency")
        // The founder left before the weekend: the rest activity was skipped.
        #expect(state.life.meters.mood == 70 + 5 - 6)
        for _ in 0..<3 { Reducer.tick(&state, balance: balance, content: content) }
        #expect(state.eventLog.contains(.founderBack(day: 17)))

        // Already away: the impact still applies but the window is untouched.
        state = GameState.newGame(companyName: "Acme", seed: 10, balance: balance)
        state.life.awayUntilDay = 30
        state.life.awayReason = "Vacation"
        for _ in 0..<13 { Reducer.tick(&state, balance: balance, content: content) }
        let blocked = Reducer.tick(&state, balance: balance, content: content)
        #expect(blocked == [.lifeEvent(eventID: "emergency", day: 14)])
        #expect(state.life.awayUntilDay == 30)
        #expect(state.life.awayReason == "Vacation")
        #expect(state.life.meters.mood == 70 - 6)
    }

    @Test func anAwayImpactWithoutAReasonUsesTheHeadline() {
        let retreat = LifeEventDef(
            id: "retreat", headline: "A silent retreat.", weight: 1,
            impact: LifeEventDef.Impact(awayDays: 2)
        )
        let balance = balance(chance: 1.0)
        let content = TestContent.tiny(lifeEvents: [retreat])
        var state = GameState.newGame(companyName: "Acme", seed: 11, balance: balance)
        for _ in 0..<14 { Reducer.tick(&state, balance: balance, content: content) }
        #expect(state.life.awayReason == "A silent retreat.")
        #expect(state.eventLog.contains(.founderAway(reason: "A silent retreat.", untilDay: 16, day: 14)))
    }

    @Test func bundledLifeEventsFireOverALongRun() {
        // Deep company pockets keep the salary from bankrupting the run.
        let balance = TestBalance.make(
            startingCash: 1_000_000, candidateRefreshDays: 10_000, contractOfferRefreshDays: 10_000,
            eventCheckIntervalDays: 10_000, life: TestBalance.life()
        )
        let content = TestContent.bundled
        var state = GameState.newGame(companyName: "Acme", seed: 12, balance: balance)
        Reducer.apply(.setFounderSalary(1_000), to: &state, balance: balance, content: content)
        for _ in 0..<364 { Reducer.tick(&state, balance: balance, content: content) }
        #expect(state.gameOver == nil)
        let fired = lifeEvents(state.eventLog)
        #expect(fired.count >= 3) // 26 rolls at 35%
        for case .lifeEvent(let id, _) in fired {
            #expect(content.lifeEvent(id) != nil)
        }
    }
}
