import Foundation
import TycoonContent

// Iteration 9 — L1. The phone.

/// The phone is a mirror, not a mechanism.
///
/// Nothing here moves a meter, spends an evening, or draws a random
/// number: every message is a line of copy written next to something the
/// game already did. `PhoneMirror` is called from the four places a person
/// says something to the founder — a narrative beat rising and being
/// answered (`NarrativeSystem`), a partner on the way out
/// (`RelationshipSystem`), somebody at work bringing a problem
/// (`SocialSystem`), and a former colleague checking in
/// (`NetworkingSystem+Alumni`) — and `PhoneSystem.run` adds the one
/// message nobody else sends, the office's Sunday numbers.
///
/// A run in which nothing happens to the founder posts nothing, and
/// `LifeState` writes no `phone` key at all.
enum PhoneSystem {

    /// Daily. The only thing the phone does on its own: on the last day of
    /// each week the office texts the week's numbers.
    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        postWeeklyOfficeLine(&state)
        return []
    }

    /// Sunday is `dayOfWeek == 7`, which is `day % 7 == 6`. Week 1 has no
    /// numbers worth sending, so the first line lands at the end of it.
    private static func postWeeklyOfficeLine(_ state: inout GameState) {
        guard state.day % 7 == 6, state.day > 0, PhoneMirror.officeIsOn(state) else { return }
        let week = state.day / 7 + 1
        let entries = state.ledger.entries.filter { $0.day > state.day - 7 }
        let income = entries.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
        let expenses = entries.filter { $0.amount < 0 }.reduce(0) { $0 - $1.amount }
        let net = income - expenses
        let sign = net >= 0 ? "+" : "-"
        state.life.phone.post(
            "Week \(week) closed. In \(money(income)), out \(money(expenses)), "
                + "\(sign)\(money(abs(net))) net. Cash \(money(state.company.cash)).",
            from: .office,
            day: state.day
        )
    }

    /// `12400` → `"$12,400"`. The engine has no formatter of its own and
    /// the app's lives in `Theme`; this is the same shape, for the one
    /// string the engine writes.
    static func money(_ amount: Int) -> String {
        let sign = amount < 0 ? "-" : ""
        let digits = String(amount.magnitude)
        var grouped = ""
        for (offset, character) in digits.reversed().enumerated() {
            if offset != 0, offset.isMultiple(of: 3) { grouped.append(",") }
            grouped.append(character)
        }
        return sign + "$" + String(grouped.reversed())
    }
}

// MARK: - The mirror

/// Where a beat lands on the phone, and what it says there.
enum PhoneMirror {

    /// The marker a deadline leaves in the thread. It never goes away:
    /// the point of it is that the founder can scroll back and find the
    /// evening they didn't answer.
    static let noReplyMarker = "Seen. No reply."

    // MARK: Narrative beats

    /// The thread a life or company beat belongs in — the person it is
    /// actually about. `nil` means nobody: the beat is between the founder
    /// and the world, and the phone stays out of it.
    static func counterpart(
        source: NarrativeSource,
        eventID: String,
        childID: UUID?,
        state: GameState
    ) -> PhoneCounterpart? {
        switch source {
        case .company:
            // Everything that happens to the company is the office
            // talking — but only once there *is* an office to talk. A
            // founder alone in a garage has nobody to text them the
            // numbers, and a run that never hires anybody leaves the
            // phone, and the save, exactly as it found them.
            return officeIsOn(state) ? .office : nil
        case .staff:
            return nil
        case .life:
            break
        }
        if let childID, state.life.family.children.contains(where: { $0.id == childID }) {
            return .child(childID)
        }
        if partnerEventIDs.contains(eventID) || eventID.hasPrefix("partner_") {
            return state.life.family.stage == .single ? nil : .partner
        }
        if childEventIDs.contains(eventID) || eventID.hasPrefix("kid_") {
            // The same child the copy's `{child}` names: the one whose
            // birthday is next round the corner.
            return nearestChild(state).map { .child($0.id) }
        }
        if friendEventIDs.contains(eventID) || eventID.hasPrefix("friend_") {
            // L4's friends, once they exist. Until then a friend beat has
            // nobody to text and stays off the phone.
            return state.life.friends.friends.first.map { .friend($0.id) }
        }
        return nil
    }

    /// A question, arriving. The headline is the first bubble and the body
    /// the second, because that is how somebody actually texts you a
    /// problem: the thing, then the detail.
    static func raised(_ pending: PendingChoice, state: inout GameState) {
        guard let counterpart = counterpart(
            source: pending.source, eventID: pending.id,
            childID: pending.childID, state: state
        ) else { return }
        state.life.phone.post(
            pending.title, from: counterpart, day: state.day, eventID: pending.id
        )
        if pending.body != pending.title, !pending.body.isEmpty {
            state.life.phone.post(
                pending.body, from: counterpart, day: state.day, eventID: pending.id
            )
        }
    }

