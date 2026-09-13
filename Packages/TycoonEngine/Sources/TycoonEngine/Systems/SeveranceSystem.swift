import Foundation

// MARK: T3 (people)

/// Iteration 17 — T3. Letting people go, with a price on each answer:
///
/// - The plain firing with `payNotice` pays notice out of the company
///   (`payNotice`, called from `EmployeeSystem.fire` before the row goes).
/// - For cause stays free, and the room sees it: `causeFollows` takes the
///   morale off everyone who stays and, when the person was happy here,
///   rolls one `socialRNG` word for a wrongful-dismissal claim — a civil
///   case on the courtroom's own machinery (`CrimeSystem.settle` and
///   `deliver` hand the claim back here).
/// - `.layOff` lets several go at once: everyone's notice, a room-wide
///   morale hit capped, reputation, and a seated headcount board's miss.
///
/// Every path here starts from a player's tap. No bot fires, sends
/// `.layOff` or the with-cause interaction, and the free `fire` without
/// `payNotice` never reaches this file.
enum SeveranceSystem {
    /// `LegalCase.kind` of a wrongful-dismissal claim. Not a `CrimeOffence`:
    /// nothing about it is a crime, and it never convicts.
    static let claimCaseKind = "wrongfulDismissal"

    // MARK: - Notice

    /// Pays `employeeID`'s notice out of the company. The caller has checked
    /// the blocker; a zero-week notice pays nothing and says nothing.
    static func payNotice(
        employeeID: UUID, state: inout GameState, balance: BalanceConfig
    ) -> [GameEvent] {
        guard let employee = state.employee(id: employeeID),
              let notice = state.severanceNotice(employeeID: employeeID, balance: balance),
              notice.amount > 0
        else { return [] }
        state.company.cash -= notice.amount
        state.ledger.post(LedgerEntry(
            day: state.day, amount: -notice.amount, category: .payroll,
            label: "Notice pay: \(employee.name)"
        ))
        return [.severancePaid(
            employeeID: employeeID, name: employee.name,
            weeks: notice.weeks, amount: notice.amount, day: state.day
        )]
    }

    // MARK: - For cause

    /// What follows a firing for cause, after the ordinary firing has run:
    /// the room's morale, and maybe a claim.
    static func causeFollows(
        _ leaving: Employee?, state: inout GameState, balance: BalanceConfig
    ) -> [GameEvent] {
        guard let leaving else { return [] }
        let config = balance.severance
        if config.causeMoraleAll != 0 {
            for index in state.employees.indices where !state.employees[index].isFounder {
                state.employees[index].morale = min(100, max(0, state.employees[index].morale + config.causeMoraleAll))
            }
        }
        guard leaving.morale > config.claimMoraleOver,
              state.crime.pendingCase == nil
        else { return [] }
        let roll = state.socialRNG.nextUniform()
        guard roll < config.claimChance else { return [] }
        return fileClaim(leaving, state: &state, balance: balance)
    }

    /// The claim: eight weeks of their pay to settle, heard at the
    /// courtroom's shortest listing. Evidence is how happy they were —
    /// somebody who was doing well is a better witness. No draw.
    private static func fileClaim(
        _ leaving: Employee, state: inout GameState, balance: BalanceConfig
    ) -> [GameEvent] {
        let price = max(0, balance.severance.claimWeeksPay) * max(0, leaving.weeklySalary)
        let hearingDay = state.day + max(1, balance.crime.hearingWeeksMin) * GameState.daysPerWeek
        state.crime.cases.append(LegalCase(
            id: "claim-\(leaving.id.uuidString)",
            kind: claimCaseKind,
            raisedDay: state.day,
            hearingDay: hearingDay,
            settlementPrice: price,
            evidence: min(0.9, max(0.3, leaving.morale / 100))
        ))
        if state.crime.cases.count > CrimeState.maxCases {
            state.crime.cases.removeFirst(state.crime.cases.count - CrimeState.maxCases)
        }
        state.narrative.flags.insert(CrimeSystem.caseFlag)
        let first = leaving.name.split(separator: " ").first.map(String.init) ?? leaving.name
        state.life.phone.post(
            "\(first)'s solicitor has written. Wrongful dismissal: \(price.dollars) makes it go away, or the tribunal on \(GameState.dateLabel(forDay: hearingDay)).",
            from: .office, day: state.day
        )
        return [.dismissalClaimFiled(
            employeeID: leaving.id, name: leaving.name,
            amount: price, hearingDay: hearingDay, day: state.day
        )]
    }

    /// Who brought the claim at `index`, from the address book (an alumnus
    /// keeps their employee id), or a stand-in.
    static func claimantName(_ legalCase: LegalCase, state: GameState) -> String {
        let raw = legalCase.id.replacingOccurrences(of: "claim-", with: "")
        guard let id = UUID(uuidString: raw),
              let contact = state.networking.contacts.first(where: { $0.id == id })
        else { return "Your former employee" }
        return contact.name
    }

