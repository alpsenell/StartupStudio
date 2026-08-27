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

/// How a run ended.
public enum EndingKind: String, Codable, Equatable, Sendable {
    case bankruptcy
    /// The founder sold the company to a rival — a successful exit.
    case acquired
}

/// Terminal state details once the run has ended.
public struct GameOverInfo: Codable, Equatable, Sendable {
    public var day: Int
    public var reason: String
    /// Saves written before endings existed decode as `.bankruptcy`.
    public var kind: EndingKind

    init(day: Int, reason: String, kind: EndingKind = .bankruptcy) {
        self.day = day
        self.reason = reason
        self.kind = kind
    }
}

extension GameOverInfo {
    private enum CodingKeys: String, CodingKey {
        case day, reason, kind
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            day: try container.decode(Int.self, forKey: .day),
            reason: try container.decode(String.self, forKey: .reason),
            kind: try container.decodeIfPresent(EndingKind.self, forKey: .kind) ?? .bankruptcy
        )
    }
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
    case marketBoom(topicID: String, day: Int)
    case marketCrash(topicID: String, day: Int)
    case employeeQuit(employeeID: UUID, name: String, day: Int)
    case employeePromoted(employeeID: UUID, level: SeniorityLevel, day: Int)
    case employeeDemoted(employeeID: UUID, level: SeniorityLevel, day: Int)
    case salaryChanged(employeeID: UUID, weeklySalary: Int, day: Int)
    case employeeTrained(employeeID: UUID, day: Int)
    /// Replaces `.contractCompleted` for deliveries graded on quality
    /// (0...100). The payout is the amount actually paid after any
    /// quality docking.
    case contractDelivered(contractID: UUID, quality: Int, payout: Int, day: Int)
    case loanTaken(amount: Int, day: Int)
    case loanRepaid(amount: Int, day: Int)
    case amenityBuilt(amenity: Amenity, day: Int)
    /// A department's first staffer arrived / its last one left (detected
    /// on the daily tick).
    case departmentFormed(department: Department, day: Int)
    case departmentDissolved(department: Department, day: Int)
    case rivalFounded(rivalID: UUID, name: String, day: Int)
    case rivalShipped(rivalID: UUID, topicID: String, day: Int)
    case rivalFolded(rivalID: UUID, name: String, day: Int)
    /// A rival made one of the player's employees an offer; the player can
    /// match it or let them go until `respondByDay`.
    case poachAttempt(rivalID: UUID, employeeID: UUID, offeredWeeklySalary: Int, respondByDay: Int, day: Int)
    /// The player matched a poach offer and the employee stayed.
    case poachDefeated(employeeID: UUID, day: Int)
    /// An employee left for a rival (declined counter, or auto-resolved).
    case employeePoached(employeeID: UUID, name: String, rivalID: UUID, day: Int)
    /// A rival offered to buy the company; open until `respondByDay`.
    case buyoutOffered(rivalID: UUID, amount: Int, respondByDay: Int, day: Int)
    case buyoutWithdrawn(rivalID: UUID, day: Int)
    /// The player accepted a buyout — the run ends as a successful exit.
    case companySold(rivalID: UUID, amount: Int, day: Int)
    /// The player acquired a rival studio.
    case rivalAcquired(rivalID: UUID, name: String, hiresAbsorbed: Int, day: Int)
    /// The office moved to a new district (pauses so the player sees the
    /// new terms).
    case officeRelocated(district: DistrictID, day: Int)
    case officeBought(district: DistrictID, price: Int, day: Int)
    case officeSold(district: DistrictID, price: Int, day: Int)
    case instantActivityDone(activity: InstantActivity, day: Int)
    case itemPurchased(itemID: String, day: Int)
    /// A one-on-one social action (or the team dinner, employeeID nil).
    case socialActivity(kind: SocialActivityKind, employeeID: UUID?, day: Int)
    /// Two employees became friends.
    case friendshipFormed(a: UUID, b: UUID, day: Int)
    /// A surviving friend took the departure hard.
    case friendLostMorale(employeeID: UUID, day: Int)
    case staffBirthday(employeeID: UUID, day: Int)
    /// A staff moment needs an answer by `respondByDay` (pauses).
    case staffEventOccurred(employeeID: UUID, kind: StaffEventKind, respondByDay: Int, day: Int)
    case staffEventResolved(employeeID: UUID, choice: StaffEventChoice, day: Int)

    // Reserved regions — each workstream appends its new cases inside its
    // own region and nowhere else, so six branches never touch the same
    // line. Keep the regions in this order; never reorder existing cases
    // (the case order is not persisted, but a stable diff is the point).

    // MARK: WS-A

    // MARK: WS-B

    // MARK: WS-F
}

