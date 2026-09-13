import Foundation
import TycoonContent

/// The people who are already in the founder's life: a partner, and a team
/// that can be more than payroll.
///
/// The relationships meter was never enough to carry either of these. It
/// is one number that a night out with friends refills, so a founder could
/// stay married for two years without once seeing their partner, and a
/// team could like their job while barely knowing the person who hired
/// them. This system adds the two things the meter cannot say:
///
/// - **Affection.** How the partner feels about *this founder*, as opposed
///   to how the founder's week went. It falls on its own, falls faster
///   once `neglectDays` have gone by with no contact, and only the
///   founder's own time brings it back. Low affection drains the
///   relationships meter, which is what eventually ends things — so a
///   breakup now has a cause the player can watch coming, and one warning
///   (`.partnerDrifting`) before it lands.
/// - **Bond.** How close each employee is to the founder personally. Grown
///   by the founder spending their own time (a coffee, a one-on-one, an
///   evening out, an afternoon teaching them something), decayed by being
///   ignored, and worth output, morale and loyalty when it is there.
///
/// Runs after `SocialSystem` so it sees the post-quit roster and the
/// loyalty that day's drift settled on. Draws nothing.
enum RelationshipSystem {
    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        var events: [GameEvent] = []
        events.append(contentsOf: driftAffection(&state, balance))
        driftBonds(&state, balance)
        // MARK: K7 (partner and diary)
        // The partner on payroll: the breakup that no path caught is still
        // a resignation, and their pay comes home weekly. Then the
        // launch-week birthday's answer, read the way `ChildhoodSystem`
        // reads the ordinary one's.
        if state.life.family.partnerEmployeeID != nil {
            if state.life.family.stage == .single {
                events.append(contentsOf: partnerLeavesPayroll(state: &state, balance: balance))
            }
            runPartnerWeek(&state)
        }
        DiaryRoadmap.resolveLaunchBirthday(&state, balance)
        // MARK: end K7
        // MARK: T1 (exits and joins)
        // The morning after the founder fired their partner: with cause,
        // the rest of the affection and a bag by the door. Returns on its
        // first line on every run that never did — every bot.
        events.append(contentsOf: partnerFiringMorning(&state, balance, content))
        // MARK: end T1
        return events
    }

    // MARK: - The partner

    /// Affection slides every day the founder does nothing about it, and
    /// slides faster once `neglectDays` have passed. It feeds the
    /// relationships meter both ways: a partner who is happy is a reason
    /// the founder is, and one who is not is a weight.
    private static func driftAffection(
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) -> [GameEvent] {
        let config = balance.relationships
        guard state.life.family.stage != .single else { return [] }

        let sinceContact = state.day - (state.life.family.lastPartnerDay ?? state.life.family.stageSinceDay)
        var drift = config.affectionDrift
        if config.neglectDays > 0, sinceContact >= config.neglectDays {
            drift += config.neglectDrift
        }
        // A founder who is never home is not there in the evenings either.
        // MARK: K6 (home and rooms) — not on the family holiday: the partner
        // is on it too (merge glue; K7's follow-up).
        if state.life.isAway(day: state.day), state.life.awayReason != HomeSystem.familyHolidayReason {
            drift += config.affectionDrift
        }
        // MARK: end K6
        // MARK: K7 (partner and diary)
        // A partner who works here reads the office: crunch, a launch, a
        // burnout. Exactly 0 unless they are on payroll.
        drift += partnerOfficeAffectionDrift(state, balance)
        // MARK: end K7

        let before = state.life.family.affection
        state.life.family.affection = min(100, max(0, before + drift))

        // Affection above the midpoint pays into the relationships meter,
        // below it drains — the same shape as every other founder factor.
        state.life.meters.apply(
            relationships: (state.life.family.affection - 50) * config.affectionRelationshipFactor
        )

        // One warning, on the way down through the line, and only once per
        // crossing: a partner tells you before they leave.
        let warningLine = balance.life.breakupThreshold + 15
        if before >= warningLine, state.life.family.affection < warningLine {
            // MARK: Iteration 9 — L1 (phone)
            // The warning arrives as a text, because that is how it would.
            PhoneMirror.partnerWarning(state: &state)
            // MARK: end L1
            return [.partnerDrifting(affection: state.life.family.affection, day: state.day)]
        }
        return []
    }

    // MARK: - The team

    /// A bond nobody tends fades. The founder's own bond is not a thing.
    private static func driftBonds(_ state: inout GameState, _ balance: BalanceConfig) {
        let config = balance.relationships
        for index in state.employees.indices where !state.employees[index].isFounder {
            if config.bondDecayPerDay > 0 {
                state.employees[index].founderBond = max(
                    0, state.employees[index].founderBond - config.bondDecayPerDay
                )
            }
            // Somebody the founder is close to is somebody who stays.
            let bond = state.employees[index].founderBond
            if config.bondLoyaltyPerDay > 0, bond > 50 {
                state.employees[index].loyalty = min(
                    100,
                    state.employees[index].loyalty + (bond - 50) / 50 * config.bondLoyaltyPerDay
                )
            }
        }
    }

    // MARK: - Partner actions

    /// Spends the founder's own evening — and their own money — on their
    /// partner. Gates: there is a partner, the founder is around, the
    /// activity's cooldown has run out, and the wallet covers it (a phone
    /// call being free is always affordable).
    ///
    /// Affection gains scale with the founder's conversation attribute:
    /// the same dinner goes further when you are actually present at it.
    static func spendTimeWithPartner(
        _ activity: PartnerActivity,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        let config = balance.relationships
        guard let def = config.partnerActivity(activity),
              state.life.family.stage != .single,
              !state.life.isAway(day: state.day),
              state.hasEveningFree(balance),
              def.cost == 0 || state.life.wallet >= def.cost
        else { return [] }
        if let last = state.life.family.partnerCooldowns[activity.rawValue],
           state.day - last < def.cooldownDays { return [] }

        let charm = state.founderCharmFactor(balance)
        let gained = def.affection * charm
        state.life.family.affection = min(100, state.life.family.affection + gained)
        state.life.family.partnerCooldowns[activity.rawValue] = state.day
        state.life.family.lastPartnerDay = state.day
        state.life.wallet -= def.cost
        state.life.meters.apply(
            energy: def.energy, mood: def.mood, relationships: def.relationships
        )
        state.economy.lonelySinceDay = nil
        state.spendEvening(balance)
        FounderSystem.practice(.conversation, multiplier: 0.5, state: &state, balance: balance)

        return [.partnerTime(
            activity: activity, affection: state.life.family.affection, day: state.day
        )]
    }

    /// Why a partner activity would be refused, or `nil`.
    static func partnerBlocker(
        _ activity: PartnerActivity,
        state: GameState,
        balance: BalanceConfig
    ) -> String? {
        guard let def = balance.relationships.partnerActivity(activity) else { return "Not available" }
        if state.life.family.stage == .single { return "You're not seeing anyone" }
        if state.life.isAway(day: state.day) { return "You're away" }
        if let reason = state.eveningBlocker(balance) { return reason }
        if let last = state.life.family.partnerCooldowns[activity.rawValue] {
            let left = def.cooldownDays - (state.day - last)
            if left > 0 { return "Again in \(left) day\(left == 1 ? "" : "s")" }
        }
        if def.cost > 0, state.life.wallet < def.cost {
            return "Need \(def.cost - state.life.wallet) more"
        }
        return nil
    }

    // MARK: - Team actions

    /// An evening out with somebody on the team, on the founder rather
    /// than on the company. Bigger than a coffee, and it is the founder's
    /// own money and their own social battery — so it pays their
    /// relationships meter too.
    static func hangOut(
        employeeID: UUID,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        let config = balance.relationships
        let def = config.hangOut
        guard let index = state.employees.firstIndex(where: { $0.id == employeeID }),
              !state.employees[index].isFounder,
              !state.life.isAway(day: state.day),
              state.hasEveningFree(balance),
              def.cost == 0 || state.life.wallet >= def.cost
        else { return [] }
        if let last = state.employees[index].lastSocialDay,
           state.day - last < balance.social.socialCooldownDays { return [] }

        let charm = state.founderCharmFactor(balance)
        state.employees[index].founderBond = min(
            100, state.employees[index].founderBond + config.bondPerSocialAction * 2 * charm
        )
        state.employees[index].morale = min(
            100, state.employees[index].morale + balance.social.coffeeMorale * 2
        )
        state.employees[index].loyalty = min(
            100, state.employees[index].loyalty + balance.social.coffeeLoyalty * 2
        )
        state.employees[index].lastSocialDay = state.day
        state.life.wallet -= def.cost
        state.life.meters.apply(
            energy: def.energy, mood: def.mood, relationships: def.relationships
        )
        state.economy.lonelySinceDay = nil
        state.spendEvening(balance)
        FounderSystem.practice(.conversation, multiplier: 0.5, state: &state, balance: balance)
        return [.hungOutWith(employeeID: employeeID, day: state.day)]
    }

    /// The founder spends an afternoon teaching somebody something. Costs
    /// the founder's energy, not the company's cash, and what lands scales
    /// with the founder's own technical and leadership — you cannot teach
    /// what you do not know.
    static func mentor(
        employeeID: UUID,
        skill: TrainableSkill,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        let config = balance.relationships
        guard let index = state.employees.firstIndex(where: { $0.id == employeeID }),
              !state.employees[index].isFounder,
              !state.life.isAway(day: state.day),
              state.hasEveningFree(balance)
        else { return [] }
        if let last = state.employees[index].lastMentoredDay,
           state.day - last < config.mentorCooldownDays { return [] }

        let founder = state.life.skills
        // Technical carries a coding lesson; market sense carries a
        // marketing one; leadership carries all three, because half of
        // teaching is not the subject.
        let subject = switch skill {
        case .coding: founder.technical
        case .design: (founder.technical + founder.marketKnowledge) / 2
        case .marketing: founder.marketKnowledge
        }
        let competence = (subject + founder.leadership) / 200
        let gain = config.mentorSkillGain * (0.4 + competence)

        var skills = state.employees[index].skills
        switch skill {
        case .coding: skills.coding = min(100, skills.coding + gain)
        case .design: skills.design = min(100, skills.design + gain)
        case .marketing: skills.marketing = min(100, skills.marketing + gain)
        }
        state.employees[index].skills = skills
        state.employees[index].founderBond = min(
            100, state.employees[index].founderBond + config.bondPerSocialAction
        )
        state.employees[index].morale = min(100, state.employees[index].morale + 3)
        state.employees[index].lastMentoredDay = state.day
        // Being taught is being invested in.
        state.economy.lastRecognitionDay[employeeID] = state.day
        state.life.meters.apply(energy: -config.mentorEnergyCost)
        state.spendEvening(balance)
        FounderSystem.practice(.leadership, state: &state, balance: balance)

        return [.employeeMentored(employeeID: employeeID, skill: skill, day: state.day)]
    }

    /// Why a hang-out would be refused, or `nil`.
    static func hangOutBlocker(
        employeeID: UUID,
        state: GameState,
        balance: BalanceConfig
    ) -> String? {
        let def = balance.relationships.hangOut
        guard let employee = state.employees.first(where: { $0.id == employeeID }),
              !employee.isFounder
        else { return "Not available" }
        if state.life.isAway(day: state.day) { return "You're away" }
        if let reason = state.eveningBlocker(balance) { return reason }
        if let last = employee.lastSocialDay {
            let left = balance.social.socialCooldownDays - (state.day - last)
            if left > 0 { return "Again in \(left) day\(left == 1 ? "" : "s")" }
        }
        if def.cost > 0, state.life.wallet < def.cost {
            return "Need \(def.cost - state.life.wallet) more"
        }
        return nil
    }

    /// Why mentoring would be refused, or `nil`.
    static func mentorBlocker(
        employeeID: UUID,
        state: GameState,
        balance: BalanceConfig
    ) -> String? {
        guard let employee = state.employees.first(where: { $0.id == employeeID }),
              !employee.isFounder
        else { return "Not available" }
        if state.life.isAway(day: state.day) { return "You're away" }
        if let reason = state.eveningBlocker(balance) { return reason }
        if let last = employee.lastMentoredDay {
            let left = balance.relationships.mentorCooldownDays - (state.day - last)
            if left > 0 { return "Again in \(left) day\(left == 1 ? "" : "s")" }
        }
        return nil
    }
}
