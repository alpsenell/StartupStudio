import Foundation
import TycoonContent

/// Iteration 9 — L3. The children's day: they get older, they remember
/// what the company did to the house, and a teenager can spend a summer at
/// the studio.
///
/// **Neutral by default.** The very first line returns for a founder with
/// no children, which is every pacing bot and every balance sweep: no
/// meter moves, no draw is made, nothing is scheduled. Nothing in here
/// touches `rng` or `worldRNG` at all — the intern's face and id come from
/// a local generator seeded off the child's own `appearanceSeed`, so the
/// world's streams never notice.
///
/// The memory ledger reads *yesterday's* `eventLog`. Systems run before
/// `Reducer.tick` logs the day's events, so today's are not there yet;
/// scanning `state.day - 1` sees every day exactly once and needs no
/// cursor on the state.
public enum ChildhoodSystem {
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        guard !state.life.family.children.isEmpty else { return [] }
        let config = balance.childhood

        var events: [GameEvent] = []
        events += advanceStages(&state, config, balance, content)
        resolveKidBeats(&state, config)
        events += harvestMemories(&state, config, content)
        events += endFinishedSummers(&state, config)
        decayBonds(&state, config)
        // MARK: T6 (away) — J6: a home near the park, a weekly bond with a school-age child. Returns at once with no home district.
        AwaySystem.schoolNearHome(&state, balance)
        // MARK: end T6
        return events
    }

    // MARK: - Growing up

    /// A child who changed stage overnight: a memory, a line on their
    /// thread, and — for school and teen — a beat scheduled about them.
    private static func advanceStages(
        _ state: inout GameState,
        _ config: ChildhoodBalance,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        let day = state.day
        var scheduled: [(String, UUID)] = []
        for index in state.life.family.children.indices {
            let child = state.life.family.children[index]
            let now = child.stage(on: day, balance: config)
            guard now != child.stage(on: day - 1, balance: config) else { continue }
            let note = grewUpNote(child.name, stage: now)
            remember(
                &state.life.family.children[index],
                kind: .grewUp, note: note, day: day, config: config
            )
            state.life.phone.post(note, from: .child(child.id), day: day)
            if let eventID = beat(for: now) { scheduled.append((eventID, child.id)) }
        }
        // Scheduled after the loop so the beats queue in child order,
        // whatever order the stages happened to turn over in.
        for (eventID, childID) in scheduled where content.lifeEvent(eventID) != nil {
            NarrativeSystem.schedule(
                eventID, source: .life, day: state.day + 1, childID: childID, state: &state
            )
        }
        return []
    }

    /// The `followUpOnly` beat a stage opens, if any. `followUpOnly` keeps
    /// these out of the ordinary weighted roll, so appending them to
    /// `LifeEvents.json` moves no existing run's stream.
    static func beat(for stage: ChildStage) -> String? {
        switch stage {
        case .toddler: "kid_first_sentence"
        case .school: "kid_first_day"
        case .teen: "kid_teen_door"
        case .grown: "kid_moves_out"
        case .baby: nil
        }
    }

    /// The `followUpOnly` beats this system schedules itself, the way
    /// `FamilyCalendar` schedules the anniversary and the birthday. No
    /// choice in `LifeEvents.json` points at them, so anything checking
    /// that every follow-up-only beat is reachable has to be told.
    static let stageBeatIDs: Set<String> = Set(ChildStage.allCases.compactMap(beat(for:)))

    private static func grewUpNote(_ name: String, stage: ChildStage) -> String {
        switch stage {
        case .baby: "\(name) is here."
        case .toddler: "\(name) walks now. Everything at knee height has moved."
        case .school: "\(name) started school today."
        case .teen: "\(name) is a teenager. The door closes more than it used to."
        case .grown: "\(name) has their own address now."
        }
    }

    // MARK: - The memory ledger

    /// Everything yesterday did that a child old enough to notice would
    /// still be talking about. One pass over the log, one memory per
    /// trigger, every memory also posted to that child's thread.
    private static func harvestMemories(
        _ state: inout GameState,
        _ config: ChildhoodBalance,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        let yesterday = state.day - 1
        guard yesterday >= 0 else { return [] }

        var entries: [(kind: ChildMemoryKind, note: String, bond: Double)] = []
        for event in state.eventLog {
            guard let trigger = trigger(for: event, on: yesterday, state: state, config: config)
            else { continue }
            entries.append(trigger)
        }
        // The sabbatical is a state, not an event: L6 sets the slot and
        // this notices it once, the day after it starts.
        if let sabbatical = state.life.sabbatical, sabbatical.sinceDay == yesterday {
            entries.append((
                .sabbatical,
                "You stopped going in. Somebody else is running it for a while.",
                2
            ))
        }
        guard !entries.isEmpty else { return [] }

        for index in state.life.family.children.indices {
            let child = state.life.family.children[index]
            guard child.stage(on: state.day, balance: config).remembers else { continue }
            for entry in entries {
                remember(
                    &state.life.family.children[index],
                    kind: entry.kind, note: entry.note, day: yesterday, config: config
                )
                move(&state.life.family.children[index].bond, by: entry.bond)
                state.life.phone.post(entry.note, from: .child(child.id), day: state.day)
            }
        }
        return []
    }

    /// The memory an event is worth, or `nil` for the overwhelming
    /// majority of the log. Only events stamped `day` are considered, so
    /// each day's log is read exactly once.
    private static func trigger(
        for event: GameEvent,
        on day: Int,
        state: GameState,
        config: ChildhoodBalance
    ) -> (kind: ChildMemoryKind, note: String, bond: Double)? {
        switch event {
        case let .reviewsIn(productID, averageScore, eventDay) where eventDay == day:
            guard averageScore >= 75 else { return nil }
            let name = state.products.first { $0.id == productID }?.name ?? state.company.name
            return (
                .launch,
                "\(name) reviewed at \(averageScore). There was cake in the kitchen at ten at night.",
                config.bondPerLaunchMemory
            )
        case let .founderMeltdown(eventDay) where eventDay == day:
            return (.burnout, "You did not get up for two days. Nobody explained why.", config.bondPerSourMemory)
        case let .founderAway(reason, _, eventDay) where eventDay == day
            && reason.localizedCaseInsensitiveContains("hospital"):
            return (.hospital, "An ambulance, and a week of somebody else doing the school run.", config.bondPerSourMemory)
        case let .homeDowngraded(tier, eventDay) where eventDay == day:
            return (
                .eviction,
                "You moved out in a hurry. The new place is a \(tier.displayName.lowercased()).",
                config.bondPerSourMemory
            )
        case let .chapterReached(chapter, eventDay) where eventDay == day:
            return (.chapter, "The company got bigger again. Chapter \(chapter), you called it.", 0)
        case let .wentPublic(proceeds, eventDay) where eventDay == day:
            return (.exit, "The company went public. \(proceeds.childMoney), and a photograph of you ringing a bell.", 1)
        case let .companySold(_, amount, eventDay) where eventDay == day:
            return (.exit, "You sold it. \(amount.childMoney), and a strange quiet at dinner.", 1)
        case let .lifeEvent(eventID, eventDay) where eventDay == day
            && (eventID == "friends_wedding" || eventID.hasPrefix("friend_wedding")):
            return (.wedding, "A wedding, and you dancing badly. Photographic evidence exists.", 1)
        default:
            return nil
        }
    }

    /// Appends a memory and holds the ledger at the cap, oldest first out.
    private static func remember(
        _ child: inout Child,
        kind: ChildMemoryKind,
        note: String,
        day: Int,
        config: ChildhoodBalance
    ) {
        child.memories.append(ChildMemory(day: day, kind: kind.rawValue, note: note))
        if child.memories.count > config.memoryCap {
            child.memories.removeFirst(child.memories.count - config.memoryCap)
        }
    }

    // MARK: - Bond

    /// Silence costs. Nothing moves inside the grace window, so a founder
    /// who sees their kids on the weekend never sees the number slide.
    private static func decayBonds(_ state: inout GameState, _ config: ChildhoodBalance) {
        let day = state.day
        for index in state.life.family.children.indices {
            let child = state.life.family.children[index]
            let last = child.lastTimeDay ?? child.bornDay
            guard day - last > config.bondGraceDays else { continue }
            move(&state.life.family.children[index].bond, by: -config.bondDecayPerDay)
        }
    }

    static func move(_ bond: inout Double, by delta: Double) {
        bond = min(100, max(0, bond + delta))
    }

    /// Every child gets a little closer for a weekend spent at home.
    /// Called by `LifeSystem` when the weekend resolves as family time.
    static func familyWeekend(_ state: inout GameState, balance: BalanceConfig) {
        guard !state.life.family.children.isEmpty else { return }
        let config = balance.childhood
        for index in state.life.family.children.indices {
            move(&state.life.family.children[index].bond, by: config.bondPerFamilyWeekend)
            state.life.family.children[index].lastTimeDay = state.day
        }
    }

    /// Every family beat the founder answered yesterday, and what the
    /// answer was worth.
    ///
    /// Read from the log rather than hooked into `NarrativeSystem`,
    /// because that file belongs to another lane this round; the cost is
    /// that `.narrativeResolved` does not carry the child, so a beat
    /// answered in a house with two children moves both. The birthday —
    /// the one beat that is always about one child — is the case that
    /// matters, and it reads the same either way while the diary only
    /// ever has one birthday due at a time.
    private static func resolveKidBeats(_ state: inout GameState, _ config: ChildhoodBalance) {
        let yesterday = state.day - 1
        guard yesterday >= 0 else { return }
        for event in state.eventLog {
            guard case let .narrativeResolved(eventID, optionID, _, day) = event, day == yesterday,
                  let warm = Self.warmOptions[eventID]
            else { continue }
            kidBeatResolved(
                eventID: eventID, childID: nil, missed: !warm.contains(optionID),
                state: &state, config: config
            )
        }
    }

    /// Per family beat, the option ids that mean the founder turned up.
    /// Anything else is the polite miss.
    private static let warmOptions: [String: Set<String>] = [
        "kid_birthday": ["party"],
        "kid_birthday_again": ["party"],
        "kid_after_missed_birthday": ["day_out"],
        "kid_brings_it_up": ["listen"],
        "recital_vs_dinner": ["recital"],
        "school_run": ["do_it"],
        "kid_sick_night": ["stay"],
        "kid_sick_second_night": ["stay", "home"],
        "kid_first_sentence": ["write_it_down"],
        "kid_first_day": ["walk_them"],
        "kid_teen_door": ["knock"],
        "kid_moves_out": ["drive_them"],
    ]

    /// A `kid_*` beat was answered: the bond moves with the answer, and a
    /// birthday leaves a memory either way.
    static func kidBeatResolved(
        eventID: String,
        childID: UUID?,
        missed: Bool,
        state: inout GameState,
        config: ChildhoodBalance
    ) {
        let indices: [Int]
        if let childID, let index = state.life.family.children.firstIndex(where: { $0.id == childID }) {
            indices = [index]
        } else {
            indices = Array(state.life.family.children.indices)
        }
        let isBirthday = eventID.hasPrefix("kid_birthday")
        for index in indices {
            let delta: Double = switch (isBirthday, missed) {
            case (true, true): config.bondPerBirthdayMissed
            case (true, false): config.bondPerBirthdayKept
            case (false, true): config.bondPerKidEventMissed
            case (false, false): config.bondPerKidEventKept
            }
            move(&state.life.family.children[index].bond, by: delta)
            if !missed { state.life.family.children[index].lastTimeDay = state.day }
            guard isBirthday else { continue }
            let name = state.life.family.children[index].name
            let note = missed
                ? "You were not at \(name)'s party. The present arrived on time."
                : "You were at \(name)'s party, phone in your pocket the whole afternoon."
            remember(
                &state.life.family.children[index],
                kind: missed ? .missedBirthday : .birthdayKept,
                note: note, day: state.day, config: config
            )
            state.life.phone.post(note, from: .child(state.life.family.children[index].id), day: state.day)
        }
    }

    // MARK: - An evening

    /// Why an evening with this child is refused, or `nil` when it is
    /// open. The app shows this string on the button; the engine enforces
    /// the same list.
    public static func eveningRefusal(
        childID: UUID,
        state: GameState,
        balance: BalanceConfig
    ) -> String? {
        guard let child = state.life.family.children.first(where: { $0.id == childID }) else {
            return "No such child."
        }
        let config = balance.childhood
        if state.life.isAway(day: state.day) { return "You are not home." }
        if child.stage(on: state.day, balance: config) == .grown {
            return "\(child.name) has their own life now — a call is all there is."
        }
        if let last = child.lastTimeDay, state.day - last < config.eveningCooldownDays {
            let left = config.eveningCooldownDays - (state.day - last)
            return "You had one \(state.day - last == 0 ? "today" : "\(state.day - last) days ago") — \(left) more day\(left == 1 ? "" : "s")."
        }
        if !state.hasEveningFree(balance) { return "No evenings left this week." }
        return nil
    }

    /// One evening, one child. A stage-appropriate vignette, a bond bump,
    /// a memory, a line on their thread.
    static func spendEvening(
        childID: UUID,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard eveningRefusal(childID: childID, state: state, balance: balance) == nil,
              let index = state.life.family.children.firstIndex(where: { $0.id == childID })
        else { return [] }
        let config = balance.childhood
        let child = state.life.family.children[index]
        let stage = child.stage(on: state.day, balance: config)
        let note = vignette(child.name, stage: stage)

        move(&state.life.family.children[index].bond, by: config.bondPerEvening)
        state.life.family.children[index].lastTimeDay = state.day
        remember(&state.life.family.children[index], kind: .evening, note: note, day: state.day, config: config)
        state.life.meters.apply(energy: -3, mood: 6, relationships: 5)
        state.life.phone.post(note, from: .child(child.id), day: state.day)
        state.spendEvening(balance)
        return [.lifeEvent(eventID: "kid_evening", day: state.day)]
    }

    /// What an evening with a child of this age actually is.
    public static func vignette(_ name: String, stage: ChildStage) -> String {
        switch stage {
        case .baby:
            "You took the two o'clock feed so nobody else had to. \(name) fell asleep on your shoulder and you did not move for an hour."
        case .toddler:
            "\(name) made you be the customer. The shop sold only bricks, and the prices changed constantly."
        case .school:
            "Homework, badly, then a film neither of you finished. \(name) explained the plot afterwards anyway."
        case .teen:
            "\(name) talked for forty minutes about something you did not follow, and you did not once look at your phone."
        case .grown:
            "Dinner, just the two of you. \(name) picked the place."
        }
    }

    // MARK: - The summer

    /// Why a summer at the studio is refused, or `nil` when it is open.
    public static func internRefusal(
        childID: UUID,
        state: GameState,
        balance: BalanceConfig
    ) -> String? {
        guard let child = state.life.family.children.first(where: { $0.id == childID }) else {
            return "No such child."
        }
        let config = balance.childhood
        if child.isInterning(on: state.day) { return "Already in, until day \(child.internUntilDay ?? 0)." }
        guard child.stage(on: state.day, balance: config) == .teen else {
            return "Only a teenager can. \(child.name) is \(child.stage(on: state.day, balance: config).displayName.lowercased())."
        }
        guard child.bond >= config.internMinBond else {
            let short = Int((config.internMinBond - child.bond).rounded(.up))
            return "\(child.name) would not want to. Bond needs \(short) more."
        }
        guard state.calendar.season == .summer else {
            return "Summer only — \(state.calendar.monthName) is term time."
        }
        return nil
    }

    /// Puts the teenager on the roster for eight weeks: no salary, a small
    /// skill sheet, a face derived from their own appearance seed rather
    /// than any of the world's streams.
    static func hireIntern(
        childID: UUID,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard internRefusal(childID: childID, state: state, balance: balance) == nil,
              let index = state.life.family.children.firstIndex(where: { $0.id == childID })
        else { return [] }
        let config = balance.childhood
        let child = state.life.family.children[index]

        // A local generator, seeded off the child: deterministic, and it
        // never touches `rng`, `worldRNG` or `socialRNG`.
        var derived = SeededRNG(seed: child.appearanceSeed &+ 0x9E37_79B9)
        let employeeID = UUID(from: &derived)
        let employee = Employee(
            id: employeeID,
            name: "\(child.name) (intern)",
            skills: config.internSkills,
            weeklySalary: 0,
            assignment: .idle,
            isFounder: false,
            hiredDay: state.day,
            appearanceSeed: child.appearanceSeed,
            morale: 85,
            level: .junior,
            loyalty: 80,
            founderBond: child.bond
        )
        state.employees.append(employee)
        state.life.family.children[index].internEmployeeID = employeeID
        state.life.family.children[index].internUntilDay = config.internEndDay(from: state.day)
        state.life.family.children[index].lastTimeDay = state.day
        move(&state.life.family.children[index].bond, by: config.internBondBonus / 2)

        let note = "\(child.name) starts on Monday. They asked what the wifi password is, then what a burn rate is."
        remember(&state.life.family.children[index], kind: .internSummer, note: note, day: state.day, config: config)
        state.life.phone.post(note, from: .child(child.id), day: state.day)
        return [.hired(employeeID: employeeID, day: state.day)]
    }

    /// The founder ending it early. Costs bond, and the child remembers
    /// that one differently.
    static func endInternshipEarly(
        childID: UUID,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard let index = state.life.family.children.firstIndex(where: { $0.id == childID }),
              state.life.family.children[index].isInterning(on: state.day)
        else { return [] }
        let config = balance.childhood
        let child = state.life.family.children[index]
        let note = "The summer ended early. \(child.name) cleared their desk in four minutes."
        move(&state.life.family.children[index].bond, by: config.internQuitBondPenalty)
        remember(&state.life.family.children[index], kind: .internQuit, note: note, day: state.day, config: config)
        state.life.phone.post(note, from: .child(child.id), day: state.day)
        return closeSummer(at: index, &state)
    }

    /// Eight weeks up: the desk is cleared, the bond keeps the rest of the
    /// bonus, and the summer is on the record.
    private static func endFinishedSummers(
        _ state: inout GameState,
        _ config: ChildhoodBalance
    ) -> [GameEvent] {
        var events: [GameEvent] = []
        for index in state.life.family.children.indices {
            let child = state.life.family.children[index]
            guard let until = child.internUntilDay, state.day >= until else { continue }
            let note = "\(child.name)'s last day. They fixed one real bug and kept the sticker."
            move(&state.life.family.children[index].bond, by: config.internBondBonus / 2)
            state.life.family.children[index].internSummers += 1
            remember(
                &state.life.family.children[index],
                kind: .internSummer, note: note, day: state.day, config: config
            )
            state.life.phone.post(note, from: .child(child.id), day: state.day)
            events += closeSummer(at: index, &state)
        }
        return events
    }

    /// Takes the intern off the roster and clears the slot.
    private static func closeSummer(at index: Int, _ state: inout GameState) -> [GameEvent] {
        var events: [GameEvent] = []
        if let employeeID = state.life.family.children[index].internEmployeeID {
            state.employees.removeAll { $0.id == employeeID }
            events.append(.fired(employeeID: employeeID, day: state.day))
        }
        state.life.family.children[index].internEmployeeID = nil
        state.life.family.children[index].internUntilDay = nil
        return events
    }
}

