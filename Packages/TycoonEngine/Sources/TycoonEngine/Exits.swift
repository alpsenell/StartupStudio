import Foundation
import TycoonContent

// MARK: T1 (exits and joins)

// Iteration 17 — T1. Three joins between verbs that already existed:
//
// - **The exit reads the options and repays the director.** At an
//   acquisition, a sell-up, an earn-out's signing and an IPO the director's
//   loan comes out of the price to the wallet first; every vested option
//   point is paid its share of the price (a ledger line — the founder's
//   slice never held those points, so nothing moves off it); and the
//   unvested are the founder's answer on the sheet: accelerated, they vest
//   today and are paid; lapsed, they come home to `equityRemaining`. At an
//   IPO they lapse. During an earn-out a lapsed holder leaves at the next
//   weekly pass and reads as a missed review; everywhere it costs the name.
// - **Firing the partner is a fight** (`RelationshipSystem.partnerFired`).
// - **The dividend reaches the holders' desks** (`FounderMoneySystem`).
//
// Everything here is behind a grant, a director's loan, a partner on
// payroll or a holder's dividend line. No bot and no fixture has any of
// them, so every settle below returns on its first lines, `joins` stays
// `nil` and is never encoded, and nothing draws.

/// Which exit settled.
public enum ExitKind: String, Codable, Equatable, Sendable {
    case acquired, soldUp, earnOut, ipo
}

/// One option holder at an exit.
public struct ExitHolderLine: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    /// Points vested on the day.
    public var vested: Double
    /// Points not yet vested on the day (0 for an alumnus).
    public var unvested: Double
    /// What they were paid from the price: the vested share, plus the
    /// unvested share when the founder accelerated.
    public var paid: Int
    /// Still on payroll (an alumnus holds only what vested).
    public var onPayroll: Bool

    public init(id: UUID, name: String, vested: Double, unvested: Double, paid: Int, onPayroll: Bool) {
        self.id = id
        self.name = name
        self.vested = vested
        self.unvested = unvested
        self.paid = paid
        self.onPayroll = onPayroll
    }
}

/// What an exit did with the loan and the options, kept for the ending's
/// lines, the name and the earn-out's weekly pass.
public struct ExitRecord: Codable, Equatable, Sendable {
    public var day: Int
    public var kind: ExitKind
    public var price: Int
    /// The director's loan repaid to the wallet out of the price.
    public var loanRepaid: Int
    public var holders: [ExitHolderLine]
    /// The founder's answer on the unvested.
    public var accelerated: Bool
    /// Holders whose unvested points lapsed: "They will not be coming with
    /// you." The name reads the count for good.
    public var lapsedIDs: [UUID]
    /// Lapsed holders still on payroll who leave at the next weekly pass
    /// (an earn-out only; the other exits end the run).
    public var leavingIDs: [UUID]

    public init(
        day: Int, kind: ExitKind, price: Int, loanRepaid: Int, holders: [ExitHolderLine],
        accelerated: Bool, lapsedIDs: [UUID], leavingIDs: [UUID]
    ) {
        self.day = day
        self.kind = kind
        self.price = price
        self.loanRepaid = loanRepaid
        self.holders = holders
        self.accelerated = accelerated
        self.lapsedIDs = lapsedIDs
        self.leavingIDs = leavingIDs
    }

    /// Everything the holders were paid.
    public var optionsPaid: Int { holders.reduce(0) { $0 + $1.paid } }
}

/// The founder fired their partner. Plain, it is the day's affection;
/// with cause, the next morning is a bag by the door and a question.
public struct PartnerFiring: Codable, Equatable, Sendable {
    public enum Answer: String, Codable, Equatable, Sendable {
        /// The founder ends it: the marriage is over, the settlement follows.
        case packBag
        /// The founder stays and takes it: affection again, and they will
        /// not work for the founder again.
        case stay
    }

