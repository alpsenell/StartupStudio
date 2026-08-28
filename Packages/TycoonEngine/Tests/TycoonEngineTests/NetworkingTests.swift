import Foundation
import Testing
import TycoonContent
import TycoonEngine

/// A networking balance with a real floor on it. Rapport decay and the
/// holding roll are off unless a test asks for them, so nothing drifts
/// under an assertion that isn't about drift.
private func networkingBalance(
    contactsPerEventMin: Int = 4,
    contactsPerEventMax: Int = 4,
    conversationsPerEvent: Int = 4,
    talkSuccessBase: Double = 0.55,
    rapportDecayPerDay: Double = 0,
    holdingExitChance: Double = 0,
    holdingFoldChance: Double = 0,
    holdingWeeklyGrowth: Double = 0,
    holdingWeeklyVolatility: Double = 0,
    maxContacts: Int = 40
) -> BalanceConfig.NetworkingBalance {
    BalanceConfig.NetworkingBalance(
        contactsPerEventMin: contactsPerEventMin,
        contactsPerEventMax: contactsPerEventMax,
        conversationsPerEvent: conversationsPerEvent,
        conversationTurnsDivisor: 35,
        eventDurationDays: 3,
        talkSuccessBase: talkSuccessBase,
        relationshipsPerEvent: 4,
        holdingWeeklyGrowth: holdingWeeklyGrowth,
        holdingWeeklyVolatility: holdingWeeklyVolatility,
        holdingExitChance: holdingExitChance,
        holdingFoldChance: holdingFoldChance,
        rapportDecayPerDay: rapportDecayPerDay,
        maxContacts: maxContacts
    )
}

private func balance(
    networking: BalanceConfig.NetworkingBalance = networkingBalance()
) -> BalanceConfig {
    TestBalance.make(
        candidateRefreshDays: 10_000,
        contractOfferRefreshDays: 10_000,
        eventCheckIntervalDays: 10_000,
        life: TestBalance.quietLife,
        networking: networking
    )
}

private func newGame(_ balance: BalanceConfig) -> GameState {
    var state = GameState.newGame(companyName: "Acme", seed: 11, balance: balance)
    state.life.wallet = 250_000
    TestLife.pinPeak(&state)
    return state
}

/// Puts one contact in a room with the founder, on the terms the test
/// wants, without going through a weekend.
private func room(
    _ state: inout GameState,
    archetype: ContactArchetype = .engineer,
    rapport: Double = 0,
    interest: Double = 0,
    valuation: Int = 200_000,
    conversations: Int = 4
) -> UUID {
    let id = UUID()
    state.networking.contacts.append(Contact(
        id: id,
        name: "Robin Vale",
        appearanceSeed: 42,
        archetype: archetype,
        skills: SkillSet(coding: 60, design: 40, marketing: 40),
        askingSalary: 800,
        companyName: archetype.hasCompany ? "Vale Systems" : nil,
        companyValuation: archetype.hasCompany ? valuation : 0,
        rapport: rapport,
        interest: interest,
        metDay: state.day,
        lastMetDay: state.day
    ))
    state.networking.pendingEvent = NetworkingEvent(
        venue: .rooftopParty,
        day: state.day,
        expiresOnDay: state.day + 3,
        contactIDs: [id],
        conversationsLeft: conversations
    )
    return id
}

// MARK: - Opening a room

@Suite("Networking events")
struct NetworkingEventTests {
    @Test("A networking weekend fills a room")
    func weekendOpensARoom() {
        let config = balance()
        var state = newGame(config)
        state.life.plannedActivity = .networking
        let content = TestContent.bundled

        // Day 6 → the tick lands on day 7, the weekly boundary.
        state.day = 6
        let events = Reducer.tick(&state, balance: config, content: content)

        let event = state.networking.pendingEvent
        #expect(event != nil)
        #expect(event?.contactIDs.count == 4)
        #expect(state.networking.contacts.count == 4)
        #expect(events.contains { if case .networkingEventStarted = $0 { true } else { false } })
    }

    @Test("A balance with no networking floor resolves the weekend as it always did")
    func disabledByDefault() {
        let config = TestBalance.make(
            candidateRefreshDays: 10_000,
            contractOfferRefreshDays: 10_000,
            eventCheckIntervalDays: 10_000,
            life: TestBalance.quietLife
        )
        var state = newGame(config)
        state.life.plannedActivity = .networking
        state.day = 6

        Reducer.tick(&state, balance: config, content: TestContent.bundled)
        #expect(state.networking.pendingEvent == nil)
        #expect(state.networking.contacts.isEmpty)
    }

