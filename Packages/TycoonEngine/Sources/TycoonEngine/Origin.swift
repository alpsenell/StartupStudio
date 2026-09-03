import Foundation
import TycoonContent

/// How the company was founded — the choice above the difficulty rows on
/// the new-game flow's Stakes page (WS-H, iteration 5).
///
/// Every origin is a set of pure state deltas applied in `GameState.newGame`
/// after the RNG setup, never a multiplier and never a draw, so the same
/// seed with the same origin is the same game and `.garage` is the game
/// that shipped.
public enum FoundingOrigin: String, Codable, Equatable, Sendable, CaseIterable {
    /// Alone, $12,000, a garage. Today's game.
    case garage
    /// A second person in the garage on day 0 who owns 30% of it forever.
    case cofounded
    /// You left a big company with a client: a signed contract, a little
    /// reputation, and a non-compete on one topic for a year.
    case spinOut
    /// You own a flat and the bank has already lent against it.
    case mortgaged

    public var displayName: String {
        switch self {
        case .garage: "Garage"
        case .cofounded: "Co-founded"
        case .spinOut: "Spin-out"
        case .mortgaged: "Mortgaged"
        }
    }

    public var blurb: String {
        switch self {
        case .garage: "Alone, twelve thousand dollars, and a garage."
        case .cofounded: "Somebody builds beside you from day one. They own a third of it."
        case .spinOut: "A client, a deadline, a little reputation, and a topic you can't touch for a year."
        case .mortgaged: "A year of runway, borrowed against the flat you live in."
        }
    }

    public var systemImageName: String {
        switch self {
        case .garage: "house.fill"
        case .cofounded: "person.2.fill"
        case .spinOut: "arrow.turn.up.right"
        case .mortgaged: "building.columns.fill"
        }
    }

    /// The biography's one line about how it started.
    public var biographyLine: String {
        switch self {
        case .garage: "Started alone, in a garage."
        case .cofounded: "Started with a co-founder who owned a third of it."
        case .spinOut: "Started as a spin-out — a client, a deadline, and a topic off limits for a year."
        case .mortgaged: "Started with the bank behind you, and the flat behind the bank."
        }
    }
}

// MARK: - Applying an origin

extension GameState {
    /// The odd multiplier the origin's derived seed uses — a fourth one, so
    /// it never runs in lockstep with the three world streams.
    static let originSeedMultiplier: UInt64 = 0xC2B2_AE3D_27D4_EB4F

    /// The seed everything an origin needs to invent is derived from: the
    /// co-founder's face and id, the client's name, the locked topic. The
    /// same derivation as `worldRNG` (multiply, add a small constant), so
    /// the same game seed always founds the same company — and nothing
    /// here is *drawn* from a stream the rest of the game reads.
    static func originSeed(for seed: UInt64) -> UInt64 {
        seed &* originSeedMultiplier &+ 4
    }

    /// Applies `origin`'s day-0 deltas. Called once, at the end of
    /// `newGame`, after every draw the garage makes.
    ///
    /// The contract this function keeps: `.garage` returns before touching
    /// anything, and no other origin reads or writes `rng`, `worldRNG`,
    /// `investorRNG` or `socialRNG`. Every other field is fair game — that
    /// is what an origin *is* — but it is a different starting state under
    /// the same rules, never a rule of its own.
    mutating func applyOrigin(
        _ origin: FoundingOrigin,
        seed: UInt64,
        founder: FounderProfile,
        balance: BalanceConfig,
        content: ContentCatalog?
    ) {
        let config = balance.origins
        let originSeed = Self.originSeed(for: seed)
        var derived = SeededRNG(seed: originSeed)

        switch origin {
        case .garage:
            return

        case .cofounded:
            // Somebody at the other desk from day one. Their look — and so
            // their traits, which the initializer derives from it — is the
            // derived seed itself; their id and name come from a stream
            // seeded by it. Nothing the garage draws moves.
            let id = UUID(from: &derived)
            let name = Self.pickName(from: content?.names, &derived)
            let skills = config.cofounderSkills
            let cofounder = Employee(
                id: id,
                name: name,
                skills: skills,
                weeklySalary: 0,
                assignment: .idle,
                isFounder: false,
                hiredDay: 0,
                appearanceSeed: originSeed,
                level: .forSkillTotal(skills.total),
                loyalty: config.cofounderLoyalty,
                role: Self.cofounderRole(for: founder.archetype),
                founderBond: config.cofounderBond,
                isCofounder: true
            )
            employees.append(cofounder)
            // The 30% is not a round: no `RaisedRound`, no board, no ask.
            // It is simply not the founder's any more, and every valuation,
            // exit and net-worth line reads `equityRemaining`.
            investors.equityRemaining = max(0, min(100, 100 - config.cofounderEquity))

        case .spinOut:
            // The client you left with. Built directly — the weekly sheet's
            // per-offer draw groups are untouched — as the same `ContractJob`
            // `acceptContract` would have produced, so `ContractSystem`
            // settles it like any other: paid on delivery, penalised past
            // the deadline, graded against `requiredSkill`.
            let id = UUID(from: &derived)
            let clientName = Self.pick(content?.names.clientCompanies ?? [], &derived)
                ?? "Your old employer"
            let points = config.spinOutContractPoints
            let split = min(1, max(0, config.spinOutContractCodeSplit))
            let payout = config.spinOutContractPayout
            activeContracts.append(ContractJob(
                id: id,
                clientName: clientName,
                requiredCodePts: points * split,
                requiredDesignPts: points * (1 - split),
                progressCode: 0,
                progressDesign: 0,
                deadlineDay: day + config.spinOutContractDeadlineDays,
                payout: payout,
                penalty: Int((balance.contractPenaltyFraction * Double(payout)).rounded()),
                acceptedDay: day,
                requiredSkill: config.spinOutContractRequiredSkill
            ))
            company.reputation = min(100, max(0, config.spinOutReputation))
            // The non-compete: one topic, a year. Picked from the catalog
            // so it is always a topic the flow can grey out.
            if let topic = Self.pick(content?.topics.map(\.id) ?? [], &derived) {
                lockedTopics[topic] = day + config.spinOutLockDays
            }

        case .mortgaged:
            // The state `takeSecuredLoan` leaves behind when the whole
            // amount is against the house: the loan on the books, the
            // guarantee flagged for all of it, the drawdown in the ledger
            // and in the account. Built directly because the bank's
            // day-0 ceiling would never lend a garage this much — that is
            // the point of already owning the flat.
            life.home = config.mortgagedHomeTier
            loanBalance += config.mortgagedLoan
            economy.guaranteedLoanAmount += config.mortgagedLoan
            company.cash += config.mortgagedLoan
            ledger.post(LedgerEntry(
                day: day, amount: config.mortgagedLoan, category: .other, label: "Loan drawdown"
            ))
        }
    }