    public var employeeID: UUID
    public var name: String
    /// The day of the firing.
    public var day: Int
    /// Read the next morning from `interactions.firedWithCauseIDs`.
    public var withCause: Bool
    /// The morning the question opened (with cause only).
    public var morningDay: Int?
    public var answer: Answer?
    /// The day it closed: answered, a plain firing's next morning, or a
    /// breakup that got there first.
    public var resolvedDay: Int?

    public init(
        employeeID: UUID, name: String, day: Int, withCause: Bool = false,
        morningDay: Int? = nil, answer: Answer? = nil, resolvedDay: Int? = nil
    ) {
        self.employeeID = employeeID
        self.name = name
        self.day = day
        self.withCause = withCause
        self.morningDay = morningDay
        self.answer = answer
        self.resolvedDay = resolvedDay
    }

    /// The bag is by the door and nothing has been said.
    public var isOpen: Bool { withCause && morningDay != nil && answer == nil && resolvedDay == nil }

    /// The last day before staying is the answer.
    public func respondByDay(balance: BalanceConfig) -> Int? {
        morningDay.map { $0 + max(1, balance.exits.partnerFiringRespondDays) }
    }
}

/// T1's slice of the save. `nil` on `GameState` until one of the three
/// joins first happens, and then encoded field by field, each only when
/// set.
public struct JoinsState: Codable, Equatable, Sendable {
    public var exit: ExitRecord?
    public var partnerFiring: PartnerFiring?
    /// The last dividend that paid a holder on payroll, and who.
    public var holderDividendDay: Int?
    public var holderDividendIDs: [UUID]

    public init(
        exit: ExitRecord? = nil,
        partnerFiring: PartnerFiring? = nil,
        holderDividendDay: Int? = nil,
        holderDividendIDs: [UUID] = []
    ) {
        self.exit = exit
        self.partnerFiring = partnerFiring
        self.holderDividendDay = holderDividendDay
        self.holderDividendIDs = holderDividendIDs
    }

    private enum CodingKeys: String, CodingKey {
        case exit, partnerFiring, holderDividendDay, holderDividendIDs
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            exit: try container.decodeIfPresent(ExitRecord.self, forKey: .exit),
            partnerFiring: try container.decodeIfPresent(PartnerFiring.self, forKey: .partnerFiring),
            holderDividendDay: try container.decodeIfPresent(Int.self, forKey: .holderDividendDay),
            holderDividendIDs: try container.decodeIfPresent([UUID].self, forKey: .holderDividendIDs) ?? []
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(exit, forKey: .exit)
        try container.encodeIfPresent(partnerFiring, forKey: .partnerFiring)
        try container.encodeIfPresent(holderDividendDay, forKey: .holderDividendDay)
        if !holderDividendIDs.isEmpty { try container.encode(holderDividendIDs, forKey: .holderDividendIDs) }
    }
}

// MARK: - The exit

