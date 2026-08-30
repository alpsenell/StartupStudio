import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

// MARK: - Founder profile & archetypes

@Suite("Founder profile")
struct FounderProfileTests {
    /// The bundled balance carries all three spreads, each a 100-point
    /// budget so no archetype is strictly stronger.
    @Test func bundledBalanceCarriesAllThreeArchetypeSpreads() throws {
        let balance = try BalanceConfig.loadBundled()
        for archetype in FounderArchetype.allCases {
            let skills = balance.progression.founderSkills(
                for: archetype, fallback: SkillSet(coding: 0, design: 0, marketing: 0)
            )
            #expect(skills.total == 100, "\(archetype.rawValue) should be a 100-point spread")
        }
        let hacker = balance.progression.founderSkills(
            for: .hacker, fallback: SkillSet(coding: 0, design: 0, marketing: 0)
        )
        #expect(hacker.coding == 55)
        #expect(hacker.design == 25)
        #expect(hacker.marketing == 20)
    }

    /// A chosen archetype names the founder and sets their skills.
    @Test func chosenArchetypeSetsFounderSkillsAndName() throws {
        let balance = try BalanceConfig.loadBundled()
        let state = GameState.newGame(
            companyName: "Bright Ideas", seed: 12, balance: balance,
            founder: FounderProfile(name: "  Ada Kwan  ", archetype: .designer)
        )
        let founder = try #require(state.employees.first)
        #expect(founder.name == "Ada Kwan")
        #expect(founder.skills.design == 55)
        #expect(founder.skills.coding == 25)
        #expect(founder.role == .founder)
        #expect(state.progression.founder.archetype == .designer)
    }

    /// The nameless default founder keeps the balance's flat skills, so a
    /// run nobody configured (the balance harness, a plain "New game") is
    /// byte-identical to the pre-archetype game.
    @Test func defaultFounderKeepsTheFlatBalanceSkills() throws {
        let balance = try BalanceConfig.loadBundled()
        let state = GameState.newGame(companyName: "X", seed: 12, balance: balance)
        let founder = try #require(state.employees.first)
        #expect(founder.name == "Founder")
        #expect(founder.skills.coding == balance.founderCoding)
        #expect(founder.skills.design == balance.founderDesign)
        #expect(founder.skills.marketing == balance.founderMarketing)
        #expect(!state.progression.founder.usesArchetypeSkills)
    }

    /// An empty name falls back rather than leaving a blank chip in the UI.
    @Test func blankNameFallsBackToFounder() {
        let profile = FounderProfile(name: "   ", archetype: .hustler)
        #expect(profile.displayName == "Founder")
    }

    /// Pinning the appearance must not shift the RNG stream: the founder's
    /// id and the post-newGame stream stay identical.
    @Test func pinningTheAppearanceDoesNotShiftTheStream() throws {
        let balance = try BalanceConfig.loadBundled()
        let plain = GameState.newGame(companyName: "X", seed: 4242, balance: balance)
        let pinned = GameState.newGame(
            companyName: "X", seed: 4242, balance: balance,
            founder: FounderProfile(name: "Ada", archetype: .hustler, appearanceSeed: 99)
        )
        #expect(pinned.rng == plain.rng)
        #expect(pinned.employees[0].id == plain.employees[0].id)
        #expect(pinned.employees[0].appearanceSeed == 99)
    }
}

// MARK: - Save compatibility

@Suite("Progression save compatibility")
struct ProgressionSaveTests {
    /// The contract every new persisted field follows: an absent key
    /// decodes as the fresh-run value.
    @Test func decodesWhenTheKeyIsAbsent() throws {
        let data = Data("{}".utf8)
        let state = try JSONDecoder().decode(ProgressionState.self, from: data)
        #expect(state == .initial)
        #expect(state.chapter == 1)
        #expect(state.founder == .default)
        #expect(state.stats == .initial)
    }

    /// Sets and dictionaries encode sorted, so identical states stay
    /// byte-identical whatever the insertion order was.
    @Test func setsAndDictionariesEncodeInSortedOrder() throws {
        var state = ProgressionState.initial
        state.completedGoalIDs = ["z_goal", "a_goal", "m_goal"]
        state.perks = [ProgressionPerk.veteranCrew.rawValue, ProgressionPerk.pressContacts.rawValue]
        state.goalProgress = ["z_goal": 3, "a_goal": 1]

        var mirror = ProgressionState.initial
        mirror.completedGoalIDs = ["m_goal", "z_goal", "a_goal"]
        mirror.perks = [ProgressionPerk.pressContacts.rawValue, ProgressionPerk.veteranCrew.rawValue]
        mirror.goalProgress = ["a_goal": 1, "z_goal": 3]

        // `.sortedKeys` is what `SaveStore` and the determinism tests use;
        // what this proves is that the *array* orders inside — sets and
        // dictionaries — don't depend on insertion order.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        #expect(try encoder.encode(state) == encoder.encode(mirror))
    }

    /// A profile written before `usesArchetypeSkills` existed decodes as a
    /// chosen founder (it can only have come from a new-game flow).
    @Test func profileWithoutTheArchetypeFlagDecodesAsChosen() throws {
        let json = Data(#"{"name":"Ada","archetype":"designer"}"#.utf8)
        let profile = try JSONDecoder().decode(FounderProfile.self, from: json)
        #expect(profile.usesArchetypeSkills)
        #expect(profile.archetype == .designer)
        #expect(profile.appearanceSeed == nil)
    }

    /// Round-tripping a fully populated state loses nothing.
    @Test func roundTripsEveryField() throws {
        var state = ProgressionState(founder: FounderProfile(name: "Ada", archetype: .hustler))
        state.chapter = 3
        state.chapterTitle = "Studio"
        state.completedGoalIDs = ["a", "b"]
        state.activeGoals = [
            GoalProgress(id: "c", title: "Ship it", detail: "1 of 2", progress: 1, target: 2, chapter: 3),
        ]
        state.goalProgress = ["c": 1]
        state.perks = [ProgressionPerk.pressContacts.rawValue]
        state.chapterLog = [ChapterEntry(chapter: 1, day: 0), ChapterEntry(chapter: 2, day: 84)]
        state.stats.peakHeadcount = 9

        let data = try JSONEncoder().encode(state)
        #expect(try JSONDecoder().decode(ProgressionState.self, from: data) == state)
    }
}
