import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

/// The story generator: eligibility gates, weighted picks, the pending
/// choice and its deadline, storyline follow-ups, flags, cooldowns, and the
/// determinism budget the whole thing is built to respect.
@Suite("Narrative system")
struct NarrativeSystemTests {

    // MARK: - Helpers

    /// A balance where only the narrative layer moves: no operating cost,
    /// no candidate or contract refreshes, no life drift, and the company
    /// roll lands on a known cadence.
    private static func balance(
        companyInterval: Int = 5,
        companyChance: Double = 1.0,
        lifeInterval: Int = 10_000,
        lifeChance: Double = 0,
        narrative: BalanceConfig.NarrativeBalance = BalanceConfig.NarrativeBalance()
    ) -> BalanceConfig {
        var config = TestBalance.make(
            weeklyOperatingCost: 0,
            candidateRefreshDays: 10_000,
            contractOfferRefreshDays: 10_000,
            eventCheckIntervalDays: companyInterval,
            eventChance: companyChance,
            life: TestBalance.life(
                lifeEventIntervalDays: lifeInterval, lifeEventChance: lifeChance
            )
        )
        config.narrative = narrative
        return config
    }

    private static func newGame(_ balance: BalanceConfig, seed: UInt64 = 11) -> GameState {
        GameState.newGame(companyName: "Acme", seed: seed, balance: balance)
    }

    private static let plainEvent = EventDef(
        id: "plain",
        headline: "A tech blog notices you.",
        impact: .reputationDelta(amount: 3),
        weight: 1
    )

    private static let choiceEvent = EventDef(
        id: "landlord",
        headline: "Your landlord wants the garage back",
        body: "He has a cousin who needs the space.",
        weight: 1,
        choices: [
            EventChoice(
                id: "pay",
                label: "Pay him off",
                detail: "−$1,500 · he forgets the cousin",
                effects: [.cash(amount: -1_500)],
                setFlags: ["landlord_paid"]
            ),
            EventChoice(
                id: "argue",
                label: "Read the lease back to him",
                effects: [.reputation(amount: -1)],
                followUpEventID: "landlord_returns",
                followUpDelayDays: 3
            ),
        ]
    )

    private static let followUp = EventDef(
        id: "landlord_returns",
        headline: "The landlord came back with a lawyer.",
        impact: .cashDelta(amount: -400),
        weight: 1,
        followUpOnly: true
    )

    // MARK: - Choices

    @Test("an event with choices raises a pending choice and pauses instead of applying")
    func choiceRaisesPendingChoice() {
        let balance = Self.balance()
        let content = TestContent.tiny(events: [Self.choiceEvent])
        var state = Self.newGame(balance)
        let cashBefore = state.company.cash

        var raised: GameEvent?
        for _ in 0..<5 {
            for event in Reducer.tick(&state, balance: balance, content: content) {
                if case .narrativeChoice = event { raised = event }
            }
        }

        let pending = state.narrative.pendingChoice
        #expect(pending?.id == "landlord")
        #expect(pending?.source == .company)
        #expect(pending?.options.count == 2)
        #expect(pending?.options.first?.label == "Pay him off")
        #expect(pending?.respondByDay == 10)
        #expect(state.company.cash == cashBefore, "nothing applies until the founder answers")
        #expect(raised?.pausesTimeline == true)
        #expect(raised?.severity == .critical)
    }