// MARK: - Copy helpers

extension Int {
    /// Money the way a child would repeat it: "$4.2M", "$180k".
    var childMoney: String {
        let value = abs(self)
        let sign = self < 0 ? "−" : ""
        switch value {
        case 1_000_000...:
            return "\(sign)$\((Double(value) / 1_000_000).rounded(toPlaces: 1))M"
        case 1_000...:
            return "\(sign)$\(value / 1_000)k"
        default:
            return "\(sign)$\(value)"
        }
    }
}

extension Double {
    fileprivate func rounded(toPlaces places: Int) -> String {
        String(format: "%.\(places)f", self)
    }
}

// MARK: K6 (home and rooms)

extension ChildhoodSystem {
    /// Iteration 15 — K6. A memory the home writes: the move ("moved") and
    /// the family holiday ("holiday"), for every child at one of `stages`
    /// (every child when `nil`), with `bond` added and, when it is non-zero,
    /// the day counted as time together.
    ///
    /// The kinds are raw strings rather than `ChildMemoryKind` cases: that
    /// enum is switched over in K7's files this round, and every reader that
    /// grades memories (custody, the successor's traits) skips a kind it
    /// does not know, so these two are the child's to keep and nobody's to
    /// grade. The ledger row draws them with its default mark.
    static func rememberHome(
        _ state: inout GameState,
        kind: String,
        note: (String) -> String,
        stages: Set<ChildStage>?,
        bond: Double,
        balance: BalanceConfig
    ) {
        let config = balance.childhood
        let day = state.day
        for index in state.life.family.children.indices {
            let child = state.life.family.children[index]
            if let stages, !stages.contains(child.stage(on: day, balance: config)) { continue }
            state.life.family.children[index].memories.append(
                ChildMemory(day: day, kind: kind, note: note(child.name))
            )
            let memories = state.life.family.children[index].memories
            if memories.count > config.memoryCap {
                state.life.family.children[index].memories.removeFirst(memories.count - config.memoryCap)
            }
            if bond != 0 {
                move(&state.life.family.children[index].bond, by: bond)
                state.life.family.children[index].lastTimeDay = day
            }
        }
    }
}
// MARK: end K6