enum ExitSystem {
    /// Settles an exit whose price has just landed in company cash (for an
    /// IPO, the market's price; nothing lands). In order: the director's
    /// loan, out of company cash to the wallet; the holders' vested share
    /// of the price, as a ledger line; and the unvested, per `accelerate`.
    /// Returns no event and writes nothing with no loan and no holder.
    static func settle(
        kind: ExitKind,
        price: Int,
        accelerate: Bool,
        grants: BalanceConfig.GrantBalance,
        state: inout GameState
    ) -> [GameEvent] {
        let split = state.ladderExitSplit(price: price, grants: grants)
        guard !split.isEmpty else { return [] }

        var loanRepaid = 0
        if split.loan > 0 {
            loanRepaid = min(split.loan, max(0, state.company.cash))
            if loanRepaid > 0 {
                state.company.cash -= loanRepaid
                state.ledger.post(LedgerEntry(
                    day: state.day, amount: -loanRepaid, category: .other,
                    label: "Director's loan repaid from the price"
                ))
                state.life.wallet += loanRepaid
                state.economy.founderMoney.directorLoan -= loanRepaid
            }
        }

        // Fully vested from today: held for the longer of the cliff and the
        // vesting period, so `vestedEquity` reads the whole grant.
        let vestedFromToday = state.day - max(grants.vestDays, grants.cliffDays)
        var lines = split.holders
        var lapsed: [UUID] = []
        for line in lines.indices where lines[line].unvested > 0 {
            let holder = lines[line]
            guard let index = state.employees.firstIndex(where: { $0.id == holder.id && !$0.isFounder })
            else { continue }
            if accelerate {
                lines[line].paid += split.share(holder.unvested)
                state.employees[index].grantDay = vestedFromToday
            } else {
                state.investors.equityRemaining = min(100, state.investors.equityRemaining + holder.unvested)
                state.employees[index].grantedEquity = holder.vested
                state.employees[index].grantDay = holder.vested > 0 ? vestedFromToday : nil
                if let grant = state.networking.grants.firstIndex(where: {
                    $0.id == holder.id && $0.reason == .options
                }) {
                    if holder.vested > 0 {
                        state.networking.grants[grant].percent = holder.vested
                    } else {
                        state.networking.grants.remove(at: grant)
                    }
                }
                lapsed.append(holder.id)
            }
        }

        let record = ExitRecord(
            day: state.day, kind: kind, price: price, loanRepaid: loanRepaid, holders: lines,
            accelerated: accelerate, lapsedIDs: lapsed,
            leavingIDs: kind == .earnOut ? lapsed : []
        )
        if record.optionsPaid > 0 {
            let count = lines.count { $0.paid > 0 }
            state.ledger.post(LedgerEntry(
                day: state.day, amount: 0, category: .other,
                label: "Options paid from the price: \(record.optionsPaid.dollars) to "
                    + "\(count) holder\(count == 1 ? "" : "s")"
            ))
        }
        var joins = state.joins ?? JoinsState()
        joins.exit = record
        state.joins = joins
        return [.exitSettled(
            kind: kind, loanRepaid: loanRepaid, optionsPaid: record.optionsPaid,
            holders: lines.count, lapsed: lapsed.count, accelerated: accelerate, day: state.day
        )]
    }

    /// The weekly pass: the holders whose options lapsed at an earn-out's
    /// signing clear their desks (loyalty 0, the ordinary quit path, an
    /// alumni entry). Returns on its first line with nobody leaving — every
    /// run that never signed one. Draws nothing.
    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        guard let leaving = state.joins?.exit?.leavingIDs, !leaving.isEmpty else { return [] }
        guard state.gameOver == nil, state.day % GameState.daysPerWeek == 0 else { return [] }
        state.joins?.exit?.leavingIDs = []
        var events: [GameEvent] = []
        for id in leaving {
            guard let index = state.employees.firstIndex(where: { $0.id == id && !$0.isFounder }) else { continue }
            state.employees[index].loyalty = 0
            let employee = state.employees.remove(at: index)
            state.economy.lastRecognitionDay[id] = nil
            if state.economy.pendingResignation?.employeeID == id {
                state.economy.pendingResignation = nil
            }
            events.append(.employeeQuit(employeeID: id, name: employee.name, day: state.day))
            events.append(contentsOf: SocialSystem.friendDeparted(id, state: &state, balance: balance))
            events.append(contentsOf: NetworkingSystem.departed(
                employee, reason: .quit, state: &state, balance: balance
            ))
            events.append(.exitHolderLeft(employeeID: id, name: employee.name, day: state.day))
        }
        return events
    }
}

extension GameState {
    /// What filing to go public today pays the founder, once the exit has
    /// read the options: the unvested lapse and come home, because there
    /// is no company left to keep them in. Exactly the old number with no
    /// grant out.
    public func exitIPOProceeds(balance: BalanceConfig) -> Int {
        let valuation = Double(companyValuation(balance: balance)) * balance.investors.ipoValuationMultiple
        let split = ladderExitSplit(price: Int(valuation.rounded()), balance: balance)
        return Int((valuation * (investors.equityRemaining + split.unvestedPoints) / 100).rounded())
    }

