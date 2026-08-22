import Foundation
import TycoonContent

/// Daily employee system, running after `LifeSystem` and before
/// `ProductSystem`: sweeps stale product and contract assignments back to
/// idle, pours the assigned employees' output into the in-development
/// product (bug resolution stays in `ProductSystem.applyDailyProgress`) and
/// into their active contracts (settlement stays in `ContractSystem`),
/// generates research points from the employees assigned to research, grows
/// the skills that fed a pool, and refreshes the candidate pool on its
/// cadence. The founder's output (product, contract, and research) is
/// scaled by `GameState.founderOutputMultiplier`; an away founder is
/// skipped entirely — no output, no skill growth — but keeps their
/// assignment and still counts for headcount. Also hosts the
/// hire/fire/assign action handlers used by `Reducer.apply`.
enum EmployeeSystem {
    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        sweepStaleAssignments(&state)
        produceDailyOutput(&state, balance, content)
        produceContractOutput(&state, balance, content)
        produceResearchPoints(&state, balance)

        if state.day % balance.candidateRefreshDays == 0 {
            refreshCandidates(&state, balance, content)
            return [.candidatesRefreshed(day: state.day)]
        }
        return []
    }

    // MARK: - Daily sweep

    /// Resets assignments pointing at gone targets back to `.idle`: products
    /// that are released or nonexistent, and contracts that completed,
    /// failed, or never existed. Research assignments are left alone.
    private static func sweepStaleAssignments(_ state: inout GameState) {
        for index in state.employees.indices {
            switch state.employees[index].assignment {
            case .product(let productID):
                if let product = state.product(id: productID),
                   case .development = product.stage { continue }
                state.employees[index].assignment = .idle
            case .contract(let contractID):
                if state.activeContract(id: contractID) != nil { continue }
                state.employees[index].assignment = .idle
            case .idle, .research:
                continue
            }
        }
    }

    // MARK: - Daily output

    /// Every employee assigned to the in-development product contributes
    /// points split by the product's focus:
    /// `poolYield = focusShare * (employeeBasePoints + relevantSkill / skillYieldDivisor)`
    /// where the code pool draws on coding, the design pool on design, and
    /// the polish pool on the mean of both. The day's pool totals are then
    /// scaled by the tech dev-speed multiplier. Afterwards each skill that
    /// fed a pool grows by `skillGrowthRate * (1 - skill/100)`, capped at 100.
    private static func produceDailyOutput(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) {
        guard let productIndex = state.products.firstIndex(where: { product in
            if case .development = product.stage { return true }
            return false
        }), case .development(let dev) = state.products[productIndex].stage else { return }

        let productID = state.products[productIndex].id
        let focus = dev.focus

        let founderAway = state.life.isAway(day: state.day)
        let founderFactor = state.founderOutputMultiplier(balance: balance)
        var design = 0.0, code = 0.0, polish = 0.0
        var codingSum = 0.0
        var producers: [Int] = []
        var founderWorked = false
        for index in state.employees.indices {
            guard case .product(let assignedID) = state.employees[index].assignment,
                  assignedID == productID else { continue }
            let isFounder = state.employees[index].isFounder
            if isFounder, founderAway { continue }
            let factor = isFounder ? founderFactor : 1
            let skills = state.employees[index].skills
            design += factor * focus.design
                * (balance.employeeBasePoints + skills.design / balance.skillYieldDivisor)
            code += factor * focus.code
                * (balance.employeeBasePoints + skills.coding / balance.skillYieldDivisor)
            polish += factor * focus.polish
                * (balance.employeeBasePoints + (skills.coding + skills.design) / 2 / balance.skillYieldDivisor)
            codingSum += skills.coding
            producers.append(index)
            if isFounder { founderWorked = true }
        }

        let averageCoding = producers.isEmpty
            ? balance.founderCoding
            : codingSum / Double(producers.count)
        let bugChanceMultiplier = founderWorked ? state.founderBugChanceMultiplier(balance: balance) : 1
        let devSpeed = state.devSpeedTechMultiplier(content: content)
        ProductSystem.applyDailyProgress(
            design: design * devSpeed, code: code * devSpeed, polish: polish * devSpeed,
            averageCoding: averageCoding,
            bugChanceMultiplier: bugChanceMultiplier,
            productIndex: productIndex, state: &state, balance: balance
        )

        // Skill growth for the skills that fed a pool today: coding feeds the
        // code and polish pools, design feeds the design and polish pools.
        let growsCoding = focus.code > 0 || focus.polish > 0
        let growsDesign = focus.design > 0 || focus.polish > 0
        for index in producers {
            if growsCoding {
                grow(&state.employees[index].skills.coding, rate: balance.skillGrowthRate)
            }
            if growsDesign {
                grow(&state.employees[index].skills.design, rate: balance.skillGrowthRate)
            }
        }
    }

    // MARK: - Daily contract output

    /// Every employee assigned to an active contract adds
    /// `employeeBasePoints + coding/skillYieldDivisor` code points and
    /// `employeeBasePoints + design/skillYieldDivisor` design points to
    /// their job per day — the product-work base formula, scaled by the
    /// tech dev-speed multiplier. Both skills fed a pool, so both grow by
    /// the standard rule.
    private static func produceContractOutput(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) {
        guard !state.activeContracts.isEmpty else { return }
        let devSpeed = state.devSpeedTechMultiplier(content: content)
        let founderAway = state.life.isAway(day: state.day)
        let founderFactor = state.founderOutputMultiplier(balance: balance)

        for index in state.employees.indices {
            guard case .contract(let contractID) = state.employees[index].assignment,
                  let jobIndex = state.activeContracts.firstIndex(where: { $0.id == contractID })
            else { continue }
            let isFounder = state.employees[index].isFounder
            if isFounder, founderAway { continue }
            let factor = isFounder ? founderFactor : 1

            let skills = state.employees[index].skills
            state.activeContracts[jobIndex].progressCode +=
                factor * (balance.employeeBasePoints + skills.coding / balance.skillYieldDivisor) * devSpeed
            state.activeContracts[jobIndex].progressDesign +=
                factor * (balance.employeeBasePoints + skills.design / balance.skillYieldDivisor) * devSpeed
            grow(&state.employees[index].skills.coding, rate: balance.skillGrowthRate)
            grow(&state.employees[index].skills.design, rate: balance.skillGrowthRate)
        }
    }

    // MARK: - Daily research points

    /// Every employee assigned to research generates
    /// `researchBasePoints + coding/researchCodingDivisor + design/researchDesignDivisor`
    /// RP per day (the tech dev-speed multiplier never applies to RP). The
    /// day's points flow into the active node's progress, or into `banked`
    /// when nothing is active. Researchers worked, so their coding and
    /// design skills grow by the standard rule.
    private static func produceResearchPoints(_ state: inout GameState, _ balance: BalanceConfig) {
        let founderAway = state.life.isAway(day: state.day)
        let founderFactor = state.founderOutputMultiplier(balance: balance)
        var points = 0.0
        var researchers: [Int] = []
        for index in state.employees.indices {
            guard state.employees[index].assignment == .research else { continue }
            let isFounder = state.employees[index].isFounder
            if isFounder, founderAway { continue }
            let factor = isFounder ? founderFactor : 1
            let skills = state.employees[index].skills
            points += factor * (balance.researchBasePoints
                + skills.coding / balance.researchCodingDivisor
                + skills.design / balance.researchDesignDivisor)
            researchers.append(index)
        }
        guard !researchers.isEmpty else { return }

        if state.research.activeNodeID != nil {
            state.research.activeProgress += points
        } else {
            state.research.banked += points
        }

        for index in researchers {
            grow(&state.employees[index].skills.coding, rate: balance.skillGrowthRate)
            grow(&state.employees[index].skills.design, rate: balance.skillGrowthRate)
        }
    }

    private static func grow(_ skill: inout Double, rate: Double) {
        skill = min(100, skill + rate * (1 - skill / 100))
    }

    // MARK: - Candidate refresh

    /// Replaces the pool with fresh seeded rolls. The skill ceiling rises
    /// with reputation and office tier (clamped to 5...100); salaries track
    /// total skills with a uniform jitter.
    private static func refreshCandidates(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) {
        let count = state.rng.nextInt(in: balance.candidateCountMin...balance.candidateCountMax)
        let tierBonus = balance.candidateSkillTierBonus[state.company.officeTier.rawValue] ?? 0
        let ceiling = min(100, max(5,
            balance.candidateSkillBase
                + state.company.reputation * balance.candidateSkillPerReputation
                + tierBonus
        ))

        var pool: [Candidate] = []
        pool.reserveCapacity(count)
        for _ in 0..<count {
            let id = UUID(from: &state.rng)
            let name = "\(pick(content.names.firstNames, &state.rng)) \(pick(content.names.lastNames, &state.rng))"
            let skills = SkillSet(
                coding: rollSkill(upTo: ceiling, &state.rng),
                design: rollSkill(upTo: ceiling, &state.rng),
                marketing: rollSkill(upTo: ceiling, &state.rng)
            )
            let jitter = 1 + (state.rng.nextUniform() * 2 - 1) * balance.salaryJitter
            let salary = (Double(balance.salaryBase) + balance.salaryPerSkillPoint * skills.total) * jitter
            pool.append(Candidate(
                id: id,
                name: name,
                skills: skills,
                weeklySalary: Int(salary.rounded()),
                appearanceSeed: state.rng.next()
            ))
        }
        state.candidatePool = pool
    }

    /// Uniform skill roll in 5...ceiling.
    private static func rollSkill(upTo ceiling: Double, _ rng: inout SeededRNG) -> Double {
        5 + rng.nextUniform() * (ceiling - 5)
    }

    private static func pick(_ pool: [String], _ rng: inout SeededRNG) -> String {
        guard !pool.isEmpty else { return "" }
        return pool[rng.nextInt(in: 0...(pool.count - 1))]
    }

    // MARK: - Actions

    /// Hires a candidate out of the pool. Ignored for unknown ids and once
    /// the office headcount cap is reached. The hire keeps the candidate's
    /// identity and joins the in-development product if there is one,
    /// mirroring the auto-assignment on `startProduct`.
    static func hire(
        candidateID: UUID,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard let poolIndex = state.candidatePool.firstIndex(where: { $0.id == candidateID }),
              state.headcount < balance.office(state.company.officeTier).headcountCap
        else { return [] }

        let candidate = state.candidatePool.remove(at: poolIndex)
        let assignment: Assignment = if let product = state.productInDevelopment {
            .product(product.id)
        } else {
            .idle
        }
        state.employees.append(Employee(
            id: candidate.id,
            name: candidate.name,
            skills: candidate.skills,
            weeklySalary: candidate.weeklySalary,
            assignment: assignment,
            isFounder: false,
            hiredDay: state.day,
            appearanceSeed: candidate.appearanceSeed
        ))
        return [.hired(employeeID: candidate.id, day: state.day)]
    }

    /// Removes an employee from payroll. Ignored for unknown ids and for
    /// the founder, who can never be fired.
    static func fire(employeeID: UUID, state: inout GameState) -> [GameEvent] {
        guard let index = state.employees.firstIndex(where: { $0.id == employeeID }),
              !state.employees[index].isFounder
        else { return [] }

        state.employees.remove(at: index)
        return [.fired(employeeID: employeeID, day: state.day)]
    }

    /// Reassigns an employee. Any assignment is accepted (a stale product
    /// assignment is swept back to idle daily). Ignored for unknown ids;
    /// no event.
    static func assign(
        employeeID: UUID,
        to assignment: Assignment,
        state: inout GameState
    ) -> [GameEvent] {
        guard let index = state.employees.firstIndex(where: { $0.id == employeeID }) else { return [] }
        state.employees[index].assignment = assignment
        return []
    }
}
