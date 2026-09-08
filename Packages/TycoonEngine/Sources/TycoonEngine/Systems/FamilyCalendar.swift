import Foundation
import TycoonContent

/// The family's calendar (WS-E, iteration 5): the dates that ask for one
/// of the founder's evenings.
///
/// Three kinds of entry: an anniversary a year after each stage of the
/// relationship begins, each child's birthday a year after the last, and
/// the follow-up a promise creates. All of them live in
/// `narrative.scheduled` as `.life` entries whose definition carries a
/// `diaryLabel` — nothing here is a new save field. A dated beat is
/// *scheduled, not rolled*: it takes the life roll's slot on the next
/// interval day inside `relationships.diary.windowDays` (no draw, no
/// extra pause), and past the window it fires like any other follow-up.
/// The deadline's answer is always the polite miss, which the engine
/// stamps as `familyDateMissed` and a flag the next beat reads.
///
/// Draws nothing. Never runs for a single, childless founder, which is
/// every pacing bot — the whole calendar is gated on somebody being in
/// the founder's life.
enum FamilyCalendar {
    /// The def the calendar schedules a year into every stage.
    static let anniversaryEventID = "partner_anniversary"
    /// The def the calendar schedules a year after each child's last one.
    static let birthdayEventID = "kid_birthday"
    /// Raised by a missed date; read by the "you missed the last one too"
    /// variants and the second acts, cleared by making it up.
    static let missedFlag = "family_date_missed"

    // MARK: Iteration 11, wave two — W2 (family drama)

    /// The parents' birthdays, one each, put in the diary the first time
    /// the founder opens the family room and recurring a year on like
    /// every other date here.
    static let motherBirthdayEventID = "family_mother_birthday"
    static let fatherBirthdayEventID = "family_father_birthday"
    /// The anniversary the founder now dreads: the same date, the same
    /// evening, fired in the anniversary's place while the affair is on
    /// the record.
    static let dreadedAnniversaryEventID = "family_anniversary_after"
    /// Dates that belong to the founder's own parents, not the partner's,
    /// so a breakup does not take them away.
    static let parentDateIDs: Set<String> = [
        "family_mother_birthday", "family_father_birthday",
    ]

    /// Every `followUpOnly` life beat this lane fires itself: the two
    /// parents' birthdays, which `parentsArrived` schedules, and the
    /// dreaded anniversary, which `anniversaryVariant` swaps in. The same
    /// shape as `ChildhoodSystem.stageBeatIDs` and
    /// `OfficeSecretsSystem.scheduledEventIDs` — the roll never draws one,
    /// which is not the same as nothing being able to reach it.
    static let familyDramaScheduledEventIDs: Set<String> = parentDateIDs.union([
        "family_anniversary_after",
    ])

    /// Puts the parents' birthdays in the diary, once. Called only from
    /// `FamilyDramaSystem`, which itself only runs once the founder has
    /// opened the room — so a run that never does keeps an unchanged
    /// diary, and the beats are ordinary dated `family_` events with a
    /// `diaryLabel`, not a new save field.
    static func parentsArrived(
        _ state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) {
        let year = balance.relationships.diary.yearDays
        let ids = [motherBirthdayEventID, fatherBirthdayEventID]
        for (offset, id) in ids.enumerated() {
            let already = state.narrative.scheduled.contains { entry in entry.eventID == id }
            guard !already else { continue }
            schedule(
                id,
                day: state.day + year / 4 + offset * year / 3,
                childID: nil, state: &state, balance: balance, content: content
            )
        }
    }

    /// The anniversary's twin while the affair is on the record.
    static func anniversaryVariant(
        of def: LifeEventDef,
        state: GameState,
        content: ContentCatalog
    ) -> LifeEventDef {
        guard def.id == anniversaryEventID,
              state.narrative.hasFlag(FamilyDrama.discoveredFlag),
              let twin = content.lifeEvent(dreadedAnniversaryEventID)
        else { return def }
        return twin
    }

    // MARK: end of Iteration 11, wave two — W2

    // MARK: - Scheduling

    /// The relationship reached a new stage, or started: the old
    /// anniversary goes and a new one lands a year from today.
    static func stageChanged(
        _ state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) {
        removePartnerDates(&state, content: content)
        guard state.life.family.stage != .single else { return }
        schedule(
            anniversaryEventID,
            day: state.life.family.stageSinceDay + balance.relationships.diary.yearDays,
            childID: nil, state: &state, balance: balance, content: content
        )
    }

