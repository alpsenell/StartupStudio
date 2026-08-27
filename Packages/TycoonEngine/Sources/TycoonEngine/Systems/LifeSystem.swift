import Foundation
import TycoonContent

/// Daily life system, running first in the fixed system order so today's
/// founder multipliers apply to today's output. Each day, in this order:
/// 1. expiry — an away window ending today clears (emitting `.founderBack`)
///    and an ending cold clears;
/// 2. meter drift — the schedule's drift (chill while away), the
///    relationship stage's drain, per-child drift, the home's mood bonus,
///    the owned amenities' founder health bonus (the gym), and the debt
///    mood penalty, clamped to 0...100;
/// 3. thresholds — burnout, then hospital (each only while not away, so
///    burnout wins a same-day tie), then the breakup streak;
/// 4. life events — every `lifeEventIntervalDays` days, one roll against
///    `lifeEventChance` and a weighted pick among the eligible events;
/// 5. weekly (day % 7 == 0) — founder salary, rent and child costs, then
///    the planned weekend activity (skipped while away).
///
/// The RNG draw order for life events is fixed for determinism:
/// 1. the hit roll (`nextUniform()`, one word) — only on interval days with
///    a non-empty catalog,
/// 2. the weighted pick (`nextInt(in:)`, one word) — only on a hit with at
///    least one eligible event,
/// 3. applying the impact draws nothing.
/// Every other step draws nothing. Also hosts the life action handlers used
/// by `Reducer.apply`.
enum LifeSystem {
    static let burnoutReason = "Burnout"
    static let hospitalReason = "Hospital"
    static let vacationReason = "Vacation"
    static let founderSalaryLabel = "Founder salary"

    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        var events: [GameEvent] = []
        let config = balance.life

        // 0. A new day resets the instant-activity cap.
        state.life.instantActionsToday = 0

        // 1. Expiry.
        if let until = state.life.awayUntilDay, state.day >= until {
            state.life.awayUntilDay = nil
            state.life.awayReason = nil
            events.append(.founderBack(day: state.day))
        }
        if let until = state.life.coldUntilDay, state.day >= until {
            state.life.coldUntilDay = nil
        }

        // 2. Drift.
        applyDailyDrift(&state, balance)

        // 3. Thresholds.
        events.append(contentsOf: checkThresholds(&state, config))

        // 4. Life events.
        events.append(contentsOf: rollLifeEvent(&state, config, content))

        // 5. Weekly flows.
        if state.day % GameState.daysPerWeek == 0 {
            events.append(contentsOf: runWeekly(&state, config))
        }

