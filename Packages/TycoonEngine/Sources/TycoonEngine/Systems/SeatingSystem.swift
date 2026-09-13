import Foundation
import TycoonContent

// MARK: S1 (seating)

/// Iteration 16 — S1. What the neighbours do, every day and every week,
/// once the player has seated somebody (`Company.seating` non-empty).
///
/// - Every day: a grumbler's two neighbours lose
///   `seating.grumblerMoraleDelta` morale, applied to morale itself the way
///   `TraitSystem`'s room mood is, so it shows the same day.
/// - Every week (day % 7 == 0): a mentor teaches each weaker neighbour
///   (`GameState.seatingWeeklyLesson`); two neighbours with a bond of 60 or
///   more gain `friendBondGain`; whoever sits behind the founder gains
///   `founderBondGain` of founder bond while the founder is in; and the
///   plan forgets anybody who has left.
///
/// The mentor's output cost lives where output is made
/// (`EmployeeSystem.gatherCrewOutput`), the door desk in the poach list
/// (`RivalSystem.poachTarget`), and the romance and clique in
/// `OfficeSecretsSystem`. Nothing here draws a random number, and the whole
/// system returns at its first line while the plan is empty.
enum SeatingSystem {
    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        guard state.seatingIsSet, state.gameOver == nil else { return [] }
        let effects = state.seatingEffects(balance: balance)
        grumble(effects, &state, balance)
        if state.day % GameState.daysPerWeek == 0 {
            teach(effects, &state, balance)
            bond(effects, &state, balance)
            forgetLeavers(&state)
        }
        return []
    }

    // MARK: - Daily

    private static func grumble(
        _ effects: Set<SeatingEffect>, _ state: inout GameState, _ balance: BalanceConfig
    ) {
        let delta = balance.seating.grumblerMoraleDelta
        guard delta != 0 else { return }
        var hits: [UUID: Int] = [:]
        for case let .grumble(_, neighbourID) in effects { hits[neighbourID, default: 0] += 1 }
        for index in state.employees.indices where !state.employees[index].isFounder {
            guard let count = hits[state.employees[index].id] else { continue }
            let morale = state.employees[index].morale + delta * Double(count)
            state.employees[index].morale = min(100, max(0, morale))
        }
    }

    // MARK: - Weekly

    /// Every lesson is read off the week's opening skills, so two mentors
    /// on either side of one student each teach from where the student
    /// started the week.
    private static func teach(
        _ effects: Set<SeatingEffect>, _ state: inout GameState, _ balance: BalanceConfig
    ) {
        let before = state
        let lessons = effects.compactMap { effect -> (UUID, UUID, TrainableSkill)? in
            if case let .lesson(mentor, student, skill) = effect { return (mentor, student, skill) }
            return nil
        }.sorted { ($0.0.uuidString, $0.1.uuidString) < ($1.0.uuidString, $1.1.uuidString) }
        for (mentorID, studentID, skill) in lessons {
            guard let mentor = before.employee(id: mentorID),
                  let student = before.employee(id: studentID),
                  let index = state.employees.firstIndex(where: { $0.id == studentID })
            else { continue }
            let gain = GameState.seatingWeeklyLesson(mentor: mentor, student: student, balance: balance)
            let ceiling = GameState.seatingSkill(skill, of: mentor)
            switch skill {
            case .coding:
                state.employees[index].skills.coding = min(ceiling, max(state.employees[index].skills.coding, state.employees[index].skills.coding + gain))
            case .design:
                state.employees[index].skills.design = min(ceiling, max(state.employees[index].skills.design, state.employees[index].skills.design + gain))
            case .marketing:
                state.employees[index].skills.marketing = min(ceiling, max(state.employees[index].skills.marketing, state.employees[index].skills.marketing + gain))
            }
            // MARK: T3 (people)
            // J5: the lesson that carries a student past their rung's bar
            // is the one that makes them ask for the title. No draw.
            if GameState.lessonCrossesRung(before: student, after: state.employees[index]) {
                SocialSystem.lessonAsksForPromotion(studentID, state: &state)
            }
            // MARK: end T3
        }
    }

    private static func bond(
        _ effects: Set<SeatingEffect>, _ state: inout GameState, _ balance: BalanceConfig
    ) {
        let config = balance.seating
        for effect in effects {
            switch effect {
            case let .friends(a, b):
                guard let index = state.friendships.firstIndex(where: { $0.involves(a) && $0.involves(b) })
                else { continue }
                state.friendships[index].strength = min(100, state.friendships[index].strength + config.friendBondGain)
            case let .founderNeighbour(id):
                guard !state.life.isAway(day: state.day),
                      let index = state.employees.firstIndex(where: { $0.id == id })
                else { continue }
                state.employees[index].founderBond = min(100, state.employees[index].founderBond + config.founderBondGain)
            case .lesson, .grumble, .door:
                continue
            }
        }
    }

    /// Drops the seats of people who have left, so the save does not carry
    /// the dead. A plan that empties this way is no plan: the room goes
    /// back to its own rule, which is where everybody already sits.
    private static func forgetLeavers(_ state: inout GameState) {
        let onStaff = Set(state.employees.filter { !$0.isFounder }.map(\.id))
        state.company.seating = state.company.seating.filter { onStaff.contains($0.key) }
    }

    // MARK: - The actions

    /// `.seatingMove`: the whole room as it sits today becomes the plan,
    /// with the mover at `desk` and whoever sat there at the mover's old
    /// desk.
    static func move(employeeID: UUID, desk: Int, state: inout GameState) -> [GameEvent] {
        guard state.seatingMoveBlocker(employeeID: employeeID, desk: desk) == nil else { return [] }
        let move = state.seatingPlanAfterMove(employeeID: employeeID, desk: desk)
        state.company.seating = move.plan
        return [.seatingMoved(employeeID: employeeID, desk: desk, swappedWithID: move.swapWithID, day: state.day)]
    }

    /// `.seatingClear`: no plan; the office seats people by its own rule
    /// and nobody's neighbours matter.
    static func clear(state: inout GameState) -> [GameEvent] {
        guard state.seatingIsSet, state.gameOver == nil else { return [] }
        state.company.seating = [:]
        return [.seatingCleared(day: state.day)]
    }
}

// MARK: end S1
