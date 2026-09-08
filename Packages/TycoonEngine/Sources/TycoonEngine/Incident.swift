import Foundation

// Iteration 10 — M3 owns this file. A live product breaking, handled in the
// incident room with the clock stopped; `GameState.incident` is `nil` when
// nothing is on fire, which is every run that has never had one.
//
// Everything here is inert until `IncidentSystem` raises an incident, and it
// cannot raise one until the player has opened the Products tab in this run
// (`IncidentLog.hasOpenedProducts`, set by the app). A pacing bot never opens
// a tab, so a bot's run is the run that shipped.

// MARK: - What broke

/// The three ways a live product goes wrong.
public enum IncidentKind: String, Codable, Equatable, Sendable, CaseIterable {
    /// A patch shipped and the wild lit up with bugs.
    case badPatch
    /// More people arrived than the servers were sized for.
    case viralSpike
    /// Somebody got at the user data.
    case dataLeak

    public var displayName: String {
        switch self {
        case .badPatch: "Bad patch"
        case .viralSpike: "Traffic spike"
        case .dataLeak: "Data leak"
        }
    }

    /// The line the room opens on.
    public var summary: String {
        switch self {
        case .badPatch: "The patch went out and took the product with it."
        case .viralSpike: "Everyone arrived at once and the servers are folding."
        case .dataLeak: "User data is out there and somebody has noticed."
        }
    }

    /// What the status page says while it is red.
    public var statusHeadline: String {
        switch self {
        case .badPatch: "MAJOR OUTAGE"
        case .viralSpike: "DEGRADED SERVICE"
        case .dataLeak: "SECURITY INCIDENT"
        }
    }

    /// How much of the audience walks per hour before anybody does
    /// anything, as a share of the product's reach.
    public var bleedShare: Double {
        switch self {
        case .badPatch: 0.016
        case .viralSpike: 0.011
        case .dataLeak: 0.024
        }
    }

    /// Bugs a botched repair leaves in the wild.
    public var bugLoad: Double {
        switch self {
        case .badPatch: 14
        case .viralSpike: 6
        case .dataLeak: 9
        }
    }

    /// What the studio's reputation loses if nobody mitigates at all.
    public var reputationHit: Double {
        switch self {
        case .badPatch: 6
        case .viralSpike: 4
        case .dataLeak: 11
        }
    }
}

// MARK: - The three lanes

/// The three things a room can do at once. People are assigned to one of
/// them; every one of them is worth doing and none of them is free.
public enum IncidentThread: String, Codable, Equatable, Sendable, CaseIterable, Identifiable {
    /// Stop the bleeding: roll back, throttle, take it off the market for
    /// an hour.
    case mitigate
    /// Tell people: the status page, the replies, the outlets calling.
    case communicate
    /// Actually fix the thing.
    case fix

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .mitigate: "Mitigate"
        case .communicate: "Communicate"
        case .fix: "Fix"
        }
    }

    public var blurb: String {
        switch self {
        case .mitigate: "Slows what is leaving."
        case .communicate: "Makes the statement believed."
        case .fix: "Ends it for good."
        }
    }

    /// Stable order for the board's three lanes.
    public var sortIndex: Int {
        switch self {
        case .mitigate: 0
        case .communicate: 1
        case .fix: 2
        }
    }
}

/// The colour of the status page.
public enum IncidentStatus: String, Codable, Equatable, Sendable {
    case red, amber, green

    public var displayName: String {
        switch self {
        case .red: "Major outage"
        case .amber: "Degraded"
        case .green: "Operational"
        }
    }
}

// MARK: - The statement

/// One of the three things the company can say in public. Chosen once; it
/// lands at `.resolveIncident`.
public struct IncidentStatement: Identifiable, Equatable, Sendable {
    public let id: String
    /// The button's line.
    public let headline: String
    /// What it actually says, in the story sheet's voice.
    public let body: String
    /// Reputation at full credibility. Communication is the multiplier.
    public let reputationDelta: Double
    /// Multiplies the users who were leaving anyway.
    public let churnFactor: Double
    /// Whether it promises a fix. Promising one and not shipping it costs
    /// `IncidentBalance.brokenPromisePenalty` on top.
    public let promisesFix: Bool

