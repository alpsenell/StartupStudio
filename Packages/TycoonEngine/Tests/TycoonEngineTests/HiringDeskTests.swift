import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

/// The hiring desk actions that sit next to `EmployeeSystem.hire`:
/// interviewing a candidate to learn the trait their CV left out, and
/// passing on one.
@Suite("Hiring desk")
struct HiringDeskTests {
    private static let content = TestContent.bundled

    private static func balance() throws -> BalanceConfig {
        try BalanceConfig.loadBundled()
    }

    /// A game with a full candidate pool, day 14 (the first refresh).
    private static func stateWithPool(seed: UInt64 = 61, balance: BalanceConfig) -> GameState {
        var state = GameState.newGame(companyName: "Acme", seed: seed, balance: balance)
        while state.candidatePool.isEmpty, state.day < 60 {
            Reducer.tick(&state, balance: balance, content: Self.content)
        }
        return state
    }

    @Test func interviewingRevealsTheCandidateAndCostsTheFounderEnergy() throws {
        let balance = try Self.balance()
        var state = Self.stateWithPool(balance: balance)
        let candidate = try #require(state.candidatePool.first)
        let energyBefore = state.life.meters.energy

        let events = Reducer.apply(
            .interviewCandidate(candidateID: candidate.id),
            to: &state, balance: balance, content: Self.content
        )
        #expect(state.progression.interviewedCandidateIDs.contains(candidate.id))
        #expect(state.life.meters.energy < energyBefore)
        #expect(events.contains { event in
            if case .candidateInterviewed(let id, _) = event { return id == candidate.id }
            return false
        })
    }

    /// One a day — the founder has a company to run.
    @Test func onlyOneInterviewPerDay() throws {
        let balance = try Self.balance()
        var state = Self.stateWithPool(balance: balance)
        try #require(state.candidatePool.count >= 2)
        let first = state.candidatePool[0]
        let second = state.candidatePool[1]

        Reducer.apply(
            .interviewCandidate(candidateID: first.id),
            to: &state, balance: balance, content: Self.content
        )
        let events = Reducer.apply(
            .interviewCandidate(candidateID: second.id),
            to: &state, balance: balance, content: Self.content
        )
        #expect(events.isEmpty)
        #expect(!state.progression.interviewedCandidateIDs.contains(second.id))

        // Tomorrow is fine.
        Reducer.tick(&state, balance: balance, content: Self.content)
        Reducer.apply(
            .interviewCandidate(candidateID: second.id),
            to: &state, balance: balance, content: Self.content
        )
        #expect(state.progression.interviewedCandidateIDs.contains(second.id))
    }

    /// Interviewing the same person twice is free and does nothing.
    @Test func interviewingTwiceIsIgnored() throws {
        let balance = try Self.balance()
        var state = Self.stateWithPool(balance: balance)
        let candidate = try #require(state.candidatePool.first)
        Reducer.apply(
            .interviewCandidate(candidateID: candidate.id),
            to: &state, balance: balance, content: Self.content
        )
        Reducer.tick(&state, balance: balance, content: Self.content)
        let energyBefore = state.life.meters.energy
        let events = Reducer.apply(
            .interviewCandidate(candidateID: candidate.id),
            to: &state, balance: balance, content: Self.content
        )
        #expect(events.isEmpty)
        #expect(state.life.meters.energy == energyBefore)
    }

    /// An away founder interviews nobody.
    @Test func anAwayFounderCannotInterview() throws {
        let balance = try Self.balance()
        var state = Self.stateWithPool(balance: balance)
        let candidate = try #require(state.candidatePool.first)
        state.life.awayUntilDay = state.day + 5
        state.life.awayReason = "Hospital"

        let events = Reducer.apply(
            .interviewCandidate(candidateID: candidate.id),
            to: &state, balance: balance, content: Self.content
        )
        #expect(events.isEmpty)
        #expect(state.progression.interviewedCandidateIDs.isEmpty)
    }

    /// Passing clears the slot, and takes the interview record with it so
    /// the id set can't grow forever.
    @Test func passingRemovesThemAndTheirInterviewRecord() throws {
        let balance = try Self.balance()
        var state = Self.stateWithPool(balance: balance)
        let candidate = try #require(state.candidatePool.first)
        Reducer.apply(
            .interviewCandidate(candidateID: candidate.id),
            to: &state, balance: balance, content: Self.content
        )
        let poolBefore = state.candidatePool.count

        Reducer.apply(
            .passOnCandidate(candidateID: candidate.id),
            to: &state, balance: balance, content: Self.content
        )
        #expect(state.candidatePool.count == poolBefore - 1)
        #expect(!state.candidatePool.contains { $0.id == candidate.id })
        #expect(!state.progression.interviewedCandidateIDs.contains(candidate.id))
    }

    /// An unknown id is ignored rather than crashing or half-applying.
    @Test func unknownCandidatesAreIgnored() throws {
        let balance = try Self.balance()
        var state = Self.stateWithPool(balance: balance)
        let before = state
        Reducer.apply(
            .interviewCandidate(candidateID: UUID()),
            to: &state, balance: balance, content: Self.content
        )
        Reducer.apply(
            .passOnCandidate(candidateID: UUID()),
            to: &state, balance: balance, content: Self.content
        )
        #expect(state.candidatePool == before.candidatePool)
        #expect(state.progression.interviewedCandidateIDs.isEmpty)
    }

    /// The hire keeps exactly the traits the sheet promised.
    @Test func theHireHasTheTraitsTheSheetShowed() throws {
        let balance = try Self.balance()
        var state = Self.stateWithPool(balance: balance)
        let candidate = try #require(state.candidatePool.first)
        let promised = candidate.traits

        Reducer.apply(
            .hire(candidateID: candidate.id),
            to: &state, balance: balance, content: Self.content
        )
        let hired = try #require(state.employees.first { $0.id == candidate.id })
        #expect(hired.traits == promised)
        #expect(hired.traits.count == TraitEffects.traitsPerEmployee)
    }
}
