import Foundation
import TycoonContent

/// Daily employee system, running after `LifeSystem` and before
/// `ProductSystem`: sweeps stale product and contract assignments back to
/// idle, pours the assigned employees' output into the in-development
/// product (bug resolution stays in `ProductSystem.applyDailyProgress`) and
/// into their active contracts (settlement stays in `ContractSystem`),
/// generates research points from the employees assigned to research, grows
/// the skills that fed a pool, tracks department transitions, and refreshes
/// the candidate pool on its cadence. The founder's output (product,
/// contract, and research) is scaled by `GameState.founderOutputMultiplier`;
/// an away founder is skipped entirely — no output, no skill growth — but
/// keeps their assignment and still counts for headcount. Also hosts the
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

        var events = updateMoraleAndQuits(&state, balance, content)
        events.append(contentsOf: trackDepartments(&state))

        if state.day % candidateRefreshInterval(state, balance) == 0 {
            refreshCandidates(&state, balance, content)
            events.append(.candidatesRefreshed(day: state.day))
        }
        return events
    }

    /// Days between candidate refreshes: the balance cadence, shortened by
    /// People & HR and never below one day.
    static func candidateRefreshInterval(_ state: GameState, _ balance: BalanceConfig) -> Int {
        let reduction = state.hasDepartment(.hr) ? balance.company.hrRefreshDaysReduction : 0
        return max(1, balance.candidateRefreshDays - reduction)
    }

    // MARK: - Departments

    /// Compares today's staffed departments against the set seen on the
    /// last tick and emits formed / dissolved events for the differences,
    /// in `Department.allCases` order. Runs after quits so a resignation
    /// that empties a department dissolves it the same day.
    private static func trackDepartments(_ state: inout GameState) -> [GameEvent] {
        let active = state.activeDepartments
        guard active != state.knownDepartments else { return [] }

        var events: [GameEvent] = []
        for department in Department.allCases {
            let isActive = active.contains(department)
            let wasActive = state.knownDepartments.contains(department)
            if isActive, !wasActive {
                events.append(.departmentFormed(department: department, day: state.day))
            } else if !isActive, wasActive {
                events.append(.departmentDissolved(department: department, day: state.day))
            }
        }
        state.knownDepartments = active
        return events
    }

    // MARK: - Daily morale

    /// Every hired employee's morale drifts toward a target set by pay
    /// fairness (their salary vs. the hiring-market rate for their skills,
    /// raised by seniority), the office tier, People & HR, and the owned
    /// amenities. Morale below the quit threshold builds a streak; a streak
    /// past `quitStreakDays` (extended by HR and the shuttle) makes the
    /// employee resign. The founder has life meters instead of morale.
    private static func updateMoraleAndQuits(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        let staff = balance.staff
        let company = balance.company
        let hasHR = state.hasDepartment(.hr)
        let officeBonus = (staff.officeMoraleBonus[state.company.officeTier.rawValue] ?? 0)
            + balance.city.district(state.city.district).moraleBonus
        let perkBonus = (hasHR ? company.hrMoraleBonus : 0)
            + state.ownedAmenities.reduce(0.0) { $0 + company.amenity($1).moraleBonus }
        let quitStreakDays = staff.quitStreakDays
            + (hasHR ? company.hrQuitStreakBonus : 0)
            + state.ownedAmenities.reduce(0) { $0 + company.amenity($1).quitStreakBonusDays }
        var events: [GameEvent] = []
        var quitting: [Int] = []

        for index in state.employees.indices where !state.employees[index].isFounder {
            let employee = state.employees[index]
            let fairPay = fairWeeklyPay(for: employee, balance: balance)
            let ratio = fairPay > 0 ? Double(employee.weeklySalary) / fairPay : 1
            var target = staff.baselineMorale + officeBonus + perkBonus
                + TraitEffects.moraleTargetDelta(employee, content: content)
            if ratio < staff.underpaidThreshold {
                target -= staff.underpaidTargetPenalty
            } else if ratio > staff.wellPaidThreshold {
                target += staff.wellPaidTargetBonus
            }
            target = min(100, max(0, target))

            var morale = employee.morale + (target - employee.morale) * staff.moraleAdaptRate
            morale = min(100, max(0, morale))
            state.employees[index].morale = morale

            if morale < staff.quitMoraleThreshold {
                state.employees[index].lowMoraleStreakDays += 1
                // Loyal people hold on longer before resigning.
                let personalStreak = quitStreakDays
                    + Int(state.employees[index].loyalty / balance.social.loyaltyQuitDivisor)
                    + TraitEffects.quitStreakBonus(employee, content: content)
                if state.employees[index].lowMoraleStreakDays > personalStreak {
                    quitting.append(index)
                }
            } else {
                state.employees[index].lowMoraleStreakDays = 0
            }
        }

        for index in quitting.reversed() {
            let employee = state.employees.remove(at: index)
            events.append(.employeeQuit(employeeID: employee.id, name: employee.name, day: state.day))
            events.append(contentsOf: SocialSystem.friendDeparted(
                employee.id, state: &state, balance: balance
            ))
        }
        return events
    }

    /// The weekly pay an employee considers fair: the candidate-market rate
    /// for their skills, raised by `levelPayExpectation` per seniority level.
    static func fairWeeklyPay(for employee: Employee, balance: BalanceConfig) -> Double {
        (Double(balance.salaryBase) + balance.salaryPerSkillPoint * employee.skills.total)
            * (1 + balance.staff.levelPayExpectation * Double(employee.level.rank))
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
    /// points split by the product's focus and shaped by their role:
    /// `poolYield = focusShare * roleYield * (employeeBasePoints + relevantSkill / skillYieldDivisor)`
    /// where the code pool draws on coding, the design pool on design, and
    /// the polish pool on the mean of both. The day's pool totals are then
    /// scaled by the tech dev-speed multiplier. Polish from QA engineers
    /// fixes `qaBugFixMultiplier` bugs per point (the day's blended rate is
    /// handed to `applyDailyProgress`), and every marketer on the product
    /// adds `marketerDailyHype × (1 + marketing/100)` hype. Afterwards each
    /// skill that fed a pool grows by `skillGrowthRate * (1 - skill/100)`,
    /// capped at 100.
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
        let company = balance.company

        let founderAway = state.life.isAway(day: state.day)
        let founderFactor = state.founderOutputMultiplier(balance: balance)
        // Working next to a friend lifts output (strongest co-assigned bond).
        let crew = state.employees
            .filter { if case .product(let id) = $0.assignment { return id == productID }; return false }
            .map(\.id)
        var design = 0.0, code = 0.0, polish = 0.0
        var qaPolish = 0.0
        var hype = 0.0
        var codingSum = 0.0
        var producers: [Int] = []
        var founderWorked = false
        for index in state.employees.indices {
            guard case .product(let assignedID) = state.employees[index].assignment,
                  assignedID == productID else { continue }
            let isFounder = state.employees[index].isFounder
            if isFounder, founderAway { continue }
            let bond = SocialSystem.strongestBond(
                for: state.employees[index].id, among: crew, in: state
            )
            let friendFactor = 1 + balance.social.friendshipOutputBonus * bond / 100
            let factor = (isFounder
                ? founderFactor
                : state.employees[index].performanceMultiplier(balance: balance))
                * friendFactor
                * TraitEffects.outputFactor(state.employees[index], content: content)
            let skills = state.employees[index].skills
            let role = state.employees[index].role
            let yield = company.roleYield(role)
            design += factor * focus.design * yield.design
                * (balance.employeeBasePoints + skills.design / balance.skillYieldDivisor)
            code += factor * focus.code * yield.code
                * (balance.employeeBasePoints + skills.coding / balance.skillYieldDivisor)
            let polishShare = factor * focus.polish * yield.polish
                * (balance.employeeBasePoints + (skills.coding + skills.design) / 2 / balance.skillYieldDivisor)
            polish += polishShare
            if role == .qa { qaPolish += polishShare }
            if role == .marketer {
                hype += company.marketerDailyHype * (1 + skills.marketing / 100)
            }
            codingSum += skills.coding
            producers.append(index)
            if isFounder { founderWorked = true }
        }

        let averageCoding = producers.isEmpty
            ? balance.founderCoding
            : codingSum / Double(producers.count)
        let bugChanceMultiplier = founderWorked ? state.founderBugChanceMultiplier(balance: balance) : 1
        // Bugs fixed per completed polish point, blended over who produced
        // today's polish (exactly 1 without QA, exactly the multiplier with
        // only QA).
        let bugFixMultiplier = polish > 0
            ? (polish - qaPolish + qaPolish * company.qaBugFixMultiplier) / polish
            : 1
        let devSpeed = state.devSpeedTechMultiplier(content: content)
        ProductSystem.applyDailyProgress(
            design: design * devSpeed, code: code * devSpeed, polish: polish * devSpeed,
            averageCoding: averageCoding,
            bugChanceMultiplier: bugChanceMultiplier,
            bugFixMultiplier: bugFixMultiplier,
            productIndex: productIndex, state: &state, balance: balance
        )
        if hype > 0, case .development(var progress) = state.products[productIndex].stage {
            progress.hype += hype
            state.products[productIndex].stage = .development(progress)
        }

        // Skill growth for the skills that fed a pool today: coding feeds the
        // code and polish pools, design feeds the design and polish pools.
        let growsCoding = focus.code > 0 || focus.polish > 0
        let growsDesign = focus.design > 0 || focus.polish > 0
        for index in producers {
            // Read the trait factor before the inout growth calls: taking
            // `&state.employees[index]...` and reading `state.employees`
            // in the same call would overlap exclusive access.
            let growthRate = balance.skillGrowthRate
                * TraitEffects.growthFactor(state.employees[index], content: content)
            if growsCoding {
                grow(&state.employees[index].skills.coding, rate: growthRate)
            }
            if growsDesign {
                grow(&state.employees[index].skills.design, rate: growthRate)
            }
        }
    }

    // MARK: - Daily contract output

    /// Every employee assigned to an active contract adds
    /// `roleYield.code × (employeeBasePoints + coding/skillYieldDivisor)`
    /// code points and `roleYield.design × (employeeBasePoints +
    /// design/skillYieldDivisor)` design points to their job per day — the
    /// product-work base formula, scaled by the tech dev-speed multiplier.
    /// Both skills fed a pool, so both grow by the standard rule.
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
            let crew = state.employees
                .filter { if case .contract(let id) = $0.assignment { return id == contractID }; return false }
                .map(\.id)
            let bond = SocialSystem.strongestBond(
                for: state.employees[index].id, among: crew, in: state
            )
            let friendFactor = 1 + balance.social.friendshipOutputBonus * bond / 100
            let factor = (isFounder
                ? founderFactor
                : state.employees[index].performanceMultiplier(balance: balance)) * friendFactor

            let skills = state.employees[index].skills
            let yield = balance.company.roleYield(state.employees[index].role)
            state.activeContracts[jobIndex].progressCode += factor * yield.code
                * (balance.employeeBasePoints + skills.coding / balance.skillYieldDivisor) * devSpeed
            state.activeContracts[jobIndex].progressDesign += factor * yield.design
                * (balance.employeeBasePoints + skills.design / balance.skillYieldDivisor) * devSpeed
            // Record the crew's skill for the delivery-quality grade.
            state.activeContracts[jobIndex].skillDaySum += (skills.coding + skills.design) / 2
            state.activeContracts[jobIndex].skillDays += 1
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
            let factor = isFounder
                ? founderFactor
                : state.employees[index].performanceMultiplier(balance: balance)
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
    /// with reputation and office tier (clamped to 5...100); a role's
    /// primary skill rolls against a raised ceiling (builders
    /// `builderPrimarySkillBonus`, marketers `marketerSkillBonus`, support
    /// roles flat); salaries track total skills with a uniform jitter,
    /// discounted by `supportSalaryFactor` for lawyers / HR / ops.
    ///
    /// The RNG draw order is fixed for determinism. Once per refresh: the
    /// pool size. Then per candidate: id (two words), first name, last
    /// name, role (one word — only when more than one role is eligible;
    /// see `rollRole`), coding, design, marketing, salary jitter, and the
    /// appearance seed.
    private static func refreshCandidates(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) {
        let company = balance.company
        let count = state.rng.nextInt(in: balance.candidateCountMin...balance.candidateCountMax)
        let tierBonus = balance.candidateSkillTierBonus[state.company.officeTier.rawValue] ?? 0
        let districtBonus = balance.city.district(state.city.district).candidateSkillBonus
        let ceiling = min(100, max(5,
            balance.candidateSkillBase
                + state.company.reputation * balance.candidateSkillPerReputation
                + tierBonus
                + districtBonus
        ))
        let eligibleRoles = EmployeeRole.allCases.filter { role in
            role != .founder
                && (company.candidateRoleWeights[role.rawValue] ?? 0) > 0
                && state.company.officeTier.rank >= company.candidateMinTier(role).rank
        }

        var pool: [Candidate] = []
        pool.reserveCapacity(count)
        for _ in 0..<count {
            let id = UUID(from: &state.rng)
            let name = "\(pick(content.names.firstNames, &state.rng)) \(pick(content.names.lastNames, &state.rng))"
            let role = rollRole(eligibleRoles, weights: company.candidateRoleWeights, &state.rng)

            var codingCeiling = ceiling, designCeiling = ceiling, marketingCeiling = ceiling
            switch role.primarySkill {
            case .coding: codingCeiling = min(100, ceiling + company.builderPrimarySkillBonus)
            case .design: designCeiling = min(100, ceiling + company.builderPrimarySkillBonus)
            case .marketing: marketingCeiling = min(100, ceiling + company.marketerSkillBonus)
            case nil: break
            }
            let skills = SkillSet(
                coding: rollSkill(upTo: codingCeiling, &state.rng),
                design: rollSkill(upTo: designCeiling, &state.rng),
                marketing: rollSkill(upTo: marketingCeiling, &state.rng)
            )
            let jitter = 1 + (state.rng.nextUniform() * 2 - 1) * balance.salaryJitter
            let salaryFactor = role.department != nil ? company.supportSalaryFactor : 1
            let salary = (Double(balance.salaryBase) + balance.salaryPerSkillPoint * skills.total)
                * jitter * salaryFactor
            pool.append(Candidate(
                id: id,
                name: name,
                skills: skills,
                weeklySalary: Int(salary.rounded()),
                appearanceSeed: state.rng.next(),
                role: role
            ))
        }
        state.candidatePool = pool
    }

    /// Weighted pick over the eligible roles, cumulative weights in
    /// `EmployeeRole.allCases` order. Draws one word (`nextInt`) only when
    /// there is a real choice: a single eligible role is taken without a
    /// draw, and no eligible role at all falls back to backend.
    private static func rollRole(
        _ eligible: [EmployeeRole],
        weights: [String: Int],
        _ rng: inout SeededRNG
    ) -> EmployeeRole {
        guard let first = eligible.first else { return .backend }
        guard eligible.count > 1 else { return first }
        let totalWeight = eligible.reduce(0) { $0 + (weights[$1.rawValue] ?? 0) }
        var remaining = rng.nextInt(in: 0...(totalWeight - 1))
        for role in eligible {
            remaining -= weights[role.rawValue] ?? 0
            if remaining < 0 { return role }
        }
        return eligible[eligible.count - 1]
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
            appearanceSeed: candidate.appearanceSeed,
            morale: balance.staff.startingMorale,
            level: .forSkillTotal(candidate.skills.total),
            role: candidate.role
        ))
        return [.hired(employeeID: candidate.id, day: state.day)]
    }

    /// Boosts a hired employee's morale, at most once per praise cooldown.
    /// Ignored for unknown ids, the founder, and while on cooldown.
    static func praise(
        employeeID: UUID,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard let index = hiredIndex(employeeID, state) else { return [] }
        if let last = state.employees[index].lastPraisedDay,
           state.day - last < balance.staff.praiseCooldownDays { return [] }

        bumpMorale(&state.employees[index], by: balance.staff.praiseMoraleBoost)
        state.employees[index].lastPraisedDay = state.day
        return []
    }

    /// Sets a new weekly salary (must be positive). Morale moves with the
    /// change: raises add `fraction × raiseMoraleFactor`, cuts subtract
    /// `fraction × cutMoraleFactor`. Ignored for unknown ids, the founder
    /// (whose salary is a life action), and a no-op amount.
    static func adjustSalary(
        employeeID: UUID,
        weeklySalary: Int,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard let index = hiredIndex(employeeID, state),
              weeklySalary > 0,
              weeklySalary != state.employees[index].weeklySalary
        else { return [] }

        let before = state.employees[index].weeklySalary
        let fraction = Double(weeklySalary - before) / Double(before)
        let staff = balance.staff
        let moraleDelta = fraction >= 0
            ? fraction * staff.raiseMoraleFactor
            : fraction * staff.cutMoraleFactor
        state.employees[index].weeklySalary = weeklySalary
        bumpMorale(&state.employees[index], by: moraleDelta)
        return [.salaryChanged(employeeID: employeeID, weeklySalary: weeklySalary, day: state.day)]
    }

    /// Moves an employee one seniority level up: salary bumps by
    /// `promotionSalaryBump` and morale jumps. Ignored for unknown ids,
    /// the founder, and at the top of the ladder.
    static func promote(
        employeeID: UUID,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard let index = hiredIndex(employeeID, state),
              let next = state.employees[index].level.next
        else { return [] }

        let staff = balance.staff
        state.employees[index].level = next
        state.employees[index].weeklySalary = Int(
            (Double(state.employees[index].weeklySalary) * (1 + staff.promotionSalaryBump)).rounded()
        )
        bumpMorale(&state.employees[index], by: staff.promotionMoraleBoost)
        return [.employeePromoted(employeeID: employeeID, level: next, day: state.day)]
    }

    /// Moves an employee one seniority level down: salary drops by
    /// `demotionSalaryCut` and morale takes a hit. Ignored for unknown ids,
    /// the founder, and at the bottom of the ladder.
    static func demote(
        employeeID: UUID,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard let index = hiredIndex(employeeID, state),
              let previous = state.employees[index].level.previous
        else { return [] }

        let staff = balance.staff
        state.employees[index].level = previous
        state.employees[index].weeklySalary = max(1, Int(
            (Double(state.employees[index].weeklySalary) * (1 - staff.demotionSalaryCut)).rounded()
        ))
        bumpMorale(&state.employees[index], by: -staff.demotionMoralePenalty)
        return [.employeeDemoted(employeeID: employeeID, level: previous, day: state.day)]
    }

    /// Sends an employee (founder included) on a paid training course:
    /// company cash pays `trainingCost` (× `hrTrainingCostFactor` with
    /// People & HR), the chosen skill jumps by `trainingSkillBoost` (capped
    /// at 100), morale by `trainingMoraleBoost`. Ignored for unknown ids,
    /// while unaffordable, and on cooldown.
    static func train(
        employeeID: UUID,
        skill: TrainableSkill,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        let cost = trainingCost(state, balance)
        guard let index = state.employees.firstIndex(where: { $0.id == employeeID }),
              state.company.cash >= cost
        else { return [] }
        if let last = state.employees[index].lastTrainedDay,
           state.day - last < balance.staff.trainingCooldownDays { return [] }

        let staff = balance.staff
        state.company.cash -= cost
        state.ledger.post(LedgerEntry(
            day: state.day,
            amount: -cost,
            category: .other,
            label: "Training: \(state.employees[index].name)"
        ))
        switch skill {
        case .coding:
            state.employees[index].skills.coding =
                min(100, state.employees[index].skills.coding + staff.trainingSkillBoost)
        case .design:
            state.employees[index].skills.design =
                min(100, state.employees[index].skills.design + staff.trainingSkillBoost)
        case .marketing:
            state.employees[index].skills.marketing =
                min(100, state.employees[index].skills.marketing + staff.trainingSkillBoost)
        }
        if !state.employees[index].isFounder {
            bumpMorale(&state.employees[index], by: staff.trainingMoraleBoost)
        }
        state.employees[index].lastTrainedDay = state.day
        return [.employeeTrained(employeeID: employeeID, day: state.day)]
    }

    /// What one training course costs today, after the People & HR discount.
    static func trainingCost(_ state: GameState, _ balance: BalanceConfig) -> Int {
        let cost = balance.staff.trainingCost
        guard state.hasDepartment(.hr) else { return cost }
        return Int((Double(cost) * balance.company.hrTrainingCostFactor).rounded())
    }

    /// Index of a hired (non-founder) employee, or nil.
    private static func hiredIndex(_ employeeID: UUID, _ state: GameState) -> Int? {
        guard let index = state.employees.firstIndex(where: { $0.id == employeeID }),
              !state.employees[index].isFounder
        else { return nil }
        return index
    }

    private static func bumpMorale(_ employee: inout Employee, by delta: Double) {
        employee.morale = min(100, max(0, employee.morale + delta))
    }

    /// Removes an employee from payroll. Ignored for unknown ids and for
    /// the founder, who can never be fired. Their friends take it hard.
    static func fire(employeeID: UUID, state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        guard let index = state.employees.firstIndex(where: { $0.id == employeeID }),
              !state.employees[index].isFounder
        else { return [] }

        state.employees.remove(at: index)
        var events: [GameEvent] = [.fired(employeeID: employeeID, day: state.day)]
        events.append(contentsOf: SocialSystem.friendDeparted(
            employeeID, state: &state, balance: balance
        ))
        return events
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
