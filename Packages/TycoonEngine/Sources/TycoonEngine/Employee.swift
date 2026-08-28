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
    /// Keeping a released product alive: fixing the bugs players find in
    /// the wild and holding down subscription churn. Only valid while the
    /// product is on the market; the daily sweep clears it otherwise.
    case support(UUID)
}

/// Seniority ladder for hired staff. Levels raise output and what the
/// employee considers fair pay.
public enum SeniorityLevel: String, Codable, Equatable, Sendable, CaseIterable {
    case junior, mid, senior, lead

    public var displayName: String {
        switch self {
        case .junior: "Junior"
        case .mid: "Mid"
        case .senior: "Senior"
        case .lead: "Lead"
        }
    }

    /// Position on the junior → lead ladder.
    public var rank: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    /// One rung up, `nil` at the top.
    public var next: SeniorityLevel? {
        let ladder = Self.allCases
        let index = ladder.index(after: rank)
        return index < ladder.endIndex ? ladder[index] : nil
    }

    /// One rung down, `nil` at the bottom.
    public var previous: SeniorityLevel? {
        rank > 0 ? Self.allCases[rank - 1] : nil
    }

    /// The level a candidate's total skill roll maps to at hire.
    public static func forSkillTotal(_ total: Double) -> SeniorityLevel {
        switch total {
        case ..<90: .junior
        case ..<150: .mid
        case ..<210: .senior
        default: .lead
        }
    }
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
    /// 0...100; drifts daily toward a target set by pay fairness and the
    /// office, and jumps on praise, raises, cuts, promotions, demotions.
    public var morale: Double
    public var level: SeniorityLevel
    /// Consecutive days with morale below the quit threshold.
    public var lowMoraleStreakDays: Int
    /// The last day a praise / training action was applied (cooldowns).
    public var lastPraisedDay: Int?
    public var lastTrainedDay: Int?
    /// 0...100 attachment to the company; resists rival poaching and (from
    /// the social system) extends the quit streak. Founder loyalty is unused.
    public var loyalty: Double
    /// The last day a social action (coffee / 1-on-1 / gift) targeted this
    /// employee (shared cooldown).
    public var lastSocialDay: Int?
    /// What they were hired to do; shapes build output and staffs
    /// departments. The founder is always `.founder`.
    public var role: EmployeeRole
    /// Personality tags (`TraitDef.id`s in the content catalog) that shape
    /// output, morale, skill growth and poach resistance through
    /// `TraitEffects`. Empty until WS-F derives them from
    /// `appearanceSeed`; saves written before traits existed decode as
    /// empty too.
    public var traits: [String]

    /// `role` defaults to the pre-roles inference (founder, else the
    /// stronger of coding and design) so callers that predate roles keep
    /// building the same employees.
    public init(
        id: UUID,
        name: String,
        skills: SkillSet,
        weeklySalary: Int,
        assignment: Assignment,
        isFounder: Bool,
        hiredDay: Int,
        appearanceSeed: UInt64,
        morale: Double = 70,
        level: SeniorityLevel = .junior,
        lowMoraleStreakDays: Int = 0,
        lastPraisedDay: Int? = nil,
        lastTrainedDay: Int? = nil,
        loyalty: Double = 50,
        lastSocialDay: Int? = nil,
        role: EmployeeRole? = nil,
        traits: [String] = []
    ) {
        self.id = id
        self.name = name
        self.skills = skills
        self.weeklySalary = weeklySalary
        self.assignment = assignment
        self.isFounder = isFounder
        self.hiredDay = hiredDay
        self.appearanceSeed = appearanceSeed
        self.morale = morale
        self.level = level
        self.lowMoraleStreakDays = lowMoraleStreakDays
        self.lastPraisedDay = lastPraisedDay
        self.lastTrainedDay = lastTrainedDay
        self.loyalty = loyalty
        self.lastSocialDay = lastSocialDay
        self.role = role ?? .inferred(isFounder: isFounder, skills: skills)
        self.traits = traits
    }

