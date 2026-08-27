import Foundation

/// The hiring-desk actions that sit alongside `EmployeeSystem.hire`:
/// interviewing a candidate, and passing on one.
///
/// A CV tells you what someone is good at; it doesn't tell you they are a
/// flight risk. An interview costs the founder a chunk of the day's energy
/// and reveals the trait the candidate wasn't advertising. Passing clears
/// the slot so the pool isn't a wall of people you've already decided
/// against.
///
/// Draws nothing: both actions are deterministic.
enum HiringSystem {
    /// Spends a day of founder time on a candidate. Ignored for unknown
    /// ids, for someone already interviewed, and while the founder is away.
    /// One interview per day — the founder has a company to run.
    static func interview(
        candidateID: UUID,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard state.candidatePool.contains(where: { $0.id == candidateID }),
              !state.progression.interviewedCandidateIDs.contains(candidateID),
              !state.life.isAway(day: state.day),
              state.progression.lastInterviewDay != state.day
        else { return [] }

        state.progression.interviewedCandidateIDs.insert(candidateID)
        state.progression.lastInterviewDay = state.day
        state.life.meters.apply(energy: -balance.traits.interviewEnergyCost)
        return [.candidateInterviewed(candidateID: candidateID, day: state.day)]
    }

    /// Takes a candidate out of the pool without hiring them. Their
    /// interview record goes with them, so the id set can't grow forever.
    static func pass(candidateID: UUID, state: inout GameState) -> [GameEvent] {
        guard let index = state.candidatePool.firstIndex(where: { $0.id == candidateID })
        else { return [] }
        state.candidatePool.remove(at: index)
        state.progression.interviewedCandidateIDs.remove(candidateID)
        return []
    }
}
