import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

/// Staff moments: ten kinds driven by `StaffEvents.json`, gated on tenure,
/// morale, loyalty, traits, friendships and departments, answered through
/// the existing supportive/strict pattern — and still falling back to the
/// generic balance numbers when the catalog has nothing to say.
@Suite("Staff events")
struct StaffEventTests {
    private static func balance(interval: Int = 7) -> BalanceConfig {
        var social = BalanceConfig.SocialBalance.standard
        social.staffEventIntervalDays = interval
        social.staffEventChance = 1.0
        social.bondChance = 0
        social.loyaltyAdaptRate = 0
        return TestBalance.make(
            startingCash: 5_000_000,
            weeklyOperatingCost: 0,
            candidateRefreshDays: 10_000,
            contractOfferRefreshDays: 10_000,
            eventChance: 0,
            life: TestBalance.quietLife,
            staff: TestBalance.frozenStaff,
            social: social
        )
    }

    private static func stateWithTeam(
        _ balance: BalanceConfig,
        hiredDay: Int = 0,
        morale: Double = 70,
        loyalty: Double = 50
    ) -> GameState {
        var state = GameState.newGame(companyName: "Acme", seed: 5, balance: balance)
        for index in 0..<3 {
            // Fixed ids: a test that compares two runs must not seed its
            // own randomness.
            var employee = TestPeople.employee(
                id: Self.fixedID(index), name: "Worker \(index)", weeklySalary: 0
            )
            employee.hiredDay = hiredDay
            employee.morale = morale
            employee.loyalty = loyalty
            state.employees.append(employee)
        }
        return state
    }

    /// A stable UUID per index, so two runs of the same script build the
    /// same roster.
    static func fixedID(_ index: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", index))!
    }

    private static func def(
        _ id: String,
        weight: Int = 1,
        requires: StaffEventDef.Gate? = nil,
        supportive: StaffEventDef.Outcome,
        strict: StaffEventDef.Outcome
    ) -> StaffEventDef {
        StaffEventDef(
            id: id, title: "{name} needs a word", body: "Body.",
            headline: "{name} asked.", weight: weight,
            requires: requires, supportive: supportive, strict: strict
        )
    }

    private static func catalog(_ defs: [StaffEventDef]) -> ContentCatalog {
        let tiny = TestContent.tiny()
        return ContentCatalog(
            productTypes: tiny.productTypes, topics: tiny.topics,
            techTree: tiny.techTree, events: tiny.events, names: tiny.names,
            lifeEvents: tiny.lifeEvents, staffEvents: defs
        )
    }

    private func pendingKind(_ state: GameState) -> StaffEventKind? {
        state.pendingStaffEvent?.kind
    }

    // MARK: - Content-driven kinds

