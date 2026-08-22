import Foundation
import Testing
import TycoonContent
import TycoonEngine

@Suite("Founder seeding")
struct FounderSeedingTests {
    @Test func newGameSeedsExactlyOneIdleFounder() throws {
        let balance = TestBalance.standard
        let state = GameState.newGame(companyName: "Acme", seed: 7, balance: balance)

        #expect(state.employees.count == 1)
        #expect(state.headcount == 1)
        #expect(state.candidatePool.isEmpty)
        #expect(state.eventLog.isEmpty)

        let founder = try #require(state.employees.first)
        #expect(founder.isFounder)
        #expect(founder.name == "Founder")
        #expect(founder.weeklySalary == 0)
        #expect(founder.assignment == .idle)
        #expect(founder.hiredDay == 0)
        #expect(founder.skills == SkillSet(
            coding: balance.founderCoding,
            design: balance.founderDesign,
            marketing: balance.founderMarketing
        ))
        #expect(founder.skills.total
            == balance.founderCoding + balance.founderDesign + balance.founderMarketing)
        #expect(state.employee(id: founder.id) == founder)
    }

    @Test func founderIdentityIsDeterministicPerSeed() throws {
        let balance = TestBalance.standard
        let a = GameState.newGame(companyName: "Acme", seed: 11, balance: balance)
        let b = GameState.newGame(companyName: "Acme", seed: 11, balance: balance)
        let c = GameState.newGame(companyName: "Acme", seed: 12, balance: balance)

        #expect(a.employees == b.employees)
        #expect(try #require(a.employees.first).id != #require(c.employees.first).id)
    }
}

@Suite("Candidate pool")
struct CandidatePoolTests {
    private let content = TestContent.bundled

    @Test func refreshFollowsCadenceWithBoundedCountsSkillsAndSalaries() throws {
        let balance = TestBalance.standard
        var state = GameState.newGame(companyName: "Acme", seed: 21, balance: balance)

        // No candidates before the first refresh day.
        for _ in 0..<13 { Reducer.tick(&state, balance: balance, content: content) }
        #expect(state.candidatePool.isEmpty)

        let day14Events = Reducer.tick(&state, balance: balance, content: content)
        #expect(day14Events.contains(.candidatesRefreshed(day: 14)))
        #expect(state.eventLog.contains(.candidatesRefreshed(day: 14)))
        #expect((balance.candidateCountMin...balance.candidateCountMax)
            .contains(state.candidatePool.count))

        // Garage at reputation 10: ceiling = 35 + 10 * 0.5 + 0 = 40.
        for candidate in state.candidatePool {
            for skill in [candidate.skills.coding, candidate.skills.design, candidate.skills.marketing] {
                #expect(skill >= 5)
                #expect(skill <= 40)
            }
            #expect(!candidate.name.isEmpty)
            // Salary tracks total skills within the jitter band.
            let baseline = Double(balance.salaryBase)
                + balance.salaryPerSkillPoint * candidate.skills.total
            #expect(Double(candidate.weeklySalary) >= baseline * (1 - balance.salaryJitter) - 0.5)
            #expect(Double(candidate.weeklySalary) <= baseline * (1 + balance.salaryJitter) + 0.5)
        }

