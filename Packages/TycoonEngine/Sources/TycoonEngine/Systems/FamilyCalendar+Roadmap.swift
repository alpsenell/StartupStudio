import Foundation
import TycoonContent

// MARK: K7 (partner and diary)

/// Iteration 15 — K7. The diary reads the roadmap, and the doctor writes.
///
/// **The diary.** The announce sheet's rows warn when a dated diary entry
/// (an anniversary, a child's birthday, a parent's) falls within
/// `partner.announceWindowDays` of the date. On a ship day that lands
/// within `partner.launchWindowDays` of one, `ProductSystem.ship`'s marked
/// line raises `clashFlag`; the launch-day sheet offers *Keep the date*
/// (hype at launch ×0.85, no launch-party vice, the date counts as kept),
/// and the default is the launch — the diary beat asks as it always does,
/// a child's birthday as its launch-week twin.
///
/// **The letter.** Doors armed, health under `partner.letterHealth`, no
/// letter in the last `partner.letterCooldownDays`: a `doctor_letter` is
/// written for `partner.letterLeadDays` from now, and lands with the
/// number and the days to the hospital at today's drift in its body.
///
/// Draws nothing. A founder with no diary never raises the flag; a run
/// whose doors are not armed never gets a letter — every bot, replay and
/// test.
public enum DiaryRoadmap {
    /// Raised when a product ships within a day of a diary date; cleared
    /// when that date is kept or the next diary beat fires.
    public static let clashFlag = "diary_launch_clash"
    /// The child's birthday, when it lands on launch week.
    public static let birthdayLaunchEventID = "diary_birthday_launch"

    /// `ProductSystem.ship`'s one marked line.
    static func noteLaunch(_ state: inout GameState, balance: BalanceConfig, content: ContentCatalog) {
        guard state.narrative.scheduled.contains(where: { $0.source == .life }) else { return }
        let dates = state.diaryDates(near: state.day, window: balance.partner.launchWindowDays, content: content)
        guard !dates.isEmpty else { return }
        state.narrative.flags.insert(clashFlag)
    }

    /// The launch-week twin of a child's birthday, while the clash stands.
    static func launchVariant(of def: LifeEventDef, state: GameState, content: ContentCatalog) -> LifeEventDef? {
        guard def.id == FamilyCalendar.birthdayEventID,
              state.narrative.hasFlag(clashFlag),
              let twin = content.lifeEvent(birthdayLaunchEventID)
        else { return nil }
        return twin
    }

    /// *Keep the date*.
    static func keepTheDate(
        productID: UUID,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard state.keepTheDateBlocker(productID: productID, balance: balance, content: content) == nil,
              let date = state.launchDiaryClash(productID: productID, balance: balance, content: content),
              let productIndex = state.products.firstIndex(where: { $0.id == productID }),
              case .released(var info) = state.products[productIndex].stage,
              let entryIndex = state.narrative.scheduled.firstIndex(where: {
                  $0.source == .life && $0.eventID == date.eventID && $0.day == date.day
                      && $0.childID == date.childID
              })
        else { return [] }

        // No launch party: the hype the launch was going to cash is less.
        info.hypeAtLaunch *= balance.partner.keepDateHypeFactor
        state.products[productIndex].stage = .released(info)

        // The date counts as kept: the beat's own first answer, without
        // the evening (the launch already had it) and without anything
        // that would draw.
        let entry = state.narrative.scheduled.remove(at: entryIndex)
        if let def = content.lifeEvent(entry.eventID), let kept = def.choices.first {
            let effects = kept.effects.filter { effect in
                if case .evening = effect { return false }
                return !effect.drawsRandomly
            }
            NarrativeSystem.apply(effects, label: def.headline, state: &state, balance: balance)
            for flag in kept.clearFlags { state.narrative.flags.remove(flag) }
        }
        if entry.eventID.hasPrefix(FamilyCalendar.birthdayEventID) {
            ChildhoodSystem.kidBeatResolved(
                eventID: FamilyCalendar.birthdayEventID, childID: entry.childID, missed: false,
                state: &state, config: balance.childhood
            )
        } else if entry.childID == nil, !FamilyCalendar.parentDateIDs.contains(entry.eventID) {
            state.life.family.lastPartnerDay = state.day
        }
        FamilyCalendar.fired(entry, &state, balance: balance, content: content)
        state.narrative.flags.remove(clashFlag)
        return [.diaryDateKept(productID: productID, label: date.label, day: state.day)]
    }

    /// Launch parties skipped this week, for the vices' weekly count.
    static func partiesSkipped(_ state: GameState) -> Int {
        state.eventLog.count {
            if case .diaryDateKept(_, _, let day) = $0 { state.day - day < GameState.daysPerWeek } else { false }
        }
    }

    /// The launch-week birthday, answered: the bond and the memory the
    /// ordinary birthday would have left. `ChildhoodSystem` reads the
    /// ordinary beat's answers; this reads its twin's. Scans only in a
    /// house with children.
    static func resolveLaunchBirthday(_ state: inout GameState, _ balance: BalanceConfig) {
        guard !state.life.family.children.isEmpty else { return }
        let yesterday = state.day - 1
        for event in state.eventLog {
            guard case let .narrativeResolved(eventID, optionID, _, day) = event,
                  day == yesterday, eventID == birthdayLaunchEventID
            else { continue }
            ChildhoodSystem.kidBeatResolved(
                eventID: FamilyCalendar.birthdayEventID, childID: nil, missed: optionID != "party",
                state: &state, config: balance.childhood
            )
        }
    }
}

