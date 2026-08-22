import Foundation

/// The three trainable skills, each 0-100.
public struct SkillSet: Codable, Equatable, Sendable {
    public var coding: Double
    public var design: Double
    public var marketing: Double

    /// Sum of all three skills (drives candidate salaries).
    public var total: Double { coding + design + marketing }

    public init(coding: Double, design: Double, marketing: Double) {
        self.coding = coding
        self.design = design
        self.marketing = marketing
    }
}

/// What an employee spends their day on.
public enum Assignment: Codable, Equatable, Sendable {
    case idle
    /// The product being built (only valid while it's in development; a
    /// daily sweep resets stale product assignments to `.idle`).
    case product(UUID)
    /// Generates research points every day.
    case research
    /// An accepted contract being worked (only valid while the job is
    /// active; the daily sweep resets stale contract assignments to `.idle`).
    case contract(UUID)
}

/// A person on payroll. The founder is a regular employee with salary 0 who
/// can never be fired.
public struct Employee: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var skills: SkillSet
    /// Founder: 0.
    public var weeklySalary: Int
    public var assignment: Assignment
    public var isFounder: Bool
    public var hiredDay: Int
    /// Drives the pixel-art look; derived from `GameState.rng` at creation.
    public var appearanceSeed: UInt64

    public init(
        id: UUID,
        name: String,
        skills: SkillSet,
        weeklySalary: Int,
        assignment: Assignment,
        isFounder: Bool,
        hiredDay: Int,
        appearanceSeed: UInt64
    ) {
        self.id = id
        self.name = name
        self.skills = skills
        self.weeklySalary = weeklySalary
        self.assignment = assignment
        self.isFounder = isFounder
        self.hiredDay = hiredDay
        self.appearanceSeed = appearanceSeed
    }
}

/// Someone in the hiring pool, waiting for an offer. Hiring carries every
/// field (including the id) over into an `Employee`.
public struct Candidate: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var skills: SkillSet
    public var weeklySalary: Int
    public var appearanceSeed: UInt64

    public init(
        id: UUID,
        name: String,
        skills: SkillSet,
        weeklySalary: Int,
        appearanceSeed: UInt64
    ) {
        self.id = id
        self.name = name
        self.skills = skills
        self.weeklySalary = weeklySalary
        self.appearanceSeed = appearanceSeed
    }
}