        // The next refresh replaces the pool instead of appending to it.
        let firstPool = state.candidatePool
        for _ in 0..<14 { Reducer.tick(&state, balance: balance, content: content) }
        #expect(state.eventLog.contains(.candidatesRefreshed(day: 28)))
        #expect((balance.candidateCountMin...balance.candidateCountMax)
            .contains(state.candidatePool.count))
        #expect(state.candidatePool != firstPool)
    }

    @Test func skillCeilingRespondsToReputationAndOfficeTier() {
        let balance = TestBalance.standard

        func maxSkillAtFirstRefresh(reputation: Double, tier: OfficeTier, seed: UInt64) -> Double {
            var state = GameState.newGame(companyName: "Acme", seed: seed, balance: balance)
            state.company.reputation = reputation
            state.company.officeTier = tier
            for _ in 0..<balance.candidateRefreshDays {
                Reducer.tick(&state, balance: balance, content: content)
            }
            return state.candidatePool
                .flatMap { [$0.skills.coding, $0.skills.design, $0.skills.marketing] }
                .max() ?? 0
        }

        // Low reputation in the garage keeps every roll at or below 40.
        for seed: UInt64 in 1...5 {
            #expect(maxSkillAtFirstRefresh(reputation: 10, tier: .garage, seed: seed) <= 40)
        }

        // High reputation on a campus raises the ceiling (35 + 40 + 30, clamped
        // to 100) far enough that rolls above the garage ceiling appear.
        var sawAboveGarageCeiling = false
        for seed: UInt64 in 1...5 {
            let rolled = maxSkillAtFirstRefresh(reputation: 80, tier: .campus, seed: seed)
            #expect(rolled <= 100)
            if rolled > 40 { sawAboveGarageCeiling = true }
        }
        #expect(sawAboveGarageCeiling)
    }

    @Test func poolIsDeterministicPerSeed() {
        let balance = TestBalance.standard

        func poolAtFirstRefresh(seed: UInt64) -> [Candidate] {
            var state = GameState.newGame(companyName: "Acme", seed: seed, balance: balance)
            for _ in 0..<balance.candidateRefreshDays {
                Reducer.tick(&state, balance: balance, content: content)
            }
            return state.candidatePool
        }

        #expect(poolAtFirstRefresh(seed: 33) == poolAtFirstRefresh(seed: 33))
        #expect(poolAtFirstRefresh(seed: 33) != poolAtFirstRefresh(seed: 34))
    }
}

@Suite("Hire, fire, and assign")
struct HireFireAssignTests {
    private let content = TestContent.bundled

    @Test func hireMovesCandidateToEmployeesAndEmitsEvent() throws {
        let balance = TestBalance.standard
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        state.day = 5
        let candidate = TestPeople.candidate()
        state.candidatePool = [candidate, TestPeople.candidate(name: "Grace Hopper")]

        let events = Reducer.apply(
            .hire(candidateID: candidate.id), to: &state, balance: balance, content: content
        )

        #expect(state.employees.count == 2)
        #expect(state.headcount == 2)
        #expect(state.candidatePool.count == 1)
        #expect(state.candidatePool.first?.name == "Grace Hopper")

        let hired = try #require(state.employee(id: candidate.id))
        #expect(hired.name == candidate.name)
        #expect(hired.skills == candidate.skills)
        #expect(hired.weeklySalary == candidate.weeklySalary)
        #expect(hired.appearanceSeed == candidate.appearanceSeed)
        #expect(!hired.isFounder)
        #expect(hired.hiredDay == 5)
        // No product in development, so the new hire starts idle.
        #expect(hired.assignment == .idle)

        #expect(events == [.hired(employeeID: candidate.id, day: 5)])
        #expect(state.eventLog.contains(.hired(employeeID: candidate.id, day: 5)))
    }

    @Test func hireDuringDevelopmentAutoAssignsToTheProduct() throws {
        let balance = TestBalance.standard
        var state = GameState.newGame(companyName: "Acme", seed: 2, balance: balance)
        Reducer.apply(
            .startProduct(typeID: "mobile_app", topicID: "fitness", name: "FitTrack", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        let productID = try #require(state.productInDevelopment?.id)

        let candidate = TestPeople.candidate()
        state.candidatePool = [candidate]
        Reducer.apply(.hire(candidateID: candidate.id), to: &state, balance: balance, content: content)

        #expect(state.employee(id: candidate.id)?.assignment == .product(productID))
    }

    @Test func hireIsBlockedAtHeadcountCapAndForUnknownCandidates() {
        let balance = TestBalance.standard
        var state = GameState.newGame(companyName: "Acme", seed: 3, balance: balance)

        // Unknown candidate id: ignored.
        #expect(Reducer.apply(
            .hire(candidateID: UUID()), to: &state, balance: balance, content: content
        ).isEmpty)
        #expect(state.employees.count == 1)

        // Fill the garage (cap 3): founder + 2 workers.
        state.employees.append(TestPeople.employee())
        state.employees.append(TestPeople.employee(name: "Second"))
        let candidate = TestPeople.candidate()
        state.candidatePool = [candidate]

        let events = Reducer.apply(
            .hire(candidateID: candidate.id), to: &state, balance: balance, content: content
        )

        #expect(events.isEmpty)
        #expect(state.employees.count == 3)
        #expect(state.candidatePool == [candidate])
        #expect(state.eventLog.isEmpty)
    }

