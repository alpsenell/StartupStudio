import Foundation
import Testing
import TycoonContent
import TycoonEngine

// The boomerang: anyone who leaves — quit, poached, fired — becomes a
// contact with the same id and face, and can be run into and hired back.

/// A networking floor with a fixed room size, no rapport decay and no
/// holding roll, so nothing drifts under an assertion that isn't about it.
private func networkingBalance(roomSize: Int = 4, maxContacts: Int = 40) -> BalanceConfig.NetworkingBalance {
    BalanceConfig.NetworkingBalance(
        contactsPerEventMin: roomSize,
        contactsPerEventMax: roomSize,
        conversationsPerEvent: 4,
        conversationTurnsDivisor: 35,
        eventDurationDays: 3,
        talkSuccessBase: 0.55,
        relationshipsPerEvent: 4,
        holdingWeeklyGrowth: 0,
        holdingWeeklyVolatility: 0,
        holdingExitChance: 0,
        holdingFoldChance: 0,
        rapportDecayPerDay: 0,
        maxContacts: maxContacts
    )
}

/// Bonds do not decay either, so "rapport equals the bond they left with"
/// is a number the test can name.
private func balance(
    staff: BalanceConfig.StaffBalance = TestBalance.frozenStaff,
    networking: BalanceConfig.NetworkingBalance = networkingBalance()
) -> BalanceConfig {
    var relationships = BalanceConfig.RelationshipBalance.default
    relationships.bondDecayPerDay = 0
    return TestBalance.make(
        candidateRefreshDays: 10_000,
        contractOfferRefreshDays: 10_000,
        eventCheckIntervalDays: 10_000,
        life: TestBalance.quietLife,
        staff: staff,
        networking: networking,
        relationships: relationships
    )
}

private func newGame(_ balance: BalanceConfig) -> GameState {
    var state = GameState.newGame(companyName: "Acme", seed: 11, balance: balance)
    state.life.wallet = 250_000
    state.company.cash = 500_000
    TestLife.pinPeak(&state)
    return state
}

/// Somebody on payroll with a history: a bond, a face, a job.
@discardableResult
private func hire(
    _ state: inout GameState,
    name: String = "Marco Reyes",
    role: EmployeeRole = .backend,
    bond: Double = 60,
    morale: Double = 70,
    weeklySalary: Int = 900,
    appearanceSeed: UInt64 = 7
) -> Employee {
    let employee = Employee(
        id: UUID(),
        name: name,
        skills: SkillSet(coding: 70, design: 30, marketing: 20),
        weeklySalary: weeklySalary,
        assignment: .idle,
        isFounder: false,
        hiredDay: state.day,
        appearanceSeed: appearanceSeed,
        morale: morale,
        level: .mid,
        loyalty: 50,
        role: role,
        founderBond: bond
    )
    state.employees.append(employee)
    return employee
}

/// A former employee already in the book, on the terms the test wants.
@discardableResult
private func alum(
    _ state: inout GameState,
    name: String = "Marco Reyes",
    role: EmployeeRole = .backend,
    rapport: Double = 60,
    interest: Double = 90,
    askingSalary: Int = 1_200,
    leftDay: Int = 0,
    appearanceSeed: UInt64 = 7,
    outcome: ContactOutcome? = nil
) -> Contact {
    let contact = Contact(
        id: UUID(),
        name: name,
        appearanceSeed: appearanceSeed,
        archetype: role.contactArchetype,
        skills: SkillSet(coding: 50, design: 30, marketing: 20),
        askingSalary: askingSalary,
        rapport: rapport,
        interest: interest,
        metDay: 0,
        lastMetDay: leftDay,
        isRevealed: true,
        outcome: outcome,
        leftDay: leftDay,
        leftReason: .quit,
        leftRole: role
    )
    state.networking.contacts.append(contact)
    return contact
}

/// A stranger the founder met at a party.
@discardableResult
private func stranger(_ state: inout GameState, name: String, rapport: Double) -> Contact {
    let contact = Contact(
        id: UUID(),
        name: name,
        appearanceSeed: 99,
        archetype: .marketer,
        skills: SkillSet(coding: 30, design: 30, marketing: 60),
        askingSalary: 800,
        rapport: rapport,
        metDay: 0,
        lastMetDay: state.day
    )
    state.networking.contacts.append(contact)
    return contact
}

