import Foundation
import Testing
import TycoonContent
import TycoonEngine

// Milestone 8 "Company depth": employee roles shape builder output,
// departments (Legal / People & HR / Operations) derive from the payroll
// and grant company-wide effects, and office amenities cost cash up front
// plus weekly upkeep in exchange for morale and founder health.

/// Shared builders for the company-depth suites.
private enum Depth {
    /// A balance with the shipped company block and every other dynamic
    /// neutral, no bug rolls, no skill growth, and no hype decay, so one
    /// day's output can be hand-computed exactly.
    static func balance(
        company: BalanceConfig.CompanyBalance = .standard,
        staff: BalanceConfig.StaffBalance = TestBalance.frozenStaff,
        candidateRefreshDays: Int = 10_000,
        contractOfferRefreshDays: Int = 10_000,
        garageRent: Int = 0
    ) -> BalanceConfig {
        TestBalance.make(
            garageRent: garageRent,
            bugChanceBase: 0,
            skillGrowthRate: 0,
            candidateRefreshDays: candidateRefreshDays,
            contractOfferRefreshDays: contractOfferRefreshDays,
            hypeDecayRate: 0,
            life: TestBalance.quietLife,
            staff: staff,
            company: company
        )
    }

    /// A product that never ships on its own (huge point pools).
    static let content = TestContent.tiny(designPts: 1_000, codePts: 1_000, polishPts: 1_000)

    /// The shipped role yields, as the spec defines them (code, design, polish).
    static let yields: [EmployeeRole: (code: Double, design: Double, polish: Double)] = [
        .founder: (1.0, 1.0, 1.0),
        .backend: (1.4, 0.5, 1.0),
        .frontend: (1.1, 1.1, 0.9),
        .designer: (0.5, 1.5, 1.0),
        .qa: (0.6, 0.6, 1.6),
        .marketer: (0.3, 0.3, 0.3),
        .lawyer: (0.3, 0.3, 0.3),
        .hr: (0.3, 0.3, 0.3),
        .ops: (0.3, 0.3, 0.3),
    ]

    /// Daily base points for the default test worker (coding 50, design
    /// 25) with `employeeBasePoints` 1 and `skillYieldDivisor` 25.
    static let codeBase = 3.0 // 1 + 50/25
    static let designBase = 2.0 // 1 + 25/25
    static let polishBase = 2.5 // 1 + (50+25)/2/25

    /// A state with one in-development product worked only by `worker`
    /// (the founder is parked on research).
    static func productState(
        worker: Employee,
        balance: BalanceConfig,
        seed: UInt64 = 3
    ) -> GameState {
        var state = GameState.newGame(companyName: "Acme", seed: seed, balance: balance)
        TestLife.pinPeak(&state)
        state.employees.append(worker)
        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "Gizmo", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        let founderID = state.employees[0].id
        Reducer.apply(
            .assign(employeeID: founderID, to: .research),
            to: &state, balance: balance, content: content
        )
        return state
    }

    static func dev(_ state: GameState) -> DevProgress? {
        guard case .development(let dev) = state.products.first?.stage else { return nil }
        return dev
    }

    /// Ticks one day with the product focused entirely on one pool and
    /// returns that pool's gain.
    static func poolGain(
        focus: PhaseFocus,
        read: (DevProgress) -> Double,
        state: inout GameState,
        balance: BalanceConfig
    ) -> Double {
        let id = state.products[0].id
        Reducer.apply(.setPhaseFocus(productID: id, focus: focus), to: &state, balance: balance, content: content)
        let before = dev(state).map(read) ?? 0
        Reducer.tick(&state, balance: balance, content: content)
        return (dev(state).map(read) ?? 0) - before
    }

    static let codeOnly = PhaseFocus(design: 0, code: 1, polish: 0)
    static let designOnly = PhaseFocus(design: 1, code: 0, polish: 0)
    static let polishOnly = PhaseFocus(design: 0, code: 0, polish: 1)

    static func setOpenBugs(_ bugs: Int, _ state: inout GameState) {
        guard case .development(var dev) = state.products[0].stage else { return }
        dev.openBugs = bugs
        state.products[0].stage = .development(dev)
    }

    /// Strips top-level keys from an encoded JSON object.
    static func stripping(_ keys: [String], from data: Data) throws -> Data {
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        for key in keys { object.removeValue(forKey: key) }
        return try JSONSerialization.data(withJSONObject: object)
    }
}

// MARK: - Roles