    public init(
        id: String,
        headline: String,
        body: String,
        reputationDelta: Double,
        churnFactor: Double,
        promisesFix: Bool
    ) {
        self.id = id
        self.headline = headline
        self.body = body
        self.reputationDelta = reputationDelta
        self.churnFactor = churnFactor
        self.promisesFix = promisesFix
    }
}

/// The three statements each kind offers. The numbers on them are the shape
/// of the choice — own it, explain it, or say as little as possible — and
/// they are the same three shapes every time, so the player learns them.
public enum IncidentStatements {
    public static func all(for kind: IncidentKind, productName: String) -> [IncidentStatement] {
        switch kind {
        case .badPatch:
            [
                IncidentStatement(
                    id: "own",
                    headline: "We broke it. We are rolling back.",
                    body: "Yesterday's update to \(productName) shipped a regression we should have caught. "
                        + "It is being rolled back now, and we will publish what went wrong.",
                    reputationDelta: 3,
                    churnFactor: 0.7,
                    promisesFix: true
                ),
                IncidentStatement(
                    id: "explain",
                    headline: "Here is exactly what happened.",
                    body: "A change to \(productName)'s sync path failed under load. "
                        + "The fault, the window and the fix are on the status page.",
                    reputationDelta: 1,
                    churnFactor: 0.85,
                    promisesFix: false
                ),
                IncidentStatement(
                    id: "downplay",
                    headline: "A small number of users are affected.",
                    body: "Some users of \(productName) report an issue after the latest update. "
                        + "We are looking into it.",
                    reputationDelta: -1,
                    churnFactor: 1.15,
                    promisesFix: false
                ),
            ]
        case .viralSpike:
            [
                IncidentStatement(
                    id: "own",
                    headline: "More of you turned up than we built for.",
                    body: "\(productName) is slow because far more people arrived than we planned for. "
                        + "That is our sizing, not your connection. Capacity goes up today.",
                    reputationDelta: 4,
                    churnFactor: 0.7,
                    promisesFix: true
                ),
                IncidentStatement(
                    id: "explain",
                    headline: "We are adding capacity.",
                    body: "\(productName) is running degraded under unusual load. "
                        + "New capacity is coming online and the queues are draining.",
                    reputationDelta: 1,
                    churnFactor: 0.85,
                    promisesFix: false
                ),
                IncidentStatement(
                    id: "downplay",
                    headline: "Success has a cost.",
                    body: "\(productName) is more popular than ever, and it shows. Thanks for your patience.",
                    reputationDelta: -2,
                    churnFactor: 1.2,
                    promisesFix: false
                ),
            ]
        case .dataLeak:
            [
                IncidentStatement(
                    id: "own",
                    headline: "Your data was exposed. Here is everything.",
                    body: "An unsecured export left \(productName)'s user records reachable. "
                        + "We have closed it, we are telling every affected account, and an auditor is coming in.",
                    reputationDelta: 2,
                    churnFactor: 0.65,
                    promisesFix: true
                ),
                IncidentStatement(
                    id: "explain",
                    headline: "No passwords were taken.",
                    body: "Records from \(productName) were reachable without authentication. "
                        + "Credentials were not among them. The hole is closed.",
                    reputationDelta: 0,
                    churnFactor: 0.9,
                    promisesFix: false
                ),
                IncidentStatement(
                    id: "downplay",
                    headline: "We are aware of the reports.",
                    body: "We have seen the reports concerning \(productName) and are investigating.",
                    reputationDelta: -4,
                    churnFactor: 1.25,
                    promisesFix: false
                ),
            ]
        }
    }

    public static func statement(
        _ id: String, for kind: IncidentKind, productName: String
    ) -> IncidentStatement? {
        all(for: kind, productName: productName).first { $0.id == id }
    }
}

// MARK: - The room's state

