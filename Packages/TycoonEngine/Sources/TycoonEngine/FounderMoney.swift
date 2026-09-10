import Foundation
import TycoonContent

// Iteration 15 — K1 (founder money).
//
// Three pipes between the founder's wallet and the company's account,
// where there used to be one (the salary) and a trapdoor (the rescue):
//
// 1. **The director's loan** (life F1). The founder lends the company
//    their own money; it sits on the books ahead of the bank, is repaid on
//    demand while cash covers it, and comes out of the next accepted term
//    sheet before the cheque lands. Lost if the company goes under.
// 2. **The dividend** (life F1 + company C2). The company pays `amount`;
//    the founder takes `amount × equityRemaining / 100` home and the rest
//    leaves for the cap table, printed line by line. Once a quarter, never
//    below eight weeks of runway, never in debt, on an earn-out or with a
//    case open. A seated board adds pressure unless the last quarter was
//    profitable; the ledger posts it as an expense, so the quarter that
//    carries it must still grow to keep the profitable streak; and for
//    thirteen weeks the take reads as founder pay to the team and the
//    board's pay line.
// 3. **The rescue as a choice** (life F9). In a run a person is playing
//    (`doors.armed`), the eviction warning becomes a question on the queue
//    — take the company's money in public, move down, or sell something —
//    instead of `checkEviction` quietly raising the salary. A rescue the
//    founder takes is not exempt from the pay line and marks the name for
//    a year. Bots never arm the doors, so every measured run keeps the old
//    automatic path, exempt, exactly as it was.
//
// Nothing here draws from `rng` or `worldRNG`. `FounderMoneyState.empty`
// is never encoded, so a run that touched none of it writes the bytes it
// always wrote.

// MARK: - State

/// The founder's own money in the company, and the one question the
/// landlord can put on the queue. Lives on `EconomyState.founderMoney`.
public struct FounderMoneyState: Codable, Equatable, Sendable {
    /// What the company owes the founder: lent, not yet repaid.
    public var directorLoan: Int
    /// The day the last dividend was declared.
    public var lastDividendDay: Int?
    /// What the founder took home from it — the number the team reads as
    /// pay for `dividendPayWeeks`.
    public var lastDividendTake: Int
    /// The last day an answer to the landlord counts; set while the rescue
    /// question is open (armed runs only).
    public var rescueRespondByDay: Int?
    /// The founder answered "sell something": the question stays open, on
    /// the rail as a room (the assets), and counts only if the wallet is
    /// back above the line by `rescueRespondByDay`.
    public var rescueSelling: Bool
    /// The day the founder chose to take the company's rescue. Read by the
    /// pay line (a chosen rescue is not exempt) and by the name, for
    /// `rescueStandingDays`.
    public var rescueTakenDay: Int?

    public init(
        directorLoan: Int = 0,
        lastDividendDay: Int? = nil,
        lastDividendTake: Int = 0,
        rescueRespondByDay: Int? = nil,
        rescueSelling: Bool = false,
        rescueTakenDay: Int? = nil
    ) {
        self.directorLoan = directorLoan
        self.lastDividendDay = lastDividendDay
        self.lastDividendTake = lastDividendTake
        self.rescueRespondByDay = rescueRespondByDay
        self.rescueSelling = rescueSelling
        self.rescueTakenDay = rescueTakenDay
    }

    /// Nothing lent, nothing paid out, nothing asked.
    public static let empty = FounderMoneyState()

    public var isEmpty: Bool { self == .empty }

    /// Whether the landlord's question is on the queue.
    public var isRescueOpen: Bool { rescueRespondByDay != nil }

    private enum CodingKeys: String, CodingKey {
        case directorLoan, lastDividendDay, lastDividendTake
        case rescueRespondByDay, rescueSelling, rescueTakenDay
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            directorLoan: try container.decodeIfPresent(Int.self, forKey: .directorLoan) ?? 0,
            lastDividendDay: try container.decodeIfPresent(Int.self, forKey: .lastDividendDay),
            lastDividendTake: try container.decodeIfPresent(Int.self, forKey: .lastDividendTake) ?? 0,
            rescueRespondByDay: try container.decodeIfPresent(Int.self, forKey: .rescueRespondByDay),
            rescueSelling: try container.decodeIfPresent(Bool.self, forKey: .rescueSelling) ?? false,
            rescueTakenDay: try container.decodeIfPresent(Int.self, forKey: .rescueTakenDay)
        )
    }

    /// Only what is set.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if directorLoan != 0 { try container.encode(directorLoan, forKey: .directorLoan) }
        try container.encodeIfPresent(lastDividendDay, forKey: .lastDividendDay)
        if lastDividendTake != 0 { try container.encode(lastDividendTake, forKey: .lastDividendTake) }
        try container.encodeIfPresent(rescueRespondByDay, forKey: .rescueRespondByDay)
        if rescueSelling { try container.encode(rescueSelling, forKey: .rescueSelling) }
        try container.encodeIfPresent(rescueTakenDay, forKey: .rescueTakenDay)
    }
}

