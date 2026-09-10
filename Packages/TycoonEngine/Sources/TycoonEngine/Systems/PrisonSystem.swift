import Foundation
import TycoonContent

/// Iteration 11, wave two — W4. The weeks a sentence is made of.
///
/// `CrimeSystem.servingTime` hands every day of a sentence to `serve`,
/// which is the only door into this file. `serve` returns `nil` when
/// nothing is being served, and a sentence is the only thing that can set
/// `state.crime.sentenceUntilDay`, so a run that has never stood in a
/// courtroom never reaches a line of this system.
///
/// What a day is: the founder picks one of five things to do with it
/// (`.chooseInsideDay`), the day ticks, and the choice is spent — the
/// meters move, the wing's opinion moves, and two of the five can go
/// wrong. A day nobody chose is a day with the head down, which is what a
/// day nobody chose is.
///
/// **Draws.** `state.socialRNG` only: three words to draw the cellmate on
/// the day the founder arrives, one a day for whether the day went wrong,
/// one an exchange at the parole board, and one for the wall.
enum PrisonSystem {

    /// Set while the founder is inside; the `inside_` life events are
    /// gated on it, so a run that has never been sentenced draws from
    /// exactly the pool it drew from before this lane existed.
    static let servingFlag = "inside_serving"
    /// Set for the rest of the run once the founder has been inside.
    static let servedFlag = "inside_out"
    /// Set while the founder is in with the wing.
    static let gangFlag = "inside_gang"
    /// Set for the rest of the run once the founder has gone over the wall.
    static let runFlag = "inside_run"

    // MARK: - The day, handed over by `CrimeSystem.servingTime`

    /// One day of a sentence. `nil` means "there is no sentence" — the
    /// caller carries on with its own business.
    static func serve(
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) -> [GameEvent]? {
        guard let until = state.crime.sentenceUntilDay else { return nil }
        let config = balance.prison

        // Out, one way or another.
        guard state.day < until else {
            return release(&state, balance, reason: .servedIt)
        }

        // In, for the first time.
        guard var prison = state.prison, prison.isInside else {
            return [arrive(&state, balance, until: until)]
        }

        var events: [GameEvent] = []

        // 1. The day's choice, spent. Nothing chosen is the head down.
        let choice = prison.todayChoice ?? .headDown
        let meters = Prison.meterEffect(choice, balance: config)
        state.life.meters.apply(
            energy: meters.energy + config.dailyEnergy,
            health: meters.health + config.dailyHealth,
            mood: meters.mood + config.dailyMood,
            // What N1 wrote the sentence costs at home, kept: the
            // relationships meter slides faster than an absence would.
            relationships: meters.relationships - balance.crime.insideAffectionPerDay
        )
        if state.life.family.stage != .single {
            state.life.family.affection = max(0, min(100,
                state.life.family.affection + config.dailyAffection
                    + (choice == .callHome ? config.callAffection : 0)
            ))
        }

        switch choice {
        case .headDown:
            break
        case .library:
            prison.libraryDays += 1
        case .yard:
            prison.yardDays += 1
            prison.gangStanding = min(100, prison.gangStanding + config.yardStanding)
            prison.cellmateBond = min(100, prison.cellmateBond + config.cellmateBondPerYardDay)
        case .callHome:
            prison.callsHome += 1
            callHome(&state, prison: prison)
        case .theDeal:
            prison.dealDays += 1
            prison.gangStanding = min(100, prison.gangStanding + config.dealStanding)
            state.life.wallet += config.dealPay
        }
        prison.cellmateBond = min(100, prison.cellmateBond + config.cellmateBondPerDay)

        // 2. One word a day: did it go wrong. Only two of the five can.
        let wrong = Prison.wrongChance(choice, state: prison, balance: config)
        if wrong > 0, state.socialRNG.nextUniform() < wrong {
            prison.infractions += 1
            state.life.meters.apply(
                health: config.infractionHealth, mood: config.infractionMood
            )
            let line = troubleLine(choice, cellmate: prison.cellmateName)
            prison.note(line, day: state.day, isIncident: true)
            state.life.phone.post(line, from: .office, day: state.day)
            events.append(.insideTrouble(
                kind: choice.rawValue, infractions: prison.infractions, day: state.day
            ))
        } else {
            // A run of identical days is what a sentence mostly is, and a
            // log that says so three times is a log nobody reads: the
            // same day only goes in once, and the date on it is the last
            // one it happened.
            let line = dayLine(choice, cellmate: prison.cellmateName)
            if prison.log.last?.text == line, let index = prison.log.indices.last {
                prison.log[index].day = state.day
            } else {
                prison.note(line, day: state.day, isIncident: false)
            }
        }

        // 3. The wing gets round to asking.
        if prison.gang == .unasked,
           state.day - prison.sinceDay >= config.gangOfferDay {
            prison.gang = .offered
            let line = "\(prison.cellmateName) says the people who run \(Prison.gangName(sinceDay: prison.sinceDay)) would like a word about protection."
            prison.note(line, day: state.day, isIncident: true)
            state.life.phone.post(line, from: .office, day: state.day)
        }

        // 4. The board is due.
        if prison.isParoleEligible(on: state.day, balance: config),
           prison.paroleHeardDay == nil, prison.parole == nil,
           state.day - prison.sinceDay == Int((Double(prison.lengthDays) * config.paroleAtProgress).rounded()) {
            let line = "Your parole hearing is listed. Somebody hands you a form and a pen that does not work."
            prison.note(line, day: state.day, isIncident: true)
            state.life.phone.post(line, from: .office, day: state.day)
            events.append(.insideParoleListed(day: state.day))
        }

        // 5. Tomorrow is a new day, and it has not been decided yet.
        prison.todayChoice = nil
        state.prison = prison
        return events
    }

