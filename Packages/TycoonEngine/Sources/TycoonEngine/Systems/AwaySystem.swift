import Foundation
import TycoonContent

// MARK: T6 (away)

/// Iteration 17 — T6. People are away from the desk (`genre.md` §3), and
/// the launch reads the founder away (`systems.md` §4).
///
/// - *Send them on a course*: `.sendOnCourse` — the price now, ten days of
///   their output, the skill on the day they are back.
/// - *The holiday rule*: `holiday_request` in `StaffEvents.json`, rolled
///   only while `doors.armed` (the def requires `holiday_askable`, which
///   `run` raises only then). The generous rule sends every non-founder
///   away `away.holidayDays` from each hiring anniversary; the strict rule
///   costs the morale target and weights the burnout talk.
/// - *The launch without its founder*: `awayLaunchHypeFactor` on the ship
///   line and a logged `.launchWhileAway` the vice week and the launch-day
///   sheet read — doors armed only, because the pacing bots do ship from
///   hospital beds (measured: 53 of 2,399 launches on the ten seeds).
///
/// Identity: on every bot and fixture nobody is away, no rule is set and
/// doors are never armed — `run` walks the roster reading one optional
/// and returns, and nothing here draws a random number.
public enum AwaySystem {
    /// Raised while a person is at the controls; the holiday question
    /// requires it.
    static let holidayAskableFlag = "holiday_askable"
    /// The memory a home near the park writes, once per child.
    static let schoolMemoryKind = "school_corner"

    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        if state.doors.armed, !state.narrative.flags.contains(holidayAskableFlag) {
            state.narrative.flags.insert(holidayAskableFlag)
        }
        var events = bringBack(&state, balance)
        if state.holidayRule == .supportive {
            events += runHolidayRule(&state, balance)
        }
        return events
    }

    // MARK: - Back at the desk

    private static func bringBack(_ state: inout GameState, _ balance: BalanceConfig) -> [GameEvent] {
        var events: [GameEvent] = []
        for index in state.employees.indices {
            guard let until = state.employees[index].awayUntilDay, state.day >= until else { continue }
            let reason = state.employees[index].awayReason ?? .holiday
            state.employees[index].awayUntilDay = nil
            state.employees[index].awayReason = nil
            if case .course(let skill) = reason {
                let boost = balance.away.courseSkillBoost
                switch skill {
                case .coding:
                    state.employees[index].skills.coding = min(100, state.employees[index].skills.coding + boost)
                case .design:
                    state.employees[index].skills.design = min(100, state.employees[index].skills.design + boost)
                case .marketing:
                    state.employees[index].skills.marketing = min(100, state.employees[index].skills.marketing + boost)
                }
                state.employees[index].lastTrainedDay = state.day
                EmployeeSystem.recordRecognition(state.employees[index].id, &state)
            }
            events.append(.staffBack(employeeID: state.employees[index].id, reason: reason, day: state.day))
        }
        return events
    }

    // MARK: - The course

    static func sendOnCourse(
        employeeID: UUID,
        skill: TrainableSkill,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard state.courseBlocker(employeeID: employeeID, balance: balance) == nil,
              let index = state.employees.firstIndex(where: { $0.id == employeeID })
        else { return [] }
        let cost = state.courseCost(balance: balance)
        state.company.cash -= cost
        state.ledger.post(LedgerEntry(
            day: state.day,
            amount: -cost,
            category: .other,
            label: "Course: \(state.employees[index].name)"
        ))
        // Sent after today's work: away the next `courseDays` days, back
        // the day after.
        let until = state.day + max(1, balance.away.courseDays) + 1
        state.employees[index].awayUntilDay = until
        state.employees[index].awayReason = .course(skill)
        return [.staffAway(employeeID: employeeID, reason: .course(skill), untilDay: until, day: state.day)]
    }

    // MARK: - The holiday rule

    /// Ten days a year from each person's hiring anniversary (never in
    /// their first year), and the rule's loyalty once for everyone it
    /// answers for — the people it answered for are also who reversing it
    /// costs, which is how the policies card already prices a reversal.
    private static func runHolidayRule(_ state: inout GameState, _ balance: BalanceConfig) -> [GameEvent] {
        let config = balance.away
        let days = max(1, config.holidayDays)
        guard let slot = state.staffMemory.policies.firstIndex(where: { $0.kind == .holidayRequest }) else { return [] }
        var events: [GameEvent] = []
        for index in state.employees.indices where !state.employees[index].isFounder {
            let id = state.employees[index].id
            if !state.staffMemory.policies[slot].beneficiaries.contains(id) {
                state.staffMemory.policies[slot].beneficiaries.append(id)
                state.employees[index].loyalty = min(100, state.employees[index].loyalty + config.holidayLoyalty)
            }
            let tenure = state.day - state.employees[index].hiredDay
            guard tenure >= GameState.daysPerYear,
                  tenure % GameState.daysPerYear < days,
                  !state.employees[index].isAway(on: state.day)
            else { continue }
            // Starting after today's work, like the course.
            let until = state.day + days + 1
            state.employees[index].awayUntilDay = until
            state.employees[index].awayReason = .holiday
            events.append(.staffAway(employeeID: id, reason: .holiday, untilDay: until, day: state.day))
        }
        return events
    }

    // MARK: - The launch without its founder

    /// Logs `.launchWhileAway` for a ship the founder was away for (doors
    /// armed). Called from `ProductSystem.ship`'s T6 pair, before the stage
    /// flips.
    static func noteLaunch(productID: UUID, state: inout GameState, balance: BalanceConfig) {
        guard state.doors.armed, state.life.isAway(day: state.day) else { return }
        state.logEvents([.launchWhileAway(productID: productID, day: state.day)])
    }

    /// Launches this week the founder was away for: parties nobody threw.
    static func partiesMissed(_ state: GameState) -> Int {
        state.eventLog.count {
            if case .launchWhileAway(_, let day) = $0 { state.day - day < GameState.daysPerWeek } else { false }
        }
    }

    // MARK: - J6: the school near home

    /// A home in `away.schoolDistrict`: every school-age child gains
    /// `schoolBondPerWeek` a week and, once, the memory. Returns at its
    /// first line with no home district — every bot, every fixture.
    static func schoolNearHome(_ state: inout GameState, _ balance: BalanceConfig) {
        guard let home = state.life.homeDistrict,
              home.rawValue == balance.away.schoolDistrict,
              state.day % GameState.daysPerWeek == 0
        else { return }
        let config = balance.childhood
        for index in state.life.family.children.indices {
            let child = state.life.family.children[index]
            guard child.stage(on: state.day, balance: config) == .school else { continue }
            ChildhoodSystem.move(&state.life.family.children[index].bond, by: balance.away.schoolBondPerWeek)
            if !child.memories.contains(where: { $0.kind == schoolMemoryKind }) {
                state.life.family.children[index].memories.append(ChildMemory(
                    day: state.day, kind: schoolMemoryKind,
                    note: "\(child.name) walks to school past the park. Some mornings you walk with them."
                ))
                let memories = state.life.family.children[index].memories
                if memories.count > config.memoryCap {
                    state.life.family.children[index].memories.removeFirst(memories.count - config.memoryCap)
                }
            }
        }
    }
}