    /// The answer. The founder's own option label goes in as their reply;
    /// a deadline that answered for them leaves the marker instead, so the
    /// thread shows the silence rather than words the founder never said.
    static func answered(
        _ pending: PendingChoice,
        label: String,
        automatic: Bool,
        state: inout GameState
    ) {
        guard let counterpart = counterpart(
            source: pending.source, eventID: pending.id,
            childID: pending.childID, state: state
        ), state.life.phone.thread(with: counterpart) != nil else { return }
        state.life.phone.post(
            automatic ? noReplyMarker : label,
            from: counterpart,
            day: state.day,
            fromFounder: true,
            eventID: pending.id,
            kind: automatic ? .unanswered : .said
        )
    }

    /// A life or company beat with no question in it: one line, no reply.
    static func landed(
        source: NarrativeSource,
        eventID: String,
        headline: String,
        childID: UUID?,
        state: inout GameState
    ) {
        guard let counterpart = counterpart(
            source: source, eventID: eventID, childID: childID, state: state
        ) else { return }
        state.life.phone.post(headline, from: counterpart, day: state.day, eventID: eventID)
    }

    // MARK: The partner's one warning

    /// The single message a partner sends on the way down through the
    /// line — the same crossing `RelationshipSystem` reports as
    /// `.partnerDrifting`, in their own words.
    static func partnerWarning(state: inout GameState) {
        guard state.life.family.stage != .single else { return }
        state.life.phone.post(
            "I'm not doing this to punish you. I just don't want to keep "
                + "waiting up on my own.",
            from: .partner,
            day: state.day
        )
    }

    // MARK: The team

    /// Somebody at work brings the founder a problem.
    static func staffRaised(
        _ event: StaffEvent,
        state: inout GameState,
        content: ContentCatalog
    ) {
        guard let employee = state.employees.first(where: { $0.id == event.employeeID }),
              let def = content.staffEvent(event.definitionID)
        else { return }
        let thread = PhoneCounterpart.employee(event.employeeID)
        func fill(_ text: String) -> String {
            text
                .replacingOccurrences(of: "{name}", with: employee.name)
                .replacingOccurrences(of: "{company}", with: state.company.name)
        }
        let headline = fill(def.headline)
        state.life.phone.post(headline, from: thread, day: state.day, eventID: def.id)
        let body = fill(def.body)
        if !body.isEmpty, body != headline {
            state.life.phone.post(body, from: thread, day: state.day, eventID: def.id)
        }
    }

    /// And the founder's answer to it, or the silence that stood in for one.
    static func staffAnswered(
        _ event: StaffEvent,
        choice: StaffEventChoice,
        automatic: Bool,
        state: inout GameState,
        content: ContentCatalog
    ) {
        let thread = PhoneCounterpart.employee(event.employeeID)
        guard state.life.phone.thread(with: thread) != nil else { return }
        let def = content.staffEvent(event.definitionID)
        let label = switch choice {
        case .supportive: def?.supportive?.label ?? "Of course. We'll sort it."
        case .strict, .strictAsPolicy: def?.strict.label ?? "Not right now."
        }
        state.life.phone.post(
            automatic ? noReplyMarker : label,
            from: thread,
            day: state.day,
            fromFounder: true,
            eventID: def?.id,
            kind: automatic ? .unanswered : .said
        )
    }

    // MARK: The boomerang

    /// Somebody who left checks in. Two beats, both on days the alumni
    /// drift already computes: the first quarter away, and the day they
    /// turn out to have founded something.
    static func alumnusCheckedIn(_ contact: Contact, line: String, state: inout GameState) {
        state.life.phone.post(line, from: .contact(contact.id), day: state.day)
    }

    /// Whether anybody but the founder works here. The office thread
    /// opens with the first hire and not before: it is the one thread
    /// nobody in the founder's life is behind.
    static func officeIsOn(_ state: GameState) -> Bool {
        state.employees.contains { !$0.isFounder }
    }

    // MARK: - Which beat belongs to whom

    /// Life events about the partner that the `partner_` prefix misses.
    private static let partnerEventIDs: Set<String> = [
        "dating_app_match", "holiday_alone", "vacation_never_taken",
    ]

    /// Life events about a child that the `kid_` prefix misses.
    private static let childEventIDs: Set<String> = [
        "kids_first_word", "newborn_sleepless", "recital_vs_dinner",
        "school_run", "sunday_lunch",
    ]

    /// Life events about a friend, for the day L4's friends exist.
    private static let friendEventIDs: Set<String> = [
        "old_friend_visits", "friends_wedding", "surprise_party",
        "burnout_friend", "friend_moves_away", "friend_startup_advisor",
        "wedding_on_launch_week", "reunion_invite", "neighbour_dinner",
    ]

    /// The child `FamilyCalendar.fill` would name: the one whose birthday
    /// came round most recently.
    private static func nearestChild(_ state: GameState) -> Child? {
        let year = BalanceConfig.RelationshipBalance.DiaryBalance.default.yearDays
        return state.life.family.children.min {
            ((state.day - $0.bornDay) % year + year) % year
                < ((state.day - $1.bornDay) % year + year) % year
        }
    }
}