    // MARK: - Arriving

    /// The first morning: the cell, the cellmate, the flags the `inside_`
    /// events read, and the line home.
    ///
    /// Three `socialRNG` words — the name, the face, the id — and no more.
    private static func arrive(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        until: Int
    ) -> GameEvent {
        let config = balance.prison
        let names = ["Ray", "Marek", "Teddy", "Ade", "Vincent", "Curtis", "Oz", "Gordon"]
        let surnames = ["Hall", "Novak", "Boyce", "Adeyemi", "Fen", "Marsh", "Okafor", "Doyle"]
        let first = names[state.socialRNG.nextInt(in: 0...(names.count - 1))]
        let last = surnames[state.socialRNG.nextInt(in: 0...(surnames.count - 1))]
        let seed = state.socialRNG.next()
        let id = UUID(from: &state.socialRNG)

        let weeks = max(1, (until - state.day + GameState.daysPerWeek - 1) / GameState.daysPerWeek)
        var prison = PrisonState(
            sinceDay: state.day,
            untilDay: until,
            sentenceWeeks: weeks,
            cellmateID: id,
            cellmateName: "\(first) \(last)",
            cellmateSeed: seed,
            cellmateBond: config.cellmateBondStart
        )
        prison.note(
            "A landing, a door, and \(first) on the top bunk saying you can have the drawer.",
            day: state.day, isIncident: true
        )
        state.prison = prison
        state.narrative.flags.insert(servingFlag)
        state.narrative.flags.insert(servedFlag)

        state.life.phone.post(
            "\(first): \"First week is the long one. After that it's just Tuesdays.\"",
            from: .office, day: state.day
        )
        rememberInside(
            &state,
            note: "You were away, and nobody in the house would say where.",
            kind: "inside_away"
        )
        return .insideArrived(weeks: weeks, cellmate: prison.cellmateName, day: state.day)
    }

    // MARK: - Leaving

    enum PrisonExit {
        case servedIt
        case paroled
        case escaped
    }