    /// Holders whose options lapsed at an exit.
    public var exitLapsedHolderCount: Int { joins?.exit?.lapsedIDs.count ?? 0 }

    /// The morning question after the founder fired their partner with
    /// cause, while it is open.
    public var openPartnerFiring: PartnerFiring? {
        guard let firing = joins?.partnerFiring, firing.isOpen else { return nil }
        return firing
    }
}

// MARK: - Firing the partner

extension RelationshipSystem {
    /// Called from `EmployeeSystem.fire`'s T1 pair with the person just
    /// removed: if it was the partner, the marriage reads it — affection
    /// off today, the payroll link cleared, the alumni entry closed (they
    /// are family, not an alumnus: the partner row hires them back, if
    /// anything does), and the morning after on the books. Nothing for
    /// anybody else.
    static func partnerFired(
        _ employee: Employee,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard employee.id == state.life.family.partnerEmployeeID else { return [] }
        state.life.family.partnerEmployeeID = nil
        guard state.life.family.stage != .single else { return [] }
        let config = balance.exits
        state.life.family.affection = max(0, state.life.family.affection - config.partnerFiredAffection)
        if let contact = state.networking.contacts.firstIndex(where: { $0.id == employee.id }) {
            state.networking.contacts[contact].outcome = .lost
        }
        state.life.phone.post(
            "You could have told me at home. You didn't even do that.",
            from: .partner, day: state.day
        )
        var joins = state.joins ?? JoinsState()
        joins.partnerFiring = PartnerFiring(employeeID: employee.id, name: employee.name, day: state.day)
        state.joins = joins
        return [.partnerFired(employeeID: employee.id, name: employee.name, day: state.day)]
    }

    /// Daily, from `run`: the morning after. A plain firing closes — the
    /// fight was the day itself. A firing with cause (the founder's own
    /// `fireWithCause` wrote it down) lands the rest of the affection and
    /// puts a bag by the door; left unanswered for the balance's days,
    /// staying is the answer. Returns on its first line on every run that
    /// never fired a partner.
    static func partnerFiringMorning(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        guard var firing = state.joins?.partnerFiring, firing.resolvedDay == nil else { return [] }
        if state.life.family.stage == .single {
            firing.resolvedDay = state.day
            state.joins?.partnerFiring = firing
            return []
        }
        guard let morning = firing.morningDay else {
            guard state.day > firing.day else { return [] }
            guard state.interactions.firedWithCauseIDs.contains(firing.employeeID) else {
                firing.resolvedDay = state.day
                state.joins?.partnerFiring = firing
                return []
            }
            let config = balance.exits
            firing.withCause = true
            firing.morningDay = state.day
            state.joins?.partnerFiring = firing
            let rest = max(0, config.partnerFiredWithCauseAffection - config.partnerFiredAffection)
            state.life.family.affection = max(0, state.life.family.affection - rest)
            state.life.phone.post(
                "For cause. In writing. I packed a bag last night — it's by the door. "
                    + "Tell me which of us is using it.",
                from: .partner, day: state.day
            )
            return [.partnerFiringMorning(day: state.day)]
        }
        if state.day >= morning + max(1, balance.exits.partnerFiringRespondDays) {
            return answerPartnerFiring(packBag: false, state: &state, balance: balance, content: content)
        }
        return []
    }