@Suite("Employee roles")
struct EmployeeRoleTests {
    @Test func roleDepartmentAndAmenityMetadata() {
        #expect(EmployeeRole.allCases == [
            .founder, .frontend, .backend, .designer, .qa, .marketer, .lawyer, .hr, .ops,
        ])
        #expect(EmployeeRole.founder.displayName == "Founder")
        #expect(EmployeeRole.frontend.displayName == "Frontend Dev")
        #expect(EmployeeRole.backend.displayName == "Backend Dev")
        #expect(EmployeeRole.designer.displayName == "Designer")
        #expect(EmployeeRole.qa.displayName == "QA Engineer")
        #expect(EmployeeRole.marketer.displayName == "Marketer")
        #expect(EmployeeRole.lawyer.displayName == "Lawyer")
        #expect(EmployeeRole.hr.displayName == "HR Manager")
        #expect(EmployeeRole.ops.displayName == "Ops Manager")

        for role in [EmployeeRole.founder, .frontend, .backend, .designer, .qa] {
            #expect(role.isBuilder, Comment(rawValue: role.rawValue))
            #expect(role.department == nil, Comment(rawValue: role.rawValue))
        }
        for role in [EmployeeRole.marketer, .lawyer, .hr, .ops] {
            #expect(!role.isBuilder, Comment(rawValue: role.rawValue))
        }
        #expect(EmployeeRole.marketer.department == nil)
        #expect(EmployeeRole.lawyer.department == .legal)
        #expect(EmployeeRole.hr.department == .hr)
        #expect(EmployeeRole.ops.department == .ops)

        #expect(Department.allCases == [.legal, .hr, .ops])
        #expect(Department.legal.displayName == "Legal")
        #expect(Department.hr.displayName == "People & HR")
        #expect(Department.ops.displayName == "Operations")

        #expect(Amenity.allCases == [.gameRoom, .cafeteria, .shuttle, .gym])
        #expect(Amenity.gameRoom.displayName == "Game Room")
        #expect(Amenity.cafeteria.displayName == "Cafeteria")
        #expect(Amenity.shuttle.displayName == "Shuttle Service")
        #expect(Amenity.gym.displayName == "Gym")
    }

    @Test func everyRoleRoutesProductOutputByItsYields() {
        let balance = Depth.balance()
        for (role, yield) in Depth.yields where role != .founder {
            let worker = TestPeople.employee(role: role)
            var state = Depth.productState(worker: worker, balance: balance)
            let tag = Comment(rawValue: role.rawValue)

            let code = Depth.poolGain(focus: Depth.codeOnly, read: \.codePts, state: &state, balance: balance)
            #expect(abs(code - yield.code * Depth.codeBase) < 1e-9, tag)

            let design = Depth.poolGain(focus: Depth.designOnly, read: \.designPts, state: &state, balance: balance)
            #expect(abs(design - yield.design * Depth.designBase) < 1e-9, tag)

            let polish = Depth.poolGain(focus: Depth.polishOnly, read: \.polishPts, state: &state, balance: balance)
            #expect(abs(polish - yield.polish * Depth.polishBase) < 1e-9, tag)
        }
    }

    @Test func founderYieldsAreNeutral() {
        let balance = Depth.balance()
        var state = GameState.newGame(companyName: "Acme", seed: 3, balance: balance)
        TestLife.pinPeak(&state)
        #expect(state.employees[0].role == .founder)
        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "Gizmo", focus: .balanced),
            to: &state, balance: balance, content: Depth.content
        )
        // Founder coding 40: 1 + 40/25 = 2.6 code points, yield 1.0.
        let code = Depth.poolGain(focus: Depth.codeOnly, read: \.codePts, state: &state, balance: balance)
        #expect(abs(code - 2.6) < 1e-9)
    }

    @Test func everyRoleRoutesContractOutputByItsYields() {
        let balance = Depth.balance()
        for (role, yield) in Depth.yields where role != .founder {
            var state = GameState.newGame(companyName: "Acme", seed: 3, balance: balance)
            let jobID = UUID()
            state.activeContracts.append(ContractJob(
                id: jobID, clientName: "TestCo",
                requiredCodePts: 1_000, requiredDesignPts: 1_000,
                progressCode: 0, progressDesign: 0,
                deadlineDay: 1_000, payout: 1_000, penalty: 300, acceptedDay: 0
            ))
            state.employees.append(TestPeople.employee(role: role, assignment: .contract(jobID)))

            Reducer.tick(&state, balance: balance, content: Depth.content)

            let job = state.activeContracts[0]
            let tag = Comment(rawValue: role.rawValue)
            #expect(abs(job.progressCode - yield.code * Depth.codeBase) < 1e-9, tag)
            #expect(abs(job.progressDesign - yield.design * Depth.designBase) < 1e-9, tag)
        }
    }

    @Test func researchOutputIgnoresRoles() {
        let balance = Depth.balance()
        func banked(role: EmployeeRole) -> Double {
            var state = GameState.newGame(companyName: "Acme", seed: 3, balance: balance)
            state.employees.append(TestPeople.employee(role: role, assignment: .research))
            Reducer.tick(&state, balance: balance, content: Depth.content)
            return state.research.banked
        }
        // 0.5 + 50/40 + 25/80 = 2.0625 regardless of role.
        #expect(abs(banked(role: .designer) - 2.0625) < 1e-9)
        #expect(abs(banked(role: .lawyer) - 2.0625) < 1e-9)
    }

    @Test func qaPolishFixesTwoBugsPerPoint() {
        let balance = Depth.balance()

        // QA alone: polish 1.6 × 2.5 = 4 points crossed → 8 bugs fixed.
        var qa = Depth.productState(worker: TestPeople.employee(role: .qa), balance: balance)
        Depth.setOpenBugs(10, &qa)
        _ = Depth.poolGain(focus: Depth.polishOnly, read: \.polishPts, state: &qa, balance: balance)
        #expect(Depth.dev(qa)?.openBugs == 2)

        // A backend dev alone: 2.5 points → 2 crossed → 2 bugs fixed.
        var backend = Depth.productState(worker: TestPeople.employee(role: .backend), balance: balance)
        Depth.setOpenBugs(10, &backend)
        _ = Depth.poolGain(focus: Depth.polishOnly, read: \.polishPts, state: &backend, balance: balance)
        #expect(Depth.dev(backend)?.openBugs == 8)

        // Mixed crew: 6.5 points, 6 crossed × (2.5×1 + 4×2)/6.5 ≈ 9.69 → 10 fixed.
        var mixed = Depth.productState(worker: TestPeople.employee(role: .qa), balance: balance)
        let productID = mixed.products[0].id
        mixed.employees.append(TestPeople.employee(
            name: "Dev", role: .backend, assignment: .product(productID)
        ))
        Depth.setOpenBugs(20, &mixed)
        _ = Depth.poolGain(focus: Depth.polishOnly, read: \.polishPts, state: &mixed, balance: balance)
        #expect(Depth.dev(mixed)?.openBugs == 10)
    }

    @Test func marketerOnAProductAddsDailyHype() {
        let balance = Depth.balance()
        let marketer = TestPeople.employee(role: .marketer, marketing: 50)
        var state = Depth.productState(worker: marketer, balance: balance)

        Reducer.tick(&state, balance: balance, content: Depth.content)
        // 0.4 × (1 + 50/100) = 0.6 per day, no decay in this balance.
        #expect(abs((Depth.dev(state)?.hype ?? 0) - 0.6) < 1e-9)
        Reducer.tick(&state, balance: balance, content: Depth.content)
        #expect(abs((Depth.dev(state)?.hype ?? 0) - 1.2) < 1e-9)

        // A marketer on research adds nothing; neither does a builder.
        var parked = Depth.productState(worker: TestPeople.employee(role: .marketer, marketing: 50), balance: balance)
        Reducer.apply(
            .assign(employeeID: parked.employees[1].id, to: .research),
            to: &parked, balance: balance, content: Depth.content
        )
        Reducer.tick(&parked, balance: balance, content: Depth.content)
        #expect(Depth.dev(parked)?.hype == 0)

        var builder = Depth.productState(worker: TestPeople.employee(role: .backend, marketing: 50), balance: balance)
        Reducer.tick(&builder, balance: balance, content: Depth.content)
        #expect(Depth.dev(builder)?.hype == 0)
    }
}