    /// The founder is out. The sentence is cleared whatever the reason, the
    /// cellmate goes into the address book, and the caretaker's report is
    /// copied out of the sabbatical slot so the release sheet can read it
    /// after the slot has been reused.
    @discardableResult
    static func release(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        reason: PrisonExit
    ) -> [GameEvent] {
        state.crime.sentenceUntilDay = nil
        state.narrative.flags.remove(servingFlag)
        guard var prison = state.prison, prison.isInside else {
            // A sentence with no prison behind it (an old save mid-sentence,
            // say): keep N1's line and event and nothing else.
            state.life.phone.post(
                "You're out. Somebody left a cardboard box of your things at reception.",
                from: .office, day: state.day
            )
            return [.crimeReleased(day: state.day)]
        }

        let config = balance.prison
        var events: [GameEvent] = []

        if reason == .escaped {
            prison.onTheRun = true
            state.narrative.flags.insert(runFlag)
        } else {
            prison.releasedDay = state.day
            prison.report = state.life.sabbatical?.report
            // Whatever the library was worth, it is worth it on the way out.
            let earned = Double(prison.libraryDays / max(1, config.librarySkillEveryDays))
                * config.librarySkillPoints
            if earned > 0 {
                state.life.skills.finance = min(100, state.life.skills.finance + earned)
            }
            // The person from the top bunk is somebody the founder knows now.
            if let contact = cellmateContact(prison, day: state.day, balance: balance) {
                state.networking.contacts.append(contact)
            }
            state.life.phone.post(
                releaseLine(reason, weeks: prison.sentenceWeeks),
                from: .office, day: state.day
            )
            rememberInside(
                &state,
                note: reason == .paroled
                    ? "You came home early. Nobody asked where from."
                    : "You came home. There was a cake and nobody said what it was for.",
                kind: "inside_home"
            )
            events.append(.insideReleased(
                weeksServed: max(1, prison.daysServed(on: state.day) / GameState.daysPerWeek),
                paroled: reason == .paroled,
                day: state.day
            ))
            events.append(.crimeReleased(day: state.day))
        }
        state.prison = prison

        // Parole and the wall both end the away window early; a sentence
        // served out ends it on its own day, and `LifeSystem` has already
        // done it.
        if reason != .servedIt {
            state.life.awayUntilDay = reason == .escaped ? state.life.awayUntilDay : nil
            state.life.awaySinceDay = reason == .escaped ? state.life.awaySinceDay : nil
            if reason == .escaped {
                state.life.awayReason = onTheRunReason
            } else {
                state.life.awayReason = nil
                events.append(.founderBack(day: state.day))
            }
        }
        return events
    }

    /// The reason on `life.awayReason` while the founder is at large.
    static let onTheRunReason = "On the run"

    private static func releaseLine(_ reason: PrisonExit, weeks: Int) -> String {
        switch reason {
        case .servedIt:
            "You're out. Somebody left a cardboard box of your things at reception."
        case .paroled:
            "You're out early. The form says you are to keep an address and a job."
        case .escaped:
            "Nobody knows where you are, which is the point."
        }
    }

    /// The cellmate as an address-book entry: the face they had inside, the
    /// rapport the weeks earned, and no company.
    private static func cellmateContact(
        _ prison: PrisonState,
        day: Int,
        balance: BalanceConfig
    ) -> Contact? {
        guard let id = prison.cellmateID, !prison.cellmateName.isEmpty else { return nil }
        return Contact(
            id: id,
            name: prison.cellmateName,
            appearanceSeed: prison.cellmateSeed,
            archetype: .inmate,
            skills: SkillSet(coding: 20, design: 20, marketing: 35),
            askingSalary: balance.salaryBase,
            rapport: min(100, prison.cellmateBond),
            interest: 0,
            metDay: prison.sinceDay,
            lastMetDay: day,
            isRevealed: true
        )
    }

    // MARK: - The gang

    /// In or out. One button, once, and both answers cost something.
    static func answerGang(
        joining: Bool,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard var prison = state.prison, prison.isInside, prison.gang == .offered else { return [] }
        let config = balance.prison
        if joining {
            prison.gang = .joined
            prison.gangStanding = min(100, prison.gangStanding + config.gangJoinStanding)
            prison.favourOwed = true
            state.narrative.flags.insert(gangFlag)
            prison.note(
                "You said yes. Nobody shook your hand and everybody knew by lunch.",
                day: state.day, isIncident: true
            )
        } else {
            prison.gang = .refused
            prison.gangStanding = max(0, prison.gangStanding + config.refusedStanding)
            prison.note(
                "You said no, politely, twice. The yard got wider.",
                day: state.day, isIncident: true
            )
        }
        state.prison = prison
        return [.insideGangAnswered(joined: joining, day: state.day)]
    }

    // MARK: - The day's choice

    /// The founder decides what today is. One a day; choosing again
    /// replaces it, because nothing has been spent until the day ticks.
    static func choose(
        _ choice: PrisonDayChoice,
        state: inout GameState
    ) -> [GameEvent] {
        guard var prison = state.prison, prison.isInside else { return [] }
        prison.todayChoice = choice
        prison.lastChoiceDay = state.day
        state.prison = prison
        return [.insideDayChosen(choice: choice.rawValue, day: state.day)]
    }

    // MARK: - The parole board