private func openRoom(_ state: inout GameState, _ balance: BalanceConfig) -> [GameEvent] {
    state.life.plannedActivity = .networking
    // Day 6 → the tick lands on day 7, the weekly boundary.
    state.day = 6
    return Reducer.tick(&state, balance: balance, content: TestContent.bundled)
}

private func joinedBook(_ events: [GameEvent]) -> Bool {
    events.contains { if case .alumnusJoinedBook = $0 { true } else { false } }
}

// MARK: - Leaving

@Suite("Alumni — leaving")
struct AlumniDepartureTests {
    @Test("Somebody you let go is in the address book, on the terms they left with")
    func firingPutsThemInTheBook() throws {
        let config = balance()
        var state = newGame(config)
        state.day = 45
        let employee = hire(&state, bond: 60, morale: 70)

        let events = Reducer.apply(.fire(employeeID: employee.id), to: &state, balance: config, content: TestContent.tiny())

        let contact = try #require(state.networking.contact(employee.id))
        #expect(state.employees.count == 1)
        #expect(contact.isOpen)
        #expect(contact.isAlumnus)
        #expect(contact.name == "Marco Reyes")
        #expect(contact.appearanceSeed == 7)
        #expect(contact.archetype == .engineer)
        #expect(contact.skills == employee.skills)
        #expect(contact.rapport == 60)
        #expect(contact.interest == 70)
        #expect(contact.isRevealed)
        #expect(contact.metDay == 45)
        #expect(contact.lastMetDay == 45)
        #expect(contact.leftDay == 45)
        #expect(contact.leftReason == .fired)
        #expect(contact.leftRole == .backend)
        // Fair pay and ten percent: the premium of somebody who is not on
        // the market.
        let fair = config.fairWeeklyPay(for: employee)
        #expect(contact.askingSalary == Int((fair * 1.1).rounded()))
        #expect(joinedBook(events))
    }

    @Test("Fire a stranger and you burned them: rapport zero, closed")
    func burnedFiringClosesThem() throws {
        let config = balance()
        var state = newGame(config)
        let employee = hire(&state, bond: 10)

        let events = Reducer.apply(.fire(employeeID: employee.id), to: &state, balance: config, content: TestContent.tiny())

        let contact = try #require(state.networking.contact(employee.id))
        #expect(contact.rapport == 0)
        #expect(contact.outcome == .lost)
        #expect(!contact.isOpen)
        #expect(contact.leftReason == .fired)
        // They still went into the book — as history.
        #expect(joinedBook(events))
    }

    @Test("Somebody who quits leaves with the bond they had")
    func quittingPutsThemInTheBook() throws {
        var staff = BalanceConfig.StaffBalance.standard
        staff.moraleAdaptRate = 1
        staff.quitMoraleThreshold = 40
        staff.quitStreakDays = 3
        let config = balance(staff: staff)
        var state = newGame(config)
        // Far under fair pay: the morale target sits below the threshold.
        let employee = hire(&state, bond: 55, weeklySalary: 300)

        var quit = false
        var joined = false
        while !quit, state.day < 8 {
            let events = Reducer.tick(&state, balance: config, content: TestContent.tiny())
            quit = events.contains { if case .employeeQuit = $0 { true } else { false } }
            joined = joinedBook(events)
        }
        #expect(quit)
        // Same tick as the quit, in the same event list.
        #expect(joined)
        let contact = try #require(state.networking.contact(employee.id))
        #expect(contact.isOpen)
        #expect(contact.leftReason == .quit)
        #expect(contact.rapport == 55)
        // They quit miserable: the founder will have to pitch them again.
        #expect(contact.interest < config.networking.joinMinInterest)
        #expect(contact.leftDay == state.day)
    }