// MARK: - Candidates

@Suite("Candidate roles")
struct CandidateRoleTests {
    /// Refreshes once with only the given roles weighted, at `tier`.
    private func pool(
        weights: [String: Int],
        minTiers: [String: OfficeTier] = BalanceConfig.CompanyBalance.standard.candidateRoleMinTier,
        tier: OfficeTier = .garage,
        seed: UInt64
    ) -> [Candidate] {
        var company = BalanceConfig.CompanyBalance.standard
        company.candidateRoleWeights = weights
        company.candidateRoleMinTier = minTiers
        let balance = TestBalance.make(company: company)
        var state = GameState.newGame(companyName: "Acme", seed: seed, balance: balance)
        state.company.officeTier = tier
        for _ in 0..<balance.candidateRefreshDays {
            Reducer.tick(&state, balance: balance, content: TestContent.tiny())
        }
        return state.candidatePool
    }

    @Test func rolesRollByWeightBehindTheOfficeTierGate() {
        let weights = [EmployeeRole.frontend.rawValue: 1, EmployeeRole.lawyer.rawValue: 1]

        // Lawyers need a loft: in the garage the whole pool is frontend.
        for seed in 1...10 as ClosedRange<UInt64> {
            let garage = pool(weights: weights, tier: .garage, seed: seed)
            #expect(!garage.isEmpty)
            #expect(garage.allSatisfy { $0.role == .frontend }, Comment(rawValue: "seed \(seed)"))
        }

        // In the loft both roles roll, and nothing outside the weights.
        var seen: Set<EmployeeRole> = []
        for seed in 1...30 as ClosedRange<UInt64> {
            for candidate in pool(weights: weights, tier: .loft, seed: seed) {
                seen.insert(candidate.role)
            }
        }
        #expect(seen == [.frontend, .lawyer])

        // Deterministic per seed (roles included), different across seeds.
        #expect(pool(weights: weights, tier: .loft, seed: 33) == pool(weights: weights, tier: .loft, seed: 33))
        #expect(pool(weights: weights, tier: .loft, seed: 33) != pool(weights: weights, tier: .loft, seed: 34))
    }