    /// A breakup: the partner's dates go with them. The children's stay.
    static func partnerLeft(_ state: inout GameState, content: ContentCatalog) {
        removePartnerDates(&state, content: content)
    }

    /// A child was born: their first birthday goes in the diary.
    static func childBorn(
        _ child: Child,
        _ state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) {
        schedule(
            birthdayEventID,
            day: child.bornDay + balance.relationships.diary.yearDays,
            childID: child.id, state: &state, balance: balance, content: content
        )
    }

    /// Puts a dated beat in the diary, spaced the way the calendar is
    /// spaced: never inside the first `stageGraceDays` of a stage for the
    /// partner's dates, and never within `spacingDays` of another date for
    /// the same person. Ignored when the catalog has no dated def by that
    /// id, so a test catalog without the calendar schedules nothing.
    static func schedule(
        _ eventID: String,
        day: Int,
        childID: UUID?,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) {
        guard content.lifeEvent(eventID)?.isDated == true else { return }
        let diary = balance.relationships.diary
        var day = day
        if childID == nil {
            day = max(day, state.life.family.stageSinceDay + diary.stageGraceDays)
        }
        let same = entries(in: state, content: content)
            .filter { $0.childID == childID }
            .sorted { $0.day < $1.day }
        for other in same where abs(other.day - day) < diary.spacingDays {
            day = other.day + diary.spacingDays
        }
        NarrativeSystem.schedule(eventID, source: .life, day: day, childID: childID, state: &state)
    }

    private static func removePartnerDates(_ state: inout GameState, content: ContentCatalog) {
        state.narrative.scheduled.removeAll { entry in
            // MARK: Iteration 11, wave two — W2 (family drama)
            // Your own parents' birthdays are not your partner's dates and
            // do not leave with them.
            guard !parentDateIDs.contains(entry.eventID) else { return false }
            // MARK: end of Iteration 11, wave two — W2
            return entry.source == .life && entry.childID == nil
                && content.lifeEvent(entry.eventID)?.isDated == true
        }
    }

    /// Every dated entry in the diary, in schedule order.
    private static func entries(
        in state: GameState,
        content: ContentCatalog
    ) -> [ScheduledNarrativeEvent] {
        state.narrative.scheduled.filter {
            $0.source == .life && content.lifeEvent($0.eventID)?.isDated == true
        }
    }

    // MARK: - Firing