    @Test("the shipped catalog defines a definition for every staff kind")
    func everyKindHasADefinition() throws {
        let content = TestContent.bundled
        #expect(content.staffEvents.count == StaffEventKind.allCases.count)
        for kind in StaffEventKind.allCases {
            let def = try #require(
                content.staffEvent(kind.rawValue), "no definition for \(kind.rawValue)"
            )
            #expect(!def.supportive.label.isEmpty)
            #expect(!def.strict.label.isEmpty)
            #expect(def.title.contains("{name}"))
        }
        #expect(StaffEventKind.allCases.count >= 10)
    }

    @Test("a gated kind is skipped for an employee who doesn't clear it")
    func gatesFilterKinds() {
        let balance = Self.balance()
        let content = Self.catalog([
            Self.def(
                "raiseRequest",
                requires: StaffEventDef.Gate(minTenureDays: 500),
                supportive: StaffEventDef.Outcome(label: "Yes", salaryPercent: 10),
                strict: StaffEventDef.Outcome(label: "No", loyalty: -10)
            ),
            Self.def(
                "burnoutWarning",
                supportive: StaffEventDef.Outcome(label: "Rest", morale: 18),
                strict: StaffEventDef.Outcome(label: "Push", morale: -14)
            ),
        ])
        var state = Self.stateWithTeam(balance, hiredDay: 0)

        var kinds: Set<StaffEventKind> = []
        for _ in 0..<40 {
            Reducer.tick(&state, balance: balance, content: content)
            if let kind = pendingKind(state) {
                kinds.insert(kind)
                Reducer.apply(
                    .resolveStaffEvent(choice: .strict),
                    to: &state, balance: balance, content: content
                )
            }
        }
        #expect(kinds.contains(.burnoutWarning))
        #expect(!kinds.contains(.raiseRequest), "nobody has been here 500 days")
    }

    @Test("trait gates read the employee's traits")
    func traitGate() {
        let balance = Self.balance()
        let content = Self.catalog([
            Self.def(
                "sideProject",
                requires: StaffEventDef.Gate(anyTrait: ["prodigy"]),
                supportive: StaffEventDef.Outcome(label: "Keep it", morale: 16),
                strict: StaffEventDef.Outcome(label: "IP clause", morale: -16)
            ),
        ])
        var state = Self.stateWithTeam(balance)
        var withTrait = state
        for index in withTrait.employees.indices where !withTrait.employees[index].isFounder {
            withTrait.employees[index].traits = ["prodigy"]
        }

        func firstKind(_ start: GameState) -> StaffEventKind? {
            var run = start
            for _ in 0..<80 {
                Reducer.tick(&run, balance: balance, content: content)
                if let kind = run.pendingStaffEvent?.kind { return kind }
            }
            return nil
        }
        #expect(firstKind(withTrait) == .sideProject)
        // Without the trait the def is ineligible, so the pick falls back
        // to the two original kinds.
        let plain = firstKind(state)
        #expect(plain == .familyEmergency || plain == .rivalOfferRumor)
        state = withTrait
    }

    // MARK: - Outcomes

    @Test("a definition's outcome numbers are what land")
    func outcomeApplies() throws {
        let balance = Self.balance()
        let content = Self.catalog([
            Self.def(
                "raiseRequest",
                supportive: StaffEventDef.Outcome(
                    label: "Give the raise", morale: 10, loyalty: 16, salaryPercent: 20
                ),
                strict: StaffEventDef.Outcome(
                    label: "Wait", morale: -10, loyalty: -14, moraleAll: -3
                )
            ),
        ])
        var state = Self.stateWithTeam(balance)
        while state.pendingStaffEvent == nil {
            Reducer.tick(&state, balance: balance, content: content)
        }
        let pending = try #require(state.pendingStaffEvent)
        let index = try #require(state.employees.firstIndex { $0.id == pending.employeeID })
        let salaryBefore = state.employees[index].weeklySalary

        Reducer.apply(
            .resolveStaffEvent(choice: .supportive),
            to: &state, balance: balance, content: content
        )
        #expect(state.employees[index].weeklySalary == Int((Double(salaryBefore) * 1.2).rounded()))
        #expect(state.employees[index].morale >= 80)
        #expect(state.employees[index].loyalty == 66)
        #expect(state.pendingStaffEvent == nil)
    }

    @Test("a strict outcome can dent everyone else's morale and raise a flag")
    func strictOutcomeSpreads() throws {
        let balance = Self.balance()
        let content = Self.catalog([
            Self.def(
                "parentalLeave",
                supportive: StaffEventDef.Outcome(
                    label: "Full pay", cash: -4_000, morale: 16, moraleAll: 12, setFlag: "good_leave"
                ),
                strict: StaffEventDef.Outcome(
                    label: "Statutory", morale: -12, moraleAll: -12, reputation: -3
                )
            ),
        ])
        var state = Self.stateWithTeam(balance)
        while state.pendingStaffEvent == nil {
            Reducer.tick(&state, balance: balance, content: content)
        }
        let pending = try #require(state.pendingStaffEvent)
        let cashBefore = state.company.cash

        Reducer.apply(
            .resolveStaffEvent(choice: .supportive),
            to: &state, balance: balance, content: content
        )
        #expect(state.company.cash == cashBefore - 4_000)
        #expect(state.narrative.flags.contains("good_leave"))
        for employee in state.employees where !employee.isFounder {
            #expect(employee.morale > 70, "everyone hears about the policy")
            _ = pending
        }
    }

    @Test("the deadline still resolves strictly")
    func deadlineResolvesStrict() throws {
        let balance = Self.balance()
        let content = Self.catalog([
            Self.def(
                "promotionDemand",
                supportive: StaffEventDef.Outcome(label: "Promote", salaryPercent: 18),
                strict: StaffEventDef.Outcome(label: "Not this cycle", loyalty: -18)
            ),
        ])
        var state = Self.stateWithTeam(balance)
        while state.pendingStaffEvent == nil {
            Reducer.tick(&state, balance: balance, content: content)
        }
        let pending = try #require(state.pendingStaffEvent)
        let index = try #require(state.employees.firstIndex { $0.id == pending.employeeID })
        let loyaltyBefore = state.employees[index].loyalty

        while state.pendingStaffEvent != nil, state.day <= pending.respondByDay + 2 {
            Reducer.tick(&state, balance: balance, content: content)
        }
        #expect(state.pendingStaffEvent == nil)
        #expect(state.employees[index].loyalty == loyaltyBefore - 18)
    }

    @Test("an empty staff catalog keeps the original two kinds and numbers")
    func emptyCatalogFallsBack() throws {
        let balance = Self.balance()
        let content = TestContent.tiny()
        var state = Self.stateWithTeam(balance)
        while state.pendingStaffEvent == nil {
            Reducer.tick(&state, balance: balance, content: content)
        }
        let pending = try #require(state.pendingStaffEvent)
        #expect(pending.kind == .familyEmergency || pending.kind == .rivalOfferRumor)

        let index = try #require(state.employees.firstIndex { $0.id == pending.employeeID })
        let loyaltyBefore = state.employees[index].loyalty
        Reducer.apply(
            .resolveStaffEvent(choice: .strict),
            to: &state, balance: balance, content: content
        )
        #expect(
            state.employees[index].loyalty
                == loyaltyBefore - balance.social.strictLoyaltyPenalty
        )
    }

    @Test("staff events stay deterministic with content loaded")
    func deterministic() {
        let balance = Self.balance()
        let content = TestContent.bundled
        func run() -> GameState {
            var state = Self.stateWithTeam(balance, hiredDay: 0)
            for day in 0..<200 {
                Reducer.tick(&state, balance: balance, content: content)
                if state.pendingStaffEvent != nil, day % 3 == 0 {
                    Reducer.apply(
                        .resolveStaffEvent(choice: .supportive),
                        to: &state, balance: balance, content: content
                    )
                }
            }
            return state
        }
        #expect(run() == run())
    }

    @Test("a three-year run surfaces several distinct staff kinds")
    func varietyOverThreeYears() {
        let balance = Self.balance()
        let content = TestContent.bundled
        var kinds: Set<StaffEventKind> = []
        for seed in UInt64(1)...4 {
            var state = GameState.newGame(companyName: "Acme", seed: seed, balance: balance)
            for index in 0..<6 {
                var employee = TestPeople.employee(
                    id: Self.fixedID(index), name: "Worker \(index)", weeklySalary: 0
                )
                employee.morale = Double(35 + index * 10)
                employee.loyalty = Double(30 + index * 8)
                state.employees.append(employee)
            }
            for _ in 0..<1_092 {
                Reducer.tick(&state, balance: balance, content: content)
                if state.pendingStaffEvent != nil {
                    kinds.insert(state.pendingStaffEvent!.kind)
                    Reducer.apply(
                        .resolveStaffEvent(choice: .supportive),
                        to: &state, balance: balance, content: content
                    )
                }
            }
        }
        #expect(kinds.count >= 6, "only saw \(kinds.map(\.rawValue).sorted())")
    }
}
