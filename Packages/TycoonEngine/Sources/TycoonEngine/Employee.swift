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
    /// Paying down a `Codebase`'s technical debt. Produces no design, no
    /// code, no polish, no hype, no research and no revenue — the only
    /// thing it moves is a number that makes everything built on that
    /// codebase better. The payload is the `Codebase.id`; the daily sweep
    /// clears the assignment if that codebase is gone.
    case refactor(String)
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
    /// `TraitEffects`.
    ///
    /// Derived from `appearanceSeed` at creation — see the initializer —
    /// so the same face always has the same personality and no RNG stream
    /// is consumed. A save written before traits existed decodes with none
    /// and gets the same derivation on the way in, which is why an old run
    /// picks up traits without any migration.
    public var traits: [String]
    /// 0...100: how close this person is to the *founder*, as opposed to
    /// how they feel about the job. Grown by the founder's own time
    /// (coffee, a one-on-one, a hang-out, being mentored) and decayed by
    /// being ignored. A strong bond is worth output, morale and staying
    /// put when a rival calls. The founder's own is unused.
    public var founderBond: Double
    /// The last day the founder mentored this person (cooldown).
    public var lastMentoredDay: Int?
    /// Signed the incorporation papers beside the founder (WS-H, the
    /// co-founded origin). Owns a slice of the company that
    /// `InvestorState.equityRemaining` already accounts for, works for
    /// equity until the office can pay them, and can be fired like anyone
    /// else — the slice stays gone. Saves from before origins decode
    /// `false`.
    public var isCofounder: Bool
    // MARK: K3 (the ladder)
    /// The day the founder *promoted* this person to lead, or `nil` for
    /// anyone who is not a lead or walked in the door as one (a candidate
    /// with skills ≥ 210 is a lead at hire). Only a promoted lead runs a
    /// room: see `GameState.ladderCrowdingFactor`. No bot promotes, so a
    /// default-path roster never carries one.
    public var leadSinceDay: Int?
    /// Percentage points of the company granted as options (K3), 0 for
    /// everyone who was never granted.
    public var grantedEquity: Double
    /// The day of the grant; vesting counts from it.
    public var grantDay: Int?
    /// What they were paid the day before the grant's pay cut. The
    /// fairness read uses it: they took the cut, they did not lose a
    /// grievance over it.
    public var salaryBeforeGrant: Int?
    // MARK: end K3
    // MARK: T6 (away)
    /// Iteration 17 — T6: the person is away from the desk (a course, a
    /// holiday) while `day < awayUntilDay`: no points, no research, no
    /// growth, not counted for crowding or a lead's span. `nil` is "at
    /// their desk", which is every save written before this and every
    /// person nobody sent anywhere; not encoded then.
    public var awayUntilDay: Int? = nil
    /// Why, while `awayUntilDay` is set.
    public var awayReason: EmployeeAway? = nil
    // MARK: end T6

    /// `role` defaults to the pre-roles inference (founder, else the
    /// stronger of coding and design) so callers that predate roles keep
    /// building the same employees.
    ///
    /// `traits` left empty is *derived* from `appearanceSeed` rather than
    /// stored empty: every caller (hiring, an absorbed acquisition, a
    /// decoded save) gets a person with a personality without having to
    /// know about traits. The founder is the exception — their character
    /// is their archetype, and giving them traits on top would quietly
    /// move every founder-output number in the balance.
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
        traits: [String] = [],
        founderBond: Double = 0,
        lastMentoredDay: Int? = nil,
        isCofounder: Bool = false,
        // MARK: K3 (the ladder)
        leadSinceDay: Int? = nil,
        grantedEquity: Double = 0,
        grantDay: Int? = nil,
        salaryBeforeGrant: Int? = nil
        // MARK: end K3
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
        self.founderBond = founderBond
        self.lastMentoredDay = lastMentoredDay
        self.isCofounder = isCofounder
        // MARK: K3 (the ladder)
        self.leadSinceDay = leadSinceDay
        self.grantedEquity = grantedEquity
        self.grantDay = grantDay
        self.salaryBeforeGrant = salaryBeforeGrant
        // MARK: end K3
        self.role = role ?? .inferred(isFounder: isFounder, skills: skills)
        self.traits = if !traits.isEmpty || isFounder {
            traits
        } else {
            TraitEffects.derivedTraitIDs(appearanceSeed: appearanceSeed)
        }
    }

    /// Output multiplier from morale, seniority and how close this person
    /// is to the founder (the founder's own output is
    /// scaled by the life system instead and always reads 1 here).
    public func performanceMultiplier(balance: BalanceConfig) -> Double {
        guard !isFounder else { return 1 }
        let staff = balance.staff
        let moraleFactor = min(staff.performanceMax, max(staff.performanceMin,
            1 + (morale - staff.moraleNeutral) * staff.performancePerMoralePoint
        ))
        // People do their best work for someone they'd go to the wall for.
        // Zero-valued in a balance without the relationships block, which
        // is exactly the pre-bond output.
        let bondBonus = 1 + founderBond / 100 * balance.relationships.bondOutputFactor
        return moraleFactor * (1 + staff.levelOutputBonus * Double(level.rank)) * bondBonus
    }
}

