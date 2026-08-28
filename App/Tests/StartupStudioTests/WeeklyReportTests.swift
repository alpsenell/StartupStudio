import TycoonEngine
import XCTest

@testable import StartupStudio

/// The weekly report is the game's retention loop; if its numbers drift
/// from the ledger the player stops trusting it. These reconcile every
/// figure it shows against the postings it is derived from.
final class WeeklyReportTests: XCTestCase {
    /// The bundled, difficulty-adjusted balance the app itself runs on.
    private static let balance: BalanceConfig = {
        guard let bundled = try? BalanceConfig.loadBundled() else {
            fatalError("TycoonEngine is missing its bundled Balance.json resource")
        }
        return bundled.adjusted(for: .normal)
    }()

    /// A state at the start of week 3 (day 14) with a known set of
    /// postings across weeks 1 and 2.
    private func fixtureState() -> GameState {
        var state = GameState.newGame(
            companyName: "Fixture Softworks",
            seed: 4242,
            balance: Self.balance,
            difficulty: .normal
        )
        state.day = 14
        state.company.cash = 12_500
        // Week 2 = days 7...13: what the report should cover.
        state.ledger.entries = [
            // Week 1 — must be excluded.
            LedgerEntry(day: 3, amount: 9_000, category: .contracts, label: "Week 1 contract"),
            LedgerEntry(day: 5, amount: -1_000, category: .payroll, label: "Week 1 payroll"),
            // Week 2 — the reported week.
            LedgerEntry(day: 7, amount: 4_000, category: .sales, label: "Sales"),
            LedgerEntry(day: 8, amount: 1_500, category: .contracts, label: "Contract payout"),
            LedgerEntry(day: 9, amount: -2_400, category: .payroll, label: "Payroll"),
            LedgerEntry(day: 9, amount: -400, category: .rent, label: "Rent"),
            LedgerEntry(day: 12, amount: -250, category: .operating, label: "Operating"),
            LedgerEntry(day: 13, amount: 500, category: .sales, label: "Sales"),
            // Week 3 (today) — must be excluded.
            LedgerEntry(day: 14, amount: -99_999, category: .other, label: "Today"),
        ]
        return state
    }

    func testCoversExactlyTheWeekThatJustEnded() {
        let report = WeeklyReport(state: fixtureState(), balance: Self.balance, weeklyBurn: 3_050)
        XCTAssertEqual(report.weekIndex, 2)
        XCTAssertEqual(report.dayRange, 7...13)
    }

    func testIncomeAndExpensesReconcileWithTheLedger() {
        let state = fixtureState()
        let report = WeeklyReport(state: state, balance: Self.balance, weeklyBurn: 3_050)

        let expectedIncome = state.ledger.entries
            .filter { (7...13).contains($0.day) && $0.amount > 0 }
            .reduce(0) { $0 + $1.amount }
        let expectedExpenses = state.ledger.entries
            .filter { (7...13).contains($0.day) && $0.amount < 0 }
            .reduce(0) { $0 - $1.amount }

        XCTAssertEqual(report.income, expectedIncome)
        XCTAssertEqual(report.income, 6_000)
        XCTAssertEqual(report.expenses, expectedExpenses)
        XCTAssertEqual(report.expenses, 3_050)
        XCTAssertEqual(report.net, 2_950)
        XCTAssertEqual(report.cash, state.company.cash)
    }

    func testCategoryBreakdownsSumToTheTotals() {
        let report = WeeklyReport(state: fixtureState(), balance: Self.balance, weeklyBurn: 3_050)
        XCTAssertEqual(report.incomeByCategory.reduce(0) { $0 + $1.amount }, report.income)
        XCTAssertEqual(report.expensesByCategory.reduce(0) { $0 + $1.amount }, report.expenses)
        // Sales (4,500) leads contracts (1,500); payroll (2,400) leads rent.
        XCTAssertEqual(report.incomeByCategory.first?.category, .sales)
        XCTAssertEqual(report.incomeByCategory.first?.amount, 4_500)
        XCTAssertEqual(report.expensesByCategory.first?.category, .payroll)
        XCTAssertEqual(report.expensesByCategory.first?.amount, 2_400)
    }

