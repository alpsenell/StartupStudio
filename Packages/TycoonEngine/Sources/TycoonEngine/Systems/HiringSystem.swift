import Foundation
import TycoonContent

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

    // MARK: Iteration 11 — N1 (crime and the courtroom: the NDA poach)

    /// Mints the engineer the founder induced out of a rival's
    /// non-compete, and puts them at the top of the candidate pool.
    ///
    /// Rivals have no named staff in this engine — a rival is a strength
    /// score and a shelf — so "poaching their senior engineer" is modelled
    /// where a hire actually happens: a candidate appears on the hiring
    /// desk who is better than anything the pool would have rolled, and
    /// who should not be there. On a refusal nobody is minted and only the
    /// name comes back, so the offence still cost the fee and the
    /// notoriety and bought nothing.
    ///
    /// Draws: two names and an appearance seed from `socialRNG`, always,
    /// so the stream advances by the same amount whether they said yes or
    /// no. Never `rng` — the pool refresh owns that stream and a poach
    /// must not shift it.
    static func crimeMintPoachedCandidate(
        from rival: Rival?,
        landed: Bool,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> String {
        let firstNames = content.names.firstNames
        let lastNames = content.names.lastNames
        let first = firstNames.isEmpty
            ? "Alex"
            : firstNames[state.socialRNG.nextInt(in: 0...(firstNames.count - 1))]
        let last = lastNames.isEmpty
            ? "Okafor"
            : lastNames[state.socialRNG.nextInt(in: 0...(lastNames.count - 1))]
        let seed = state.socialRNG.next()
        let name = "\(first) \(last)"
        guard landed else { return name }

        // A senior from a real studio: better than the best CV currently
        // on the desk, by the balance's margin.
        let poolBest = (state.candidatePool.map(\.skills.total).max() ?? 180) / 3
        let base = min(100.0, poolBest + balance.crime.ndaPoachSkillBonus)
        let skills = SkillSet(
            coding: min(100, base + 8),
            design: min(100, base),
            marketing: min(100, max(5, base - 12))
        )
        let salary = Int((Double(balance.salaryBase)
            + balance.salaryPerSkillPoint * skills.total * 1.15).rounded())
        state.candidatePool.insert(
            Candidate(
                id: UUID(from: &state.socialRNG),
                name: name,
                skills: skills,
                weeklySalary: salary,
                appearanceSeed: seed,
                role: .backend
            ),
            at: 0
        )
        if let rival {
            state.life.phone.post(
                "\(name) starts Monday. Nobody is to mention \(rival.name).",
                from: .office, day: state.day
            )
        }
        return name
    }

    // MARK: end of Iteration 11 — N1

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
