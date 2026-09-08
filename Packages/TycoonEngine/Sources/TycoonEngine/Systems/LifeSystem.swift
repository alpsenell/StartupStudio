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
/// 4. life events — delegated to `LifeEventSystem.roll` (WS-B owns it):
///    every `lifeEventIntervalDays` days, one roll against
///    `lifeEventChance` and a weighted pick among the eligible events;
/// 5. weekly (day % 7 == 0) — founder salary, rent and child costs, then
///    the planned weekend activity (skipped while away).
///
/// The life-event draw order lives with the roll, in `LifeEventSystem`.
/// Every other step here draws nothing. Also hosts the life action handlers
/// used by `Reducer.apply`.
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

        // 0. A new day resets the per-day caps; a new week refills the
        //    evening budget those caps sit under.
        state.life.instantActionsToday = 0
        state.life.trainingsToday = 0
        if state.day % GameState.daysPerWeek == 1 {
            state.life.eveningsSpentThisWeek = 0
        }

        // 1. Expiry.
        if let until = state.life.awayUntilDay, state.day >= until {
            state.life.awayUntilDay = nil
            state.life.awaySinceDay = nil
            state.life.awayReason = nil
            events.append(.founderBack(day: state.day))
        }
        if let until = state.life.coldUntilDay, state.day >= until {
            state.life.coldUntilDay = nil
        }
        if let until = state.economy.convalescingUntilDay, state.day >= until {
            state.economy.convalescingUntilDay = nil
        }

        // 2. Drift.
        applyDailyDrift(&state, balance)

        // 3. Thresholds.
        events.append(contentsOf: checkThresholds(&state, balance, content))

        // 3b. The long tail of those thresholds: a chronic condition, a
        //     meltdown that makes the press, loneliness, and the landlord.
        events.append(contentsOf: applyConsequences(&state, balance))

        // MARK: Iteration 11 — N3 (assets, vices and the doctor)
        // 3c. The founder's things, the founder's habits and the founder's
        //     body, on the same meters the schedule just moved: the mood a
        //     dog is worth, the mood a dependency costs, the drift of
        //     whatever the doctor has named, and the counters the next
        //     diagnosis reads. The existing `chronicCondition`,
        //     `hospitalizationDays` and `burnoutDays` above are *read* by
        //     it and never moved. Draws nothing, and returns on its first
        //     line until the player has opened the Assets screen — so
        //     every bot and every fixture is untouched.
        events.append(contentsOf: AssetsSystem.applyLife(&state, balance))
        // MARK: end of Iteration 11 — N3

        // 4. Life events.
        events.append(contentsOf: LifeEventSystem.roll(&state, balance, content))

        // 5. Weekly flows.
        if state.day % GameState.daysPerWeek == 0 {
            events.append(contentsOf: runWeekly(&state, balance, content))
        }

        return events
    }

    // MARK: - Daily drift

    private static func applyDailyDrift(_ state: inout GameState, _ balance: BalanceConfig) {
        let config = balance.life
        let drift = config.drift(for: state.effectiveSchedule)
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
        // Being broke is grim; climbing out of it is not. The penalty
        // stands while the wallet is level or still falling week on week,
        // and lifts the moment it starts recovering — so a founder whose
        // company has finally started paying them properly can get their
        // head above water instead of being pinned at mood zero (and so at
        // `minOutputFactor`) for the rest of the run.
        if state.life.wallet < 0,
           state.life.wallet <= state.economy.walletLastWeek ?? Int.max {
            mood -= config.debtMoodPenalty
        }
        // Nobody has called in two months.
        if isLonely(state, balance.economy) {
            mood -= balance.economy.lonelinessMoodDrift
        }

        state.life.meters.apply(energy: energy, health: health, mood: mood, relationships: relationships)

        // A chronic condition puts a ceiling on how rested the founder can
        // ever be.
        if state.economy.chronicCondition {
            state.life.meters.energy = min(
                state.life.meters.energy, balance.economy.chronicMaxEnergy
            )
        }
    }

    /// Whether the founder has been alone at rock bottom long enough for it
    /// to start costing them.
    static func isLonely(_ state: GameState, _ economy: BalanceConfig.EconomyBalance) -> Bool {
        guard let since = state.economy.lonelySinceDay else { return false }
        return state.day - since >= economy.lonelinessDays
    }

    // MARK: - Thresholds

    private static func checkThresholds(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        let config = balance.life
        var events: [GameEvent] = []
        let day = state.day

        if !state.life.isAway(day: day), state.life.meters.energy < config.burnoutEnergyThreshold {
            let until = day + config.burnoutDays
            state.life.awayUntilDay = until
            state.life.awaySinceDay = day
            state.life.awayReason = burnoutReason
            state.life.meters.energy = LifeMeters.clamped(config.burnoutRecoveryEnergy)
            state.economy.burnoutDays.append(day)
            events.append(.founderAway(reason: burnoutReason, untilDay: until, day: day))
        }

        if !state.life.isAway(day: day), state.life.meters.health < config.hospitalHealthThreshold {
            let until = day + config.hospitalDays
            state.life.awayUntilDay = until
            state.life.awaySinceDay = day
            state.life.awayReason = hospitalReason
            state.life.wallet -= hospitalBill(state, balance)
            state.life.meters.health = LifeMeters.clamped(config.hospitalRecoveryHealth)
            state.economy.hospitalizationDays.append(day)
            // Signed off. The ward, then a fortnight of being told to take
            // it easy: `effectiveSchedule` reads `.chill` throughout and
            // `setWorkSchedule` refuses to crunch, so a founder cannot
            // discharge themselves straight back into the loop that put
            // them there. `life.schedule` keeps their intent, so the run
            // they were on resumes by itself afterwards. Without this the
            // same crunch that caused the stay picks up the day the bed is
            // free and health falls the same forty days to the same
            // threshold, five to twelve times over two years.
            state.economy.convalescingUntilDay = until + balance.economy.convalescenceDays
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
            state.life.family.partnerContactID = nil
            state.life.family.affection = 0
            state.life.family.lastPartnerDay = nil
            state.life.family.partnerCooldowns = [:]
            state.life.meters.apply(mood: -config.breakupMoodPenalty)
            state.life.lowRelationshipStreakDays = 0
            // WS-E: their dates leave the diary with them.
            FamilyCalendar.partnerLeft(&state, content: content)
            events.append(.breakup(day: day))
        }

        return events
    }

    // MARK: - Consequences

    /// What today's thresholds mean beyond the week they happen in.
    ///
    /// - **Chronic condition.** Two hospital stays inside a year and the
    ///   founder is living with something: energy is capped and their
    ///   output permanently docked until three straight restorative
    ///   weekends clear it.
    /// - **Meltdown.** Burning out twice in a year makes the trade press
    ///   and costs the studio reputation.
    /// - **Loneliness.** Rock-bottom relationships while single start a
    ///   clock; past `lonelinessDays` the mood drifts down every day until
    ///   the founder sees somebody.
    /// - **Eviction.** A wallet past `evictionWalletThreshold` earns a
    ///   warning; if nothing changes by the deadline the company either
    ///   starts paying the founder properly or they move somewhere
    ///   cheaper. Zero RNG throughout.
    private static func applyConsequences(
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) -> [GameEvent] {
        let economy = balance.economy
        let day = state.day
        var events: [GameEvent] = []

        // Two hospital stays in a year: something is now permanent.
        if !state.economy.chronicCondition, economy.chronicWindowDays > 0 {
            let recent = state.economy.hospitalizationDays
                .count { day - $0 < economy.chronicWindowDays }
            if recent >= 2 {
                state.economy.chronicCondition = true
                state.economy.recoveryWeeks = 0
                events.append(.chronicConditionDiagnosed(day: day))
            }
        }
        // Two burnouts in a year: the founder's meltdown makes the news.
        if economy.burnoutWindowDays > 0,
           state.economy.burnoutDays.last == day,
           state.economy.burnoutDays.count(where: { day - $0 < economy.burnoutWindowDays }) >= 2 {
            state.company.reputation = max(
                0, state.company.reputation - economy.burnoutReputationPenalty
            )
            events.append(.founderMeltdown(day: day))
        }

        // Loneliness: the clock starts at rock bottom and stops the moment
        // there is anybody in the founder's life again.
        if state.life.family.stage == .single,
           state.life.meters.relationships <= economy.lonelinessRelationshipThreshold {
            if state.economy.lonelySinceDay == nil {
                state.economy.lonelySinceDay = day
            }
        } else {
            state.economy.lonelySinceDay = nil
        }

        // The landlord.
        events.append(contentsOf: checkEviction(&state, balance))
        return events
    }

    /// The debt spiral's endgame. Under the threshold the founder gets one
    /// warning and `evictionGraceDays` to fix it; after that the company
    /// starts paying them a real salary if it can, and otherwise they pack.
    private static func checkEviction(
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) -> [GameEvent] {
        let economy = balance.economy
        let day = state.day
        guard economy.evictionWalletThreshold > Int.min else { return [] }

        guard state.life.wallet < economy.evictionWalletThreshold else {
            // Back in the black: the warning is withdrawn, and once the
            // overdraft is actually cleared the rescue salary steps back
            // down to what it costs the founder to live. The company
            // covers you until you are square; it does not keep paying
            // three times the going rate for the rest of the run because
            // of one bad quarter. A salary the *player* set is never
            // touched — only the one this function raised.
            state.economy.evictionWarningDay = nil
            if let rescue = state.economy.rescueSalary,
               state.life.wallet >= 0,
               state.life.founderSalary == rescue {
                state.life.founderSalary = min(
                    rescue, max(balance.life.defaultFounderSalary, livingCosts(state, balance))
                )
                state.economy.rescueSalary = nil
            }
            return []
        }
        guard let warned = state.economy.evictionWarningDay else {
            state.economy.evictionWarningDay = day
            return [.evictionWarning(untilDay: day + economy.evictionGraceDays, day: day)]
        }
        // Re-checked every grace period, not once. The warning stands
        // until the wallet is back above the threshold, so a founder
        // stuck at the bottom is not re-served every fortnight — but the
        // *rescue* has to be re-offered, or a company that happened to be
        // short of cash on one particular day never bails its founder out
        // at all, however rich it gets afterwards.
        let elapsed = day - warned
        guard elapsed > 0, elapsed.isMultiple(of: max(1, economy.evictionGraceDays)) else {
            return []
        }

        // The company bails them out if it can carry the salary — and the
        // salary is sized to *clear the hole*, not merely to cover the
        // rent. Paying somebody £240 a week against a £30,000 overdraft is
        // not a rescue, it is a rounding error: it would take fifteen
        // years. This pays the weekly costs plus the overdraft amortised
        // over `evictionRecoveryWeeks`, capped at `founderSalaryMax`.
        let rent = balance.life.home(state.life.home).weeklyRent
        let weeklyCosts = livingCosts(state, balance)
        let deficit = max(0, -state.life.wallet)
        let amortised = weeklyCosts
            + Int((Double(deficit) / Double(max(1, economy.evictionRecoveryWeeks))).rounded())
        let rescue = min(
            balance.life.founderSalaryMax,
            max(state.life.founderSalary, rent * 2, amortised)
        )
        // Affordable means the company could carry it for a quarter on
        // today's balance, not merely make this week's payment.
        if state.company.cash >= rescue * GameState.daysPerWeek * 2,
           rescue > state.life.founderSalary {
            state.life.founderSalary = rescue
            state.economy.rescueSalary = rescue
            return []
        }
        // Otherwise they move somewhere they can afford.
        guard let cheaper = state.life.home.previous else { return [] }
        state.life.home = cheaper
        state.life.meters.apply(mood: -balance.life.breakupMoodPenalty / 2)
        return [.homeDowngraded(tier: cheaper, day: day)]
    }

    /// What the founder's week costs them before they eat: rent and the
    /// children.
    static func livingCosts(_ state: GameState, _ balance: BalanceConfig) -> Int {
        balance.life.home(state.life.home).weeklyRent
            + state.life.family.children.count * balance.life.childWeeklyCost
    }

    /// What a hospital stay actually costs the founder. A company with a
    /// People & HR department carries `hospitalInsuredFraction` of it —
    /// the department's first reason to exist that is not morale, and the
    /// answer to "why would a studio ever staff HR?".
    static func hospitalBill(_ state: GameState, _ balance: BalanceConfig) -> Int {
        let full = balance.life.hospitalBill
        guard state.activeDepartments.contains(.hr) else { return full }
        return Int((Double(full) * (1 - balance.economy.hospitalInsuredFraction)).rounded())
    }

    // MARK: - Weekly flows

    /// (i) the founder's salary moves from company cash into the wallet
    /// (ledger `.payroll`, only when > 0); (ii) home rent and per-child
    /// costs debit the wallet; (iii) the planned weekend resolves unless
    /// the founder is away. Costs debit the wallet even into the negative.
    private static func runWeekly(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        let config = balance.life
        let day = state.day
        // Snapshot *before* this week's settlement, so the following week
        // can ask "did the wallet go up?" and the debt mood penalty can
        // lift while the founder is climbing out.
        state.economy.walletLastWeek = state.life.wallet

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

        // An overdrawn personal account is not free money — but the
        // overdraft is only extended as far as the eviction threshold.
        // Past that nobody is lending the founder anything, so the
        // interest stops growing with the hole instead of compounding on
        // it. (Uncapped, a founder who is hospitalised eight times reaches
        // −$90k on a $200-a-week salary, of which roughly $38k is interest
        // on interest, and there is no arithmetic that gets them back.)
        if state.life.wallet < 0 {
            // `Int.min` is the "no eviction in this test balance" sentinel,
            // and `abs` would trap on it — an uncapped overdraft is the
            // right reading of a threshold that never arrives.
            let ceiling = balance.economy.evictionWalletThreshold
            let cap = Int(exactly: ceiling.magnitude) ?? Int.max
            let charged = min(-state.life.wallet, cap)
            let interest = Int(
                (Double(charged) * balance.economy.walletInterestWeeklyRate).rounded()
            )
            state.life.wallet -= interest
        }

        guard !state.life.isAway(day: day) else {
            // A weekend spent in hospital is not a weekend spent recovering.
            state.economy.recoveryWeeks = 0
            return []
        }

        let activity = resolvedActivity(state.life)
        let def = config.activity(activity)
        state.life.meters.apply(
            energy: def.energy, health: def.health, mood: def.mood, relationships: def.relationships
        )
        state.life.wallet -= def.cost

        // A weekend actually spent with the person you are with counts as
        // spending it with them — the Life tab's date night and the
        // partner card's are the same evening.
        if activity == .dateNight || activity == .familyTime,
           state.life.family.stage != .single {
            state.life.family.affection = min(
                100,
                state.life.family.affection
                    + def.relationships * state.founderCharmFactor(balance)
            )
            state.life.family.lastPartnerDay = day
        }

        var events: [GameEvent] = [.weekendSpent(activity: activity, day: day)]
        events.append(contentsOf: applyWeekendRecovery(activity, &state, balance))
        switch activity {
        case .vacation:
            let until = day + config.vacationDays
            state.life.awayUntilDay = until
            state.life.awaySinceDay = day
            state.life.awayReason = vacationReason
            state.life.plannedActivity = .rest
            events.append(.founderAway(reason: vacationReason, untilDay: until, day: day))
        case .doctor:
            state.life.coldUntilDay = nil
        case .networking:
            // The evening is not just a meter change: it opens a room full
            // of people, which stays open for a couple of days so the
            // player can work it at their own pace.
            events.append(contentsOf: NetworkingSystem.startEvent(
                state: &state, balance: balance, content: content
            ))
            FounderSystem.practice(.conversation, multiplier: 2, state: &state, balance: balance)
        case .familyTime:
            // Iteration 9 — L3: a weekend at home is worth a little to
            // every child. No-op in a childless house.
            ChildhoodSystem.familyWeekend(&state, balance: balance)
        // MARK: Iteration 9 — L4 (friends)
        case .friends:
            // The weekend goes to whoever the founder has seen least, and
            // the other two hear about it. No company effect: this is the
            // founder's own Saturday.
            FriendSystem.spendWeekend(&state, content)
        // MARK: end of Iteration 9 — L4
        case .rest, .gym, .dateNight, .hobby, .spa:
            break
        }
        return events
    }

    /// A weekend spent on the founder's own health counts toward clearing
    /// a chronic condition; anything else breaks the streak. Seeing people
    /// also breaks a loneliness run outright.
    private static func applyWeekendRecovery(
        _ activity: WeekendActivity,
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) -> [GameEvent] {
        switch activity {
        case .friends, .networking, .dateNight, .familyTime:
            state.economy.lonelySinceDay = nil
        default:
            break
        }

        guard state.economy.chronicCondition else { return [] }
        switch activity {
        case .gym, .spa, .doctor:
            state.economy.recoveryWeeks += 1
        default:
            state.economy.recoveryWeeks = 0
        }
        guard state.economy.recoveryWeeks >= balance.economy.chronicCureWeeks else { return [] }
        state.economy.chronicCondition = false
        state.economy.recoveryWeeks = 0
        return [.chronicConditionCleared(day: state.day)]
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
    ///
    /// Refuses `.crunch` while the founder is signed off after a hospital
    /// stay: they are physically unable to, and a player (or a bot) that
    /// re-issues the order every day would otherwise walk straight back
    /// into the loop that hospitalised them.
    static func setWorkSchedule(_ schedule: WorkSchedule, state: inout GameState) -> [GameEvent] {
        if schedule == .crunch, isConvalescing(state) { return [] }
        state.life.schedule = schedule
        return []
    }

    /// Whether the founder is still signed off after a hospital stay.
    public static func isConvalescing(_ state: GameState) -> Bool {
        state.economy.convalescingUntilDay.map { state.day < $0 } ?? false
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
        let affection = state.life.family.affection
        let daysAtStage = state.day - state.life.family.stageSinceDay

        switch state.life.family.stage {
        case .single:
            guard relationships >= config.datingMinRelationships else { return [] }
            state.life.family.partnerName = pick(content.names.partnerNames, &state.rng)
            state.life.family.partnerAppearanceSeed = state.rng.next()
            state.life.family.partnerContactID = nil
            state.life.family.affection = balance.relationships.startingAffection
            state.life.family.lastPartnerDay = state.day
            state.life.family.partnerCooldowns = [:]
            state.life.family.stage = .dating
        case .dating:
            guard relationships >= config.partnerMinRelationships,
                  daysAtStage >= config.partnerMinDaysAtStage,
                  affection >= balance.relationships.minAffection(for: .partner)
            else { return [] }
            state.life.family.stage = .partner
        case .partner:
            guard relationships >= config.marriedMinRelationships,
                  daysAtStage >= config.marriedMinDaysAtStage,
                  affection >= balance.relationships.minAffection(for: .married),
                  state.life.wallet >= config.weddingCost
            else { return [] }
            state.life.wallet -= config.weddingCost
            state.life.family.stage = .married
        case .married:
            return []
        }

        state.life.family.stageSinceDay = state.day
        // WS-E: a year from today is an anniversary.
        FamilyCalendar.stageChanged(&state, balance: balance, content: content)
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
        let child = Child(id: id, name: name, bornDay: state.day, appearanceSeed: seed)
        state.life.family.children.append(child)
        state.life.family.lastChildDay = state.day
        state.life.meters.apply(mood: config.childMoodBonus)
        // WS-E: their first birthday goes in the diary.
        FamilyCalendar.childBorn(child, &state, balance: balance, content: content)
        // Iteration 9 — L3: the thread starts the day they do. Bookkeeping
        // only; no meter moves because of the phone.
        state.life.phone.post(
            "\(name) was born today. Someone will be reading this back to them in a few years.",
            from: .child(child.id), day: state.day
        )
        return [.childBorn(name: name, day: state.day)]
    }

    /// Does an instant activity right now: applies the meter deltas and
    /// debits the wallet. Gated on the shared per-day cap, the week's
    /// evening budget, the activity's cooldown, the wallet, and the founder
    /// being around. Zero RNG.
    static func doInstantActivity(
        _ activity: InstantActivity,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        let instant = balance.instantLife
        guard let def = instant.activity(activity),
              state.life.instantActionsToday < instant.maxPerDay,
              state.hasEveningFree(balance),
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
        state.spendEvening(balance)
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
        // MARK: Iteration 9 — L7 (furnish)
        // A thing you just bought does not live in a box: if the home has
        // an empty slot it fits, it goes straight in. Cosmetic only.
        if let slot = HomeDecor.firstEmptySlot(for: itemID, tier: state.life.home, decor: state.life.decor) {
            HomeDecor.place(itemID: itemID, slot: slot, tier: state.life.home, decor: &state.life.decor)
        }
        // MARK: end of Iteration 9 — L7
        return [.itemPurchased(itemID: itemID, day: state.day)]
    }

    private static func pick(_ pool: [String], _ rng: inout SeededRNG) -> String {
        guard !pool.isEmpty else { return "" }
        return pool[rng.nextInt(in: 0...(pool.count - 1))]
    }
}