    @Test func fireRemovesEmployeeButNeverTheFounder() throws {
        let balance = TestBalance.standard
        var state = GameState.newGame(companyName: "Acme", seed: 4, balance: balance)
        state.day = 9
        let founderID = try #require(state.employees.first).id
        let worker = TestPeople.employee()
        state.employees.append(worker)

        // The founder can never be fired.
        #expect(Reducer.apply(
            .fire(employeeID: founderID), to: &state, balance: balance, content: content
        ).isEmpty)
        #expect(state.employees.count == 2)

        // Unknown ids are ignored.
        #expect(Reducer.apply(
            .fire(employeeID: UUID()), to: &state, balance: balance, content: content
        ).isEmpty)
        #expect(state.employees.count == 2)

        // A regular employee is removed with an event.
        let events = Reducer.apply(
            .fire(employeeID: worker.id), to: &state, balance: balance, content: content
        )
        #expect(events == [.fired(employeeID: worker.id, day: 9)])
        #expect(state.employees.count == 1)
        #expect(state.employee(id: worker.id) == nil)
        #expect(state.eventLog.contains(.fired(employeeID: worker.id, day: 9)))
    }

    @Test func assignRoundTripsThroughEveryAssignmentCase() throws {
        let balance = TestBalance.standard
        var state = GameState.newGame(companyName: "Acme", seed: 5, balance: balance)
        let worker = TestPeople.employee()
        state.employees.append(worker)

        // Unknown employee: ignored.
        #expect(Reducer.apply(
            .assign(employeeID: UUID(), to: .research), to: &state, balance: balance, content: content
        ).isEmpty)

        let contractID = UUID()
        let productID = UUID()
        for assignment: Assignment in [.research, .contract(contractID), .product(productID), .idle] {
            let events = Reducer.apply(
                .assign(employeeID: worker.id, to: assignment),
                to: &state, balance: balance, content: content
            )
            #expect(events.isEmpty)
            #expect(state.employee(id: worker.id)?.assignment == assignment)
        }
        #expect(state.eventLog.isEmpty)
    }
}

@Suite("Employee output")
struct EmployeeOutputTests {
    @Test func assignedOutputMatchesFormulaTwoEmployeesSumAndIdleContributesNothing() throws {
        let balance = TestBalance.make(bugChanceBase: 0, skillGrowthRate: 0, life: TestBalance.quietLife)
        let content = TestContent.tiny(designPts: 100, codePts: 100, polishPts: 100)
        var state = GameState.newGame(companyName: "Acme", seed: 6, balance: balance)
        TestLife.pinPeak(&state) // founder output multiplier exactly 1

        Reducer.apply(
            .startProduct(
                typeID: "tool", topicID: "testing", name: "T",
                focus: PhaseFocus(design: 0.5, code: 0.3, polish: 0.2)
            ),
            to: &state, balance: balance, content: content
        )
        let productID = try #require(state.productInDevelopment?.id)
        let founderID = try #require(state.employees.first).id

        // Park the founder and add an idle worker: nobody produces.
        Reducer.apply(
            .assign(employeeID: founderID, to: .research),
            to: &state, balance: balance, content: content
        )
        let worker = TestPeople.employee(coding: 50, design: 25, marketing: 0)
        state.employees.append(worker)

        func devProgress() throws -> DevProgress {
            guard case .development(let dev) = try #require(state.product(id: productID)).stage else {
                Issue.record("expected a development stage")
                throw CancellationError()
            }
            return dev
        }

        Reducer.tick(&state, balance: balance, content: content)
        var dev = try devProgress()
        #expect(dev.designPts == 0)
        #expect(dev.codePts == 0)
        #expect(dev.polishPts == 0)

        // One assigned worker (coding 50, design 25), focus 0.5/0.3/0.2:
        //   design = 0.5 * (1 + 25/25)          = 1.0
        //   code   = 0.3 * (1 + 50/25)          = 0.9
        //   polish = 0.2 * (1 + (75/2)/25)      = 0.5
        Reducer.apply(
            .assign(employeeID: worker.id, to: .product(productID)),
            to: &state, balance: balance, content: content
        )
        Reducer.tick(&state, balance: balance, content: content)
        dev = try devProgress()
        #expect(abs(dev.designPts - 1.0) < 1e-9)
        #expect(abs(dev.codePts - 0.9) < 1e-9)
        #expect(abs(dev.polishPts - 0.5) < 1e-9)