    /// The answer to the bag by the door. Ignored with no question open.
    static func answerPartnerFiring(
        packBag: Bool,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard var firing = state.joins?.partnerFiring, firing.isOpen else { return [] }
        firing.answer = packBag ? .packBag : .stay
        firing.resolvedDay = state.day
        state.joins?.partnerFiring = firing
        var events: [GameEvent] = [.partnerFiringAnswered(packBag: packBag, day: state.day)]
        if packBag {
            // K7's "Pack a bag": the marriage as it stood is kept, so the
            // settlement can follow.
            state.life.phone.post(FamilyConfession.leave.line, from: .partner, day: state.day, fromFounder: true)
            FamilyDramaSystem.snapshotLeaving(&state)
            events.append(contentsOf: InteractionSystem.breakUp(state: &state, balance: balance, content: content))
        } else {
            state.life.family.affection = max(
                0, state.life.family.affection - balance.exits.partnerFiringStayAffection
            )
            state.life.phone.post(
                "Fine. The bag goes back in the wardrobe. Don't ever ask me to work for you again.",
                from: .partner, day: state.day
            )
        }
        return events
    }
}

// MARK: - Debug

#if DEBUG
/// `-autoRoute t1-…` with `-autoFixture release-studio-day400`: dresses the
/// loaded save through the engine for a screenshot. Debug builds only;
/// nothing in the game sends `.exitsDebugSeed`.
///
/// - `buyout` / `earnout`: two holders (2% granted two years ago, half
///   vested; 1% granted today, none vested), a $25,000 director's loan, and
///   a strategic bid at 1.0× today's valuation on the desk.
/// - `sellup`: the same holders and loan, the company nine days in the red.
/// - `dividend`: the same holders, then the largest dividend allowed today.
/// - `firing`: the partner hired, then fired with cause, the morning after.
enum ExitsDebugSeed {
    static func apply(
        scenario: String,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        var events: [GameEvent] = []
        switch scenario {
        case "buyout", "earnout", "sellup", "dividend":
            events += seedHolders(&state, balance)
            if scenario != "dividend" {
                state.life.wallet = max(state.life.wallet, 25_000)
                events += FounderMoneySystem.lend(amount: 25_000, state: &state)
            }
        default:
            break
        }
        switch scenario {
        case "buyout", "earnout":
            guard let buyer = GameState.dealStrongest(state.rivals.rivals) else { break }
            state.rivals.pendingBuyout = BuyoutOffer(
                rivalID: buyer.id,
                amount: state.companyValuation(balance: balance),
                respondByDay: state.day + balance.rivals.buyoutResponseDays
            )
            state.rivals.lastBuyoutDay = state.day
            state.rivals.lastBuyoutWasStrategic = true
        case "sellup":
            state.company.cash = min(state.company.cash, -4_000)
            state.company.daysInDebt = max(state.company.daysInDebt, 9)
        case "dividend":
            let most = state.founderMoneyMaxDividend(balance: balance)
            if most > 0 {
                events += FounderMoneySystem.declareDividend(amount: most, state: &state, balance: balance)
            }
        case "firing":
            events += PartnerDebugSeed.apply(stage: "hired", state: &state, balance: balance, content: content)
            if let id = state.life.family.partnerEmployeeID {
                events += InteractionSystem.fireWithCause(employeeID: id, state: &state, balance: balance)
                state.joins?.partnerFiring?.day = state.day - 1
                events += RelationshipSystem.partnerFiringMorning(&state, balance, content)
            }
        default:
            break
        }
        return events
    }

    /// The two longest-serving people who could hold options: 2% for the
    /// first, granted two years back (half vested); 1% for the second,
    /// granted today.
    private static func seedHolders(_ state: inout GameState, _ balance: BalanceConfig) -> [GameEvent] {
        let people = state.employees
            .filter { !$0.isFounder && !$0.isCofounder && !$0.holdsOptions }
            .sorted { ($0.hiredDay, $0.id.uuidString) < ($1.hiredDay, $1.id.uuidString) }
        var events: [GameEvent] = []
        for (person, percent) in zip(people.prefix(2), [2, 1]) {
            events += EmployeeSystem.grantEquity(
                employeeID: person.id, percent: percent, state: &state, balance: balance
            )
        }
        if let first = people.first, let index = state.employees.firstIndex(where: { $0.id == first.id }) {
            state.employees[index].grantDay = state.day - balance.ladder.grants.vestDays / 2
        }
        return events
    }
}
#endif

// MARK: end T1