    @Test("Opening a room draws only from the social stream")
    func drawsOnlyFromTheSocialStream() {
        let config = balance()
        var state = newGame(config)
        state.life.plannedActivity = .networking
        state.day = 6

        var quiet = state
        quiet.life.plannedActivity = .rest

        let content = TestContent.bundled
        Reducer.tick(&state, balance: config, content: content)
        Reducer.tick(&quiet, balance: config, content: content)

        // The world's own streams walked the same path whether or not the
        // founder went out on Friday.
        #expect(state.rng == quiet.rng)
        #expect(state.worldRNG == quiet.worldRNG)
        #expect(state.investorRNG == quiet.investorRNG)
        #expect(state.socialRNG != quiet.socialRNG)
    }

    @Test("The room closes on its own")
    func roomExpires() {
        let config = balance()
        var state = newGame(config)
        _ = room(&state)
        let content = TestContent.tiny()

        Reducer.tick(&state, balance: config, content: content)
        #expect(state.networking.pendingEvent != nil)
        for _ in 0..<3 { Reducer.tick(&state, balance: config, content: content) }
        #expect(state.networking.pendingEvent == nil)
    }

    @Test("Walking out closes the room and pays the evening's relationships")
    func leavingPaysOut() {
        let config = balance()
        var state = newGame(config)
        state.life.meters.relationships = 50
        _ = room(&state)

        Reducer.apply(.leaveNetworkingEvent, to: &state, balance: config, content: TestContent.tiny())
        #expect(state.networking.pendingEvent == nil)
        #expect(state.life.meters.relationships == 54)
    }
}

// MARK: - Conversation

@Suite("Networking conversation")
struct NetworkingConversationTests {
    @Test("Small talk always lands and costs one exchange")
    func smallTalkLands() {
        let config = balance()
        var state = newGame(config)
        let id = room(&state)

        Reducer.apply(
            .talkToContact(contactID: id, topic: .smallTalk),
            to: &state, balance: config, content: TestContent.tiny()
        )

        #expect((state.networking.contact(id)?.rapport ?? 0) > 0)
        #expect(state.networking.pendingEvent?.conversationsLeft == 3)
        #expect(state.life.meters.energy < 100)
    }

    @Test("Listening is how you learn what somebody wants")
    func listeningReveals() {
        let config = balance()
        var state = newGame(config)
        let id = room(&state)
        #expect(state.networking.contact(id)?.isRevealed == false)

        Reducer.apply(
            .talkToContact(contactID: id, topic: .listen),
            to: &state, balance: config, content: TestContent.tiny()
        )
        #expect(state.networking.contact(id)?.isRevealed == true)
    }

    @Test("A pitch that lands moves interest; one that doesn't costs rapport")
    func pitchIsAGamble() {
        var state = newGame(balance())
        let id = room(&state, rapport: 40)
        let content = TestContent.tiny()

        // A balance where the pitch cannot miss, and one where it cannot land.
        let sure = balance(networking: networkingBalance(talkSuccessBase: 10))
        let doomed = balance(networking: networkingBalance(talkSuccessBase: -10))

        var lucky = state
        Reducer.apply(.talkToContact(contactID: id, topic: .pitch),
                      to: &lucky, balance: sure, content: content)
        var unlucky = state
        Reducer.apply(.talkToContact(contactID: id, topic: .pitch),
                      to: &unlucky, balance: doomed, content: content)

        #expect((lucky.networking.contact(id)?.interest ?? 0) > 0)
        #expect((lucky.networking.contact(id)?.rapport ?? 0) > 40)
        #expect((unlucky.networking.contact(id)?.rapport ?? 100) < 40)
    }

    @Test("The last exchange ends the evening")
    func lastExchangeClosesTheRoom() {
        let config = balance()
        var state = newGame(config)
        let id = room(&state, conversations: 1)

        let events = Reducer.apply(
            .talkToContact(contactID: id, topic: .smallTalk),
            to: &state, balance: config, content: TestContent.tiny()
        )
        #expect(state.networking.pendingEvent == nil)
        #expect(events.contains { if case .networkingEventEnded = $0 { true } else { false } })
    }

