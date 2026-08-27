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
public enum StaffEventKind: String, Codable, Equatable, Sendable, CaseIterable {
    case familyEmergency, rivalOfferRumor
}

/// The founder's answer to a staff event.
public enum StaffEventChoice: String, Codable, Equatable, Sendable {
    /// Costs cash, lifts morale and loyalty (a family emergency also
    /// clears the employee's assignment for the time off).
    case supportive
    /// Free, dents loyalty. Also the auto-resolution past the deadline.
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
