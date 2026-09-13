import Foundation

// MARK: T3 (people)

/// Iteration 17 — T3. What letting somebody go costs, as numbers the
/// buttons print before the tap: the plain firing's notice, the with-cause
/// claim's risk and the layoff's whole ledger. The system that spends them
/// is `SeveranceSystem`; everything here is a pure read.

/// A plain firing's notice: a week of salary per full quarter served, up
/// to `severance.maxWeeks`.
public struct SeveranceNotice: Equatable, Sendable {
    public var weeks: Int
    public var weeklySalary: Int
    public var amount: Int { weeks * weeklySalary }
}

/// Letting several people go at once, priced.
public struct SeveranceLayoffQuote: Equatable, Sendable {
    public var count: Int
    /// Every picked person's notice, summed.
    public var severance: Int
    /// Morale on each of the people who stay (negative).
    public var moraleHit: Double
    /// Reputation lost on the day.
    public var reputationCost: Double
    /// Board pressure a seated board watching headcount adds (0 without one).
    public var boardPressure: Double
    public var headcountAfter: Int
    public var weeklyPayrollSaved: Int
    public var cashAfter: Int
}

extension GameState {
    /// The notice a plain firing of `employeeID` pays today; `nil` for the
    /// founder and for anybody not on payroll.
    public func severanceNotice(employeeID: UUID, balance: BalanceConfig) -> SeveranceNotice? {
        guard let employee = employee(id: employeeID), !employee.isFounder else { return nil }
        let config = balance.severance
        let quarters = max(0, day - employee.hiredDay) / GameState.daysPerWeek / 13
        let weeks = min(max(0, config.maxWeeks), quarters * max(0, config.weeksPerQuarterTenure))
        return SeveranceNotice(weeks: weeks, weeklySalary: max(0, employee.weeklySalary))
    }

    /// Why a plain firing with notice would be refused today, or `nil`.
    public func severanceNoticeBlocker(employeeID: UUID, balance: BalanceConfig) -> String? {
        guard gameOver == nil else { return "The company is over" }
        guard let notice = severanceNotice(employeeID: employeeID, balance: balance) else {
            return "They don't work here any more"
        }
        guard notice.amount > company.cash else { return nil }
        return "Their notice is \(notice.amount.dollars) and there is \(company.cash.dollars)"
    }

    /// What firing `employeeID` for cause might cost: the claim's price
    /// when their morale is over the line, `nil` when they would not bring
    /// one.
    public func severanceClaimPrice(employeeID: UUID, balance: BalanceConfig) -> Int? {
        guard let employee = employee(id: employeeID), !employee.isFounder,
              employee.morale > balance.severance.claimMoraleOver
        else { return nil }
        return max(0, balance.severance.claimWeeksPay) * max(0, employee.weeklySalary)
    }

    /// Letting `employeeIDs` go at once, priced. Unknown ids and the
    /// founder are ignored.
    public func severanceLayoffQuote(employeeIDs: [UUID], balance: BalanceConfig) -> SeveranceLayoffQuote {
        let config = balance.severance
        let picked = severanceLayoffPicks(employeeIDs)
        let severance = picked.reduce(0) { $0 + (severanceNotice(employeeID: $1.id, balance: balance)?.amount ?? 0) }
        let count = picked.count
        let moraleHit = count == 0 ? 0 : max(config.layoffMoraleCap, config.layoffMoralePerHead * Double(count))
        return SeveranceLayoffQuote(
            count: count,
            severance: severance,
            moraleHit: moraleHit,
            reputationCost: Double(count / 3) * config.layoffReputationPerThree,
            boardPressure: count == 0 ? 0 : severanceLayoffBoardPressure(balance: balance),
            headcountAfter: headcount - count,
            weeklyPayrollSaved: picked.reduce(0) { $0 + $1.weeklySalary },
            cashAfter: company.cash - severance
        )
    }

    /// Why the layoff would be refused today, or `nil`.
    public func severanceLayoffBlocker(employeeIDs: [UUID], balance: BalanceConfig) -> String? {
        guard gameOver == nil else { return "The company is over" }
        let quote = severanceLayoffQuote(employeeIDs: employeeIDs, balance: balance)
        guard quote.count > 0 else { return "Pick who goes" }
        guard quote.severance > company.cash else { return nil }
        return "The notice is \(quote.severance.dollars) and there is \(company.cash.dollars)"
    }

    /// The people a layoff of `employeeIDs` would actually let go, in
    /// roster order, each once.
    func severanceLayoffPicks(_ employeeIDs: [UUID]) -> [Employee] {
        let wanted = Set(employeeIDs)
        return employees.filter { wanted.contains($0.id) && !$0.isFounder }
    }

    /// A seated board that grades headcount reads a layoff as a miss:
    /// the review's own miss step, weighted by the share of seated boards
    /// that watch headcount, never to the door outside a meeting.
    func severanceLayoffBoardPressure(balance: BalanceConfig) -> Double {
        let watching = investors.boardExpectations
        let headcountBoards = watching.filter { $0 == .headcount }.count
        guard headcountBoards > 0 else { return 0 }
        let share = Double(headcountBoards) / Double(watching.count)
        let before = investors.boardPressure
        let ceiling = balance.investors.boardOustPressure - 1
        return max(0, min(ceiling, before + balance.investors.pressurePerMiss * share) - before)
    }
}

// MARK: end T3
