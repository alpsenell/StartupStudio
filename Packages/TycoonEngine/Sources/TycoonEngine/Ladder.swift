import Foundation
import TycoonContent

// Iteration 15 — K3 (the ladder).
//
// Two things the founder can give a person besides a raise:
//
// 1. **A room to run** (company.md §3). `promote` to lead writes
//    `Employee.leadSinceDay`. One promoted lead on a build softens Brooks's
//    crowding penalty for up to `leads.span` of the others; two cancel
//    each other out; a promoted lead with too few people to lead drifts
//    unhappy. The factor was always there and never printed: every build
//    card now says *8 people · ×0.59 each · lead: none*.
// 2. **A piece of the company** (company.md §4). `grantEquity` gives 1% or
//    2% for a pay cut, vests over four years after a one-year cliff, and
//    comes back if they leave before it vests. A poacher weighs the
//    unvested part; a poached holder takes what vested with them.
//
// Identity: every read here returns the pre-ladder answer when nobody on
// the roster has `leadSinceDay` set and nobody has `grantedEquity`, which
// is every run a bot plays. Nothing here draws.

/// Who is working one build today and what crowding does to each of them.
public struct LadderCrew: Equatable, Sendable {
    /// Producers on the build today (an away founder is not one).
    public var count: Int
    /// What each of them produces against a solo day, after crowding and
    /// any lead's relief.
    public var factor: Double
    /// The factor with nobody leading: Brooks as it always was.
    public var unledFactor: Double
    /// The one promoted lead running the build, if there is exactly one.
    public var leadName: String?
    /// Two or more promoted leads on the build: nobody's relief applies.
    public var leadsColliding: Bool
    /// How many of the others the lead is carrying (the span caps it).
    public var relievedCount: Int

    public init(
        count: Int, factor: Double, unledFactor: Double,
        leadName: String?, leadsColliding: Bool, relievedCount: Int
    ) {
        self.count = count
        self.factor = factor
        self.unledFactor = unledFactor
        self.leadName = leadName
        self.leadsColliding = leadsColliding
        self.relievedCount = relievedCount
    }
}

/// What one grant would cost and give, at today's valuation.
public struct LadderGrantQuote: Equatable, Sendable {
    public var percent: Int
    /// Percent of today's valuation, in dollars.
    public var valueToday: Int
    /// Taken off their weekly salary.
    public var payCut: Int
    /// Their salary after the cut.
    public var newSalary: Int
    /// True when this would be the first point the founder gives up: the
    /// *Still yours* ending closes on it.
    public var closesStillYours: Bool
    /// Why it cannot be done, or `nil`.
    public var blocker: String?
}

extension Employee {
    /// A lead the founder promoted (not one hired in at the top).
    public var isPromotedLead: Bool {
        level == .lead && leadSinceDay != nil
    }

    /// Whether this person holds options.
    public var holdsOptions: Bool { grantedEquity > 0 }

    /// The salary the morale system reads for pay fairness: what they took
    /// home before the grant's cut, until a raise overtakes it. Exactly
    /// `weeklySalary` for anyone who was never granted.
    public var fairnessSalary: Int {
        guard grantedEquity > 0, let before = salaryBeforeGrant else { return weeklySalary }
        return max(weeklySalary, before)
    }

    /// Points vested on `day`: nothing before the cliff, straight-line to
    /// the full grant at `vestDays`.
    public func vestedEquity(day: Int, balance: BalanceConfig) -> Double {
        guard grantedEquity > 0, let grantDay else { return 0 }
        let grants = balance.ladder.grants
        let held = day - grantDay
        guard held >= grants.cliffDays else { return 0 }
        guard grants.vestDays > 0 else { return grantedEquity }
        return grantedEquity * min(1, Double(held) / Double(grants.vestDays))
    }

    /// Points that would come back to the founder if they left on `day`.
    public func unvestedEquity(day: Int, balance: BalanceConfig) -> Double {
        max(0, grantedEquity - vestedEquity(day: day, balance: balance))
    }

    /// The day the cliff passes, if they hold options.
    public func cliffDay(balance: BalanceConfig) -> Int? {
        grantDay.map { $0 + balance.ladder.grants.cliffDays }
    }
}

extension GameState {
    // MARK: - Leads

    /// Brooks's law with a lead in the room. With no promoted lead among
    /// `producers`, or two or more of them, this is
    /// `EmployeeSystem.crowdingFactor(producerCount:)` exactly. With one,
    /// the lead carries up to `span` of the others at `penaltyFactor` of
    /// the penalty and the rest pay full:
    /// `1 / (1 + p × (f × min(span, n−1) + max(0, n−1−span)))`.
    func ladderCrowdingFactor(producers: [Int], balance: BalanceConfig) -> Double {
        let count = producers.count
        let unled = EmployeeSystem.crowdingFactor(producerCount: count, balance: balance)
        guard count > 1 else { return unled }
        let leads = producers.filter { employees[$0].isPromotedLead }
        guard leads.count == 1 else { return unled }
        let config = balance.ladder.leads
        let others = count - 1
        let relieved = min(max(0, config.span), others)
        let extra = others - relieved
        let penalty = balance.economy.brooksPenalty
            * (config.penaltyFactor * Double(relieved) + Double(extra))
        return 1 / (1 + penalty)
    }