    @Test("A poached employee asks for the number they left for")
    func poachSetsTheAskAtTheRivalsNumber() throws {
        let config = balance()
        var state = newGame(config)
        let employee = hire(&state, bond: 40)
        state.rivals.pendingPoach = PoachOffer(
            rivalID: UUID(), employeeID: employee.id, offeredWeeklySalary: 1_500,
            respondByDay: state.day + 3
        )

        let events = Reducer.apply(.declinePoachOffer, to: &state, balance: config, content: TestContent.tiny())

        let contact = try #require(state.networking.contact(employee.id))
        #expect(state.employees.count == 1)
        #expect(contact.askingSalary == 1_500)
        #expect(contact.leftReason == .poached)
        #expect(contact.rapport == 40)
        #expect(contact.isOpen)
        #expect(joinedBook(events))
    }

    @Test("Creating the contact draws nothing from any stream")
    func departureDrawsNothing() {
        let config = balance()
        var state = newGame(config)
        let employee = hire(&state)
        let before = state

        Reducer.apply(.fire(employeeID: employee.id), to: &state, balance: config, content: TestContent.tiny())

        #expect(state.socialRNG == before.socialRNG)
        #expect(state.worldRNG == before.worldRNG)
        #expect(state.investorRNG == before.investorRNG)
        #expect(state.rng == before.rng)
    }

    @Test("Somebody hired from the book re-opens under the same entry")
    func aContactWhoWasHiredReopens() throws {
        let config = balance()
        var state = newGame(config)
        let original = alum(&state, rapport: 80, interest: 90, leftDay: 0)
        // Not actually an alum yet for this test: make them a plain warm
        // contact standing in a room.
        state.networking.contacts[0].leftDay = nil
        state.networking.contacts[0].leftReason = nil
        state.networking.contacts[0].leftRole = nil
        state.networking.contacts[0].metDay = 3
        state.networking.pendingEvent = NetworkingEvent(
            venue: .demoDay, day: state.day, expiresOnDay: state.day + 3,
            contactIDs: [original.id], conversationsLeft: 4
        )
        Reducer.apply(
            .makeNetworkingOffer(contactID: original.id, offer: .recruit),
            to: &state, balance: config, content: TestContent.tiny()
        )
        #expect(state.networking.contact(original.id)?.outcome == .hired)
        state.day = 120

        Reducer.apply(.fire(employeeID: original.id), to: &state, balance: config, content: TestContent.tiny())

        #expect(state.networking.contacts.count == 1)
        let contact = try #require(state.networking.contact(original.id))
        #expect(contact.isOpen)
        #expect(contact.leftReason == .fired)
        #expect(contact.leftDay == 120)
        #expect(contact.metDay == 3)
        #expect(contact.archetype == original.archetype)
        // The bond they walked in with (rapport / 2), unchanged with no decay.
        #expect(contact.rapport == 40)
    }
}

// MARK: - Off-screen

@Suite("Alumni — off-screen")
struct AlumniDriftTests {
    @Test("A former employee gets better every quarter away")
    func theyGetBetterEveryQuarter() throws {
        let config = balance()
        var state = newGame(config)
        let marco = alum(&state, role: .backend, leftDay: 0)
        let gone = alum(&state, name: "Priya Shah", role: .designer, leftDay: 0, outcome: .lost)

        state.day = 90
        Reducer.tick(&state, balance: config, content: TestContent.tiny())
        #expect(state.networking.contact(marco.id)?.skills.coding == 53)
        #expect(state.networking.contact(marco.id)?.skills.design == 30)

        while state.day < 182 {
            Reducer.tick(&state, balance: config, content: TestContent.tiny())
        }
        #expect(state.networking.contact(marco.id)?.skills.coding == 56)
        // Somebody who is history stays history.
        #expect(state.networking.contact(gone.id)?.skills.design == 30)
    }