    /// Opens the hearing. The opening standing is the record, read out.
    static func openParole(
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard var prison = state.prison, prison.isInside, prison.parole == nil,
              prison.isParoleEligible(on: state.day, balance: balance.prison)
        else { return [] }
        let config = balance.prison
        var standing = Prison.paroleOpeningStanding(prison, day: state.day, balance: config)
        standing += Prison.caretakerCredit(
            opening: state.life.sabbatical?.opening,
            closing: SabbaticalSnapshot(state),
            balance: config
        )
        prison.parole = PrisonParoleHearing(
            day: state.day,
            standing: min(Prison.standingLimit, max(-Prison.standingLimit, standing)),
            exchangesLeft: config.paroleExchanges,
            lastLine: "\"You have read the file. Is there anything in it that is wrong?\""
        )
        state.prison = prison
        // MARK: J6 (queue)
        // A room the player's own action opened: `GameEngine.send` stops the
        // clock through `PausePolicy.roomPausingEvents`, with the reason kept.
        // MARK: end J6
        return [.insideParoleOpened(day: state.day)]
    }

    /// One thing said to the board. One `socialRNG` word, whatever is said.
    static func say(
        _ exchange: PrisonParoleExchange,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard var prison = state.prison, var hearing = prison.parole,
              hearing.exchangesLeft > 0, !hearing.decided
        else { return [] }
        let config = balance.prison
        let chance = Prison.paroleLandChance(
            exchange,
            skill: state.life.skills.crimeValue(for: exchange.gradedOn),
            state: prison,
            balance: config
        )
        let landed = state.socialRNG.nextUniform() < chance
        hearing.standing = min(Prison.standingLimit, max(
            -Prison.standingLimit,
            hearing.standing + (landed ? exchange.landed : exchange.missed)
        ))
        let lines = exchange.line(
            cellmateName: prison.cellmateName, companyName: state.company.name
        )
        hearing.lastLine = landed ? lines.landed : lines.missed
        hearing.lastLanded = landed
        hearing.exchangesLeft -= 1
        hearing.said.append(exchange.rawValue)
        prison.parole = hearing
        state.prison = prison
        return [.insideParoleSaid(
            exchange: exchange.rawValue, landed: landed, day: state.day
        )]
    }

    /// The board rules. Granted, the founder walks out today; refused, the
    /// sentence runs to its day and there is no second hearing.
    static func decideParole(
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard var prison = state.prison, let hearing = prison.parole, !hearing.decided
        else { return [] }
        let config = balance.prison
        let granted = hearing.standing >= config.paroleGrantStanding
        prison.parole = nil
        prison.paroleHeardDay = state.day
        prison.paroleGranted = granted
        prison.note(
            granted
                ? "They let you out. The chair on the left says \"do not make me wrong.\""
                : "They did not let you out. The folder closes with the sound folders make.",
            day: state.day, isIncident: true
        )
        state.prison = prison
        var events: [GameEvent] = [.insideParoleDecided(granted: granted, day: state.day)]
        if granted {
            events.append(contentsOf: release(&state, balance, reason: .paroled))
        } else {
            state.life.phone.post(
                "The board said no. There is no second board.",
                from: .partner, day: state.day
            )
        }
        return events
    }

    // MARK: - The wall

    /// One attempt, ever. Failure doubles what is left; success is a life
    /// on the run and a case nobody ever lists.
    static func attemptEscape(
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard var prison = state.prison, prison.isInside, !prison.escapeAttempted,
              let until = state.crime.sentenceUntilDay
        else { return [] }
        let config = balance.prison
        let chance = Prison.escapeChance(prison, day: state.day, balance: config)
        prison.escapeAttempted = true
        let made = state.socialRNG.nextUniform() < chance

        if made {
            prison.note(
                "A laundry van, a gate that stays open eleven seconds, and a road.",
                day: state.day, isIncident: true
            )
            state.prison = prison
            state.crime.notoriety = min(100, state.crime.notoriety + config.escapeNotoriety)
            openTheCaseThatNeverCloses(&state)
            state.life.phone.post(
                "There is a photograph of you on the news and it is the one from the website.",
                from: .office, day: state.day
            )
            var events: [GameEvent] = [.insideEscape(succeeded: true, day: state.day)]
            events.append(contentsOf: release(&state, balance, reason: .escaped))
            return events
        }

        let left = max(GameState.daysPerWeek, until - state.day)
        let extended = state.day + Int(Double(left) * config.escapeFailureSentenceFactor)
        state.crime.sentenceUntilDay = extended
        prison.untilDay = extended
        prison.sentenceWeeks += max(1, (extended - until) / GameState.daysPerWeek)
        prison.infractions += config.escapeFailureInfractions
        prison.note(
            "You got as far as the second gate. They doubled it, and they were not even angry.",
            day: state.day, isIncident: true
        )
        state.prison = prison
        // The away window and the caretaker's weeks run to the new day too.
        state.life.awayUntilDay = extended
        if var sabbatical = state.life.sabbatical, sabbatical.isActive {
            sabbatical.untilDay = extended
            sabbatical.note(
                "The date they told me changed. Nobody will say why.",
                day: state.day, isDecision: false
            )
            state.life.sabbatical = sabbatical
        }
        state.life.meters.apply(health: -6, mood: -12)
        state.life.phone.post(
            "They found you at the second gate. It is longer now.",
            from: .office, day: state.day
        )
        return [.insideEscape(succeeded: false, day: state.day)]
    }