/// The founder's three answers to the landlord.
public enum FounderMoneyRescueAnswer: String, Codable, Equatable, Sendable, CaseIterable {
    /// The company raises the salary to clear the hole, in public.
    case take
    /// One home down the ladder, today.
    case moveDown
    /// Keep the question open and go and sell something: it counts only
    /// if the wallet is back above the line by the deadline.
    case sell
}

/// One holder's share of a dividend, as the sheet prints it.
public struct FounderMoneyDividendLine: Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    /// Percentage points of the company.
    public var percent: Double
    public var amount: Int
    public var isFounder: Bool

    public init(id: String, name: String, percent: Double, amount: Int, isFounder: Bool) {
        self.id = id
        self.name = name
        self.percent = percent
        self.amount = amount
        self.isFounder = isFounder
    }
}

// MARK: - Queries

extension GameState {
    /// The founder's money in the company.
    public var founderMoney: FounderMoneyState { economy.founderMoney }

    /// What the founder takes home from a dividend of `amount`.
    public func founderMoneyDividendTake(_ amount: Int) -> Int {
        Int((Double(max(0, amount)) * investors.equityRemaining / 100).rounded())
    }

    /// The runway floor in dollars: what a dividend must leave behind.
    public func founderMoneyDividendFloor(balance: BalanceConfig) -> Int {
        max(0, balance.founderMoney.dividendRunwayWeeks) * queueWeeklyBurn(balance: balance)
    }

    /// The largest dividend the runway floor allows today, before the
    /// other gates.
    public func founderMoneyMaxDividend(balance: BalanceConfig) -> Int {
        max(0, company.cash - founderMoneyDividendFloor(balance: balance))
    }

    /// The first day the next dividend may be declared, or `nil` when one
    /// may be declared today as far as the calendar goes.
    public func founderMoneyNextDividendDay(balance: BalanceConfig) -> Int? {
        guard let last = economy.founderMoney.lastDividendDay else { return nil }
        let next = last + max(1, balance.founderMoney.dividendIntervalDays)
        return next > day ? next : nil
    }

    /// Why a dividend of `amount` would be refused, or `nil` when it would
    /// be paid. Mirrors `FounderMoneySystem.declareDividend`, in the order
    /// the founder would hit the gates.
    public func founderMoneyDividendBlocker(amount: Int, balance: BalanceConfig) -> String? {
        let config = balance.founderMoney
        // Merge glue (K1's report): a sole owner could take most of the
        // garage's seed cash home on day one. The company has to have
        // shipped something first.
        if !products.contains(where: { if case .released = $0.stage { return true } else { return false } }) {
            return "Not before the company has shipped a product"
        }
        if investors.earnOut != nil { return "Not while the acquirer's earn-out runs" }
        if FounderStanding.openCases(self) > 0 { return "Not with a case open against you" }
        if company.cash < 0 { return "Not while the company is in the red" }
        if loanBalance > 0 { return "Clear the bank loan first (\(loanBalance.money) owed)" }
        if let next = founderMoneyNextDividendDay(balance: balance) {
            return "One a quarter: the next can be paid on day \(next)"
        }
        let most = founderMoneyMaxDividend(balance: balance)
        if most <= 0 {
            return "It would leave under \(config.dividendRunwayWeeks) weeks of runway (\(founderMoneyDividendFloor(balance: balance).money))"
        }
        if amount <= 0 { return "Choose an amount" }
        if amount > most {
            return "At most \(most.money): \(config.dividendRunwayWeeks) weeks of runway stay in the bank"
        }
        return nil
    }