    @Test("A prodigy who leaves founds something, and you can back it")
    func aProdigyFoundsSomething() throws {
        let config = balance()
        var state = newGame(config)
        let seed = try #require((0..<20_000).first { candidate in
            TraitEffects.derivedTraitIDs(appearanceSeed: UInt64(candidate)).contains("prodigy")
        })
        let prodigy = alum(&state, name: "Marco Reyes", rapport: 60, leftDay: 0, appearanceSeed: UInt64(seed))
        let plain = alum(&state, name: "Priya Shah", role: .designer, leftDay: 0, appearanceSeed: 1)
        #expect(!TraitEffects.derivedTraitIDs(appearanceSeed: 1).contains("prodigy"))
        #expect(!TraitEffects.derivedTraitIDs(appearanceSeed: 1).contains("showman"))

        // A tick lands on the next day: 178 → 179 is still nothing, 179 →
        // 180 is the founding.
        state.day = 178
        Reducer.tick(&state, balance: config, content: TestContent.tiny())
        #expect(state.networking.contact(prodigy.id)?.companyValuation == 0)
        Reducer.tick(&state, balance: config, content: TestContent.tiny())
        #expect(state.day == 180)

        let founded = try #require(state.networking.contact(prodigy.id))
        #expect(founded.companyName?.hasPrefix("Reyes ") == true)
        // 100 skill points × 1,500.
        #expect(founded.companyValuation == 150_000)
        #expect(founded.runsACompany)
        #expect(state.networking.contact(plain.id)?.companyValuation == 0)
        #expect(state.networking.contact(plain.id)?.runsACompany == false)

        // `backThem` opens, on the same terms as any founder in the book.
        state.networking.pendingEvent = NetworkingEvent(
            venue: .demoDay, day: state.day, expiresOnDay: state.day + 3,
            contactIDs: [prodigy.id], conversationsLeft: 4
        )
        #expect(state.networkingOfferBlocker(.backThem, contactID: prodigy.id, balance: config) == nil)
        Reducer.apply(
            .makeNetworkingOffer(contactID: prodigy.id, offer: .backThem),
            to: &state, balance: config, content: TestContent.tiny()
        )
        #expect(state.networking.holdings.first?.companyName == founded.companyName)
        #expect(state.networking.contact(prodigy.id)?.outcome == .backed)
    }
}

// MARK: - Coming back

@Suite("Alumni — coming back")
struct AlumniReturnTests {
    @Test("An alum takes a stranger's slot in the room")
    func anAlumTakesAStrangersSlot() throws {
        let config = balance()
        var state = newGame(config)
        stranger(&state, name: "Warm One", rapport: 80)
        stranger(&state, name: "Warm Two", rapport: 70)
        let marco = alum(&state, rapport: 20)

        openRoom(&state, config)

        let room = try #require(state.networking.pendingEvent)
        #expect(room.contactIDs.count == 4)
        #expect(room.contactIDs.contains(marco.id))
        // Two returning, the alum, and one stranger rolled.
        #expect(state.networking.contacts.count == 4)
    }

    @Test("A room with no open alumni draws exactly as it did")
    func aRoomWithNoAlumniDrawsAsItDid() throws {
        let config = balance()
        var plain = newGame(config)
        stranger(&plain, name: "Warm One", rapport: 80)
        stranger(&plain, name: "Warm Two", rapport: 70)
        var withHistory = plain
        alum(&withHistory, rapport: 20, outcome: .lost)

        openRoom(&plain, config)
        openRoom(&withHistory, config)

        #expect(plain.socialRNG == withHistory.socialRNG)
        #expect(plain.networking.contacts.count == 4)
        #expect(withHistory.networking.contacts.count == 5)
        #expect(plain.networking.pendingEvent?.contactIDs.count == 4)
        #expect(withHistory.networking.pendingEvent?.contactIDs.count == 4)
    }

    @Test("The last stranger's slot is never the alum's")
    func theRoomKeepsAStranger() throws {
        let config = balance(networking: networkingBalance(roomSize: 3))
        var state = newGame(config)
        stranger(&state, name: "Warm One", rapport: 80)
        stranger(&state, name: "Warm Two", rapport: 70)
        let marco = alum(&state, rapport: 20)

        openRoom(&state, config)

        let room = try #require(state.networking.pendingEvent)
        #expect(room.contactIDs.count == 3)
        #expect(!room.contactIDs.contains(marco.id))
        #expect(state.networking.contacts.count == 4)
    }

