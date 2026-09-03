import Foundation
import TycoonContent

/// The five deals a conversation can end in, and the one place that says
/// why one of them is refused.
///
/// Every offer is a closed question: the contact has already named their
/// terms (see `Contact.equityAsk`, `stakePrice`, `angelTerms`), so the
/// founder is accepting a price rather than typing one. Accepting closes
/// the contact — they stop appearing in rooms and stay in the address book
/// as history.
///
/// Deterministic throughout: the terms come from the contact and the
/// balance, and nothing here draws.
extension NetworkingSystem {
    /// Puts a deal on the table. Ignored — returning no events — whenever
    /// `offerBlocker` would have something to say.
    static func makeOffer(
        contactID: UUID,
        offer: NetworkingOffer,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard offerBlocker(offer, contactID: contactID, state: state, balance: balance) == nil,
              let index = state.networking.contacts.firstIndex(where: { $0.id == contactID })
        else { return [] }

        let config = balance.networking
        let contact = state.networking.contacts[index]
        var events: [GameEvent] = []

        switch offer {
        case .recruit:
            joinTeam(
                contact, salary: contact.askingSalary, morale: balance.staff.startingMorale,
                loyalty: 50, state: &state
            )
            state.networking.contacts[index].outcome = .hired
            events.append(.contactRecruited(contactID: contactID, name: contact.name, day: state.day))

        case .equityHire:
            let equity = contact.equityAsk(config)
            joinTeam(
                contact, salary: contact.equityHireSalary(config),
                morale: config.equityHireMorale, loyalty: config.equityHireLoyalty,
                state: &state
            )
            state.investors.equityRemaining = max(0, state.investors.equityRemaining - equity)
            state.networking.grants.append(EquityGrant(
                id: contactID, name: contact.name, percent: equity, day: state.day, reason: .partner
            ))
            state.networking.contacts[index].outcome = .partner
            events.append(.contactJoinedForEquity(
                contactID: contactID, name: contact.name, equity: equity, day: state.day
            ))

        case .backThem:
            let stake = contact.stakeOnOffer(config)
            let price = contact.stakePrice(config)
            state.life.wallet -= price
            state.networking.holdings.append(Holding(
                id: contactID,
                companyName: contact.companyName ?? contact.name,
                stakePercent: stake,
                invested: price,
                valuation: contact.companyValuation,
                boughtDay: state.day
            ))
            state.networking.contacts[index].outcome = .backed
            events.append(.stakeAcquired(
                contactID: contactID,
                companyName: contact.companyName ?? contact.name,
                stakePercent: stake,
                amount: price,
                day: state.day
            ))

        case .takeTheirMoney:
            let terms = contact.angelTerms(config, dealFactor: state.founderDealFactor(balance))
            state.company.cash += terms.amount
            state.ledger.post(LedgerEntry(
                day: state.day, amount: terms.amount, category: .other,
                label: "Angel round — \(contact.name)"
            ))
            state.investors.equityRemaining = max(0, state.investors.equityRemaining - terms.equity)
            state.networking.grants.append(EquityGrant(
                id: contactID, name: contact.name, percent: terms.equity,
                day: state.day, reason: .angel
            ))
            state.networking.contacts[index].outcome = .angel
            events.append(.angelInvestment(
                contactID: contactID, name: contact.name,
                amount: terms.amount, equity: terms.equity, day: state.day
            ))

        case .askOut:
            state.life.family.stage = .dating
            state.life.family.stageSinceDay = state.day
            state.life.family.partnerName = contact.name
            state.life.family.partnerAppearanceSeed = contact.appearanceSeed
            state.life.family.partnerContactID = contactID
            // An evening that went this well starts the relationship warm.
            state.life.family.affection = min(
                100, balance.relationships.startingAffection + contact.rapport / 4
            )
            state.life.family.lastPartnerDay = state.day
            state.life.family.partnerCooldowns = [:]
            state.life.lowRelationshipStreakDays = 0
            state.economy.lonelySinceDay = nil
            state.networking.contacts[index].outcome = .romance
            // WS-E: a year from tonight is an anniversary.
            FamilyCalendar.stageChanged(&state, balance: balance, content: content)
            events.append(.relationshipChanged(stage: .dating, day: state.day))
            events.append(.romanceStarted(contactID: contactID, name: contact.name, day: state.day))
        }

        // Whoever it was, they are no longer standing in the room — and
        // once the last of them is dealt with, the evening is over rather
        // than an empty floor waiting to expire.
        state.networking.pendingEvent?.contactIDs.removeAll { $0 == contactID }
        FounderSystem.practice(.conversation, multiplier: 2, state: &state, balance: balance)
        if state.networking.pendingEvent?.contactIDs.isEmpty == true {
            events.append(contentsOf: leaveEvent(state: &state, balance: balance))
        }
        return events
    }

