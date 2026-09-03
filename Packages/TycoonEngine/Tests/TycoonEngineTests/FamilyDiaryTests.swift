import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

// The date in the diary (WS-E, iteration 5): three effects that reach the
// numbers that end a relationship, an option that greys out when the
// week's evenings are spent, and a family calendar whose beats take the
// life roll's slot instead of adding a pause.

/// A balance with an evening budget, a life roll on the shipped cadence,
/// and nothing else that draws from `rng` on a schedule — so a test can
/// say exactly which day a beat lands on and what the stream did.
private let missedFlag = "family_date_missed"

private func diaryBalance(
    lifeInterval: Int = 14,
    lifeChance: Double = 0.35
) -> BalanceConfig {
    var life = TestBalance.life(
        lifeEventIntervalDays: lifeInterval, lifeEventChance: lifeChance
    )
    life.eveningsPerWeek = [
        WorkSchedule.chill.rawValue: 5,
        WorkSchedule.normal.rawValue: 3,
        WorkSchedule.crunch.rawValue: 1,
    ]
    let relationships = BalanceConfig.RelationshipBalance(
        partnerActivities: [
            PartnerActivity.call.rawValue: .init(cost: 0, affection: 4, cooldownDays: 0),
        ]
    )
    return TestBalance.make(
        weeklyOperatingCost: 0,
        candidateRefreshDays: 10_000,
        contractOfferRefreshDays: 10_000,
        eventCheckIntervalDays: 10_000,
        life: life,
        relationships: relationships
    )
}

private func newGame(_ balance: BalanceConfig, seed: UInt64 = 21) -> GameState {
    var state = GameState.newGame(companyName: "Acme", seed: seed, balance: balance)
    state.life.wallet = 50_000
    TestLife.pinPeak(&state)
    return state
}

/// A dated beat shaped like the shipped anniversary: "Go" wants an
/// evening, the polite miss is the deadline's answer.
private let anniversary = LifeEventDef(
    id: "anniversary_test",
    headline: "Your anniversary with {partner} is this week.",
    weight: 1,
    impact: LifeEventDef.Impact(),
    body: "{partner} booked the table.",
    choices: [
        EventChoice(
            id: "go", label: "Go",
            effects: [.evening, .affection(amount: 15)],
            requires: EventRequirements(minEveningsLeft: 1)
        ),
        EventChoice(
            id: "miss", label: "Send flowers",
            effects: [.affection(amount: -20)],
            setFlags: [missedFlag],
            followUpEventID: "after_test", followUpDelayDays: 30
        ),
    ],
    category: .family,
    autoChoiceIndex: 1,
    followUpOnly: true,
    diaryLabel: "Your anniversary with {partner}",
    missedVariantID: "anniversary_again_test"
)

private let anniversaryAgain = LifeEventDef(
    id: "anniversary_again_test",
    headline: "Your anniversary. You missed the last one too.",
    weight: 1,
    impact: LifeEventDef.Impact(),
    body: "{partner} has not mentioned it.",
    choices: [
        EventChoice(
            id: "go", label: "Be there",
            effects: [.evening, .affection(amount: 22)],
            clearFlags: [missedFlag],
            requires: EventRequirements(minEveningsLeft: 1)
        ),
        EventChoice(
            id: "miss", label: "Flowers again",
            effects: [.affection(amount: -25)],
            setFlags: [missedFlag]
        ),
    ],
    category: .family,
    autoChoiceIndex: 1,
    followUpOnly: true,
    diaryLabel: "Your anniversary with {partner}"
)

/// The second act: only while the miss is on the books.
private let afterMiss = LifeEventDef(
    id: "after_test",
    headline: "{partner} brings up the evening you didn't come to.",
    weight: 1,
    impact: LifeEventDef.Impact(),
    body: "Not angrily.",
    requires: EventRequirements(flagsAll: [missedFlag]),
    choices: [
        EventChoice(id: "make_up", label: "Make it up", effects: [.affection(amount: 10)]),
        EventChoice(id: "promise", label: "Promise the next one", effects: [.affection(amount: -5)]),
    ],
    category: .family,
    followUpOnly: true
)

