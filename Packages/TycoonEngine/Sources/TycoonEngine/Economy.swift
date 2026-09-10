import Foundation

/// The pace the whole company works at. Crunch buys speed with morale,
/// bugs, and the founder's evenings; relaxed trades a slice of output for a
/// team that stays. `.normal` is the neutral middle.
public enum WorkPace: String, Codable, Equatable, Sendable, CaseIterable {
    case relaxed, normal, crunch

    public var displayName: String {
        switch self {
        case .relaxed: "Relaxed"
        case .normal: "Normal"
        case .crunch: "Crunch"
        }
    }
}

/// An employee who has handed in their notice. The founder has until
/// `respondByDay` to counter with a raise or a promotion; otherwise they
/// walk. Exactly one can be open at a time, mirroring the pending
/// poach/staff/buyout decisions.
public struct PendingResignation: Codable, Equatable, Sendable {
    public var employeeID: UUID
    public var name: String
    /// The day notice was given.
    public var sinceDay: Int
    /// The last day a counter-offer still lands.
    public var respondByDay: Int
    /// The weekly salary they were on when they resigned, so a counter can
    /// be graded against it.
    public var salaryAtNotice: Int
    /// Why, when the notice is the second act of an answer the founder
    /// gave (WS-D) — a sentence the resignation sheet shows. Nil for a
    /// resignation morale alone explains, and in every older save.
    public var reason: String?

    public init(
        employeeID: UUID,
        name: String,
        sinceDay: Int,
        respondByDay: Int,
        salaryAtNotice: Int,
        reason: String? = nil
    ) {
        self.employeeID = employeeID
        self.name = name
        self.sinceDay = sinceDay
        self.respondByDay = respondByDay
        self.salaryAtNotice = salaryAtNotice
        self.reason = reason
    }
}

/// A patch cycle on an already-released product: a short second development
/// pass (a fraction of the original point pools) that, on completion, lifts
/// quality, re-reviews the product at reduced weight, and buys one bumper
/// sales week.
public struct ProductUpdate: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID { productID }
    public var productID: UUID
    public var startedDay: Int
    /// Points needed to finish the patch.
    public var designPts: Double
    public var codePts: Double
    public var polishPts: Double
    /// Points banked so far.
    public var progressDesign: Double
    public var progressCode: Double
    public var progressPolish: Double

    public init(
        productID: UUID,
        startedDay: Int,
        designPts: Double,
        codePts: Double,
        polishPts: Double,
        progressDesign: Double = 0,
        progressCode: Double = 0,
        progressPolish: Double = 0
    ) {
        self.productID = productID
        self.startedDay = startedDay
        self.designPts = designPts
        self.codePts = codePts
        self.polishPts = polishPts
        self.progressDesign = progressDesign
        self.progressCode = progressCode
        self.progressPolish = progressPolish
    }

    /// Fraction of the patch finished, 0...1 across all three pools.
    public var completion: Double {
        let pools = [
            (progressDesign, designPts), (progressCode, codePts), (progressPolish, polishPts),
        ]
        let total = pools.reduce(0.0) { $0 + $1.1 }
        guard total > 0 else { return 1 }
        return pools.reduce(0.0) { $0 + min($1.0, $1.1) } / total
    }

    /// Whether every pool is full.
    public var isComplete: Bool {
        progressDesign >= designPts && progressCode >= codePts && progressPolish >= polishPts
    }
}

/// Everything the economy, live-ops and pacing systems persist.
///
/// Every field decodes with a default, so a save written before the field
/// existed loads as a company that simply never used it; the two maps
/// encode as arrays sorted by key so identical states stay byte-identical.
public struct EconomyState: Codable, Equatable, Sendable {
    /// How hard the whole company is pushed.
    public var workPace: WorkPace
    /// The one open resignation the founder can still counter.
    public var pendingResignation: PendingResignation?
    /// The last day each employee was recognised — hired, raised, promoted
    /// or trained. Long silences feed the stagnation morale penalty.
    public var lastRecognitionDay: [UUID: Int]
    /// Patch cycles running on released products.
    public var updates: [ProductUpdate]
    /// The founder carries a long-term condition: energy is capped and
    /// output permanently docked until three straight weeks of looking
    /// after themselves.
    public var chronicCondition: Bool
    /// The day each hospital stay began, oldest first — the "twice in a
    /// year" chronic trigger reads it, and a weekly sweep drops anything
    /// older than the window.
    public var hospitalizationDays: [Int]
    /// The day each burnout began, oldest first, on the same weekly sweep.
    /// Twice inside the window makes the news.
    public var burnoutDays: [Int]
    /// Consecutive weeks the founder spent a weekend on gym / spa / doctor,
    /// counting toward curing a chronic condition.
    public var recoveryWeeks: Int
    /// The day the founder's relationships meter bottomed out while single;
    /// `nil` whenever they are not lonely.
    public var lonelySinceDay: Int?
    /// The last day an eviction warning was served (one per debt spiral).
    public var evictionWarningDay: Int?
    /// The day the founder is signed off until after a hospital stay.
    /// While it stands the schedule is pinned to `.chill` and a request to
    /// crunch is refused: somebody who has just been discharged is not
    /// pulling another all-nighter, whatever the roadmap says.
    public var convalescingUntilDay: Int?
    /// The wallet at the last weekly settlement, so the debt mood penalty
    /// can tell "broke and sinking" from "broke and climbing out".
    public var walletLastWeek: Int?
    /// The founder salary the eviction rescue set, so it can be stepped
    /// back down once the overdraft is cleared — and so a salary the
    /// player set themselves is never touched.
    public var rescueSalary: Int?
    /// How much of `loanBalance` the founder has personally guaranteed
    /// against their home. Nothing until they sign for it, and the first
    /// thing the bank comes for when the company stops paying.
    public var guaranteedLoanAmount: Int
    /// The last day a non-critical event was allowed to stop the clock —
    /// the pause budget's cursor.
    public var lastNonCriticalPauseDay: Int?
    /// Why the clock stopped on the last tick that stopped it, decided by
    /// `PausePolicy`. Empty whenever the pause did not come from an event.
    /// Persisted, so "why did time stop?" survives a relaunch the way the
    /// pending-decision sheets do.
    public var pauseEvents: [GameEvent]