// MARK: - Reads

extension GameState {
    /// The rule the holiday question became, if any.
    public var holidayRule: StaffEventChoice? {
        staffMemory.policy(for: .holidayRequest)?.choice
    }

    /// What a course costs today, after the People & HR discount.
    public func courseCost(balance: BalanceConfig) -> Int {
        let cost = Double(balance.away.courseCost)
        guard hasDepartment(.hr) else { return Int(cost.rounded()) }
        return Int((cost * balance.company.hrTrainingCostFactor).rounded())
    }

    /// Why `employeeID` cannot be sent on a course today, or `nil`.
    public func courseBlocker(employeeID: UUID, balance: BalanceConfig) -> String? {
        guard let employee = employee(id: employeeID) else { return "Nobody by that name" }
        if employee.isFounder { return "Founders learn on the job" }
        if employee.isAway(on: day), let until = employee.awayUntilDay {
            return "Away until \(Self.awayDateLabel(until - 1))"
        }
        let cost = courseCost(balance: balance)
        if company.cash < cost { return "Need $\(cost - max(0, company.cash)) more" }
        return nil
    }

    /// Morale-target points for `employee` from being away and from the
    /// holiday rule. Exactly 0 for anyone at their desk on a run with no
    /// rule, which is every bot and every fixture.
    func awayMoraleTargetDelta(for employee: Employee, balance: BalanceConfig) -> Double {
        var delta = 0.0
        if employee.isAway(on: day) { delta += balance.away.awayMoraleTarget }
        switch holidayRule {
        case .supportive: delta += balance.away.holidayMoraleTarget
        case .strict, .strictAsPolicy: delta += balance.away.strictMoraleTarget
        case nil: break
        }
        return delta
    }