// MARK: - The doctor's letter

enum DoctorLetter {
    static let eventID = "doctor_letter"
    /// Raised when a letter is written; its answers take it down. Gates
    /// the def, so nothing but this path can reach it.
    static let dueFlag = "doctor_letter_due"

    static func check(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        guard state.doors.armed else { return [] }
        let config = balance.partner

        // A letter that has landed.
        if let index = state.narrative.scheduled.firstIndex(where: {
            $0.eventID == eventID && $0.source == .life
        }) {
            guard state.narrative.scheduled[index].day <= state.day,
                  state.narrative.pendingChoice == nil,
                  var def = content.lifeEvent(eventID)
            else { return [] }
            state.narrative.scheduled.remove(at: index)
            // The number and the days, written into the letter today (the
            // catalog's copy carries only the `{partner}`-style tokens).
            def.body = [numbers(state, balance), def.body].compactMap { $0 }.joined(separator: " ")
            let events = NarrativeSystem.fireLife(def, state: &state, balance: balance)
            state.narrative.cooldowns[eventID] = state.day + config.letterCooldownDays
            return events
        }

        // Writing one.
        guard state.life.meters.health < config.letterHealth,
              !state.life.isAway(day: state.day),
              content.lifeEvent(eventID) != nil
        else { return [] }
        if let until = state.narrative.cooldowns[eventID], state.day < until { return [] }
        state.narrative.flags.insert(dueFlag)
        NarrativeSystem.schedule(
            eventID, source: .life, day: state.day + max(1, config.letterLeadDays), state: &state
        )
        return []
    }

    /// "Your health is at 38. At this rate you will be in a hospital bed
    /// in about 140 days."
    static func numbers(_ state: GameState, _ balance: BalanceConfig) -> String {
        let health = Int(state.life.meters.health.rounded())
        return "Your health is at \(health). \(hospitalLine(state, balance))"
    }

    private static func hospitalLine(_ state: GameState, _ balance: BalanceConfig) -> String {
        guard let days = state.daysToHospital(balance: balance) else {
            return "It is not falling at the moment, which is the only good news on the page."
        }
        return days <= 1
            ? "At this rate you will be in a hospital bed this week."
            : "At this rate you will be in a hospital bed in about \(days) days."
    }
}

// MARK: - Queries

extension GameState {
    /// Diary dates within `window` days of `day`, soonest first.
    public func diaryDates(near day: Int, window: Int, content: ContentCatalog) -> [FamilyDate] {
        familyDates(content: content).filter { abs($0.day - day) <= window }
    }

    /// The diary date an announcement for `day` would land on, if any —
    /// the announce row's warning.
    public func announceDiaryClash(day: Int, balance: BalanceConfig, content: ContentCatalog) -> FamilyDate? {
        diaryDates(near: day, window: balance.partner.announceWindowDays, content: content).first
    }

    /// The diary date a released product's launch landed on, while it is
    /// still in the diary and the clash stands.
    public func launchDiaryClash(productID: UUID, balance: BalanceConfig, content: ContentCatalog) -> FamilyDate? {
        guard narrative.hasFlag(DiaryRoadmap.clashFlag),
              let product = product(id: productID),
              case .released(let info) = product.stage
        else { return nil }
        return diaryDates(near: info.launchDay, window: balance.partner.launchWindowDays, content: content).first
    }

    /// Why *Keep the date* would be refused, or `nil`.
    public func keepTheDateBlocker(productID: UUID, balance: BalanceConfig, content: ContentCatalog) -> String? {
        guard let product = product(id: productID), case .released(let info) = product.stage else {
            return "It has not shipped"
        }
        if day - info.launchDay >= GameState.daysPerWeek { return "Launch week is over" }
        if launchDiaryClash(productID: productID, balance: balance, content: content) == nil {
            return "Nothing in the diary that day"
        }
        return nil
    }

    /// Health lost per day at today's drift (negative when falling): the
    /// schedule, the children and the office's amenities, the same terms
    /// `LifeSystem.applyDailyDrift` adds.
    public func founderHealthDriftPerDay(balance: BalanceConfig) -> Double {
        let config = balance.life
        let amenities = ownedAmenities.reduce(0.0) { $0 + balance.company.amenity($1).founderHealthBonus }
        return config.drift(for: effectiveSchedule).health
            + Double(life.family.children.count) * config.childDrift.health
            + amenities
    }

    /// Whole days until health crosses the hospital line at today's drift,
    /// or `nil` when it is not falling.
    public func daysToHospital(balance: BalanceConfig) -> Int? {
        let drift = founderHealthDriftPerDay(balance: balance)
        guard drift < 0 else { return nil }
        let room = life.meters.health - balance.life.hospitalHealthThreshold
        return max(0, Int((room / -drift).rounded(.up)))
    }
}

// MARK: end K7
