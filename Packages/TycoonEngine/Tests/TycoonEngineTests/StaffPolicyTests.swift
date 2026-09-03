import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

/// The answer becomes the policy (WS-D): a supportive answer to a
/// policy-shaped staff moment sets a rule that answers the next person
/// who asks — same numbers, a ledger line, no sheet — and the deadline's
/// answer never sets one, which is what keeps the pacing runs where they
/// were.
@Suite("Staff policies")
struct StaffPolicyTests {
    static func balance(interval: Int = 7) -> BalanceConfig {
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

    static func stateWithTeam(
        _ balance: BalanceConfig,
        count: Int = 3,
        morale: Double = 70,
        loyalty: Double = 50
    ) -> GameState {
        var state = GameState.newGame(companyName: "Acme", seed: 5, balance: balance)
        for index in 0..<count {
            var employee = TestPeople.employee(
                id: fixedID(index), name: "Worker \(index)", weeklySalary: 500
            )
            employee.morale = morale
            employee.loyalty = loyalty
            state.employees.append(employee)
        }
        return state
    }

    static func fixedID(_ index: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", index))!
    }

    static func catalog(_ defs: [StaffEventDef]) -> ContentCatalog {
        let tiny = TestContent.tiny()
        return ContentCatalog(
            productTypes: tiny.productTypes, topics: tiny.topics,
            techTree: tiny.techTree, events: tiny.events, names: tiny.names,
            lifeEvents: tiny.lifeEvents, staffEvents: defs
        )
    }

    /// The shipped parental-leave shape: a rule either way.
    static let parentalLeave = StaffEventDef(
        id: "parentalLeave",
        title: "{name} is having a baby",
        body: "There is no policy.",
        headline: "{name} asked what the parental leave policy is.",
        weight: 1,
        supportive: StaffEventDef.Outcome(
            label: "Full pay, three months", cash: -4_000, morale: 16, loyalty: 20, moraleAll: 12
        ),
        strict: StaffEventDef.Outcome(
            label: "The statutory minimum", morale: -12, loyalty: -14, moraleAll: -12
        ),
        policy: StaffEventDef.PolicyFlags(
            name: "Parental leave",
            supportiveFlag: "good_leave_policy",
            strictFlag: "leave_statutory"
        )
    )

    /// Ticks until a staff moment is pending, or `limit` days pass.
    static func tickUntilPending(
        _ state: inout GameState, balance: BalanceConfig, content: ContentCatalog, limit: Int = 60
    ) {
        let start = state.day
        while state.pendingStaffEvent == nil, state.day - start < limit {
            Reducer.tick(&state, balance: balance, content: content)
        }
    }

    // MARK: - The rule answers

    @Test("a supportive answer for A becomes the rule that answers B without a sheet")
    func theAnswerBecomesThePolicy() throws {
        let balance = Self.balance()
        let content = Self.catalog([Self.parentalLeave])
        var state = Self.stateWithTeam(balance)

        Self.tickUntilPending(&state, balance: balance, content: content)
        let first = try #require(state.pendingStaffEvent)
        let cashBefore = state.company.cash
        Reducer.apply(.resolveStaffEvent(choice: .supportive), to: &state, balance: balance, content: content)

        #expect(state.company.cash == cashBefore - 4_000)
        let policy = try #require(state.staffMemory.policy(for: .parentalLeave))
        #expect(policy.flag == "good_leave_policy")
        #expect(policy.choice == .supportive)
        #expect(policy.setBy == first.employeeID)
        #expect(policy.setByName == state.employee(id: first.employeeID)?.name)
        #expect(policy.setDay == state.day)
        #expect(policy.beneficiaries == [first.employeeID])
        #expect(state.narrative.flags.contains("good_leave_policy"))
        #expect(state.eventLog.contains {
            if case .staffPolicySet(let flag, let employeeID, _) = $0 {
                return flag == "good_leave_policy" && employeeID == first.employeeID
            }
            return false
        })

