import Foundation
import TycoonContent

/// Weekly rival system, running after `MarketSystem` and before
/// `EmployeeSystem`: keeps the field of competitor studios populated,
/// evolves each rival's strength, lets rivals ship (denting that topic's
/// demand multiplier) or stumble, and — on their cadences — makes poach
/// and buyout offers the player answers through `Reducer.apply`. Offers
/// left past their deadline auto-resolve here. Also hosts the offer and
/// acquisition action handlers.
///
/// All randomness draws from `state.worldRNG`, never `state.rng`, so the
/// original systems' documented draw order stays byte-identical. World
/// draw order per tick: pending-poach auto-resolve (one uniform when due)
/// → founding (per new rival: two id words, name pick, strength,
/// reputation, topic pick, appearance seed) → weekly evolution (per
/// rival: one gaussian, one uniform event roll, one topic pick when it
/// ships) → fold replacements (founding draws each) → poach check (one
/// uniform, plus one premium uniform on a hit) → buyout check (one
/// uniform, plus one fraction uniform on a hit).
enum RivalSystem {
    /// Strength a rival gains by successfully hiring away an employee.
    private static let poachedStrengthGain: Double = 5

    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        let config = balance.rivals
        var events: [GameEvent] = []

        events.append(contentsOf: resolveExpiredPoach(&state, balance))
        resolveExpiredBuyout(&state, &events)

        while state.rivals.rivals.count < config.rivalCount {
            let rival = found(&state, config, content)
            state.rivals.rivals.append(rival)
            events.append(.rivalFounded(rivalID: rival.id, name: rival.name, day: state.day))
        }

        if state.day % config.evolveIntervalDays == 0 {
            events.append(contentsOf: evolve(&state, balance, content))
        }

