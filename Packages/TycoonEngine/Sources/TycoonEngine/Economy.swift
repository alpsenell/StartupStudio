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

    public init(
        employeeID: UUID,
        name: String,
        sinceDay: Int,
        respondByDay: Int,
        salaryAtNotice: Int
    ) {
        self.employeeID = employeeID
        self.name = name
        self.sinceDay = sinceDay
        self.respondByDay = respondByDay
        self.salaryAtNotice = salaryAtNotice
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
    /// The day each hospital stay began (used for the "twice in a year"
    /// chronic trigger). Kept sorted, capped at the last few years.
    public var hospitalizationDays: [Int]
    /// The day each burnout began ("twice in a year" makes the news).
    public var burnoutDays: [Int]
    /// Consecutive weeks the founder spent a weekend on gym / spa / doctor,
    /// counting toward curing a chronic condition.
    public var recoveryWeeks: Int
    /// The day the founder's relationships meter bottomed out while single;
    /// `nil` whenever they are not lonely.
    public var lonelySinceDay: Int?
    /// The last day an eviction warning was served (one per debt spiral).
    public var evictionWarningDay: Int?
    /// The last day a non-critical event was allowed to stop the clock —
    /// the pause budget's cursor.
    public var lastNonCriticalPauseDay: Int?
    /// Why the clock stopped on the last tick that stopped it, decided by
    /// `PausePolicy`. Empty whenever the pause did not come from an event.
    /// Persisted, so "why did time stop?" survives a relaunch the way the
    /// pending-decision sheets do.
    public var pauseEvents: [GameEvent]

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
        lastNonCriticalPauseDay: Int? = nil,
        pauseEvents: [GameEvent] = []
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
        self.lastNonCriticalPauseDay = lastNonCriticalPauseDay
        self.pauseEvents = pauseEvents
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
            lastNonCriticalPauseDay: try container.decodeIfPresent(
                Int.self, forKey: .lastNonCriticalPauseDay
            ),
            pauseEvents: try container.decodeIfPresent([GameEvent].self, forKey: .pauseEvents) ?? []
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
        try container.encodeIfPresent(lastNonCriticalPauseDay, forKey: .lastNonCriticalPauseDay)
        try container.encode(pauseEvents, forKey: .pauseEvents)
    }
}
