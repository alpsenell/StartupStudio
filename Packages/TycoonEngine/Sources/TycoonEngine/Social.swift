import Foundation

/// A bond between two employees. Canonical: `a.uuidString < b.uuidString`,
/// so a pair exists at most once and encodes deterministically.
public struct Friendship: Codable, Equatable, Sendable {
    public var a: UUID
    public var b: UUID
    /// 0...100, grown by working together, decayed apart.
    public var strength: Double
    public var sinceDay: Int

    public init(a: UUID, b: UUID, strength: Double, sinceDay: Int) {
        // Normalize so callers can pass the pair in any order.
        if a.uuidString <= b.uuidString {
            self.a = a
            self.b = b
        } else {
            self.a = b
            self.b = a
        }
        self.strength = strength
        self.sinceDay = sinceDay
    }

    public func involves(_ id: UUID) -> Bool { a == id || b == id }

    public func other(than id: UUID) -> UUID? {
        if a == id { return b }
        if b == id { return a }
        return nil
    }
}

/// A staff moment that needs the founder's answer.
///
/// Each kind is backed by a `StaffEventDef` in `StaffEvents.json` — the
/// wording, the two answers and what they cost. A kind with no def (or a
/// content catalog with no staff events at all, as in the unit-test
/// catalogs) falls back to the generic numbers in `balance.social`, which
/// is exactly the pre-content behavior.
///
/// Append-only: raw values are persisted inside `StaffEvent`.
public enum StaffEventKind: String, Codable, Equatable, Sendable, CaseIterable {
    case familyEmergency, rivalOfferRumor
    /// They pulled the market data and they are not wrong.
    case raiseRequest
    /// They want to do a different job than the one they were hired for.
    case roleSwitch
    /// Two people who used to be friends are routing around each other.
    case teamConflict
    /// Someone is running on fumes and calling it commitment.
    case burnoutWarning
    /// A side project that is starting to look like a competitor.
    case sideProject
    /// They want the title, and they have a case for it.
    case promotionDemand
    /// A baby, and the question of what your leave policy actually is.
    case parentalLeave
    /// They want to work from somewhere else, permanently.
    case remoteRequest
    /// A complaint that needs a process, not a chat.
    case harassmentComplaint
}

/// The founder's answer to a staff event.
public enum StaffEventChoice: String, Codable, Equatable, Sendable {
    /// The generous answer: usually costs cash, lifts morale and loyalty
    /// (a family emergency also clears the employee's assignment for the
    /// time off).
    case supportive
    /// The firm answer: usually free, dents loyalty. Also what the
    /// deadline picks when the founder never got back to them.
    case strict
    /// The firm answer, made the rule (WS-D): the strict outcome lands and
    /// the kind's strict policy is set, so the next person who asks gets
    /// the same answer without a sheet — the cheap-now, remembered-later
    /// choice. Appended; the deadline never picks it, and a kind with no
    /// policy block treats it as plain `strict`.
    case strictAsPolicy

    /// Whether the answer is the firm one, rule or not.
    public var isStrict: Bool { self != .supportive }
}

/// A pending staff event, stored until answered or auto-resolved.
public struct StaffEvent: Codable, Equatable, Sendable {
    public var employeeID: UUID
    public var kind: StaffEventKind
    public var respondByDay: Int
    /// The `StaffEventDef` id when this is a scheduled second act rather
    /// than a rolled kind (WS-D); `kind` is then the act's parent kind, for
    /// the icon and the feed. Nil for every rolled moment, so saves from
    /// before second acts decode as before.
    public var defID: String?

    public init(employeeID: UUID, kind: StaffEventKind, respondByDay: Int, defID: String? = nil) {
        self.employeeID = employeeID
        self.kind = kind
        self.respondByDay = respondByDay
        self.defID = defID
    }

    /// The definition this moment renders and resolves against.
    public var definitionID: String { defID ?? kind.rawValue }
}

// MARK: - Memory (WS-D)