private let birthday = LifeEventDef(
    id: "birthday_test",
    headline: "{child}'s birthday is on Saturday.",
    weight: 1,
    impact: LifeEventDef.Impact(),
    body: "{child} asked whether you'd be there.",
    choices: [
        EventChoice(
            id: "party", label: "Go to the party",
            effects: [.evening, .founderMeters(energy: 0, health: 0, mood: 10, relationships: 12, wallet: 0)],
            requires: EventRequirements(minEveningsLeft: 1)
        ),
        EventChoice(
            id: "miss", label: "Send a present",
            effects: [.founderMeters(energy: 0, health: 0, mood: -8, relationships: -10, wallet: 0)],
            setFlags: [missedFlag]
        ),
    ],
    category: .family,
    autoChoiceIndex: 1,
    followUpOnly: true,
    diaryLabel: "{child}'s birthday"
)

/// A rolled beat so the weighted pick has something to draw.
private let plainLife = LifeEventDef(
    id: "cold_test", headline: "You come down with something.",
    weight: 1, impact: LifeEventDef.Impact(energy: -3)
)

private func content(_ extra: [LifeEventDef] = []) -> ContentCatalog {
    TestContent.tiny(lifeEvents: [plainLife] + extra)
}

/// Narrow access to the engine's internals: firing a life definition
/// without waiting for its roll, and applying a bare effect list.
private enum Hook {
    static func fire(_ def: LifeEventDef, _ state: inout GameState, _ balance: BalanceConfig) -> [GameEvent] {
        NarrativeSystem.fireLife(def, state: &state, balance: balance)
    }

    static func apply(_ effects: [EventEffect], _ state: inout GameState, _ balance: BalanceConfig) {
        NarrativeSystem.apply(effects, label: "test", state: &state, balance: balance)
    }
}

// MARK: - The three effects

@Suite("Diary effects")
struct DiaryEffectTests {
    @Test("affection moves the partner's number, clamps, and counts as showing up")
    func affection() {
        let balance = diaryBalance()
        var state = newGame(balance)
        TestLife.setPartner(&state, stage: .partner)
        state.life.family.affection = 50
        state.life.family.lastPartnerDay = 0
        state.day = 40

        Hook.apply([.affection(amount: 15)], &state, balance)
        #expect(state.life.family.affection == 65)
        #expect(state.life.family.lastPartnerDay == 40, "a good evening restarts the neglect clock")

        Hook.apply([.affection(amount: -20)], &state, balance)
        #expect(state.life.family.affection == 45)
        #expect(state.life.family.lastPartnerDay == 40, "a miss does not")

        Hook.apply([.affection(amount: 200)], &state, balance)
        #expect(state.life.family.affection == 100)
        Hook.apply([.affection(amount: -500)], &state, balance)
        #expect(state.life.family.affection == 0)
    }

    @Test("affection is a no-op while single — the number is not simulated")
    func affectionWhileSingle() {
        let balance = diaryBalance()
        var state = newGame(balance)
        Hook.apply([.affection(amount: 30)], &state, balance)
        #expect(state.life.family.affection == 0)
        #expect(state.life.family.lastPartnerDay == nil)
    }

    @Test("an evening books one of the week's evenings")
    func evening() {
        let balance = diaryBalance()
        var state = newGame(balance)
        state.life.schedule = .normal
        #expect(state.eveningsLeftThisWeek(balance) == 3)
        Hook.apply([.evening], &state, balance)
        #expect(state.eveningsLeftThisWeek(balance) == 2)
        #expect(state.life.eveningsSpentThisWeek == 1)

        // A balance with no budget has nothing to book.
        let unbudgeted = TestBalance.make(life: TestBalance.quietLife)
        var free = newGame(unbudgeted)
        Hook.apply([.evening], &free, unbudgeted)
        #expect(free.life.eveningsSpentThisWeek == 0)
    }

