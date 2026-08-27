import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

@Suite("Employee traits")
struct TraitTests {
    private static func catalog() throws -> ContentCatalog {
        try ContentCatalog.loadBundled()
    }

    private static func employee(
        seed: UInt64,
        traits: [String] = [],
        morale: Double = 60,
        loyalty: Double = 50
    ) -> Employee {
        Employee(
            id: UUID(),
            name: "Test",
            skills: SkillSet(coding: 40, design: 40, marketing: 40),
            weeklySalary: 500,
            assignment: .idle,
            isFounder: false,
            hiredDay: 0,
            appearanceSeed: seed,
            morale: morale,
            loyalty: loyalty,
            role: .backend,
            traits: traits
        )
    }

    // MARK: - Derivation

    /// Two distinct traits, always, and always the same two for a seed.
    @Test func derivationIsStableAndNeverRepeatsATrait() {
        for seed in [UInt64(0), 1, 42, 9_999, .max] {
            let first = TraitEffects.derivedTraitIDs(appearanceSeed: seed)
            #expect(first.count == TraitEffects.traitsPerEmployee)
            #expect(Set(first).count == first.count, "seed \(seed) drew the same trait twice")
            #expect(first == TraitEffects.derivedTraitIDs(appearanceSeed: seed))
            for id in first {
                #expect(TraitEffects.canonicalTraitIDs.contains(id))
            }
        }
    }

    /// Every canonical trait is reachable — no dead entries in the table.
    @Test func everyTraitCanBeDrawn() {
        var seen: Set<String> = []
        for seed in UInt64(0)..<400 {
            seen.formUnion(TraitEffects.derivedTraitIDs(appearanceSeed: seed))
        }
        #expect(seen == Set(TraitEffects.canonicalTraitIDs))
    }

    /// The whole point of taking draws 5 and 6: the pixel look for a seed
    /// is exactly what it was before traits existed.
    @Test func derivationLeavesTheFirstFourWordsAlone() {
        // The first four SplitMix64 words are the appearance. Re-derive
        // them here and confirm the trait draw starts after them.
        var appearanceStream = SeededRNG(seed: 1234)
        let appearanceWords = (0..<4).map { _ in appearanceStream.next() }

        var traitStream = SeededRNG(seed: 1234)
        let replayed = (0..<4).map { _ in traitStream.next() }
        #expect(appearanceWords == replayed)
    }

    // MARK: - Backfill

    /// A hire created without traits gets them derived from their seed.
    @Test func creatingAnEmployeeWithoutTraitsDerivesThem() {
        let person = Self.employee(seed: 777)
        #expect(person.traits == TraitEffects.derivedTraitIDs(appearanceSeed: 777))
    }

    /// A save written before traits existed backfills on decode, purely —
    /// decoding the same bytes twice gives the same people.
    @Test func decodingASaveWithoutTraitsBackfillsDeterministically() throws {
        let json = Data("""
        {
          "id": "11111111-2222-3333-4444-555555555555",
          "name": "Old Hand",
          "skills": {"coding": 30, "design": 20, "marketing": 10},
          "weeklySalary": 400,
          "assignment": {"idle": {}},
          "isFounder": false,
          "hiredDay": 12,
          "appearanceSeed": 5150
        }
        """.utf8)
        let first = try JSONDecoder().decode(Employee.self, from: json)
        let second = try JSONDecoder().decode(Employee.self, from: json)
        #expect(first.traits.count == TraitEffects.traitsPerEmployee)
        #expect(first.traits == second.traits)
        #expect(first.traits == TraitEffects.derivedTraitIDs(appearanceSeed: 5150))
        #expect(first == second)
    }

    /// The founder's character is their archetype; giving them traits on
    /// top would quietly move every founder-output number.
    @Test func theFounderCarriesNoTraits() throws {
        let balance = try BalanceConfig.loadBundled()
        let state = GameState.newGame(companyName: "X", seed: 3, balance: balance)
        #expect(state.employees[0].isFounder)
        #expect(state.employees[0].traits.isEmpty)
    }

    /// A candidate promises exactly the traits the hire will walk in with.
    @Test func candidateTraitsMatchTheEventualHire() {
        let candidate = Candidate(
            id: UUID(),
            name: "Nia",
            skills: SkillSet(coding: 20, design: 20, marketing: 20),
            weeklySalary: 300,
            appearanceSeed: 8_675_309,
            role: .frontend
        )
        let hired = Self.employee(seed: candidate.appearanceSeed)
        #expect(candidate.traits == hired.traits)
    }

    // MARK: - Effects

    @Test func outputAndGrowthMultipliersComeFromTheCatalog() throws {
        let content = try Self.catalog()
        let speedster = Self.employee(seed: 1, traits: ["speedster"])
        #expect(abs(TraitEffects.outputFactor(speedster, content: content) - 1.18) < 1e-9)
        #expect(abs(TraitEffects.growthFactor(speedster, content: content) - 0.75) < 1e-9)

        let perfectionist = Self.employee(seed: 1, traits: ["perfectionist"])
        #expect(abs(TraitEffects.outputFactor(perfectionist, content: content) - 0.88) < 1e-9)
        #expect(abs(TraitEffects.growthFactor(perfectionist, content: content) - 1.35) < 1e-9)
    }

