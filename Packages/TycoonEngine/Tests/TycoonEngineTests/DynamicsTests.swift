import Foundation
import Testing
import TycoonContent
import TycoonEngine

// Tests for the dynamics added on top of the base engine: the per-topic
// market, the launch adoption ramp, staff morale/seniority management,
// contract delivery quality, and company loans.

@Suite("Market dynamics")
struct MarketDynamicsTests {
    @Test func marketShiftsOnItsCadenceAndClampsToBounds() {
        var market = BalanceConfig.MarketBalance.standard
        market.shiftIntervalDays = 7
        market.boomChance = 0
        market.crashChance = 0
        let balance = TestBalance.make(market: market)
        let content = TestContent.tiny()
        var state = GameState.newGame(companyName: "Acme", seed: 5, balance: balance)

        #expect(state.market.multiplier(for: "testing") == 1.0)

        for _ in 0..<6 {
            Reducer.tick(&state, balance: balance, content: content)
            #expect(state.market.topics.isEmpty) // no shift before day 7
        }
        Reducer.tick(&state, balance: balance, content: content) // day 7

        let topic = state.market.topics["testing"]
        #expect(topic != nil)
        if let topic {
            #expect(topic.multiplier >= market.multiplierMin)
            #expect(topic.multiplier <= market.multiplierMax)
            #expect(topic.multiplier != 1.0) // the gaussian never lands exactly on 0
            #expect(topic.lastChange == topic.multiplier - 1.0)
        }
    }

    @Test func boomsAndCrashesEmitPausingEvents() {
        var market = BalanceConfig.MarketBalance.standard
        market.shiftIntervalDays = 7
        market.driftSigma = 0
        market.boomChance = 1 // every shift booms
        let balance = TestBalance.make(market: market)
        let content = TestContent.tiny()
        var state = GameState.newGame(companyName: "Acme", seed: 5, balance: balance)

        var events: [GameEvent] = []
        for _ in 0..<7 {
            events = Reducer.tick(&state, balance: balance, content: content)
        }
        #expect(events.contains(.marketBoom(topicID: "testing", day: 7)))
        #expect(GameEvent.marketBoom(topicID: "testing", day: 7).pausesTimeline)
        #expect(GameEvent.marketCrash(topicID: "testing", day: 7).pausesTimeline)
        #expect(state.market.multiplier(for: "testing") == 1.4) // +boomJump exactly (sigma 0)
    }

    @Test func weeklySalesScaleWithTheTopicMultiplier() {
        let balance = TestBalance.make(
            reviewNoiseSigma: 0, reviewCeiling: 100,
            salesDecayBase: 0.1, salesDecayQualityFactor: 0,
            life: TestBalance.quietLife
        )
        let content = TestContent.tiny(marketSize: 1000)
        var state = GameState.newGame(companyName: "Acme", seed: 11, balance: balance)
        state.products.append(Product(
            id: UUID(), name: "Gizmo", typeID: "tool", topicID: "testing",
            stage: .released(ReleaseInfo(
                launchDay: 0,
                quality: 100,
                reviews: [Review(outlet: "T", score: 100, blurb: "")],
                weeklySales: [],
                offMarket: false
            ))
        ))
        state.market.topics["testing"] = TopicMarket(multiplier: 1.5, lastChange: 0)

        while state.day < 7 {
            Reducer.tick(&state, balance: balance, content: content)
        }
        guard case .released(let info) = state.products[0].stage else {
            Issue.record("expected a released product")
            return
        }
        // Peak 1000 × market 1.5 = 1500 units on launch week.
        #expect(info.weeklySales == [WeeklySale(weekIndex: 0, units: 1500, revenue: 3000)])
    }
}

