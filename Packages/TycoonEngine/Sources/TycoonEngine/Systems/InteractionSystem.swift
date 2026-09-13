import Foundation
import TycoonContent

// Iteration 11 — N2 owns this file: the people menu's one verb.
//
// Nothing here runs on a tick. Every draw is a player's own tap, taken
// from `socialRNG`, so a run that never opens a menu leaves the stream —
// and therefore the whole save — exactly where the scaffold left it.

/// Numbers that are design rather than balance: none of them can be felt
/// by a pacing bot, because a bot never opens a menu. They live beside the
/// code that uses them, the way `AlumniTuning` and `RivalDepthTuning` do,
/// rather than in `Balance.json`.
public enum InteractionTuning {
    /// How much the founder's conversation attribute, read as a signed
    /// distance from 50, is worth on the roll.
    static let conversationWeight = 0.30
    /// How much the current bar is worth: warm people take things better,
    /// including the bad things.
    static let barWeight = 0.20
    static let minChance = 0.05
    static let maxChance = 0.95
    /// An employee's morale moves with their bond, at this share of it.
    static let employeeMoraleShare = 0.5
    /// A nice thing landing is worth this much mood to the founder.
    static let niceMood = 1.5
    /// A mean thing going wrong costs this much.
    static let meanMood = -2.0
    /// An evening out with somebody moves the founder's own meters too.
    static let eveningRelationships = 3.0
    static let eveningEnergy = -4.0
    static let eveningMood = 3.0
    /// The grudge at which a rival is named the founder's nemesis.
    public static let nemesisGrudge = 25.0
    /// Ids the system does more than arithmetic for.
    static let breakUpID = "breakUp"
    static let affairID = "affair"
    static let disownID = "disown"
    static let fireWithCauseID = "fireWithCause"

    /// The narrative flags this lane raises. They gate every `people_`
    /// life event, which is what keeps the event pool — and so the whole
    /// weighted draw — identical for a run that never meddles.
    public static let meddlerFlag = "people_meddler"
    public static let cruelFlag = "people_cruel"
    public static let affairFlag = "people_affair"
    public static let nemesisFlag = "people_nemesis"
    public static let estrangedFlag = "people_estranged"
}

public enum InteractionSystem {
    // MARK: - The roll

    /// The chance the good line comes back. A pure function of the rule,
    /// the bar and the founder, so the percentage on the button is the
    /// number the roll actually uses.
    static func chance(rule: InteractionRule, bar: Double, state: GameState) -> Double {
        let conversation = state.life.skills.conversation
        let raw = rule.baseChance
            + (conversation - 50) / 100 * InteractionTuning.conversationWeight
            + (bar - 50) / 100 * InteractionTuning.barWeight
        return min(InteractionTuning.maxChance, max(InteractionTuning.minChance, raw))
    }

    // MARK: - Doing it