        events.append(contentsOf: poachCheck(&state, balance, content))
        events.append(contentsOf: buyoutCheck(&state, balance))
        return events
    }

    // MARK: - Founding

    /// Rolls one new rival. Draws, in order: two id words, the name pick,
    /// the strength roll, the reputation roll, the focus-topic pick (only
    /// when the catalog has topics at all), and the appearance seed.
    private static func found(
        _ state: inout GameState,
        _ config: BalanceConfig.RivalBalance,
        _ content: ContentCatalog
    ) -> Rival {
        let id = UUID(from: &state.worldRNG)
        let name = pick(content.names.clientCompanies, &state.worldRNG) ?? "Nimbus Labs"
        let strength = config.foundingStrengthMin
            + state.worldRNG.nextUniform() * (config.foundingStrengthMax - config.foundingStrengthMin)
        let reputation = config.foundingReputationMin
            + state.worldRNG.nextUniform() * (config.foundingReputationMax - config.foundingReputationMin)
        let topics = content.topics.map(\.id)
        let focus: [String] = if let topic = pick(topics, &state.worldRNG) {
            [topic]
        } else {
            []
        }
        return Rival(
            id: id,
            name: name,
            strength: strength,
            reputation: reputation,
            focusTopicIDs: focus,
            foundedDay: state.day,
            appearanceSeed: state.worldRNG.next()
        )
    }

    // MARK: - Weekly evolution

    /// Per rival in array order: one gaussian strength step, then one
    /// uniform event roll — below `shipChance` the rival ships (denting
    /// its topic's demand multiplier), below `shipChance + stumbleChance`
    /// it stumbles. Rivals that end below `foldThreshold` fold afterwards
    /// and are replaced with fresh foundings.
    private static func evolve(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        let config = balance.rivals
        var events: [GameEvent] = []

        for index in state.rivals.rivals.indices {
            let drift = state.worldRNG.nextGaussian(sigma: config.strengthDriftSigma)
            state.rivals.rivals[index].strength = clamp(
                state.rivals.rivals[index].strength + drift, min: 1, max: 100
            )

            let roll = state.worldRNG.nextUniform()
            if roll < config.shipChance {
                let rival = state.rivals.rivals[index]
                if let topicID = pick(rival.focusTopicIDs, &state.worldRNG) {
                    dentMarket(topicID: topicID, by: config.competitionDent, &state, balance)
                    state.rivals.rivals[index].lastShippedDay = state.day
                    state.rivals.rivals[index].reputation = clamp(
                        rival.reputation + config.shipReputationGain, min: 0, max: 100
                    )
                    events.append(.rivalShipped(rivalID: rival.id, topicID: topicID, day: state.day))
                }
            } else if roll < config.shipChance + config.stumbleChance {
                state.rivals.rivals[index].strength = clamp(
                    state.rivals.rivals[index].strength - config.stumbleStrengthDrop, min: 1, max: 100
                )
                state.rivals.rivals[index].reputation = clamp(
                    state.rivals.rivals[index].reputation - config.stumbleReputationDrop, min: 0, max: 100
                )
            }
        }

        // Fold pass: collapsed rivals leave (their pending offers die with
        // them) and fresh studios take their slots.
        var folded: [Rival] = []
        state.rivals.rivals.removeAll { rival in
            guard rival.strength < config.foldThreshold else { return false }
            folded.append(rival)
            return true
        }
        for rival in folded {
            if state.rivals.pendingPoach?.rivalID == rival.id { state.rivals.pendingPoach = nil }
            if state.rivals.pendingBuyout?.rivalID == rival.id { state.rivals.pendingBuyout = nil }
            events.append(.rivalFolded(rivalID: rival.id, name: rival.name, day: state.day))
            let replacement = found(&state, config, content)
            state.rivals.rivals.append(replacement)
            events.append(.rivalFounded(rivalID: replacement.id, name: replacement.name, day: state.day))
        }
        return events
    }

    /// Direct write to the topic's demand multiplier (not an RNG draw on
    /// the main stream): a rival shipping soaks up some demand.
    private static func dentMarket(
        topicID: String,
        by dent: Double,
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) {
        let before = state.market.multiplier(for: topicID)
        let after = max(balance.market.multiplierMin, before - dent)
        state.market.topics[topicID] = TopicMarket(multiplier: after, lastChange: after - before)
    }

    // MARK: - Poaching

    /// On poach-check days (interval + offset, cooldown elapsed, no offer
    /// already pending, at least one rival and one hired employee): the
    /// target is picked deterministically — the highest score of
    /// `skillWeight × skills.total + underpaidWeight × underpayment +
    /// moraleWeight × (how far morale sits below 70)` — and one uniform
    /// decides whether the strongest rival makes the offer, resisted by
    /// the target's loyalty. A hit draws one more uniform for the salary
    /// premium and pauses the timeline via `.poachAttempt`.
    private static func poachCheck(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        let config = balance.rivals
        guard state.day % config.poachIntervalDays == config.poachOffsetDays,
              state.rivals.pendingPoach == nil,
              state.rivals.lastPoachDay.map({ state.day - $0 >= config.poachCooldownDays }) ?? true,
              let poacher = strongestRival(state),
              let target = poachTarget(state, balance)
        else { return [] }

        let resistance = clamp(1 - target.loyalty / config.loyaltyResistDivisor, min: 0, max: 1)
            / TraitEffects.poachResistance(target, content: content)
        let roll = state.worldRNG.nextUniform()
        guard roll < config.poachChance * resistance else { return [] }

        let fairPay = EmployeeSystem.fairWeeklyPay(for: target, balance: balance)
        let premium = config.poachPremiumMin
            + state.worldRNG.nextUniform() * (config.poachPremiumMax - config.poachPremiumMin)
        let offered = max(target.weeklySalary + 1, Int((fairPay * premium).rounded()))
        let offer = PoachOffer(
            rivalID: poacher.id,
            employeeID: target.id,
            offeredWeeklySalary: offered,
            respondByDay: state.day + config.poachResponseDays
        )
        state.rivals.pendingPoach = offer
        state.rivals.lastPoachDay = state.day
        return [.poachAttempt(
            rivalID: poacher.id,
            employeeID: target.id,
            offeredWeeklySalary: offered,
            respondByDay: offer.respondByDay,
            day: state.day
        )]
    }

    /// The non-founder employee a rival would most want: skilled,
    /// underpaid, unhappy. Deterministic — zero draws; ties break on the
    /// id string so the pick replays identically.
    private static func poachTarget(_ state: GameState, _ balance: BalanceConfig) -> Employee? {
        let config = balance.rivals
        return state.employees
            .filter { !$0.isFounder }
            .map { employee -> (score: Double, employee: Employee) in
                let fairPay = EmployeeSystem.fairWeeklyPay(for: employee, balance: balance)
                let underpaid = fairPay > 0
                    ? max(0, (fairPay - Double(employee.weeklySalary)) / fairPay)
                    : 0
                let lowMorale = max(0, (70 - employee.morale) / 70)
                let score = config.poachSkillWeight * employee.skills.total
                    + config.poachUnderpaidWeight * underpaid
                    + config.poachMoraleWeight * lowMorale
                return (score, employee)
            }
            .max { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score < rhs.score }
                return lhs.employee.id.uuidString < rhs.employee.id.uuidString
            }?
            .employee
    }

    /// A pending poach past its deadline resolves against the employee's
    /// loyalty: one uniform — below `loyalty / 100` they turn the rival
    /// down on their own (shaken loyalty), otherwise they leave.
    private static func resolveExpiredPoach(
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) -> [GameEvent] {
        guard let offer = state.rivals.pendingPoach, state.day > offer.respondByDay else { return [] }
        state.rivals.pendingPoach = nil

        guard let index = state.employees.firstIndex(where: { $0.id == offer.employeeID }) else {
            return []
        }
        let roll = state.worldRNG.nextUniform()
        if roll < state.employees[index].loyalty / 100 {
            state.employees[index].loyalty = clamp(
                state.employees[index].loyalty - 10, min: 0, max: 100
            )
            return [.poachDefeated(employeeID: offer.employeeID, day: state.day)]
        }
        return poachSucceeds(offer, &state, balance)
    }

    /// Removes the employee and credits the rival; friends left behind
    /// take the exit like a firing.
    private static func poachSucceeds(
        _ offer: PoachOffer,
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) -> [GameEvent] {
        guard let index = state.employees.firstIndex(where: { $0.id == offer.employeeID }),
              !state.employees[index].isFounder
        else { return [] }
        let employee = state.employees.remove(at: index)
        if let rivalIndex = state.rivals.rivals.firstIndex(where: { $0.id == offer.rivalID }) {
            state.rivals.rivals[rivalIndex].strength = clamp(
                state.rivals.rivals[rivalIndex].strength + poachedStrengthGain, min: 1, max: 100
            )
        }
        var events: [GameEvent] = [.employeePoached(
            employeeID: employee.id, name: employee.name, rivalID: offer.rivalID, day: state.day
        )]
        events.append(contentsOf: SocialSystem.friendDeparted(
            employee.id, state: &state, balance: balance
        ))
        return events
    }

    // MARK: - Buyouts

    /// On buyout-check days (interval + offset, cooldown elapsed, nothing
    /// pending) a rival moves on a weak company — in debt, cash under the
    /// threshold, or reputation under the threshold (all deterministic).
    /// One uniform decides the approach; a hit draws one more for the
    /// offer fraction and pauses the timeline via `.buyoutOffered`.
    private static func buyoutCheck(
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) -> [GameEvent] {
        let config = balance.rivals
        guard state.day % config.buyoutIntervalDays == config.buyoutOffsetDays,
              state.rivals.pendingBuyout == nil,
              state.rivals.lastBuyoutDay.map({ state.day - $0 >= config.buyoutCooldownDays }) ?? true,
              let buyer = strongestRival(state)
        else { return [] }

        let weak = state.company.daysInDebt > 0
            || state.company.cash < config.weakCashThreshold
            || state.company.reputation < config.weakRepThreshold
        guard weak else { return [] }

        let roll = state.worldRNG.nextUniform()
        guard roll < config.buyoutChance else { return [] }

        let fraction = config.offerFractionMin
            + state.worldRNG.nextUniform() * (config.offerFractionMax - config.offerFractionMin)
        let valuation = state.companyValuation(balance: balance)
        let amount = max(1000, Int((Double(valuation) * fraction).rounded()))
        let offer = BuyoutOffer(
            rivalID: buyer.id,
            amount: amount,
            respondByDay: state.day + config.buyoutResponseDays
        )
        state.rivals.pendingBuyout = offer
        state.rivals.lastBuyoutDay = state.day
        return [.buyoutOffered(
            rivalID: buyer.id, amount: amount, respondByDay: offer.respondByDay, day: state.day
        )]
    }

    /// A pending buyout past its deadline is quietly withdrawn (no draws).
    private static func resolveExpiredBuyout(_ state: inout GameState, _ events: inout [GameEvent]) {
        guard let offer = state.rivals.pendingBuyout, state.day > offer.respondByDay else { return }
        state.rivals.pendingBuyout = nil
        events.append(.buyoutWithdrawn(rivalID: offer.rivalID, day: state.day))
    }

    // MARK: - Actions

    /// Matches a pending poach offer: the employee's salary rises to the
    /// rival's number (with the usual raise morale math) and their loyalty
    /// jumps. Ignored with nothing pending; a target who already left just
    /// clears the offer.
    static func matchPoachOffer(state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        guard let offer = state.rivals.pendingPoach else { return [] }
        state.rivals.pendingPoach = nil
        guard let index = state.employees.firstIndex(where: { $0.id == offer.employeeID }),
              !state.employees[index].isFounder
        else { return [] }

        var events = EmployeeSystem.adjustSalary(
            employeeID: offer.employeeID,
            weeklySalary: offer.offeredWeeklySalary,
            state: &state,
            balance: balance
        )
        state.employees[index].loyalty = clamp(
            state.employees[index].loyalty + balance.rivals.matchLoyaltyBoost, min: 0, max: 100
        )
        events.append(.poachDefeated(employeeID: offer.employeeID, day: state.day))
        return events
    }

    /// Lets the poached employee go to the rival. Ignored with nothing
    /// pending.
    static func declinePoachOffer(state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        guard let offer = state.rivals.pendingPoach else { return [] }
        state.rivals.pendingPoach = nil
        return poachSucceeds(offer, &state, balance)
    }

    /// Sells the company: the sale posts to the ledger and the run ends as
    /// a successful exit. Ignored with nothing pending.
    static func acceptBuyout(state: inout GameState) -> [GameEvent] {
        guard let offer = state.rivals.pendingBuyout else { return [] }
        state.rivals.pendingBuyout = nil
        let buyerName = state.rivals.rival(id: offer.rivalID)?.name ?? "a rival"

        state.company.cash += offer.amount
        state.ledger.post(LedgerEntry(
            day: state.day,
            amount: offer.amount,
            category: .other,
            label: "Company sale to \(buyerName)"
        ))
        state.gameOver = GameOverInfo(
            day: state.day,
            reason: "Acquired by \(buyerName) for $\(offer.amount).",
            kind: .acquired
        )
        return [
            .companySold(rivalID: offer.rivalID, amount: offer.amount, day: state.day),
            .gameOver(day: state.day),
        ]
    }

    /// Turns a pending buyout down. Ignored with nothing pending.
    static func declineBuyout(state: inout GameState) -> [GameEvent] {
        guard let offer = state.rivals.pendingBuyout else { return [] }
        state.rivals.pendingBuyout = nil
        return [.buyoutWithdrawn(rivalID: offer.rivalID, day: state.day)]
    }

    /// Buys a rival studio outright. Gated on affordability
    /// (`valuation × acquirePremium`) and dominance (player valuation at
    /// least `acquireDominanceFactor ×` the rival's). The rival's team
    /// partially joins — `strength / absorbDivisor` hires, capped by the
    /// office headroom, each rolled from `worldRNG` (two id words, first
    /// name, last name, three skill rolls, salary jitter, appearance
    /// seed) — and the rival leaves the field for good.
    static func acquireRival(
        rivalID: UUID,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        let config = balance.rivals
        guard let rivalIndex = state.rivals.rivals.firstIndex(where: { $0.id == rivalID })
        else { return [] }
        let rival = state.rivals.rivals[rivalIndex]
        let cost = Int((Double(rival.valuation(balance: balance)) * config.acquirePremium).rounded())
        guard state.company.cash >= cost,
              Double(state.companyValuation(balance: balance))
                >= Double(rival.valuation(balance: balance)) * config.acquireDominanceFactor
        else { return [] }

        state.company.cash -= cost
        state.ledger.post(LedgerEntry(
            day: state.day,
            amount: -cost,
            category: .other,
            label: "Acquired \(rival.name)"
        ))
        state.company.reputation = clamp(
            state.company.reputation + config.acquireRepBonus, min: 0, max: 100
        )

        let headroom = max(0, balance.office(state.company.officeTier).headcountCap - state.headcount)
        let joining = min(headroom, Int((rival.strength / config.absorbDivisor).rounded()))
        for hireIndex in 0..<joining {
            state.employees.append(absorbedHire(
                from: rival, index: hireIndex, state: &state, balance: balance, content: content
            ))
        }

        state.rivals.rivals.remove(at: rivalIndex)
        if state.rivals.pendingPoach?.rivalID == rival.id { state.rivals.pendingPoach = nil }
        if state.rivals.pendingBuyout?.rivalID == rival.id { state.rivals.pendingBuyout = nil }
        return [.rivalAcquired(
            rivalID: rival.id, name: rival.name, hiresAbsorbed: joining, day: state.day
        )]
    }

    /// One employee inherited from an acquired rival. Skills roll against
    /// a ceiling set by the rival's strength; the role rotates through the
    /// builder roles by index (no draw).
    private static func absorbedHire(
        from rival: Rival,
        index: Int,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> Employee {
        let id = UUID(from: &state.worldRNG)
        let first = pick(content.names.firstNames, &state.worldRNG) ?? "Alex"
        let last = pick(content.names.lastNames, &state.worldRNG) ?? "Doe"
        let ceiling = clamp(20 + rival.strength * 0.6, min: 20, max: 90)
        let skills = SkillSet(
            coding: 5 + state.worldRNG.nextUniform() * (ceiling - 5),
            design: 5 + state.worldRNG.nextUniform() * (ceiling - 5),
            marketing: 5 + state.worldRNG.nextUniform() * (ceiling - 5)
        )
        let jitter = 1 + (state.worldRNG.nextUniform() * 2 - 1) * balance.salaryJitter
        let salary = (Double(balance.salaryBase) + balance.salaryPerSkillPoint * skills.total) * jitter
        let roles: [EmployeeRole] = [.backend, .frontend, .designer]
        return Employee(
            id: id,
            name: "\(first) \(last)",
            skills: skills,
            weeklySalary: Int(salary.rounded()),
            assignment: .idle,
            isFounder: false,
            hiredDay: state.day,
            appearanceSeed: state.worldRNG.next(),
            morale: balance.staff.startingMorale,
            level: .forSkillTotal(skills.total),
            role: roles[index % roles.count]
        )
    }

    // MARK: - Helpers

    /// The strongest rival; ties break on the id string.
    private static func strongestRival(_ state: GameState) -> Rival? {
        state.rivals.rivals.max { lhs, rhs in
            if lhs.strength != rhs.strength { return lhs.strength < rhs.strength }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private static func pick(_ pool: [String], _ rng: inout SeededRNG) -> String? {
        guard !pool.isEmpty else { return nil }
        return pool[rng.nextInt(in: 0...(pool.count - 1))]
    }

    private static func clamp(_ value: Double, min lower: Double, max upper: Double) -> Double {
        min(upper, max(lower, value))
    }
}