        // Founder joins (coding 40, design 30):
        //   design += 0.5 * (1 + 30/25)         = 1.1
        //   code   += 0.3 * (1 + 40/25)         = 0.78
        //   polish += 0.2 * (1 + (70/2)/25)     = 0.48
        Reducer.apply(
            .assign(employeeID: founderID, to: .product(productID)),
            to: &state, balance: balance, content: content
        )
        Reducer.tick(&state, balance: balance, content: content)
        dev = try devProgress()
        #expect(abs(dev.designPts - (1.0 + 1.0 + 1.1)) < 1e-9)
        #expect(abs(dev.codePts - (0.9 + 0.9 + 0.78)) < 1e-9)
        #expect(abs(dev.polishPts - (0.5 + 0.5 + 0.48)) < 1e-9)
    }
}

@Suite("Skill growth")
struct SkillGrowthTests {
    @Test func skillsGrowOnlyOnProductiveDaysWithCorrectMagnitude() throws {
        let balance = TestBalance.make(bugChanceBase: 0)
        let content = TestContent.tiny(designPts: 1000, codePts: 1000, polishPts: 1000)
        var state = GameState.newGame(companyName: "Acme", seed: 8, balance: balance)
        let founderID = try #require(state.employees.first).id

        // Idle day: no growth.
        Reducer.tick(&state, balance: balance, content: content)
        #expect(state.employees[0].skills == SkillSet(coding: 40, design: 30, marketing: 20))

        // Productive balanced day: coding and design grow toward 100,
        // marketing feeds no pool and never grows.
        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        Reducer.tick(&state, balance: balance, content: content)
        let grown = state.employees[0].skills
        #expect(abs(grown.coding - (40 + 0.08 * (1 - 40.0 / 100))) < 1e-9)
        #expect(abs(grown.design - (30 + 0.08 * (1 - 30.0 / 100))) < 1e-9)
        #expect(grown.marketing == 20)

        // On research (a productive day since M4): coding and design grow by
        // the same rule; marketing still never grows.
        Reducer.apply(
            .assign(employeeID: founderID, to: .research),
            to: &state, balance: balance, content: content
        )
        Reducer.tick(&state, balance: balance, content: content)
        let afterResearch = state.employees[0].skills
        #expect(abs(afterResearch.coding - (grown.coding + 0.08 * (1 - grown.coding / 100))) < 1e-9)
        #expect(abs(afterResearch.design - (grown.design + 0.08 * (1 - grown.design / 100))) < 1e-9)
        #expect(afterResearch.marketing == 20)

        // Idle: a non-productive day leaves skills unchanged.
        Reducer.apply(
            .assign(employeeID: founderID, to: .idle),
            to: &state, balance: balance, content: content
        )
        Reducer.tick(&state, balance: balance, content: content)
        #expect(state.employees[0].skills == afterResearch)
    }

    @Test func onlySkillsThatFedAPoolGrow() throws {
        let balance = TestBalance.make(bugChanceBase: 0)
        let content = TestContent.tiny(designPts: 1000, codePts: 1000, polishPts: 1000)
        var state = GameState.newGame(companyName: "Acme", seed: 9, balance: balance)

        // All-code focus: only the code pool is fed, so only coding grows.
        Reducer.apply(
            .startProduct(
                typeID: "tool", topicID: "testing", name: "T",
                focus: PhaseFocus(design: 0, code: 1, polish: 0)
            ),
            to: &state, balance: balance, content: content
        )
        Reducer.tick(&state, balance: balance, content: content)
        let skills = state.employees[0].skills
        #expect(skills.coding > 40)
        #expect(skills.design == 30)
        #expect(skills.marketing == 20)
    }

    @Test func skillGrowthCapsAtOneHundred() throws {
        // An absurd growth rate overshoots in one day; the cap holds at 100.
        let balance = TestBalance.make(bugChanceBase: 0, skillGrowthRate: 200)
        let content = TestContent.tiny(designPts: 1000, codePts: 1000, polishPts: 1000)
        var state = GameState.newGame(companyName: "Acme", seed: 10, balance: balance)

        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        Reducer.tick(&state, balance: balance, content: content)
        #expect(state.employees[0].skills.coding == 100)
        #expect(state.employees[0].skills.design == 100)

        // Further productive days keep it pinned at 100.
        Reducer.tick(&state, balance: balance, content: content)
        #expect(state.employees[0].skills.coding == 100)
        #expect(state.employees[0].skills.design == 100)
    }
}

@Suite("Payroll")
struct PayrollTests {
    private let content = TestContent.bundled

