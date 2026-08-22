import Foundation

/// The player's company.
public struct Company: Codable, Equatable, Sendable {
    public var name: String
    public var cash: Int
    /// 0–100, starts at 10.
    public var reputation: Double
    public var officeTier: OfficeTier
    /// Consecutive days spent with negative cash. Resets to 0 on recovery.
    public var daysInDebt: Int
}

/// A single financial posting. Negative amounts are expenses.
public struct LedgerEntry: Codable, Equatable, Sendable {
    public enum Category: String, Codable, Equatable, Sendable, CaseIterable {
        case operating, rent, payroll, sales, contracts, marketing, research, other
    }

    public var day: Int
    public var amount: Int
    public var category: Category
    public var label: String

    public init(day: Int, amount: Int, category: Category, label: String) {
        self.day = day
        self.amount = amount
        self.category = category
        self.label = label
    }
}

/// Rolling financial ledger, capped to the most recent 500 entries.
public struct FinancialLedger: Codable, Equatable, Sendable {
    /// The maximum number of entries retained.
    static let maxEntries = 500

    public var entries: [LedgerEntry]

    /// Appends an entry, dropping the oldest entries beyond the cap.
    mutating func post(_ entry: LedgerEntry) {
        entries.append(entry)
        if entries.count > Self.maxEntries {
            entries.removeFirst(entries.count - Self.maxEntries)
        }
    }
}

/// Terminal state details once the run has ended.
public struct GameOverInfo: Codable, Equatable, Sendable {
    public var day: Int
    public var reason: String
}

/// Notable simulation events surfaced to the UI.
public enum GameEvent: Codable, Equatable, Sendable {
    case bankruptcyWarning(day: Int)
    case gameOver(day: Int)
    case productStarted(productID: UUID, day: Int)
    case shipped(productID: UUID, day: Int)
    case reviewsIn(productID: UUID, averageScore: Int, day: Int)
    case productOffMarket(productID: UUID, day: Int)
    case hired(employeeID: UUID, day: Int)
    case fired(employeeID: UUID, day: Int)
    case candidatesRefreshed(day: Int)
    case researchStarted(nodeID: String, day: Int)
    case researchCompleted(nodeID: String, day: Int)
    case contractOffersRefreshed(day: Int)
    case contractAccepted(contractID: UUID, day: Int)
    case contractCompleted(contractID: UUID, payout: Int, day: Int)
    case contractFailed(contractID: UUID, penalty: Int, day: Int)
    case campaignStarted(campaignID: UUID, day: Int)
    case officeUpgraded(tier: OfficeTier, day: Int)
    case randomEvent(eventID: String, day: Int)
    case lifeEvent(eventID: String, day: Int)
    case founderAway(reason: String, untilDay: Int, day: Int)
    case founderBack(day: Int)
    case relationshipChanged(stage: RelationshipStage, day: Int)
    case breakup(day: Int)
    case childBorn(name: String, day: Int)
    case homeUpgraded(tier: HomeTier, day: Int)
    case weekendSpent(activity: WeekendActivity, day: Int)
}

/// The complete, serializable simulation state. A pure value: the reducer is
/// the only thing that advances it, one game day per tick.
public struct GameState: Codable, Equatable, Sendable {
    /// Days per game year (52 weeks of 7 days).
    static let daysPerYear = 364
    /// Days per game week.
    static let daysPerWeek = 7
    /// The maximum number of `eventLog` entries retained (mirrors
    /// `FinancialLedger.maxEntries`).
    static let maxEventLogEntries = 500

    public var schemaVersion: Int
    public var rng: SeededRNG
    /// Ticks since founding; starts at 0.
    public var day: Int
    public var speed: SimSpeed
    public var company: Company
    public var ledger: FinancialLedger
    public var products: [Product]
    public var employees: [Employee]
    public var candidatePool: [Candidate]
    public var research: ResearchState
    public var contractOffers: [ContractOffer]
    public var activeContracts: [ContractJob]
    public var campaigns: [MarketingCampaign]
    public var eventLog: [GameEvent]
    /// Reached office-tier raw values, e.g. "loft". Recorded by
    /// `upgradeOffice` and never removed.
    public var milestonesReached: Set<String>
    /// The founder's personal life, advanced by `LifeSystem`.
    public var life: LifeState
    public var gameOver: GameOverInfo?

    public static func newGame(companyName: String, seed: UInt64, balance: BalanceConfig) -> GameState {
        var rng = SeededRNG(seed: seed)
        let founder = Employee(
            id: UUID(from: &rng),
            name: "Founder",
            skills: SkillSet(
                coding: balance.founderCoding,
                design: balance.founderDesign,
                marketing: balance.founderMarketing
            ),
            weeklySalary: 0,
            assignment: .idle,
            isFounder: true,
            hiredDay: 0,
            appearanceSeed: rng.next()
        )
        return GameState(
            schemaVersion: 1,
            rng: rng,
            day: 0,
            speed: .paused,
            company: Company(
                name: companyName,
                cash: balance.startingCash,
                reputation: 10,
                officeTier: .garage,
                daysInDebt: 0
            ),
            ledger: FinancialLedger(entries: []),
            products: [],
            employees: [founder],
            candidatePool: [],
            research: .initial,
            contractOffers: [],
            activeContracts: [],
            campaigns: [],
            eventLog: [],
            milestonesReached: [],
            life: LifeState.newGame(balance: balance),
            gameOver: nil
        )
    }

