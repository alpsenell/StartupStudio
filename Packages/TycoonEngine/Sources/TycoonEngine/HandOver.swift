import Foundation

// MARK: Iteration 15 — K5 (hand over the keys)
//
// *Walked away* is the founder leaving a company standing and the run
// ending. This is the other answer: name the person who takes it, keep a
// slice of it, and carry on playing as them.
//
// A pure state rewrite on one action (`GameAction.handOverKeys`). Nothing
// here reads `rng`, `worldRNG` or any other stream, no bot sends it, and
// nothing it writes exists in a run that never sends it: the emeritus
// round is an ordinary `RaisedRound` on the cap table, the old founder an
// ordinary `Contact`, the new founder an ordinary `Employee` with
// `isFounder` set, and `lineage` and `mode` were already on `GameState`.
//
// The two answers, both printed on the sheet:
//
// - *Walk away*: the run ends, ranked, and the ledger records the whole
//   of the founder's net worth.
// - *Hand over*: the company carries on with its standing, its products,
//   its rivals, its case and its debts; the run becomes `.custom`
//   (unranked); the successor starts single, in a studio flat, with a
//   wallet of eight weeks of their own pay — and with the old founder on
//   the cap table as a silent round, so *Still yours* stays closed to them
//   until they buy that stake back through the ordinary `buyBackRound`.

/// The slices of their holding a founder may keep when they hand over.
public enum HandOverKeep {
    /// Percent of the founder's own holding, not of the company.
    public static let percents = [10, 25, 50]
    /// The sheet's default: a quarter.
    public static let standard = 25
}

/// Everything the sheet prints before the tap, read once so the button,
/// the ledger and the engine cannot disagree.
public struct HandOverTerms: Equatable, Sendable {
    public var successorID: UUID
    public var successorName: String
    public var keptPercent: Int
    /// Points of the company the outgoing founder keeps — `keptPercent`
    /// of what they hold today.
    public var keptEquity: Double
    /// Points the successor holds the day they take over.
    public var successorEquity: Double
    /// The kept slice at today's valuation.
    public var keptValue: Int
    /// What the outgoing founder's line in the ledger will say they are
    /// worth: their wallet, their things and the kept slice.
    public var outgoingNetWorth: Int
    /// The successor's weekly pay, which becomes the founder's salary.
    public var successorSalary: Int
    /// Eight weeks of that pay, the successor's opening wallet.
    public var successorWallet: Int
    /// What buying the kept slice back would cost the company today.
    public var buybackPrice: Int
}

extension GameState {
    /// Weeks of the successor's own pay they arrive with in their wallet.
    public static let handOverWalletWeeks = 8

    /// Why the founder cannot hand the company to anybody today, or `nil`.
    ///
    /// The gates of `walkAwayBlocker` without its two life gates (the net
    /// worth and the life score: a founder who hands over is not leaving
    /// on their numbers, they are staying in the company's), plus the
    /// three that only a hand-over has: nobody on a sabbatical or signed
    /// off, no acquirer on an earn-out, and a founder who took the keys
    /// by a hand-over holds them for a caretaker's tenure before passing
    /// them on.
    public func handOverBlocker(balance: BalanceConfig) -> String? {
        let config = balance.lifeScore
        if gameOver != nil { return "This company already had its ending." }
        if let epilogue { return "This company had its ending on day \(epilogue.day)." }
        if day < config.walkAwayMinDay {
            let weeks = Swift.max(1, (config.walkAwayMinDay - day) / Self.daysPerWeek)
            return "Too soon. \(weeks) more week" + (weeks == 1 ? "" : "s")
                + " — nobody takes the keys to a company this young."
        }
        if company.cash < 0 || loanBalance > 0 {
            return loanBalance > 0
                ? "\(loanBalance.dollars) of debt outstanding. You do not hand somebody that."
                : "The company is overdrawn. You do not hand somebody that."
        }
        if investors.hasBoard {
            return "There is still a board in the room. Buy them out, or they decide this."
        }
        if let earnOut = investors.earnOut {
            return "\(earnOut.buyerName) is buying the company. It is not yours to hand on."
        }
        if headcount <= 1 {
            return "There is nobody to hand it to."
        }
        if life.isAway(day: day) || life.sabbatical?.isActive == true {
            return "You are away. Hand it over in person."
        }
        if let since = handOverTookKeysDay {
            let held = (day - since) / Self.daysPerWeek
            let needed = balance.sabbatical.minTenureWeeks
            if held < needed {
                return "You took the keys on day \(since). Hold them \(needed) weeks before you pass them on"
                    + " (\(held) so far)."
            }
        }
        if !employees.contains(where: { handOverSuccessorBlocker($0, balance: balance) == nil }) {
            return "Nobody here could take it yet: \(balance.sabbatical.minTenureWeeks) weeks in"
                + " and a bond of \(Int(balance.sabbatical.minBond)) with you."
        }
        return nil
    }