/// A rule the founder set by answering one person.
///
/// A supportive answer to a policy-shaped kind (one whose def carries a
/// `policy` block) becomes the rule: the next person who brings the same
/// kind is answered by it — the same numbers, a ledger line, no sheet.
/// The strict answer sets no rule unless the founder makes it one. The
/// flag itself lives in `NarrativeState.flags` so content can gate on it;
/// this record is who set it, when, and everyone it has answered for,
/// which is what reversing it costs.
public struct StaffPolicy: Codable, Equatable, Sendable, Identifiable {
    public var id: String { flag }
    public var kind: StaffEventKind
    /// The narrative flag the rule raised (`good_leave_policy`, …).
    public var flag: String
    /// `.supportive` or `.strict`: which of the kind's two answers the
    /// rule gives.
    public var choice: StaffEventChoice
    public var setDay: Int
    /// The person whose question became the rule.
    public var setBy: UUID
    /// Their name, kept so the card still reads after they leave.
    public var setByName: String
    /// Everyone the rule has answered for, the person who set it first.
    public var beneficiaries: [UUID]

    public init(
        kind: StaffEventKind,
        flag: String,
        choice: StaffEventChoice,
        setDay: Int,
        setBy: UUID,
        setByName: String,
        beneficiaries: [UUID]
    ) {
        self.kind = kind
        self.flag = flag
        self.choice = choice
        self.setDay = setDay
        self.setBy = setBy
        self.setByName = setByName
        self.beneficiaries = beneficiaries
    }
}

/// A staff moment answered strictly, remembered by the person who asked —
/// the fact behind "You said no in March" on their manage sheet.
public struct StaffRefusal: Codable, Equatable, Sendable {
    public var employeeID: UUID
    public var kind: StaffEventKind
    public var day: Int
    /// Whether the deadline answered rather than the founder.
    public var automatic: Bool

    public init(employeeID: UUID, kind: StaffEventKind, day: Int, automatic: Bool) {
        self.employeeID = employeeID
        self.kind = kind
        self.day = day
        self.automatic = automatic
    }
}

/// What the staff remember about the founder's answers: the rules those
/// answers became, and the last time each person was told no. Empty in
/// every save written before it existed, and in every pacing run — the
/// bots never answer, so nothing here ever moves the baseline.
public struct StaffMemory: Codable, Equatable, Sendable {
    /// At most one per kind, in the order they were set.
    public var policies: [StaffPolicy]
    /// At most one per employee: the latest.
    public var refusals: [StaffRefusal]

    public init(policies: [StaffPolicy] = [], refusals: [StaffRefusal] = []) {
        self.policies = policies
        self.refusals = refusals
    }

    public static let initial = StaffMemory()

    public var isEmpty: Bool { policies.isEmpty && refusals.isEmpty }

    /// The rule for a kind, if the founder has set one.
    public func policy(for kind: StaffEventKind) -> StaffPolicy? {
        policies.first { $0.kind == kind }
    }

    /// The rule behind a flag, if it is one.
    public func policy(flag: String) -> StaffPolicy? {
        policies.first { $0.flag == flag }
    }

    /// The last strict answer this person got, if any.
    public func refusal(for employeeID: UUID) -> StaffRefusal? {
        refusals.first { $0.employeeID == employeeID }
    }

    /// Records a strict answer, replacing the person's earlier one.
    public mutating func remember(_ refusal: StaffRefusal) {
        refusals.removeAll { $0.employeeID == refusal.employeeID }
        refusals.append(refusal)
    }

    private enum CodingKeys: String, CodingKey {
        case policies, refusals
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            policies: try container.decodeIfPresent([StaffPolicy].self, forKey: .policies) ?? [],
            refusals: try container.decodeIfPresent([StaffRefusal].self, forKey: .refusals) ?? []
        )
    }
}

/// The social action kinds surfaced in events.
public enum SocialActivityKind: String, Codable, Equatable, Sendable {
    case coffee, oneOnOne, gift, teamDinner
}