    /// `burnoutWarning`'s weight factor while the strict holiday rule
    /// stands, `nil` otherwise.
    func awayBurnoutWeightFactor(balance: BalanceConfig) -> Double? {
        guard let rule = holidayRule, rule != .supportive else { return nil }
        return balance.away.strictBurnoutWeight
    }

    /// The factor on launch hype today: `away.launchHypeFactor` while the
    /// founder is away with doors armed, exactly 1 at the desk and for
    /// every bot.
    public func awayLaunchHypeFactor(balance: BalanceConfig) -> Double {
        guard doors.armed, life.isAway(day: day) else { return 1 }
        return balance.away.launchHypeFactor
    }

    /// Whether `productID` shipped while the founder was away.
    public func launchedWhileAway(_ productID: UUID) -> Bool {
        eventLog.contains {
            if case .launchWhileAway(let id, _) = $0 { id == productID } else { false }
        }
    }

    /// The day the next planned weekend resolves (a vacation leaves then).
    public var nextWeekendResolveDay: Int {
        day + (Self.daysPerWeek - day % Self.daysPerWeek)
    }

    /// The clash an away row prints before the tap: the first build whose
    /// ship gate falls inside `start..<start + days`, named with its day of
    /// the absence and what the launch loses. `nil` when nothing is due or
    /// nobody is at the controls (the factor is 1 then).
    public func launchClash(
        awayFrom start: Int,
        days: Int,
        absence: String,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> String? {
        guard doors.armed, days > 0 else { return nil }
        let window = start..<(start + days)
        let hits = shipETAs(balance: balance, content: content).filter { window.contains($0.day) }
        guard let first = hits.first else { return nil }
        let factor = String(format: "%.2f", balance.away.launchHypeFactor)
            .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
        var line = "\(first.productName) ships on day \(first.day - start + 1) of \(absence) · hype ×\(factor), no party"
        if hits.count > 1 { line += " (and \(hits.count - 1) more)" }
        return line
    }

    /// "Sofia away until 14 Mar · Liam away until 16 Mar" for a build's
    /// crew, `nil` when everybody on it is at their desk.
    public func awayCrewLine(productID: UUID) -> String? {
        let away = employees
            .filter { $0.assignment == .product(productID) && $0.isAway(on: day) }
            .sorted { ($0.awayUntilDay ?? 0, $0.name) < ($1.awayUntilDay ?? 0, $1.name) }
        guard !away.isEmpty else { return nil }
        return away.map { person in
            let first = person.name.split(separator: " ").first.map(String.init) ?? person.name
            return "\(first) away until \(Self.awayDateLabel((person.awayUntilDay ?? day) - 1))"
        }.joined(separator: " · ")
    }

    /// What a course for `employeeID` does to the build they are on: the
    /// ship gate today and with them away `away.courseDays` (at today's
    /// crew rates, the boost not counted — so "no later than"). `nil` off a
    /// build in development, or when nothing is moving.
    public func courseShipPreview(
        employeeID: UUID,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> (productName: String, nowDay: Int, courseDay: Int)? {
        guard let person = employee(id: employeeID),
              case .product(let productID) = person.assignment,
              let product = product(id: productID),
              case .development(let dev) = product.stage,
              let type = content.productType(product.typeID),
              let now = buildETA(productID: productID, balance: balance, content: content),
              let nowDays = now.daysToShippable
        else { return nil }
        let courseDays = max(1, balance.away.courseDays)
        var preview = self
        if let index = preview.employees.firstIndex(where: { $0.id == employeeID }) {
            preview.employees[index].awayUntilDay = day + courseDays + 1
        }
        let without = preview.buildETA(productID: productID, balance: balance, content: content)?.codePerDay ?? 0
        let remaining = max(0, balance.shipCodeThreshold * type.codePts - dev.codePts)
        let away = Double(courseDays)
        let days: Int
        if without > 0, remaining <= without * away {
            days = Int((remaining / without).rounded(.up))
        } else if now.codePerDay > 0 {
            days = courseDays + Int(((remaining - without * away) / now.codePerDay).rounded(.up))
        } else {
            return nil
        }
        return (product.name, day + nowDays, day + max(nowDays, days))
    }

    /// "14 Mar".
    public static func awayDateLabel(_ day: Int) -> String {
        let calendar = GameCalendar(day: day)
        return "\(calendar.dayOfMonth) \(calendar.shortMonthName)"
    }

    /// The next scheduled holidays under the generous rule, soonest first:
    /// who, and the first and last day away.
    public func upcomingHolidays(balance: BalanceConfig, limit: Int = 3) -> [(name: String, from: Int, to: Int)] {
        guard holidayRule == .supportive else { return [] }
        let days = max(1, balance.away.holidayDays)
        let year = Self.daysPerYear
        return employees
            .filter { !$0.isFounder }
            .map { person -> (name: String, from: Int, to: Int) in
                if person.awayReason == .holiday, let until = person.awayUntilDay, person.isAway(on: day) {
                    return (person.name, day, until - 1)
                }
                var start = person.hiredDay + year
                while start < day { start += year }
                return (person.name, start + 1, start + days)
            }
            .sorted { ($0.from, $0.name) < ($1.from, $1.name) }
            .prefix(limit)
            .map { $0 }
    }
}

// MARK: - Debug seed

#if DEBUG
/// Dresses the running game for a T6 screenshot (`-autoRoute t6-…`).
/// - `course`: two of the first build's crew sent on courses.
/// - `question`: doors armed and the holiday question on the table.
/// - `rule`: the generous holiday rule set, somebody on holiday today.
/// - `strict`: the strict holiday rule set.
/// - `launch`: the founder on vacation today with doors armed.
/// - `home`: the founder living in Midtown.
enum AwayDebugSeed {
    static func apply(
        scenario: String,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        state.doors.armed = true
        state.narrative.flags.insert(AwaySystem.holidayAskableFlag)
        state.company.cash = max(state.company.cash, 50_000)
        let hired = state.employees.filter { !$0.isFounder }
        switch scenario {
        case "course":
            let build = state.productsInDevelopment.first?.id
            let crew = hired.filter { build != nil && $0.assignment == .product(build!) }
            var events: [GameEvent] = []
            for (offset, person) in crew.prefix(2).enumerated() {
                events += AwaySystem.sendOnCourse(
                    employeeID: person.id, skill: offset == 0 ? .coding : .design,
                    state: &state, balance: balance
                )
            }
            return events
        case "question":
            guard let person = hired.first else { return [] }
            state.pendingStaffEvent = StaffEvent(
                employeeID: person.id, kind: .holidayRequest,
                respondByDay: state.day + balance.social.staffEventResponseDays
            )
            return []
        case "rule", "strict":
            guard let person = hired.first else { return [] }
            let supportive = scenario == "rule"
            state.staffMemory.policies.removeAll { $0.kind == .holidayRequest }
            state.staffMemory.policies.append(StaffPolicy(
                kind: .holidayRequest,
                flag: supportive ? "holidays_scheduled" : "holidays_when_quiet",
                choice: supportive ? .supportive : .strict,
                setDay: state.day, setBy: person.id, setByName: person.name,
                beneficiaries: [person.id]
            ))
            state.narrative.flags.insert(supportive ? "holidays_scheduled" : "holidays_when_quiet")
            if supportive, let index = state.employees.firstIndex(where: { $0.id == person.id }) {
                state.employees[index].awayUntilDay = state.day + balance.away.holidayDays + 1
                state.employees[index].awayReason = .holiday
            }
            return []
        case "launch":
            state.life.awayUntilDay = state.day + balance.life.vacationDays
            state.life.awaySinceDay = state.day
            state.life.awayReason = "Vacation"
            return []
        case "home":
            state.life.homeDistrict = .midtown
            return []
        case "clash":
            // The soonest build's gate pulled back to two days into next
            // weekend's week away, so the vacation row has a clash to print.
            let target = state.nextWeekendResolveDay + 2
            guard let eta = state.shipETAs(balance: balance, content: content).first,
                  let index = state.products.firstIndex(where: { $0.id == eta.productID }),
                  case .development(var dev) = state.products[index].stage,
                  let type = content.productType(state.products[index].typeID),
                  let rate = state.buildETA(productID: eta.productID, balance: balance, content: content)?.codePerDay,
                  rate > 0
            else { return [] }
            let gate = balance.shipCodeThreshold * type.codePts
            dev.codePts = max(0, gate - rate * (Double(target - state.day) - 0.5))
            state.products[index].stage = .development(dev)
            return []
        default:
            return []
        }
    }
}
#endif

// MARK: end T6