    /// A charge that is listed for a day nobody will reach: while the
    /// founder is at large there is nothing to hear, and the case sits on
    /// the record for the rest of the run.
    private static func openTheCaseThatNeverCloses(_ state: inout GameState) {
        let id = "case-escape-\(state.day)"
        guard !state.crime.cases.contains(where: { $0.id == id }) else { return }
        state.crime.cases.append(LegalCase(
            id: id,
            kind: "escape",
            raisedDay: state.day,
            hearingDay: state.day + 99_999,
            evidence: 1
        ))
        state.narrative.flags.insert(CrimeSystem.caseFlag)
    }

    // MARK: - Beginning one

    /// A sentence, handed down. The verdict's own path (`CrimeSystem`)
    /// calls `SabbaticalSystem.crimeBeginSentence` and sets
    /// `sentenceUntilDay` itself; this is the same two lines for the debug
    /// flag, so `-autoInside 8` walks the same road a verdict does.
    static func beginSentence(
        weeks: Int,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard state.crime.sentenceUntilDay == nil, state.prison?.isInside != true else { return [] }
        let weeks = max(1, weeks)
        state.crime.sentenceUntilDay = state.day + weeks * GameState.daysPerWeek
        var events = SabbaticalSystem.crimeBeginSentence(
            weeks: weeks, state: &state, balance: balance
        )
        events.append(arrive(
            &state, balance, until: state.crime.sentenceUntilDay ?? state.day
        ))
        return events
    }

    // MARK: - Small things

    /// The phone call home: the partner or the eldest child, whoever there
    /// is, and the line they say back.
    private static func callHome(_ state: inout GameState, prison: PrisonState) {
        if let child = state.life.family.children.last {
            state.life.phone.post(
                "\(child.name): \"Are you coming to the thing? It's fine if you're not.\"",
                from: .child(child.id), day: state.day
            )
        } else if state.life.family.stage != .single {
            state.life.phone.post(
                "\"Twelve minutes. I counted. Same time Thursday.\"",
                from: .partner, day: state.day
            )
        } else {
            state.life.phone.post(
                "You called the office. Somebody put you on speaker and everybody said hello at once.",
                from: .office, day: state.day
            )
        }
    }

    /// What the children put in the ledger about all this. `ChildhoodSystem`
    /// owns the kinds it writes; these two are the lane's own strings,
    /// which the ledger stores as freely as it stores anybody else's.
    private static func rememberInside(_ state: inout GameState, note: String, kind: String) {
        for index in state.life.family.children.indices {
            state.life.family.children[index].memories.append(
                ChildMemory(day: state.day, kind: kind, note: note)
            )
        }
    }

    private static func dayLine(_ choice: PrisonDayChoice, cellmate: String) -> String {
        switch choice {
        case .headDown: "A day with nothing in it. That is the good kind."
        case .library: "Two hours in the library. The law is duller than you hoped."
        case .yard: "Forty minutes in the yard, walking the long way round."
        case .callHome: "Twelve minutes on the phone, and eight of them were the queue."
        case .theDeal: "You carried something from one landing to another and did not look at it."
        }
    }

    private static func troubleLine(_ choice: PrisonDayChoice, cellmate: String) -> String {
        switch choice {
        case .yard:
            "Something started in the yard. You were near it, which is the same as being in it."
        case .theDeal:
            "The wing got turned over and they found what you were carrying. \(cellmate) says nothing."
        default:
            "It got written down. Everything in here gets written down."
        }
    }
}
