import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine
import TycoonBots

// The date in the diary (WS-E, iteration 5): three effects that reach the
// numbers that end a relationship, an option that greys out when the
// week's evenings are spent, and a family calendar whose beats take the
// life roll's slot instead of adding a pause.

/// A balance with an evening budget, a life roll on the shipped cadence,
/// and nothing else that draws from `rng` on a schedule — so a test can
/// say exactly which day a beat lands on and what the stream did. The
/// meters and affection sit still: a year is long enough for the shipped
/// drift to end the relationship the calendar is about.
private func diaryBalance(
    lifeInterval: Int = 14,
    lifeChance: Double = 0.35,
    diary: BalanceConfig.RelationshipBalance.DiaryBalance = .init()
) -> BalanceConfig {
    let still = BalanceConfig.LifeBalance.MeterDrift(energy: 0, health: 0, mood: 0, relationships: 0)
    var life = TestBalance.life(
        chillDrift: still, normalDrift: still, crunchDrift: still,
        stageRelationshipDrain: [
            RelationshipStage.single.rawValue: 0,
            RelationshipStage.dating.rawValue: 0,
            RelationshipStage.partner.rawValue: 0,
            RelationshipStage.married.rawValue: 0,
        ],
        childDrift: still,
        lifeEventIntervalDays: lifeInterval, lifeEventChance: lifeChance
    )
    life.eveningsPerWeek = [
        WorkSchedule.chill.rawValue: 5,
        WorkSchedule.normal.rawValue: 3,
        WorkSchedule.crunch.rawValue: 1,
    ]
    let relationships = BalanceConfig.RelationshipBalance(
        affectionDrift: 0,
        neglectDrift: 0,
        affectionRelationshipFactor: 0,
        partnerActivities: [
            PartnerActivity.call.rawValue: .init(cost: 0, affection: 4, cooldownDays: 0),
        ],
        diary: diary
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
    id: FamilyCalendar.anniversaryEventID,
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
            setFlags: [FamilyCalendar.missedFlag],
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
            clearFlags: [FamilyCalendar.missedFlag],
            requires: EventRequirements(minEveningsLeft: 1)
        ),
        EventChoice(
            id: "miss", label: "Flowers again",
            effects: [.affection(amount: -25)],
            setFlags: [FamilyCalendar.missedFlag]
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
    requires: EventRequirements(flagsAll: [FamilyCalendar.missedFlag]),
    choices: [
        EventChoice(id: "make_up", label: "Make it up", effects: [.affection(amount: 10)]),
        EventChoice(id: "promise", label: "Promise the next one", effects: [.affection(amount: -5)]),
    ],
    category: .family,
    followUpOnly: true
)

private let birthday = LifeEventDef(
    id: FamilyCalendar.birthdayEventID,
    headline: "{child}'s birthday is on Saturday.",
    weight: 1,
    impact: LifeEventDef.Impact(),
    body: "{child} asked whether you'd be there.",
    choices: [
        EventChoice(
            id: "party", label: "Go to {child}'s party",
            effects: [.evening, .founderMeters(energy: 0, health: 0, mood: 10, relationships: 12, wallet: 0)],
            requires: EventRequirements(minEveningsLeft: 1)
        ),
        EventChoice(
            id: "miss", label: "Send a present",
            effects: [.founderMeters(energy: 0, health: 0, mood: -8, relationships: -10, wallet: 0)],
            setFlags: [FamilyCalendar.missedFlag]
        ),
    ],
    category: .family,
    autoChoiceIndex: 1,
    followUpOnly: true,
    diaryLabel: "{child}'s birthday"
)

/// A promise: the follow-up a choice creates, with a date on it.
private let promiseBeat = LifeEventDef(
    id: "asks_future_test",
    headline: "Where is this going?",
    weight: 1,
    minStage: "partner",
    impact: LifeEventDef.Impact(),
    body: "Calmly.",
    choices: [
        EventChoice(
            id: "honest", label: "A date",
            effects: [.affection(amount: 5)],
            followUpEventID: "promise_test", followUpDelayDays: 90
        ),
        EventChoice(id: "deflect", label: "Depends on the launch", effects: [.affection(amount: -5)]),
    ],
    category: .family
)

private let promiseDate = LifeEventDef(
    id: "promise_test",
    headline: "The date you gave {partner} is this week.",
    weight: 1,
    impact: LifeEventDef.Impact(),
    body: "It is on the fridge.",
    choices: [
        EventChoice(
            id: "kept", label: "Keep it",
            effects: [.evening, .affection(amount: 25)],
            requires: EventRequirements(hasLiveProduct: true, minEveningsLeft: 1)
        ),
        EventChoice(
            id: "broke", label: "Tell them it's close",
            effects: [.affection(amount: -20)],
            setFlags: [FamilyCalendar.missedFlag]
        ),
    ],
    category: .family,
    autoChoiceIndex: 1,
    followUpOnly: true,
    diaryLabel: "The date you gave {partner}"
)

/// A rolled beat so the weighted pick has something to draw.
private let plainLife = LifeEventDef(
    id: "cold_test", headline: "You come down with something.",
    weight: 1, impact: LifeEventDef.Impact(energy: -3)
)

private func content(_ extra: [LifeEventDef] = []) -> ContentCatalog {
    TestContent.tiny(lifeEvents: [plainLife] + extra)
}

private let calendar = content([anniversary, anniversaryAgain, afterMiss, birthday, promiseBeat, promiseDate])

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

/// Ticks until `day`, collecting every event on the way.
@discardableResult
private func run(
    _ state: inout GameState, to day: Int, _ balance: BalanceConfig, _ catalog: ContentCatalog
) -> [GameEvent] {
    var events: [GameEvent] = []
    while state.day < day {
        events.append(contentsOf: Reducer.tick(&state, balance: balance, content: catalog))
    }
    return events
}

private func dated(_ state: GameState) -> [(id: String, day: Int)] {
    state.narrative.scheduled.map { ($0.eventID, $0.day) }
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
        #expect(pending.title == "Your anniversary with Sam is this week.")
        #expect(pending.body == "Sam booked the table.")
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
            .resolveChoice(eventID: FamilyCalendar.anniversaryEventID, optionIndex: 0),
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

// MARK: - The calendar

@Suite("The family calendar")
struct FamilyCalendarTests {
    @Test("dating puts an anniversary in the diary a year on; each stage replaces it; a breakup clears it")
    func anniversaryFollowsTheStage() {
        let balance = diaryBalance(lifeChance: 0)
        var state = newGame(balance)
        state.day = 10
        state.life.meters.relationships = 100
        Reducer.apply(.advanceRelationship, to: &state, balance: balance, content: calendar)
        #expect(state.life.family.stage == .dating)
        #expect(dated(state).map(\.id) == [FamilyCalendar.anniversaryEventID])
        #expect(dated(state).map(\.day) == [375])
        #expect(state.familyDates(content: calendar).first?.label.hasSuffix("anniversary with \(state.life.family.partnerName!)") == true)

        // Moving in on day 200 starts the year again.
        state.day = 200
        Reducer.apply(.advanceRelationship, to: &state, balance: balance, content: calendar)
        #expect(state.life.family.stage == .partner)
        #expect(dated(state).map(\.day) == [565])

        // The breakup takes the date with it.
        state.life.meters.relationships = 0
        run(&state, to: 220, balance, calendar)
        #expect(state.life.family.stage == .single)
        #expect(state.narrative.scheduled.isEmpty)
    }

    @Test("asking somebody out at a networking event is the same year")
    func askOutSchedulesToo() {
        var balance = diaryBalance(lifeChance: 0)
        balance.networking = BalanceConfig.NetworkingBalance(
            contactsPerEventMin: 1, contactsPerEventMax: 1, romanceMinRapport: 0
        )
        var state = newGame(balance)
        state.day = 50
        state.networking.contacts = [
            Contact(
                id: UUID(), name: "Priya Nair", appearanceSeed: 5, archetype: .engineer,
                skills: SkillSet(coding: 50, design: 20, marketing: 10),
                askingSalary: 900, rapport: 80, metDay: 50, lastMetDay: 50
            )
        ]
        state.networking.pendingEvent = NetworkingEvent(
            venue: .rooftopParty, day: 50, expiresOnDay: 53,
            contactIDs: [state.networking.contacts[0].id], conversationsLeft: 3
        )
        Reducer.apply(
            .makeNetworkingOffer(contactID: state.networking.contacts[0].id, offer: .askOut),
            to: &state, balance: balance, content: calendar
        )
        #expect(state.life.family.stage == .dating)
        #expect(dated(state).map(\.day) == [415])
        #expect(state.familyDates(content: calendar).first?.label == "Your anniversary with Priya")
    }

    @Test("the anniversary takes the life roll's slot, draws nothing, and the miss is the deadline's answer")
    func theAnniversaryTakesTheSlot() throws {
        let balance = diaryBalance()
        var state = newGame(balance)
        state.day = 10
        state.life.meters.relationships = 100
        Reducer.apply(.advanceRelationship, to: &state, balance: balance, content: calendar)
        state.life.family.affection = 60
        state.life.schedule = .crunch

        // Day 375 is the date; 378 is the next interval day. Spend the
        // week's one evening on day 373, so "Go" is greyed when it lands.
        run(&state, to: 373, balance, calendar)
        // Answer anything the ordinary roll raised on the way, so the
        // calendar is not blocked by an unrelated beat.
        if let pending = state.narrative.pendingChoice {
            Reducer.apply(
                .resolveChoice(eventID: pending.id, optionIndex: pending.options[0].index),
                to: &state, balance: balance, content: calendar
            )
        }
        Reducer.apply(.spendTimeWithPartner(.call), to: &state, balance: balance, content: calendar)
        #expect(state.eveningsLeftThisWeek(balance) == 0)
        run(&state, to: 377, balance, calendar)
        #expect(state.narrative.pendingChoice == nil)
        let affectionBefore = state.life.family.affection

        let rngBefore = state.rng
        let events = Reducer.tick(&state, balance: balance, content: calendar)
        #expect(state.day == 378)
        let pending = try #require(state.narrative.pendingChoice)
        #expect(pending.id == FamilyCalendar.anniversaryEventID)
        #expect(pending.title == "Your anniversary with \(state.life.family.partnerName!) is this week.")
        #expect(pending.options[0].disabledReason == "No evenings left this week")
        #expect(events.contains {
            if case .narrativeChoice(FamilyCalendar.anniversaryEventID, _, 378) = $0 { true } else { false }
        })
        #expect(state.rng == rngBefore, "the slot was taken, not rolled: no draw")
        #expect(
            events.filter { $0.pausesTimeline }.count == 1,
            "one pause — the beat replaced the roll instead of joining it"
        )
        #expect(
            dated(state).map(\.day) == [740],
            "next year's is in the diary the day this one fires"
        )

        // Put it off past the deadline: the polite miss answers.
        let missed = run(&state, to: pending.respondByDay + 1, balance, calendar)
        #expect(state.narrative.pendingChoice == nil)
        #expect(state.life.family.affection == affectionBefore - 20)
        #expect(state.narrative.hasFlag(FamilyCalendar.missedFlag))
        #expect(missed.contains(.familyDateMissed(eventID: FamilyCalendar.anniversaryEventID, day: state.day)))
        #expect(missed.contains {
            if case .narrativeResolved(FamilyCalendar.anniversaryEventID, "miss", true, _) = $0 { true } else { false }
        })
        // The second act is thirty days out and requires the miss.
        let secondAct = try #require(state.narrative.scheduled.first { $0.eventID == "after_test" })
        #expect(secondAct.day == state.day + 30)
        run(&state, to: secondAct.day, balance, calendar)
        #expect(state.narrative.pendingChoice?.id == "after_test")
        #expect(state.narrative.pendingChoice?.title == "\(state.life.family.partnerName!) brings up the evening you didn't come to.")
    }

    @Test("a second act whose gate has closed is dropped, not told")
    func secondActChecksItsGate() {
        let balance = diaryBalance(lifeChance: 0)
        var state = newGame(balance)
        TestLife.setPartner(&state, stage: .partner)
        state.day = 100
        NarrativeSystem.schedule("after_test", source: .life, day: 105, state: &state)
        // The miss was made up for in the meantime: no flag, no scene.
        run(&state, to: 106, balance, calendar)
        #expect(state.narrative.pendingChoice == nil)
        #expect(state.narrative.scheduled.isEmpty)
    }

    @Test("the deadline's answer is the miss; choosing it by hand is a miss too")
    func choosingTheMissByHand() {
        let balance = diaryBalance(lifeChance: 0)
        var state = newGame(balance)
        TestLife.setPartner(&state, stage: .partner)
        state.day = 30
        state.life.family.affection = 60
        _ = Hook.fire(anniversary, &state, balance)
        let events = Reducer.apply(
            .resolveChoice(eventID: FamilyCalendar.anniversaryEventID, optionIndex: 1),
            to: &state, balance: balance, content: calendar
        )
        #expect(events.contains(.familyDateMissed(eventID: FamilyCalendar.anniversaryEventID, day: 30)))
        #expect(state.narrative.hasFlag(FamilyCalendar.missedFlag))
        #expect(state.life.family.affection == 40)

        // Going is not a miss.
        var went = newGame(balance)
        TestLife.setPartner(&went, stage: .partner)
        went.day = 30
        went.life.family.affection = 60
        _ = Hook.fire(anniversary, &went, balance)
        let wentEvents = Reducer.apply(
            .resolveChoice(eventID: FamilyCalendar.anniversaryEventID, optionIndex: 0),
            to: &went, balance: balance, content: calendar
        )
        #expect(!wentEvents.contains { if case .familyDateMissed = $0 { true } else { false } })
        #expect(!went.narrative.hasFlag(FamilyCalendar.missedFlag))
        #expect(went.life.family.affection == 75)
        #expect(went.life.eveningsSpentThisWeek == 1)
    }

    @Test("while the miss is on the books the twin fires in the anniversary's place")
    func missedVariant() {
        let balance = diaryBalance(lifeChance: 0)
        var state = newGame(balance)
        TestLife.setPartner(&state, stage: .partner, sinceDay: 10)
        state.day = 10
        FamilyCalendar.stageChanged(&state, balance: balance, content: calendar)
        state.narrative.flags.insert(FamilyCalendar.missedFlag)
        run(&state, to: 378, balance, calendar)
        #expect(state.narrative.pendingChoice?.id == "anniversary_again_test")
        #expect(state.narrative.pendingChoice?.title == "Your anniversary. You missed the last one too.")
        // Being there clears it, and next year is the plain anniversary again.
        Reducer.apply(
            .resolveChoice(eventID: "anniversary_again_test", optionIndex: 0),
            to: &state, balance: balance, content: calendar
        )
        #expect(!state.narrative.hasFlag(FamilyCalendar.missedFlag))
        #expect(dated(state).map(\.id) == [FamilyCalendar.anniversaryEventID])
    }

    @Test("past its window a dated beat fires like any other follow-up")
    func theWindowThenAFollowUp() {
        // A thirty-day roll: the date is 375, the interval days are 360
        // and 390, and 390 is outside the ten-day window — so the beat
        // gives up waiting on day 386 and pauses on its own.
        let balance = diaryBalance(lifeInterval: 30, lifeChance: 0)
        var state = newGame(balance)
        TestLife.setPartner(&state, stage: .partner, sinceDay: 10)
        state.day = 10
        FamilyCalendar.stageChanged(&state, balance: balance, content: calendar)
        run(&state, to: 385, balance, calendar)
        #expect(state.narrative.pendingChoice == nil, "still waiting for a slot inside the window")
        Reducer.tick(&state, balance: balance, content: calendar)
        #expect(state.day == 386)
        #expect(state.narrative.pendingChoice?.id == FamilyCalendar.anniversaryEventID)
    }

    @Test("a pending beat on the interval day leaves the roll and the stream exactly as today")
    func blockedSlotFallsThrough() {
        let balance = diaryBalance(lifeChance: 0)
        var state = newGame(balance)
        TestLife.setPartner(&state, stage: .partner, sinceDay: 10)
        state.day = 10
        FamilyCalendar.stageChanged(&state, balance: balance, content: calendar)
        run(&state, to: 377, balance, calendar)
        _ = Hook.fire(promiseBeat, &state, balance)
        let rngBefore = state.rng
        Reducer.tick(&state, balance: balance, content: calendar)
        #expect(state.narrative.pendingChoice?.id == "asks_future_test", "the beat on the table stays")
        #expect(state.rng != rngBefore, "the ordinary hit roll drew, as it always did")
        #expect(dated(state).map(\.id) == [FamilyCalendar.anniversaryEventID], "the date waits")
    }

    @Test("a child's birthday recurs every year, counted from the birth")
    func birthdaysRecur() throws {
        let balance = diaryBalance(lifeChance: 0)
        var state = newGame(balance)
        TestLife.setPartner(&state, stage: .married, sinceDay: 0)
        state.day = 100
        state.life.home = .house
        state.life.meters.relationships = 100
        Reducer.apply(.haveChild, to: &state, balance: balance, content: calendar)
        let child = try #require(state.life.family.children.first)
        state.life.family.children[0].name = "Kit"
        // (`setPartner` is a test shortcut past `advanceRelationship`, so
        // there is no anniversary here — only the birthday.)
        #expect(dated(state).map(\.day) == [465], "the first birthday, a year from the birth")
        let entry = try #require(state.narrative.scheduled.first { $0.eventID == FamilyCalendar.birthdayEventID })
        #expect(entry.childID == child.id)
        #expect(state.familyDates(content: calendar).map(\.label) == ["Kit's birthday"])
        #expect(state.nextFamilyDate(content: calendar)?.day == 465)
        #expect(state.nextPartnerDate(content: calendar) == nil)

        // The birthday lands on the first interval day after 465, which
        // is 476.
        run(&state, to: 476, balance, calendar)
        let pending = try #require(state.narrative.pendingChoice)
        #expect(pending.id == FamilyCalendar.birthdayEventID)
        #expect(pending.title == "Kit's birthday is on Saturday.")
        #expect(pending.options[0].label == "Go to Kit's party")
        #expect(pending.childID == child.id)
        #expect(
            state.narrative.scheduled.contains { $0.eventID == FamilyCalendar.birthdayEventID && $0.day == 830 },
            "next year's, from the birth day: \(dated(state))"
        )
    }

    @Test("one dated obligation per person per sixty days, and never in a stage's first ninety")
    func spacingAndGrace() {
        let balance = diaryBalance(lifeChance: 0)
        var state = newGame(balance)
        TestLife.setPartner(&state, stage: .partner, sinceDay: 300)
        state.day = 300
        FamilyCalendar.stageChanged(&state, balance: balance, content: calendar)
        #expect(dated(state).map(\.day) == [665])

        // A promise ninety days out lands on 690, within sixty of the
        // anniversary: it moves to sixty days after it.
        state.day = 600
        _ = Hook.fire(promiseBeat, &state, balance)
        Reducer.apply(
            .resolveChoice(eventID: "asks_future_test", optionIndex: 0),
            to: &state, balance: balance, content: calendar
        )
        #expect(dated(state).map(\.day) == [665, 725])
        #expect(state.familyDates(content: calendar).map(\.label) == [
            "Your anniversary with Sam", "The date you gave Sam",
        ])
        #expect(state.nextPartnerDate(content: calendar)?.day == 665)
        #expect(state.nextFamilyDate(content: calendar)?.eventID == FamilyCalendar.anniversaryEventID)

        // A promise inside the first ninety days of a stage waits for
        // them. (The answer is resolved against the catalog's definition,
        // so the shorter promise needs a catalog of its own.)
        var quick = promiseBeat
        quick.choices[0].followUpDelayDays = 10
        let quickCalendar = content([anniversary, quick, promiseDate])
        var fresh = newGame(balance)
        TestLife.setPartner(&fresh, stage: .partner, sinceDay: 300)
        fresh.day = 301
        _ = Hook.fire(quick, &fresh, balance)
        Reducer.apply(
            .resolveChoice(eventID: "asks_future_test", optionIndex: 0),
            to: &fresh, balance: balance, content: quickCalendar
        )
        #expect(dated(fresh).map(\.day) == [390])

        // A birthday is the child's, not the partner's: no grace, its own
        // spacing.
        var parent = newGame(balance)
        TestLife.setPartner(&parent, stage: .married, sinceDay: 300)
        parent.day = 300
        FamilyCalendar.stageChanged(&parent, balance: balance, content: calendar)
        let kit = TestLife.child(name: "Kit", bornDay: 310)
        parent.life.family.children = [kit]
        FamilyCalendar.childBorn(kit, &parent, balance: balance, content: calendar)
        #expect(dated(parent).map(\.day) == [665, 675])
    }

    @Test("a breakup keeps the children's dates")
    func breakupKeepsBirthdays() {
        let balance = diaryBalance(lifeChance: 0)
        var state = newGame(balance)
        TestLife.setPartner(&state, stage: .married, sinceDay: 0)
        let kit = TestLife.child(name: "Kit", bornDay: 20)
        state.life.family.children = [kit]
        state.day = 20
        FamilyCalendar.stageChanged(&state, balance: balance, content: calendar)
        FamilyCalendar.childBorn(kit, &state, balance: balance, content: calendar)
        #expect(dated(state).map(\.id) == [FamilyCalendar.anniversaryEventID, FamilyCalendar.birthdayEventID])

        state.life.meters.relationships = 0
        run(&state, to: 40, balance, calendar)
        #expect(state.life.family.stage == .single)
        #expect(dated(state).map(\.id) == [FamilyCalendar.birthdayEventID])
        // And the beat still reads, with nobody to name for the partner.
        run(&state, to: 392, balance, calendar)
        #expect(state.narrative.pendingChoice?.id == FamilyCalendar.birthdayEventID)
        #expect(state.narrative.pendingChoice?.title == "Kit's birthday is on Saturday.")
    }

    @Test("a catalog without the calendar schedules nothing")
    func noCalendarNoDates() {
        let balance = diaryBalance(lifeChance: 0)
        var state = newGame(balance)
        state.day = 10
        state.life.meters.relationships = 100
        Reducer.apply(.advanceRelationship, to: &state, balance: balance, content: content())
        #expect(state.life.family.stage == .dating)
        #expect(state.narrative.scheduled.isEmpty)
    }
}