    /// The founder does something to somebody. Returns the events the
    /// consequence produced — usually none, because the outcome of an
    /// interaction is a line in a phone thread and a bar that moved, not a
    /// headline.
    @discardableResult
    static func perform(
        target: InteractionTarget,
        interactionID: String,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard blocker(
            target: target, interactionID: interactionID,
            state: state, balance: balance, content: content
        ) == nil else { return [] }
        guard let rule = content.interactionRules.first(where: { $0.id == interactionID })
        else { return [] }

        // A friend's row can be opened before the friends were ever rolled
        // (the roster is a pure function of the seed until somebody is
        // called), so write it into state before moving a bond. After the
        // blocker, so a refused row still changes nothing at all.
        if case .friend = target { FriendSystem.materialise(&state, content) }

        let day = state.day
        let bar = state.interactionBar(target, content: content) ?? 50
        let odds = chance(rule: rule, bar: bar, state: state)
        let good = state.socialRNG.nextUniform() < odds

        // Costs first, so a refused wallet cannot be spent twice and the
        // evening is booked before anything reads the budget.
        if rule.cost.spendsEvening { state.spendEvening(balance) }
        let money = rule.cost.walletAmount
        if money > 0 {
            state.life.wallet -= money
        } else if money < 0 && good {
            // Money the founder asked for only arrives if they said yes.
            state.life.wallet -= money
        }

        let deltas = rule.deltas(for: target.kind)
        var delta = good ? deltas.good : deltas.bad
        var events: [GameEvent] = []

        switch interactionID {
        case InteractionTuning.breakUpID:
            events += breakUp(state: &state, balance: balance, content: content)
            delta = 0
        case InteractionTuning.affairID:
            if case .contact(let id) = target { startAffair(contactID: id, state: &state) }
        case InteractionTuning.disownID:
            if case .child(let id) = target { disown(childID: id, state: &state) }
            delta = 0
        case InteractionTuning.fireWithCauseID:
            if case .employee(let id) = target {
                events += fireWithCause(
                    employeeID: id, state: &state, balance: balance
                )
            }
            delta = 0
        default:
            break
        }

        let applied = apply(delta: delta, to: target, state: &state)
        let line = pick(rule: rule, kind: target.kind, good: good, state: &state)
            ?? fallbackLine(rule: rule, good: good)

        // The founder's own meters: a good evening is an evening, a mean
        // thing going wrong sits with you.
        if rule.cost.spendsEvening {
            state.life.meters.apply(
                energy: InteractionTuning.eveningEnergy,
                mood: good ? InteractionTuning.eveningMood : 0,
                relationships: InteractionTuning.eveningRelationships
            )
        } else if rule.group == .nice && good {
            state.life.meters.apply(mood: InteractionTuning.niceMood)
        } else if rule.group == .mean && !good {
            state.life.meters.apply(mood: InteractionTuning.meanMood)
        }

        // The line lands where that person actually talks to you.
        if let counterpart = target.phoneCounterpart {
            state.life.phone.post(line, from: counterpart, day: day, eventID: "people_\(rule.id)")
        }
        if case .child(let id) = target {
            remember(childID: id, line: line, good: good, day: day, state: &state)
        }

        state.interactions.markUsed(target, rule.id, day: day)
        // MARK: J2 (record)
        // People you treated badly give references too. A mean act on
        // somebody on payroll goes on the list the founder's name reads.
        if rule.group == .mean, case .employee = target {
            state.interactions.standingRecordMeanAct(
                day: day, window: balance.founderStanding.nameMeanActWindowDays
            )
        }
        // MARK: end J2
        state.interactions.performedCount += 1
        state.interactions.lastOutcome = InteractionOutcome(
            target: target, interactionID: rule.id, good: good, line: line,
            delta: applied, barLabel: target.kind.barLabel, day: day
        )
        raiseFlags(rule: rule, target: target, state: &state)
        return events
    }

    /// Moves the one bar this target owns and returns what actually landed
    /// after the 0...100 clamp, so the outcome card can say the true
    /// number rather than the intended one.
    @discardableResult
    private static func apply(
        delta: Double, to target: InteractionTarget, state: inout GameState
    ) -> Double {
        guard delta != 0 else { return 0 }
        func moved(_ current: Double) -> Double { clamp(current + delta) - current }

        switch target {
        case .partner:
            let applied = moved(state.life.family.affection)
            state.life.family.affection = clamp(state.life.family.affection + delta)
            return applied
        case .child(let id):
            guard let index = state.life.family.children.firstIndex(where: { $0.id == id })
            else { return 0 }
            let applied = moved(state.life.family.children[index].bond)
            state.life.family.children[index].bond =
                clamp(state.life.family.children[index].bond + delta)
            return applied
        case .friend(let id):
            guard let index = state.life.friends.friends.firstIndex(where: { $0.id == id })
            else { return 0 }
            let applied = moved(state.life.friends.friends[index].bond)
            state.life.friends.friends[index].bond =
                clamp(state.life.friends.friends[index].bond + delta)
            state.life.friends.friends[index].lastContactDay = state.day
            return applied
        case .employee(let id):
            guard let index = state.employees.firstIndex(where: { $0.id == id }) else { return 0 }
            let applied = moved(state.employees[index].founderBond)
            state.employees[index].founderBond =
                clamp(state.employees[index].founderBond + delta)
            // Morale follows the bond at half weight: how the founder
            // treats you is most of how work feels, but not all of it.
            state.employees[index].morale = clamp(
                state.employees[index].morale + delta * InteractionTuning.employeeMoraleShare
            )
            return applied
        case .contact(let id):
            guard let index = state.networking.contacts.firstIndex(where: { $0.id == id })
            else { return 0 }
            let applied = moved(state.networking.contacts[index].rapport)
            state.networking.contacts[index].rapport =
                clamp(state.networking.contacts[index].rapport + delta)
            state.networking.contacts[index].lastMetDay = state.day
            return applied
        case .rival(let id):
            guard let index = state.rivals.rivals.firstIndex(where: { $0.id == id })
            else { return 0 }
            let applied = moved(state.rivals.rivals[index].grudge)
            state.rivals.rivals[index].grudge = clamp(state.rivals.rivals[index].grudge + delta)
            return applied
        }
    }