    func testBreakdownOrderIsStableAcrossBuilds() {
        // Dictionary iteration order is not stable; the report sorts.
        let first = WeeklyReport(state: fixtureState(), balance: Self.balance, weeklyBurn: 3_050)
        let second = WeeklyReport(state: fixtureState(), balance: Self.balance, weeklyBurn: 3_050)
        XCTAssertEqual(first.expensesByCategory.map(\.category), second.expensesByCategory.map(\.category))
        XCTAssertEqual(first.incomeByCategory.map(\.category), second.incomeByCategory.map(\.category))
    }

    func testRunwayUsesTheEnginesOwnBurnFigure() {
        let report = WeeklyReport(state: fixtureState(), balance: Self.balance, weeklyBurn: 2_500)
        XCTAssertEqual(report.weeklyBurn, 2_500)
        XCTAssertEqual(report.runwayWeeks, 12_500 / 2_500)
    }

    func testRunwayIsUnknownWithoutBurn() {
        let report = WeeklyReport(state: fixtureState(), balance: Self.balance, weeklyBurn: 0)
        XCTAssertNil(report.runwayWeeks)
    }

    func testEventsAreLimitedToTheReportedWeek() {
        var state = fixtureState()
        state.eventLog = [
            .candidatesRefreshed(day: 2),
            .hired(employeeID: UUID(), day: 8),
            .marketBoom(topicID: "fitness", day: 11),
            .contractOffersRefreshed(day: 14),
        ]
        let report = WeeklyReport(state: state, balance: Self.balance, weeklyBurn: 100)
        XCTAssertEqual(report.events.count, 2)
        // Newest first.
        if case .marketBoom = report.events.first {} else {
            XCTFail("expected the newest in-week event first")
        }
    }

    func testMoraleDeltaComparesWithThePreviousReport() {
        // Just under the engine's own quit threshold, so this hire is one
        // the report is right to worry about on any difficulty.
        let morale = Self.balance.staff.quitMoraleThreshold - 2
        var state = fixtureState()
        state.employees.append(staffer(morale: morale))
        let report = WeeklyReport(
            state: state, balance: Self.balance, weeklyBurn: 100, previousMorale: morale + 12
        )
        XCTAssertEqual(report.averageMorale, morale, accuracy: 0.001)
        XCTAssertEqual(report.moraleDelta, -12, accuracy: 0.001)
        XCTAssertEqual(report.unhappy.count, 1)
        XCTAssertEqual(report.unhappy.first?.name, "Priya")
    }

    func testHappyStaffAreNotFlagged() {
        var state = fixtureState()
        state.employees.append(staffer(morale: Self.balance.staff.quitMoraleThreshold + 40))
        let report = WeeklyReport(state: state, balance: Self.balance, weeklyBurn: 100)
        XCTAssertTrue(report.unhappy.isEmpty)
    }

    private func staffer(morale: Double) -> Employee {
        Employee(
            id: UUID(),
            name: "Priya",
            skills: SkillSet(coding: 50, design: 30, marketing: 20),
            weeklySalary: 900,
            assignment: .idle,
            isFounder: false,
            hiredDay: 1,
            appearanceSeed: 9,
            morale: morale,
            role: .backend
        )
    }

    func testFirstReportHasNoPhantomDeltas() {
        let report = WeeklyReport(state: fixtureState(), balance: Self.balance, weeklyBurn: 100)
        XCTAssertEqual(report.moraleDelta, 0, accuracy: 0.001)
        XCTAssertEqual(report.meterDeltas.energy, 0, accuracy: 0.001)
        XCTAssertEqual(report.meterDeltas.mood, 0, accuracy: 0.001)
    }

    func testEventDayReadsEveryEventsDay() {
        XCTAssertEqual(EventDay.of(.gameOver(day: 41)), 41)
        XCTAssertEqual(EventDay.of(.reviewsIn(productID: UUID(), averageScore: 62, day: 118)), 118)
        XCTAssertEqual(EventDay.of(.weekendSpent(activity: .rest, day: 7)), 7)
        XCTAssertEqual(
            EventDay.of(.contractDelivered(contractID: UUID(), quality: 70, payout: 900, day: 33)),
            33
        )
    }
}