/// The incident room: the three threads, who is on each, what has been
/// said, and how many users have walked out while it ran.
///
/// Every mutation is an action through the reducer — including the room's
/// own clock (`.advanceIncident`) — so a room is deterministic and
/// replayable, and no wall clock reaches it.
public struct IncidentState: Codable, Equatable, Sendable {
    public var productID: UUID
    public var kind: IncidentKind
    public var startedDay: Int
    /// Who is on which lane. An employee is on at most one.
    public var assignments: [UUID: IncidentThread]
    /// Each lane's progress, 0…100.
    public var mitigate: Double
    public var communicate: Double
    public var fix: Double
    /// Users who have walked out so far.
    public var usersLost: Int
    /// The statement chosen, `nil` until the player picks one.
    public var statementID: String?
    /// How many hours of the room have been spent.
    public var hoursSpent: Int
    /// The product's reach when the incident started — subscribers for a
    /// subscription, last week's units otherwise. The bleed is a share of
    /// this, so it does not chase a number the incident is changing.
    public var reach: Int

    public init(
        productID: UUID,
        kind: IncidentKind,
        startedDay: Int,
        assignments: [UUID: IncidentThread] = [:],
        mitigate: Double = 0,
        communicate: Double = 0,
        fix: Double = 0,
        usersLost: Int = 0,
        statementID: String? = nil,
        hoursSpent: Int = 0,
        reach: Int = 0
    ) {
        self.productID = productID
        self.kind = kind
        self.startedDay = startedDay
        self.assignments = assignments
        self.mitigate = mitigate
        self.communicate = communicate
        self.fix = fix
        self.usersLost = usersLost
        self.statementID = statementID
        self.hoursSpent = hoursSpent
        self.reach = reach
    }

    /// Progress on one lane.
    public func progress(_ thread: IncidentThread) -> Double {
        switch thread {
        case .mitigate: mitigate
        case .communicate: communicate
        case .fix: fix
        }
    }

    mutating func advance(_ thread: IncidentThread, by amount: Double) {
        switch thread {
        case .mitigate: mitigate = min(100, mitigate + amount)
        case .communicate: communicate = min(100, communicate + amount)
        case .fix: fix = min(100, fix + amount)
        }
    }

    /// Who is on `thread`, in no particular order — callers sort by the
    /// roster.
    public func crew(on thread: IncidentThread) -> [UUID] {
        assignments.filter { $0.value == thread }.map(\.key)
    }

    /// The status page's colour. Green needs both the bleeding stopped and
    /// the thing actually fixed.
    public var status: IncidentStatus {
        if mitigate >= 100, fix >= 100 { return .green }
        if mitigate >= 50 || fix >= 50 { return .amber }
        return .red
    }

    /// Whether the room has anything left to do this shift.
    public func hasHoursLeft(_ balance: BalanceConfig) -> Bool {
        hoursSpent < balance.incidents.hoursPerIncident
    }

    /// Everything settled: the fix landed and the statement is out.
    public var isHandled: Bool {
        fix >= 100 && statementID != nil
    }
}

// MARK: - Codable

// Hand-written so `assignments` encodes as an array sorted by employee id
// (dictionary key order is not stable across processes, and identical
// states must produce identical saves) and so every key decodes with a
// default.
extension IncidentState {
    private enum CodingKeys: String, CodingKey {
        case productID, kind, startedDay, assignments
        case mitigate, communicate, fix, usersLost, statementID, hoursSpent, reach
    }