    /// The dated beat that takes today's life-roll slot, if any: due, and
    /// still inside its window. Entries are kept sorted by day, so the
    /// first due dated one is the earliest.
    static func dueDatedBeat(
        _ state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> (index: Int, def: LifeEventDef)? {
        let window = balance.relationships.diary.windowDays
        for (index, entry) in state.narrative.scheduled.enumerated() {
            guard entry.day <= state.day else { break }
            guard entry.source == .life,
                  let def = content.lifeEvent(entry.eventID), def.isDated,
                  state.day <= entry.day + window
            else { continue }
            return (index, def)
        }
        return nil
    }

    /// Whether an entry is a dated beat still waiting for a life-roll
    /// slot — the ordinary follow-up path leaves those alone until the
    /// window closes.
    static func isWaitingForSlot(
        _ entry: ScheduledNarrativeEvent,
        state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> Bool {
        guard entry.source == .life,
              let def = content.lifeEvent(entry.eventID), def.isDated
        else { return false }
        return state.day <= entry.day + balance.relationships.diary.windowDays
    }

    /// The definition that actually fires for `def`: its "you missed the
    /// last one too" twin while the miss is still on the books.
    static func variant(
        of def: LifeEventDef,
        state: GameState,
        content: ContentCatalog
    ) -> LifeEventDef {
        // MARK: Iteration 11, wave two — W2 (family drama)
        // The anniversary after the affair is a different evening.
        let def = anniversaryVariant(of: def, state: state, content: content)
        // MARK: end of Iteration 11, wave two — W2
        guard state.narrative.hasFlag(missedFlag),
              let id = def.missedVariantID,
              let twin = content.lifeEvent(id)
        else { return def }
        return twin
    }

    /// Bookkeeping after a diary entry fired: the calendar's own dates
    /// recur a year on, counted from the stage or the birth rather than
    /// from where spacing happened to put this one.
    static func fired(
        _ entry: ScheduledNarrativeEvent,
        _ state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) {
        let year = balance.relationships.diary.yearDays
        func next(after base: Int) -> Int {
            base + year * (max(0, entry.day - base) / year + 1)
        }
        switch entry.eventID {
        case anniversaryEventID:
            guard state.life.family.stage != .single else { return }
            schedule(
                anniversaryEventID, day: next(after: state.life.family.stageSinceDay),
                childID: nil, state: &state, balance: balance, content: content
            )
        // MARK: Iteration 11, wave two — W2 (family drama)
        case motherBirthdayEventID, fatherBirthdayEventID:
            schedule(
                entry.eventID, day: entry.day + year,
                childID: nil, state: &state, balance: balance, content: content
            )
        // MARK: end of Iteration 11, wave two — W2
        case birthdayEventID:
            guard let childID = entry.childID,
                  let child = state.life.family.children.first(where: { $0.id == childID })
            else { return }
            schedule(
                birthdayEventID, day: next(after: child.bornDay),
                childID: childID, state: &state, balance: balance, content: content
            )
        default:
            break
        }
    }

    // MARK: - Copy

    /// Fills `{partner}`, `{child}` and `{company}`. The child is the one
    /// the beat is about when it says; otherwise the one whose birthday
    /// was most recent, which is the right child for a second act that
    /// lost its id on the way, and any child at all for a beat that just
    /// needs a name.
    static func fill(_ text: String, state: GameState, childID: UUID?) -> String {
        guard text.contains("{") else { return text }
        let family = state.life.family
        let partner = family.partnerName
            .flatMap { $0.split(separator: " ").first.map(String.init) } ?? "your partner"
        let child = family.children.first { $0.id == childID }
            ?? family.children.min {
                daysSinceBirthday($0, day: state.day) < daysSinceBirthday($1, day: state.day)
            }
        return text
            .replacingOccurrences(of: "{partner}", with: partner)
            .replacingOccurrences(of: "{child}", with: child?.name ?? "your kid")
            .replacingOccurrences(of: "{company}", with: state.company.name)
    }

    private static func daysSinceBirthday(_ child: Child, day: Int) -> Int {
        let year = BalanceConfig.RelationshipBalance.DiaryBalance.default.yearDays
        return ((day - child.bornDay) % year + year) % year
    }
}

// MARK: - Query

/// One line of the family calendar, as the Life tab shows it.
public struct FamilyDate: Equatable, Sendable, Identifiable {
    /// The day the date falls on (it fires on the life roll's next slot).
    public let day: Int
    /// "Sam's birthday", "Your anniversary with Priya".
    public let label: String
    public let eventID: String
    public let childID: UUID?

    public var id: String { "\(eventID)-\(day)-\(childID?.uuidString ?? "")" }
}

extension GameState {
    /// The family's upcoming dates, soonest first — the "next: Sam's
    /// birthday · 9 days" line. Empty for a founder with nobody to miss.
    public func familyDates(content: ContentCatalog) -> [FamilyDate] {
        narrative.scheduled.compactMap { entry -> FamilyDate? in
            guard entry.source == .life,
                  let def = content.lifeEvent(entry.eventID), let label = def.diaryLabel
            else { return nil }
            return FamilyDate(
                day: entry.day,
                label: FamilyCalendar.fill(label, state: self, childID: entry.childID),
                eventID: entry.eventID,
                childID: entry.childID
            )
        }
        .sorted { ($0.day, $0.eventID) < ($1.day, $1.eventID) }
    }

    /// The partner's next date — the anniversary, or a promise.
    public func nextPartnerDate(content: ContentCatalog) -> FamilyDate? {
        familyDates(content: content).first { $0.childID == nil }
    }

    /// The soonest date for anybody in the family.
    public func nextFamilyDate(content: ContentCatalog) -> FamilyDate? {
        familyDates(content: content).first
    }

    /// The diary line for a dated beat, filled from live state — for copy
    /// about a date that has already fired and left the diary, such as
    /// "You missed Sam's birthday". `nil` for a beat that is not dated.
    public func diaryLabel(for eventID: String, content: ContentCatalog) -> String? {
        content.lifeEvent(eventID)?.diaryLabel.map {
            FamilyCalendar.fill($0, state: self, childID: nil)
        }
    }
}