    /// What `amount` pays each holder, founder first, then the rounds,
    /// the people who took equity, the ex, and whoever holds the rest (a
    /// co-founder). Printed line by line on the money sheet.
    public func founderMoneyDividendSplit(amount: Int) -> [FounderMoneyDividendLine] {
        let total = Double(max(0, amount))
        func dollars(_ percent: Double) -> Int { Int((total * percent / 100).rounded()) }
        var lines: [FounderMoneyDividendLine] = [
            FounderMoneyDividendLine(
                id: "founder", name: "You", percent: investors.equityRemaining,
                amount: founderMoneyDividendTake(amount), isFounder: true
            ),
        ]
        var named = investors.equityRemaining
        for round in investors.rounds where round.equity > 0 {
            named += round.equity
            lines.append(FounderMoneyDividendLine(
                id: "round-\(round.investorID)", name: round.investorName,
                percent: round.equity, amount: dollars(round.equity), isFounder: false
            ))
        }
        for grant in networking.grants where grant.percent > 0 {
            named += grant.percent
            lines.append(FounderMoneyDividendLine(
                id: "grant-\(grant.id.uuidString)", name: grant.name,
                percent: grant.percent, amount: dollars(grant.percent), isFounder: false
            ))
        }
        if let ex = exPartnerEquity {
            named += ex.points
            lines.append(FounderMoneyDividendLine(
                id: "ex", name: ex.name, percent: ex.points, amount: dollars(ex.points), isFounder: false
            ))
        }
        let rest = 100 - named
        if rest > 0.05 {
            let cofounder = employees.first { $0.isCofounder }?.name
            lines.append(FounderMoneyDividendLine(
                id: "rest", name: cofounder ?? "Other holders",
                percent: rest, amount: dollars(rest), isFounder: false
            ))
        }
        return lines
    }

    /// What the founder's last dividend adds to their weekly pay while the
    /// team and the board still read it: `take / dividendPayWeeks` for
    /// that many weeks after it was paid, zero otherwise.
    public func founderMoneyDividendWeeklyPay(balance: BalanceConfig) -> Int {
        let money = economy.founderMoney
        guard let last = money.lastDividendDay, money.lastDividendTake > 0 else { return 0 }
        let weeks = max(1, balance.founderMoney.dividendPayWeeks)
        guard day - last < weeks * GameState.daysPerWeek else { return 0 }
        return Int((Double(money.lastDividendTake) / Double(weeks)).rounded())
    }

    /// The last day the dividend still reads as pay, or `nil`.
    public func founderMoneyDividendPayUntilDay(balance: BalanceConfig) -> Int? {
        guard founderMoneyDividendWeeklyPay(balance: balance) > 0,
              let last = economy.founderMoney.lastDividendDay
        else { return nil }
        return last + max(1, balance.founderMoney.dividendPayWeeks) * GameState.daysPerWeek - 1
    }

    /// Whether a seated board would add pressure for a dividend today: it
    /// does unless the last quarter was profitable.
    public var founderMoneyDividendAngersBoard: Bool {
        investors.hasBoard && investors.profitableQuarters == 0
    }

    /// Why lending `amount` would be refused, or `nil`.
    public func founderMoneyLendBlocker(amount: Int) -> String? {
        if StakeLadder.refuses(.lendToCompany(amount: max(1, amount)), at: rules.stake) {
            return "No credit at this stake — not even yours"
        }
        if life.wallet <= 0 { return "Your wallet is empty" }
        if amount <= 0 { return "Choose an amount" }
        if amount > life.wallet { return "Your wallet holds \(life.wallet.money)" }
        return nil
    }

    /// Why repaying `amount` of the director's loan would be refused, or
    /// `nil`.
    public func founderMoneyRepayBlocker(amount: Int) -> String? {
        let owed = economy.founderMoney.directorLoan
        if owed <= 0 { return "The company owes you nothing" }
        if company.cash <= 0 { return "The company has no cash to repay you with" }
        if amount <= 0 { return "Choose an amount" }
        return nil
    }

    /// The weekly salary the company's rescue would pay today: the
    /// founder's weekly costs plus the overdraft amortised over
    /// `evictionRecoveryWeeks`, capped at the salary ceiling — the number
    /// `checkEviction` always paid.
    public func founderMoneyRescueSalary(balance: BalanceConfig) -> Int {
        LifeSystem.evictionRescueSalary(self, balance)
    }

    /// Why "take the rescue" would be refused, or `nil`.
    public func founderMoneyRescueTakeBlocker(balance: BalanceConfig) -> String? {
        guard economy.founderMoney.isRescueOpen else { return "Nobody is asking" }
        let rescue = founderMoneyRescueSalary(balance: balance)
        guard rescue > life.founderSalary else { return "Your salary already covers it" }
        let needed = rescue * GameState.daysPerWeek * 2
        guard company.cash >= needed else {
            return "The company can't carry \(rescue.money)/wk: it needs \(needed.money) in the bank"
        }
        return nil
    }