    /// The co-founder's role, from a fixed table keyed by what the founder
    /// is not: the pair covers each other.
    static func cofounderRole(for archetype: FounderArchetype) -> EmployeeRole {
        switch archetype {
        case .hacker: .designer
        case .designer: .backend
        case .hustler: .frontend
        }
    }

    private static func pick(_ pool: [String], _ rng: inout SeededRNG) -> String? {
        guard !pool.isEmpty else { return nil }
        return pool[Int(rng.next() % UInt64(pool.count))]
    }

    private static func pickName(from names: NamePools?, _ rng: inout SeededRNG) -> String {
        guard let names,
              let first = pick(names.firstNames, &rng),
              let last = pick(names.lastNames, &rng)
        else { return "Your co-founder" }
        return "\(first) \(last)"
    }
}

// MARK: - Queries

extension GameState {
    /// The person who signed the papers beside the founder, if the company
    /// was co-founded and they are still here.
    public var cofounder: Employee? {
        employees.first { $0.isCofounder }
    }

    /// The first day a product may be started in `topicID`, or `nil` when
    /// the topic is open now. A lock that has passed reads as open; the
    /// entry stays so the biography can say there was one.
    public func topicUnlockDay(_ topicID: String) -> Int? {
        guard let unlockDay = lockedTopics[topicID], day < unlockDay else { return nil }
        return unlockDay
    }

    /// Whether a non-compete refuses products in `topicID` today.
    public func isTopicLocked(_ topicID: String) -> Bool {
        topicUnlockDay(topicID) != nil
    }

    /// Whether this person works for equity rather than pay: a co-founder
    /// in an office below `origins.cofounderPaidFromTier`. While it is
    /// true, a $0 salary is not "underpaid" — it is the deal.
    public func cofounderWorksForEquity(_ employee: Employee, balance: BalanceConfig) -> Bool {
        employee.isCofounder && company.officeTier.rank < balance.origins.cofounderPaidFrom.rank
    }
}

// MARK: - The day the office can pay them

enum OriginRules {
    /// A co-founder still on $0 starts drawing fair pay the day the office
    /// reaches the tier they were promised. Called from the office upgrade;
    /// an office that never gets there never pays them, and the underpaid
    /// rule never applies (`cofounderWorksForEquity`).
    static func cofoundersStartDrawingPay(
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) -> [GameEvent] {
        guard state.company.officeTier.rank >= balance.origins.cofounderPaidFrom.rank else { return [] }
        var events: [GameEvent] = []
        for index in state.employees.indices
        where state.employees[index].isCofounder && state.employees[index].weeklySalary == 0 {
            let pay = max(1, Int(balance.fairWeeklyPay(for: state.employees[index]).rounded()))
            state.employees[index].weeklySalary = pay
            events.append(.salaryChanged(
                employeeID: state.employees[index].id, weeklySalary: pay, day: state.day
            ))
        }
        return events
    }
}
