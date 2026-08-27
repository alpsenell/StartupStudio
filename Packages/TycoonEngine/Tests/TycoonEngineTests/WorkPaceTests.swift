import Foundation
import Testing
import TycoonContent
import TycoonEngine

/// The pace the company works at, the conditions people notice, and what
/// happens when they have had enough: a week's notice the founder can still
/// answer, not a silent disappearance.
@Suite("Work pace, morale & resignations")
struct WorkPaceTests {
    /// An economy with the pace and morale rules live, everything else
    /// neutral.
    static func economy(
        stagnationDays: Int = 364,
        stagnationMoralePenalty: Double = 10,
        overcrowdingMoralePenalty: Double = 6,
        overdueContractMoralePenalty: Double = 4,
        founderAwayDays: Int = 7,
        founderAwayMoralePenalty: Double = 5,
        resignationNoticeDays: Int = 7,
        counterOfferRaiseFactor: Double = 1.12,
        counterOfferMoraleBoost: Double = 30
    ) -> BalanceConfig.EconomyBalance {
        var economy = TestBalance.neutralEconomy
        economy.pace = BalanceConfig.EconomyBalance.PaceDef.standardTable
        economy.stagnationDays = stagnationDays
        economy.stagnationMoralePenalty = stagnationMoralePenalty
        economy.overcrowdingMoralePenalty = overcrowdingMoralePenalty
        economy.overdueContractMoralePenalty = overdueContractMoralePenalty
        economy.founderAwayDays = founderAwayDays
        economy.founderAwayMoralePenalty = founderAwayMoralePenalty
        economy.resignationNoticeDays = resignationNoticeDays
        economy.counterOfferRaiseFactor = counterOfferRaiseFactor
        economy.counterOfferMoraleBoost = counterOfferMoraleBoost
        return economy
    }

    /// Morale snaps straight to its target so a single tick shows it.
    static var snappingStaff: BalanceConfig.StaffBalance {
        var staff = BalanceConfig.StaffBalance.standard
        staff.moraleAdaptRate = 1
        staff.quitStreakDays = 1_000_000
        return staff
    }

    /// A studio with one well-paid worker, morale snapping to target.
    static func studio(
        economy: BalanceConfig.EconomyBalance,
        staff: BalanceConfig.StaffBalance? = nil,
        salary: Int = 2_000,
        seed: UInt64 = 41
    ) -> (GameState, BalanceConfig, ContentCatalog) {
        let balance = TestBalance.make(
            life: TestBalance.quietLife,
            staff: staff ?? snappingStaff,
            economy: economy
        )
        var state = GameState.newGame(companyName: "Acme", seed: seed, balance: balance)
        TestLife.pinPeak(&state)
        state.employees.append(TestPeople.employee(weeklySalary: salary))
        return (state, balance, TestContent.tiny())
    }

    static func morale(_ state: GameState) -> Double {
        state.employees.last?.morale ?? 0
    }

    // MARK: - Work pace

    @Test func crunchBuysSpeedWithMorale() throws {
        var (relaxed, balance, content) = Self.studio(economy: Self.economy())
        var crunched = relaxed
        crunched.economy.workPace = .crunch
        relaxed.economy.workPace = .normal

        Reducer.tick(&relaxed, balance: balance, content: content)
        Reducer.tick(&crunched, balance: balance, content: content)
        // Crunch takes 18 points off everybody's morale target.
        #expect(abs(Self.morale(relaxed) - Self.morale(crunched) - 18) < 1e-9)
    }

    @Test func aRelaxedCompanyIsAHappierOne() throws {
        var (state, balance, content) = Self.studio(economy: Self.economy())
        state.economy.workPace = .relaxed
        var normal = state
        normal.economy.workPace = .normal

        Reducer.tick(&state, balance: balance, content: content)
        Reducer.tick(&normal, balance: balance, content: content)
        #expect(abs(Self.morale(state) - Self.morale(normal) - 6) < 1e-9)
    }

    @Test func crunchTradesOutputAgainstBugsAndBurn() throws {
        func build(_ pace: WorkPace) -> (code: Double, bugs: Int) {
            let balance = TestBalance.make(
                bugChanceBase: 1, skillGrowthRate: 0,
                life: TestBalance.quietLife, economy: Self.economy()
            )
            let content = TestContent.tiny(designPts: 500, codePts: 500, polishPts: 500)
            var state = GameState.newGame(companyName: "Acme", seed: 5, balance: balance)
            TestLife.pinPeak(&state)
            state.economy.workPace = pace
            Reducer.apply(
                .startProduct(
                    typeID: "tool", topicID: "testing", name: "T",
                    focus: PhaseFocus(design: 0, code: 1, polish: 0)
                ),
                to: &state, balance: balance, content: content
            )
            for _ in 0..<10 {
                Reducer.tick(&state, balance: balance, content: content)
            }
            guard case .development(let dev) = state.products[0].stage else { return (0, 0) }
            return (dev.codePts, dev.openBugs)
        }

        let normal = build(.normal)
        let crunch = build(.crunch)
        let relaxed = build(.relaxed)
        #expect(abs(crunch.code - normal.code * 1.25) < 1e-6)
        #expect(abs(relaxed.code - normal.code * 0.85) < 1e-6)
        #expect(crunch.bugs > normal.bugs, "crunch should ship more bugs")
    }

