import Foundation
import TycoonContent

/// Daily progression system: the run's spine.
///
/// Every day it (1) refreshes the monotonic run counters no other state
/// records, (2) measures every goal in the chapters the player has reached,
/// (3) pays out and locks any that just finished, (4) opens the next
/// chapter once enough of the current one is done, and (5) rebuilds the
/// three goals the HQ card shows.
///
/// Completely deterministic — no RNG draws at all, from either stream — so
/// the same seed and the same actions always finish the same goals on the
/// same days. Runs near the end of the day, after every system that could
/// have moved a measurement.
enum ProgressionSystem {
    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        updateStats(&state, content)
        guard !content.goals.isEmpty else { return [] }

        var events = evaluateGoals(&state, balance, content)
        events.append(contentsOf: advanceChapter(&state, balance, content))
        refreshActiveGoals(&state, content)
        return events
    }

    // MARK: - Run counters

    /// Brings `ProgressionStats` up to date from what today's state can
    /// see. Every counter only ever grows, so a re-run on the same day is
    /// harmless.
    private static func updateStats(_ state: inout GameState, _ content: ContentCatalog) {
        var stats = state.progression.stats

        stats.peakHeadcount = max(stats.peakHeadcount, state.headcount)
        stats.departmentsEverFormed = max(
            stats.departmentsEverFormed,
            max(state.activeDepartments.count, state.knownDepartments.count)
        )

        // Contracts are counted by watching the open list change: it grows
        // when the player accepts one and shrinks when one is delivered or
        // failed. Comparing against yesterday's count (rather than reading
        // `acceptedDay`) catches an acceptance whenever it happened — the
        // player, and the bot harness, act between ticks, not during one.
        let open = state.activeContracts.count
        if open > stats.openContracts {
            stats.contractsAccepted += open - stats.openContracts
        } else if open < stats.openContracts {
            stats.contractsSettled += stats.openContracts - open
        }
        stats.openContracts = open

        // Weekly beats: LifeSystem resolves the weekend and FinanceSystem
        // settles the week on `day % 7 == 0`, both before this system runs.
        if state.day > 0, state.day.isMultiple(of: GameState.daysPerWeek) {
            if state.company.cash > 0 { stats.cashPositiveWeeks += 1 }
            if !state.life.isAway(day: state.day), state.life.plannedActivity != .rest {
                stats.weekendsOff += 1
            }
        }

        stats.crashesWeathered += state.market.recentEvents.count {
            $0.day == state.day && $0.kind == .crash
        }
        stats.campaignsRun = max(stats.campaignsRun, state.campaigns.count)

        for product in state.products {
            guard case .released(let info) = product.stage else { continue }
            stats.bestReviewScore = max(stats.bestReviewScore, info.averageReviewScore)
            let revenue = info.weeklySales.reduce(0) { $0 + $1.revenue }
            stats.bestProductRevenue = max(stats.bestProductRevenue, revenue)
        }

        stats.topicsDominated = max(stats.topicsDominated, state.rivals.dominatedTopicCount)
        stats.roundsRaised = max(stats.roundsRaised, state.investors.rounds.count)

        state.progression.stats = stats
    }

    // MARK: - Goal evaluation

    /// Measures every goal in a reached chapter and completes the ones that
    /// have arrived. A goal already in `completedGoalIDs` is skipped, so
    /// nothing can ever complete (or pay out) twice.
    private static func evaluateGoals(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        var events: [GameEvent] = []
        // Catalog order, so two goals finishing on the same day always
        // complete in the same order.
        for goal in content.goals where goal.chapter <= state.progression.chapter {
            let measured = measure(goal.condition, state: state, balance: balance, content: content)
            state.progression.goalProgress[goal.id] = measured.value
            guard !state.progression.completedGoalIDs.contains(goal.id),
                  measured.value >= measured.target
            else { continue }

            state.progression.completedGoalIDs.insert(goal.id)
            grant(goal.reward, to: &state, balance: balance)
            events.append(.goalCompleted(goalID: goal.id, day: state.day))
        }
        return events
    }

    /// Pays a goal's reward. Cash posts to the ledger so the finance screen
    /// can account for it; perks are permanent and never stack.
    private static func grant(
        _ reward: GoalDef.Reward?,
        to state: inout GameState,
        balance: BalanceConfig
    ) {
        guard let reward else { return }
        let config = balance.progression
        if let reputation = reward.reputation {
            state.company.reputation = min(
                100, max(0, state.company.reputation + reputation * config.rewardReputationScale)
            )
        }
        if let cash = reward.cash {
            let amount = Int((Double(cash) * config.rewardCashScale).rounded())
            state.company.cash += amount
            state.ledger.post(LedgerEntry(
                day: state.day, amount: amount, category: .other, label: "Milestone reward"
            ))
        }
        if let perk = reward.perk, ProgressionPerk(rawValue: perk) != nil {
            state.progression.perks.insert(perk)
        }
    }

    // MARK: - Chapters

    /// Opens the next chapter once `goalsToAdvanceChapter` of the current
    /// one are done — deliberately below the chapter's goal count, so one
    /// awkward goal can never wall the run off.
    private static func advanceChapter(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        var events: [GameEvent] = []
        let chapters = content.chapters.map(\.chapter)
        guard let highest = chapters.max() else { return events }

        while state.progression.chapter < highest {
            let current = content.goals(inChapter: state.progression.chapter)
            let done = current.count { state.progression.completedGoalIDs.contains($0.id) }
            let needed = min(current.count, max(1, balance.progression.goalsToAdvanceChapter))
            guard done >= needed else { break }

            state.progression.chapter += 1
            state.progression.chapterLog.append(
                ChapterEntry(chapter: state.progression.chapter, day: state.day)
            )
            events.append(.chapterReached(chapter: state.progression.chapter, day: state.day))
        }
        return events
    }

    /// Rebuilds the up-to-three goals the HQ card shows: the unfinished
    /// ones from the current chapter first (that is the thing to do next),
    /// then any left behind in earlier chapters, so nothing is ever
    /// silently abandoned.
    private static func refreshActiveGoals(_ state: inout GameState, _ content: ContentCatalog) {
        state.progression.chapterTitle = ChapterDef.title(for: state.progression.chapter)

        let completed = state.progression.completedGoalIDs
        let currentChapter = state.progression.chapter
        let open = content.goals
            .filter { $0.chapter <= currentChapter && !completed.contains($0.id) }
            .sorted { lhs, rhs in
                // Current chapter first; catalog order within a chapter is
                // already stable, so only the chapter key needs a rule.
                let lhsCurrent = lhs.chapter == currentChapter
                let rhsCurrent = rhs.chapter == currentChapter
                if lhsCurrent != rhsCurrent { return lhsCurrent }
                return lhs.chapter < rhs.chapter
            }
            .prefix(ProgressionState.activeGoalLimit)

        state.progression.activeGoals = open.map { goal in
            let value = state.progression.goalProgress[goal.id] ?? 0
            let target = max(1, goal.condition.amount)
            return GoalProgress(
                id: goal.id,
                title: goal.title,
                detail: goal.detail ?? "",
                progress: min(value, target),
                target: target,
                chapter: goal.chapter
            )
        }
    }

    // MARK: - Measurement

    /// What a condition currently reads, and what it has to reach. Pure:
    /// no state is written, nothing is drawn.
    static func measure(
        _ condition: GoalDef.Condition,
        state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> (value: Double, target: Double) {
        let stats = state.progression.stats
        let target = max(1, condition.amount)

        switch condition.kind {
        case .productsStarted:
            return (Double(state.products.count), target)
        case .productsShipped:
            return (Double(state.products.count { if case .released = $0.stage { true } else { false } }), target)
        case .bestReviewScore:
            return (Double(stats.bestReviewScore), target)
        case .peakHeadcount:
            return (Double(stats.peakHeadcount), target)
        case .officeTierReached:
            return (reachedTier(condition.text, state: state) ? 1 : 0, 1)
        case .homeTierReached:
            return (reachedHome(condition.text, state: state) ? 1 : 0, 1)
        case .contractsAccepted:
            return (Double(stats.contractsAccepted), target)
        case .contractsSettled:
            return (Double(stats.contractsSettled), target)
        case .cashPositiveWeeks:
            return (Double(stats.cashPositiveWeeks), target)
        case .cashOnHand:
            return (Double(max(0, state.company.cash)), target)
        case .reputation:
            return (state.company.reputation, target)
        case .techsResearched:
            return (Double(state.research.unlocked.count), target)
        case .techTierResearched:
            let best = state.research.unlocked
                .compactMap { content.tech($0)?.tier }
                .max() ?? 0
            return (Double(best), target)
        case .weekendsOff:
            return (Double(stats.weekendsOff), target)
        case .relationshipReached:
            return (reachedRelationship(condition.text, state: state) ? 1 : 0, 1)
        case .children:
            return (Double(state.life.family.children.count), target)
        case .departmentsFormed:
            return (Double(stats.departmentsEverFormed), target)
        case .amenitiesBuilt:
            return (Double(state.amenities.count), target)
        case .campaignsRun:
            return (Double(stats.campaignsRun), target)
        case .crashesWeathered:
            return (Double(stats.crashesWeathered), target)
        case .bestProductRevenue:
            return (Double(stats.bestProductRevenue), target)
        case .topicsDominated:
            return (Double(stats.topicsDominated), target)
        case .rivalsAcquired:
            return (Double(stats.rivalsAcquired), target)
        case .roundsRaised:
            return (Double(stats.roundsRaised), target)
        case .founderNetWorth:
            return (Double(max(0, state.founderNetWorth(balance: balance))), target)
        case .companyValuation:
            return (Double(state.companyValuation(balance: balance)), target)
        case .readyToGoPublic:
            return (state.canFileIPO(balance: balance) ? 1 : 0, 1)
        }
    }

    /// Office tiers are a ladder, and `milestonesReached` records every rung
    /// the company ever stood on — so downgrading (there is no downgrade
    /// today, but a future one shouldn't un-complete a goal) can't undo it.
    private static func reachedTier(_ raw: String?, state: GameState) -> Bool {
        guard let raw, let wanted = OfficeTier(rawValue: raw) else { return false }
        if state.milestonesReached.contains(raw) { return true }
        return OfficeTier.allCases.firstIndex(of: state.company.officeTier).map { current in
            OfficeTier.allCases.firstIndex(of: wanted).map { current >= $0 } ?? false
        } ?? false
    }

    private static func reachedHome(_ raw: String?, state: GameState) -> Bool {
        guard let raw, let wanted = HomeTier(rawValue: raw),
              let current = HomeTier.allCases.firstIndex(of: state.life.home),
              let target = HomeTier.allCases.firstIndex(of: wanted)
        else { return false }
        return current >= target
    }

    /// "Go on a date" stays done after a breakup — it happened.
    private static func reachedRelationship(_ raw: String?, state: GameState) -> Bool {
        guard let raw, let wanted = RelationshipStage(rawValue: raw),
              let current = RelationshipStage.allCases.firstIndex(of: state.life.family.stage),
              let target = RelationshipStage.allCases.firstIndex(of: wanted)
        else { return false }
        return current >= target
    }
}
