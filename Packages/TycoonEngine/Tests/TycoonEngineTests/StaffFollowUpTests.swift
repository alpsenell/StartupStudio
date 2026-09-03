import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

/// Second acts (WS-D): an answer schedules another staff def for the same
/// person through `narrative.scheduled`, which fires as their pending
/// staff moment — or lands at once, as a notice with a reason — unless
/// they left, or a rule made since called it off. The deadline's answer
/// never schedules one. Plus the three flag mechanics: `remote_friendly`
/// doubles `teamConflict` and halves bond growth for the people it
/// answered for; `good_leave_policy` takes 5% off every candidate's ask.
@Suite("Staff second acts")
struct StaffFollowUpTests {
    /// The policy-test balance with a real notice period, so a notice is
    /// a sheet and not a walk-out.
    static func balance(noticeDays: Int = 7) -> BalanceConfig {
        var social = BalanceConfig.SocialBalance.standard
        social.staffEventIntervalDays = 7
        social.staffEventChance = 1.0
        social.bondChance = 0
        social.loyaltyAdaptRate = 0
        var economy = TestBalance.neutralEconomy
        economy.resignationNoticeDays = noticeDays
        return TestBalance.make(
            startingCash: 5_000_000,
            weeklyOperatingCost: 0,
            candidateRefreshDays: 10_000,
            contractOfferRefreshDays: 10_000,
            eventChance: 0,
            life: TestBalance.quietLife,
            staff: TestBalance.frozenStaff,
            social: social,
            economy: economy
        )
    }

    static let sideProject = StaffEventDef(
        id: "sideProject",
        title: "{name} has a side project",
        body: "It is good.",
        headline: "{name} has been building something on the side.",
        weight: 1,
        supportive: StaffEventDef.Outcome(
            label: "It's theirs", morale: 16, loyalty: 18,
            followUpEventID: "sideProject_shipped", followUpDelayDays: 120
        ),
        strict: StaffEventDef.Outcome(
            label: "The IP clause", morale: -16, loyalty: -18,
            followUpEventID: "sideProject_notice", followUpDelayDays: 90
        ),
        policy: StaffEventDef.PolicyFlags(
            name: "Side projects", supportiveFlag: "ip_generous", strictFlag: "ip_strict"
        )
    )

    /// The second act that does not ask.
    static let notice = StaffEventDef(
        id: "sideProject_notice",
        title: "{name} is leaving over the side project",
        body: "It got an offer.",
        headline: "{name} handed in notice over the side project.",
        weight: 1,
        requires: StaffEventDef.Gate(flagsNone: ["ip_generous"]),
        supportive: nil,
        strict: StaffEventDef.Outcome(
            label: "They hand in notice", moraleAll: -4,
            noticeReason: "They are leaving to build the side project."
        ),
        kind: "sideProject"
    )

    /// The second act that asks.
    static let shipped = StaffEventDef(
        id: "sideProject_shipped",
        title: "{name}'s side project shipped",
        body: "It is small and it is good.",
        headline: "{name}'s side project shipped.",
        weight: 1,
        supportive: StaffEventDef.Outcome(label: "Newsletter", morale: 6, reputation: 3),
        strict: StaffEventDef.Outcome(label: "Ask for a share", cash: 1_500, loyalty: -12),
        kind: "sideProject"
    )

    static func staffFollowUps(_ state: GameState) -> [ScheduledNarrativeEvent] {
        state.narrative.scheduled.filter { $0.source == .staff }
    }

    // MARK: - Scheduling