@Suite("Adoption ramp")
struct AdoptionRampTests {
    @Test func salesRampToPeakOverAdoptionWeeksThenDecay() {
        let balance = TestBalance.make(
            salesDecayBase: 0.5, salesDecayQualityFactor: 0,
            delistFraction: 0,
            life: TestBalance.quietLife
        )
        let content = TestContent.tiny(marketSize: 1000)
        var state = GameState.newGame(companyName: "Acme", seed: 11, balance: balance)
        state.products.append(Product(
            id: UUID(), name: "Gizmo", typeID: "tool", topicID: "testing",
            stage: .released(ReleaseInfo(
                launchDay: 0,
                quality: 100,
                reviews: [Review(outlet: "T", score: 100, blurb: "")],
                weeklySales: [],
                offMarket: false,
                hypeAtLaunch: 0,
                adoptionWeeks: 4
            ))
        ))

        while state.day < 35 {
            Reducer.tick(&state, balance: balance, content: content)
        }
        guard case .released(let info) = state.products[0].stage else {
            Issue.record("expected a released product")
            return
        }
        // Peak 1000, ramp 4 weeks: 250, 500, 750, 1000, then decay ×0.5.
        #expect(info.weeklySales.map(\.units) == [250, 500, 750, 1000, 500])
    }

    @Test func shipComputesAdoptionWeeksFromMarketingSkillAndHype() throws {
        let balance = TestBalance.make(
            bugChanceBase: 0, founderMarketing: 32,
            life: TestBalance.quietLife,
            adoption: .init(rampWeeksMax: 8, rampWeeksMin: 1, marketingDivisor: 16, hypeDivisor: 25)
        )
        let content = TestContent.tiny(designPts: 2, codePts: 2, polishPts: 2)
        var state = GameState.newGame(companyName: "Acme", seed: 11, balance: balance)
        TestLife.pinPeak(&state)

        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "Gizmo", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        let id = try #require(state.products.first?.id)
        for _ in 0..<3 {
            Reducer.tick(&state, balance: balance, content: content)
        }
        Reducer.apply(.ship(productID: id), to: &state, balance: balance, content: content)

        guard case .released(let info) = try #require(state.products.first).stage else {
            Issue.record("expected a released product")
            return
        }
        // Solo founder with marketing 32, no hype: 8 − 32/16 − 0 = 6 weeks.
        #expect(abs(info.adoptionWeeks - 6) < 1e-9)
    }
}

@Suite("Staff management")
struct StaffManagementTests {
    private func makeState(
        staff: BalanceConfig.StaffBalance,
        salary: Int = 945 // exactly fair pay for the default test skills
    ) -> (GameState, BalanceConfig) {
        let balance = TestBalance.make(
            candidateRefreshDays: 10_000, contractOfferRefreshDays: 10_000,
            life: TestBalance.quietLife, staff: staff
        )
        var state = GameState.newGame(companyName: "Acme", seed: 3, balance: balance)
        state.employees.append(TestPeople.employee(weeklySalary: salary))
        return (state, balance)
    }

    @Test func underpaidMoraleDriftsDownAndFairPayHoldsSteady() {
        var staff = BalanceConfig.StaffBalance.standard
        staff.moraleAdaptRate = 0.5
        let content = TestContent.tiny()

        var (state, balance) = makeState(staff: staff, salary: 300) // far under fair 945
        Reducer.tick(&state, balance: balance, content: content)
        // Target 60 − 25 = 35: morale 70 → 70 + (35−70)×0.5 = 52.5.
        #expect(abs(state.employees[1].morale - 52.5) < 1e-9)

        var (fair, fairBalance) = makeState(staff: staff, salary: 945)
        Reducer.tick(&fair, balance: fairBalance, content: content)
        // Target 60: morale 70 → 65.
        #expect(abs(fair.employees[1].morale - 65) < 1e-9)
    }