    @Test("bond moves the founder's bond with the pick and draws nothing")
    func bond() {
        let balance = diaryBalance()
        var state = newGame(balance)
        state.employees.append(TestPeople.employee(name: "Rae"))
        state.employees.append(TestPeople.employee(name: "Sam"))
        state.employees[1].morale = 20
        state.employees[2].morale = 80
        state.employees[1].founderBond = 10
        state.employees[2].founderBond = 10
        let rng = state.rng

        Hook.apply([.bond(amount: 8, pick: .lowestMorale)], &state, balance)
        #expect(state.employees[1].founderBond == 18)
        #expect(state.employees[2].founderBond == 10)
        #expect(state.rng == rng)

        Hook.apply([.bond(amount: 200, pick: .everyone)], &state, balance)
        #expect(state.employees[1].founderBond == 100)
        #expect(state.employees[2].founderBond == 100)
        #expect(EventEffect.bond(amount: 1, pick: .random).drawsRandomly)
        #expect(!EventEffect.bond(amount: 1, pick: .everyone).drawsRandomly)
    }
}

// MARK: - The greyed option

@Suite("The greyed option")
struct GreyedOptionTests {
    @Test("an option that wants an evening stays on the sheet, greyed, when the week is spent")
    func greysInsteadOfHiding() {
        let balance = diaryBalance()
        var state = newGame(balance)
        TestLife.setPartner(&state, stage: .partner)
        state.day = 30
        state.life.schedule = .crunch
        Reducer.apply(.spendTimeWithPartner(.call), to: &state, balance: balance, content: content())
        #expect(state.eveningsLeftThisWeek(balance) == 0, "crunch is one evening, and it went on the call")

        _ = Hook.fire(anniversary, &state, balance)
        let pending = try! #require(state.narrative.pendingChoice)
        #expect(pending.options.map(\.id) == ["go", "miss"], "the option is offered, not filtered")
        #expect(pending.options[0].disabledReason == "No evenings left this week")
        #expect(pending.options[1].disabledReason == nil)
    }

    @Test("with an evening in hand the same option is open")
    func openWithAnEvening() {
        let balance = diaryBalance()
        var state = newGame(balance)
        TestLife.setPartner(&state, stage: .partner)
        state.day = 30
        state.life.schedule = .normal

        _ = Hook.fire(anniversary, &state, balance)
        #expect(state.narrative.pendingChoice?.options[0].disabledReason == nil)
    }

    @Test("a greyed option cannot be chosen and is never the deadline's answer")
    func greyedIsNotAnAnswer() {
        let balance = diaryBalance()
        let catalog = content([anniversary, afterMiss])
        var state = newGame(balance)
        TestLife.setPartner(&state, stage: .partner)
        state.day = 30
        state.life.schedule = .crunch
        state.life.eveningsSpentThisWeek = 1
        state.life.family.affection = 60

        _ = Hook.fire(anniversary, &state, balance)
        #expect(Reducer.apply(
            .resolveChoice(eventID: "anniversary_test", optionIndex: 0),
            to: &state, balance: balance, content: catalog
        ).isEmpty)
        #expect(state.narrative.pendingChoice != nil, "the sheet is still up")
        #expect(state.life.family.affection == 60)

        // A definition that points its auto answer at the greyed option
        // still resolves to an open one.
        var greyedAuto = anniversary
        greyedAuto.autoChoiceIndex = 0
        var state2 = state
        state2.narrative.pendingChoice = nil
        _ = Hook.fire(greyedAuto, &state2, balance)
        #expect(state2.narrative.pendingChoice?.autoOptionIndex == 1)
    }

    @Test("a company beat's options are unchanged: no reason, same indices")
    func companyBeatsUntouched() {
        let balance = diaryBalance()
        var state = newGame(balance)
        let def = EventDef(
            id: "plain_company", headline: "The landlord.", body: "He wants the garage.",
            weight: 1,
            choices: [
                EventChoice(id: "pay", label: "Pay", effects: [.cash(amount: -100)]),
                EventChoice(id: "argue", label: "Argue"),
            ]
        )
        _ = NarrativeSystem.fireCompany(def, state: &state, balance: balance)
        let options = try! #require(state.narrative.pendingChoice?.options)
        #expect(options.map(\.index) == [0, 1])
        #expect(options.allSatisfy { $0.isEnabled })
    }
}
