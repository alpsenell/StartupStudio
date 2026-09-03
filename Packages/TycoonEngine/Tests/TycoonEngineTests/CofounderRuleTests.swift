import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

/// The co-founder's rules (WS-H): they work for equity until the office
/// can pay them, the loft puts them on payroll, firing them does not buy
/// the slice back, and the slice shows in every number that reads
/// `equityRemaining` — including the investor filter.
@Suite("Co-founder rules")
struct CofounderRuleTests {
    static func balance() throws -> BalanceConfig { try OriginTests.balance() }
    static let content = OriginTests.content
    static func newGame(_ origin: FoundingOrigin, seed: UInt64 = 4_242) throws -> GameState {
        try OriginTests.newGame(origin, seed: seed)
    }
    static func tick(_ state: inout GameState, days: Int) throws -> [GameEvent] {
        try OriginTests.tick(&state, days: days)
    }

    @Test func theCofounderWorksForEquityInTheGarageAndNotInTheLoft() throws {
        let balance = try Self.balance()
        var garage = try Self.newGame(.cofounded)
        let cofounder = try #require(garage.cofounder)
        #expect(garage.cofounderWorksForEquity(cofounder, balance: balance))

        var loft = garage
        loft.company.officeTier = .loft
        #expect(!loft.cofounderWorksForEquity(cofounder, balance: balance))

        // A $0 hire who is *not* a co-founder, for the contrast.
        var stranger = garage
        stranger.employees[1].isCofounder = false

        _ = try Self.tick(&garage, days: 28)
        _ = try Self.tick(&loft, days: 28)
        _ = try Self.tick(&stranger, days: 28)
        let garageMorale = try #require(garage.cofounder?.morale)
        let loftMorale = try #require(loft.cofounder?.morale)
        let strangerMorale = try #require(stranger.employees.first { $0.id == cofounder.id }?.morale)
        #expect(garageMorale > strangerMorale, "the same $0 is underpaid for a hire and the deal for a co-founder")
        #expect(garageMorale > loftMorale, "in the loft, $0 is underpaid even for a co-founder")
    }

    @Test func theLoftPutsTheCofounderOnPayroll() throws {
        let balance = try Self.balance()
        var state = try Self.newGame(.cofounded)
        state.company.cash += 100_000
        let cofounderID = try #require(state.cofounder).id

        let events = Reducer.apply(.upgradeOffice, to: &state, balance: balance, content: Self.content)
        #expect(state.company.officeTier == .loft)
        let cofounder = try #require(state.cofounder)
        let fair = Int(balance.fairWeeklyPay(for: cofounder).rounded())
        #expect(cofounder.weeklySalary == fair)
        #expect(cofounder.weeklySalary > 0)
        #expect(events.contains(.salaryChanged(employeeID: cofounderID, weeklySalary: fair, day: state.day)))
        #expect(!state.cofounderWorksForEquity(cofounder, balance: balance))

        // Once only: a second tier does not reset a salary the player
        // has since changed.
        state.company.cash += 100_000
        Reducer.apply(
            .adjustSalary(employeeID: cofounderID, weeklySalary: fair + 100),
            to: &state, balance: balance, content: Self.content
        )
        Reducer.apply(.upgradeOffice, to: &state, balance: balance, content: Self.content)
        #expect(state.company.officeTier == .studio)
        #expect(state.cofounder?.weeklySalary == fair + 100)
    }

    @Test func firingTheCofounderKeepsTheirSliceGone() throws {
        let balance = try Self.balance()
        var state = try Self.newGame(.cofounded)
        let cofounderID = try #require(state.cofounder).id

        let events = Reducer.apply(.fire(employeeID: cofounderID), to: &state, balance: balance, content: Self.content)
        #expect(!events.isEmpty)
        #expect(state.cofounder == nil)
        #expect(state.employees.count == 1)
        #expect(state.investors.equityRemaining == 70, "the 30% does not come back")
        #expect(state.founderEquity == 70)
    }

    /// Every valuation, exit and net-worth line reads `equityRemaining`,
    /// so 70% falls out of the arithmetic.
    @Test func theSliceShowsInNetWorth() throws {
        let balance = try Self.balance()
        var state = try Self.newGame(.cofounded)
        state.company.cash = 200_000
        state.company.reputation = 50
        let valuation = state.companyValuation(balance: balance)
        #expect(valuation > 0)
        #expect(state.founderNetWorth(balance: balance) == state.life.wallet + Int((Double(valuation) * 0.7).rounded()))
    }

    /// The investor filter (`equityRemaining − equityAsk ≥ 20`) still
    /// offers every persona at 70; it closes one round sooner than at 100.
    @Test func theInvestorFilterStillOffersSensibleRoundsAtSeventy() throws {
        let personas = Self.content.investors
        #expect(!personas.isEmpty)
        for persona in personas {
            #expect(70 - persona.equityAsk >= 20, "\(persona.id) asks \(persona.equityAsk)% and would never be offered")
        }
        // Taking the biggest ask every time: how many rounds before the
        // filter closes.
        let biggest = try #require(personas.map(\.equityAsk).max())
        func rounds(from equity: Double) -> Int {
            var equity = equity, count = 0
            while equity - biggest >= 20 { equity -= biggest; count += 1 }
            return count
        }
        #expect(rounds(from: 100) == 3)
        #expect(rounds(from: 70) == 2)
    }
}