    @Test func chronicallyMiserableEmployeeQuits() {
        var staff = BalanceConfig.StaffBalance.standard
        staff.moraleAdaptRate = 1 // snaps to target instantly
        staff.quitMoraleThreshold = 40
        staff.quitStreakDays = 3
        let content = TestContent.tiny()
        var (state, balance) = makeState(staff: staff, salary: 300) // target 35 < threshold

        var quitEvents: [GameEvent] = []
        for _ in 0..<5 {
            quitEvents += Reducer.tick(&state, balance: balance, content: content).filter {
                if case .employeeQuit = $0 { return true }
                return false
            }
        }
        #expect(quitEvents.count == 1)
        #expect(state.employees.count == 1) // only the founder remains
        if case .employeeQuit(_, let name, let day) = quitEvents[0] {
            #expect(name == "Worker")
            #expect(day == 4) // 3 sub-threshold days, quits on the 4th
            #expect(GameEvent.employeeQuit(employeeID: UUID(), name: name, day: day).pausesTimeline)
        }
    }

    @Test func praiseBoostsMoraleOncePerCooldown() {
        let (initial, balance) = makeState(staff: TestBalance.frozenStaff)
        var state = initial
        let id = state.employees[1].id
        let content = TestContent.tiny()

        Reducer.apply(.praise(employeeID: id), to: &state, balance: balance, content: content)
        #expect(state.employees[1].morale == 78) // 70 + 8

        Reducer.apply(.praise(employeeID: id), to: &state, balance: balance, content: content)
        #expect(state.employees[1].morale == 78) // still on cooldown

        // Praising the founder is ignored.
        let founderID = state.employees[0].id
        Reducer.apply(.praise(employeeID: founderID), to: &state, balance: balance, content: content)
        #expect(state.employees[0].morale == 70)
    }

    @Test func salaryChangesMoveMorale() {
        let (initial, balance) = makeState(staff: TestBalance.frozenStaff, salary: 1000)
        var state = initial
        let id = state.employees[1].id
        let content = TestContent.tiny()

        // +10% raise: morale +0.1 × 40 = +4.
        let raised = Reducer.apply(
            .adjustSalary(employeeID: id, weeklySalary: 1100),
            to: &state, balance: balance, content: content
        )
        #expect(raised == [.salaryChanged(employeeID: id, weeklySalary: 1100, day: 0)])
        #expect(abs(state.employees[1].morale - 74) < 1e-9)

        // Cut back by ~18.2%: morale −0.1818… × 80 ≈ −14.5.
        Reducer.apply(
            .adjustSalary(employeeID: id, weeklySalary: 900),
            to: &state, balance: balance, content: content
        )
        #expect(state.employees[1].weeklySalary == 900)
        #expect(state.employees[1].morale < 74 - 14)
    }

    @Test func promotionAndDemotionMoveLevelSalaryAndMorale() {
        let (initial, balance) = makeState(staff: TestBalance.frozenStaff, salary: 1000)
        var state = initial
        let id = state.employees[1].id
        let content = TestContent.tiny()

        let promoted = Reducer.apply(
            .promote(employeeID: id), to: &state, balance: balance, content: content
        )
        #expect(promoted == [.employeePromoted(employeeID: id, level: .mid, day: 0)])
        #expect(state.employees[1].level == .mid)
        #expect(state.employees[1].weeklySalary == 1150) // +15%
        #expect(state.employees[1].morale == 85) // +15

        let demoted = Reducer.apply(
            .demote(employeeID: id), to: &state, balance: balance, content: content
        )
        #expect(demoted == [.employeeDemoted(employeeID: id, level: .junior, day: 0)])
        #expect(state.employees[1].level == .junior)
        #expect(state.employees[1].weeklySalary == 1035) // −10%
        #expect(state.employees[1].morale == 65) // −20

        // Demoting a junior is ignored; promoting the founder is ignored.
        #expect(Reducer.apply(.demote(employeeID: id), to: &state, balance: balance, content: content).isEmpty)
        let founderID = state.employees[0].id
        #expect(Reducer.apply(.promote(employeeID: founderID), to: &state, balance: balance, content: content).isEmpty)
    }

    @Test func moraleAndSeniorityScaleOutput() {
        var happy = TestPeople.employee()
        happy.morale = 90
        happy.level = .senior
        let balance = TestBalance.make() // frozenStaff: neutral 70, 0.005/pt, +6%/level
        // (1 + 20×0.005) × (1 + 0.06×2) = 1.1 × 1.12
        #expect(abs(happy.performanceMultiplier(balance: balance) - 1.1 * 1.12) < 1e-9)

        var miserable = TestPeople.employee()
        miserable.morale = 0
        #expect(abs(miserable.performanceMultiplier(balance: balance) - 0.65) < 1e-9)
    }