    @Test func settingThePaceIsRecordedAndSurvivesASaveRoundTrip() throws {
        let balance = TestBalance.make(economy: Self.economy())
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        #expect(state.economy.workPace == .normal)

        Reducer.apply(.setWorkPace(.crunch), to: &state, balance: balance, content: TestContent.tiny())
        #expect(state.economy.workPace == .crunch)

        let data = try JSONEncoder().encode(state)
        let restored = try JSONDecoder().decode(GameState.self, from: data)
        #expect(restored.economy.workPace == .crunch)
    }

    // MARK: - Conditions people notice

    @Test func aFullRoomDragsOnEverybody() throws {
        let economy = Self.economy()
        let balance = TestBalance.make(
            life: TestBalance.quietLife, staff: Self.snappingStaff, economy: economy
        )
        var state = GameState.newGame(companyName: "Acme", seed: 3, balance: balance)
        TestLife.pinPeak(&state)
        // Garage cap is 3: founder + 2 fills it.
        state.employees.append(TestPeople.employee(name: "A", weeklySalary: 2_000))
        var roomy = state
        state.employees.append(TestPeople.employee(name: "B", weeklySalary: 2_000))

        Reducer.tick(&state, balance: balance, content: TestContent.tiny())
        Reducer.tick(&roomy, balance: balance, content: TestContent.tiny())
        #expect(abs(Self.morale(roomy) - Self.morale(state) - 6) < 1e-9)
    }

    @Test func anOverdueContractWeighsOnTheTeam() throws {
        var (state, balance, content) = Self.studio(economy: Self.economy())
        var late = state
        late.activeContracts = [ContractJob(
            id: UUID(), clientName: "TestCo",
            requiredCodePts: 10, requiredDesignPts: 10,
            progressCode: 0, progressDesign: 0,
            deadlineDay: -1, payout: 100, penalty: 10, acceptedDay: 0
        )]

        Reducer.tick(&state, balance: balance, content: content)
        Reducer.tick(&late, balance: balance, content: content)
        #expect(abs(Self.morale(state) - Self.morale(late) - 4) < 1e-9)
    }

    @Test func aFounderWhoDisappearsForAWeekIsNoticed() throws {
        var (state, balance, content) = Self.studio(economy: Self.economy())
        state.day = 30
        var absent = state
        absent.life.awayUntilDay = 60
        absent.life.awaySinceDay = 20 // ten days gone
        absent.life.awayReason = "Hospital"
        var justLeft = state
        justLeft.life.awayUntilDay = 60
        justLeft.life.awaySinceDay = 29 // one day gone
        justLeft.life.awayReason = "Hospital"

        Reducer.tick(&state, balance: balance, content: content)
        Reducer.tick(&absent, balance: balance, content: content)
        Reducer.tick(&justLeft, balance: balance, content: content)
        #expect(abs(Self.morale(state) - Self.morale(absent) - 5) < 1e-9)
        #expect(abs(Self.morale(state) - Self.morale(justLeft)) < 1e-9)
    }

    @Test func aYearWithoutARaiseOrAPromotionWearsPeopleDown() throws {
        var (state, balance, content) = Self.studio(
            economy: Self.economy(stagnationDays: 100)
        )
        state.day = 200
        var recognised = state
        recognised.economy.lastRecognitionDay[recognised.employees[1].id] = 150

        Reducer.tick(&state, balance: balance, content: content)
        Reducer.tick(&recognised, balance: balance, content: content)
        #expect(abs(Self.morale(recognised) - Self.morale(state) - 10) < 1e-9)
    }

    @Test func aRaiseResetsTheStagnationClock() throws {
        let balance = TestBalance.make(economy: Self.economy())
        var state = GameState.newGame(companyName: "Acme", seed: 8, balance: balance)
        state.day = 400
        state.employees.append(TestPeople.employee(weeklySalary: 500))
        let id = state.employees[1].id
        #expect(state.economy.lastRecognitionDay[id] == nil)

        Reducer.apply(
            .adjustSalary(employeeID: id, weeklySalary: 700),
            to: &state, balance: balance, content: TestContent.tiny()
        )
        #expect(state.economy.lastRecognitionDay[id] == 400)

        // A pay cut is not recognition.
        state.day = 500
        Reducer.apply(
            .adjustSalary(employeeID: id, weeklySalary: 400),
            to: &state, balance: balance, content: TestContent.tiny()
        )
        #expect(state.economy.lastRecognitionDay[id] == 400)

        // Promotion and training are.
        state.day = 600
        Reducer.apply(.promote(employeeID: id), to: &state, balance: balance, content: TestContent.tiny())
        #expect(state.economy.lastRecognitionDay[id] == 600)
    }