    /// Why "move down" would be refused, or `nil`.
    public var founderMoneyMoveDownBlocker: String? {
        guard economy.founderMoney.isRescueOpen else { return "Nobody is asking" }
        guard life.home.previous != nil else {
            return "There is nowhere cheaper than a \(life.home.displayName.lowercased())"
        }
        return nil
    }
}

// MARK: - The system

enum FounderMoneySystem {

    // MARK: The director's loan

    /// Wallet into company cash, owed back to the founder.
    static func lend(amount: Int, state: inout GameState) -> [GameEvent] {
        guard state.founderMoneyLendBlocker(amount: amount) == nil else { return [] }
        state.life.wallet -= amount
        post(amount, label: "Director's loan", to: &state)
        state.economy.founderMoney.directorLoan += amount
        return [.founderMoneyLoanMade(amount: amount, day: state.day)]
    }

    /// Company cash back into the wallet, capped by what is owed and by
    /// the cash on hand.
    static func repay(amount: Int, state: inout GameState) -> [GameEvent] {
        guard state.founderMoneyRepayBlocker(amount: amount) == nil else { return [] }
        let paid = min(amount, state.economy.founderMoney.directorLoan, state.company.cash)
        guard paid > 0 else { return [] }
        post(-paid, label: "Director's loan repaid", to: &state)
        state.life.wallet += paid
        state.economy.founderMoney.directorLoan -= paid
        return [.founderMoneyLoanRepaid(amount: paid, fromRound: false, day: state.day)]
    }

    /// The loan comes out of a new round before the cheque lands: called
    /// by `InvestorSystem.acceptOffer` the moment the money posts. A no-op
    /// (and no event) with nothing owed.
    static func repayFromRound(cheque: Int, investorName: String, state: inout GameState) -> [GameEvent] {
        let paid = min(state.economy.founderMoney.directorLoan, max(0, cheque))
        guard paid > 0 else { return [] }
        post(-paid, label: "Director's loan repaid from the \(investorName) round", to: &state)
        state.life.wallet += paid
        state.economy.founderMoney.directorLoan -= paid
        return [.founderMoneyLoanRepaid(amount: paid, fromRound: true, day: state.day)]
    }

    // MARK: The dividend

    static func declareDividend(
        amount: Int,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard state.founderMoneyDividendBlocker(amount: amount, balance: balance) == nil else { return [] }
        let take = state.founderMoneyDividendTake(amount)
        // An expense like any other: the quarter that carries it has to
        // grow past it to count as profitable (`quarterlyReview` compares
        // cash), which is the cost on the independent ladder.
        post(-amount, label: "Dividend", to: &state)
        state.life.wallet += take
        state.economy.founderMoney.lastDividendDay = state.day
        state.economy.founderMoney.lastDividendTake = take

        var added = 0.0
        if state.founderMoneyDividendAngersBoard {
            // The board objects now; it votes at the review. Never to the
            // door outside a meeting.
            let before = state.investors.boardPressure
            let ceiling = balance.investors.boardOustPressure - 1
            state.investors.boardPressure = max(
                before, min(ceiling, before + balance.founderMoney.dividendBoardPressure)
            )
            added = state.investors.boardPressure - before
        }
        return [.founderMoneyDividend(
            amount: amount, take: take, boardPressure: Int(added.rounded()), day: state.day
        )]
    }

    // MARK: The rescue (armed runs only)

    /// Called by `checkEviction` on a grace-period boundary in an armed
    /// run, in place of the automatic rescue: an unanswered question takes
    /// its default (move down), and while the founder is still in the hole
    /// with no rescue running the landlord asks again for the next period.
    static func rescueDeadline(_ state: inout GameState, _ balance: BalanceConfig) -> [GameEvent] {
        var events: [GameEvent] = []
        if state.economy.founderMoney.isRescueOpen {
            state.economy.founderMoney.rescueRespondByDay = nil
            state.economy.founderMoney.rescueSelling = false
            events.append(contentsOf: moveDown(&state, balance))
        }
        let rescueRunning = state.economy.rescueSalary != nil
            && state.economy.rescueSalary == state.life.founderSalary
        if !rescueRunning {
            state.economy.founderMoney.rescueRespondByDay = state.day
                + max(1, balance.economy.evictionGraceDays)
        }
        return events
    }