    @Test func trainingCostsCashBoostsOneSkillAndCoolsDown() {
        let (initial, balance) = makeState(staff: TestBalance.frozenStaff)
        var state = initial
        let id = state.employees[1].id
        let content = TestContent.tiny()
        let cashBefore = state.company.cash

        let trained = Reducer.apply(
            .train(employeeID: id, skill: .coding), to: &state, balance: balance, content: content
        )
        #expect(trained == [.employeeTrained(employeeID: id, day: 0)])
        #expect(state.employees[1].skills.coding == 56) // 50 + 6
        #expect(state.employees[1].morale == 74) // 70 + 4
        #expect(state.company.cash == cashBefore - 800)

        // On cooldown: ignored, no charge.
        let again = Reducer.apply(
            .train(employeeID: id, skill: .design), to: &state, balance: balance, content: content
        )
        #expect(again.isEmpty)
        #expect(state.company.cash == cashBefore - 800)

        // The founder can train too (no morale, life meters instead).
        let founderID = state.employees[0].id
        Reducer.apply(.train(employeeID: founderID, skill: .marketing), to: &state, balance: balance, content: content)
        #expect(state.employees[0].skills.marketing == 26) // 20 + 6
    }

    @Test func hiresGetStartingMoraleAndSkillBasedLevel() {
        #expect(SeniorityLevel.forSkillTotal(50) == .junior)
        #expect(SeniorityLevel.forSkillTotal(120) == .mid)
        #expect(SeniorityLevel.forSkillTotal(180) == .senior)
        #expect(SeniorityLevel.forSkillTotal(250) == .lead)
    }
}

@Suite("Contract delivery quality")
struct ContractQualityTests {
    private func run(
        crewCoding: Double, crewDesign: Double, requiredSkill: Double
    ) -> (events: [GameEvent], state: GameState) {
        let balance = TestBalance.make(
            skillGrowthRate: 0,
            candidateRefreshDays: 10_000, contractOfferRefreshDays: 10_000,
            life: TestBalance.quietLife,
            contractQuality: .standard
        )
        let content = TestContent.tiny()
        var state = GameState.newGame(companyName: "Acme", seed: 3, balance: balance)
        let jobID = UUID()
        state.activeContracts.append(ContractJob(
            id: jobID, clientName: "TestCo",
            requiredCodePts: 4, requiredDesignPts: 4,
            progressCode: 0, progressDesign: 0,
            deadlineDay: 100, payout: 1000, penalty: 300, acceptedDay: 0,
            requiredSkill: requiredSkill
        ))
        var worker = TestPeople.employee(
            coding: crewCoding, design: crewDesign, assignment: .contract(jobID)
        )
        worker.morale = 70
        state.employees.append(worker)

        var events: [GameEvent] = []
        for _ in 0..<10 where !state.activeContracts.isEmpty {
            events += Reducer.tick(&state, balance: balance, content: content)
        }
        return (events, state)
    }

    @Test func skilledCrewGetsFullPayoutAndReputation() {
        let (events, state) = run(crewCoding: 80, crewDesign: 80, requiredSkill: 60)
        let delivered = events.compactMap { event -> (Int, Int)? in
            if case .contractDelivered(_, let quality, let payout, _) = event {
                return (quality, payout)
            }
            return nil
        }
        #expect(delivered.count == 1)
        // Crew skill 80 vs required 60: ratio 1.33 → quality 100, full pay.
        #expect(delivered.first?.0 == 100)
        #expect(delivered.first?.1 == 1000)
        #expect(state.company.reputation > 10) // reward applied
    }