    @Test("Nobody to talk to once the exchanges are gone")
    func exhaustedRoomRefuses() {
        let config = balance()
        var state = newGame(config)
        let id = room(&state, conversations: 1)
        let content = TestContent.tiny()

        Reducer.apply(.talkToContact(contactID: id, topic: .smallTalk),
                      to: &state, balance: config, content: content)
        #expect(Reducer.apply(.talkToContact(contactID: id, topic: .smallTalk),
                              to: &state, balance: config, content: content).isEmpty)
    }

    @Test("Rapport fades for somebody the founder never calls")
    func rapportDecays() {
        let config = balance(networking: networkingBalance(rapportDecayPerDay: 1))
        var state = newGame(config)
        let id = room(&state, rapport: 50)
        let content = TestContent.tiny()

        for _ in 0..<5 { Reducer.tick(&state, balance: config, content: content) }
        #expect((state.networking.contact(id)?.rapport ?? 0) == 45)
    }
}

// MARK: - Deals

@Suite("Networking deals")
struct NetworkingOfferTests {
    @Test("A stranger will not take the job")
    func recruitNeedsRapport() {
        let config = balance()
        var state = newGame(config)
        let id = room(&state, rapport: 5, interest: 90)

        #expect(Reducer.apply(
            .makeNetworkingOffer(contactID: id, offer: .recruit),
            to: &state, balance: config, content: TestContent.tiny()
        ).isEmpty)
        #expect(state.headcount == 1)
        #expect(state.networkingOfferBlocker(.recruit, contactID: id, balance: config) != nil)
    }

    @Test("Somebody who likes you and knows what you do takes the job")
    func recruitHires() {
        let config = balance()
        var state = newGame(config)
        let id = room(&state, rapport: 80, interest: 90)

        let events = Reducer.apply(
            .makeNetworkingOffer(contactID: id, offer: .recruit),
            to: &state, balance: config, content: TestContent.tiny()
        )

        #expect(state.headcount == 2)
        #expect(state.employees.last?.id == id)
        // They walk in already knowing the founder.
        #expect((state.employees.last?.founderBond ?? 0) == 40)
        #expect(state.networking.contact(id)?.outcome == .hired)
        // They were the only person in the room, so the evening is over
        // rather than an empty floor waiting to expire.
        #expect(state.networking.pendingEvent == nil)
        #expect(events.contains { if case .contactRecruited = $0 { true } else { false } })
    }

    @Test("An equity hire costs the founder's own company, not their payroll")
    func equityHireCostsEquity() {
        let config = balance()
        var state = newGame(config)
        let id = room(&state, rapport: 90, interest: 90)
        let ask = try! #require(state.networking.contact(id)).equityAsk(config.networking)

        Reducer.apply(
            .makeNetworkingOffer(contactID: id, offer: .equityHire),
            to: &state, balance: config, content: TestContent.tiny()
        )

        #expect(abs(state.founderEquity - (100 - ask)) < 1e-9)
        #expect(state.networking.grants.count == 1)
        #expect(state.networking.grants.first?.reason == .partner)
        // Cheaper on payroll than a salaried hire, and they mean it.
        #expect((state.employees.last?.weeklySalary ?? 0) < 800)
        #expect((state.employees.last?.loyalty ?? 0) > 80)
    }

    @Test("Backing somebody's startup spends the wallet and books a stake")
    func backingBuysAStake() {
        let config = balance()
        var state = newGame(config)
        let id = room(&state, archetype: .founder, rapport: 60, valuation: 200_000)
        let contact = try! #require(state.networking.contact(id))
        let price = contact.stakePrice(config.networking)

        Reducer.apply(
            .makeNetworkingOffer(contactID: id, offer: .backThem),
            to: &state, balance: config, content: TestContent.tiny()
        )

        #expect(state.life.wallet == 250_000 - price)
        #expect(state.networking.holdings.count == 1)
        #expect(state.networking.holdings.first?.stakePercent == contact.stakeOnOffer(config.networking))
        // Company cash is untouched: this is the founder's own money.
        #expect(state.company.cash == config.startingCash)
    }

    @Test("Rapport buys a bigger stake at a better price")
    func rapportImprovesTheTerms() {
        let config = balance().networking
        let base = Contact(
            id: UUID(), name: "Robin", appearanceSeed: 1, archetype: .founder,
            skills: SkillSet(coding: 50, design: 50, marketing: 50), askingSalary: 500,
            companyName: "Vale", companyValuation: 200_000, rapport: 45,
            metDay: 0, lastMetDay: 0
        )
        var warm = base
        warm.rapport = 95

        #expect(warm.stakeOnOffer(config) > base.stakeOnOffer(config))
        // A bigger slice, but the discount means it does not cost
        // proportionally more.
        let basePerPoint = Double(base.stakePrice(config)) / base.stakeOnOffer(config)
        let warmPerPoint = Double(warm.stakePrice(config)) / warm.stakeOnOffer(config)
        #expect(warmPerPoint < basePerPoint)
    }

    @Test("Only investors write cheques")
    func onlyBackersInvest() {
        let config = balance()
        var state = newGame(config)
        let id = room(&state, archetype: .engineer, rapport: 90, interest: 90)

        #expect(
            state.networkingOfferBlocker(.takeTheirMoney, contactID: id, balance: config)
                == "They don't write cheques"
        )
    }

    @Test("An angel's money lands in company cash and costs company equity")
    func angelRound() {
        let config = balance()
        var state = newGame(config)
        let id = room(&state, archetype: .investor, rapport: 90, interest: 90)
        let terms = try! #require(state.networking.contact(id))
            .angelTerms(config.networking, dealFactor: state.founderDealFactor(config))

        Reducer.apply(
            .makeNetworkingOffer(contactID: id, offer: .takeTheirMoney),
            to: &state, balance: config, content: TestContent.tiny()
        )

        #expect(state.company.cash == config.startingCash + terms.amount)
        #expect(abs(state.founderEquity - (100 - terms.equity)) < 1e-9)
        #expect(state.networking.grants.first?.reason == .angel)
    }

    @Test("An evening that went unusually well can end in a relationship")
    func askingSomebodyOut() {
        let config = balance()
        var state = newGame(config)
        let id = room(&state, rapport: 90)

        let events = Reducer.apply(
            .makeNetworkingOffer(contactID: id, offer: .askOut),
            to: &state, balance: config, content: TestContent.tiny()
        )

        #expect(state.life.family.stage == .dating)
        #expect(state.life.family.partnerName == "Robin Vale")
        #expect(state.life.family.partnerContactID == id)
        #expect(state.life.family.affection > 0)
        #expect(events.contains { if case .romanceStarted = $0 { true } else { false } })
    }

    @Test("A founder who is already seeing somebody cannot ask")
    func alreadyTaken() {
        let config = balance()
        var state = newGame(config)
        TestLife.setPartner(&state, stage: .married)
        let id = room(&state, rapport: 95)

        #expect(
            state.networkingOfferBlocker(.askOut, contactID: id, balance: config)
                == "You're seeing someone"
        )
        #expect(Reducer.apply(
            .makeNetworkingOffer(contactID: id, offer: .askOut),
            to: &state, balance: config, content: TestContent.tiny()
        ).isEmpty)
    }
}

