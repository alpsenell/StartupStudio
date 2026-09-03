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

    // MARK: - Reversal

    @Test("reversing a generous rule costs everyone morale, the beneficiaries loyalty, flips the flag, and the sheet comes back")
    func reversalIsPublic() throws {
        let balance = Self.balance()
        let content = Self.catalog([Self.parentalLeave])
        var state = Self.stateWithTeam(balance)

        Self.tickUntilPending(&state, balance: balance, content: content)
        let first = try #require(state.pendingStaffEvent).employeeID
        Reducer.apply(.resolveStaffEvent(choice: .supportive), to: &state, balance: balance, content: content)
        var second: UUID?
        let start = state.day
        while second == nil, state.day - start < 120 {
            for event in Reducer.tick(&state, balance: balance, content: content) {
                if case .staffPolicyApplied(_, let employeeID, _) = event, employeeID != first {
                    second = employeeID
                }
            }
        }
        let beneficiary = try #require(second)
        let bystander = try #require(
            state.employees.first { !$0.isFounder && $0.id != first && $0.id != beneficiary }
        )
        let before = Dictionary(uniqueKeysWithValues: state.employees.map { ($0.id, ($0.morale, $0.loyalty)) })

        Reducer.apply(.reverseStaffPolicy(flag: "good_leave_policy"), to: &state, balance: balance, content: content)

        let penalty = balance.staff.policyReversalMoralePenalty
        let loyaltyPenalty = balance.staff.policyReversalLoyaltyPenalty
        for employee in state.employees where !employee.isFounder {
            let was = try #require(before[employee.id])
            #expect(employee.morale == max(0, was.0 - penalty), "\(employee.name) heard about it")
            let benefited = employee.id == first || employee.id == beneficiary
            #expect(employee.loyalty == max(0, was.1 - (benefited ? loyaltyPenalty : 0)))
        }
        #expect(state.employee(id: bystander.id)?.loyalty == before[bystander.id]?.1)
        #expect(state.staffMemory.policies.isEmpty)
        #expect(!state.narrative.flags.contains("good_leave_policy"))
        #expect(state.narrative.flags.contains("leave_statutory"))
        #expect(state.eventLog.contains {
            if case .staffPolicyReversed(let flag, _) = $0 { return flag == "good_leave_policy" }
            return false
        })

        // The next person who asks gets the sheet again.
        Self.tickUntilPending(&state, balance: balance, content: content, limit: 120)
        #expect(state.pendingStaffEvent?.kind == .parentalLeave)
    }

    @Test("dropping a strict rule costs nothing and hands nobody a policy")
    func reversingAStrictRuleIsFree() throws {
        let balance = Self.balance()
        let content = Self.catalog([Self.parentalLeave])
        var state = Self.stateWithTeam(balance)
        Self.tickUntilPending(&state, balance: balance, content: content)
        Reducer.apply(.resolveStaffEvent(choice: .strictAsPolicy), to: &state, balance: balance, content: content)
        let moraleBefore = state.employees.map(\.morale)
        let loyaltyBefore = state.employees.map(\.loyalty)

        Reducer.apply(.reverseStaffPolicy(flag: "leave_statutory"), to: &state, balance: balance, content: content)
        #expect(state.employees.map(\.morale) == moraleBefore)
        #expect(state.employees.map(\.loyalty) == loyaltyBefore)
        #expect(state.staffMemory.policies.isEmpty)
        #expect(state.narrative.flags.isEmpty)

        // A flag that is not a rule is ignored.
        let untouched = state
        Reducer.apply(.reverseStaffPolicy(flag: "cofounder_settled"), to: &state, balance: balance, content: content)
        #expect(state == untouched)
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

    @Test("\u{2026}and make that the rule: the strict answer as a rule answers the next asker strictly")
    func theStrictAnswerAsARule() throws {
        let balance = Self.balance()
        let content = Self.catalog([Self.parentalLeave])
        var state = Self.stateWithTeam(balance)
        Self.tickUntilPending(&state, balance: balance, content: content)
        let first = try #require(state.pendingStaffEvent)
        let cashBefore = state.company.cash
        let moraleBefore = try #require(state.employee(id: first.employeeID)?.morale)
        Reducer.apply(
            .resolveStaffEvent(choice: .strictAsPolicy), to: &state, balance: balance, content: content
        )

        // The strict numbers land on the asker, and the rule is strict.
        #expect(state.company.cash == cashBefore, "the firm answer is free")
        #expect(state.employee(id: first.employeeID)?.morale == moraleBefore - 12)
        let policy = try #require(state.staffMemory.policy(for: .parentalLeave))
        #expect(policy.choice == .strict)
        #expect(policy.flag == "leave_statutory")
        #expect(state.narrative.flags.contains("leave_statutory"))
        #expect(!state.narrative.flags.contains("good_leave_policy"))
        #expect(state.staffMemory.refusal(for: first.employeeID)?.automatic == false)

        // The next asker gets the same answer without a sheet, and
        // remembers it as a no.
        var applied: UUID?
        let start = state.day
        while applied == nil, state.day - start < 120 {
            for event in Reducer.tick(&state, balance: balance, content: content) {
                if case .staffPolicyApplied(let flag, let employeeID, _) = event,
                   employeeID != first.employeeID {
                    #expect(flag == "leave_statutory")
                    applied = employeeID
                }
            }
            #expect(state.pendingStaffEvent == nil)
        }
        let second = try #require(applied)
        #expect(
            !state.ledger.entries.contains { $0.label.hasSuffix("· the policy") },
            "nothing on the ledger for a strict rule"
        )
        #expect(state.employee(id: second)?.morale ?? 100 < 70)
        #expect(state.staffMemory.refusal(for: second)?.kind == .parentalLeave)
        #expect(state.staffMemory.policy(for: .parentalLeave)?.beneficiaries.contains(second) == true)
    }

    @Test("the rule button on a kind with no policy block is a plain no")
    func strictAsPolicyWithoutAPolicyBlock() throws {
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
        let pending = try #require(state.pendingStaffEvent)
        let loyaltyBefore = try #require(state.employee(id: pending.employeeID)?.loyalty)
        Reducer.apply(
            .resolveStaffEvent(choice: .strictAsPolicy), to: &state, balance: balance, content: content
        )
        #expect(state.staffMemory.policies.isEmpty)
        #expect(state.employee(id: pending.employeeID)?.loyalty == loyaltyBefore - 10)

        // And with no catalog at all it is the generic strict answer.
        var bare = Self.stateWithTeam(balance)
        Self.tickUntilPending(&bare, balance: balance, content: TestContent.tiny())
        let barePending = try #require(bare.pendingStaffEvent)
        let bareLoyalty = try #require(bare.employee(id: barePending.employeeID)?.loyalty)
        Reducer.apply(
            .resolveStaffEvent(choice: .strictAsPolicy), to: &bare, balance: balance, content: TestContent.tiny()
        )
        #expect(bare.employee(id: barePending.employeeID)?.loyalty
            == bareLoyalty - balance.social.strictLoyaltyPenalty)
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
