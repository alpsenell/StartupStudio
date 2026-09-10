import Foundation
import TycoonContent

// MARK: K7 (partner and diary)

/// Iteration 15 — K7. Hire your partner: the marriage now reads the office.
///
/// Built the way `FriendSystem.hire` builds a friend: skills derived from
/// the seed the partner already carries, fair pay, a `Candidate` pushed
/// through `EmployeeSystem.hire`, and the bond seeded from affection. While
/// they are on payroll two things couple the halves:
///
/// - their morale target moves with affection, `(affection − 50) × 0.3`
///   (`EmployeeSystem`'s one marked line reads `partnerMoraleTargetDelta`);
/// - affection moves with the company: crunch pace costs −0.6 a day on top
///   of the schedule's own drift, a launch is +6 the day after, a burnout
///   −8 on the day (`partnerOfficeAffectionDrift`).
///
/// Their salary comes home: the wallet gets it every week, and the
/// household draw (the founder's salary plus theirs) is what
/// `founderPayExcess` holds against the team median. A breakup — chosen,
/// packed into a bag, or the meter's own — is also a resignation, the same
/// day.
///
/// Draws nothing: the skills, the role and the person's id all come from
/// `partnerAppearanceSeed`, which is already in the save. Nothing here
/// runs until `.hirePartner`, which no bot sends.
extension RelationshipSystem {
    // MARK: Hire

    static func hirePartner(state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        guard state.partnerHireBlocker(balance: balance) == nil,
              let seed = state.life.family.partnerAppearanceSeed,
              let name = state.life.family.partnerName,
              let id = PartnerDerivation.personID(state.life.family)
        else { return [] }

        let skills = PartnerDerivation.skills(seed: seed)
        state.candidatePool.append(Candidate(
            id: id,
            name: name,
            skills: skills,
            weeklySalary: PartnerDerivation.ask(skills: skills, balance: balance),
            appearanceSeed: seed,
            role: PartnerDerivation.role(seed: seed)
        ))
        let events = EmployeeSystem.hire(candidateID: id, state: &state, balance: balance)
        guard !events.isEmpty else {
            // Refused at the door: the hiring desk does not quietly gain
            // the founder's partner.
            state.candidatePool.removeAll { $0.id == id }
            return []
        }
        if let index = state.employees.firstIndex(where: { $0.id == id }) {
            state.employees[index].founderBond = min(100, max(0, state.life.family.affection))
        }
        state.life.family.partnerEmployeeID = id
        state.life.phone.post(
            "Fine. But I'm not calling you boss at dinner either.",
            from: .partner, day: state.day
        )
        return events + [.partnerHired(employeeID: id, day: state.day)]
    }

    // MARK: Leave

    /// The relationship is over, and so is the job: the partner leaves the
    /// payroll today, through the ordinary quit path (the roster, the
    /// friendships, an alumni entry), and the alumni entry is closed —
    /// nobody takes that call. Clears `partnerEmployeeID` either way.
    static func partnerLeavesPayroll(state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        guard let id = state.life.family.partnerEmployeeID else { return [] }
        state.life.family.partnerEmployeeID = nil
        guard let index = state.employees.firstIndex(where: { $0.id == id && !$0.isFounder })
        else { return [] }

        let employee = state.employees.remove(at: index)
        state.economy.lastRecognitionDay[id] = nil
        if state.economy.pendingResignation?.employeeID == id {
            state.economy.pendingResignation = nil
        }
        var events: [GameEvent] = [.employeeQuit(employeeID: id, name: employee.name, day: state.day)]
        events.append(contentsOf: SocialSystem.friendDeparted(id, state: &state, balance: balance))
        events.append(contentsOf: NetworkingSystem.departed(
            employee, reason: .quit, state: &state, balance: balance
        ))
        if let contact = state.networking.contacts.firstIndex(where: { $0.id == id }) {
            state.networking.contacts[contact].outcome = .lost
            state.networking.contacts[contact].rapport = 0
        }
        events.append(.partnerResigned(employeeID: id, name: employee.name, day: state.day))
        return events
    }

    // MARK: The daily couplings

    /// Affection per day from the office, on top of the ordinary drift:
    /// crunch, a launch yesterday, a burnout today. Exactly 0 unless the
    /// partner is on payroll.
    static func partnerOfficeAffectionDrift(_ state: GameState, _ balance: BalanceConfig) -> Double {
        guard state.partnerOnPayroll != nil else { return 0 }
        let config = balance.partner
        var drift = state.partnerCrunchAffectionPerDay(balance: balance)
        let launchedYesterday = state.products.contains {
            if case .released(let info) = $0.stage { info.launchDay == state.day - 1 } else { false }
        }
        if launchedYesterday { drift += config.shipAffection }
        if state.economy.burnoutDays.contains(state.day) { drift += config.burnoutAffection }
        return drift
    }

    /// The weekly half of the coupling: the partner's pay comes home, and
    /// a partner who left the job but not the founder stops being tracked
    /// as on payroll only when the relationship ends.
    static func runPartnerWeek(_ state: inout GameState) {
        guard state.day % GameState.daysPerWeek == 0,
              let partner = state.partnerOnPayroll
        else { return }
        state.life.wallet += partner.weeklySalary
    }

    /// Called from `LifeSystem` right after the thresholds, so a breakup
    /// the relationships meter caused is a resignation the same day, and
    /// the doctor's letter reads the health the day's drift left.
    static func afterThresholds(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        var events: [GameEvent] = []
        if state.life.family.partnerEmployeeID != nil, state.life.family.stage == .single {
            events.append(contentsOf: partnerLeavesPayroll(state: &state, balance: balance))
        }
        events.append(contentsOf: DoctorLetter.check(&state, balance, content))
        return events
    }
}

