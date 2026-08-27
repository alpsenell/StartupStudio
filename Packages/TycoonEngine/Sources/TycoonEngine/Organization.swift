import Foundation

/// What an employee was hired to do. Builder roles shape how their daily
/// output lands across the design / code / polish pools (see
/// `BalanceConfig.CompanyBalance.roleYields`); support roles form
/// departments that grant company-wide effects.
public enum EmployeeRole: String, Codable, Equatable, Sendable, CaseIterable {
    case founder, frontend, backend, designer, qa, marketer, lawyer, hr, ops

    public var displayName: String {
        switch self {
        case .founder: "Founder"
        case .frontend: "Frontend Dev"
        case .backend: "Backend Dev"
        case .designer: "Designer"
        case .qa: "QA Engineer"
        case .marketer: "Marketer"
        case .lawyer: "Lawyer"
        case .hr: "HR Manager"
        case .ops: "Ops Manager"
        }
    }

    /// Whether the role's output lands on products and contracts at full
    /// role yield. Non-builders still contribute a reduced trickle when
    /// assigned to build work.
    public var isBuilder: Bool {
        switch self {
        case .founder, .frontend, .backend, .designer, .qa: true
        case .marketer, .lawyer, .hr, .ops: false
        }
    }

    /// The department this role staffs, if any.
    public var department: Department? {
        switch self {
        case .lawyer: .legal
        case .hr: .hr
        case .ops: .ops
        case .founder, .frontend, .backend, .designer, .qa, .marketer: nil
        }
    }

    /// The skill a candidate of this role leans into at the hiring roll
    /// (nil: a flat roll).
    var primarySkill: TrainableSkill? {
        switch self {
        case .frontend, .backend, .qa: .coding
        case .designer: .design
        case .marketer: .marketing
        case .founder, .lawyer, .hr, .ops: nil
        }
    }

    /// The role a pre-roles save is read as: the founder flag wins, then
    /// the stronger of coding and design.
    static func inferred(isFounder: Bool, skills: SkillSet) -> EmployeeRole {
        if isFounder { return .founder }
        return skills.coding >= skills.design ? .backend : .designer
    }
}

/// A department exists on any day at least one employee holds a role that
/// staffs it (`GameState.activeDepartments`); it dissolves the moment the
/// last one leaves.
public enum Department: String, Codable, Equatable, Sendable, CaseIterable {
    case legal, hr, ops

    public var displayName: String {
        switch self {
        case .legal: "Legal"
        case .hr: "People & HR"
        case .ops: "Operations"
        }
    }
}

/// A one-off office improvement: bought for cash, billed weekly, and kept
/// across office upgrades.
public enum Amenity: String, Codable, Equatable, Sendable, CaseIterable {
    case gameRoom, cafeteria, shuttle, gym

    public var displayName: String {
        switch self {
        case .gameRoom: "Game Room"
        case .cafeteria: "Cafeteria"
        case .shuttle: "Shuttle Service"
        case .gym: "Gym"
        }
    }
}
