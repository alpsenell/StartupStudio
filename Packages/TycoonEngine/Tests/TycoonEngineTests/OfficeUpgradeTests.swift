import Foundation
import Testing
import TycoonContent
import TycoonEngine

@Suite("Office upgrades")
struct OfficeUpgradeTests {
    /// No test in this suite needs products or events, so the tiny catalog is inert.
    private let content = TestContent.tiny()

    @Test func nextClimbsGarageToCampusThenStops() {
        #expect(OfficeTier.garage.next == .loft)
        #expect(OfficeTier.loft.next == .studio)
        #expect(OfficeTier.studio.next == .campus)
        #expect(OfficeTier.campus.next == nil)
    }

    @Test func newGameStartsWithNoMilestones() {
        let state = GameState.newGame(companyName: "Acme", seed: 1, balance: TestBalance.standard)
        #expect(state.milestonesReached.isEmpty)
    }

    @Test func upgradeIsIgnoredWhenUnaffordable() {
        let balance = TestBalance.standard
        var state = GameState.newGame(companyName: "Acme", seed: 2, balance: balance)
        state.company.cash = balance.office(.loft).upgradeCost - 1

        let before = state
        let events = Reducer.apply(.upgradeOffice, to: &state, balance: balance, content: content)

        #expect(events.isEmpty)
        #expect(state == before)
    }

    @Test func upgradeIsIgnoredAtCampusBecauseThereIsNoNextTier() {
        let balance = TestBalance.standard
        var state = GameState.newGame(companyName: "Acme", seed: 3, balance: balance)
        state.company.officeTier = .campus
        state.company.cash = 100_000_000

        let before = state
        let events = Reducer.apply(.upgradeOffice, to: &state, balance: balance, content: content)

        #expect(events.isEmpty)
        #expect(state == before)
    }

    @Test func upgradeDeductsCostPostsLedgerSetsTierRecordsMilestoneAndEmits() throws {
        let balance = TestBalance.standard
        var state = GameState.newGame(companyName: "Acme", seed: 4, balance: balance)
        let loftCost = balance.office(.loft).upgradeCost
        state.company.cash = loftCost + 123
        state.day = 42

        let events = Reducer.apply(.upgradeOffice, to: &state, balance: balance, content: content)

        #expect(events == [.officeUpgraded(tier: .loft, day: 42)])
        #expect(state.eventLog == [.officeUpgraded(tier: .loft, day: 42)])
        #expect(state.company.officeTier == .loft)
        #expect(state.company.cash == 123)
        #expect(state.milestonesReached == ["loft"])

        let entry = try #require(state.ledger.entries.last)
        #expect(entry.day == 42)
        #expect(entry.amount == -loftCost)
        #expect(entry.category == .other)
        #expect(entry.label == "Office upgrade: Loft")
    }

    @Test func upgradesChainThroughEveryTierAndAccumulateMilestones() {
        let balance = TestBalance.standard
        var state = GameState.newGame(companyName: "Acme", seed: 5, balance: balance)
        state.company.cash = balance.office(.loft).upgradeCost
            + balance.office(.studio).upgradeCost
            + balance.office(.campus).upgradeCost

        for expected in [OfficeTier.loft, .studio, .campus] {
            let events = Reducer.apply(.upgradeOffice, to: &state, balance: balance, content: content)
            #expect(events == [.officeUpgraded(tier: expected, day: 0)])
            #expect(state.company.officeTier == expected)
        }

        #expect(state.company.cash == 0)
        #expect(state.milestonesReached == ["loft", "studio", "campus"])

        // At the top of the ladder further upgrades are ignored.
        let before = state
        #expect(Reducer.apply(.upgradeOffice, to: &state, balance: balance, content: content).isEmpty)
        #expect(state == before)
    }

    @Test func upgradeRaisesTheHeadcountCapSoABlockedHireSucceeds() throws {
        let balance = TestBalance.standard
        var state = GameState.newGame(companyName: "Acme", seed: 6, balance: balance)
        // Fill the garage to its cap of 3 (founder + 2).
        state.employees.append(TestPeople.employee(name: "Second"))
        state.employees.append(TestPeople.employee(name: "Third"))
        let candidate = TestPeople.candidate()
        state.candidatePool = [candidate]
        state.company.cash = balance.office(.loft).upgradeCost + 1_000

        // Blocked at the garage cap.
        #expect(Reducer.apply(
            .hire(candidateID: candidate.id), to: &state, balance: balance, content: content
        ).isEmpty)
        #expect(state.headcount == 3)

        // The loft cap of 6 lets the same hire through.
        Reducer.apply(.upgradeOffice, to: &state, balance: balance, content: content)
        let events = Reducer.apply(
            .hire(candidateID: candidate.id), to: &state, balance: balance, content: content
        )
        #expect(events == [.hired(employeeID: candidate.id, day: 0)])
        #expect(state.headcount == 4)
    }

    @Test func milestonesEncodeSortedAndMissingKeyDecodesAsEmpty() throws {
        let balance = TestBalance.standard
        var state = GameState.newGame(companyName: "Acme", seed: 7, balance: balance)
        state.milestonesReached = ["studio", "loft", "campus"]

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let json = try #require(String(data: try encoder.encode(state), encoding: .utf8))
        // Set iteration order is not stable across processes, so the encoder
        // must write the milestones as a sorted array (like ResearchState).
        #expect(json.contains(#""milestonesReached":["campus","loft","studio"]"#))

        // Saves written before this field existed decode to an empty set.
        var object = try #require(
            try JSONSerialization.jsonObject(with: encoder.encode(state)) as? [String: Any]
        )
        object.removeValue(forKey: "milestonesReached")
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(GameState.self, from: legacyData)
        #expect(decoded.milestonesReached.isEmpty)
        #expect(decoded.company == state.company)
    }
}