// MARK: - Neutrality and saves

@Suite("The diary is invisible to a single, childless run")
struct DiaryNeutralityTests {
    @Test("a solo founder never has a date in the diary and the life roll is untouched")
    func singleRunNeverSchedules() throws {
        let balance = try BalanceConfig.loadBundled()
        let content = TestContent.bundled
        var state = GameState.newGame(companyName: "Solo", seed: 2_026, balance: balance)
        let bot = SoloSlowBot()
        for _ in 0..<400 {
            Reducer.tick(&state, balance: balance, content: content)
            for action in bot.actions(for: state, balance: balance, content: content) {
                Reducer.apply(action, to: &state, balance: balance, content: content)
            }
            #expect(state.life.family.stage == .single)
            #expect(state.familyDates(content: content).isEmpty)
            #expect(
                FamilyCalendar.dueDatedBeat(state, balance: balance, content: content) == nil,
                "the pre-emption path is never entered on day \(state.day)"
            )
            #expect(!state.narrative.hasFlag(FamilyCalendar.missedFlag))
        }
        #expect(state.day == 400)
    }

    @Test("the diary's fields survive a save, and an entry with no child encodes as it always did")
    func roundTrip() throws {
        let balance = diaryBalance(lifeChance: 0)
        var state = newGame(balance)
        TestLife.setPartner(&state, stage: .married, sinceDay: 0)
        let kit = TestLife.child(name: "Kit", bornDay: 20)
        state.life.family.children = [kit]
        state.day = 30
        state.life.schedule = .crunch
        state.life.eveningsSpentThisWeek = 1
        FamilyCalendar.stageChanged(&state, balance: balance, content: calendar)
        FamilyCalendar.childBorn(kit, &state, balance: balance, content: calendar)
        _ = NarrativeSystem.fireLife(birthday, state: &state, balance: balance, childID: kit.id)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(state)
        let decoded = try JSONDecoder().decode(GameState.self, from: data)
        #expect(decoded == state)
        #expect(decoded.narrative.pendingChoice?.childID == kit.id)
        #expect(decoded.narrative.pendingChoice?.options[0].disabledReason == "No evenings left this week")
        #expect(try encoder.encode(decoded) == data)

        let plain = try encoder.encode(ScheduledNarrativeEvent(day: 1, eventID: "x", source: .life))
        let text = String(decoding: plain, as: UTF8.self)
        #expect(!text.contains("childID"), "a nil child is not written: \(text)")
        let legacy = try JSONDecoder().decode(
            ScheduledNarrativeEvent.self, from: Data(#"{"day":1,"eventID":"x","source":"life"}"#.utf8)
        )
        #expect(legacy.childID == nil)
    }

    @Test("a relationships block without the diary decodes the shipped calendar")
    func balanceDecodesWithoutTheDiary() throws {
        let json = #"{"startingAffection":55,"affectionDrift":-0.3,"neglectDrift":-0.5,"neglectDays":14,"affectionRelationshipFactor":0.012,"partnerActivities":{},"stageMinAffection":{},"startingBond":10,"bondDecayPerDay":0.12,"bondPerSocialAction":6,"hangOut":{"cost":70,"affection":0,"energy":-4,"mood":5,"relationships":4,"cooldownDays":5},"mentorSkillGain":4.5,"mentorEnergyCost":8,"mentorCooldownDays":7,"bondOutputFactor":0.12,"bondMoraleTargetFactor":0.06,"bondLoyaltyPerDay":0.15}"#
        let decoded = try JSONDecoder().decode(
            BalanceConfig.RelationshipBalance.self, from: Data(json.utf8)
        )
        #expect(decoded.diary == .default)
        #expect(decoded.diary.windowDays == 10)
        #expect(decoded.diary.spacingDays == 60)
        #expect(decoded.diary.stageGraceDays == 90)
        #expect(decoded.diary.yearDays == 365)
        let bundled = try BalanceConfig.loadBundled()
        #expect(bundled.relationships.diary == .default)
    }
}
