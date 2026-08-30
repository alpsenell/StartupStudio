import Foundation
import TycoonContent

/// The people the founder meets, and what comes of it.
///
/// A networking weekend opens a *room*: three to five people, a handful of
/// exchanges, and — once the rapport is there — a deal. The room stays
/// open for `networking.eventDurationDays` so the player can take their
/// time over it rather than being made to answer a modal on a Sunday.
///
/// The deals run both ways, which is the whole point of the tab. The
/// founder can hire someone for salary; give away a slice of their own
/// company to get someone who would never take the salary; put their own
/// money into somebody else's startup and hold the stake; take somebody
/// else's money into theirs; or, if they are single and the evening went
/// unusually well, stop talking about work.
///
/// Every draw comes from `state.socialRNG`, its own stream, so opening a
/// room never disturbs the world. Draw order per tick: holdings settle on
/// the weekly boundary, in `id` order, two words each (growth, then
/// outcome) plus one more for an exit multiple. Nothing else here draws.
enum NetworkingSystem {
    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        var events: [GameEvent] = []

        // The room closes whether or not the founder was finished with it.
        if let event = state.networking.pendingEvent, state.day >= event.expiresOnDay {
            state.networking.pendingEvent = nil
            events.append(.networkingEventEnded(day: state.day))
        }

        decayRapport(&state, balance)