        return events
    }

    // MARK: - Daily drift

    private static func applyDailyDrift(_ state: inout GameState, _ balance: BalanceConfig) {
        let config = balance.life
        let schedule = state.life.isAway(day: state.day) ? WorkSchedule.chill : state.life.schedule
        let drift = config.drift(for: schedule)
        let childCount = Double(state.life.family.children.count)
        let child = config.childDrift
        let amenityHealth = state.ownedAmenities.reduce(0.0) {
            $0 + balance.company.amenity($1).founderHealthBonus
        }

        let energy = drift.energy + childCount * child.energy
        let health = drift.health + childCount * child.health + amenityHealth
        // Owned possessions in sorted-id order so the sum accumulates in a
        // fixed order (the list is kept sorted, but stay defensive).
        let instant = balance.instantLife
        var possessionMood = 0.0
        var possessionPrestige = 0.0
        for id in state.life.possessions.sorted() {
            guard let item = instant.items[id] else { continue }
            possessionMood += item.dailyMoodDrift
            possessionPrestige += item.prestige
        }

        let relationships = drift.relationships + childCount * child.relationships
            - config.relationshipDrain(for: state.life.family.stage)
            + possessionPrestige * instant.prestigeRelationshipFactor
        var mood = drift.mood + childCount * child.mood + config.home(state.life.home).moodBonus
            + possessionMood
        if state.life.wallet < 0 {
            mood -= config.debtMoodPenalty
        }

        state.life.meters.apply(energy: energy, health: health, mood: mood, relationships: relationships)
    }

    // MARK: - Thresholds

    private static func checkThresholds(
        _ state: inout GameState,
        _ config: BalanceConfig.LifeBalance
    ) -> [GameEvent] {
        var events: [GameEvent] = []
        let day = state.day

        if !state.life.isAway(day: day), state.life.meters.energy < config.burnoutEnergyThreshold {
            let until = day + config.burnoutDays
            state.life.awayUntilDay = until
            state.life.awayReason = burnoutReason
            state.life.meters.energy = LifeMeters.clamped(config.burnoutRecoveryEnergy)
            events.append(.founderAway(reason: burnoutReason, untilDay: until, day: day))
        }

        if !state.life.isAway(day: day), state.life.meters.health < config.hospitalHealthThreshold {
            let until = day + config.hospitalDays
            state.life.awayUntilDay = until
            state.life.awayReason = hospitalReason
            state.life.wallet -= config.hospitalBill
            state.life.meters.health = LifeMeters.clamped(config.hospitalRecoveryHealth)
            events.append(.founderAway(reason: hospitalReason, untilDay: until, day: day))
        }

        if state.life.family.stage != .single,
           state.life.meters.relationships < config.breakupThreshold {
            state.life.lowRelationshipStreakDays += 1
        } else {
            state.life.lowRelationshipStreakDays = 0
        }
        if state.life.family.stage != .single,
           state.life.lowRelationshipStreakDays >= config.breakupStreakDays {
            state.life.family.stage = .single
            state.life.family.stageSinceDay = day
            state.life.family.partnerName = nil
            state.life.family.partnerAppearanceSeed = nil
            state.life.meters.apply(mood: -config.breakupMoodPenalty)
            state.life.lowRelationshipStreakDays = 0
            events.append(.breakup(day: day))
        }

        return events
    }

    // MARK: - Life events

    private static func rollLifeEvent(
        _ state: inout GameState,
        _ config: BalanceConfig.LifeBalance,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        guard state.day % config.lifeEventIntervalDays == 0,
              !content.lifeEvents.isEmpty
        else { return [] }

        // 1. The hit roll.
        guard state.rng.nextUniform() < config.lifeEventChance else { return [] }

        // 2. The weighted pick over the eligible events, cumulative weights
        // in catalog order. Weights are >= 1 by the content contract;
        // max(1, _) keeps a malformed catalog from trapping the reducer.
        let eligible = content.lifeEvents.filter { isEligible($0, state: state) }
        guard !eligible.isEmpty else { return [] }
        let totalWeight = eligible.reduce(0) { $0 + max(1, $1.weight) }
        var remaining = state.rng.nextInt(in: 0...(totalWeight - 1))
        var picked = eligible[eligible.count - 1]
        for event in eligible {
            remaining -= max(1, event.weight)
            if remaining < 0 {
                picked = event
                break
            }
        }

        // 3. Apply the impact.
        return apply(picked, to: &state)
    }

    private static func isEligible(_ event: LifeEventDef, state: GameState) -> Bool {
        if let minStage = event.minStage {
            guard let stage = RelationshipStage(rawValue: minStage),
                  state.life.family.stage.rank >= stage.rank
            else { return false }
        }
        if event.requiresChildren, state.life.family.children.isEmpty {
            return false
        }
        if let cap = event.maxRelationships, state.life.meters.relationships >= cap {
            return false
        }
        return true
    }

    /// Applies one event's impact: meter deltas (clamped), the wallet
    /// delta, a cold window, and — unless the founder is already away — an
    /// away window (reason: the impact's `awayReason`, or the headline).
    private static func apply(_ event: LifeEventDef, to state: inout GameState) -> [GameEvent] {
        let impact = event.impact
        let day = state.day
        state.life.meters.apply(
            energy: impact.energy, health: impact.health,
            mood: impact.mood, relationships: impact.relationships
        )
        state.life.wallet += impact.wallet
        if impact.coldDays > 0 {
            state.life.coldUntilDay = day + impact.coldDays
        }

        var events: [GameEvent] = [.lifeEvent(eventID: event.id, day: day)]
        if impact.awayDays > 0, !state.life.isAway(day: day) {
            let until = day + impact.awayDays
            let reason = impact.awayReason ?? event.headline
            state.life.awayUntilDay = until
            state.life.awayReason = reason
            events.append(.founderAway(reason: reason, untilDay: until, day: day))
        }
        return events
    }

    // MARK: - Weekly flows

    /// (i) the founder's salary moves from company cash into the wallet
    /// (ledger `.payroll`, only when > 0); (ii) home rent and per-child
    /// costs debit the wallet; (iii) the planned weekend resolves unless
    /// the founder is away. Costs debit the wallet even into the negative.
    private static func runWeekly(
        _ state: inout GameState,
        _ config: BalanceConfig.LifeBalance
    ) -> [GameEvent] {
        let day = state.day

        let salary = state.life.founderSalary
        if salary > 0 {
            state.company.cash -= salary
            state.life.wallet += salary
            state.ledger.post(LedgerEntry(
                day: day, amount: -salary, category: .payroll, label: founderSalaryLabel
            ))
        }

        state.life.wallet -= config.home(state.life.home).weeklyRent
            + state.life.family.children.count * config.childWeeklyCost

        guard !state.life.isAway(day: day) else { return [] }

        let activity = resolvedActivity(state.life)
        let def = config.activity(activity)
        state.life.meters.apply(
            energy: def.energy, health: def.health, mood: def.mood, relationships: def.relationships
        )
        state.life.wallet -= def.cost

        var events: [GameEvent] = [.weekendSpent(activity: activity, day: day)]
        switch activity {
        case .vacation:
            let until = day + config.vacationDays
            state.life.awayUntilDay = until
            state.life.awayReason = vacationReason
            state.life.plannedActivity = .rest
            events.append(.founderAway(reason: vacationReason, untilDay: until, day: day))
        case .doctor:
            state.life.coldUntilDay = nil
        case .rest, .gym, .dateNight, .friends, .hobby, .familyTime, .spa, .networking:
            break
        }
        return events
    }

    /// The activity that actually happens: a date night while single is a
    /// night out with friends; family time with no partner and no children
    /// is rest.
    private static func resolvedActivity(_ life: LifeState) -> WeekendActivity {
        switch life.plannedActivity {
        case .dateNight where life.family.stage == .single:
            .friends
        case .familyTime where life.family.stage == .single && life.family.children.isEmpty:
            .rest
        default:
            life.plannedActivity
        }
    }

    // MARK: - Actions

    /// Changes the work schedule. No event.
    static func setWorkSchedule(_ schedule: WorkSchedule, state: inout GameState) -> [GameEvent] {
        state.life.schedule = schedule
        return []
    }

    /// Sets the weekly founder salary, clamped to 0...`founderSalaryMax`.
    /// No event.
    static func setFounderSalary(_ amount: Int, state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        state.life.founderSalary = min(balance.life.founderSalaryMax, max(0, amount))
        return []
    }

    /// Plans the next weekend. No event.
    static func planWeekend(_ activity: WeekendActivity, state: inout GameState) -> [GameEvent] {
        state.life.plannedActivity = activity
        return []
    }

    /// Moves one home tier up the ladder. Ignored at the top and while the
    /// next tier's upgrade cost exceeds the wallet.
    static func upgradeHome(state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        guard let next = state.life.home.next,
              state.life.wallet >= balance.life.home(next).upgradeCost
        else { return [] }

        state.life.wallet -= balance.life.home(next).upgradeCost
        state.life.home = next
        return [.homeUpgraded(tier: next, day: state.day)]
    }

    /// Advances the relationship one stage. Gates: single → dating needs
    /// `datingMinRelationships` (and draws a partner name then an appearance
    /// seed from the RNG, in that order); dating → partner needs
    /// `partnerMinRelationships` and `partnerMinDaysAtStage`; partner →
    /// married needs `marriedMinRelationships`, `marriedMinDaysAtStage`, and
    /// the wedding cost in the wallet (debited). Ignored otherwise.
    static func advanceRelationship(
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        let config = balance.life
        let relationships = state.life.meters.relationships
        let daysAtStage = state.day - state.life.family.stageSinceDay

        switch state.life.family.stage {
        case .single:
            guard relationships >= config.datingMinRelationships else { return [] }
            state.life.family.partnerName = pick(content.names.partnerNames, &state.rng)
            state.life.family.partnerAppearanceSeed = state.rng.next()
            state.life.family.stage = .dating
        case .dating:
            guard relationships >= config.partnerMinRelationships,
                  daysAtStage >= config.partnerMinDaysAtStage
            else { return [] }
            state.life.family.stage = .partner
        case .partner:
            guard relationships >= config.marriedMinRelationships,
                  daysAtStage >= config.marriedMinDaysAtStage,
                  state.life.wallet >= config.weddingCost
            else { return [] }
            state.life.wallet -= config.weddingCost
            state.life.family.stage = .married
        case .married:
            return []
        }

        state.life.family.stageSinceDay = state.day
        return [.relationshipChanged(stage: state.life.family.stage, day: state.day)]
    }

    /// Has a child. Gates: married, `childMinRelationships`, the child start
    /// cost in the wallet (debited), a home of at least `childMinHome`,
    /// fewer than `maxChildren`, and `childSpacingDays` since the last
    /// child. The RNG draws id (two words), name, then appearance seed.
    static func haveChild(
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        let config = balance.life
        let family = state.life.family
        let minHomeRank = HomeTier(rawValue: config.childMinHome)?.rank ?? 0
        guard family.stage == .married,
              state.life.meters.relationships >= config.childMinRelationships,
              state.life.wallet >= config.childStartCost,
              state.life.home.rank >= minHomeRank,
              family.children.count < config.maxChildren,
              family.lastChildDay.map({ state.day - $0 >= config.childSpacingDays }) ?? true
        else { return [] }

        let id = UUID(from: &state.rng)
        let name = pick(content.names.childNames, &state.rng)
        let seed = state.rng.next()

        state.life.wallet -= config.childStartCost
        state.life.family.children.append(Child(
            id: id, name: name, bornDay: state.day, appearanceSeed: seed
        ))
        state.life.family.lastChildDay = state.day
        state.life.meters.apply(mood: config.childMoodBonus)
        return [.childBorn(name: name, day: state.day)]
    }

    /// Does an instant activity right now: applies the meter deltas and
    /// debits the wallet. Gated on the shared per-day cap, the activity's
    /// cooldown, the wallet, and the founder being around. Zero RNG.
    static func doInstantActivity(
        _ activity: InstantActivity,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        let instant = balance.instantLife
        guard let def = instant.activity(activity),
              state.life.instantActionsToday < instant.maxPerDay,
              // Free activities are always affordable, even overdrawn.
              def.cost == 0 || state.life.wallet >= def.cost,
              !state.life.isAway(day: state.day)
        else { return [] }
        if let last = state.life.instantCooldowns[activity.rawValue],
           state.day - last < def.cooldownDays { return [] }

        state.life.meters.apply(
            energy: def.energy, health: def.health, mood: def.mood, relationships: def.relationships
        )
        state.life.wallet -= def.cost
        state.life.instantCooldowns[activity.rawValue] = state.day
        state.life.instantActionsToday += 1
        return [.instantActivityDone(activity: activity, day: state.day)]
    }

    /// Buys a possession from the shop catalog: instant mood pop now, its
    /// daily drift joins `applyDailyDrift` from tomorrow. Gated on the
    /// wallet, not already owning it, and the founder being around.
    static func buyItem(
        itemID: String,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard let item = balance.instantLife.items[itemID],
              !state.life.possessions.contains(itemID),
              state.life.wallet >= item.cost,
              !state.life.isAway(day: state.day)
        else { return [] }

        state.life.wallet -= item.cost
        state.life.possessions.append(itemID)
        state.life.possessions.sort()
        state.life.meters.apply(mood: item.moodPop)
        return [.itemPurchased(itemID: itemID, day: state.day)]
    }

    private static func pick(_ pool: [String], _ rng: inout SeededRNG) -> String {
        guard !pool.isEmpty else { return "" }
        return pool[rng.nextInt(in: 0...(pool.count - 1))]
    }
}