    static func answerRescue(
        _ answer: FounderMoneyRescueAnswer,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard state.economy.founderMoney.isRescueOpen else { return [] }
        switch answer {
        case .take:
            guard state.founderMoneyRescueTakeBlocker(balance: balance) == nil else { return [] }
            let rescue = state.founderMoneyRescueSalary(balance: balance)
            state.life.founderSalary = rescue
            state.economy.rescueSalary = rescue
            state.economy.founderMoney.rescueTakenDay = state.day
            closeRescue(&state)
            return [.founderMoneyRescueAnswered(answer: .take, salary: rescue, day: state.day)]
        case .moveDown:
            guard state.founderMoneyMoveDownBlocker == nil else { return [] }
            closeRescue(&state)
            return [.founderMoneyRescueAnswered(answer: .moveDown, salary: state.life.founderSalary, day: state.day)]
                + moveDown(&state, balance)
        case .sell:
            guard !state.economy.founderMoney.rescueSelling else { return [] }
            state.economy.founderMoney.rescueSelling = true
            return [.founderMoneyRescueAnswered(answer: .sell, salary: state.life.founderSalary, day: state.day)]
        }
    }

    private static func closeRescue(_ state: inout GameState) {
        state.economy.founderMoney.rescueRespondByDay = nil
        state.economy.founderMoney.rescueSelling = false
    }

    /// One home down the ladder, the way `checkEviction` has always moved
    /// a founder the company could not carry: half a breakup's mood.
    private static func moveDown(_ state: inout GameState, _ balance: BalanceConfig) -> [GameEvent] {
        guard let cheaper = state.life.home.previous else { return [] }
        state.life.home = cheaper
        state.life.meters.apply(mood: -balance.life.breakupMoodPenalty / 2)
        return [.homeDowngraded(tier: cheaper, day: state.day)]
    }

    // MARK: Ledger

    private static func post(_ amount: Int, label: String, to state: inout GameState) {
        state.company.cash += amount
        state.ledger.post(LedgerEntry(day: state.day, amount: amount, category: .other, label: label))
    }

    // MARK: Debug seeds

    /// `-autoFounderMoney loan|dividend|paid|rescue`: one situation each,
    /// dressed for a screenshot. Reached only through
    /// `.founderMoneyDebugSeed`, which the reducer applies in debug builds
    /// alone.
    static func debugSeed(
        _ kind: String,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        switch kind {
        case "loan":
            // A founder with savings and a company three weeks from the wall.
            state.life.wallet = max(state.life.wallet, 60_000)
            let burn = state.queueWeeklyBurn(balance: balance)
            state.company.cash = min(state.company.cash, max(1_000, burn * 3))
            return []
        case "dividend", "paid":
            // A seated fund, a quarter that lost money and a fat account.
            if state.investors.rounds.isEmpty {
                state.investors.equityRemaining = max(0, state.investors.equityRemaining - 22)
                state.investors.rounds.append(RaisedRound(
                    investorID: "k1-corvus", investorName: "Corvus Ventures",
                    amount: 400_000, equity: 22, valuation: 1_818_000,
                    day: max(0, state.day - 120), takesBoardSeat: true,
                    expects: .profitability
                ))
            }
            state.loanBalance = 0
            state.investors.profitableQuarters = 0
            state.economy.founderMoney.lastDividendDay = nil
            state.company.cash = max(
                state.company.cash, state.founderMoneyDividendFloor(balance: balance) + 250_000
            )
            guard kind == "paid" else { return [] }
            return declareDividend(amount: 200_000, state: &state, balance: balance)
        case "rescue":
            // Broke, warned, and a company that could carry them.
            state.doors.armed = true
            state.life.wallet = min(state.life.wallet, -4_200)
            if state.life.home == .studioFlat, let next = state.life.home.next { state.life.home = next }
            state.economy.evictionWarningDay = state.day
            state.economy.founderMoney.rescueRespondByDay = state.day
                + max(1, balance.economy.evictionGraceDays)
            state.company.cash = max(state.company.cash, 120_000)
            return [.evictionWarning(
                untilDay: state.day + balance.economy.evictionGraceDays, day: state.day
            )]
        default:
            return []
        }
    }
}

/// The app's `Int.money` (`Theme.swift`), repeated here as
/// `AssetsSystem.swift` does, because the refusal lines this file writes
/// are the player's own words. `12400` → `"$12,400"`.
private extension Int {
    var money: String {
        let sign = self < 0 ? "-" : ""
        let digits = String(magnitude)
        var grouped = ""
        for (offset, character) in digits.reversed().enumerated() {
            if offset != 0, offset.isMultiple(of: 3) { grouped.append(",") }
            grouped.append(character)
        }
        return sign + "$" + String(grouped.reversed())
    }
}
