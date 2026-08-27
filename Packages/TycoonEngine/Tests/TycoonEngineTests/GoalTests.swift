import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

/// The chapter/goal engine: the catalog's shape, one-shot completion,
/// chapter gating, perks, determinism, and the bar the plan set for how
/// much progress a bot run makes.
@Suite("Chapter goals")
struct GoalTests {
    private static let content = TestContent.bundled

    private static func balance() throws -> BalanceConfig {
        try BalanceConfig.loadBundled()
    }

    /// The catalog is the shape the card and the chapter gate assume.
    @Test func catalogIsFiveChaptersOfSix() throws {
        let content = Self.content
        #expect(content.chapters.count == ProgressionState.chapterCount)
        for chapter in content.chapters {
            #expect(chapter.goals.count == 6, "chapter \(chapter.chapter) has \(chapter.goals.count)")
            #expect(!chapter.title.isEmpty)
            #expect(!chapter.teaser.isEmpty)
        }
        let ids = content.goals.map(\.id)
        #expect(Set(ids).count == ids.count, "goal ids must be unique")
        for goal in content.goals {
            #expect(!goal.title.isEmpty)
            #expect(goal.detail?.isEmpty == false, "\(goal.id) has no detail line")
            #expect(goal.condition.amount > 0)
        }
    }

    /// Every perk a goal hands out has to be a real one.
    @Test func everyRewardPerkExists() throws {
        for goal in Self.content.goals {
            guard let perk = goal.reward?.perk else { continue }
            #expect(ProgressionPerk(rawValue: perk) != nil, "\(goal.id) rewards unknown perk \(perk)")
        }
    }

    /// Chapter 1 opens with three live goals and the chapter's title.
    @Test func theCardHasSomethingToShowOnDayOne() throws {
        let balance = try Self.balance()
        var state = GameState.newGame(companyName: "Acme", seed: 11, balance: balance)
        Reducer.tick(&state, balance: balance, content: Self.content)

        #expect(state.progression.chapterTitle == "Garage")
        #expect(state.progression.activeGoals.count == ProgressionState.activeGoalLimit)
        for goal in state.progression.activeGoals {
            #expect(goal.chapter == 1)
            #expect(goal.target > 0)
            #expect(goal.fraction >= 0 && goal.fraction <= 1)
        }
    }

    /// Naming a product finishes the first goal, pays its reward once, and
    /// never pays again.
    @Test func aGoalCompletesOnceAndPaysOnce() throws {
        let balance = try Self.balance()
        var state = GameState.newGame(companyName: "Acme", seed: 12, balance: balance)
        Reducer.apply(
            .startProduct(typeID: "mobile_app", topicID: "fitness", name: "FitTrack", focus: .balanced),
            to: &state, balance: balance, content: Self.content
        )
        let before = state.company.reputation
        let events = Reducer.tick(&state, balance: balance, content: Self.content)

        #expect(events.contains { event in
            if case .goalCompleted(let id, _) = event { return id == "g1_name_a_product" }
            return false
        })
        #expect(state.progression.completedGoalIDs.contains("g1_name_a_product"))
        #expect(state.company.reputation > before)

        // Ten more days: the goal is done, so it cannot fire or pay again.
        var completions = 0
        for _ in 0..<10 {
            for event in Reducer.tick(&state, balance: balance, content: Self.content) {
                if case .goalCompleted(let id, _) = event, id == "g1_name_a_product" {
                    completions += 1
                }
            }
        }
        #expect(completions == 0)
    }

    /// Finishing enough of a chapter opens the next one, exactly once.
    @Test func enoughGoalsOpenTheNextChapter() throws {
        let balance = try Self.balance()
        var state = GameState.newGame(companyName: "Acme", seed: 13, balance: balance)
        let needed = balance.progression.goalsToAdvanceChapter
        for goal in Self.content.goals(inChapter: 1).prefix(needed) {
            state.progression.completedGoalIDs.insert(goal.id)
        }

        let events = Reducer.tick(&state, balance: balance, content: Self.content)
        #expect(state.progression.chapter == 2)
        #expect(state.progression.chapterTitle == "Loft")
        #expect(events.contains { event in
            if case .chapterReached(let chapter, _) = event { return chapter == 2 }
            return false
        })
        #expect(state.progression.dayReached(chapter: 2) == state.day)

        let again = Reducer.tick(&state, balance: balance, content: Self.content)
        #expect(!again.contains { event in
            if case .chapterReached = event { return true }
            return false
        })
    }

    /// A perk reward lands in the permanent set.
    @Test func aPerkRewardIsPermanent() throws {
        let balance = try Self.balance()
        var state = GameState.newGame(companyName: "Acme", seed: 14, balance: balance)
        state.progression.chapter = 2
        state.progression.stats.bestReviewScore = 70

        Reducer.tick(&state, balance: balance, content: Self.content)
        #expect(state.progression.completedGoalIDs.contains("g2_review_60"))
        #expect(state.progression.hasPerk(.pressContacts))
    }

    /// The whole system draws nothing from either stream.
    @Test func progressionConsumesNoRandomness() throws {
        let balance = try Self.balance()
        var state = GameState.newGame(companyName: "Acme", seed: 15, balance: balance)
        let rng = state.rng
        let worldRNG = state.worldRNG
        _ = ProgressionSystem.run(&state, balance, Self.content)
        #expect(state.rng == rng)
        #expect(state.worldRNG == worldRNG)
    }

    /// The acceptance bar: a bot that builds and hires clears at least ten
    /// goals in two years, and a bot that only grinds contracts still gets
    /// a handful — the early chapters have to be reachable by playing badly.
    @Test func botsMakeProgressOverTwoYears() throws {
        let balance = try Self.balance()
        let engaged = SimRunner.run(
            days: 730, seed: 7_302, bot: CrunchHireBot(), balance: balance, content: Self.content
        ).state.progression
        let solo = SimRunner.run(
            days: 730, seed: 7_301, bot: SoloSlowBot(), balance: balance, content: Self.content
        ).state.progression

        #expect(
            engaged.completedGoalIDs.count >= 10,
            "crunch-hire finished \(engaged.completedGoalIDs.count) goals in two years"
        )
        #expect(
            solo.completedGoalIDs.count >= 4,
            "solo-slow finished \(solo.completedGoalIDs.count) goals in two years"
        )
        #expect(engaged.chapter >= 3, "crunch-hire only reached chapter \(engaged.chapter)")
    }
}