    @Test func underSkilledCrewGetsDockedPayAndReputation() {
        let (events, state) = run(crewCoding: 30, crewDesign: 30, requiredSkill: 80)
        let delivered = events.compactMap { event -> (Int, Int)? in
            if case .contractDelivered(_, let quality, let payout, _) = event {
                return (quality, payout)
            }
            return nil
        }
        #expect(delivered.count == 1)
        // Crew skill 30 vs required 80: ratio 0.375 → quality 30, poor band.
        #expect(delivered.first?.0 == 30)
        #expect(delivered.first?.1 == 500) // poorPayoutFraction 0.5
        #expect(state.company.reputation < 10) // penalty applied
        // A delivery is good news with nothing to answer, so under WS-A's
        // pause policy it no longer stops the clock — it is a feed line.
        if let quality = delivered.first?.0 {
            #expect(!GameEvent.contractDelivered(
                contractID: UUID(), quality: quality, payout: 0, day: 0
            ).pausesTimeline)
        }
    }

    @Test func offersRollARequiredSkillWithinBounds() {
        var quality = BalanceConfig.ContractQualityBalance.standard
        quality.skillMin = 40
        quality.skillMax = 50
        let balance = TestBalance.make(life: TestBalance.quietLife, contractQuality: quality)
        let content = TestContent.tiny()
        var state = GameState.newGame(companyName: "Acme", seed: 9, balance: balance)

        for _ in 0..<7 {
            Reducer.tick(&state, balance: balance, content: content)
        }
        #expect(!state.contractOffers.isEmpty)
        for offer in state.contractOffers {
            #expect(offer.requiredSkill >= 40)
            #expect(offer.requiredSkill <= 50)
        }
    }
}

@Suite("Company loans")
struct LoanTests {
    @Test func takeRepayAndWeeklyInterest() {
        let balance = TestBalance.make(
            candidateRefreshDays: 10_000, contractOfferRefreshDays: 10_000,
            life: TestBalance.quietLife
        )
        let content = TestContent.tiny()
        var state = GameState.newGame(companyName: "Acme", seed: 3, balance: balance)
        let cashBefore = state.company.cash

        let taken = Reducer.apply(
            .takeLoan(amount: 10_000), to: &state, balance: balance, content: content
        )
        #expect(taken == [.loanTaken(amount: 10_000, day: 0)])
        #expect(state.loanBalance == 10_000)
        #expect(state.company.cash == cashBefore + 10_000)

        // Weekly interest: 1% of 10 000 = 100 on day 7.
        while state.day < 7 {
            Reducer.tick(&state, balance: balance, content: content)
        }
        #expect(state.ledger.entries.contains {
            $0.label == "Loan interest" && $0.amount == -100 && $0.day == 7
        })

        let repaid = Reducer.apply(
            .repayLoan(amount: 4_000), to: &state, balance: balance, content: content
        )
        #expect(repaid == [.loanRepaid(amount: 4_000, day: 7)])
        #expect(state.loanBalance == 6_000)
    }

    @Test func borrowingIsCappedByTheCreditLimit() {
        let balance = TestBalance.make(life: TestBalance.quietLife)
        let content = TestContent.tiny()
        var state = GameState.newGame(companyName: "Acme", seed: 3, balance: balance)
        // The bank lends against a book, not a pitch: 20 000 base
        // + 300 × 10 reputation + half of a trading history this studio
        // does not have yet = 23 000.
        state.company.reputation = 10

        Reducer.apply(.takeLoan(amount: 1_000_000), to: &state, balance: balance, content: content)
        #expect(state.loanBalance == 23_000)

        // A quarter of real revenue on the books raises the line.
        state.ledger.entries.append(
            LedgerEntry(day: state.day, amount: 40_000, category: .sales, label: "Hit")
        )
        Reducer.apply(.takeLoan(amount: 1_000_000), to: &state, balance: balance, content: content)
        #expect(state.loanBalance == 43_000)

        // Maxed out: further borrowing is ignored.
        let more = Reducer.apply(.takeLoan(amount: 1), to: &state, balance: balance, content: content)
        #expect(more.isEmpty)
    }
}
