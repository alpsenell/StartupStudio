import Foundation
import TycoonContent

/// The incident room (iteration 10, M3).
///
/// Two halves:
///
/// 1. **Raising.** `raiseIfNeeded` is called from `LiveOpsSystem`'s M3
///    region at the end of the live-ops day, when the facts it reads —
///    a patch that just landed, a week that sold far more than the last
///    one, a product big enough to be worth attacking — are freshest.
///    It raises at most one incident, for at most one product, at most
///    once a quarter, and *only* once `state.economy.incidents
///    .hasOpenedProducts` is true. The app sets that flag when the player
///    opens the Products tab; nothing else does, so a pacing bot, a
///    fixture replay and every headless run never reach a line below the
///    gate — including the one draw from `socialRNG`.
///
/// 2. **The room.** Four actions (`assignToIncident`,
///    `chooseIncidentStatement`, `advanceIncident`, `resolveIncident`), no
///    wall clock, no RNG: the room's own hour hand is an action, so the
///    whole thing replays from the action log. `resolveIncident` is where
///    it lands on the world — churn off the release, reputation off the
///    statement, bugs left by an unfinished repair, the front page, the
///    journal and the phone.
public enum IncidentSystem {

    // MARK: - Raising

    /// Considers raising an incident for today's live-ops facts. Returns
    /// the event if one was raised.
    ///
    /// Called from `LiveOpsSystem.run`'s M3 region, after the patches have
    /// landed and the week's discovery has run.
    static func raiseIfNeeded(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        // The gate. Everything below this line — the reads, the roll, the
        // room — belongs to a run the player is actually playing.
        guard balance.incidents.enabled,
              state.economy.incidents.hasOpenedProducts,
              state.incident == nil,
              state.gameOver == nil
        else { return [] }

        let config = balance.incidents

        // Deterministic causes first, in `state.products` order, so the one
        // draw below happens in the same place every replay.
        for product in state.products {
            guard case .released(let info) = product.stage, !info.offMarket else { continue }
            guard cooledDown(product.id, state: state, balance: balance) else { continue }
            if isBadPatch(info, state: state, balance: balance) {
                return [raise(.badPatch, on: product, info: info, state: &state, balance: balance)]
            }
            if isViralSpike(info, product: product, state: state, balance: balance, content: content) {
                return [raise(.viralSpike, on: product, info: info, state: &state, balance: balance)]
            }
        }

        // And the one that is a roll, once a week, on the biggest product
        // worth attacking. Lawyers are what makes it rare.
        guard state.day % GameState.daysPerWeek == 0 else { return [] }
        let candidates = state.products.filter { product in
            guard case .released(let info) = product.stage, !info.offMarket else { return false }
            guard cooledDown(product.id, state: state, balance: balance) else { return false }
            return reach(of: info) >= config.minimumReach
        }
        guard let target = candidates.max(by: { left, right in
            reachOf(left) < reachOf(right)
        }) else { return [] }

        let chance = config.leakWeeklyChance
            * (state.knownDepartments.contains(.legal) ? config.leakLegalFactor : 1)
        guard state.socialRNG.nextUniform() < chance else { return [] }
        guard case .released(let info) = target.stage else { return [] }
        return [raise(.dataLeak, on: target, info: info, state: &state, balance: balance)]
    }

    private static func reachOf(_ product: Product) -> Int {
        guard case .released(let info) = product.stage else { return 0 }
        return reach(of: info)
    }

    /// How many people this release has to lose: subscribers for a
    /// subscription, last week's units for a one-off.
    public static func reach(of info: ReleaseInfo) -> Int {
        info.isSubscription ? info.subscribers : (info.weeklySales.last?.units ?? 0)
    }

    private static func cooledDown(
        _ productID: UUID, state: GameState, balance: BalanceConfig
    ) -> Bool {
        guard let last = state.economy.incidents.lastIncidentDay[productID] else { return true }
        return state.day - last >= balance.incidents.cooldownDays
    }

    /// A patch landed in the last few days and the wild is on fire.
    private static func isBadPatch(
        _ info: ReleaseInfo, state: GameState, balance: BalanceConfig
    ) -> Bool {
        guard let landed = info.lastUpdateDay,
              state.day - landed <= balance.incidents.badPatchWindowDays,
              state.day >= landed
        else { return false }
        let threshold = balance.economy.liveBugAlarmThreshold
        guard threshold > 0 else { return false }
        return Double(info.liveBugs) >= Double(threshold) * balance.incidents.badPatchBugFactor
    }

