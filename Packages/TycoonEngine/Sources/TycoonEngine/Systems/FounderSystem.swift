import Foundation

/// The founder's own attributes: training them deliberately, and picking
/// them up by doing the work.
///
/// Training is a life action, not a daily system — it hosts no `run`. The
/// per-day counter it uses is reset by `LifeSystem` alongside the instant
/// activity cap, so the two caps clear on exactly the same tick.
///
/// Draws nothing: every gain here is deterministic.
enum FounderSystem {
    /// Spends the founder's day (and, above self-study, their own money)
    /// getting better at one attribute.
    ///
    /// Gates, all mirrored by the Life tab so a disabled button can say
    /// why: the method has to exist in the balance, the founder has to be
    /// around, the day's training cap has to have room, the week has to
    /// have an evening left in it, the method's cooldown has to have run
    /// out, and the wallet has to cover it — self-study being free is
    /// always affordable, overdrawn or not.
    ///
    /// The gain runs through `FounderSkillSet.grow`, so the same course
    /// is worth a lot at 20 and almost nothing at 90.
    static func train(
        _ skill: FounderSkill,
        method: TrainingMethod,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        let config = balance.founder
        guard let def = config.training(method),
              !state.life.isAway(day: state.day),
              state.life.trainingsToday < config.maxTrainingsPerDay,
              state.hasEveningFree(balance),
              def.cost == 0 || state.life.wallet >= def.cost
        else { return [] }
        if let last = state.life.trainingCooldowns[method.rawValue],
           state.day - last < def.cooldownDays { return [] }

        let before = state.life.skills[skill]
        state.life.skills.grow(skill, by: def.gain)
        state.life.wallet -= def.cost
        state.life.meters.apply(energy: -def.energy, mood: def.mood)
        state.life.trainingCooldowns[method.rawValue] = state.day
        state.life.trainingsToday += 1
        state.spendEvening(balance)

        return [.founderTrained(
            skill: skill,
            method: method,
            gained: state.life.skills[skill] - before,
            day: state.day
        )]
    }

    /// A smaller, silent gain from having actually done the thing —
    /// pitching at a party teaches you to pitch. No event: the practice
    /// gain is deliberately quiet, and the attribute bar moving is the
    /// feedback.
    static func practice(
        _ skill: FounderSkill,
        multiplier: Double = 1,
        state: inout GameState,
        balance: BalanceConfig
    ) {
        let gain = balance.founder.practiceGain * multiplier
        guard gain > 0 else { return }
        state.life.skills.grow(skill, by: gain)
    }

    /// Why a training session would be refused, in the player's words, or
    /// `nil` when it would go ahead. The Life tab's disabled reasons come
    /// from here rather than being written out again in SwiftUI, so the
    /// button and the engine can never disagree about the rules.
    static func trainingBlocker(
        _ method: TrainingMethod,
        state: GameState,
        balance: BalanceConfig
    ) -> String? {
        let config = balance.founder
        guard let def = config.training(method) else { return "Not available" }
        if state.life.isAway(day: state.day) { return "You're away" }
        if state.life.trainingsToday >= config.maxTrainingsPerDay {
            return "That's enough studying for one day"
        }
        if let reason = state.eveningBlocker(balance) { return reason }
        if let last = state.life.trainingCooldowns[method.rawValue] {
            let left = def.cooldownDays - (state.day - last)
            if left > 0 { return "Again in \(left) day\(left == 1 ? "" : "s")" }
        }
        if def.cost > 0, state.life.wallet < def.cost {
            return "Need \(def.cost - state.life.wallet) more"
        }
        return nil
    }
}