    @Test("a strict answer from the founder schedules the second act for that person")
    func aStrictAnswerSchedulesTheSecondAct() throws {
        let balance = Self.balance()
        let content = StaffPolicyTests.catalog([Self.sideProject, Self.notice, Self.shipped])
        var state = StaffPolicyTests.stateWithTeam(balance)
        StaffPolicyTests.tickUntilPending(&state, balance: balance, content: content)
        let pending = try #require(state.pendingStaffEvent)
        Reducer.apply(.resolveStaffEvent(choice: .strict), to: &state, balance: balance, content: content)

        let scheduled = try #require(Self.staffFollowUps(state).first)
        #expect(scheduled.eventID == "sideProject_notice")
        #expect(scheduled.employeeID == pending.employeeID)
        #expect(scheduled.day == state.day + 90)

        // Ninety days on, the same person hands in notice with the reason.
        while state.economy.pendingResignation == nil, state.day <= scheduled.day + 1 {
            Reducer.tick(&state, balance: balance, content: content)
            if state.pendingStaffEvent != nil {
                Reducer.apply(.resolveStaffEvent(choice: .strict), to: &state, balance: balance, content: content)
            }
        }
        let resignation = try #require(state.economy.pendingResignation)
        #expect(resignation.employeeID == pending.employeeID)
        #expect(resignation.reason == "They are leaving to build the side project.")
        #expect(resignation.respondByDay == resignation.sinceDay + 7)
        // (Other people's strict answers in the loop above scheduled acts
        // of their own; this person's has fired.)
        #expect(!Self.staffFollowUps(state).contains {
            $0.employeeID == pending.employeeID && $0.day == scheduled.day
        })
        #expect(state.employee(id: pending.employeeID) != nil, "notice, not a walk-out")
        #expect(state.eventLog.contains {
            if case .resignationNotice(let id, _, _, _) = $0 { return id == pending.employeeID }
            return false
        })
    }

    @Test("the deadline's answer schedules nothing")
    func theDeadlineSchedulesNothing() throws {
        let balance = Self.balance()
        let content = StaffPolicyTests.catalog([Self.sideProject, Self.notice, Self.shipped])
        var state = StaffPolicyTests.stateWithTeam(balance)
        StaffPolicyTests.tickUntilPending(&state, balance: balance, content: content)
        while state.pendingStaffEvent != nil {
            Reducer.tick(&state, balance: balance, content: content)
        }
        #expect(Self.staffFollowUps(state).isEmpty)
        #expect(state.economy.pendingResignation == nil)
    }

    @Test("a second act that asks becomes that person's pending staff moment, with its own words")
    func aSecondActAsks() throws {
        let balance = Self.balance()
        let content = StaffPolicyTests.catalog([Self.sideProject, Self.notice, Self.shipped])
        var state = StaffPolicyTests.stateWithTeam(balance)
        StaffPolicyTests.tickUntilPending(&state, balance: balance, content: content)
        let first = try #require(state.pendingStaffEvent).employeeID
        Reducer.apply(.resolveStaffEvent(choice: .supportive), to: &state, balance: balance, content: content)
        let due = try #require(Self.staffFollowUps(state).first { $0.employeeID == first })
        #expect(due.eventID == "sideProject_shipped")

        // Every rolled moment in between is somebody else's, or the rule's.
        while state.day < due.day {
            Reducer.tick(&state, balance: balance, content: content)
            if let pending = state.pendingStaffEvent, pending.defID == nil {
                Reducer.apply(.resolveStaffEvent(choice: .strict), to: &state, balance: balance, content: content)
            }
        }
        var act: StaffEvent?
        while act == nil, state.day < due.day + 10 {
            if let pending = state.pendingStaffEvent, pending.defID != nil {
                act = pending
                break
            }
            Reducer.tick(&state, balance: balance, content: content)
            if let pending = state.pendingStaffEvent, pending.defID == nil {
                Reducer.apply(.resolveStaffEvent(choice: .strict), to: &state, balance: balance, content: content)
            }
        }
        let pending = try #require(act)
        #expect(pending.defID == "sideProject_shipped")
        #expect(pending.employeeID == first)
        #expect(pending.kind == .sideProject)
        #expect(pending.definitionID == "sideProject_shipped")

        // Its strict answer lands the second act's numbers, not the kind's,
        // sets no rule, and is remembered.
        let cashBefore = state.company.cash
        let loyaltyBefore = try #require(state.employee(id: first)?.loyalty)
        Reducer.apply(.resolveStaffEvent(choice: .strict), to: &state, balance: balance, content: content)
        #expect(state.company.cash == cashBefore + 1_500)
        #expect(state.employee(id: first)?.loyalty == loyaltyBefore - 12)
        #expect(state.staffMemory.policy(for: .sideProject)?.choice == .supportive, "the rule from the first answer stands")
        #expect(state.staffMemory.refusal(for: first)?.kind == .sideProject)
    }

    @Test("a second act is dropped when the person has left")
    func droppedWhenTheyLeft() throws {
        let balance = Self.balance()
        let content = StaffPolicyTests.catalog([Self.sideProject, Self.notice, Self.shipped])
        var state = StaffPolicyTests.stateWithTeam(balance)
        StaffPolicyTests.tickUntilPending(&state, balance: balance, content: content)
        let first = try #require(state.pendingStaffEvent).employeeID
        Reducer.apply(.resolveStaffEvent(choice: .strict), to: &state, balance: balance, content: content)
        let due = try #require(Self.staffFollowUps(state).first)
        Reducer.apply(.fire(employeeID: first), to: &state, balance: balance, content: content)

        while state.day <= due.day + 1 {
            Reducer.tick(&state, balance: balance, content: content)
            if state.pendingStaffEvent != nil {
                Reducer.apply(.resolveStaffEvent(choice: .strict), to: &state, balance: balance, content: content)
            }
        }
        #expect(!Self.staffFollowUps(state).contains { $0.employeeID == first })
        #expect(state.economy.pendingResignation?.employeeID != first)
        #expect(!state.eventLog.contains {
            if case .resignationNotice(let id, _, _, _) = $0 { return id == first }
            return false
        })
    }

    @Test("a rule made in between calls the second act off")
    func aRuleMadeSinceCallsItOff() throws {
        let balance = Self.balance()
        let content = StaffPolicyTests.catalog([Self.sideProject, Self.notice, Self.shipped])
        var state = StaffPolicyTests.stateWithTeam(balance)
        StaffPolicyTests.tickUntilPending(&state, balance: balance, content: content)
        let first = try #require(state.pendingStaffEvent).employeeID
        Reducer.apply(.resolveStaffEvent(choice: .strict), to: &state, balance: balance, content: content)
        let due = try #require(Self.staffFollowUps(state).first)

        // Somebody else asks and gets the generous answer — the rule.
        var second: UUID?
        while second == nil, state.day < due.day - 1 {
            Reducer.tick(&state, balance: balance, content: content)
            if let pending = state.pendingStaffEvent {
                if pending.employeeID != first {
                    second = pending.employeeID
                    Reducer.apply(.resolveStaffEvent(choice: .supportive), to: &state, balance: balance, content: content)
                } else {
                    Reducer.apply(.resolveStaffEvent(choice: .strict), to: &state, balance: balance, content: content)
                }
            }
        }
        #expect(second != nil)
        #expect(state.narrative.flags.contains("ip_generous"))

        while state.day <= due.day + 1 {
            Reducer.tick(&state, balance: balance, content: content)
            if state.pendingStaffEvent != nil {
                Reducer.apply(.resolveStaffEvent(choice: .strict), to: &state, balance: balance, content: content)
            }
        }
        #expect(state.economy.pendingResignation?.employeeID != first, "the generous rule read `flagsNone` false")
        #expect(state.employee(id: first) != nil)
    }

    @Test("the rule's answer schedules the second act for the person it answered for")
    func theRuleSchedulesToo() throws {
        let balance = Self.balance()
        let content = StaffPolicyTests.catalog([Self.sideProject, Self.notice, Self.shipped])
        var state = StaffPolicyTests.stateWithTeam(balance)
        StaffPolicyTests.tickUntilPending(&state, balance: balance, content: content)
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
        #expect(Self.staffFollowUps(state).contains {
            $0.employeeID == beneficiary && $0.eventID == "sideProject_shipped"
        })
    }

    @Test("without a notice period the second act's notice is a walk-out")
    func noNoticePeriodMeansAWalkOut() throws {
        let balance = Self.balance(noticeDays: 0)
        let content = StaffPolicyTests.catalog([Self.sideProject, Self.notice, Self.shipped])
        var state = StaffPolicyTests.stateWithTeam(balance)
        StaffPolicyTests.tickUntilPending(&state, balance: balance, content: content)
        let first = try #require(state.pendingStaffEvent).employeeID
        Reducer.apply(.resolveStaffEvent(choice: .strict), to: &state, balance: balance, content: content)
        let due = try #require(Self.staffFollowUps(state).first)
        while state.day <= due.day + 1 {
            Reducer.tick(&state, balance: balance, content: content)
            if state.pendingStaffEvent != nil {
                Reducer.apply(.resolveStaffEvent(choice: .strict), to: &state, balance: balance, content: content)
            }
        }
        #expect(state.employee(id: first) == nil)
        #expect(state.eventLog.contains {
            if case .employeeQuit(let id, _, _) = $0 { return id == first }
            return false
        })
    }

    // MARK: - The flags with mechanics

    @Test("remote_friendly makes teamConflict twice as likely, with the same one draw")
    func remoteFriendlyDoublesConflict() throws {
        let balance = Self.balance()
        let content = StaffPolicyTests.catalog([
            StaffEventDef(
                id: "teamConflict", title: "{name} and a teammate", body: "Body.",
                headline: "{name} is routing around a teammate.", weight: 1,
                supportive: StaffEventDef.Outcome(label: "Sit them down"),
                strict: StaffEventDef.Outcome(label: "Let them work it out")
            ),
            StaffEventDef(
                id: "burnoutWarning", title: "{name} is running on fumes", body: "Body.",
                headline: "{name} has been shipping at 2am.", weight: 1,
                supportive: StaffEventDef.Outcome(label: "Rest"),
                strict: StaffEventDef.Outcome(label: "Push")
            ),
        ])
        func conflicts(remote: Bool) -> (conflicts: Int, total: Int, rng: SeededRNG) {
            var state = StaffPolicyTests.stateWithTeam(balance)
            if remote { state.narrative.flags.insert(StaffPolicyFlag.remoteFriendly) }
            var conflicts = 0, total = 0
            for _ in 0..<700 {
                Reducer.tick(&state, balance: balance, content: content)
                if let pending = state.pendingStaffEvent {
                    total += 1
                    if pending.kind == .teamConflict { conflicts += 1 }
                    Reducer.apply(.resolveStaffEvent(choice: .strict), to: &state, balance: balance, content: content)
                }
            }
            return (conflicts, total, state.worldRNG)
        }
        let plain = conflicts(remote: false)
        let remote = conflicts(remote: true)
        #expect(plain.total == remote.total, "the flag changes weights, not draws")
        #expect(plain.rng == remote.rng, "the stream walks the same path")
        #expect(Double(plain.conflicts) / Double(plain.total) < 0.62)
        #expect(Double(remote.conflicts) / Double(remote.total) > 0.55)
        #expect(remote.conflicts > plain.conflicts)
    }

    @Test("a bond with someone the remote rule answered for grows at half speed")
    func remoteBondsGrowSlower() throws {
        let balance = Self.balance()
        let content = StaffPolicyTests.catalog([])
        var state = StaffPolicyTests.stateWithTeam(balance)
        let a = StaffPolicyTests.fixedID(0), b = StaffPolicyTests.fixedID(1), c = StaffPolicyTests.fixedID(2)
        for index in state.employees.indices where !state.employees[index].isFounder {
            state.employees[index].assignment = .research
        }
        state.friendships = [
            Friendship(a: a, b: b, strength: 20, sinceDay: 0),
            Friendship(a: b, b: c, strength: 20, sinceDay: 0),
        ]
        state.staffMemory.policies = [StaffPolicy(
            kind: .remoteRequest, flag: StaffPolicyFlag.remoteFriendly, choice: .supportive,
            setDay: 0, setBy: a, setByName: "Worker 0", beneficiaries: [a]
        )]
        state.narrative.flags.insert(StaffPolicyFlag.remoteFriendly)

        for _ in 0..<7 {
            Reducer.tick(&state, balance: balance, content: content)
            if state.pendingStaffEvent != nil {
                Reducer.apply(.resolveStaffEvent(choice: .strict), to: &state, balance: balance, content: content)
            }
        }
        let growth = balance.social.bondGrowthPerWeek
        let ab = try #require(state.friendships.first { $0.involves(a) && $0.involves(b) })
        let bc = try #require(state.friendships.first { $0.involves(b) && $0.involves(c) })
        #expect(ab.strength == 20 + growth * balance.staff.remoteBondGrowthFactor)
        #expect(bc.strength == 20 + growth)
        #expect(balance.staff.remoteBondGrowthFactor == 0.5)
    }

    @Test("good_leave_policy takes five percent off every candidate's ask and nothing else")
    func aLeavePolicyIsCheaperToSayYesTo() throws {
        var balance = Self.balance()
        balance.candidateRefreshDays = 1
        let content = TestContent.bundled
        var plain = GameState.newGame(companyName: "Acme", seed: 9, balance: balance)
        var generous = plain
        generous.narrative.flags.insert(StaffPolicyFlag.goodLeavePolicy)
        Reducer.tick(&plain, balance: balance, content: content)
        Reducer.tick(&generous, balance: balance, content: content)

        #expect(!plain.candidatePool.isEmpty)
        #expect(plain.candidatePool.map(\.id) == generous.candidatePool.map(\.id), "no draw moved")
        #expect(plain.rng == generous.rng)
        for (cheap, full) in zip(generous.candidatePool, plain.candidatePool) {
            let expected = Int((Double(full.weeklySalary) * balance.staff.leavePolicyAskFactor).rounded())
            #expect(abs(cheap.weeklySalary - expected) <= 1, "\(cheap.weeklySalary) vs \(full.weeklySalary)")
            #expect(cheap.weeklySalary < full.weeklySalary)
            #expect(cheap.skills == full.skills)
        }
        #expect(balance.staff.leavePolicyAskFactor == 0.95)
    }

    // MARK: - The shipped content

    @Test("every second act in the shipped catalog resolves, belongs to a kind, and is reachable")
    func shippedSecondActsAreWellFormed() throws {
        let content = TestContent.bundled
        let ids = Set(content.staffEvents.map(\.id))
        var targets: Set<String> = []
        for def in content.staffEvents {
            for outcome in [def.supportive, def.strict].compactMap({ $0 }) {
                guard let target = outcome.followUpEventID else { continue }
                #expect(ids.contains(target), "\(def.id) -> unknown \(target)")
                #expect(outcome.followUpDelayDays > 0, "\(def.id) -> \(target) fires with no delay")
                targets.insert(target)
            }
        }
        let secondActs = content.staffEvents.filter { StaffEventKind(rawValue: $0.id) == nil }
        #expect(secondActs.count >= 8, "\(secondActs.count) second acts")
        for act in secondActs {
            #expect(targets.contains(act.id), "\(act.id) is reachable from nothing")
            let kind = try #require(act.kind, "\(act.id) has no kind")
            #expect(StaffEventKind(rawValue: kind) != nil, "\(act.id) belongs to unknown kind \(kind)")
            #expect(act.policy == nil, "a second act cannot become a rule")
            if act.isImmediate {
                #expect(act.strict.noticeReason != nil, "\(act.id) lands without asking and without a notice")
            }
        }
        // Every policy-shaped kind has two distinct flags, and no two
        // kinds share one.
        var flags: [String] = []
        for def in content.staffEvents {
            guard let policy = def.policy else { continue }
            #expect(policy.supportiveFlag != policy.strictFlag)
            #expect(!policy.name.isEmpty)
            flags += [policy.supportiveFlag, policy.strictFlag]
        }
        #expect(flags.count == 12)
        #expect(Set(flags).count == flags.count)
    }
}