    /// `CrimeSystem.settle` for a claim: the company pays first, the
    /// founder's wallet only what the company cannot.
    static func settleClaim(
        index: Int, state: inout GameState, balance: BalanceConfig
    ) -> [GameEvent] {
        let legalCase = state.crime.cases[index]
        let price = legalCase.settlementPrice
        guard state.company.cash + state.life.wallet >= price else { return [] }
        let fromCompany = min(max(0, state.company.cash), price)
        state.company.cash -= fromCompany
        state.life.wallet -= price - fromCompany
        if fromCompany > 0 {
            state.ledger.post(LedgerEntry(
                day: state.day, amount: -fromCompany, category: .other,
                label: "Settlement: \(claimantName(legalCase, state: state)) (no admission of liability)"
            ))
        }
        state.crime.cases[index].settledDay = state.day
        state.crime.cases[index].verdict = .settlement
        state.crime.cases[index].penalty = price
        state.narrative.flags.remove(CrimeSystem.caseFlag)
        state.life.phone.post(
            "Signed. They get a reference that says the dates they worked and nothing else.",
            from: .office, day: state.day
        )
        return [.crimeSettled(amount: price, day: state.day)]
    }

    /// `CrimeSystem.deliver` for a claim: found for the founder and nothing
    /// is paid, or against and the award is the settlement ×
    /// `claimLostFactor`, out of the company. Civil either way.
    static func deliverClaim(
        standing: Double, index: Int, state: inout GameState, balance: BalanceConfig
    ) -> [GameEvent] {
        let legalCase = state.crime.cases[index]
        let name = claimantName(legalCase, state: state)
        let won = standing >= balance.crime.fineStanding
        var award = 0
        if won {
            state.crime.cases[index].verdict = .acquitted
            state.life.phone.post(
                "The tribunal found for you. Nobody from the old floor calls to say so.",
                from: .office, day: state.day
            )
        } else {
            award = Int((Double(legalCase.settlementPrice) * balance.severance.claimLostFactor).rounded())
            state.company.cash -= award
            state.ledger.post(LedgerEntry(
                day: state.day, amount: -award, category: .other,
                label: "Tribunal award: \(name)"
            ))
            state.crime.cases[index].verdict = .settlement
            state.life.phone.post(
                "The tribunal found for \(name). It is in the trade press by lunch.",
                from: .office, day: state.day
            )
        }
        state.crime.cases[index].penalty = award
        if state.crime.cases.count > CrimeState.maxCases {
            state.crime.cases.removeFirst(state.crime.cases.count - CrimeState.maxCases)
        }
        return [.dismissalClaimHeard(name: name, won: won, award: award, day: state.day)]
    }

    // MARK: - The layoff

    /// `.layOff`: everyone picked goes with their notice; the people who
    /// stay take the room's hit; reputation and the board read the day.
    static func layOff(
        employeeIDs: [UUID], state: inout GameState, balance: BalanceConfig
    ) -> [GameEvent] {
        guard state.severanceLayoffBlocker(employeeIDs: employeeIDs, balance: balance) == nil else { return [] }
        let quote = state.severanceLayoffQuote(employeeIDs: employeeIDs, balance: balance)
        let picked = state.severanceLayoffPicks(employeeIDs)
        var events: [GameEvent] = []
        for person in picked {
            events += EmployeeSystem.fire(
                employeeID: person.id, payNotice: true, state: &state, balance: balance
            )
        }
        if quote.moraleHit != 0 {
            for index in state.employees.indices where !state.employees[index].isFounder {
                state.employees[index].morale = min(100, max(0, state.employees[index].morale + quote.moraleHit))
            }
        }
        if quote.reputationCost > 0 {
            state.company.reputation = max(0, state.company.reputation - quote.reputationCost)
        }
        if quote.boardPressure > 0 {
            state.investors.boardPressure += quote.boardPressure
        }
        state.life.phone.post(
            quote.count == 1
                ? "One desk cleared today. The rest of the floor worked with the door shut."
                : "\(quote.count) desks cleared today. The ones left are counting.",
            from: .office, day: state.day
        )
        events.append(.laidOff(
            count: quote.count,
            severance: quote.severance,
            moraleHit: quote.moraleHit,
            reputation: quote.reputationCost,
            boardPressure: Int(quote.boardPressure.rounded()),
            day: state.day
        ))
        return events
    }

    // MARK: - Debug

    #if DEBUG
    /// `.severanceDebugClaim`: the firing for cause with the claim filed
    /// regardless of the roll, for the screenshot.
    static func debugClaim(
        employeeID: UUID, state: inout GameState, balance: BalanceConfig
    ) -> [GameEvent] {
        guard let leaving = state.employee(id: employeeID), !leaving.isFounder,
              state.crime.pendingCase == nil
        else { return [] }
        var events = InteractionSystem.fireWithCause(employeeID: employeeID, state: &state, balance: balance)
        if state.crime.pendingCase == nil {
            events += fileClaim(leaving, state: &state, balance: balance)
        }
        return events
    }
    #endif
}

// MARK: end T3