extension GameEvent {
    /// Whether this event is notable enough to auto-pause the timeline so
    /// the player can react. Checked by the engine after every tick.
    public var pausesTimeline: Bool {
        switch self {
        case .bankruptcyWarning, .gameOver, .reviewsIn, .contractFailed,
             .contractDelivered, .randomEvent, .lifeEvent, .founderAway,
             .breakup, .childBorn, .marketBoom, .marketCrash, .employeeQuit,
             .poachAttempt, .buyoutOffered, .companySold, .rivalAcquired,
             .employeePoached, .officeRelocated, .staffEventOccurred:
            true

        // Reserved regions — each workstream adds its pausing cases inside
        // its own region, above the `default`, which stays `false`.

        // MARK: WS-A

        // MARK: WS-B

        // MARK: WS-F

        default:
            false
        }
    }

    /// How loudly an event should interrupt the player. WS-A grades every
    /// case (and derives `pausesTimeline` from it); until then everything
    /// reads `.info`, which changes nothing — `pausesTimeline` is still the
    /// switch above.
    public var severity: EventSeverity {
        switch self {

        // MARK: WS-A

        // MARK: WS-B

        // MARK: WS-F

        default:
            .info
        }
    }
}

/// How loudly an event interrupts the player, from background noise to a
/// full stop. WS-A's pause policy grades every `GameEvent` with one of
/// these and budgets non-critical pauses; WS-E picks banner and haptic
/// strength from it.
public enum EventSeverity: String, Codable, Equatable, Sendable, CaseIterable {
    case quiet, info, notable, critical
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
    /// Chosen once at `newGame`; the engine rescales the balance with it.
    /// Saves written before difficulty existed decode as `.normal`.
    public var difficulty: Difficulty
    public var rng: SeededRNG
    /// A second RNG stream feeding the "world" systems added after launch
    /// (rivals, city, social). Kept separate so those systems' draws never
    /// shift the long-established `rng` stream that the original systems
    /// (and their determinism tests) document word by word.
    public var worldRNG: SeededRNG
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
    /// Per-topic market conditions, advanced by `MarketSystem`.
    public var market: MarketState
    /// Competitor studios and their standing offers, advanced by
    /// `RivalSystem`.
    public var rivals: RivalsState
    /// Office district and rent-vs-own terms, advanced by `CitySystem`.
    public var city: CityState
    /// Bonds between employees, advanced by `SocialSystem` (canonical pair
    /// order, kept sorted by (a, b) for deterministic encoding).
    public var friendships: [Friendship]
    /// A staff moment awaiting the founder's answer.
    public var pendingStaffEvent: StaffEvent?
    /// The last day the whole team went to dinner (global cooldown).
    public var lastTeamDinnerDay: Int?
    /// Outstanding company loan principal. Interest posts weekly.
    public var loanBalance: Int
    /// Office amenities bought so far; kept across office upgrades.
    public var amenities: Set<Amenity>
    /// The departments seen active on the last daily tick, so the tick can
    /// emit formed/dissolved events on transitions. `activeDepartments` is
    /// the live truth.
    public var knownDepartments: Set<Department>
    /// Economy, live-ops and pacing state (WS-A). Empty in the scaffold.
    public var economy: EconomyState
    /// Narrative engine state — pending choice, flags, cooldowns (WS-B).
    /// Empty in the scaffold.
    public var narrative: NarrativeState
    /// Chapters, goals and perks (WS-F). Empty in the scaffold.
    public var progression: ProgressionState
    /// Rounds raised, equity and board pressure (WS-F). Empty in the
    /// scaffold.
    public var investors: InvestorState
    public var gameOver: GameOverInfo?