    /// Why this person cannot take the company, or `nil`: the caretaker
    /// gate (`caretakerBlocker` — tenure and bond), and nobody with a
    /// question of their own still open.
    public func handOverSuccessorBlocker(_ employee: Employee, balance: BalanceConfig) -> String? {
        if let reason = caretakerBlocker(employee, balance: balance) { return reason }
        if rivals.pendingPoach?.employeeID == employee.id {
            return "A rival's offer is on the table"
        }
        if pendingStaffEvent?.employeeID == employee.id {
            return "Waiting on an answer from you"
        }
        if economy.pendingResignation?.employeeID == employee.id {
            return "Has handed in their notice"
        }
        return nil
    }

    /// The people the sheet lists, best first — the sabbatical's own order
    /// (bond, then tenure), including the ones who do not pass yet, greyed
    /// with their reason.
    public func handOverCandidates(balance: BalanceConfig) -> [Employee] {
        sabbaticalCandidates(balance: balance)
    }

    /// What handing the company to `successorID`, keeping `keptPercent` of
    /// the founder's holding, would mean today. `nil` for somebody not on
    /// the roster or a slice the sheet does not offer; it does not check
    /// the gates — the sheet prints the terms beside the reason it cannot.
    public func handOverTerms(
        successorID: UUID, keptPercent: Int, balance: BalanceConfig
    ) -> HandOverTerms? {
        guard HandOverKeep.percents.contains(keptPercent),
              let successor = employees.first(where: { $0.id == successorID && !$0.isFounder })
        else { return nil }
        let valuation = companyValuation(balance: balance)
        let kept = investors.equityRemaining * Double(keptPercent) / 100
        let round = RaisedRound.emeritus(
            founderID: employees.first(where: \.isFounder)?.id ?? successorID,
            founderName: progression.founder.displayName,
            equity: kept, valuation: valuation, day: day
        )
        var outgoing = self
        outgoing.investors.equityRemaining = kept
        return HandOverTerms(
            successorID: successorID,
            successorName: successor.name,
            keptPercent: keptPercent,
            keptEquity: kept,
            successorEquity: Swift.max(0, investors.equityRemaining - kept),
            keptValue: Int((Double(valuation) * kept / 100).rounded()),
            outgoingNetWorth: outgoing.founderNetWorth(balance: balance),
            successorSalary: successor.weeklySalary,
            successorWallet: successor.weeklySalary * Self.handOverWalletWeeks,
            buybackPrice: buybackPrice(for: round, balance: balance)
        )
    }

    /// The day the current founder took the keys by a hand-over, read off
    /// the newest emeritus round (seated or already bought back); `nil`
    /// for a founder who founded the company.
    public var handOverTookKeysDay: Int? {
        guard lineage?.predecessorCompanyName == company.name else { return nil }
        return (investors.rounds + investors.boughtOut)
            .filter(\.isEmeritus)
            .map(\.day)
            .max()
    }
}