    /// Output multiplier from morale and seniority (the founder's output is
    /// scaled by the life system instead and always reads 1 here).
    public func performanceMultiplier(balance: BalanceConfig) -> Double {
        guard !isFounder else { return 1 }
        let staff = balance.staff
        let moraleFactor = min(staff.performanceMax, max(staff.performanceMin,
            1 + (morale - staff.moraleNeutral) * staff.performancePerMoralePoint
        ))
        return moraleFactor * (1 + staff.levelOutputBonus * Double(level.rank))
    }
}

// MARK: - Codable

// Hand-written decode so saves written before morale/seniority/roles/traits
// existed keep loading: the new keys decode as optional with fresh-hire
// defaults, a missing role is inferred from the founder flag and skills, and
// missing traits read as none.
extension Employee {
    private enum CodingKeys: String, CodingKey {
        case id, name, skills, weeklySalary, assignment, isFounder, hiredDay
        case appearanceSeed, morale, level, lowMoraleStreakDays, lastPraisedDay, lastTrainedDay
        case loyalty, lastSocialDay, role, traits
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            skills: try container.decode(SkillSet.self, forKey: .skills),
            weeklySalary: try container.decode(Int.self, forKey: .weeklySalary),
            assignment: try container.decode(Assignment.self, forKey: .assignment),
            isFounder: try container.decode(Bool.self, forKey: .isFounder),
            hiredDay: try container.decode(Int.self, forKey: .hiredDay),
            appearanceSeed: try container.decode(UInt64.self, forKey: .appearanceSeed),
            morale: try container.decodeIfPresent(Double.self, forKey: .morale) ?? 70,
            level: try container.decodeIfPresent(SeniorityLevel.self, forKey: .level) ?? .junior,
            lowMoraleStreakDays: try container.decodeIfPresent(Int.self, forKey: .lowMoraleStreakDays) ?? 0,
            lastPraisedDay: try container.decodeIfPresent(Int.self, forKey: .lastPraisedDay),
            lastTrainedDay: try container.decodeIfPresent(Int.self, forKey: .lastTrainedDay),
            loyalty: try container.decodeIfPresent(Double.self, forKey: .loyalty) ?? 50,
            lastSocialDay: try container.decodeIfPresent(Int.self, forKey: .lastSocialDay),
            role: try container.decodeIfPresent(EmployeeRole.self, forKey: .role),
            traits: try container.decodeIfPresent([String].self, forKey: .traits) ?? []
        )
    }
}

/// Someone in the hiring pool, waiting for an offer. Hiring carries every
/// field (including the id and role) over into an `Employee`.
public struct Candidate: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var skills: SkillSet
    public var weeklySalary: Int
    public var appearanceSeed: UInt64
    /// Rolled at refresh; never `.founder`.
    public var role: EmployeeRole

    /// `role` defaults to the pre-roles inference (the stronger of coding
    /// and design).
    public init(
        id: UUID,
        name: String,
        skills: SkillSet,
        weeklySalary: Int,
        appearanceSeed: UInt64,
        role: EmployeeRole? = nil
    ) {
        self.id = id
        self.name = name
        self.skills = skills
        self.weeklySalary = weeklySalary
        self.appearanceSeed = appearanceSeed
        self.role = role ?? .inferred(isFounder: false, skills: skills)
    }
}

// Hand-written decode so pools saved before roles existed keep loading.
extension Candidate {
    private enum CodingKeys: String, CodingKey {
        case id, name, skills, weeklySalary, appearanceSeed, role
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            skills: try container.decode(SkillSet.self, forKey: .skills),
            weeklySalary: try container.decode(Int.self, forKey: .weeklySalary),
            appearanceSeed: try container.decode(UInt64.self, forKey: .appearanceSeed),
            role: try container.decodeIfPresent(EmployeeRole.self, forKey: .role)
        )
    }
}