    /// The week sold far more than the last one, and the hosting bill is
    /// eating the week it sold.
    private static func isViralSpike(
        _ info: ReleaseInfo,
        product: Product,
        state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> Bool {
        let config = balance.incidents
        let weeks = info.weeklySales
        guard weeks.count >= 2, let week = weeks.last else { return false }
        let previous = weeks[weeks.count - 2]
        guard week.units >= config.minimumReach,
              previous.units > 0,
              Double(week.units) >= Double(previous.units) * config.spikeGrowthFactor,
              week.revenue > 0,
              let type = content.productType(product.typeID)
        else { return false }
        let hosting = ProductSystem.weeklyHostingCost(for: info, type: type, balance: balance)
        return Double(hosting) >= Double(week.revenue) * config.spikeHostingShare
    }

    /// Opens the room: the state, the ledger's cooldown stamp, the phone,
    /// and the critical event that stops the clock.
    private static func raise(
        _ kind: IncidentKind,
        on product: Product,
        info: ReleaseInfo,
        state: inout GameState,
        balance: BalanceConfig
    ) -> GameEvent {
        state.incident = IncidentState(
            productID: product.id,
            kind: kind,
            startedDay: state.day,
            reach: max(reach(of: info), balance.incidents.minimumReach)
        )
        state.economy.incidents.lastIncidentDay[product.id] = state.day
        postRaised(kind: kind, productName: product.name, state: &state)
        return .incidentRaised(productID: product.id, kind: kind.rawValue, day: state.day)
    }

    // MARK: - The room's actions

    /// Puts somebody on a lane, or takes them off it (`thread: nil`).
    /// Refused for anyone who is not on the payroll, for a founder who is
    /// away, and once the statement has been made and the fix is in.
    static func assign(
        employeeID: UUID,
        thread: IncidentThread?,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard var incident = state.incident else { return [] }
        guard let employee = state.employees.first(where: { $0.id == employeeID }) else { return [] }
        if employee.isFounder, state.life.isAway(day: state.day) { return [] }
        if let thread {
            incident.assignments[employeeID] = thread
        } else {
            incident.assignments.removeValue(forKey: employeeID)
        }
        state.incident = incident
        return []
    }

    /// Why an assignment would be refused, in the player's words. `nil`
    /// when it would be accepted.
    public static func assignBlocker(
        employeeID: UUID, state: GameState
    ) -> String? {
        guard state.incident != nil else { return "No incident is open" }
        guard let employee = state.employees.first(where: { $0.id == employeeID })
        else { return "Not on the payroll" }
        if employee.isFounder, state.life.isAway(day: state.day) { return "You are away" }
        return nil
    }

    /// Picks the public statement. Changeable until the room is closed —
    /// it only lands at `resolve`.
    static func chooseStatement(
        id: String,
        state: inout GameState,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard var incident = state.incident,
              let product = state.product(id: incident.productID),
              IncidentStatements.statement(
                  id, for: incident.kind, productName: product.name
              ) != nil
        else { return [] }
        incident.statementID = id
        state.incident = incident
        return []
    }

    /// One hour of the room: everyone assigned works their lane, and the
    /// people who could not wait leave.
    static func advance(
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard var incident = state.incident, incident.hasHoursLeft(balance) else { return [] }

        for thread in IncidentThread.allCases {
            let crew = incident.crew(on: thread)
            guard !crew.isEmpty else { continue }
            var points = 0.0
            for employeeID in crew.sorted(by: { $0.uuidString < $1.uuidString }) {
                guard let employee = state.employees.first(where: { $0.id == employeeID })
                else { continue }
                points += contribution(of: employee, on: thread, state: state, balance: balance)
            }
            incident.advance(thread, by: points)
        }

        incident.usersLost += leaving(incident, balance: balance)
        incident.hoursSpent += 1
        state.incident = incident
        return []
    }

    /// Users walking out in one hour of the room as it stands.
    public static func leaving(_ incident: IncidentState, balance: BalanceConfig) -> Int {
        let config = balance.incidents
        let relief = min(
            config.reliefCap,
            incident.mitigate / 100 * config.mitigateRelief
                + incident.communicate / 100 * config.communicateRelief
        )
        let bleed = Double(incident.reach) * incident.kind.bleedShare * (1 - relief)
        let remaining = max(0, incident.reach - incident.usersLost)
        return max(0, min(remaining, Int(bleed.rounded())))
    }

    /// What one person lands on one lane in one hour. No RNG: the room is
    /// about who you put where, not about luck.
    public static func contribution(
        of employee: Employee,
        on thread: IncidentThread,
        state: GameState,
        balance: BalanceConfig
    ) -> Double {
        let config = balance.incidents
        let skills = employee.skills
        let skill: Double = switch thread {
        case .mitigate: (skills.coding + skills.design) / 2
        case .communicate: skills.marketing
        case .fix: skills.coding
        }
        var factor = config.skillFloor + config.skillSpan * min(1, max(0, skill / 100))
        if suits(employee.role, thread) { factor += config.roleBonus }
        if employee.isFounder {
            factor *= config.founderFactor
            factor *= state.founderOutputMultiplier(balance: balance)
        } else {
            factor *= employee.performanceMultiplier(balance: balance)
        }
        return config.pointsPerPersonHour * factor
    }

    /// Whether a role is the obvious one for a lane. Everybody can work
    /// every lane; the right person is simply faster.
    public static func suits(_ role: EmployeeRole, _ thread: IncidentThread) -> Bool {
        switch thread {
        case .mitigate: role == .backend || role == .ops
        case .communicate: role == .marketer || role == .hr || role == .lawyer
        case .fix: role == .backend || role == .frontend || role == .qa
        }
    }

    /// Why the room cannot be closed yet, in the player's words. `nil`
    /// when `.resolveIncident` would be accepted.
    public static func resolveBlocker(state: GameState) -> String? {
        guard state.incident != nil else { return "No incident is open" }
        guard state.incident?.statementID != nil else { return "Say something first" }
        return nil
    }

    /// Closes the room and lands it on the world.
    static func resolve(
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard let incident = state.incident, let statementID = incident.statementID,
              let index = state.products.firstIndex(where: { $0.id == incident.productID }),
              case .released(var info) = state.products[index].stage
        else { return [] }
        let product = state.products[index]
        guard let statement = IncidentStatements.statement(
            statementID, for: incident.kind, productName: product.name
        ) else { return [] }
        let config = balance.incidents

        // 1. The audience. What the statement says decides how many of the
        //    people who were walking out actually go.
        let lost = max(0, Int((Double(incident.usersLost) * statement.churnFactor).rounded()))
        if info.isSubscription {
            info.subscribers = max(0, info.subscribers - lost)
        } else {
            info.liveHype = max(0, info.liveHype - Double(lost) * config.hypePerUserLost)
        }

        // 2. The bugs. A finished repair halves what was in the wild; an
        //    unfinished one leaves the rest of the kind's load behind.
        let unfixed = max(0, 1 - incident.fix / 100)
        if unfixed <= 0 {
            info.liveBugs /= 2
        } else {
            info.liveBugs += Int((incident.kind.bugLoad * unfixed).rounded())
        }
        let bugsLeft = info.liveBugs
        state.products[index].stage = .released(info)

        // 3. The reputation. The severity hit is what mitigation was for;
        //    the statement is only worth what communication made it worth.
        let credibility = config.credibilityFloor
            + (1 - config.credibilityFloor) * incident.communicate / 100
        var delta = -incident.kind.reputationHit * max(0, 1 - incident.mitigate / 100)
        delta += statement.reputationDelta * credibility
        if statement.promisesFix, incident.fix < 100 {
            delta -= config.brokenPromisePenalty
        }
        state.company.reputation = min(100, max(0, state.company.reputation + delta))

        let outcome = IncidentOutcome(
            kind: incident.kind,
            usersLost: lost,
            reputationDelta: delta,
            bugsLeft: bugsLeft,
            statementID: statementID,
            status: incident.status
        )

        state.incident = nil
        postResolved(
            outcome: outcome, statement: statement, productName: product.name, state: &state
        )
        return [
            .incidentResolved(
                productID: product.id,
                kind: incident.kind.rawValue,
                usersLost: lost,
                reputationDelta: delta,
                day: state.day
            )
        ]
    }

    // MARK: - The phone

    /// The office hears first; the partner hears at the door.
    ///
    /// The office thread only opens once somebody other than the founder is
    /// on the payroll (L1's rule — a solo garage has no office chat), and
    /// the partner only exists once there is one.
    private static func postRaised(
        kind: IncidentKind, productName: String, state: inout GameState
    ) {
        guard state.employees.contains(where: { !$0.isFounder }) else { return }
        state.life.phone.post(
            "\(productName) is down — \(kind.displayName.lowercased()). Everyone in the room.",
            from: .office, day: state.day
        )
    }

    private static func postResolved(
        outcome: IncidentOutcome,
        statement: IncidentStatement,
        productName: String,
        state: inout GameState
    ) {
        if state.employees.contains(where: { !$0.isFounder }) {
            let users = outcome.usersLost == 1 ? "1 user" : "\(outcome.usersLost) users"
            state.life.phone.post(
                outcome.status == .green
                    ? "\(productName) is green again. \(users) gone, and that is the worst of it."
                    : "\(productName) is stable, not fixed. \(users) gone and \(outcome.bugsLeft) bugs still out there.",
                from: .office, day: state.day
            )
        }
        if state.life.family.partnerName != nil {
            state.life.phone.post(
                outcome.reputationDelta >= 0
                    ? "I saw the statement. You said the right thing."
                    : "Saw the news about \(productName). Come home when you can.",
                from: .partner, day: state.day
            )
        }
    }
}