    private static func clamp(_ value: Double) -> Double { min(100, max(0, value)) }

    /// One line out of the pool for this kind of person, on `socialRNG`.
    private static func pick(
        rule: InteractionRule, kind: InteractionTargetKind, good: Bool, state: inout GameState
    ) -> String? {
        let pool = rule.lines(for: kind, good: good)
        guard !pool.isEmpty else { return nil }
        return pool[state.socialRNG.nextInt(in: 0...(pool.count - 1))]
    }

    /// What a row with no lines for this kind says, so a half-written
    /// catalog still reads as the game rather than as a blank.
    private static func fallbackLine(rule: InteractionRule, good: Bool) -> String {
        good ? "It landed." : "It did not land."
    }

    /// Children keep a ledger, and this goes in it. The kind is this
    /// lane's own tag rather than one of L3's — the row renders from the
    /// note either way.
    private static func remember(
        childID: UUID, line: String, good: Bool, day: Int, state: inout GameState
    ) {
        guard let index = state.life.family.children.firstIndex(where: { $0.id == childID })
        else { return }
        guard state.life.family.children[index].stage(on: day).remembers else { return }
        state.life.family.children[index].memories.append(
            ChildMemory(day: day, kind: good ? "people_warm" : "people_sour", note: line)
        )
        let cap = 12
        let overflow = state.life.family.children[index].memories.count - cap
        if overflow > 0 {
            state.life.family.children[index].memories.removeFirst(overflow)
        }
    }

    private static func raiseFlags(
        rule: InteractionRule, target: InteractionTarget, state: inout GameState
    ) {
        state.narrative.flags.insert(InteractionTuning.meddlerFlag)
        if rule.group == .mean { state.narrative.flags.insert(InteractionTuning.cruelFlag) }
        if rule.id == InteractionTuning.affairID {
            state.narrative.flags.insert(InteractionTuning.affairFlag)
        }
        if rule.id == InteractionTuning.breakUpID || rule.id == InteractionTuning.disownID
            || rule.id == InteractionTuning.fireWithCauseID {
            state.narrative.flags.insert(InteractionTuning.estrangedFlag)
        }
        if state.nemesis != nil { state.narrative.flags.insert(InteractionTuning.nemesisFlag) }
    }

    // MARK: - The big ones

    /// The founder ends it. The same collapse the relationships meter
    /// causes on its own, taken deliberately: the home stays, the children
    /// stay, the diary loses their dates and the mood takes the hit.
    static func breakUp(
        state: inout GameState, balance: BalanceConfig, content: ContentCatalog
    ) -> [GameEvent] {
        guard state.life.family.stage != .single else { return [] }
        let day = state.day
        // MARK: K7 (partner and diary)
        // A partner on payroll leaves the job the day they leave you.
        let resigned = RelationshipSystem.partnerLeavesPayroll(state: &state, balance: balance)
        // MARK: end K7
        state.life.family.stage = .single
        state.life.family.stageSinceDay = day
        state.life.family.partnerName = nil
        state.life.family.partnerAppearanceSeed = nil
        state.life.family.partnerContactID = nil
        state.life.family.affection = 0
        state.life.family.lastPartnerDay = nil
        state.life.family.partnerCooldowns = [:]
        state.life.lowRelationshipStreakDays = 0
        state.life.meters.apply(mood: -balance.life.breakupMoodPenalty)
        FamilyCalendar.partnerLeft(&state, content: content)
        state.narrative.flags.insert(InteractionTuning.estrangedFlag)
        return resigned + [.breakup(day: day)] // K7: the resignation first
    }

    /// A fact with a shelf life. Wave two's family drama reads
    /// `affairContactID`, `affairSinceDay` and `affairDiscoveredDay`; this
    /// lane only starts it.
    private static func startAffair(contactID: UUID, state: inout GameState) {
        guard state.interactions.affairContactID == nil else { return }
        state.interactions.affairContactID = contactID
        state.interactions.affairSinceDay = state.day
        state.interactions.affairDiscoveredDay = nil
    }

    /// A grown child, cut off. They stay on the family card and in the
    /// save — this is a life, not a delete key — but the bond goes to
    /// nothing and the record says why.
    private static func disown(childID: UUID, state: inout GameState) {
        guard !state.interactions.isDisowned(childID) else { return }
        state.interactions.disownedChildIDs.append(childID)
        guard let index = state.life.family.children.firstIndex(where: { $0.id == childID })
        else { return }
        state.life.family.children[index].bond = 0
    }