    @Test func theShippedWeightsNeverRollTheFounderRole() {
        for seed in 1...10 as ClosedRange<UInt64> {
            let campus = pool(weights: BalanceConfig.CompanyBalance.standard.candidateRoleWeights, tier: .campus, seed: seed)
            #expect(campus.allSatisfy { $0.role != .founder })
        }
    }

    @Test func builderRollsBiasTheirPrimarySkillCeiling() {
        // Garage, reputation 10: ceiling 35 + 5 = 40 before any bias.
        func skills(role: EmployeeRole) -> [SkillSet] {
            (1...30 as ClosedRange<UInt64>).flatMap { seed in
                pool(weights: [role.rawValue: 1], minTiers: [:], seed: seed).map(\.skills)
            }
        }

        let backend = skills(role: .backend)
        #expect(backend.allSatisfy { $0.coding <= 55 && $0.design <= 40 && $0.marketing <= 40 })
        #expect(backend.contains { $0.coding > 40 })

        let frontend = skills(role: .frontend)
        #expect(frontend.allSatisfy { $0.coding <= 55 && $0.design <= 40 })
        #expect(frontend.contains { $0.coding > 40 })

        let qa = skills(role: .qa)
        #expect(qa.allSatisfy { $0.coding <= 55 && $0.design <= 40 })

        let designer = skills(role: .designer)
        #expect(designer.allSatisfy { $0.design <= 55 && $0.coding <= 40 && $0.marketing <= 40 })
        #expect(designer.contains { $0.design > 40 })

        let marketer = skills(role: .marketer)
        #expect(marketer.allSatisfy { $0.marketing <= 60 && $0.coding <= 40 && $0.design <= 40 })
        #expect(marketer.contains { $0.marketing > 40 })

        for role in [EmployeeRole.lawyer, .hr, .ops] {
            let flat = skills(role: role)
            #expect(flat.allSatisfy { $0.coding <= 40 && $0.design <= 40 && $0.marketing <= 40 },
                    Comment(rawValue: role.rawValue))
        }
    }

    @Test func supportRolesAskForALowerSalary() {
        let balance = TestBalance.make(company: .standard)
        func salaryRatios(role: EmployeeRole) -> [Double] {
            (1...30 as ClosedRange<UInt64>).flatMap { seed in
                pool(weights: [role.rawValue: 1], minTiers: [:], seed: seed).map { candidate in
                    let market = Double(balance.salaryBase) + balance.salaryPerSkillPoint * candidate.skills.total
                    return Double(candidate.weeklySalary) / market
                }
            }
        }
        // Lawyers: jitter ±10% × 0.9 → 0.81...0.99 (plus rounding slack).
        let lawyers = salaryRatios(role: .lawyer)
        #expect(lawyers.allSatisfy { $0 >= 0.80 && $0 <= 1.0 })
        #expect(lawyers.contains { $0 < 0.9 })
        // Builders keep the plain formula: 0.9...1.1.
        let backends = salaryRatios(role: .backend)
        #expect(backends.allSatisfy { $0 >= 0.89 && $0 <= 1.11 })
    }

    @Test func hiringCarriesTheRoleOver() {
        let balance = TestBalance.standard
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        let candidate = TestPeople.candidate(role: .qa)
        state.candidatePool = [candidate]

        Reducer.apply(.hire(candidateID: candidate.id), to: &state, balance: balance, content: TestContent.tiny())
        #expect(state.employees.last?.role == .qa)
    }

    @Test func oldSavesInferRolesFromSkills() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        // Employees: the founder flag wins, then coding vs. design.
        let balance = TestBalance.standard
        let founder = GameState.newGame(companyName: "Acme", seed: 1, balance: balance).employees[0]
        let legacyFounder = try Depth.stripping(["role"], from: try encoder.encode(founder))
        #expect(try JSONDecoder().decode(Employee.self, from: legacyFounder).role == .founder)

        let coder = TestPeople.employee(coding: 50, design: 25)
        let legacyCoder = try Depth.stripping(["role"], from: try encoder.encode(coder))
        #expect(try JSONDecoder().decode(Employee.self, from: legacyCoder).role == .backend)

        let artist = TestPeople.employee(coding: 10, design: 20)
        let legacyArtist = try Depth.stripping(["role"], from: try encoder.encode(artist))
        #expect(try JSONDecoder().decode(Employee.self, from: legacyArtist).role == .designer)

        // Candidates: the same skill inference.
        let candidate = TestPeople.candidate(coding: 30, design: 20)
        let legacyCandidate = try Depth.stripping(["role"], from: try encoder.encode(candidate))
        #expect(try JSONDecoder().decode(Candidate.self, from: legacyCandidate).role == .backend)
        let legacyDesigner = try Depth.stripping(
            ["role"], from: try encoder.encode(TestPeople.candidate(coding: 5, design: 20))
        )
        #expect(try JSONDecoder().decode(Candidate.self, from: legacyDesigner).role == .designer)

        // An explicit role round-trips byte-identically.
        let lawyer = TestPeople.employee(role: .lawyer)
        let data = try encoder.encode(lawyer)
        let decoded = try JSONDecoder().decode(Employee.self, from: data)
        #expect(decoded == lawyer)
        #expect(try encoder.encode(decoded) == data)
    }
}