    private struct AssignmentEntry: Codable {
        var employeeID: UUID
        var thread: IncidentThread
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entries = try container.decodeIfPresent(
            [AssignmentEntry].self, forKey: .assignments
        ) ?? []
        self.init(
            productID: try container.decode(UUID.self, forKey: .productID),
            kind: try container.decode(IncidentKind.self, forKey: .kind),
            startedDay: try container.decode(Int.self, forKey: .startedDay),
            assignments: Dictionary(
                entries.map { ($0.employeeID, $0.thread) }, uniquingKeysWith: { _, last in last }
            ),
            mitigate: try container.decodeIfPresent(Double.self, forKey: .mitigate) ?? 0,
            communicate: try container.decodeIfPresent(Double.self, forKey: .communicate) ?? 0,
            fix: try container.decodeIfPresent(Double.self, forKey: .fix) ?? 0,
            usersLost: try container.decodeIfPresent(Int.self, forKey: .usersLost) ?? 0,
            statementID: try container.decodeIfPresent(String.self, forKey: .statementID),
            hoursSpent: try container.decodeIfPresent(Int.self, forKey: .hoursSpent) ?? 0,
            reach: try container.decodeIfPresent(Int.self, forKey: .reach) ?? 0
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(productID, forKey: .productID)
        try container.encode(kind, forKey: .kind)
        try container.encode(startedDay, forKey: .startedDay)
        try container.encode(
            assignments.keys.sorted { $0.uuidString < $1.uuidString }.map {
                AssignmentEntry(employeeID: $0, thread: assignments[$0] ?? .mitigate)
            },
            forKey: .assignments
        )
        try container.encode(mitigate, forKey: .mitigate)
        try container.encode(communicate, forKey: .communicate)
        try container.encode(fix, forKey: .fix)
        try container.encode(usersLost, forKey: .usersLost)
        try container.encodeIfPresent(statementID, forKey: .statementID)
        try container.encode(hoursSpent, forKey: .hoursSpent)
        try container.encode(reach, forKey: .reach)
    }
}

// MARK: - The run's incident ledger

/// The two per-run facts an incident needs that outlive the room itself:
/// whether the player has ever opened the Products tab (nothing fires until
/// they have, which is what keeps the pacing bots where they are) and the
/// last day each product had one (at most one a quarter).
///
/// Lives on `EconomyState` behind one field, encoded only when it is not
/// `.empty`, so a run that never opens the Products tab writes no new key.
public struct IncidentLog: Codable, Equatable, Sendable {
    /// Set by the app the first time the player opens the Products tab.
    /// False for every headless run, every pacing bot, and every save
    /// written before incidents existed.
    public var hasOpenedProducts: Bool
    /// Product id → the day its last incident was raised.
    public var lastIncidentDay: [UUID: Int]

    public init(hasOpenedProducts: Bool = false, lastIncidentDay: [UUID: Int] = [:]) {
        self.hasOpenedProducts = hasOpenedProducts
        self.lastIncidentDay = lastIncidentDay
    }

    public static let empty = IncidentLog()

    public var isEmpty: Bool { self == .empty }
}

extension IncidentLog {
    private enum CodingKeys: String, CodingKey {
        case hasOpenedProducts, lastIncidentDay
    }

    private struct DayEntry: Codable {
        var productID: UUID
        var day: Int
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entries = try container.decodeIfPresent([DayEntry].self, forKey: .lastIncidentDay) ?? []
        self.init(
            hasOpenedProducts: try container.decodeIfPresent(
                Bool.self, forKey: .hasOpenedProducts
            ) ?? false,
            lastIncidentDay: Dictionary(
                entries.map { ($0.productID, $0.day) }, uniquingKeysWith: { _, last in last }
            )
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hasOpenedProducts, forKey: .hasOpenedProducts)
        try container.encode(
            lastIncidentDay.keys.sorted { $0.uuidString < $1.uuidString }.map {
                DayEntry(productID: $0, day: lastIncidentDay[$0] ?? 0)
            },
            forKey: .lastIncidentDay
        )
    }
}

// MARK: - What the room did

/// The settled result of a room, carried by `.incidentResolved` so every
/// surface reads the same numbers.
public struct IncidentOutcome: Codable, Equatable, Sendable {
    public var kind: IncidentKind
    public var usersLost: Int
    public var reputationDelta: Double
    public var bugsLeft: Int
    public var statementID: String?
    public var status: IncidentStatus

    public init(
        kind: IncidentKind,
        usersLost: Int,
        reputationDelta: Double,
        bugsLeft: Int,
        statementID: String?,
        status: IncidentStatus
    ) {
        self.kind = kind
        self.usersLost = usersLost
        self.reputationDelta = reputationDelta
        self.bugsLeft = bugsLeft
        self.statementID = statementID
        self.status = status
    }
}