// MARK: - Codable

// Hand-written decode so saves written before morale/seniority/roles/traits
// existed keep loading: the new keys decode as optional with fresh-hire
// defaults, a missing role is inferred from the founder flag and skills, and
// missing traits are backfilled from the appearance seed by the initializer
// (a pure derivation — the same save always decodes to the same people).
extension Employee {
    private enum CodingKeys: String, CodingKey {
        case id, name, skills, weeklySalary, assignment, isFounder, hiredDay
        case appearanceSeed, morale, level, lowMoraleStreakDays, lastPraisedDay, lastTrainedDay
        case loyalty, lastSocialDay, role, traits, founderBond, lastMentoredDay
        case isCofounder
        // MARK: K3 (the ladder)
        case leadSinceDay, grantedEquity, grantDay, salaryBeforeGrant
        // MARK: end K3
        // MARK: T6 (away)
        case awayUntilDay, awayReason
        // MARK: end T6
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
            traits: try container.decodeIfPresent([String].self, forKey: .traits) ?? [],
            founderBond: try container.decodeIfPresent(Double.self, forKey: .founderBond) ?? 0,
            lastMentoredDay: try container.decodeIfPresent(Int.self, forKey: .lastMentoredDay),
            isCofounder: try container.decodeIfPresent(Bool.self, forKey: .isCofounder) ?? false,
            // MARK: K3 (the ladder)
            leadSinceDay: try container.decodeIfPresent(Int.self, forKey: .leadSinceDay),
            grantedEquity: try container.decodeIfPresent(Double.self, forKey: .grantedEquity) ?? 0,
            grantDay: try container.decodeIfPresent(Int.self, forKey: .grantDay),
            salaryBeforeGrant: try container.decodeIfPresent(Int.self, forKey: .salaryBeforeGrant)
            // MARK: end K3
        )
        // MARK: T6 (away) — absent keys decode as "at their desk".
        awayUntilDay = try container.decodeIfPresent(Int.self, forKey: .awayUntilDay)
        awayReason = try container.decodeIfPresent(EmployeeAway.self, forKey: .awayReason)
        // MARK: end T6
    }

    // Hand-written encode so `isCofounder` is only written when it is
    // true: a roster with no co-founder encodes byte-for-byte as it did
    // before origins existed, which is what lets a garage save be compared
    // against one written by the scaffold.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(skills, forKey: .skills)
        try container.encode(weeklySalary, forKey: .weeklySalary)
        try container.encode(assignment, forKey: .assignment)
        try container.encode(isFounder, forKey: .isFounder)
        try container.encode(hiredDay, forKey: .hiredDay)
        try container.encode(appearanceSeed, forKey: .appearanceSeed)
        try container.encode(morale, forKey: .morale)
        try container.encode(level, forKey: .level)
        try container.encode(lowMoraleStreakDays, forKey: .lowMoraleStreakDays)
        try container.encodeIfPresent(lastPraisedDay, forKey: .lastPraisedDay)
        try container.encodeIfPresent(lastTrainedDay, forKey: .lastTrainedDay)
        try container.encode(loyalty, forKey: .loyalty)
        try container.encodeIfPresent(lastSocialDay, forKey: .lastSocialDay)
        try container.encode(role, forKey: .role)
        try container.encode(traits, forKey: .traits)
        try container.encode(founderBond, forKey: .founderBond)
        try container.encodeIfPresent(lastMentoredDay, forKey: .lastMentoredDay)
        if isCofounder {
            try container.encode(true, forKey: .isCofounder)
        }
        // MARK: K3 (the ladder)
        // Written only when set: a roster nobody promoted or granted
        // encodes byte-for-byte as it did before the ladder.
        try container.encodeIfPresent(leadSinceDay, forKey: .leadSinceDay)
        if grantedEquity != 0 {
            try container.encode(grantedEquity, forKey: .grantedEquity)
        }
        try container.encodeIfPresent(grantDay, forKey: .grantDay)
        try container.encodeIfPresent(salaryBeforeGrant, forKey: .salaryBeforeGrant)
        // MARK: end K3
        // MARK: T6 (away) — written only while somebody is away.
        try container.encodeIfPresent(awayUntilDay, forKey: .awayUntilDay)
        try container.encodeIfPresent(awayReason, forKey: .awayReason)
        // MARK: end T6
    }
}

// MARK: T6 (away)

/// Why a person on payroll is away from the desk (iteration 17, T6).
public enum EmployeeAway: Codable, Equatable, Sendable {
    /// Sent on a course in `TrainableSkill`; back with the boost.
    case course(TrainableSkill)
    /// The holiday rule's ten days, from their hiring anniversary.
    case holiday
}

extension Employee {
    /// Whether this person is away from the desk on `day` (half-open: back
    /// on `awayUntilDay` itself).
    public func isAway(on day: Int) -> Bool {
        guard let awayUntilDay else { return false }
        return day < awayUntilDay
    }
}

// MARK: end T6

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

    /// The traits this candidate would bring, derived from the same seed
    /// the hire will carry — so what the hiring sheet promises is exactly
    /// what walks in the door.
    public var traits: [String] {
        TraitEffects.derivedTraitIDs(appearanceSeed: appearanceSeed)
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