// MARK: - Departments

@Suite("Departments")
struct DepartmentTests {
    private let content = TestContent.tiny()

    @Test func departmentsDeriveFromTheRolesOnPayroll() {
        let balance = Depth.balance()
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        #expect(state.activeDepartments.isEmpty)
        #expect(!state.hasDepartment(.legal))

        state.employees.append(TestPeople.employee(role: .lawyer))
        #expect(state.activeDepartments == [.legal])
        #expect(state.hasDepartment(.legal))
        #expect(!state.hasDepartment(.hr))

        state.employees.append(TestPeople.employee(role: .hr))
        state.employees.append(TestPeople.employee(role: .ops))
        #expect(state.activeDepartments == [.legal, .hr, .ops])
        #expect(state.hasDepartment(.ops))
    }

    @Test func formingAndDissolvingEmitEventsOnTheDailyTick() {
        let balance = Depth.balance()
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        #expect(state.knownDepartments.isEmpty)
        let lawyer = TestPeople.employee(role: .lawyer)
        state.employees.append(lawyer)

        let formed = Reducer.tick(&state, balance: balance, content: content)
        #expect(formed.contains(.departmentFormed(department: .legal, day: 1)))
        #expect(!GameEvent.departmentFormed(department: .legal, day: 1).pausesTimeline)
        #expect(state.knownDepartments == [.legal])

        // Steady state: no repeat events.
        let quiet = Reducer.tick(&state, balance: balance, content: content)
        #expect(!quiet.contains { event in
            switch event {
            case .departmentFormed, .departmentDissolved: true
            default: false
            }
        })

        Reducer.apply(.fire(employeeID: lawyer.id), to: &state, balance: balance, content: content)
        let dissolved = Reducer.tick(&state, balance: balance, content: content)
        #expect(dissolved.contains(.departmentDissolved(department: .legal, day: 3)))
        #expect(!GameEvent.departmentDissolved(department: .legal, day: 3).pausesTimeline)
        #expect(state.knownDepartments.isEmpty)
    }

    /// One job delivered on the first tick and one already past its
    /// deadline, settled with or without a lawyer on payroll.
    private func settle(withLegal: Bool) -> (events: [GameEvent], state: GameState) {
        let balance = Depth.balance()
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        let delivered = UUID()
        state.activeContracts.append(ContractJob(
            id: delivered, clientName: "Good Co",
            requiredCodePts: 0.5, requiredDesignPts: 0.5,
            progressCode: 0, progressDesign: 0,
            deadlineDay: 100, payout: 1_000, penalty: 300, acceptedDay: 0
        ))
        state.activeContracts.append(ContractJob(
            id: UUID(), clientName: "Late Co",
            requiredCodePts: 100, requiredDesignPts: 100,
            progressCode: 0, progressDesign: 0,
            deadlineDay: 0, payout: 2_000, penalty: 300, acceptedDay: 0
        ))
        state.employees.append(TestPeople.employee(role: .backend, assignment: .contract(delivered)))
        if withLegal {
            state.employees.append(TestPeople.employee(name: "Counsel", role: .lawyer))
        }
        let events = Reducer.tick(&state, balance: balance, content: content)
        return (events, state)
    }

    @Test func legalLiftsPayoutsAndHalvesPenalties() {
        let (plain, plainState) = settle(withLegal: false)
        #expect(plain.contains { if case .contractDelivered(_, _, 1_000, 1) = $0 { true } else { false } })
        #expect(plain.contains { if case .contractFailed(_, 300, 1) = $0 { true } else { false } })
        #expect(plainState.ledger.entries.contains { $0.label == "Good Co" && $0.amount == 1_000 })
        #expect(plainState.ledger.entries.contains { $0.label == "Late Co" && $0.amount == -300 })

        let (legal, legalState) = settle(withLegal: true)
        #expect(legal.contains { if case .contractDelivered(_, _, 1_100, 1) = $0 { true } else { false } })
        #expect(legal.contains { if case .contractFailed(_, 150, 1) = $0 { true } else { false } })
        #expect(legalState.ledger.entries.contains { $0.label == "Good Co" && $0.amount == 1_100 })
        #expect(legalState.ledger.entries.contains { $0.label == "Late Co" && $0.amount == -150 })
        #expect(legalState.company.cash == plainState.company.cash + 100 + 150)
    }

    @Test func legalAddsAnOfferToEveryWeeklyRefresh() {
        let balance = Depth.balance(contractOfferRefreshDays: 7)
        func offersAfterFirstRefresh(withLegal: Bool) -> Int {
            var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
            if withLegal {
                state.employees.append(TestPeople.employee(role: .lawyer))
            }
            for _ in 0..<7 {
                Reducer.tick(&state, balance: balance, content: content)
            }
            return state.contractOffers.count
        }
        #expect(offersAfterFirstRefresh(withLegal: false) == 3)
        #expect(offersAfterFirstRefresh(withLegal: true) == 4)
    }

    /// Staff tuning that snaps morale to its target every day.
    private var snappingStaff: BalanceConfig.StaffBalance {
        var staff = BalanceConfig.StaffBalance.standard
        staff.moraleAdaptRate = 1
        staff.quitStreakDays = 1_000_000
        return staff
    }

    @Test func hrRaisesTheMoraleTarget() {
        let balance = Depth.balance(staff: snappingStaff)
        // Fair pay for the default test skills is 945: target 60 alone…
        var plain = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        plain.employees.append(TestPeople.employee(weeklySalary: 945))
        Reducer.tick(&plain, balance: balance, content: content)
        #expect(abs(plain.employees[1].morale - 60) < 1e-9)

        // …and 65 with an HR manager on payroll (who enjoys the same target).
        var hr = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        hr.employees.append(TestPeople.employee(weeklySalary: 945))
        hr.employees.append(TestPeople.employee(name: "People", role: .hr, weeklySalary: 945))
        Reducer.tick(&hr, balance: balance, content: content)
        #expect(abs(hr.employees[1].morale - 65) < 1e-9)
        #expect(abs(hr.employees[2].morale - 65) < 1e-9)
    }

    @Test func hrShortensTheCandidateRefreshInterval() {
        let balance = Depth.balance(candidateRefreshDays: 14)
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        state.employees.append(TestPeople.employee(role: .hr))

        var refreshDays: [Int] = []
        for _ in 0..<20 {
            let events = Reducer.tick(&state, balance: balance, content: content)
            if events.contains(.candidatesRefreshed(day: state.day)) {
                refreshDays.append(state.day)
            }
        }
        // 14 − 4 = 10-day cadence.
        #expect(refreshDays == [10, 20])
        #expect(!state.candidatePool.isEmpty)
    }

    /// Days until an underpaid worker quits, with the given colleagues and
    /// amenities; morale snaps to target, quits after 3 sub-threshold days.
    private func quitDay(colleagues: [Employee] = [], amenities: Set<Amenity> = []) -> Int? {
        var staff = snappingStaff
        staff.quitMoraleThreshold = 45
        staff.quitStreakDays = 3
        let balance = Depth.balance(staff: staff)
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        state.employees.append(TestPeople.employee(weeklySalary: 300)) // target 35 (+5 with HR)
        state.employees.append(contentsOf: colleagues)
        state.amenities = amenities
        for _ in 0..<40 {
            let events = Reducer.tick(&state, balance: balance, content: content)
            if events.contains(where: { if case .employeeQuit(_, "Worker", _) = $0 { true } else { false } }) {
                return state.day
            }
        }
        return nil
    }

    @Test func hrExtendsTheQuitStreak() {
        #expect(quitDay() == 4)
        // Streak 3 + 7 = 10: quits on the 11th day.
        #expect(quitDay(colleagues: [TestPeople.employee(name: "People", role: .hr, weeklySalary: 945)]) == 11)
    }

    @Test func shuttleExtendsTheQuitStreak() {
        #expect(quitDay(amenities: [.shuttle]) == 11)
        // Amenity morale bonuses stack into the target but +4 keeps 39 < 45.
        #expect(quitDay(amenities: [.gameRoom]) == 4)
    }

    @Test func hrDiscountsTraining() {
        let balance = Depth.balance()
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        state.employees.append(TestPeople.employee(role: .hr))
        let id = state.employees[1].id
        let cashBefore = state.company.cash

        Reducer.apply(.train(employeeID: id, skill: .coding), to: &state, balance: balance, content: content)
        // 800 × 0.7 = 560.
        #expect(state.company.cash == cashBefore - 560)
        #expect(state.ledger.entries.last?.amount == -560)
    }

    @Test func opsDiscountsRentAndAmenityUpkeep() {
        let balance = Depth.balance()
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        state.company.officeTier = .loft // rent 150
        state.amenities = [.gameRoom] // upkeep 150
        state.employees.append(TestPeople.employee(role: .ops))

        while state.day < 7 {
            Reducer.tick(&state, balance: balance, content: content)
        }
        let rent = state.ledger.entries.first { $0.label == "Office rent" }
        #expect(rent?.amount == -135)
        #expect(rent?.category == .rent)
        let upkeep = state.ledger.entries.first { $0.label == "Amenities" }
        #expect(upkeep?.amount == -105)
        #expect(upkeep?.category == .rent)
    }
}