    @Test("Hiring them back restores the bond, the job, and the new ask")
    func recruitingThemBackRestoresTheBond() throws {
        let config = balance()
        var state = newGame(config)
        state.day = 200
        let marco = alum(&state, role: .qa, rapport: 60, interest: 90, askingSalary: 1_200, leftDay: 60)
        state.networking.pendingEvent = NetworkingEvent(
            venue: .demoDay, day: state.day, expiresOnDay: state.day + 3,
            contactIDs: [marco.id], conversationsLeft: 4
        )

        let events = Reducer.apply(
            .makeNetworkingOffer(contactID: marco.id, offer: .recruit),
            to: &state, balance: config, content: TestContent.tiny()
        )

        let employee = try #require(state.employee(id: marco.id))
        #expect(employee.weeklySalary == 1_200)
        #expect(employee.hiredDay == 200)
        #expect(employee.founderBond == 60)
        #expect(employee.role == .qa)
        #expect(employee.appearanceSeed == 7)
        #expect(employee.skills == marco.skills)
        #expect(state.networking.contact(marco.id)?.outcome == .hired)
        #expect(events.contains { if case .contactRecruited = $0 { true } else { false } })
    }

    @Test("Somebody the founder burned cannot be hired back")
    func aBurnedAlumRefuses() {
        let config = balance()
        var state = newGame(config)
        let marco = alum(&state, rapport: 0, outcome: .lost)
        state.networking.pendingEvent = NetworkingEvent(
            venue: .demoDay, day: state.day, expiresOnDay: state.day + 3,
            contactIDs: [marco.id], conversationsLeft: 4
        )
        #expect(state.networkingOfferBlocker(.recruit, contactID: marco.id, balance: config) != nil)
        #expect(Reducer.apply(
            .makeNetworkingOffer(contactID: marco.id, offer: .recruit),
            to: &state, balance: config, content: TestContent.tiny()
        ).isEmpty)
        #expect(state.employees.count == 1)
    }

    @Test("The book still caps at forty with alumni in it")
    func trimStillCaps() throws {
        let config = balance()
        var state = newGame(config)
        for index in 0..<40 {
            alum(&state, name: "Alum \(index)", rapport: Double(index))
        }
        let employee = hire(&state, bond: 5)

        // A departure into a full book keeps the cap and keeps the leaver.
        Reducer.apply(.fire(employeeID: employee.id), to: &state, balance: config, content: TestContent.tiny())
        #expect(state.networking.contacts.count == 40)
        #expect(state.networking.contact(employee.id) != nil)

        openRoom(&state, config)
        let room = try #require(state.networking.pendingEvent)
        #expect(state.networking.contacts.count == 40)
        #expect(room.contactIDs.allSatisfy { state.networking.contact($0) != nil })
    }
}

// MARK: - Saves

@Suite("Alumni — saves")
struct AlumniSaveTests {
    @Test("A contact written before alumni existed decodes as a stranger")
    func legacyContactDecodes() throws {
        let plain = Contact(
            id: UUID(), name: "Robin Vale", appearanceSeed: 42, archetype: .engineer,
            skills: SkillSet(coding: 60, design: 40, marketing: 40), askingSalary: 800,
            metDay: 0, lastMetDay: 0
        )
        let data = try JSONEncoder().encode(plain)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(!json.contains("leftDay"))
        #expect(!json.contains("leftReason"))
        #expect(!json.contains("leftRole"))

        let decoded = try JSONDecoder().decode(Contact.self, from: data)
        #expect(decoded == plain)
        #expect(!decoded.isAlumnus)
    }

    @Test("An alum round-trips")
    func alumRoundTrips() throws {
        let alum = Contact(
            id: UUID(), name: "Marco Reyes", appearanceSeed: 7, archetype: .engineer,
            skills: SkillSet(coding: 70, design: 30, marketing: 20), askingSalary: 1_200,
            rapport: 60, interest: 70, metDay: 10, lastMetDay: 45, isRevealed: true,
            leftDay: 45, leftReason: .poached, leftRole: .frontend
        )
        let decoded = try JSONDecoder().decode(Contact.self, from: JSONEncoder().encode(alum))
        #expect(decoded == alum)
        #expect(decoded.leftReason == .poached)
        #expect(decoded.leftRole == .frontend)
    }
}