        if state.day % GameState.daysPerWeek == 0 {
            events.append(contentsOf: settleHoldings(&state, balance))
        }
        return events
    }

    /// Nobody stays interested in somebody who never calls. Contacts the
    /// founder spoke to today are left alone; everyone else slides.
    private static func decayRapport(_ state: inout GameState, _ balance: BalanceConfig) {
        let decay = balance.networking.rapportDecayPerDay
        guard decay > 0 else { return }
        for index in state.networking.contacts.indices
        where state.networking.contacts[index].isOpen
            && state.networking.contacts[index].lastMetDay < state.day {
            state.networking.contacts[index].rapport = max(
                0, state.networking.contacts[index].rapport - decay
            )
        }
    }

    // MARK: - Holdings

    /// Weekly: every stake drifts, and each one rolls once for whether the
    /// startup behind it got bought or ran out of money. An exit pays the
    /// stake's current value times a drawn premium into the *wallet* —
    /// this is the founder's own money, not the company's, and it is the
    /// one way out of a personal debt spiral that does not involve the
    /// company bailing them out.
    private static func settleHoldings(
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) -> [GameEvent] {
        let config = balance.networking
        guard !state.networking.holdings.isEmpty else { return [] }

        var events: [GameEvent] = []
        var surviving: [Holding] = []
        surviving.reserveCapacity(state.networking.holdings.count)

        for var holding in state.networking.holdings.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            let noise = (state.socialRNG.nextUniform() - 0.5) * 2 * config.holdingWeeklyVolatility
            holding.valuation = max(
                0, Int((Double(holding.valuation) * (1 + config.holdingWeeklyGrowth + noise)).rounded())
            )

            let outcome = state.socialRNG.nextUniform()
            if outcome < config.holdingExitChance {
                let span = max(0, config.holdingExitMultipleMax - config.holdingExitMultipleMin)
                let multiple = config.holdingExitMultipleMin + state.socialRNG.nextUniform() * span
                let proceeds = Int((Double(holding.currentValue) * multiple).rounded())
                state.life.wallet += proceeds
                // The contact stays `.backed`: they got bought, they did
                // not stop knowing the founder. Only a fold loses them.
                events.append(.stakeExited(
                    companyName: holding.companyName, proceeds: proceeds, day: state.day
                ))
                continue
            }
            if outcome < config.holdingExitChance + config.holdingFoldChance {
                closeContact(holding.id, as: .lost, in: &state)
                events.append(.stakeLost(
                    companyName: holding.companyName, invested: holding.invested, day: state.day
                ))
                continue
            }
            surviving.append(holding)
        }

        state.networking.holdings = surviving
        return events
    }

    private static func closeContact(_ id: UUID, as outcome: ContactOutcome, in state: inout GameState) {
        guard let index = state.networking.contacts.firstIndex(where: { $0.id == id }) else { return }
        state.networking.contacts[index].outcome = outcome
    }

    // MARK: - Opening a room

    /// Opens a networking event. Called by `LifeSystem` when a networking
    /// weekend resolves, and a no-op when the balance has no networking
    /// floor (`contactsPerEventMax` of zero) or the founder already has a
    /// room open.
    ///
    /// The roster mixes faces: up to two people the founder already knows
    /// and has unfinished business with — picked by rapport, no draw — and
    /// new people rolled for the rest. Draw order: venue, headcount, then
    /// per new contact id → first name → last name → appearance → (
    /// archetype, only for the unfavored slots) → three skills → salary
    /// jitter → (valuation, only for someone who runs something).
    static func startEvent(
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        let config = balance.networking
        guard config.isEnabled, state.networking.pendingEvent == nil else { return [] }

        let venues = NetworkingVenue.allCases
        let venue = venues[state.socialRNG.nextInt(in: 0...(venues.count - 1))]
        let headcount = state.socialRNG.nextInt(
            in: min(config.contactsPerEventMin, config.contactsPerEventMax)...max(
                config.contactsPerEventMin, config.contactsPerEventMax
            )
        )
        guard headcount > 0 else { return [] }

        // Familiar faces first: the best-known open contacts, at most one
        // fewer than the room holds so there is always somebody new.
        let returning = state.networking.contacts
            .filter(\.isOpen)
            .sorted {
                $0.rapport == $1.rapport ? $0.id.uuidString < $1.id.uuidString : $0.rapport > $1.rapport
            }
            .prefix(max(0, min(2, headcount - 1)))
            .map(\.id)

        var roster = Array(returning)
        let favored = venue.favoredArchetypes
        for slot in 0..<(headcount - roster.count) {
            let contact = rollContact(
                favoring: slot < favored.count ? favored[slot] : nil,
                state: &state, balance: balance, content: content
            )
            state.networking.contacts.append(contact)
            roster.append(contact.id)
        }

        let turns = config.conversationsPerEvent + Int(
            state.life.skills.conversation / max(1, config.conversationTurnsDivisor)
        )
        state.networking.pendingEvent = NetworkingEvent(
            venue: venue,
            day: state.day,
            expiresOnDay: state.day + max(1, config.eventDurationDays),
            contactIDs: roster,
            conversationsLeft: max(1, turns)
        )
        state.networking.lastEventDay = state.day
        // Trim *after* the room exists, so `trimContacts` can see who is
        // standing in it. Trimming first would let the book evict somebody
        // from a party the founder is about to walk into, and the roster
        // would then hold an id with no contact behind it.
        trimContacts(&state, balance)
        return [.networkingEventStarted(venue: venue, contactCount: roster.count, day: state.day)]
    }

    /// The address book is a book, not a filing cabinet: once it is over
    /// `maxContacts` the oldest closed entries go first, and only then the
    /// coldest open ones.
    private static func trimContacts(_ state: inout GameState, _ balance: BalanceConfig) {
        let cap = balance.networking.maxContacts
        guard cap > 0, state.networking.contacts.count > cap else { return }
        let inRoom = Set(state.networking.pendingEvent?.contactIDs ?? [])
        var contacts = state.networking.contacts
        while contacts.count > cap {
            let victim = contacts.firstIndex { !$0.isOpen && !inRoom.contains($0.id) }
                ?? contacts.indices.min {
                    (contacts[$0].rapport, contacts[$0].metDay) < (contacts[$1].rapport, contacts[$1].metDay)
                }
            guard let victim else { break }
            contacts.remove(at: victim)
        }
        state.networking.contacts = contacts
    }

    private static func rollContact(
        favoring archetype: ContactArchetype?,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> Contact {
        let names = content.names
        let id = UUID(from: &state.socialRNG)
        let first = pick(names.firstNames, &state.socialRNG)
        let last = pick(names.lastNames, &state.socialRNG)
        let appearanceSeed = state.socialRNG.next()

        let kinds = ContactArchetype.allCases
        let kind = archetype ?? kinds[state.socialRNG.nextInt(in: 0...(kinds.count - 1))]

        // Everybody at these things is at least competent, and the thing
        // they do for a living is the thing they are good at.
        func roll(_ isPrimary: Bool) -> Double {
            Double(state.socialRNG.nextInt(in: 25...75)) + (isPrimary ? 20 : 0)
        }
        let skills = SkillSet(
            coding: roll(kind == .engineer),
            design: roll(kind == .designer),
            marketing: roll(kind == .marketer || kind == .founder)
        )

        // Priced the way the hiring desk prices anybody, then bumped:
        // somebody you met at a party is not on the market and knows it.
        let jitter = 1 + (state.socialRNG.nextUniform() - 0.5) * 2 * balance.salaryJitter
        let salary = (Double(balance.salaryBase) + balance.salaryPerSkillPoint * skills.total)
            * jitter * 1.15

        var companyName: String?
        var valuation = 0
        if kind.hasCompany {
            companyName = pick(names.rivalStudios.isEmpty ? names.clientCompanies : names.rivalStudios,
                               &state.socialRNG)
            valuation = state.socialRNG.nextInt(in: 40_000...600_000)
        }

        return Contact(
            id: id,
            name: "\(first) \(last)",
            appearanceSeed: appearanceSeed,
            archetype: kind,
            skills: skills,
            askingSalary: Int(salary.rounded()),
            companyName: companyName,
            companyValuation: valuation,
            metDay: state.day,
            lastMetDay: state.day
        )
    }

    private static func pick(_ pool: [String], _ rng: inout SeededRNG) -> String {
        guard !pool.isEmpty else { return "" }
        return pool[rng.nextInt(in: 0...(pool.count - 1))]
    }

    // MARK: - Conversation

    /// One exchange with somebody in the room.
    ///
    /// Every topic costs one of the evening's exchanges and a little
    /// energy, and every topic draws exactly one word — including the two
    /// that cannot fail — so the stream advances by the same amount
    /// whatever the player says.
    ///
    /// Small talk and listening always land. Talking shop is graded on the
    /// founder's technical and market sense; a pitch is graded on their
    /// conversation and on how much rapport there is to spend. A miss
    /// costs rapport, which is what makes pitching a stranger a mistake
    /// rather than a free roll.
    static func talk(
        contactID: UUID,
        topic: ConversationTopic,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        let config = balance.networking
        guard var event = state.networking.pendingEvent,
              event.conversationsLeft > 0,
              event.contactIDs.contains(contactID),
              !state.life.isAway(day: state.day),
              let index = state.networking.contacts.firstIndex(where: { $0.id == contactID })
        else { return [] }

        let charm = state.founderCharmFactor(balance)
        let roll = state.socialRNG.nextUniform()
        let contact = state.networking.contacts[index]

        let landed: Bool
        var rapport = 0.0
        var interest = 0.0
        switch topic {
        case .smallTalk:
            landed = true
            rapport = config.talkRapport * 0.6 * charm
        case .listen:
            landed = true
            rapport = config.talkRapport * 0.5 * charm
            state.networking.contacts[index].isRevealed = true
        case .shopTalk:
            let expertise = max(state.life.skills.technical, state.life.skills.marketKnowledge)
            landed = roll < min(0.95, config.talkSuccessBase + expertise / 200)
            rapport = landed ? config.talkRapport * 1.3 * charm : -config.talkRapportMiss
            interest = landed ? config.pitchInterest * 0.25 : 0
        case .pitch:
            // Nobody wants the deck ninety seconds after hello.
            let warmth = contact.rapport / 200 + state.life.skills.conversation / 250
            landed = roll < min(0.95, config.talkSuccessBase * 0.7 + warmth)
            rapport = landed ? config.pitchRapport * charm : -config.talkRapportMiss * 1.5
            interest = landed ? config.pitchInterest * charm : config.pitchInterest * 0.2
        }

        state.networking.contacts[index].rapport = clamp(contact.rapport + rapport)
        state.networking.contacts[index].interest = clamp(contact.interest + interest)
        state.networking.contacts[index].lastMetDay = state.day

        event.conversationsLeft -= 1
        state.networking.pendingEvent = event

        state.life.meters.apply(
            energy: -config.energyPerTurn,
            mood: landed ? config.moodPerGoodTurn : -config.moodPerGoodTurn
        )
        FounderSystem.practice(.conversation, state: &state, balance: balance)
        switch topic {
        case .shopTalk: FounderSystem.practice(.technical, multiplier: 0.5, state: &state, balance: balance)
        case .pitch: FounderSystem.practice(.marketKnowledge, state: &state, balance: balance)
        case .smallTalk, .listen: break
        }

        var events: [GameEvent] = [
            .networkingTalk(contactID: contactID, topic: topic, landed: landed, day: state.day)
        ]
        if event.conversationsLeft == 0 {
            events.append(contentsOf: leaveEvent(state: &state, balance: balance))
        }
        return events
    }

    /// Calls it a night: the room closes and the evening's relationships
    /// pay out. Ignored with no room open.
    static func leaveEvent(state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        guard state.networking.pendingEvent != nil else { return [] }
        state.networking.pendingEvent = nil
        state.life.meters.apply(relationships: balance.networking.relationshipsPerEvent)
        return [.networkingEventEnded(day: state.day)]
    }

    private static func clamp(_ value: Double) -> Double { min(100, max(0, value)) }
}