// MARK: - The portfolio

@Suite("Founder holdings")
struct HoldingTests {
    private func stateHolding(
        _ config: BalanceConfig,
        valuation: Int = 200_000,
        stake: Double = 10
    ) -> GameState {
        var state = newGame(config)
        state.networking.holdings = [Holding(
            id: UUID(), companyName: "Vale Systems", stakePercent: stake,
            invested: 20_000, valuation: valuation, boughtDay: 0
        )]
        return state
    }

    @Test("A holding is worth its share of the valuation")
    func currentValue() {
        let holding = Holding(
            id: UUID(), companyName: "Vale", stakePercent: 12.5,
            invested: 10_000, valuation: 400_000, boughtDay: 0
        )
        #expect(holding.currentValue == 50_000)
    }

    @Test("An exit pays the founder's wallet, not the company")
    func exitPaysTheWallet() {
        let config = balance(networking: networkingBalance(holdingExitChance: 1))
        var state = stateHolding(config)
        state.day = 6

        let events = Reducer.tick(&state, balance: config, content: TestContent.tiny())

        #expect(state.networking.holdings.isEmpty)
        // Well clear of the week's rent, which also settled on this tick.
        #expect(state.life.wallet > 250_000)
        #expect(events.contains { if case .stakeExited = $0 { true } else { false } })
    }

    @Test("A fold takes the money with it")
    func foldLosesTheStake() {
        let config = balance(networking: networkingBalance(holdingFoldChance: 1))
        var state = stateHolding(config)
        state.day = 6

        let events = Reducer.tick(&state, balance: config, content: TestContent.tiny())

        #expect(state.networking.holdings.isEmpty)
        // Nothing came back: the wallet only moved by the week's rent.
        #expect(state.life.wallet < 250_000)
        #expect(events.contains { if case .stakeLost = $0 { true } else { false } })
    }

    @Test("Holdings only settle on the weekly boundary")
    func settlesWeekly() {
        let config = balance(networking: networkingBalance(holdingExitChance: 1))
        var state = stateHolding(config)
        state.day = 3

        Reducer.tick(&state, balance: config, content: TestContent.tiny())
        #expect(state.networking.holdings.count == 1)
    }
}