// MARK: - Derivation

/// Everything the hire needs that is not already in the save, derived from
/// the partner's stored `partnerAppearanceSeed` — the `Friend.derivedSkills`
/// shape, so the row on the card and the person who walks in are the same.
public enum PartnerDerivation {
    /// The id the partner has as an employee and as a contact: the address
    /// book's id when they came from it, else one derived from the seed.
    public static func personID(_ family: FamilyState) -> UUID? {
        if let id = family.partnerContactID { return id }
        return family.partnerAppearanceSeed.map(personID(seed:))
    }

    /// A stable id from the seed alone. Not a draw: the same seed names the
    /// same person every replay.
    public static func personID(seed: UInt64) -> UUID {
        let a = seed
        let b = seed ^ 0x4B37_5041_5254_4E52 // "K7PARTNR"
        func byte(_ word: UInt64, _ index: Int) -> UInt8 { UInt8((word >> (8 * UInt64(index))) & 0xFF) }
        return UUID(uuid: (
            byte(a, 0), byte(a, 1), byte(a, 2), byte(a, 3),
            byte(a, 4), byte(a, 5), (byte(a, 6) & 0x0F) | 0x40, byte(a, 7),
            (byte(b, 0) & 0x3F) | 0x80, byte(b, 1), byte(b, 2), byte(b, 3),
            byte(b, 4), byte(b, 5), byte(b, 6), byte(b, 7)
        ))
    }

    public static func role(seed: UInt64) -> EmployeeRole {
        let roles: [EmployeeRole] = [.backend, .designer, .marketer, .frontend, .ops]
        return roles[Int((seed >> 28) % UInt64(roles.count))]
    }

    public static func skills(seed: UInt64) -> SkillSet {
        func roll(_ shift: UInt64) -> Double { 30 + Double((seed >> shift) % 40) }
        return switch role(seed: seed) {
        case .backend, .frontend: SkillSet(coding: roll(4) + 25, design: roll(12), marketing: roll(20))
        case .designer: SkillSet(coding: roll(4), design: roll(12) + 25, marketing: roll(20))
        default: SkillSet(coding: roll(4), design: roll(12), marketing: roll(20) + 25)
        }
    }

    /// Fair pay for those skills, the way a friend's hire is priced.
    public static func ask(skills: SkillSet, balance: BalanceConfig) -> Int {
        Int((Double(balance.salaryBase) + balance.salaryPerSkillPoint * skills.total).rounded())
    }

    /// What they would be in an address book.
    public static func archetype(seed: UInt64) -> ContactArchetype {
        switch role(seed: seed) {
        case .backend, .frontend: .engineer
        case .designer: .designer
        case .marketer: .marketer
        default: .ops
        }
    }
}

// MARK: - Queries

extension GameState {
    /// The partner, if they are on the payroll right now.
    public var partnerOnPayroll: Employee? {
        guard let id = life.family.partnerEmployeeID else { return nil }
        return employees.first { $0.id == id && !$0.isFounder }
    }

    /// Why `.hirePartner` would be refused, or `nil`.
    public func partnerHireBlocker(balance: BalanceConfig) -> String? {
        let family = life.family
        switch family.stage {
        case .single: return "You're not seeing anyone"
        case .dating: return "Too soon. You've been on four dates"
        default: break
        }
        guard family.partnerAppearanceSeed != nil, family.partnerName != nil else { return "Not available" }
        if partnerOnPayroll != nil { return "Already on the payroll" }
        if life.isAway(day: day) { return "You're away" }
        if headcount >= balance.office(company.officeTier).headcountCap {
            return "No desk free — upgrade the office"
        }
        return nil
    }

    /// What the hire row promises: the role and skills from the seed.
    public var partnerHireProfile: (skills: SkillSet, role: EmployeeRole)? {
        guard let seed = life.family.partnerAppearanceSeed else { return nil }
        return (PartnerDerivation.skills(seed: seed), PartnerDerivation.role(seed: seed))
    }

    /// Their weekly ask, the way a friend's hire is priced.
    public func partnerHireAsk(balance: BalanceConfig) -> Int? {
        guard let seed = life.family.partnerAppearanceSeed else { return nil }
        return PartnerDerivation.ask(skills: PartnerDerivation.skills(seed: seed), balance: balance)
    }

    /// Morale-target points affection is worth to this employee: nonzero
    /// only for the partner on payroll. `EmployeeSystem` adds it to the
    /// target; the partner card prints it.
    public func partnerMoraleTargetDelta(for employee: Employee, balance: BalanceConfig) -> Double {
        guard employee.id == life.family.partnerEmployeeID, !employee.isFounder,
              life.family.stage != .single
        else { return 0 }
        return (life.family.affection - 50) * balance.partner.moraleAffectionFactor
    }

    /// The crunch half of the office drift, for the card's "−0.6 a day:
    /// the office". 0 unless the partner is on payroll and the company is
    /// on crunch.
    public func partnerCrunchAffectionPerDay(balance: BalanceConfig) -> Double {
        guard partnerOnPayroll != nil, economy.workPace == .crunch else { return 0 }
        return balance.partner.crunchAffectionPerDay
    }

    /// The partner's weekly pay while it is household money: 0 otherwise.
    /// `founderPayExcess` adds it to the founder's own draw.
    public var partnerHouseholdDraw: Int {
        partnerOnPayroll?.weeklySalary ?? 0
    }
}

// MARK: end K7