    /// The crew line for one build: *8 people · ×0.59 each · lead: none*.
    /// `nil` for anything nobody could be assigned to.
    public func ladderCrew(
        productID: UUID,
        balance: BalanceConfig
    ) -> LadderCrew? {
        guard product(id: productID) != nil else { return nil }
        let founderAway = life.isAway(day: day)
        let producers = employees.indices.filter { index in
            guard case .product(let id) = employees[index].assignment, id == productID else { return false }
            return !(employees[index].isFounder && founderAway)
        }
        let leads = producers.filter { employees[$0].isPromotedLead }
        let others = max(0, producers.count - 1)
        return LadderCrew(
            count: producers.count,
            factor: ladderCrowdingFactor(producers: producers, balance: balance),
            unledFactor: EmployeeSystem.crowdingFactor(producerCount: producers.count, balance: balance),
            leadName: leads.count == 1 ? employees[leads[0]].name : nil,
            leadsColliding: leads.count > 1,
            relievedCount: leads.count == 1 ? min(max(0, balance.ladder.leads.span), others) : 0
        )
    }

    /// What `employeeID`'s crew would read if they were a promoted lead on
    /// the build they are on now (the promote button's preview). `nil` off
    /// a build.
    public func ladderCrewIfLed(
        by employeeID: UUID,
        balance: BalanceConfig
    ) -> LadderCrew? {
        guard let index = employees.firstIndex(where: { $0.id == employeeID }),
              case .product(let productID) = employees[index].assignment
        else { return nil }
        var preview = self
        preview.employees[index].level = .lead
        preview.employees[index].leadSinceDay = day
        return preview.ladderCrew(productID: productID, balance: balance)
    }

    /// Whether a promoted lead has a room to run: on a build with at least
    /// `idleMinCrew` others. Everybody else is not idle in this sense.
    public func ladderLeadIsIdle(_ employee: Employee, balance: BalanceConfig) -> Bool {
        guard employee.isPromotedLead else { return false }
        guard case .product(let productID) = employee.assignment,
              let product = product(id: productID)
        else { return true }
        // A build in development or a patch cycle is a room; anything
        // else (a released product with no patch) is not.
        let isWork: Bool = if case .development = product.stage {
            true
        } else {
            economy.update(for: productID) != nil
        }
        guard isWork else { return true }
        let others = employees.count {
            $0.id != employee.id && $0.assignment == .product(productID)
        }
        return others < balance.ladder.leads.idleMinCrew
    }

    /// The promotion-demand gate (company.md §3), engaged only once the
    /// founder has promoted a lead: from then on the ask comes from a
    /// senior on a build of four or more with no promoted lead — the day
    /// the title would actually mean something. Before that, `true`, so
    /// the staff-event roll reads exactly as it always did.
    func ladderAllowsPromotionDemand(_ employee: Employee) -> Bool {
        guard employees.contains(where: \.isPromotedLead) else { return true }
        guard employee.level == .senior,
              case .product(let productID) = employee.assignment
        else { return false }
        let crew = employees.filter { $0.assignment == .product(productID) }
        return crew.count >= 4 && !crew.contains(where: \.isPromotedLead)
    }

    // MARK: - Options

    /// Option points out right now, across everyone on payroll and every
    /// alumnus who kept what vested.
    public var ladderOptionsOutstanding: Double {
        networking.grants.filter { $0.reason == .options }.reduce(0) { $0 + $1.percent }
    }

    /// The trade, printed: what `percent` of today's company is worth, what
    /// comes off their pay, and whether *Still yours* closes on it.
    public func ladderGrantQuote(
        employeeID: UUID,
        percent: Int,
        balance: BalanceConfig
    ) -> LadderGrantQuote? {
        guard let employee = employee(id: employeeID) else { return nil }
        let cut = ladderPayCut(employee, percent: percent, balance: balance)
        let valuation = companyValuation(balance: balance)
        return LadderGrantQuote(
            percent: percent,
            valueToday: Int((Double(valuation) * Double(percent) / 100).rounded()),
            payCut: cut,
            newSalary: max(1, employee.weeklySalary - cut),
            closesStillYours: investors.equityRemaining >= 100,
            blocker: ladderGrantBlocker(employeeID: employeeID, percent: percent, balance: balance)
        )
    }