// MARK: - Amenities

@Suite("Amenities")
struct AmenityTests {
    private let content = TestContent.tiny()

    @Test func buildIsGatedByTierCashAndOwnership() {
        let balance = Depth.balance()
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        state.company.cash = 1_000_000

        // Garage: the game room needs a loft.
        var before = state
        #expect(Reducer.apply(.buildAmenity(.gameRoom), to: &state, balance: balance, content: content).isEmpty)
        #expect(state == before)

        // Loft, one dollar short.
        state.company.officeTier = .loft
        state.company.cash = balance.company.amenity(.gameRoom).upgradeCost - 1
        before = state
        #expect(Reducer.apply(.buildAmenity(.gameRoom), to: &state, balance: balance, content: content).isEmpty)
        #expect(state == before)

        // Loft, affordable.
        state.company.cash = 10_123
        state.day = 42
        let events = Reducer.apply(.buildAmenity(.gameRoom), to: &state, balance: balance, content: content)
        #expect(events == [.amenityBuilt(amenity: .gameRoom, day: 42)])
        #expect(!GameEvent.amenityBuilt(amenity: .gameRoom, day: 42).pausesTimeline)
        #expect(state.eventLog.last == .amenityBuilt(amenity: .gameRoom, day: 42))
        #expect(state.company.cash == 123)
        #expect(state.ledger.entries.last == LedgerEntry(day: 42, amount: -10_000, category: .other, label: "Built: Game Room"))
        #expect(state.amenities == [.gameRoom])
        #expect(state.hasAmenity(.gameRoom))
        #expect(!state.hasAmenity(.gym))

        // Already owned.
        state.company.cash = 1_000_000
        before = state
        #expect(Reducer.apply(.buildAmenity(.gameRoom), to: &state, balance: balance, content: content).isEmpty)
        #expect(state == before)

        // The cafeteria, shuttle, and gym need a studio.
        for amenity in [Amenity.cafeteria, .shuttle, .gym] {
            #expect(Reducer.apply(.buildAmenity(amenity), to: &state, balance: balance, content: content).isEmpty,
                    Comment(rawValue: amenity.rawValue))
        }
        state.company.officeTier = .studio
        #expect(Reducer.apply(.buildAmenity(.gym), to: &state, balance: balance, content: content)
            == [.amenityBuilt(amenity: .gym, day: 42)])
        #expect(state.company.cash == 1_000_000 - 30_000)
        #expect(state.amenities == [.gameRoom, .gym])
    }

    @Test func upkeepPostsWeeklyAsRent() {
        let balance = Depth.balance()
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        state.amenities = [.gameRoom, .cafeteria]
        let cashBefore = state.company.cash

        while state.day < 7 {
            Reducer.tick(&state, balance: balance, content: content)
        }
        // 150 + 400 = 550, no Ops discount.
        #expect(state.ledger.entries.contains(
            LedgerEntry(day: 7, amount: -550, category: .rent, label: "Amenities")
        ))
        #expect(state.company.cash == cashBefore - balance.weeklyOperatingCost - 550)

        // Nothing posts without amenities.
        var bare = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        while bare.day < 7 {
            Reducer.tick(&bare, balance: balance, content: content)
        }
        #expect(!bare.ledger.entries.contains { $0.label == "Amenities" })
    }

    @Test func amenitiesLiftTheMoraleTarget() {
        var staff = BalanceConfig.StaffBalance.standard
        staff.moraleAdaptRate = 1
        let balance = Depth.balance(staff: staff)
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        state.employees.append(TestPeople.employee(weeklySalary: 945)) // fair pay: target 60
        state.amenities = [.gameRoom, .cafeteria, .shuttle, .gym] // +4 +6 +4 +5

        Reducer.tick(&state, balance: balance, content: content)
        #expect(abs(state.employees[1].morale - 79) < 1e-9)
    }

    @Test func gymNudgesFounderHealthDaily() {
        let balance = Depth.balance()
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        state.amenities = [.gym]
        state.life.meters = LifeMeters(energy: 80, health: 80, mood: 70, relationships: 50)

        Reducer.tick(&state, balance: balance, content: content)
        #expect(abs(state.life.meters.health - 80.2) < 1e-9)
        #expect(state.life.meters.energy == 80) // only health moves

        state.amenities = [.gameRoom]
        Reducer.tick(&state, balance: balance, content: content)
        #expect(abs(state.life.meters.health - 80.2) < 1e-9)
    }

    @Test func amenitiesSurviveOfficeUpgrades() {
        let balance = Depth.balance()
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        state.company.officeTier = .loft
        state.company.cash = 1_000_000
        Reducer.apply(.buildAmenity(.gameRoom), to: &state, balance: balance, content: content)

        Reducer.apply(.upgradeOffice, to: &state, balance: balance, content: content)
        #expect(state.company.officeTier == .studio)
        #expect(state.amenities == [.gameRoom])
    }

    @Test func amenitiesAndKnownDepartmentsEncodeSortedAndDecodeWhenMissing() throws {
        let balance = TestBalance.standard
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        #expect(state.amenities.isEmpty)
        state.amenities = [.gym, .gameRoom, .cafeteria]
        state.knownDepartments = [.ops, .legal]

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(state)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["amenities"] as? [String] == ["cafeteria", "gameRoom", "gym"])
        #expect(object["knownDepartments"] as? [String] == ["legal", "ops"])

        let decoded = try JSONDecoder().decode(GameState.self, from: data)
        #expect(decoded == state)
        #expect(try encoder.encode(decoded) == data)

        let legacy = try Depth.stripping(["amenities", "knownDepartments"], from: data)
        let fromLegacy = try JSONDecoder().decode(GameState.self, from: legacy)
        #expect(fromLegacy.amenities.isEmpty)
        #expect(fromLegacy.knownDepartments.isEmpty)
        #expect(fromLegacy.company == state.company)
    }
}