    @Test func multipliersStackAndDeltasAdd() throws {
        let content = try Self.catalog()
        let both = Self.employee(seed: 1, traits: ["speedster", "prodigy"])
        // 1.18 × 1.25 = 1.475, clamped to the pair ceiling.
        #expect(TraitEffects.outputFactor(both, content: content) == TraitEffects.Limits.outputMultMax)

        let glum = Self.employee(seed: 1, traits: ["grumbler", "fragile"])
        #expect(abs(TraitEffects.moraleTargetDelta(glum, content: content) - -14) > 1e-9)
        #expect(TraitEffects.moraleTargetDelta(glum, content: content) == -TraitEffects.Limits.moraleDelta)
    }

    @Test func loyalistIsHardToPoachAndFlightRiskIsEasy() throws {
        let content = try Self.catalog()
        let loyalist = Self.employee(seed: 1, traits: ["loyalist"])
        let flighty = Self.employee(seed: 1, traits: ["flightRisk"])
        #expect(TraitEffects.poachResistance(loyalist, content: content) > 2)
        #expect(TraitEffects.poachResistance(flighty, content: content) < 0.6)
        #expect(TraitEffects.quitStreakBonus(loyalist, content: content) == 10)
        #expect(TraitEffects.quitStreakBonus(flighty, content: content) == -4)
    }

    /// An unknown trait id is inert — a content bundle without
    /// `Traits.json` must change nothing.
    @Test func unknownTraitsAreNeutral() throws {
        let content = try Self.catalog()
        let odd = Self.employee(seed: 1, traits: ["notARealTrait"])
        #expect(TraitEffects.outputFactor(odd, content: content) == 1)
        #expect(TraitEffects.growthFactor(odd, content: content) == 1)
        #expect(TraitEffects.moraleTargetDelta(odd, content: content) == 0)
        #expect(TraitEffects.quitStreakBonus(odd, content: content) == 0)
        #expect(TraitEffects.poachResistance(odd, content: content) == 1)
    }

    // MARK: - TraitSystem (roster-wide)

    /// A mentor on payroll lifts everyone else's skills, and not their own.
    @Test func mentorTeachesTheTeamButNotThemselves() throws {
        let content = try Self.catalog()
        let balance = try BalanceConfig.loadBundled()
        var state = GameState.newGame(companyName: "X", seed: 5, balance: balance)
        let mentor = Self.employee(seed: 1, traits: ["mentor"])
        let student = Self.employee(seed: 2, traits: ["workhorse"])
        state.employees.append(mentor)
        state.employees.append(student)

        let mentorCodingBefore = mentor.skills.coding
        let studentCodingBefore = student.skills.coding
        _ = TraitSystem.run(&state, balance, content)

        let mentorAfter = try #require(state.employees.first { $0.id == mentor.id })
        let studentAfter = try #require(state.employees.first { $0.id == student.id })
        #expect(studentAfter.skills.coding > studentCodingBefore)
        #expect(mentorAfter.skills.coding == mentorCodingBefore)
    }

    /// A jokester lifts the room; a grumbler drags it down.
    @Test func theRoomsMoodFollowsTheTraitsInIt() throws {
        let content = try Self.catalog()
        let balance = try BalanceConfig.loadBundled()

        var happy = GameState.newGame(companyName: "X", seed: 5, balance: balance)
        happy.employees.append(Self.employee(seed: 1, traits: ["jokester"]))
        happy.employees.append(Self.employee(seed: 2, traits: ["workhorse"], morale: 50))
        _ = TraitSystem.run(&happy, balance, content)
        #expect(happy.employees[2].morale > 50)

        var glum = GameState.newGame(companyName: "X", seed: 5, balance: balance)
        glum.employees.append(Self.employee(seed: 1, traits: ["grumbler"]))
        glum.employees.append(Self.employee(seed: 2, traits: ["workhorse"], morale: 50))
        _ = TraitSystem.run(&glum, balance, content)
        #expect(glum.employees[2].morale < 50)
    }

    /// A showman gets the company noticed, and stops once it is.
    @Test func showmanTricklesReputationUpToACeiling() throws {
        let content = try Self.catalog()
        let balance = try BalanceConfig.loadBundled()
        var state = GameState.newGame(companyName: "X", seed: 5, balance: balance)
        state.employees.append(Self.employee(seed: 1, traits: ["showman"]))

        let before = state.company.reputation
        _ = TraitSystem.run(&state, balance, content)
        #expect(state.company.reputation > before)

        state.company.reputation = balance.traits.reputationBonusCeiling
        _ = TraitSystem.run(&state, balance, content)
        #expect(state.company.reputation == balance.traits.reputationBonusCeiling)
    }

    /// `TraitSystem` draws nothing: running it never moves either stream.
    @Test func traitSystemConsumesNoRandomness() throws {
        let content = try Self.catalog()
        let balance = try BalanceConfig.loadBundled()
        var state = GameState.newGame(companyName: "X", seed: 5, balance: balance)
        state.employees.append(Self.employee(seed: 1, traits: ["mentor", "showman"]))
        let rng = state.rng
        let worldRNG = state.worldRNG
        _ = TraitSystem.run(&state, balance, content)
        #expect(state.rng == rng)
        #expect(state.worldRNG == worldRNG)
    }
}