    /// Puts a contact on payroll. They arrive with the bond the evening
    /// earned — somebody the founder talked into this is not a stranger on
    /// their first day.
    private static func joinTeam(
        _ contact: Contact,
        salary: Int,
        morale: Double,
        loyalty: Double,
        state: inout GameState
    ) {
        let assignment: Assignment = if let product = state.productInDevelopment {
            .product(product.id)
        } else {
            .idle
        }
        state.employees.append(Employee(
            id: contact.id,
            name: contact.name,
            skills: contact.skills,
            weeklySalary: salary,
            assignment: assignment,
            isFounder: false,
            hiredDay: state.day,
            appearanceSeed: contact.appearanceSeed,
            morale: morale,
            level: .forSkillTotal(contact.skills.total),
            loyalty: loyalty,
            role: contact.archetype.employeeRole,
            founderBond: contact.rapport / 2
        ))
    }

    /// Why this deal cannot be made, in the player's words, or `nil` when
    /// it can. The offer buttons read their disabled reasons from here, so
    /// the sheet and the engine can never disagree about the terms.
    static func offerBlocker(
        _ offer: NetworkingOffer,
        contactID: UUID,
        state: GameState,
        balance: BalanceConfig
    ) -> String? {
        let config = balance.networking
        guard let contact = state.networking.contact(contactID), contact.isOpen else {
            return "That conversation is over"
        }
        if state.life.isAway(day: state.day) { return "You're away" }

        func needsRapport(_ minimum: Double) -> String? {
            contact.rapport < minimum
                ? "Talk to them more first (\(Int(contact.rapport.rounded()))/\(Int(minimum)))"
                : nil
        }
        func needsInterest() -> String? {
            contact.interest < config.joinMinInterest
                ? "Pitch them first — they don't know what you do"
                : nil
        }

        switch offer {
        case .recruit:
            if let reason = needsRapport(config.recruitMinRapport) { return reason }
            if let reason = needsInterest() { return reason }
            if state.headcount >= balance.office(state.company.officeTier).headcountCap {
                return "No desk for them"
            }
            return nil
        case .equityHire:
            if let reason = needsRapport(config.equityHireMinRapport) { return reason }
            if let reason = needsInterest() { return reason }
            if state.headcount >= balance.office(state.company.officeTier).headcountCap {
                return "No desk for them"
            }
            if state.investors.equityRemaining < contact.equityAsk(config) {
                return "You don't have that much of the company left"
            }
            return nil
        case .backThem:
            guard contact.archetype.hasCompany, contact.companyValuation > 0 else {
                return "They don't have a company"
            }
            if let reason = needsRapport(config.investMinRapport) { return reason }
            let price = contact.stakePrice(config)
            if state.life.wallet < price {
                return "Need \(price - state.life.wallet) more"
            }
            return nil
        case .takeTheirMoney:
            guard contact.archetype.isBacker else { return "They don't write cheques" }
            if let reason = needsRapport(config.angelMinRapport) { return reason }
            if let reason = needsInterest() { return reason }
            let terms = contact.angelTerms(config, dealFactor: state.founderDealFactor(balance))
            if state.investors.equityRemaining < terms.equity {
                return "You don't have that much of the company left"
            }
            return nil
        case .askOut:
            guard state.life.family.stage == .single else { return "You're seeing someone" }
            return needsRapport(config.romanceMinRapport)
        }
    }
}