    @Test("answering applies the option's effects, flags and follow-up")
    func answeringApplies() {
        let balance = Self.balance()
        let content = TestContent.tiny(events: [Self.choiceEvent, Self.followUp])
        var state = Self.newGame(balance)
        for _ in 0..<5 { Reducer.tick(&state, balance: balance, content: content) }
        let cashBefore = state.company.cash

        let events = Reducer.apply(
            .resolveChoice(eventID: "landlord", optionIndex: 0),
            to: &state, balance: balance, content: content
        )

        #expect(state.narrative.pendingChoice == nil)
        #expect(state.company.cash == cashBefore - 1_500)
        #expect(state.narrative.flags.contains("landlord_paid"))
        #expect(events.contains(.narrativeResolved(
            eventID: "landlord", optionID: "pay", automatic: false, day: state.day
        )))
        #expect(state.narrative.scheduled.isEmpty, "the paid option schedules nothing")
    }

    @Test("a follow-up fires on its scheduled day and only then")
    func followUpChain() {
        let balance = Self.balance(companyChance: 0)
        let content = TestContent.tiny(events: [Self.choiceEvent, Self.followUp])
        var state = Self.newGame(balance)
        // Raise the beat by hand so the roll cadence isn't in the way.
        _ = NarrativeSystemTestHook.fire(Self.choiceEvent, &state, balance)
        Reducer.apply(
            .resolveChoice(eventID: "landlord", optionIndex: 1),
            to: &state, balance: balance, content: content
        )
        #expect(state.narrative.scheduled.map(\.eventID) == ["landlord_returns"])
        let dueDay = state.narrative.scheduled[0].day

        var firedDay: Int?
        for _ in 0..<6 {
            for event in Reducer.tick(&state, balance: balance, content: content) {
                if case .randomEvent(let id, let day) = event, id == "landlord_returns" {
                    firedDay = day
                }
            }
        }
        #expect(firedDay == dueDay)
        #expect(state.narrative.scheduled.isEmpty)
    }

    @Test("the deadline answers with the auto option")
    func deadlineAutoResolves() {
        let balance = Self.balance(companyChance: 0)
        let content = TestContent.tiny(events: [Self.choiceEvent, Self.followUp])
        var state = Self.newGame(balance)
        _ = NarrativeSystemTestHook.fire(Self.choiceEvent, &state, balance)
        let respondBy = try! #require(state.narrative.pendingChoice).respondByDay

        var automatic: GameEvent?
        while state.day <= respondBy + 1 {
            for event in Reducer.tick(&state, balance: balance, content: content) {
                if case .narrativeResolved(_, _, true, _) = event { automatic = event }
            }
        }
        #expect(state.narrative.pendingChoice == nil)
        #expect(automatic != nil, "the deadline answers for a founder who never did")
        // The last option is the default, and it schedules the follow-up.
        #expect(state.narrative.scheduled.map(\.eventID) == ["landlord_returns"])
    }

    @Test("a stale or unknown answer is ignored")
    func staleAnswerIgnored() {
        let balance = Self.balance(companyChance: 0)
        let content = TestContent.tiny(events: [Self.choiceEvent])
        var state = Self.newGame(balance)
        _ = NarrativeSystemTestHook.fire(Self.choiceEvent, &state, balance)

        #expect(Reducer.apply(
            .resolveChoice(eventID: "someone_else", optionIndex: 0),
            to: &state, balance: balance, content: content
        ).isEmpty)
        #expect(Reducer.apply(
            .resolveChoice(eventID: "landlord", optionIndex: 9),
            to: &state, balance: balance, content: content
        ).isEmpty)
        #expect(state.narrative.pendingChoice != nil)
    }

    @Test("nothing new fires while a choice is on the table")
    func pendingChoiceBlocksNewBeats() {
        let balance = Self.balance(companyInterval: 1)
        let content = TestContent.tiny(events: [Self.choiceEvent, Self.plainEvent])
        var state = Self.newGame(balance)
        _ = NarrativeSystemTestHook.fire(Self.choiceEvent, &state, balance)

        for _ in 0..<3 {
            let events = Reducer.tick(&state, balance: balance, content: content)
            #expect(!events.contains { if case .randomEvent = $0 { true } else { false } })
        }
        #expect(state.narrative.pendingChoice?.id == "landlord")
    }

    // MARK: - Requirements

    @Test("requirements gate which events are drawable")
    func requirementsGate() {
        let campusOnly = EventDef(
            id: "campus_only", headline: "Union talk.",
            impact: .reputationDelta(amount: -1), weight: 1,
            requires: EventRequirements(minTier: "campus")
        )
        let garageOnly = EventDef(
            id: "garage_only", headline: "The bulb went again.",
            impact: .cashDelta(amount: -20), weight: 1,
            requires: EventRequirements(maxTier: "garage")
        )
        let balance = Self.balance()
        let content = TestContent.tiny(events: [campusOnly, garageOnly])
        var state = Self.newGame(balance)

        var fired: [String] = []
        for _ in 0..<40 {
            for event in Reducer.tick(&state, balance: balance, content: content) {
                if case .randomEvent(let id, _) = event { fired.append(id) }
            }
        }
        #expect(!fired.isEmpty)
        #expect(!fired.contains("campus_only"), "a garage studio never sees campus problems")
        #expect(fired.allSatisfy { $0 == "garage_only" })
    }

    @Test("flags gate storyline halves")
    func flagsGate() {
        let needsFlag = EventRequirements(flagsAll: ["met_journalist"])
        var state = Self.newGame(Self.balance())
        #expect(!NarrativeSystemTestHook.meets(needsFlag, state))
        state.narrative.flags.insert("met_journalist")
        #expect(NarrativeSystemTestHook.meets(needsFlag, state))

        let forbidsFlag = EventRequirements(flagsNone: ["met_journalist"])
        #expect(!NarrativeSystemTestHook.meets(forbidsFlag, state))
    }

    @Test("a follow-up-only event is never drawn directly")
    func followUpOnlyNeverDrawn() {
        let balance = Self.balance()
        let content = TestContent.tiny(events: [Self.followUp])
        var state = Self.newGame(balance)
        for _ in 0..<60 {
            for event in Reducer.tick(&state, balance: balance, content: content) {
                #expect(!(event == .randomEvent(eventID: "landlord_returns", day: state.day)))
            }
        }
    }

    @Test("once-only events fire at most once and cooldowns space repeats")
    func onceAndCooldowns() {
        let onceEvent = EventDef(
            id: "once", headline: "Your first customer emails you.",
            impact: .reputationDelta(amount: 1), weight: 1, once: true
        )
        let balance = Self.balance()
        let content = TestContent.tiny(events: [onceEvent])
        var state = Self.newGame(balance)
        var count = 0
        for _ in 0..<80 {
            for event in Reducer.tick(&state, balance: balance, content: content) {
                if case .randomEvent(let id, _) = event, id == "once" { count += 1 }
            }
        }
        #expect(count == 1)
        #expect(state.narrative.firedOnce.contains("once"))

        var cooled = Self.balance()
        cooled.narrative = BalanceConfig.NarrativeBalance(defaultCooldownDays: 30)
        var state2 = Self.newGame(cooled)
        var days: [Int] = []
        for _ in 0..<80 {
            for event in Reducer.tick(&state2, balance: cooled, content: TestContent.tiny(
                events: [Self.plainEvent]
            )) {
                if case .randomEvent(let id, let day) = event, id == "plain" { days.append(day) }
            }
        }
        #expect(days.count >= 2)
        for (earlier, later) in zip(days, days.dropFirst()) {
            #expect(later - earlier >= 30)
        }
    }

    // MARK: - Effects

    @Test("effects land on the right part of the state")
    func effectsApply() {
        let balance = Self.balance()
        var state = Self.newGame(balance)
        state.employees.append(TestPeople.employee(name: "Rae", coding: 40))
        state.employees.append(TestPeople.employee(name: "Sam", coding: 30))
        state.employees[1].morale = 30
        state.employees[2].morale = 80
        let cashBefore = state.company.cash

        NarrativeSystemTestHook.apply(
            [
                .cash(amount: -500),
                .reputation(amount: 5),
                .moraleAll(amount: -4),
                .morale(amount: -10, pick: .lowestMorale),
                .founderMeters(energy: -5, health: 0, mood: -6, relationships: 0, wallet: -200),
                .flag("story"),
                .skill(skill: .coding, amount: 3, pick: .everyone),
                .market(topicID: "testing", amount: 0.2),
            ],
            &state, balance
        )

        #expect(state.company.cash == cashBefore - 500)
        #expect(state.company.reputation == 15)
        #expect(state.employees[1].morale == 30 - 4 - 10)
        #expect(state.employees[2].morale == 80 - 4)
        #expect(state.life.wallet == 2_000 - 200)
        #expect(state.narrative.flags.contains("story"))
        #expect(state.employees[1].skills.coding == 43)
        #expect(state.employees[2].skills.coding == 33)
        #expect(abs(state.market.multiplier(for: "testing") - 1.2) < 1e-9)
        #expect(state.ledger.entries.last?.amount == -500)
    }

    @Test("effects clamp to their legal ranges")
    func effectsClamp() {
        let balance = Self.balance()
        var state = Self.newGame(balance)
        state.employees.append(TestPeople.employee(name: "Rae"))
        NarrativeSystemTestHook.apply(
            [.reputation(amount: -50), .moraleAll(amount: -500), .market(topicID: "testing", amount: -5)],
            &state, balance
        )
        #expect(state.company.reputation == 0)
        #expect(state.employees[1].morale == 0)
        #expect(state.market.multiplier(for: "testing") >= 0.1)
    }

    // MARK: - Determinism & save compatibility

    @Test("two runs of the same seed produce identical narrative state")
    func deterministic() {
        let balance = Self.balance(companyChance: 0.5, lifeInterval: 3, lifeChance: 0.5)
        let content = TestContent.tiny(
            events: [Self.choiceEvent, Self.plainEvent, Self.followUp],
            lifeEvents: [LifeEventDef(
                id: "cold", headline: "You come down with something.",
                weight: 1, impact: LifeEventDef.Impact(energy: -8, coldDays: 3)
            )]
        )
        func run() -> GameState {
            var state = Self.newGame(balance, seed: 4242)
            for day in 0..<120 {
                Reducer.tick(&state, balance: balance, content: content)
                if day % 17 == 0, let pending = state.narrative.pendingChoice {
                    Reducer.apply(
                        .resolveChoice(eventID: pending.id, optionIndex: pending.options[0].index),
                        to: &state, balance: balance, content: content
                    )
                }
            }
            return state
        }
        #expect(run() == run())
    }

    @Test("a pending choice survives encode and decode")
    func pendingChoiceRoundTrips() throws {
        let balance = Self.balance(companyChance: 0)
        var state = Self.newGame(balance)
        _ = NarrativeSystemTestHook.fire(Self.choiceEvent, &state, balance)
        state.narrative.flags.insert("zebra")
        state.narrative.flags.insert("alpha")
        state.narrative.cooldowns["b"] = 20
        state.narrative.cooldowns["a"] = 10

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(state)
        let decoded = try JSONDecoder().decode(GameState.self, from: data)
        #expect(decoded.narrative == state.narrative)
        #expect(decoded.narrative.pendingChoice?.options.count == 2)
        // Sets and dictionaries encode sorted, so identical states stay
        // byte-identical.
        #expect(try encoder.encode(decoded) == data)
    }

    @Test("a save written before the narrative key decodes as initial")
    func decodesWhenKeyAbsent() throws {
        let balance = Self.balance(companyChance: 0)
        var state = Self.newGame(balance)
        _ = NarrativeSystemTestHook.fire(Self.choiceEvent, &state, balance)

        let data = try JSONEncoder().encode(state)
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["narrative"] != nil)
        object.removeValue(forKey: "narrative")
        let legacy = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(GameState.self, from: legacy)
        #expect(decoded.narrative == .initial)
        #expect(decoded.narrative.pendingChoice == nil)
    }

    @Test("a balance with no narrative overrides rolls on the legacy cadence")
    func legacyCadencePreserved() {
        let balance = Self.balance(companyInterval: 5, companyChance: 1.0)
        #expect(balance.narrative.companyEventIntervalDays == nil)
        let content = TestContent.tiny(events: [Self.plainEvent])
        var state = Self.newGame(balance)
        var days: [Int] = []
        for _ in 0..<20 {
            for event in Reducer.tick(&state, balance: balance, content: content) {
                if case .randomEvent(_, let day) = event { days.append(day) }
            }
        }
        #expect(days == [5, 10, 15, 20])
    }
}

/// Narrow test access to the internals the suite drives directly: firing a
/// definition without waiting for its roll, evaluating a requirement gate,
/// and applying a bare effect list.
enum NarrativeSystemTestHook {
    static func fire(
        _ def: EventDef, _ state: inout GameState, _ balance: BalanceConfig
    ) -> [GameEvent] {
        NarrativeSystem.fireCompany(def, state: &state, balance: balance)
    }

    static func meets(_ requires: EventRequirements, _ state: GameState) -> Bool {
        NarrativeSystem.meets(requires, state: state)
    }

    static func apply(
        _ effects: [EventEffect], _ state: inout GameState, _ balance: BalanceConfig
    ) {
        NarrativeSystem.apply(effects, label: "test", state: &state, balance: balance)
    }
}