    /// Starts a fresh company. `balance` is used as given — pass the
    /// difficulty-adjusted balance (`GameEngine.newGame` does); `difficulty`
    /// is only recorded so a resume can re-derive that adjustment.
    public static func newGame(
        companyName: String,
        seed: UInt64,
        balance: BalanceConfig,
        difficulty: Difficulty = .normal,
        founder: FounderProfile = .default
    ) -> GameState {
        var rng = SeededRNG(seed: seed)
        // The id and the appearance word are drawn in this order, always —
        // a profile that pins the appearance still burns the draw, so the
        // stream walks the same path whatever the new-game flow chose.
        let founderID = UUID(from: &rng)
        let drawnAppearanceSeed = rng.next()
        let founderEmployee = Employee(
            id: founderID,
            name: founder.name,
            // WS-F gives each archetype its own spread here; every
            // archetype starts from the balance's founder skills today.
            skills: SkillSet(
                coding: balance.founderCoding,
                design: balance.founderDesign,
                marketing: balance.founderMarketing
            ),
            weeklySalary: 0,
            assignment: .idle,
            isFounder: true,
            hiredDay: 0,
            appearanceSeed: founder.appearanceSeed ?? drawnAppearanceSeed,
            role: .founder
        )
        return GameState(
            schemaVersion: 1,
            difficulty: difficulty,
            rng: rng,
            // Derived from the seed (not drawn from `rng`) so the original
            // stream's draw count at newGame is unchanged.
            worldRNG: SeededRNG(seed: seed &* 0x9E37_79B9_7F4A_7C15 &+ 1),
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
            employees: [founderEmployee],
            candidatePool: [],
            research: .initial,
            contractOffers: [],
            activeContracts: [],
            campaigns: [],
            eventLog: [],
            milestonesReached: [],
            life: LifeState.newGame(balance: balance),
            market: .neutral,
            rivals: .empty,
            city: .legacy,
            friendships: [],
            pendingStaffEvent: nil,
            lastTeamDinnerDay: nil,
            loanBalance: 0,
            amenities: [],
            knownDepartments: [],
            economy: .initial,
            narrative: .initial,
            progression: .initial,
            investors: .initial,
            gameOver: nil
        )
    }

    /// Departments staffed right now: any employee whose role staffs one.
    public var activeDepartments: Set<Department> {
        Set(employees.compactMap(\.role.department))
    }

    public func hasDepartment(_ department: Department) -> Bool {
        employees.contains { $0.role.department == department }
    }

    public func hasAmenity(_ amenity: Amenity) -> Bool {
        amenities.contains(amenity)
    }

    /// Owned amenities in `Amenity.allCases` order, so sums over their
    /// bonuses accumulate in a fixed order (set iteration order is not).
    var ownedAmenities: [Amenity] {
        Amenity.allCases.filter { amenities.contains($0) }
    }

    /// This week's office rent: the tier's rent scaled by the district,
    /// after the Operations discount. An owned office pays no rent
    /// (`CitySystem` posts property tax instead).
    func officeWeeklyRent(balance: BalanceConfig) -> Int {
        guard !city.ownership.isOwned else { return 0 }
        let rent = Double(balance.office(company.officeTier).weeklyRent)
            * balance.city.district(city.district).rentMultiplier
        guard hasDepartment(.ops) else { return Int(rent.rounded()) }
        return Int((rent * balance.company.opsRentFactor).rounded())
    }

    /// What buying the current tier's space in a district costs:
    /// `buyPriceFactor` weeks of that district's rent (a garage's free rent
    /// reads as a small baseline so even it has a price).
    public func officePurchasePrice(in district: DistrictID, balance: BalanceConfig) -> Int {
        let weekly = Double(max(balance.office(company.officeTier).weeklyRent, 50))
            * balance.city.district(district).rentMultiplier
        return Int((weekly * balance.city.buyPriceFactor).rounded())
    }

    /// This week's amenity upkeep after the Operations discount.
    func amenityWeeklyUpkeep(balance: BalanceConfig) -> Int {
        let upkeep = ownedAmenities.reduce(0) { $0 + balance.company.amenity($1).weeklyCost }
        guard hasDepartment(.ops) else { return upkeep }
        return Int((Double(upkeep) * balance.company.opsUpkeepFactor).rounded())
    }

    /// The single product currently in development, if any.
    public var productInDevelopment: Product? {
        products.first { product in
            if case .development = product.stage { return true }
            return false
        }
    }

    /// Every product currently in development. One at a time today; WS-A
    /// opens concurrent slots by office tier and `productInDevelopment`
    /// stays as the first-of-these shorthand for the UI.
    public var productsInDevelopment: [Product] {
        products.filter { product in
            if case .development = product.stage { return true }
            return false
        }
    }

    /// How many products may be in development at once. 1 today; WS-A
    /// scales it by office tier (garage 1, loft 2, studio 3, campus 5).
    public var devSlots: Int { 1 }

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

    /// What the company is worth to an acquirer: cash on hand, a revenue
    /// multiple over each on-market product's recent sales, and a premium
    /// per reputation point. Deterministic — no RNG.
    public func companyValuation(balance: BalanceConfig) -> Int {
        let rivalBalance = balance.rivals
        var value = Double(company.cash - loanBalance)
        for product in products {
            guard case .released(let info) = product.stage, !info.offMarket else { continue }
            let recent = info.weeklySales.suffix(4).reduce(0) { $0 + $1.revenue }
            value += Double(recent) * rivalBalance.valuationRevenueMultiple
        }
        value += company.reputation * rivalBalance.valuationPerReputation
        return max(0, Int(value.rounded()))
    }
}