    /// A firing with a named cause. The ordinary firing runs first — the
    /// roster, the severance and the alumnus entry are all
    /// `EmployeeSystem`'s job — and then the boomerang is closed: however
    /// warm the bond was, somebody dismissed for cause does not come back
    /// through the address book.
    static func fireWithCause(
        employeeID: UUID, state: inout GameState, balance: BalanceConfig
    ) -> [GameEvent] {
        guard state.employees.contains(where: { $0.id == employeeID && !$0.isFounder })
        else { return [] }
        // MARK: T3 (people) — who they were, read before the row goes.
        let leaving = state.employees.first { $0.id == employeeID }
        // MARK: end T3
        let events = EmployeeSystem.fire(employeeID: employeeID, state: &state, balance: balance)
        guard !events.isEmpty else { return events }
        state.interactions.firedWithCauseIDs.append(employeeID)
        if let index = state.networking.contacts.firstIndex(where: { $0.id == employeeID }) {
            state.networking.contacts[index].outcome = .lost
            state.networking.contacts[index].rapport = 0
        }
        state.narrative.flags.insert(InteractionTuning.estrangedFlag)
        // MARK: T3 (people)
        // The room saw it, and somebody who was happy here may call a
        // lawyer: one `socialRNG` word, only on this tap.
        return events + SeveranceSystem.causeFollows(leaving, state: &state, balance: balance)
        // MARK: end T3
    }

    // MARK: - Refusals

    /// Why this is greyed out, in the player's words. `nil` means go.
    static func blocker(
        target: InteractionTarget,
        interactionID: String,
        state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> String? {
        guard state.gameOver == nil else { return "The company is over" }
        guard let rule = content.interactionRules.first(where: { $0.id == interactionID })
        else { return "That isn't something you can do" }
        guard rule.kinds.contains(target.kind) else { return "Not to them" }
        // Content-aware, so a friend whose roster has not been written into
        // state yet reads as the person they are rather than as a stranger.
        guard let bar = state.interactionBar(target, content: content) else {
            return "They're not in your life any more"
        }

        if let last = state.interactions.lastUsedDay(target, rule.id), rule.cooldownDays > 0 {
            let wait = rule.cooldownDays - (state.day - last)
            if wait > 0 { return "Too soon — \(wait) day\(wait == 1 ? "" : "s") to go" }
        }
        if let minBar = rule.minBar, bar < minBar {
            return "\(target.kind.barLabel.capitalized) \(Int(minBar))+ before you could"
        }
        if let maxBar = rule.maxBar, bar > maxBar {
            return "Nothing to make up for"
        }
        if rule.cost.spendsEvening {
            if state.life.isAway(day: state.day) { return "You're away" }
            if let blocker = state.eveningBlocker(balance) { return blocker }
        }
        let money = rule.cost.walletAmount
        if money > 0 && state.life.wallet < money {
            return "Need \((money - state.life.wallet).friendMoney) more in your wallet"
        }

        switch target {
        case .partner:
            if state.life.family.stage == .single { return "You're not with anybody" }
            if let minStage = rule.minStage, state.life.family.stage.rank < minStage.rank {
                return "Not this early on"
            }
        case .child(let id):
            guard let child = state.life.family.children.first(where: { $0.id == id })
            else { return "They're not in your life any more" }
            if let minChildStage = rule.minChildStage,
               child.stage(on: state.day).rank < minChildStage.rank {
                return "They're too young for that"
            }
            if state.interactions.isDisowned(id) && rule.id != "apologise" {
                return "You cut them off"
            }
        case .employee(let id):
            guard let employee = state.employees.first(where: { $0.id == id })
            else { return "They don't work here any more" }
            if employee.isFounder { return "That's you" }
        case .contact(let id):
            guard let contact = state.networking.contacts.first(where: { $0.id == id })
            else { return "They're not in the book" }
            if rule.id == InteractionTuning.affairID {
                if state.life.family.stage == .single { return "There's nothing to hide" }
                if state.interactions.hasAffair { return "You've already got one of those" }
                if contact.isAlumnus && contact.outcome == .lost { return "They won't see you" }
            }
        case .friend, .rival:
            break
        }

        if rule.id == InteractionTuning.fireWithCauseID,
           case .employee(let id) = target,
           state.employees.first(where: { $0.id == id })?.isFounder == true {
            return "That's you"
        }
        return nil
    }
}