// MARK: - Engine & balance

@MainActor
@Suite("Company depth: weekly burn")
struct CompanyDepthBurnTests {
    @Test func weeklyBurnIncludesAmenityUpkeepAfterTheOpsDiscount() {
        let balance = Depth.balance(garageRent: 150)
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        state.amenities = [.gameRoom]
        let plain = GameEngine(state: state, balance: balance, content: TestContent.bundled)
        #expect(plain.weeklyBurn == 400 + 150 + 150)

        state.employees.append(TestPeople.employee(role: .ops, weeklySalary: 500))
        let ops = GameEngine(state: state, balance: balance, content: TestContent.bundled)
        // Rent 150 × 0.9 = 135, upkeep 150 × 0.7 = 105.
        #expect(ops.weeklyBurn == 400 + 135 + 500 + 105)
    }
}

@Suite("Company balance block")
struct CompanyBalanceTests {
    @Test func bundledCompanyBlockMatchesTheDesign() throws {
        let company = try BalanceConfig.loadBundled().company

        for role in EmployeeRole.allCases {
            #expect(company.roleYields[role.rawValue] != nil, Comment(rawValue: role.rawValue))
        }
        let backend = company.roleYield(.backend)
        #expect(backend.code == 1.4 && backend.design == 0.5 && backend.polish == 1.0)
        let qa = company.roleYield(.qa)
        #expect(qa.code == 0.6 && qa.design == 0.6 && qa.polish == 1.6)
        let ops = company.roleYield(.ops)
        #expect(ops.code == 0.3 && ops.design == 0.3 && ops.polish == 0.3)
        #expect(company.qaBugFixMultiplier == 2.0)
        #expect(company.marketerDailyHype == 0.4)

        #expect(company.candidateRoleWeights == [
            "frontend": 22, "backend": 25, "designer": 18, "qa": 12,
            "marketer": 10, "lawyer": 5, "hr": 5, "ops": 3,
        ])
        #expect(company.candidateMinTier(.lawyer) == .loft)
        #expect(company.candidateMinTier(.hr) == .loft)
        #expect(company.candidateMinTier(.ops) == .studio)
        #expect(company.candidateMinTier(.frontend) == .garage)
        #expect(company.builderPrimarySkillBonus == 15)
        #expect(company.marketerSkillBonus == 20)
        #expect(company.supportSalaryFactor == 0.9)

        #expect(company.legalPenaltyFactor == 0.5)
        #expect(company.legalPayoutBonus == 1.10)
        #expect(company.legalExtraOffers == 1)
        #expect(company.hrMoraleBonus == 5)
        #expect(company.hrRefreshDaysReduction == 4)
        #expect(company.hrQuitStreakBonus == 7)
        #expect(company.hrTrainingCostFactor == 0.7)
        #expect(company.opsUpkeepFactor == 0.7)
        #expect(company.opsRentFactor == 0.9)

        for amenity in Amenity.allCases {
            #expect(company.amenities[amenity.rawValue] != nil, Comment(rawValue: amenity.rawValue))
        }
        let gameRoom = company.amenity(.gameRoom)
        #expect(gameRoom.upgradeCost == 10_000 && gameRoom.weeklyCost == 150 && gameRoom.minTier == .loft)
        #expect(gameRoom.moraleBonus == 4 && gameRoom.founderHealthBonus == 0 && gameRoom.quitStreakBonusDays == 0)
        let cafeteria = company.amenity(.cafeteria)
        #expect(cafeteria.upgradeCost == 25_000 && cafeteria.weeklyCost == 400 && cafeteria.minTier == .studio)
        #expect(cafeteria.moraleBonus == 6)
        let shuttle = company.amenity(.shuttle)
        #expect(shuttle.upgradeCost == 15_000 && shuttle.weeklyCost == 300 && shuttle.minTier == .studio)
        #expect(shuttle.moraleBonus == 4 && shuttle.quitStreakBonusDays == 7)
        let gym = company.amenity(.gym)
        #expect(gym.upgradeCost == 30_000 && gym.weeklyCost == 350 && gym.minTier == .studio)
        #expect(gym.moraleBonus == 5 && gym.founderHealthBonus == 0.2)

        #expect(company == .standard)
    }
}