    // MARK: - Resignations

    /// A studio where the only worker is badly underpaid and about to walk.
    static func aboutToQuit(
        economy: BalanceConfig.EconomyBalance
    ) -> (GameState, BalanceConfig, ContentCatalog) {
        var staff = snappingStaff
        staff.quitMoraleThreshold = 45
        staff.quitStreakDays = 2
        var (state, balance, content) = studio(economy: economy, staff: staff, salary: 300)
        state.economy.workPace = .crunch
        return (state, balance, content)
    }

    @Test func peopleGiveNoticeBeforeTheyGo() throws {
        var (state, balance, content) = Self.aboutToQuit(economy: Self.economy())
        let id = state.employees[1].id

        var notice: (UUID, Int)?
        for _ in 0..<6 {
            for event in Reducer.tick(&state, balance: balance, content: content) {
                if case .resignationNotice(let employeeID, _, let respondBy, _) = event {
                    notice = (employeeID, respondBy)
                }
            }
            if notice != nil { break }
        }
        let served = try #require(notice)
        #expect(served.0 == id)
        #expect(served.1 == state.day + 7)
        // They are still on payroll, and the founder can still act.
        #expect(state.employees.count == 2)
        #expect(state.economy.pendingResignation?.employeeID == id)
    }

    @Test func anUnansweredNoticeRunsOutAndTheyLeave() throws {
        var (state, balance, content) = Self.aboutToQuit(economy: Self.economy())
        var quit = false
        for _ in 0..<40 {
            for event in Reducer.tick(&state, balance: balance, content: content) {
                if case .employeeQuit = event { quit = true }
            }
            if quit { break }
        }
        #expect(quit, "an unanswered notice should end in a resignation")
        #expect(state.employees.count == 1, "only the founder is left")
        #expect(state.economy.pendingResignation == nil)
    }

    @Test func aBigEnoughRaiseKeepsThem() throws {
        var (state, balance, content) = Self.aboutToQuit(economy: Self.economy())
        while state.economy.pendingResignation == nil, state.day < 40 {
            Reducer.tick(&state, balance: balance, content: content)
        }
        let pending = try #require(state.economy.pendingResignation)

        // 12% is the bar; 5% is not a counter-offer.
        Reducer.apply(
            .adjustSalary(
                employeeID: pending.employeeID,
                weeklySalary: Int(Double(pending.salaryAtNotice) * 1.05)
            ),
            to: &state, balance: balance, content: content
        )
        #expect(state.economy.pendingResignation != nil, "a token raise is not a counter-offer")

        Reducer.apply(
            .adjustSalary(
                employeeID: pending.employeeID,
                weeklySalary: Int(Double(pending.salaryAtNotice) * 1.5)
            ),
            to: &state, balance: balance, content: content
        )
        #expect(state.economy.pendingResignation == nil, "a real raise should keep them")
        #expect(state.employees[1].lowMoraleStreakDays == 0)
        #expect(state.employees[1].morale > 30, "being fought for lifts morale")
    }

    @Test func aPromotionAlsoAnswersANotice() throws {
        var (state, balance, content) = Self.aboutToQuit(economy: Self.economy())
        while state.economy.pendingResignation == nil, state.day < 40 {
            Reducer.tick(&state, balance: balance, content: content)
        }
        let pending = try #require(state.economy.pendingResignation)
        Reducer.apply(
            .promote(employeeID: pending.employeeID),
            to: &state, balance: balance, content: content
        )
        #expect(state.economy.pendingResignation == nil)
    }

    @Test func onlyOneNoticeIsOpenAtATime() throws {
        var (state, balance, content) = Self.aboutToQuit(economy: Self.economy())
        state.employees.append(TestPeople.employee(name: "Second", weeklySalary: 300))
        var notices = 0
        for _ in 0..<10 {
            for event in Reducer.tick(&state, balance: balance, content: content) {
                if case .resignationNotice = event { notices += 1 }
            }
        }
        #expect(notices == 1, "the second unhappy person waits their turn, got \(notices)")
    }

    @Test func firingSomeoneUnderNoticeClosesIt() throws {
        var (state, balance, content) = Self.aboutToQuit(economy: Self.economy())
        while state.economy.pendingResignation == nil, state.day < 40 {
            Reducer.tick(&state, balance: balance, content: content)
        }
        let pending = try #require(state.economy.pendingResignation)
        Reducer.apply(
            .fire(employeeID: pending.employeeID), to: &state, balance: balance, content: content
        )
        #expect(state.economy.pendingResignation == nil)
        #expect(state.economy.lastRecognitionDay[pending.employeeID] == nil)
    }
}
