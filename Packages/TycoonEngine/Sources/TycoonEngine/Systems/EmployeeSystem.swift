import Foundation
import TycoonContent

/// Daily employee system, running after `LifeSystem` and before
/// `ProductSystem`: sweeps stale product and contract assignments back to
/// idle, pours the assigned employees' output into the in-development
/// product (bug resolution stays in `ProductSystem.applyDailyProgress`) and
/// into their active contracts (settlement stays in `ContractSystem`),
/// generates research points from the employees assigned to research and
/// pays down technical debt from the ones assigned to refactoring, grows
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
        CodebaseSystem.runRefactoring(&state, balance)

        var events = updateMoraleAndQuits(&state, balance, content)
        events.append(contentsOf: trackDepartments(&state))

        if state.day % candidateRefreshInterval(state, balance) == 0 {
            refreshCandidates(&state, balance, content)
            events.append(.candidatesRefreshed(day: state.day))
        }
        if state.day % GameState.daysPerWeek == 0 {
            pruneEconomyBookkeeping(&state, balance)
        }
        return events
    }

    /// Weekly tidy-up of the economy's bookkeeping, so a long game does not
    /// carry a growing tail of dead ids and ancient dates in its save: the
    /// recognition log drops anyone who has left however they left (fired,
    /// resigned, poached, absorbed), and the hospital and burnout logs keep
    /// only the entries their "twice in a window" rules can still see.
    private static func pruneEconomyBookkeeping(_ state: inout GameState, _ balance: BalanceConfig) {
        let onPayroll = Set(state.employees.map(\.id))
        state.economy.lastRecognitionDay = state.economy.lastRecognitionDay.filter {
            onPayroll.contains($0.key)
        }
        let economy = balance.economy
        state.economy.hospitalizationDays = state.economy.hospitalizationDays.filter {
            state.day - $0 < max(economy.chronicWindowDays, 1)
        }
        state.economy.burnoutDays = state.economy.burnoutDays.filter {
            state.day - $0 < max(economy.burnoutWindowDays, 1)
        }
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
    /// raised by seniority), the office tier, People & HR, the owned
    /// amenities, and — new in the economy pass — how the place is actually
    /// being run: the company's work pace, being stuck on the same rung for
    /// a year, a room at its headcount cap, contracts running past their
    /// deadline, and a founder who has been gone for over a week.
    ///
    /// Morale below the quit threshold builds a streak. Past the streak an
    /// employee does not vanish: they hand in their notice
    /// (`.resignationNotice`), keep working, and leave on `respondByDay`
    /// unless the founder counters with a raise or a promotion. Only one
    /// notice is open at a time — the next unhappy person waits their turn.
    /// The founder has life meters instead of morale.
    private static func updateMoraleAndQuits(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        let staff = balance.staff
        let company = balance.company
        let economy = balance.economy
        let hasHR = state.hasDepartment(.hr)
        let officeBonus = (staff.officeMoraleBonus[state.company.officeTier.rawValue] ?? 0)
            + balance.city.district(state.city.district).moraleBonus
        let perkBonus = (hasHR ? company.hrMoraleBonus : 0)
            + state.ownedAmenities.reduce(0.0) { $0 + company.amenity($1).moraleBonus }
            // WS-G: the Veteran Crew perk (chapter 4's "three amenities")
            // was awarded and read by nothing. A crew that has been
            // through it sits a little higher, for everyone.
            + (state.progression.hasPerk(.veteranCrew) ? balance.progression.veteranCrewMoraleBonus : 0)
        let quitStreakDays = staff.quitStreakDays
            + (hasHR ? company.hrQuitStreakBonus : 0)
            + state.ownedAmenities.reduce(0) { $0 + company.amenity($1).quitStreakBonusDays }
        let conditions = workplaceMoraleDelta(state, balance)
        // Whoever is running this place is part of the conditions. Zero at
        // the balance's `skillMidpoint`, so an untrained founder changes
        // nothing and the pre-attribute morale numbers stand.
        let leadership = state.founderLeadershipMoraleDelta(balance)
        // The share of `conditions` that is the work pace, so a crunch can
        // land differently on different people. Only a *penalty* is
        // personal — a relaxed week is good for everybody.
        let paceMoralePenalty = min(0, economy.pace(state.economy.workPace).moraleTargetDelta)
        var events: [GameEvent] = []
        var quitting: [Int] = []
        var noticeCandidate: Int?

        for index in state.employees.indices where !state.employees[index].isFounder {
            let employee = state.employees[index]
            let fairPay = fairWeeklyPay(for: employee, balance: balance)
            // A co-founder working for equity (WS-H) reads as fairly paid
            // until the office reaches the tier they were promised.
            let ratio = state.cofounderWorksForEquity(employee, balance: balance) ? 1
                // MARK: K3 (the ladder)
                // A holder took the cut for the options: fairness reads
                // the pay before it (`weeklySalary` for everyone else).
                : (fairPay > 0 ? Double(employee.fairnessSalary) / fairPay : 1)
                // MARK: end K3
            // Exactly zero when the trait factor is 1, so a trait-less
            // roster keeps the target it had to the last bit.
            let crunchAdjustment = paceMoralePenalty
                * (TraitEffects.crunchMoraleFactor(employee, content: content) - 1)
            var target = staff.baselineMorale + officeBonus + perkBonus + conditions
                + TraitEffects.moraleTargetDelta(employee, content: content)
                + crunchAdjustment
                + leadership
                // Being close to the person you work for is worth
                // something on its own.
                + employee.founderBond * balance.relationships.bondMoraleTargetFactor
            // MARK: K3 (the ladder)
            // A lead the founder promoted with nobody much to lead: a
            // drift in the target, never a jump. 0 for everyone else.
            if state.ladderLeadIsIdle(employee, balance: balance) {
                target += balance.ladder.leads.idleMoraleDelta
            }
            // MARK: end K3
            if ratio < staff.underpaidThreshold {
                target -= staff.underpaidTargetPenalty
            } else if ratio > staff.wellPaidThreshold {
                target += staff.wellPaidTargetBonus
            }
            // Nobody has been promoted, raised or trained in a year: they
            // start reading job ads.
            let lastRecognised = state.economy.lastRecognitionDay[employee.id] ?? employee.hiredDay
            if state.day - lastRecognised >= economy.stagnationDays {
                target -= economy.stagnationMoralePenalty
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
                if state.employees[index].lowMoraleStreakDays > personalStreak,
                   noticeCandidate == nil {
                    noticeCandidate = index
                }
            } else {
                state.employees[index].lowMoraleStreakDays = 0
            }
        }

        // A notice that ran out of road: they leave today.
        if let pending = state.economy.pendingResignation, state.day >= pending.respondByDay {
            state.economy.pendingResignation = nil
            if let index = state.employees.firstIndex(where: { $0.id == pending.employeeID }) {
                quitting.append(index)
            }
        }
        // With no notice period configured (the neutral test economy) an
        // unhappy employee simply walks, which is the pre-notice behavior.
        if economy.resignationNoticeDays <= 0 {
            if let index = noticeCandidate, !quitting.contains(index) {
                quitting.append(index)
            }
        } else if state.economy.pendingResignation == nil,
                  let index = noticeCandidate,
                  !quitting.contains(index) {
            let employee = state.employees[index]
            let respondByDay = state.day + economy.resignationNoticeDays
            state.economy.pendingResignation = PendingResignation(
                employeeID: employee.id,
                name: employee.name,
                sinceDay: state.day,
                respondByDay: respondByDay,
                salaryAtNotice: employee.weeklySalary
            )
            events.append(.resignationNotice(
                employeeID: employee.id,
                name: employee.name,
                respondByDay: respondByDay,
                day: state.day
            ))
        }

        for index in quitting.reversed() {
            let employee = state.employees.remove(at: index)
            state.economy.lastRecognitionDay[employee.id] = nil
            events.append(.employeeQuit(employeeID: employee.id, name: employee.name, day: state.day))
            events.append(contentsOf: SocialSystem.friendDeparted(
                employee.id, state: &state, balance: balance
            ))
            events.append(contentsOf: NetworkingSystem.departed(
                employee, reason: .quit, state: &state, balance: balance
            ))
        }
        return events
    }

    /// What the company's own conduct does to everybody's morale target
    /// today: the work pace, a room at its cap, contracts running late, and
    /// a founder who has not been seen in over a week.
    static func workplaceMoraleDelta(_ state: GameState, _ balance: BalanceConfig) -> Double {
        let economy = balance.economy
        var delta = economy.pace(state.economy.workPace).moraleTargetDelta

        if state.headcount >= balance.office(state.company.officeTier).headcountCap {
            delta -= economy.overcrowdingMoralePenalty
        }
        let overdue = state.activeContracts.count { $0.deadlineDay < state.day }
        delta -= Double(overdue) * economy.overdueContractMoralePenalty
        if let since = state.life.awaySinceDay,
           state.life.isAway(day: state.day),
           state.day - since > economy.founderAwayDays {
            delta -= economy.founderAwayMoralePenalty
        }
        delta += founderMoraleDelta(state, balance)
        // MARK: K4 (deals and exits)
        // The office reads the papers: a for-sale sign drags the target a
        // point a week, capped. Exactly 0 while no sign stands.
        delta -= state.dealMoraleTargetDrag(balance: balance)
        // MARK: end K4
        return delta
    }

    /// What the founder personally is doing to the room.
    ///
    /// Both hooks are **penalties only**: the founder can cost the team
    /// morale and can never hand it any. That is a balance decision before
    /// it is a design one — the pacing suite encodes "crunch-and-hire
    /// mostly fails", and a room-wide morale *bonus* for a founder who was
    /// crunching anyway is a free buff the bots collect without ever
    /// paying the evening budget or the meters that are supposed to price
    /// it. Measured: a symmetric version of these two hooks took board
    /// oustings from 3 in 10 to 0 and pulled `hardModeIsGenuinelyHard`
    /// under its floor, at every rebate size, because a bot's founder
    /// keeps their mood topped up with weekends.
    ///
    /// It also reads better. Nobody's morale goes up because the boss
    /// seems cheerful; everybody notices when the boss is falling apart,
    /// and everybody notices who went home at five during a crunch.
    ///
    /// - **A founder in a bad way.** Below `founderMoodMoraleFloor` the
    ///   room takes `founderMoodMoraleFactor` per point. This is what
    ///   finally gives the hobby / shopping / home half of the Life tab a
    ///   company-side reason to exist: it used to feed nothing but the
    ///   founder's own small share of output.
    /// - **What the founder takes home.** Pay above
    ///   `founderPayFairRatio` × the team's median is noticed, on a slope,
    ///   capped. The salary stepper used to have exactly one downside —
    ///   company cash — which made it the free pipe behind every personal
    ///   purchase in the game.
    /// - **Whose crunch is it.** The company has a work pace and the
    ///   founder has a work schedule, and until now neither knew the other
    ///   existed: a founder could put the team on crunch from a deckchair.
    ///   While the *team* is crunching, a founder on chill costs the room
    ///   `paceMismatchMoralePenalty`, one on normal half of it, and one
    ///   crunching alongside them nothing. A relaxed company does not care
    ///   what hours the founder keeps.
    static func founderMoraleDelta(_ state: GameState, _ balance: BalanceConfig) -> Double {
        let economy = balance.economy
        var delta = min(
            0,
            (state.life.meters.mood - economy.founderMoodMoraleFloor) * economy.founderMoodMoraleFactor
        )

        if state.economy.workPace == .crunch, !state.life.isAway(day: state.day) {
            switch state.effectiveSchedule {
            case .chill: delta -= economy.paceMismatchMoralePenalty
            case .normal: delta -= economy.paceMismatchMoralePenalty / 2
            case .crunch: break
            }
        }
        // And what the founder is paying themselves, against what they pay
        // everybody else.
        delta -= state.founderPayMoralePenalty(balance: balance)
        return delta
    }

    /// Records that an employee was recognised today — hired, raised,
    /// promoted or trained — resetting the stagnation clock.
    static func recordRecognition(_ employeeID: UUID, _ state: inout GameState) {
        state.economy.lastRecognitionDay[employeeID] = state.day
    }

    /// Answers an open resignation notice. A raise that clears
    /// `counterOfferRaiseFactor` of the salary they resigned on — or any
    /// promotion — keeps them: morale jumps, the streak resets, and the
    /// notice is withdrawn. Anything less is not a counter-offer.
    private static func answerResignation(
        _ employeeID: UUID,
        newSalary: Int?,
        promoted: Bool,
        state: inout GameState,
        balance: BalanceConfig
    ) {
        guard let pending = state.economy.pendingResignation,
              pending.employeeID == employeeID
        else { return }
        let enough = promoted || newSalary.map {
            Double($0) >= Double(pending.salaryAtNotice) * balance.economy.counterOfferRaiseFactor
        } ?? false
        guard enough else { return }

        state.economy.pendingResignation = nil
        guard let index = state.employees.firstIndex(where: { $0.id == employeeID }) else { return }
        bumpMorale(&state.employees[index], by: balance.economy.counterOfferMoraleBoost)
        state.employees[index].lowMoraleStreakDays = 0
    }

    /// The weekly pay an employee considers fair. Lives on `BalanceConfig`
    /// so screens can show the number the morale system actually uses
    /// rather than re-deriving it.
    static func fairWeeklyPay(for employee: Employee, balance: BalanceConfig) -> Double {
        balance.fairWeeklyPay(for: employee)
    }

    // MARK: - Daily sweep

    /// Resets assignments pointing at gone targets back to `.idle`:
    /// products that are released (unless a patch cycle is running on them)
    /// or nonexistent, contracts that completed, failed, or never existed,
    /// support desks whose product has left the market, and refactor desks
    /// on a codebase that does not exist. Research assignments are left
    /// alone.
    ///
    /// A codebase is never deleted once it exists, so in practice the
    /// refactor sweep only fires on a hand-built or hand-edited state —
    /// but leaving somebody permanently assigned to nothing is exactly the
    /// bug this sweep exists to prevent.
    private static func sweepStaleAssignments(_ state: inout GameState) {
        for index in state.employees.indices {
            switch state.employees[index].assignment {
            case .product(let productID):
                if let product = state.product(id: productID),
                   case .development = product.stage { continue }
                // A patch cycle keeps its crew on the released product it
                // is patching.
                if state.economy.update(for: productID) != nil { continue }
                state.employees[index].assignment = .idle
            case .contract(let contractID):
                if state.activeContract(id: contractID) != nil { continue }
                state.employees[index].assignment = .idle
            case .support(let productID):
                if case .released(let info)? = state.product(id: productID)?.stage,
                   !info.offMarket { continue }
                state.employees[index].assignment = .idle
            case .refactor(let codebaseID):
                if state.codebase(id: codebaseID) != nil { continue }
                state.employees[index].assignment = .idle
            case .idle, .research:
                continue
            }
        }
    }

    // MARK: - Daily output

    /// Every employee assigned to a product in development — or to a
    /// released product with a patch cycle running — contributes
    /// points split by the product's focus and shaped by their role:
    /// `poolYield = focusShare * roleYield * (employeeBasePoints + relevantSkill / skillYieldDivisor)`
    /// where the code pool draws on coding, the design pool on design, and
    /// the polish pool on the mean of both. The day's pool totals are then
    /// scaled by the tech dev-speed multiplier. Polish from QA engineers
    /// fixes `qaBugFixMultiplier` bugs per point (the day's blended rate is
    /// handed to `applyDailyProgress`), and every marketer on the product
    /// adds `marketerDailyHype × (1 + marketing/100) × hypeFactor` hype.
    /// The crew's `bugMult` traits scale the day's bug chance. Afterwards each
    /// skill that fed a pool grows by `skillGrowthRate * (1 - skill/100)`,
    /// capped at 100.
    private static func produceDailyOutput(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) {
        // Every product in development gets its own crew and its own day.
        for productIndex in state.products.indices {
            guard case .development(let dev) = state.products[productIndex].stage else { continue }
            buildProduct(at: productIndex, focus: dev.focus, &state, balance, content)
        }
        // Patches on released products draw from the same pool of hands.
        for updateIndex in state.economy.updates.indices {
            patchProduct(at: updateIndex, &state, balance, content)
        }
    }

    /// One day of work on one in-development product.
    private static func buildProduct(
        at productIndex: Int,
        focus: PhaseFocus,
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) {
        let productID = state.products[productIndex].id
        let crew = gatherCrewOutput(
            productID: productID, focus: focus, state: state, balance: balance, content: content
        )
        let pace = balance.economy.pace(state.economy.workPace)
        let output = state.devSpeedTechMultiplier(content: content)
            // MARK: K3 (the ladder) — Brooks, with a promoted lead's relief.
            * state.ladderCrowdingFactor(producers: crew.producers, balance: balance)
            // MARK: end K3
            * pace.outputFactor

        // Read out of `state` before the `&state` call below: the crew's
        // care is a property of who is at the desk today.
        let crewBugFactor = TraitEffects.crewBugFactor(
            crew.producers.map { state.employees[$0] }, content: content
        )
        // Bugs you did not write: a debt-laden codebase breaks in places
        // nobody on this team has ever read. Exactly 1 on a greenfield
        // build, which is every build the pacing bots ever start.
        let codebaseBugFactor = balance.codebase.bugRateMultiplier(
            state.inheritedDebt(for: state.products[productIndex])
        )

        ProductSystem.applyDailyProgress(
            design: crew.design * output,
            code: crew.code * output,
            polish: crew.polish * output,
            averageCoding: crew.producers.isEmpty
                ? balance.founderCoding
                : crew.codingSum / Double(crew.producers.count),
            bugChanceMultiplier: (crew.founderWorked
                ? state.founderBugChanceMultiplier(balance: balance)
                : 1) * pace.bugFactor * crewBugFactor * codebaseBugFactor,
            bugFixMultiplier: crew.bugFixMultiplier(balance: balance),
            productIndex: productIndex, state: &state, balance: balance
        )
        // Record who built it today, for the ship-time quality ceiling.
        if !crew.producers.isEmpty,
           case .development(var progress) = state.products[productIndex].stage {
            progress.hype += crew.hype
            progress.crewSkillDaySum += ProductSystem.crewSkillSample(
                designSkillSum: crew.designSum,
                codingSkillSum: crew.codingSum,
                crewCount: crew.producers.count,
                balance: balance
            )
            progress.crewSkillDays += 1
            state.products[productIndex].stage = .development(progress)
        }
        // A crunch week takes shortcuts, and the shortcuts stay in the
        // code. Charged only when somebody actually worked today.
        if !crew.producers.isEmpty {
            CodebaseSystem.accrueDailyDebt(
                productIndex: productIndex, state: &state, balance: balance
            )
        }
        growProducers(crew.producers, focus: focus, pace: pace, &state, balance, content)
    }

    /// One day of work on one patch cycle. The crew is whoever is assigned
    /// to the released product; the focus follows whatever the patch still
    /// needs, so a patch always finishes rather than stalling on a pool the
    /// player has no way to re-aim.
    private static func patchProduct(
        at updateIndex: Int,
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) {
        let update = state.economy.updates[updateIndex]
        let focus = PhaseFocus(
            design: max(0, update.designPts - update.progressDesign),
            code: max(0, update.codePts - update.progressCode),
            polish: max(0, update.polishPts - update.progressPolish)
        ).normalized
        let crew = gatherCrewOutput(
            productID: update.productID, focus: focus,
            state: state, balance: balance, content: content
        )
        guard !crew.producers.isEmpty else { return }

        let pace = balance.economy.pace(state.economy.workPace)
        let output = state.devSpeedTechMultiplier(content: content)
            // MARK: K3 (the ladder) — a patch crew is led the same way.
            * state.ladderCrowdingFactor(producers: crew.producers, balance: balance)
            // MARK: end K3
            * pace.outputFactor
        state.economy.updates[updateIndex].progressDesign += crew.design * output
        state.economy.updates[updateIndex].progressCode += crew.code * output
        state.economy.updates[updateIndex].progressPolish += crew.polish * output
        growProducers(crew.producers, focus: focus, pace: pace, &state, balance, content)
    }

    /// One day's raw pool output from everyone assigned to `productID`,
    /// before the tech, crowding and pace multipliers.
    struct CrewOutput {
        var design = 0.0
        var code = 0.0
        var polish = 0.0
        var qaPolish = 0.0
        var hype = 0.0
        var codingSum = 0.0
        var designSum = 0.0
        var producers: [Int] = []
        var founderWorked = false

        /// Bugs fixed per completed polish point, blended over who produced
        /// today's polish (exactly 1 without QA, exactly the multiplier with
        /// only QA).
        func bugFixMultiplier(balance: BalanceConfig) -> Double {
            guard polish > 0 else { return 1 }
            return (polish - qaPolish + qaPolish * balance.company.qaBugFixMultiplier) / polish
        }
    }

    static func gatherCrewOutput(
        productID: UUID,
        focus: PhaseFocus,
        state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> CrewOutput {
        let company = balance.company
        let founderAway = state.life.isAway(day: state.day)
        let founderFactor = state.founderOutputMultiplier(balance: balance)
        // Working next to a friend lifts output (strongest co-assigned bond).
        let crewIDs = state.employees
            .filter { if case .product(let id) = $0.assignment { return id == productID }; return false }
            .map(\.id)

        var out = CrewOutput()
        for index in state.employees.indices {
            guard case .product(let assignedID) = state.employees[index].assignment,
                  assignedID == productID else { continue }
            let isFounder = state.employees[index].isFounder
            if isFounder, founderAway { continue }
            let bond = SocialSystem.strongestBond(
                for: state.employees[index].id, among: crewIDs, in: state
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
            out.design += factor * focus.design * yield.design
                * (balance.employeeBasePoints + skills.design / balance.skillYieldDivisor)
            out.code += factor * focus.code * yield.code
                * (balance.employeeBasePoints + skills.coding / balance.skillYieldDivisor)
            let polishShare = factor * focus.polish * yield.polish
                * (balance.employeeBasePoints + (skills.coding + skills.design) / 2 / balance.skillYieldDivisor)
            out.polish += polishShare
            if role == .qa { out.qaPolish += polishShare }
            if role == .marketer {
                out.hype += company.marketerDailyHype * (1 + skills.marketing / 100)
                    * TraitEffects.hypeFactor(state.employees[index], content: content)
            }
            out.codingSum += skills.coding
            out.designSum += skills.design
            out.producers.append(index)
            if isFounder { out.founderWorked = true }
        }
        return out
    }

    /// Skill growth for the skills that fed a pool today: coding feeds the
    /// code and polish pools, design feeds the design and polish pools.
    private static func growProducers(
        _ producers: [Int],
        focus: PhaseFocus,
        pace: BalanceConfig.EconomyBalance.PaceDef,
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) {
        let growsCoding = focus.code > 0 || focus.polish > 0
        let growsDesign = focus.design > 0 || focus.polish > 0
        guard growsCoding || growsDesign else { return }
        for index in producers {
            // Read the trait factor before the inout growth calls: taking
            // `&state.employees[index]...` and reading `state.employees`
            // in the same call would overlap exclusive access.
            let growthRate = balance.skillGrowthRate
                * pace.skillGrowthFactor
                * TraitEffects.growthFactor(state.employees[index], content: content)
            if growsCoding {
                grow(&state.employees[index].skills.coding, rate: growthRate)
            }
            if growsDesign {
                grow(&state.employees[index].skills.design, rate: growthRate)
            }
        }
    }

    /// One day of code points the crew currently assigned to `productID`
    /// would add, at today's tech, crowding and pace multipliers — exactly
    /// the `crew.code * output` that `buildProduct` hands to
    /// `applyDailyProgress`, read out of an unmutated state and drawing no
    /// random numbers. `GameState.shipETA` turns it into a day.
    static func dailyCodeOutput(
        productID: UUID,
        focus: PhaseFocus,
        state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> Double {
        let crew = gatherCrewOutput(
            productID: productID, focus: focus, state: state, balance: balance, content: content
        )
        let pace = balance.economy.pace(state.economy.workPace)
        return crew.code
            * state.devSpeedTechMultiplier(content: content)
            // MARK: K3 (the ladder)
            * state.ladderCrowdingFactor(producers: crew.producers, balance: balance)
            // MARK: end K3
            * pace.outputFactor
    }

    /// Brooks's law as one number: `n` people working the same job each
    /// produce `1 / (1 + brooksPenalty × (n − 1))` of a solo day. A penalty
    /// of 0 (the neutral test economy) restores the old straight sum.
    static func crowdingFactor(producerCount: Int, balance: BalanceConfig) -> Double {
        guard producerCount > 1 else { return 1 }
        return 1 / (1 + balance.economy.brooksPenalty * Double(producerCount - 1))
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
        let pace = balance.economy.pace(state.economy.workPace)
        // A contract crew crowds the same way a product crew does.
        var crewSizes: [UUID: Int] = [:]
        for employee in state.employees {
            if case .contract(let id) = employee.assignment {
                crewSizes[id, default: 0] += 1
            }
        }

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
            let output = devSpeed * pace.outputFactor * crowdingFactor(
                producerCount: crewSizes[contractID] ?? 1, balance: balance
            )
            state.activeContracts[jobIndex].progressCode += factor * yield.code
                * (balance.employeeBasePoints + skills.coding / balance.skillYieldDivisor) * output
            state.activeContracts[jobIndex].progressDesign += factor * yield.design
                * (balance.employeeBasePoints + skills.design / balance.skillYieldDivisor) * output
            // Record the crew's skill for the delivery-quality grade.
            state.activeContracts[jobIndex].skillDaySum += (skills.coding + skills.design) / 2
            state.activeContracts[jobIndex].skillDays += 1
            let growthRate = balance.skillGrowthRate * pace.skillGrowthFactor
            grow(&state.employees[index].skills.coding, rate: growthRate)
            grow(&state.employees[index].skills.design, rate: growthRate)
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
        let count = state.rng.nextInt(in: balance.candidateCountMin...balance.candidateCountMax)
        let ceiling = candidateSkillCeiling(state, balance)
        let eligibleRoles = candidateRoles(state, balance)
        let askFactor = candidateAskFactor(state, balance)

        var pool: [Candidate] = []
        pool.reserveCapacity(count)
        for _ in 0..<count {
            pool.append(rollCandidate(
                roles: eligibleRoles,
                ceiling: ceiling,
                askFactor: askFactor,
                balance: balance,
                content: content,
                rng: &state.rng
            ))
        }
        state.candidatePool = pool
    }

    // MARK: P1 (purchases: engine)
    // Iteration 13 — P1. The pool's roll, extracted so the bought veteran
    // (`PurchaseRule.veteranOnOffer`) is rolled by the same code from its
    // own private stream. The pool calls it with `&state.rng` and the
    // default floor and cap, which is the arithmetic and the draw order it
    // always had: the day-30 fixtures are byte-identical.

    /// The pool's skill ceiling: base, reputation, office tier, district
    /// and the `talentMagnet` perk, clamped to 5...100. Draws nothing.
    static func candidateSkillCeiling(_ state: GameState, _ balance: BalanceConfig) -> Double {
        let tierBonus = balance.candidateSkillTierBonus[state.company.officeTier.rawValue] ?? 0
        let districtBonus = balance.city.district(state.city.district).candidateSkillBonus
        // WS-F's `talentMagnet` perk had no consumer: candidate ceilings are
        // computed here, in WS-A's file. Wired at integration — a studio
        // that earned the perk sees better people on the sheet.
        let perkBonus = state.progression.hasPerk(.talentMagnet)
            ? balance.progression.talentMagnetSkillBonus
            : 0
        return min(100, max(5,
            balance.candidateSkillBase
                + state.company.reputation * balance.candidateSkillPerReputation
                + tierBonus
                + districtBonus
                + perkBonus
        ))
    }

    /// The roles this office can hire, in `EmployeeRole.allCases` order.
    static func candidateRoles(_ state: GameState, _ balance: BalanceConfig) -> [EmployeeRole] {
        let company = balance.company
        return EmployeeRole.allCases.filter { role in
            role != .founder
                && (company.candidateRoleWeights[role.rawValue] ?? 0) > 0
                && state.company.officeTier.rank >= company.candidateMinTier(role).rank
        }
    }

    /// WS-D: a studio with a leave policy is a cheaper place to say yes
    /// to. One multiplier on the ask, 1.0 without the flag, no draw.
    static func candidateAskFactor(_ state: GameState, _ balance: BalanceConfig) -> Double {
        state.narrative.hasFlag(StaffPolicyFlag.goodLeavePolicy)
            ? balance.staff.leavePolicyAskFactor
            : 1
    }

    /// One candidate, in the pool's fixed draw order: id (two words), first
    /// name, last name, role (one word, only when more than one role is
    /// eligible), coding, design, marketing, salary jitter, appearance seed.
    ///
    /// - `ceiling`: every skill's ceiling; a role's primary skill adds its
    ///   bonus, capped at `skillCap`.
    /// - `skillSpread`: `nil` rolls each skill in 5...its ceiling (the
    ///   pool); a spread rolls it in (ceiling − spread)...ceiling (the
    ///   veteran, who is *at* the ceiling rather than under it).
    /// - `askFactor`: multiplies the salary formula (the leave policy; the
    ///   veteran's 1.4×).
    static func rollCandidate(
        roles eligible: [EmployeeRole],
        ceiling: Double,
        skillSpread: Double? = nil,
        skillCap: Double = 100,
        askFactor: Double,
        balance: BalanceConfig,
        content: ContentCatalog,
        rng: inout SeededRNG
    ) -> Candidate {
        let company = balance.company
        let id = UUID(from: &rng)
        let name = "\(pick(content.names.firstNames, &rng)) \(pick(content.names.lastNames, &rng))"
        let role = rollRole(eligible, weights: company.candidateRoleWeights, &rng)

        var codingCeiling = ceiling, designCeiling = ceiling, marketingCeiling = ceiling
        switch role.primarySkill {
        case .coding: codingCeiling = min(skillCap, ceiling + company.builderPrimarySkillBonus)
        case .design: designCeiling = min(skillCap, ceiling + company.builderPrimarySkillBonus)
        case .marketing: marketingCeiling = min(skillCap, ceiling + company.marketerSkillBonus)
        case nil: break
        }
        let skills = SkillSet(
            coding: rollSkill(upTo: codingCeiling, spread: skillSpread, &rng),
            design: rollSkill(upTo: designCeiling, spread: skillSpread, &rng),
            marketing: rollSkill(upTo: marketingCeiling, spread: skillSpread, &rng)
        )
        let jitter = 1 + (rng.nextUniform() * 2 - 1) * balance.salaryJitter
        let salaryFactor = role.department != nil ? company.supportSalaryFactor : 1
        let salary = (Double(balance.salaryBase) + balance.salaryPerSkillPoint * skills.total)
            * jitter * salaryFactor * askFactor
        return Candidate(
            id: id,
            name: name,
            skills: skills,
            weeklySalary: Int(salary.rounded()),
            appearanceSeed: rng.next(),
            role: role
        )
    }

    /// A skill in `(ceiling − spread)...ceiling`, floored at 5. With no
    /// spread this is `rollSkill(upTo:)`, the pool's roll, exactly.
    private static func rollSkill(upTo ceiling: Double, spread: Double?, _ rng: inout SeededRNG) -> Double {
        guard let spread else { return rollSkill(upTo: ceiling, &rng) }
        let floor = min(ceiling, max(5, ceiling - spread))
        return floor + rng.nextUniform() * (ceiling - floor)
    }
    // MARK: end P1

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
        // MARK: J2 (record)
        // The founder's name, read at the moment of hiring rather than at
        // the roll: the best CV past the line will not come in, and every
        // other ask carries the premium. Exactly the rolled salary, and
        // nobody refusing, at a name of zero.
        guard !state.standingRefuses(candidateID, balance: balance) else { return [] }
        let standingAsk = state.standingAsk(for: state.candidatePool[poolIndex], balance: balance)
        // MARK: end J2

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
            // MARK: J2 (record) — what they asked, name and all.
            weeklySalary: standingAsk,
            // MARK: end J2
            assignment: assignment,
            isFounder: false,
            hiredDay: state.day,
            appearanceSeed: candidate.appearanceSeed,
            morale: balance.staff.startingMorale,
            level: .forSkillTotal(candidate.skills.total),
            role: candidate.role
        ))
        recordRecognition(candidate.id, &state)
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
        // MARK: K3 (the ladder)
        // Paid back up to (or past) what they earned before the grant:
        // the cut is over, and fairness reads the real salary again.
        if let prior = state.employees[index].salaryBeforeGrant, weeklySalary >= prior {
            state.employees[index].salaryBeforeGrant = nil
        }
        // MARK: end K3
        let fraction = Double(weeklySalary - before) / Double(before)
        let staff = balance.staff
        let moraleDelta = fraction >= 0
            ? fraction * staff.raiseMoraleFactor
            : fraction * staff.cutMoraleFactor
        state.employees[index].weeklySalary = weeklySalary
        bumpMorale(&state.employees[index], by: moraleDelta)
        if moraleDelta > 0 {
            recordRecognition(employeeID, &state)
        }
        answerResignation(
            employeeID, newSalary: weeklySalary, promoted: false, state: &state, balance: balance
        )
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
        // MARK: K3 (the ladder)
        // The founder made them lead: from today they run a room.
        if next == .lead {
            state.employees[index].leadSinceDay = state.day
        }
        // MARK: end K3
        state.employees[index].weeklySalary = Int(
            (Double(state.employees[index].weeklySalary) * (1 + staff.promotionSalaryBump)).rounded()
        )
        bumpMorale(&state.employees[index], by: staff.promotionMoraleBoost)
        recordRecognition(employeeID, &state)
        answerResignation(
            employeeID, newSalary: nil, promoted: true, state: &state, balance: balance
        )
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
        // MARK: K3 (the ladder)
        state.employees[index].leadSinceDay = nil
        // MARK: end K3
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
        recordRecognition(employeeID, &state)
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

        let employee = state.employees.remove(at: index)
        state.economy.lastRecognitionDay[employeeID] = nil
        if state.economy.pendingResignation?.employeeID == employeeID {
            state.economy.pendingResignation = nil
        }
        var events: [GameEvent] = [.fired(employeeID: employeeID, day: state.day)]
        events.append(contentsOf: SocialSystem.friendDeparted(
            employeeID, state: &state, balance: balance
        ))
        events.append(contentsOf: NetworkingSystem.departed(
            employee, reason: .fired, state: &state, balance: balance
        ))
        return events
    }

    /// Sets the pace the whole company works at. No event — the effects
    /// show up in tomorrow's output, morale and bug rolls.
    static func setWorkPace(_ pace: WorkPace, state: inout GameState) -> [GameEvent] {
        state.economy.workPace = pace
        return []
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