    /// The single product currently in development, if any.
    public var productInDevelopment: Product? {
        products.first { product in
            if case .development = product.stage { return true }
            return false
        }
    }

    /// Looks up a product by id.
    public func product(id: UUID) -> Product? {
        products.first { $0.id == id }
    }

    /// Everyone on payroll, founder included.
    public var headcount: Int { employees.count }

    /// Looks up an employee by id.
    public func employee(id: UUID) -> Employee? {
        employees.first { $0.id == id }
    }

    /// Looks up an accepted, still-running contract by id.
    public func activeContract(id: UUID) -> ContractJob? {
        activeContracts.first { $0.id == id }
    }

    /// Appends events to the rolling event log, dropping the oldest entries
    /// beyond the cap. The reducer is the only caller.
    mutating func logEvents(_ events: [GameEvent]) {
        eventLog.append(contentsOf: events)
        if eventLog.count > Self.maxEventLogEntries {
            eventLog.removeFirst(eventLog.count - Self.maxEventLogEntries)
        }
    }

    /// 1-based game year.
    public var year: Int { day / Self.daysPerYear + 1 }

    /// 1-based week within the current year (1...52).
    public var weekOfYear: Int { (day % Self.daysPerYear) / Self.daysPerWeek + 1 }

    /// 1-based day within the current week (1...7).
    public var dayOfWeek: Int { day % Self.daysPerWeek + 1 }

    /// Compact date label, e.g. "W3 · Y1".
    public var dateLabel: String { "W\(weekOfYear) · Y\(year)" }
}

// MARK: - Codable

// Hand-written (in an extension, preserving the memberwise initializer) so
// `milestonesReached` encodes in sorted order: `Set` iteration order is not
// stable across processes, and saves (like the determinism tests) rely on
// byte-identical JSON for identical states. The `milestonesReached` and
// `life` keys also decode as optional so saves written before the fields
// existed keep loading (a missing life starts fresh with an empty wallet).

extension GameState {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion, rng, day, speed, company, ledger, products, employees
        case candidatePool, research, contractOffers, activeContracts, campaigns
        case eventLog, milestonesReached, life, gameOver
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            schemaVersion: try container.decode(Int.self, forKey: .schemaVersion),
            rng: try container.decode(SeededRNG.self, forKey: .rng),
            day: try container.decode(Int.self, forKey: .day),
            speed: try container.decode(SimSpeed.self, forKey: .speed),
            company: try container.decode(Company.self, forKey: .company),
            ledger: try container.decode(FinancialLedger.self, forKey: .ledger),
            products: try container.decode([Product].self, forKey: .products),
            employees: try container.decode([Employee].self, forKey: .employees),
            candidatePool: try container.decode([Candidate].self, forKey: .candidatePool),
            research: try container.decode(ResearchState.self, forKey: .research),
            contractOffers: try container.decode([ContractOffer].self, forKey: .contractOffers),
            activeContracts: try container.decode([ContractJob].self, forKey: .activeContracts),
            campaigns: try container.decode([MarketingCampaign].self, forKey: .campaigns),
            eventLog: try container.decode([GameEvent].self, forKey: .eventLog),
            milestonesReached: Set(
                try container.decodeIfPresent([String].self, forKey: .milestonesReached) ?? []
            ),
            life: try container.decodeIfPresent(LifeState.self, forKey: .life)
                ?? LifeState.newGame(wallet: 0, founderSalary: 0),
            gameOver: try container.decodeIfPresent(GameOverInfo.self, forKey: .gameOver)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(rng, forKey: .rng)
        try container.encode(day, forKey: .day)
        try container.encode(speed, forKey: .speed)
        try container.encode(company, forKey: .company)
        try container.encode(ledger, forKey: .ledger)
        try container.encode(products, forKey: .products)
        try container.encode(employees, forKey: .employees)
        try container.encode(candidatePool, forKey: .candidatePool)
        try container.encode(research, forKey: .research)
        try container.encode(contractOffers, forKey: .contractOffers)
        try container.encode(activeContracts, forKey: .activeContracts)
        try container.encode(campaigns, forKey: .campaigns)
        try container.encode(eventLog, forKey: .eventLog)
        try container.encode(milestonesReached.sorted(), forKey: .milestonesReached)
        try container.encode(life, forKey: .life)
        try container.encodeIfPresent(gameOver, forKey: .gameOver)
    }
}