    // MARK: Iteration 10 — M3 (incident room)

    /// The run's incident ledger: whether the player has ever opened the
    /// Products tab (nothing is raised until they have) and the last day
    /// each product had an incident. `.empty` for every run that has never
    /// opened the tab, and encoded only when it is not — so a pacing bot's
    /// save is byte-for-byte the save it always was. See `Incident.swift`.
    public var incidents: IncidentLog

    // MARK: end M3

    // MARK: K1 (founder money)

    /// The director's loan, the last dividend and the landlord's question
    /// (`FounderMoney.swift`). `.empty` for every run that never lent,
    /// paid out or was asked, and encoded only when it is not.
    public var founderMoney: FounderMoneyState

    // MARK: end K1

    public init(
        workPace: WorkPace = .normal,
        pendingResignation: PendingResignation? = nil,
        lastRecognitionDay: [UUID: Int] = [:],
        updates: [ProductUpdate] = [],
        chronicCondition: Bool = false,
        hospitalizationDays: [Int] = [],
        burnoutDays: [Int] = [],
        recoveryWeeks: Int = 0,
        lonelySinceDay: Int? = nil,
        evictionWarningDay: Int? = nil,
        convalescingUntilDay: Int? = nil,
        walletLastWeek: Int? = nil,
        rescueSalary: Int? = nil,
        guaranteedLoanAmount: Int = 0,
        lastNonCriticalPauseDay: Int? = nil,
        pauseEvents: [GameEvent] = [],
        // MARK: Iteration 10 — M3 (incident room)
        incidents: IncidentLog = .empty,
        // MARK: end M3
        // MARK: K1 (founder money)
        founderMoney: FounderMoneyState = .empty
        // MARK: end K1
    ) {
        self.workPace = workPace
        self.pendingResignation = pendingResignation
        self.lastRecognitionDay = lastRecognitionDay
        self.updates = updates
        self.chronicCondition = chronicCondition
        self.hospitalizationDays = hospitalizationDays
        self.burnoutDays = burnoutDays
        self.recoveryWeeks = recoveryWeeks
        self.lonelySinceDay = lonelySinceDay
        self.evictionWarningDay = evictionWarningDay
        self.convalescingUntilDay = convalescingUntilDay
        self.walletLastWeek = walletLastWeek
        self.rescueSalary = rescueSalary
        self.guaranteedLoanAmount = guaranteedLoanAmount
        self.lastNonCriticalPauseDay = lastNonCriticalPauseDay
        self.pauseEvents = pauseEvents
        // MARK: Iteration 10 — M3 (incident room)
        self.incidents = incidents
        // MARK: end M3
        // MARK: K1 (founder money)
        self.founderMoney = founderMoney
        // MARK: end K1
    }

    /// A fresh company's economy state.
    public static let initial = EconomyState()

    /// The update running on a product, if any.
    public func update(for productID: UUID) -> ProductUpdate? {
        updates.first { $0.productID == productID }
    }
}

// MARK: - Codable

// Hand-written so `lastRecognitionDay` encodes as an array sorted by id
// (`Dictionary` key order is not stable across processes and saves rely on
// byte-identical JSON for identical states) and so every key decodes as
// optional: a save written before the economy pass existed loads as a
// company on a normal pace that never had a resignation, a patch, or a bad
// year.

