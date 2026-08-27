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
}

/// A pending staff event, stored until answered or auto-resolved.
public struct StaffEvent: Codable, Equatable, Sendable {
    public var employeeID: UUID
    public var kind: StaffEventKind
    public var respondByDay: Int

    public init(employeeID: UUID, kind: StaffEventKind, respondByDay: Int) {
        self.employeeID = employeeID
        self.kind = kind
        self.respondByDay = respondByDay
    }
}

/// The social action kinds surfaced in events.
public enum SocialActivityKind: String, Codable, Equatable, Sendable {
    case coffee, oneOnOne, gift, teamDinner
}