    /// Why `percent` cannot be granted to `employeeID` today, or `nil`.
    public func ladderGrantBlocker(
        employeeID: UUID,
        percent: Int,
        balance: BalanceConfig
    ) -> String? {
        let grants = balance.ladder.grants
        guard BalanceConfig.GrantBalance.sizes.contains(percent) else { return "Grants come in 1% or 2%." }
        guard let employee = employee(id: employeeID), !employee.isFounder else {
            return "Only people on the payroll."
        }
        if employee.isCofounder { return "They already own a slice from the founding." }
        if employee.holdsOptions { return "They already hold options." }
        if gameOver != nil { return "The company is finished." }
        let outstanding = ladderOptionsOutstanding
        if outstanding + Double(percent) > grants.poolMax + 0.000_1 {
            let left = max(0, grants.poolMax - outstanding)
            return "The option pool is \(Int(grants.poolMax))%. "
                + (left < 1 ? "It is all out." : "\(Self.ladderPoints(left)) is left.")
        }
        if investors.equityRemaining < Double(percent) {
            return "You have \(Self.ladderPoints(investors.equityRemaining)) of the company left."
        }
        return nil
    }

    /// The weekly cut for a grant: a fraction of fair pay.
    func ladderPayCut(_ employee: Employee, percent: Int, balance: BalanceConfig) -> Int {
        let fraction = balance.ladder.grants.payCutFraction(percent: percent)
        return Int((balance.fairWeeklyPay(for: employee) * fraction).rounded())
    }

    /// A rival's poach score, adjusted for a holder: the cut they took does
    /// not read as underpayment, and every unvested point is a buy-out the
    /// offer would have to cover. Exactly 0 for anyone never granted.
    func ladderPoachScoreDelta(
        _ employee: Employee,
        fairPay: Double,
        underpaidWeight: Double,
        balance: BalanceConfig
    ) -> Double {
        guard employee.grantedEquity > 0, fairPay > 0 else { return 0 }
        let paid = max(0, (fairPay - Double(employee.weeklySalary)) / fairPay)
        let fair = max(0, (fairPay - Double(employee.fairnessSalary)) / fairPay)
        return underpaidWeight * (fair - paid)
            - balance.ladder.grants.poachUnvestedWeight * employee.unvestedEquity(day: day, balance: balance)
    }

    /// "1.5%", "2%": a percentage for a sentence.
    public static func ladderPoints(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded()
            ? "\(Int(rounded))%"
            : String(format: "%.1f%%", rounded)
    }
}

// MARK: - The actions

extension EmployeeSystem {
    /// `grantEquity`: `percent` points of the company for a pay cut of
    /// `payCut` × fair pay, loyalty and bond on the day, recorded on the
    /// cap table as an `.options` grant. Refused with no event for any
    /// reason `ladderGrantBlocker` names.
    static func grantEquity(
        employeeID: UUID,
        percent: Int,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard state.ladderGrantBlocker(employeeID: employeeID, percent: percent, balance: balance) == nil,
              let index = state.employees.firstIndex(where: { $0.id == employeeID })
        else { return [] }
        let grants = balance.ladder.grants
        let employee = state.employees[index]
        let cut = state.ladderPayCut(employee, percent: percent, balance: balance)
        let points = Double(percent)

        state.employees[index].salaryBeforeGrant = employee.weeklySalary
        state.employees[index].weeklySalary = max(1, employee.weeklySalary - cut)
        state.employees[index].loyalty = min(100, employee.loyalty + grants.loyalty)
        state.employees[index].founderBond = min(100, employee.founderBond + grants.bond)
        state.employees[index].grantedEquity = points
        state.employees[index].grantDay = state.day
        state.investors.equityRemaining = max(0, state.investors.equityRemaining - points)
        state.networking.grants.append(EquityGrant(
            id: employee.id, name: employee.name, percent: points, day: state.day, reason: .options
        ))
        recordRecognition(employeeID, &state)
        return [.ladderEquityGranted(
            employeeID: employee.id, name: employee.name, percent: points,
            payCut: cut, day: state.day
        )]
    }

    /// Settles a departing holder's options (called from
    /// `NetworkingSystem.departed`, which every exit reaches): the unvested
    /// points go back to the founder, the vested ones stay on the cap
    /// table under their name — a poached holder takes them to the rival.
    static func ladderSettleOptions(
        _ employee: Employee,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard employee.grantedEquity > 0 else { return [] }
        let vested = employee.vestedEquity(day: state.day, balance: balance)
        let returned = max(0, employee.grantedEquity - vested)
        state.investors.equityRemaining = min(100, state.investors.equityRemaining + returned)
        if let grant = state.networking.grants.firstIndex(where: {
            $0.id == employee.id && $0.reason == .options
        }) {
            if vested > 0 {
                state.networking.grants[grant].percent = vested
            } else {
                state.networking.grants.remove(at: grant)
            }
        }
        return [.ladderOptionsSettled(
            employeeID: employee.id, name: employee.name,
            keptPercent: vested, returnedPercent: returned, day: state.day
        )]
    }
}
