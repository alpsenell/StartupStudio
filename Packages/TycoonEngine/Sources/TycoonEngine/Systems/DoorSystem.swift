import Foundation
import TycoonContent

// Iteration 12 — J1. The four doors' day.
//
// Runs last in `Reducer.systems`, every day:
//
// 1. the crunch window takes today's schedule (from day 62, and only
//    while the vices door is still to come);
// 2. a door past its deadline is closed as a no;
// 3. the spare room, if that was the answer at the care door, takes this
//    week's evening;
// 4. from day 90, the first door whose condition is met opens — one a
//    day at most — with a phone message and an event the rail can carry.
//
// It never pauses, never touches `narrative.lastFiredDay`, never raises a
// flag the founder did not say out loud, and never draws.
enum DoorSystem {

    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        // The identity gate: only a game a person is playing has doors.
        guard state.doors.armed else { return [] }
        trackCrunch(&state)

        var events = lapse(&state)
        spareRoomEvening(&state, balance)

        guard state.day >= DoorRules.notBeforeDay,
              state.gameOver == nil,
              state.prison == nil,
              !state.life.isAway(day: state.day)
        else { return events }
        for kind in DoorKind.allCases where state.doors.record(kind) == nil {
            guard DoorRules.meets(kind, state: state, balance: balance, content: content) else { continue }
            let subject = kind == .care ? DoorRules.careSubject(state: state, content: content) : nil
            events.append(contentsOf: open(kind, subject: subject, state: &state, content: content))
            break
        }
        return events
    }

    // MARK: - The day's bookkeeping

    /// The last 28 days of the founder's schedule, as bits. Nothing is
    /// kept before day 62 or after the question has been asked.
    private static func trackCrunch(_ state: inout GameState) {
        if state.doors.record(.vices) != nil || state.assets.isEngaged {
            if state.doors.crunchMask != 0 { state.doors.crunchMask = 0 }
            return
        }
        guard state.day >= DoorRules.crunchTrackFromDay else { return }
        let bit: UInt32 = state.effectiveSchedule == .crunch ? 1 : 0
        let mask = ((state.doors.crunchMask << 1) | bit) & DoorRules.crunchWindowMask
        if mask != state.doors.crunchMask { state.doors.crunchMask = mask }
    }

    /// A door nobody answered closes. The deadline's answer is no.
    private static func lapse(_ state: inout GameState) -> [GameEvent] {
        var events: [GameEvent] = []
        for index in state.doors.records.indices {
            let record = state.doors.records[index]
            guard record.answer == nil, state.day > record.respondByDay else { continue }
            state.doors.records[index].answer = .lapsed
            state.doors.records[index].answeredDay = state.day
            events.append(.doorAnswered(
                kind: record.kind.rawValue, choice: DoorChoice.lapsed.rawValue, day: state.day
            ))
        }
        return events
    }

    /// A parent in the spare room is an evening a week, every week, booked
    /// the day the budget refills (`LifeSystem` resets it on day % 7 == 1,
    /// earlier in the same tick).
    private static func spareRoomEvening(_ state: inout GameState, _ balance: BalanceConfig) {
        guard state.doors.careTakesAnEvening,
              state.day % GameState.daysPerWeek == 1,
              let subject = state.doors.record(.care)?.subject.flatMap(FamilyRelation.init(rawValue:)),
              state.familyDrama.record(subject)?.isAlive != false
        else { return }
        state.spendEvening(balance)
    }

    // MARK: - Opening

    static func open(
        _ kind: DoorKind,
        subject: FamilyRelation?,
        state: inout GameState,
        content: ContentCatalog
    ) -> [GameEvent] {
        let by = state.day + DoorRules.respondDays
        state.doors.records.append(DoorRecord(
            kind: kind, openedDay: state.day, respondByDay: by, subject: subject?.rawValue
        ))
        let (text, from) = message(kind, subject: subject, state: state, content: content)
        state.life.phone.post(text, from: from, day: state.day)
        return [.doorOpened(kind: kind.rawValue, respondByDay: by, day: state.day)]
    }

    /// The phone message each door arrives as, and who sends it.
    static func message(
        _ kind: DoorKind,
        subject: FamilyRelation?,
        state: GameState,
        content: ContentCatalog
    ) -> (String, PhoneCounterpart) {
        switch kind {
        case .shark:
            return ("A man called Denny rang the office. He knows the runway to the week, "
                + "which nobody outside this building does. He would like twenty minutes.", .office)
        case .vices:
            return ("Somebody from the launch party left a number on a napkin in your coat. "
                + "\"For the next late one.\" There have been a lot of late ones.", .office)
        case .fame:
            return ("A journalist at The Ledger wants your take on the launch. Two paragraphs, "
                + "on the record, by Friday.", .office)
        case .care:
            let name = state.familyRelativeName(subject ?? .mother, content: content)
            let from: PhoneCounterpart = state.life.family.stage == .single ? .office : .partner
            return ("\(name) had a fall. It's not serious. The home wants a number by Friday.", from)
        }
    }

    // MARK: - Answering

    /// The founder's answer. Yes wakes the room through that room's own
    /// function; no raises a flag and nothing else.
    static func answer(
        _ kind: DoorKind,
        _ choice: DoorChoice,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard DoorRules.refusal(kind, choice, state: state, balance: balance) == nil,
              let index = state.doors.records.firstIndex(where: { $0.kind == kind })
        else { return [] }
        let subject = state.doors.records[index].subject.flatMap(FamilyRelation.init(rawValue:))
        state.doors.records[index].answer = choice
        state.doors.records[index].answeredDay = state.day
        if let flag = DoorRules.flag(kind, choice) { state.narrative.flags.insert(flag) }

        var events: [GameEvent] = [
            .doorAnswered(kind: kind.rawValue, choice: choice.rawValue, day: state.day),
        ]
        guard choice.opens else { return events }
        switch kind {
        case .shark:
            events.append(contentsOf: DirtyMoneySystem.doorOffer(state: &state, balance: balance))
        case .vices:
            events.append(contentsOf: AssetsSystem.doorEngage(state: &state, balance: balance))
        case .fame:
            events.append(contentsOf: FameSystem.doorOpenFeed(state: &state, balance: balance))
        case .care:
            events.append(contentsOf: FamilyDramaSystem.doorCare(
                choice, relation: subject ?? .mother,
                state: &state, balance: balance, content: content
            ))
        }
        return events
    }

    // MARK: - The screenshot pass

    #if DEBUG
    /// `-autoDoor <kind>`: opens that door today, whatever the state says,
    /// through the same `open` a real day uses. A door already waiting is
    /// left alone; one that was answered is asked again.
    static func debugOpen(
        _ kind: DoorKind, state: inout GameState, content: ContentCatalog
    ) -> [GameEvent] {
        guard state.doors.record(kind)?.isOpen(on: state.day) != true else { return [] }
        state.doors.records.removeAll { $0.kind == kind }
        let subject: FamilyRelation? = kind == .care
            ? DoorRules.careSubject(state: state, content: content) ?? .mother
            : nil
        return open(kind, subject: subject, state: &state, content: content)
    }
    #endif
}