    @Test func weeklyPayrollEntryTotalsAllSalaries() throws {
        let balance = TestBalance.standard
        var state = GameState.newGame(companyName: "Acme", seed: 12, balance: balance)
        state.employees.append(TestPeople.employee(weeklySalary: 500))
        state.employees.append(TestPeople.employee(name: "Second", weeklySalary: 700))

        for _ in 0..<7 { Reducer.tick(&state, balance: balance, content: content) }

        let payrollEntries = state.ledger.entries.filter { $0.category == .payroll }
        #expect(payrollEntries == [
            LedgerEntry(day: 7, amount: -1200, category: .payroll, label: "Payroll")
        ])
        #expect(state.company.cash == balance.startingCash - balance.weeklyOperatingCost - 1200)

        for _ in 0..<7 { Reducer.tick(&state, balance: balance, content: content) }
        #expect(state.ledger.entries.filter { $0.category == .payroll }.count == 2)
        #expect(state.company.cash == balance.startingCash - 2 * (balance.weeklyOperatingCost + 1200))
    }

    @Test func founderOnlyCompanyPostsNoPayrollEntry() {
        let balance = TestBalance.standard
        var state = GameState.newGame(companyName: "Acme", seed: 13, balance: balance)

        for _ in 0..<7 { Reducer.tick(&state, balance: balance, content: content) }

        #expect(state.ledger.entries.filter { $0.category == .payroll }.isEmpty)
        #expect(state.company.cash == balance.startingCash - balance.weeklyOperatingCost)
    }

    @MainActor
    @Test func weeklyBurnIncludesPayroll() {
        let balance = TestBalance.make(weeklyOperatingCost: 400, garageRent: 150)
        var state = GameState.newGame(companyName: "Acme", seed: 14, balance: balance)
        state.employees.append(TestPeople.employee(weeklySalary: 500))
        state.employees.append(TestPeople.employee(name: "Second", weeklySalary: 700))

        let engine = GameEngine(state: state, balance: balance, content: TestContent.bundled)
        #expect(engine.weeklyBurn == 400 + 150 + 1200)
    }
}

@Suite("Auto-assignment")
struct AutoAssignmentTests {
    @Test func startProductAutoAssignsIdleEmployeesAndShipSweepsThemBackToIdle() throws {
        let balance = TestBalance.make(bugChanceBase: 0, skillGrowthRate: 0)
        let content = TestContent.tiny(designPts: 2, codePts: 2, polishPts: 2)
        var state = GameState.newGame(companyName: "Acme", seed: 15, balance: balance)
        let founderID = try #require(state.employees.first).id
        let worker = TestPeople.employee(coding: 50, design: 25)
        let researcher = TestPeople.employee(name: "Researcher", assignment: .research)
        state.employees.append(worker)
        state.employees.append(researcher)

        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        let productID = try #require(state.productInDevelopment?.id)

        // Every idle employee (founder included) is pulled onto the product;
        // non-idle assignments are left alone.
        #expect(state.employee(id: founderID)?.assignment == .product(productID))
        #expect(state.employee(id: worker.id)?.assignment == .product(productID))
        #expect(state.employee(id: researcher.id)?.assignment == .research)

        // One day clears the tiny code gate (founder 0.867 + worker 1.0 >= 1.2).
        Reducer.tick(&state, balance: balance, content: content)
        let shipEvents = Reducer.apply(
            .ship(productID: productID), to: &state, balance: balance, content: content
        )
        #expect(!shipEvents.isEmpty)

        // The next daily sweep resets stale product assignments to idle.
        Reducer.tick(&state, balance: balance, content: content)
        #expect(state.employee(id: founderID)?.assignment == .idle)
        #expect(state.employee(id: worker.id)?.assignment == .idle)
        #expect(state.employee(id: researcher.id)?.assignment == .research)
    }

    @Test func assignmentToNonexistentProductSweepsToIdle() throws {
        let balance = TestBalance.standard
        let content = TestContent.bundled
        var state = GameState.newGame(companyName: "Acme", seed: 16, balance: balance)
        let worker = TestPeople.employee()
        state.employees.append(worker)

        Reducer.apply(
            .assign(employeeID: worker.id, to: .product(UUID())),
            to: &state, balance: balance, content: content
        )
        Reducer.tick(&state, balance: balance, content: content)

        #expect(state.employee(id: worker.id)?.assignment == .idle)
    }
}