        // The next person who asks is answered by the rule: no pending
        // event, the same −$4,000, a ledger line that says so.
        let cashAfterFirst = state.company.cash
        var applied: (flag: String, employeeID: UUID)?
        let start = state.day
        while applied == nil, state.day - start < 120 {
            let events = Reducer.tick(&state, balance: balance, content: content)
            #expect(state.pendingStaffEvent == nil, "the rule should have answered, not the sheet")
            for event in events {
                if case .staffPolicyApplied(let flag, let employeeID, _) = event,
                   employeeID != first.employeeID {
                    applied = (flag, employeeID)
                }
            }
        }
        let second = try #require(applied)
        #expect(second.flag == "good_leave_policy")
        #expect(state.company.cash <= cashAfterFirst - 4_000)
        let name = try #require(state.employee(id: second.employeeID)?.name)
        #expect(state.ledger.entries.contains {
            $0.label == "Parental leave: \(name) · the policy" && $0.amount == -4_000
        })
        let updated = try #require(state.staffMemory.policy(for: .parentalLeave))
        #expect(updated.beneficiaries.contains(second.employeeID))
        #expect(updated.beneficiaries.first == first.employeeID)
        #expect(state.employee(id: second.employeeID)?.morale ?? 0 > 70, "the same numbers land")
        #expect(state.staffMemory.policies.count == 1, "one rule per kind")
    }

    @Test("the rule's answer replaces the pause: no staff event occurs for that kind again")
    func thePolicyReplacesThePause() throws {
        let balance = Self.balance()
        let content = Self.catalog([Self.parentalLeave])
        var state = Self.stateWithTeam(balance)
        Self.tickUntilPending(&state, balance: balance, content: content)
        Reducer.apply(.resolveStaffEvent(choice: .supportive), to: &state, balance: balance, content: content)

        var occurred = 0
        var applied = 0
        for _ in 0..<200 {
            for event in Reducer.tick(&state, balance: balance, content: content) {
                switch event {
                case .staffEventOccurred: occurred += 1
                case .staffPolicyApplied: applied += 1
                default: break
                }
            }
        }
        #expect(occurred == 0)
        #expect(applied >= 3, "the rule answered \(applied) times in 200 days")
    }

    // MARK: - What never sets a rule

    @Test("the deadline's strict answer sets no rule and is remembered as silence")
    func theDeadlineSetsNoPolicy() throws {
        let balance = Self.balance()
        let content = Self.catalog([Self.parentalLeave])
        var state = Self.stateWithTeam(balance)
        Self.tickUntilPending(&state, balance: balance, content: content)
        let pending = try #require(state.pendingStaffEvent)

        while state.pendingStaffEvent != nil {
            Reducer.tick(&state, balance: balance, content: content)
        }
        #expect(state.staffMemory.policies.isEmpty)
        #expect(state.narrative.flags.isEmpty)
        let refusal = try #require(state.staffMemory.refusal(for: pending.employeeID))
        #expect(refusal.kind == .parentalLeave)
        #expect(refusal.automatic)
        #expect(!state.eventLog.contains {
            if case .staffPolicySet = $0 { return true }
            return false
        })
    }

    @Test("a strict answer from the founder sets no rule either, and is remembered as a no")
    func aPlainNoIsNotARule() throws {
        let balance = Self.balance()
        let content = Self.catalog([Self.parentalLeave])
        var state = Self.stateWithTeam(balance)
        Self.tickUntilPending(&state, balance: balance, content: content)
        let pending = try #require(state.pendingStaffEvent)
        Reducer.apply(.resolveStaffEvent(choice: .strict), to: &state, balance: balance, content: content)

        #expect(state.staffMemory.policies.isEmpty)
        #expect(state.narrative.flags.isEmpty)
        let refusal = try #require(state.staffMemory.refusal(for: pending.employeeID))
        #expect(refusal.day == state.day)
        #expect(!refusal.automatic)

        // The next asker gets the sheet again.
        Self.tickUntilPending(&state, balance: balance, content: content, limit: 120)
        #expect(state.pendingStaffEvent != nil)
    }

    @Test("a kind with no policy block never becomes a rule, however generous the answer")
    func onlyPolicyShapedKindsBecomeRules() throws {
        let balance = Self.balance()
        let content = Self.catalog([
            StaffEventDef(
                id: "familyEmergency", title: "{name} has a family emergency", body: "Body.",
                headline: "{name} needed time off.", weight: 1,
                supportive: StaffEventDef.Outcome(label: "Cover for them", cash: -500, loyalty: 12),
                strict: StaffEventDef.Outcome(label: "Business first", loyalty: -10)
            ),
        ])
        var state = Self.stateWithTeam(balance)
        Self.tickUntilPending(&state, balance: balance, content: content)
        Reducer.apply(.resolveStaffEvent(choice: .supportive), to: &state, balance: balance, content: content)
        #expect(state.staffMemory.policies.isEmpty)
        Self.tickUntilPending(&state, balance: balance, content: content, limit: 120)
        #expect(state.pendingStaffEvent != nil, "a family emergency still asks")
    }

    /// The shipped catalog, answered the way every pacing bot answers —
    /// never. (`BalanceTargetsTests` is the proof on the shipped balance;
    /// this pins the mechanism on a roster that stays put.)
    @Test("a run nobody answers remembers no rule, so a pacing run encodes as it always did")
    func anUnansweredRunSetsNothing() throws {
        let balance = Self.balance(interval: 21)
        let content = TestContent.bundled
        var state = Self.stateWithTeam(balance, count: 4, morale: 80, loyalty: 60)
        var resolved = 0
        for _ in 0..<730 {
            for event in Reducer.tick(&state, balance: balance, content: content) {
                if case .staffEventResolved(_, let choice, _) = event {
                    resolved += 1
                    #expect(choice == .strict, "the deadline only ever picks strict")
                }
            }
        }
        #expect(state.gameOver == nil)
        #expect(state.employees.count == 5, "the roster should have survived two years")
        #expect(resolved > 0, "the two years should have raised something")
        #expect(state.staffMemory.policies.isEmpty)
        #expect(!state.narrative.scheduled.contains { $0.source == .staff })

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let object = try #require(
            try JSONSerialization.jsonObject(with: try encoder.encode(state)) as? [String: Any]
        )
        let memory = object["staffMemory"] as? [String: Any]
        #expect(memory?["policies"] == nil || (memory?["policies"] as? [Any])?.isEmpty == true)
    }

    // MARK: - Saves

    @Test("a fresh state writes no memory key; a rule round-trips")
    func memoryRoundTrips() throws {
        let balance = Self.balance()
        let content = Self.catalog([Self.parentalLeave])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let fresh = Self.stateWithTeam(balance)
        let freshObject = try #require(
            try JSONSerialization.jsonObject(with: try encoder.encode(fresh)) as? [String: Any]
        )
        #expect(freshObject["staffMemory"] == nil)

        var state = fresh
        Self.tickUntilPending(&state, balance: balance, content: content)
        Reducer.apply(.resolveStaffEvent(choice: .supportive), to: &state, balance: balance, content: content)
        let data = try encoder.encode(state)
        let decoded = try JSONDecoder().decode(GameState.self, from: data)
        #expect(decoded == state)
        #expect(decoded.staffMemory.policies.count == 1)

        // And a save from before the key existed reads as nothing remembered.
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "staffMemory")
        let legacy = try JSONDecoder().decode(
            GameState.self, from: try JSONSerialization.data(withJSONObject: object)
        )
        #expect(legacy.staffMemory == .initial)
    }
}