// MARK: - Codable

// Hand-written (in an extension, preserving the memberwise initializer) so
// the sets (`milestonesReached`, `amenities`, `knownDepartments`) encode in
// sorted order: `Set` iteration order is not stable across processes, and
// saves (like the determinism tests) rely on byte-identical JSON for
// identical states. The set, `life`, `market`, `loanBalance`, and
// `difficulty` keys also decode as optional so saves written before the
// fields existed keep loading (a missing life starts fresh with an empty
// wallet; a missing difficulty is Normal). The four workstream sub-states
// (`economy`, `narrative`, `progression`, `investors`) follow the same
// rule: absent keys decode as `.initial`, so `saveFormatVersion` stays 1.

extension GameState {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion, rng, day, speed, company, ledger, products, employees
        case candidatePool, research, contractOffers, activeContracts, campaigns
        case eventLog, milestonesReached, life, market, loanBalance, gameOver
        case amenities, knownDepartments, difficulty
        case worldRNG, rivals, city, friendships, pendingStaffEvent, lastTeamDinnerDay
        case economy, narrative, progression, investors
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            schemaVersion: try container.decode(Int.self, forKey: .schemaVersion),
            difficulty: try container.decodeIfPresent(Difficulty.self, forKey: .difficulty) ?? .normal,
            rng: try container.decode(SeededRNG.self, forKey: .rng),
            // Pre-rivals saves get a fixed-seed world stream; determinism
            // only needs encode/decode round-trips to be stable, which a
            // constant is.
            worldRNG: try container.decodeIfPresent(SeededRNG.self, forKey: .worldRNG)
                ?? SeededRNG(seed: 0xC0FF_EE00_C0FF_EE00),
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
            market: try container.decodeIfPresent(MarketState.self, forKey: .market) ?? .neutral,
            rivals: try container.decodeIfPresent(RivalsState.self, forKey: .rivals) ?? .empty,
            city: try container.decodeIfPresent(CityState.self, forKey: .city) ?? .legacy,
            friendships: try container.decodeIfPresent([Friendship].self, forKey: .friendships) ?? [],
            pendingStaffEvent: try container.decodeIfPresent(StaffEvent.self, forKey: .pendingStaffEvent),
            lastTeamDinnerDay: try container.decodeIfPresent(Int.self, forKey: .lastTeamDinnerDay),
            loanBalance: try container.decodeIfPresent(Int.self, forKey: .loanBalance) ?? 0,
            amenities: Set(try container.decodeIfPresent([Amenity].self, forKey: .amenities) ?? []),
            knownDepartments: Set(
                try container.decodeIfPresent([Department].self, forKey: .knownDepartments) ?? []
            ),
            economy: try container.decodeIfPresent(EconomyState.self, forKey: .economy) ?? .initial,
            narrative: try container.decodeIfPresent(NarrativeState.self, forKey: .narrative) ?? .initial,
            progression: try container.decodeIfPresent(ProgressionState.self, forKey: .progression)
                ?? .initial,
            investors: try container.decodeIfPresent(InvestorState.self, forKey: .investors) ?? .initial,
            gameOver: try container.decodeIfPresent(GameOverInfo.self, forKey: .gameOver)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encode(rng, forKey: .rng)
        try container.encode(worldRNG, forKey: .worldRNG)
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
        try container.encode(market, forKey: .market)
        try container.encode(rivals, forKey: .rivals)
        try container.encode(city, forKey: .city)
        try container.encode(
            friendships.sorted {
                ($0.a.uuidString, $0.b.uuidString) < ($1.a.uuidString, $1.b.uuidString)
            },
            forKey: .friendships
        )
        try container.encodeIfPresent(pendingStaffEvent, forKey: .pendingStaffEvent)
        try container.encodeIfPresent(lastTeamDinnerDay, forKey: .lastTeamDinnerDay)
        try container.encode(loanBalance, forKey: .loanBalance)
        try container.encode(amenities.sorted { $0.rawValue < $1.rawValue }, forKey: .amenities)
        try container.encode(
            knownDepartments.sorted { $0.rawValue < $1.rawValue }, forKey: .knownDepartments
        )
        try container.encode(economy, forKey: .economy)
        try container.encode(narrative, forKey: .narrative)
        try container.encode(progression, forKey: .progression)
        try container.encode(investors, forKey: .investors)
        try container.encodeIfPresent(gameOver, forKey: .gameOver)
    }
}