/// The action's arithmetic. No draws, no events but its own.
enum HandOverSystem {
    static func handOver(
        successorID: UUID,
        keptPercent: Int,
        predecessorRunID: UUID,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard state.handOverBlocker(balance: balance) == nil,
              let terms = state.handOverTerms(
                  successorID: successorID, keptPercent: keptPercent, balance: balance
              ),
              let successor = state.employee(id: successorID),
              state.handOverSuccessorBlocker(successor, balance: balance) == nil,
              let founderIndex = state.employees.firstIndex(where: \.isFounder)
        else { return [] }

        let founder = state.employees[founderIndex]
        let outgoingName = state.progression.founder.displayName
        let valuation = state.companyValuation(balance: balance)

        // 1. What the founder keeps: a silent round on the cap table. No
        //    seat, no patience, so `boardExpectations` (seated rounds
        //    only) never sees it, and `buyBackRound` pays it out like any
        //    other round.
        state.investors.rounds.append(RaisedRound.emeritus(
            founderID: founder.id, founderName: outgoingName,
            equity: terms.keptEquity, valuation: valuation, day: state.day
        ))
        state.investors.equityRemaining = Swift.max(
            0, state.investors.equityRemaining - terms.keptEquity
        )

        // 2. The old founder leaves payroll for the address book, with
        //    the rapport the successor had with them.
        state.employees.remove(at: founderIndex)
        state.economy.lastRecognitionDay[founder.id] = nil
        state.friendships.removeAll { $0.involves(founder.id) }
        let standIn = Employee(
            id: founder.id, name: outgoingName, skills: founder.skills, weeklySalary: 0,
            assignment: .idle, isFounder: false, hiredDay: 0,
            appearanceSeed: founder.appearanceSeed,
            level: .forSkillTotal(founder.skills.total), role: .founder
        )
        state.networking.contacts.removeAll { $0.id == founder.id }
        state.networking.contacts.append(Contact(
            id: founder.id,
            name: outgoingName,
            appearanceSeed: founder.appearanceSeed,
            archetype: .founder,
            skills: founder.skills,
            askingSalary: Swift.max(1, Int(balance.fairWeeklyPay(for: standIn).rounded())),
            rapport: Swift.min(100, Swift.max(0, successor.founderBond)),
            interest: 50,
            metDay: 0,
            lastMetDay: state.day,
            isRevealed: true,
            leftDay: state.day,
            leftReason: .formerCompany,
            leftRole: .founder
        ))

        // 3. The successor's row becomes the founder's: off payroll (the
        //    founder is paid through `life.founderSalary`, at the same
        //    number), no bond with themselves.
        guard let heirIndex = state.employees.firstIndex(where: { $0.id == successorID }) else { return [] }
        var heir = state.employees[heirIndex]
        heir.isFounder = true
        heir.role = .founder
        heir.weeklySalary = 0
        heir.founderBond = 0
        state.employees[heirIndex] = heir
        state.economy.lastRecognitionDay[heir.id] = nil
        state.progression.founder = FounderProfile(
            name: heir.name,
            archetype: HandOverSystem.archetype(for: successor.role),
            appearanceSeed: heir.appearanceSeed
        )

        // 4. A fresh life: single, a studio flat, rested, eight weeks of
        //    their own pay in the wallet. The old founder's will was theirs.
        var life = LifeState.newGame(
            wallet: terms.successorWallet, founderSalary: terms.successorSalary
        )
        life.skills = balance.founder.starting
        state.life = life
        state.familyDrama.heir = nil
        state.familyDrama.heirName = nil
        state.familyDrama.heirChildID = nil

        // 5. The run's record: who they came after, and unranked.
        state.lineage = Lineage(
            predecessorRunID: predecessorRunID,
            predecessorFounderName: outgoingName,
            predecessorCompanyName: state.company.name,
            kind: .employee
        )
        state.mode = .custom
        state.ledger.post(LedgerEntry(
            day: state.day, amount: 0, category: .other,
            label: "Keys handed to \(heir.name)"
        ))
        return [.keysHandedOver(
            successorID: successorID, keptEquity: terms.keptEquity, day: state.day
        )]
    }

    /// The founder archetype an employee's trade reads as — the same map
    /// the Dynasty's successors use (`Successors.archetype(for:)`).
    static func archetype(for role: EmployeeRole) -> FounderArchetype {
        switch role {
        case .frontend, .backend, .qa: .hacker
        case .designer: .designer
        default: .hustler
        }
    }
}

// MARK: end K5
