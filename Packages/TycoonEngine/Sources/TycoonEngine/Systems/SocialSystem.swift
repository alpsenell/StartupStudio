import Foundation
import TycoonContent

/// Daily social system, running right after `EmployeeSystem` so it sees
/// the post-sweep, post-quit roster: loyalty drifts with morale,
/// friendships form and fade with who works with whom, and every few
/// weeks a staff moment (birthday, family emergency, rival rumor) fires —
/// the answerable ones through the pending-decision pattern. Also hosts
/// the social action handlers used by `Reducer.apply`.
///
/// All randomness draws from `state.worldRNG`. Draw order per tick:
/// pending staff-event auto-resolve (no draws) → weekly bond formation
/// (one uniform per bond-less co-assigned pair, pairs in sorted id order)
/// → staff-event check on its interval (one uniform hit roll, then on a
/// hit one `nextInt` kind pick — the target pick is deterministic).
enum SocialSystem {
    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        let config = balance.social
        var events: [GameEvent] = []

        autoResolveStaffEvent(&state, balance, content, &events)
        driftLoyalty(&state, config)
        pruneFriendships(&state)

        if state.day % GameState.daysPerWeek == 0 {
            events.append(contentsOf: updateBonds(&state, config))
        }

        events.append(contentsOf: staffEventCheck(&state, balance, content))
        return events
    }

    // MARK: - Loyalty

    /// Loyalty follows morale: toward `50 + (morale − 70) / 2`.
    private static func driftLoyalty(_ state: inout GameState, _ config: BalanceConfig.SocialBalance) {
        for index in state.employees.indices where !state.employees[index].isFounder {
            let employee = state.employees[index]
            let target = min(100, max(0, 50 + (employee.morale - 70) / 2))
            state.employees[index].loyalty = min(100, max(0,
                employee.loyalty + (target - employee.loyalty) * config.loyaltyAdaptRate
            ))
        }
    }

    // MARK: - Friendships

    /// Drops bonds whose members left (quit, fired, poached) or faded out,
    /// and the refusals they remembered with them.
    private static func pruneFriendships(_ state: inout GameState) {
        let ids = Set(state.employees.map(\.id))
        state.friendships.removeAll { !ids.contains($0.a) || !ids.contains($0.b) || $0.strength <= 0 }
        if !state.staffMemory.refusals.isEmpty {
            state.staffMemory.refusals.removeAll { !ids.contains($0.employeeID) }
        }
    }

    /// Weekly: co-assigned pairs without a bond roll one uniform each
    /// against `bondChance` (pairs visited in sorted id order); existing
    /// bonds grow while the pair works together and decay apart — no
    /// draws.
    private static func updateBonds(
        _ state: inout GameState,
        _ config: BalanceConfig.SocialBalance
    ) -> [GameEvent] {
        var events: [GameEvent] = []
        let together = coAssignedPairs(state)

        // Grow / decay existing bonds first (index-stable, no draws).
        for index in state.friendships.indices {
            let key = pairKey(state.friendships[index].a, state.friendships[index].b)
            if together.contains(key) {
                state.friendships[index].strength = min(100,
                    state.friendships[index].strength + config.bondGrowthPerWeek)
            } else {
                state.friendships[index].strength = max(0,
                    state.friendships[index].strength - config.bondDecayPerWeek)
            }
        }

        // New bonds, deterministic visit order.
        let existing = Set(state.friendships.map { pairKey($0.a, $0.b) })
        for key in together.sorted() where !existing.contains(key) {
            let roll = state.worldRNG.nextUniform()
            guard roll < config.bondChance else { continue }
            let parts = key.split(separator: "|").map(String.init)
            guard parts.count == 2, let a = UUID(uuidString: parts[0]), let b = UUID(uuidString: parts[1])
            else { continue }
            state.friendships.append(Friendship(a: a, b: b, strength: 20, sinceDay: state.day))
            events.append(.friendshipFormed(a: a, b: b, day: state.day))
        }

        state.friendships.removeAll { $0.strength <= 0 }
        return events
    }

    /// Keys of non-founder pairs sharing a non-idle assignment target.
    private static func coAssignedPairs(_ state: GameState) -> Set<String> {
        var groups: [String: [UUID]] = [:]
        for employee in state.employees where !employee.isFounder {
            let target: String?
            switch employee.assignment {
            case .idle: target = nil
            case .research: target = "research"
            case .product(let id): target = "product-\(id.uuidString)"
            case .contract(let id): target = "contract-\(id.uuidString)"
            // Appended with `Assignment.support` (WS-A): people on the same
            // support desk work side by side like any other crew.
            case .support(let id): target = "support-\(id.uuidString)"
            // And again for the people rewriting the same codebase.
            case .refactor(let id): target = "refactor-\(id)"
            }
            if let target {
                groups[target, default: []].append(employee.id)
            }
        }
        var pairs: Set<String> = []
        for members in groups.values where members.count > 1 {
            let sorted = members.sorted { $0.uuidString < $1.uuidString }
            for i in 0..<(sorted.count - 1) {
                for j in (i + 1)..<sorted.count {
                    pairs.insert(pairKey(sorted[i], sorted[j]))
                }
            }
        }
        return pairs
    }

    private static func pairKey(_ a: UUID, _ b: UUID) -> String {
        a.uuidString <= b.uuidString
            ? "\(a.uuidString)|\(b.uuidString)"
            : "\(b.uuidString)|\(a.uuidString)"
    }

    /// The strongest bond `employeeID` shares with anyone in `coWorkers`
    /// (0 with none) — the output-bonus input for `EmployeeSystem`.
    static func strongestBond(for employeeID: UUID, among coWorkers: [UUID], in state: GameState) -> Double {
        let coWorkerSet = Set(coWorkers)
        return state.friendships
            .filter { friendship in
                guard let other = friendship.other(than: employeeID) else { return false }
                return coWorkerSet.contains(other)
            }
            .map(\.strength)
            .max() ?? 0
    }

    /// Dents every surviving friend's morale when an employee leaves
    /// involuntarily (fired or poached), then drops the bonds. Shared by
    /// `EmployeeSystem.fire` and the rival system's poach exit so both
    /// departures behave identically.
    static func friendDeparted(
        _ departedID: UUID,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        var events: [GameEvent] = []
        for friendship in state.friendships where friendship.involves(departedID) {
            guard let friendID = friendship.other(than: departedID),
                  let index = state.employees.firstIndex(where: { $0.id == friendID })
            else { continue }
            let penalty = balance.social.friendFiredMoralePenalty * friendship.strength / 100
            state.employees[index].morale = min(100, max(0, state.employees[index].morale - penalty))
            events.append(.friendLostMorale(employeeID: friendID, day: state.day))
        }
        state.friendships.removeAll { $0.involves(departedID) }
        return events
    }

    // MARK: - Staff events

    /// Every `staffEventIntervalDays` (nothing pending, at least one hired
    /// employee): one uniform against `staffEventChance`; on a hit the
    /// target rotates deterministically through the sorted non-founder
    /// ids, and one `nextInt` picks the kind — a birthday applies right
    /// away, the other kinds pause for an answer.
    ///
    /// With staff-event content loaded, an answerable moment draws one
    /// further word to pick a kind from the definitions this employee is
    /// eligible for (tenure, morale, loyalty, traits, friendships,
    /// departments). With no content — the unit-test catalogs — that draw
    /// never happens and the kind is the old `familyEmergency` /
    /// `rivalOfferRumor` coin flip.
    ///
    /// With a rule for the rolled kind (WS-D), the rule answers: the same
    /// outcome the sheet would have landed, a ledger line, and no pending
    /// event. The roll above is the beat either way, so a policy replaces
    /// a pause and never adds one.
    private static func staffEventCheck(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        let config = balance.social
        guard state.day % config.staffEventIntervalDays == 0,
              state.pendingStaffEvent == nil
        else { return [] }
        let hired = state.employees.filter { !$0.isFounder }.sorted { $0.id.uuidString < $1.id.uuidString }
        guard !hired.isEmpty else { return [] }

        let roll = state.worldRNG.nextUniform()
        guard roll < config.staffEventChance else { return [] }

        let target = hired[(state.day / config.staffEventIntervalDays) % hired.count]
        let kindRoll = state.worldRNG.nextInt(in: 0...2)
        if kindRoll == 0 {
            // Birthday: cake on the company, everyone's happy, no pause.
            if let index = state.employees.firstIndex(where: { $0.id == target.id }) {
                state.employees[index].morale = min(100,
                    state.employees[index].morale + config.birthdayMoraleBoost)
            }
            state.company.cash -= config.birthdayCakeCost
            state.ledger.post(LedgerEntry(
                day: state.day,
                amount: -config.birthdayCakeCost,
                category: .other,
                label: "Birthday cake: \(target.name)"
            ))
            return [.staffBirthday(employeeID: target.id, day: state.day)]
        }

        let fallback: StaffEventKind = kindRoll == 1 ? .familyEmergency : .rivalOfferRumor
        let kind = pickKind(
            for: target, fallback: fallback, state: &state, config: config, content: content
        )
        if let policy = state.staffMemory.policy(for: kind),
           let def = content.staffEvent(kind.rawValue) {
            return applyPolicy(policy, def: def, to: target.id, state: &state, balance: balance)
        }
        let event = StaffEvent(
            employeeID: target.id,
            kind: kind,
            respondByDay: state.day + config.staffEventResponseDays
        )
        state.pendingStaffEvent = event
        return [.staffEventOccurred(
            employeeID: target.id, kind: kind, respondByDay: event.respondByDay, day: state.day
        )]
    }

    /// The kinds this employee could plausibly bring the founder today,
    /// weighted. One `nextInt` word, and only when the catalog has staff
    /// events at all.
    private static func pickKind(
        for target: Employee,
        fallback: StaffEventKind,
        state: inout GameState,
        config: BalanceConfig.SocialBalance,
        content: ContentCatalog
    ) -> StaffEventKind {
        let eligible = content.staffEvents.filter { def in
            StaffEventKind(rawValue: def.id) != nil
                && isEligible(def, for: target, state: state)
        }
        guard !eligible.isEmpty else { return fallback }

        let total = eligible.reduce(0) { $0 + max(1, $1.weight) }
        var remaining = state.worldRNG.nextInt(in: 0...(total - 1))
        for def in eligible {
            remaining -= max(1, def.weight)
            if remaining < 0 { return StaffEventKind(rawValue: def.id) ?? fallback }
        }
        return StaffEventKind(rawValue: eligible[eligible.count - 1].id) ?? fallback
    }

    /// Evaluates a staff-event gate against one employee and the company
    /// around them. Pure — no draws.
    private static func isEligible(
        _ def: StaffEventDef,
        for employee: Employee,
        state: GameState
    ) -> Bool {
        guard let gate = def.requires else { return true }
        if !gate.anyTrait.isEmpty, !gate.anyTrait.contains(where: employee.traits.contains) {
            return false
        }
        if gate.noTrait.contains(where: employee.traits.contains) { return false }
        if let days = gate.minTenureDays, state.day - employee.hiredDay < days { return false }
        if let value = gate.minMorale, employee.morale < value { return false }
        if let value = gate.maxMorale, employee.morale > value { return false }
        if let value = gate.minLoyalty, employee.loyalty < value { return false }
        if let value = gate.maxLoyalty, employee.loyalty > value { return false }
        if let needsFriend = gate.requiresFriend,
           state.friendships.contains(where: { $0.involves(employee.id) }) != needsFriend {
            return false
        }
        if let raw = gate.requiresDepartment {
            guard let department = Department(rawValue: raw),
                  state.hasDepartment(department) else { return false }
        }
        if let value = gate.minHeadcount, state.headcount < value { return false }
        if let raw = gate.minTier {
            guard let tier = OfficeTier(rawValue: raw),
                  state.company.officeTier.rank >= tier.rank else { return false }
        }
        return true
    }

    /// A pending staff event past its deadline resolves as `strict` (the
    /// founder never got back to them). No draws — and no rule: a rule is
    /// something the founder says, which is what keeps every pacing run
    /// on the pre-policy numbers.
    private static func autoResolveStaffEvent(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog,
        _ events: inout [GameEvent]
    ) {
        guard let pending = state.pendingStaffEvent, state.day > pending.respondByDay else { return }
        state.pendingStaffEvent = nil
        events.append(contentsOf: applyStaffChoice(
            .strict, to: pending, automatic: true, state: &state, balance: balance, content: content
        ))
    }

    /// Applies one answer. The numbers come from the moment's
    /// `StaffEventDef` when the catalog has one, and from the generic
    /// `balance.social` costs when it doesn't.
    ///
    /// A supportive answer to a policy-shaped kind (WS-D) also sets the
    /// rule — only when the founder gave it (`automatic == false`), and
    /// only for a rolled kind, never a second act. Any strict answer is
    /// remembered by the person who got it.
    private static func applyStaffChoice(
        _ choice: StaffEventChoice,
        to event: StaffEvent,
        automatic: Bool,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard let index = state.employees.firstIndex(where: { $0.id == event.employeeID }) else {
            return []
        }
        let resolved: GameEvent = .staffEventResolved(
            employeeID: event.employeeID, choice: choice, day: state.day
        )
        guard let def = content.staffEvent(event.definitionID) else {
            applyGenericStaffChoice(
                choice, kind: event.kind, index: index, state: &state, config: balance.social
            )
            return [resolved]
        }

        let employee = state.employees[index]
        var events: [GameEvent] = [resolved]
        if choice != .supportive {
            state.staffMemory.remember(StaffRefusal(
                employeeID: employee.id, kind: event.kind, day: state.day, automatic: automatic
            ))
        }
        if !automatic, event.defID == nil, let flags = def.policy,
           choice == .supportive,
           state.staffMemory.policy(for: event.kind) == nil {
            let policy = StaffPolicy(
                kind: event.kind,
                flag: flags.supportiveFlag,
                choice: .supportive,
                setDay: state.day,
                setBy: employee.id,
                setByName: employee.name,
                beneficiaries: [employee.id]
            )
            state.staffMemory.policies.append(policy)
            state.narrative.flags.remove(flags.strictFlag)
            state.narrative.flags.insert(policy.flag)
            events.append(.staffPolicySet(flag: policy.flag, employeeID: employee.id, day: state.day))
        }

        let outcome = choice == .supportive ? (def.supportive ?? def.strict) : def.strict
        events.append(contentsOf: applyOutcome(
            outcome,
            to: employee.id,
            ledgerLabel: def.headline.replacingOccurrences(of: "{name}", with: employee.name),
            state: &state,
            balance: balance
        ))
        return events
    }

    /// The rule answering for somebody (WS-D): the outcome the sheet would
    /// have landed, a ledger line that says so, and the person added to
    /// the people the rule has answered for.
    private static func applyPolicy(
        _ policy: StaffPolicy,
        def: StaffEventDef,
        to employeeID: UUID,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard let index = state.employees.firstIndex(where: { $0.id == employeeID }) else { return [] }
        let employee = state.employees[index]
        var events: [GameEvent] = [
            .staffPolicyApplied(flag: policy.flag, employeeID: employee.id, day: state.day)
        ]
        if let slot = state.staffMemory.policies.firstIndex(where: { $0.flag == policy.flag }),
           !state.staffMemory.policies[slot].beneficiaries.contains(employee.id) {
            state.staffMemory.policies[slot].beneficiaries.append(employee.id)
        }
        if policy.choice != .supportive {
            state.staffMemory.remember(StaffRefusal(
                employeeID: employee.id, kind: policy.kind, day: state.day, automatic: false
            ))
        }
        let outcome = policy.choice == .supportive ? (def.supportive ?? def.strict) : def.strict
        let name = def.policy?.name ?? def.headline.replacingOccurrences(of: "{name}", with: employee.name)
        events.append(contentsOf: applyOutcome(
            outcome,
            to: employee.id,
            ledgerLabel: "\(name): \(employee.name) · the policy",
            state: &state,
            balance: balance
        ))
        return events
    }

    /// Lands one outcome's numbers on one person and the company around
    /// them. Shared by the sheet's answer and the rule's, so the two can
    /// never drift.
    private static func applyOutcome(
        _ outcome: StaffEventDef.Outcome,
        to employeeID: UUID,
        ledgerLabel: String,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard let index = state.employees.firstIndex(where: { $0.id == employeeID }) else { return [] }
        if outcome.cash != 0 {
            state.company.cash += outcome.cash
            state.ledger.post(LedgerEntry(
                day: state.day,
                amount: outcome.cash,
                category: .other,
                label: ledgerLabel
            ))
        }
        state.employees[index].morale = clamp(state.employees[index].morale + outcome.morale)
        state.employees[index].loyalty = clamp(state.employees[index].loyalty + outcome.loyalty)
        if outcome.salaryPercent != 0 {
            let salary = Double(state.employees[index].weeklySalary)
            state.employees[index].weeklySalary = max(
                0, Int((salary * (1 + outcome.salaryPercent / 100)).rounded())
            )
        }
        if outcome.skill != 0 {
            state.employees[index].skills.coding = clamp(state.employees[index].skills.coding + outcome.skill)
            state.employees[index].skills.design = clamp(state.employees[index].skills.design + outcome.skill)
            state.employees[index].skills.marketing = clamp(
                state.employees[index].skills.marketing + outcome.skill
            )
        }
        if outcome.clearsAssignment {
            state.employees[index].assignment = .idle
        }
        if outcome.moraleAll != 0 {
            for other in state.employees.indices
            where !state.employees[other].isFounder && other != index {
                state.employees[other].morale = clamp(
                    state.employees[other].morale + outcome.moraleAll
                )
            }
        }
        if outcome.reputation != 0 {
            state.company.reputation = clamp(state.company.reputation + outcome.reputation)
        }
        if let flag = outcome.setFlag {
            state.narrative.flags.insert(flag)
        }
        return []
    }

    /// The pre-content behavior, kept for kinds with no definition.
    private static func applyGenericStaffChoice(
        _ choice: StaffEventChoice,
        kind: StaffEventKind,
        index: Int,
        state: inout GameState,
        config: BalanceConfig.SocialBalance
    ) {
        switch choice {
        case .supportive:
            state.company.cash -= config.supportCost
            state.ledger.post(LedgerEntry(
                day: state.day,
                amount: -config.supportCost,
                category: .other,
                label: "Supporting \(state.employees[index].name)"
            ))
            state.employees[index].morale = min(100,
                state.employees[index].morale + config.supportMorale)
            state.employees[index].loyalty = min(100,
                state.employees[index].loyalty + config.supportLoyalty)
            if kind == .familyEmergency {
                state.employees[index].assignment = .idle
            }
        case .strict:
            state.employees[index].loyalty = max(0,
                state.employees[index].loyalty - config.strictLoyaltyPenalty)
        }
    }

    private static func clamp(_ value: Double) -> Double { min(100, max(0, value)) }

    // MARK: - Actions

    /// Coffee with one employee: small morale and loyalty, company pays,
    /// per-employee social cooldown.
    static func grabCoffee(employeeID: UUID, state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        socialAction(
            employeeID: employeeID, state: &state, balance: balance,
            cost: balance.social.coffeeCost,
            morale: balance.social.coffeeMorale,
            loyalty: balance.social.coffeeLoyalty,
            kind: .coffee,
            label: "Coffee with"
        )
    }

    /// A one-on-one: free, the biggest loyalty lift, and it clears the
    /// employee's low-morale streak (they felt heard).
    static func oneOnOne(employeeID: UUID, state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        let events = socialAction(
            employeeID: employeeID, state: &state, balance: balance,
            cost: 0,
            morale: 0,
            loyalty: balance.social.oneOnOneLoyalty,
            kind: .oneOnOne,
            label: nil
        )
        if !events.isEmpty, let index = state.employees.firstIndex(where: { $0.id == employeeID }) {
            state.employees[index].lowMoraleStreakDays = 0
        }
        return events
    }

    /// A gift: pricier, big morale and loyalty.
    static func giveGift(employeeID: UUID, state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        socialAction(
            employeeID: employeeID, state: &state, balance: balance,
            cost: balance.social.giftCost,
            morale: balance.social.giftMorale,
            loyalty: balance.social.giftLoyalty,
            kind: .gift,
            label: "Gift for"
        )
    }

    /// Dinner for the whole team: per-head cost, morale and loyalty for
    /// every hired employee, global cooldown.
    static func teamDinner(state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        let config = balance.social
        let hired = state.employees.filter { !$0.isFounder }
        let cost = config.dinnerCostPerHead * state.headcount
        guard !hired.isEmpty, state.company.cash >= cost else { return [] }
        if let last = state.lastTeamDinnerDay,
           state.day - last < config.teamDinnerCooldownDays { return [] }

        state.company.cash -= cost
        state.ledger.post(LedgerEntry(
            day: state.day, amount: -cost, category: .other, label: "Team dinner"
        ))
        let charm = state.founderCharmFactor(balance)
        for index in state.employees.indices where !state.employees[index].isFounder {
            state.employees[index].morale = min(100,
                state.employees[index].morale + config.dinnerMorale)
            state.employees[index].loyalty = min(100,
                state.employees[index].loyalty + config.dinnerLoyalty)
            state.employees[index].founderBond = min(100,
                state.employees[index].founderBond
                    + balance.relationships.bondPerSocialAction / 2 * charm)
        }
        state.lastTeamDinnerDay = state.day
        return [.socialActivity(kind: .teamDinner, employeeID: nil, day: state.day)]
    }

    /// Shared one-on-one social plumbing: gates (hired target, cash,
    /// cooldown), effects, ledger, event.
    private static func socialAction(
        employeeID: UUID,
        state: inout GameState,
        balance: BalanceConfig,
        cost: Int,
        morale: Double,
        loyalty: Double,
        kind: SocialActivityKind,
        label: String?
    ) -> [GameEvent] {
        let config = balance.social
        guard let index = state.employees.firstIndex(where: { $0.id == employeeID }),
              !state.employees[index].isFounder,
              cost == 0 || state.company.cash >= cost
        else { return [] }
        if let last = state.employees[index].lastSocialDay,
           state.day - last < config.socialCooldownDays { return [] }

        if cost > 0 {
            state.company.cash -= cost
            state.ledger.post(LedgerEntry(
                day: state.day,
                amount: -cost,
                category: .other,
                label: "\(label ?? "Social:") \(state.employees[index].name)"
            ))
        }
        state.employees[index].morale = min(100, max(0, state.employees[index].morale + morale))
        state.employees[index].loyalty = min(100, max(0, state.employees[index].loyalty + loyalty))
        // Every one of these is the founder's own time, so every one of
        // them is worth a little of the founder's own bond with them — and
        // a founder who is good at talking to people gets more out of the
        // same coffee.
        state.employees[index].founderBond = min(100,
            state.employees[index].founderBond
                + balance.relationships.bondPerSocialAction * state.founderCharmFactor(balance))
        state.employees[index].lastSocialDay = state.day
        return [.socialActivity(kind: kind, employeeID: employeeID, day: state.day)]
    }

    /// Answers the pending staff event. Ignored with nothing pending.
    static func resolveStaffEvent(
        choice: StaffEventChoice,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard let pending = state.pendingStaffEvent else { return [] }
        state.pendingStaffEvent = nil
        return applyStaffChoice(
            choice, to: pending, automatic: false, state: &state, balance: balance, content: content
        )
    }
}