extension EconomyState {
    private enum CodingKeys: String, CodingKey {
        case workPace, pendingResignation, lastRecognitionDay, updates
        case chronicCondition, hospitalizationDays, burnoutDays, recoveryWeeks
        case lonelySinceDay, evictionWarningDay, lastNonCriticalPauseDay, pauseEvents
        case convalescingUntilDay, walletLastWeek, rescueSalary, guaranteedLoanAmount
        // MARK: Iteration 10 — M3 (incident room)
        case incidents
        // MARK: end M3
        // MARK: K1 (founder money)
        case founderMoney
        // MARK: end K1
    }

    private struct RecognitionEntry: Codable {
        var employeeID: UUID
        var day: Int
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let recognition = try container.decodeIfPresent(
            [RecognitionEntry].self, forKey: .lastRecognitionDay
        ) ?? []
        self.init(
            workPace: try container.decodeIfPresent(WorkPace.self, forKey: .workPace) ?? .normal,
            pendingResignation: try container.decodeIfPresent(
                PendingResignation.self, forKey: .pendingResignation
            ),
            lastRecognitionDay: Dictionary(
                recognition.map { ($0.employeeID, $0.day) }, uniquingKeysWith: { _, last in last }
            ),
            updates: try container.decodeIfPresent([ProductUpdate].self, forKey: .updates) ?? [],
            chronicCondition: try container.decodeIfPresent(Bool.self, forKey: .chronicCondition) ?? false,
            hospitalizationDays: try container.decodeIfPresent(
                [Int].self, forKey: .hospitalizationDays
            ) ?? [],
            burnoutDays: try container.decodeIfPresent([Int].self, forKey: .burnoutDays) ?? [],
            recoveryWeeks: try container.decodeIfPresent(Int.self, forKey: .recoveryWeeks) ?? 0,
            lonelySinceDay: try container.decodeIfPresent(Int.self, forKey: .lonelySinceDay),
            evictionWarningDay: try container.decodeIfPresent(Int.self, forKey: .evictionWarningDay),
            convalescingUntilDay: try container.decodeIfPresent(
                Int.self, forKey: .convalescingUntilDay
            ),
            walletLastWeek: try container.decodeIfPresent(Int.self, forKey: .walletLastWeek),
            rescueSalary: try container.decodeIfPresent(Int.self, forKey: .rescueSalary),
            guaranteedLoanAmount: try container.decodeIfPresent(
                Int.self, forKey: .guaranteedLoanAmount
            ) ?? 0,
            lastNonCriticalPauseDay: try container.decodeIfPresent(
                Int.self, forKey: .lastNonCriticalPauseDay
            ),
            pauseEvents: try container.decodeIfPresent([GameEvent].self, forKey: .pauseEvents) ?? [],
            // MARK: Iteration 10 — M3 (incident room)
            incidents: try container.decodeIfPresent(IncidentLog.self, forKey: .incidents) ?? .empty,
            // MARK: end M3
            // MARK: K1 (founder money)
            founderMoney: try container.decodeIfPresent(
                FounderMoneyState.self, forKey: .founderMoney
            ) ?? .empty
            // MARK: end K1
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(workPace, forKey: .workPace)
        try container.encodeIfPresent(pendingResignation, forKey: .pendingResignation)
        try container.encode(
            lastRecognitionDay.keys.sorted { $0.uuidString < $1.uuidString }.map {
                RecognitionEntry(employeeID: $0, day: lastRecognitionDay[$0] ?? 0)
            },
            forKey: .lastRecognitionDay
        )
        try container.encode(updates, forKey: .updates)
        try container.encode(chronicCondition, forKey: .chronicCondition)
        try container.encode(hospitalizationDays, forKey: .hospitalizationDays)
        try container.encode(burnoutDays, forKey: .burnoutDays)
        try container.encode(recoveryWeeks, forKey: .recoveryWeeks)
        try container.encodeIfPresent(lonelySinceDay, forKey: .lonelySinceDay)
        try container.encodeIfPresent(evictionWarningDay, forKey: .evictionWarningDay)
        try container.encodeIfPresent(convalescingUntilDay, forKey: .convalescingUntilDay)
        try container.encodeIfPresent(walletLastWeek, forKey: .walletLastWeek)
        try container.encodeIfPresent(rescueSalary, forKey: .rescueSalary)
        try container.encode(guaranteedLoanAmount, forKey: .guaranteedLoanAmount)
        try container.encodeIfPresent(lastNonCriticalPauseDay, forKey: .lastNonCriticalPauseDay)
        try container.encode(pauseEvents, forKey: .pauseEvents)
        // MARK: Iteration 10 — M3 (incident room)
        // Encoded only when the player has touched it: an untouched run
        // writes exactly the bytes it wrote before incidents existed.
        if !incidents.isEmpty {
            try container.encode(incidents, forKey: .incidents)
        }
        // MARK: end M3
        // MARK: K1 (founder money)
        // Encoded only when the founder lent, paid out or was asked.
        if !founderMoney.isEmpty {
            try container.encode(founderMoney, forKey: .founderMoney)
        }
        // MARK: end K1
    }
}
