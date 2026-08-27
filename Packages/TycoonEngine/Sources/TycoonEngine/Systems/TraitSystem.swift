import Foundation
import TycoonContent

/// Daily trait system: the half of `TraitEffects` that needs the whole
/// roster rather than one person.
///
/// `EmployeeSystem` already applies the per-employee hooks (output, own
/// skill growth, morale target, quit patience) and `RivalSystem` the poach
/// resistance. What is left is what people do *to each other* — a mentor
/// teaching, a jokester lifting the room, a grumbler draining it, a showman
/// getting the company's name into print — and none of that can be computed
/// from a single `Employee`.
///
/// Draws no randomness at all: everything here is a deterministic function
/// of today's roster, so the same seed and the same actions replay
/// identically. Runs after `EmployeeSystem`'s own sweep (it is appended to
/// the system list, which runs last) so it works on the post-sweep team.
enum TraitSystem {
    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        guard !content.traits.isEmpty else { return [] }
        let config = balance.traits

        applyMentoring(&state, config, content)
        applyRoomMood(&state, config, content)
        applyPress(&state, config, content)
        return []
    }

    // MARK: - Mentoring

    /// Every mentor on payroll lifts *everyone else's* skills a little each
    /// day — the same growth the day's work would have earned, again. The
    /// bonus is summed across mentors, scaled and capped, and applied only
    /// to people who are not themselves the mentor.
    private static func applyMentoring(
        _ state: inout GameState,
        _ config: BalanceConfig.TraitBalance,
        _ content: ContentCatalog
    ) {
        var mentorBonus: [UUID: Double] = [:]
        var total = 0.0
        for employee in state.employees {
            let bonus = TraitEffects.rawTeamGrowthBonus(employee, content: content)
            guard bonus != 0 else { continue }
            mentorBonus[employee.id] = bonus
            total += bonus
        }
        guard total > 0 else { return }

        for index in state.employees.indices {
            // A mentor doesn't teach themselves.
            let share = total - (mentorBonus[state.employees[index].id] ?? 0)
            guard share > 0 else { continue }
            let rate = min(config.teamGrowthLimit, share * config.teamGrowthStrength)
                * balanceGrowthRate(state.employees[index])
            grow(&state.employees[index].skills.coding, by: rate)
            grow(&state.employees[index].skills.design, by: rate)
        }
    }

    /// The daily skill step a mentor is worth, before the team bonus
    /// scales it: a flat fraction of a point, tapering as the student
    /// approaches the ceiling so mentoring can't push anyone to 100.
    private static func balanceGrowthRate(_ employee: Employee) -> Double {
        employee.isFounder ? 0.02 : 0.03
    }

    private static func grow(_ skill: inout Double, by rate: Double) {
        guard rate > 0 else { return }
        skill = min(100, skill + rate * (100 - skill) / 100)
    }

    // MARK: - The mood of the room

    /// Jokesters lift everyone's morale a little every day; grumblers pull
    /// it down. Applied to the settled morale directly (not the target), so
    /// it shows up the same day and the balance's adaptation rate still
    /// governs everything else.
    private static func applyRoomMood(
        _ state: inout GameState,
        _ config: BalanceConfig.TraitBalance,
        _ content: ContentCatalog
    ) {
        var contribution: [UUID: Double] = [:]
        var total = 0.0
        for employee in state.employees where !employee.isFounder {
            let bonus = TraitEffects.rawTeamMoraleBonus(employee, content: content)
            guard bonus != 0 else { continue }
            contribution[employee.id] = bonus
            total += bonus
        }
        guard total != 0 else { return }

        for index in state.employees.indices where !state.employees[index].isFounder {
            // Nobody laughs at their own jokes, or annoys themselves.
            let share = total - (contribution[state.employees[index].id] ?? 0)
            guard share != 0 else { continue }
            let nudge = min(config.teamMoraleLimit, max(-config.teamMoraleLimit, share))
            state.employees[index].morale = min(100, max(0, state.employees[index].morale + nudge))
        }
    }

    // MARK: - Press

    /// Showmen keep the company's name in circulation — a small daily
    /// reputation trickle that stops once the company is already known.
    private static func applyPress(
        _ state: inout GameState,
        _ config: BalanceConfig.TraitBalance,
        _ content: ContentCatalog
    ) {
        guard state.company.reputation < config.reputationBonusCeiling else { return }
        let raw = state.employees.reduce(0.0) { sum, employee in
            sum + TraitEffects.rawReputationBonus(employee, content: content)
        }
        guard raw > 0 else { return }
        let gain = min(config.reputationBonusCap, raw)
        state.company.reputation = min(
            config.reputationBonusCeiling, state.company.reputation + gain
        )
    }
}
