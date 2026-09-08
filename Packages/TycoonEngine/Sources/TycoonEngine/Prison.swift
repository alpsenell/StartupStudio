import Foundation

// Iteration 11, wave two — W4 owns this file. Prison as a place.
//
// N1's courtroom can hand down a sentence, and until now that sentence was
// a sabbatical nobody booked: the founder was away, the caretaker ran the
// company, and the weeks passed off screen. This file is what the weeks
// are made of — a cell, a day with a choice in it, a cellmate who becomes
// somebody in the address book, a gang that offers protection, a parole
// board at the halfway mark and a wall the founder can decide to go over.
//
// **Identity at the default.** `GameState.prison` is `nil` until a court
// sentences the founder (or the debug flag serves one), it is encoded only
// while it is non-nil, and every function here is reached from exactly one
// place: `CrimeSystem.servingTime`, which itself returns on its first line
// unless `state.crime.sentenceUntilDay` is set. No bot, no fixture replay
// and no save written before this existed reaches a line of it.
//
// **Draws.** `state.socialRNG` only, and only while a sentence is running:
// one word to draw the cellmate's name, one for their face and one for
// their id when the founder arrives, one a day for whether the day's
// choice goes wrong, one an exchange at the parole board, and one for the
// wall. `rng` and `worldRNG` are never touched.
//
// Types are prefixed `Prison…` (rule 8); `PrisonState` keeps the
// scaffold's name because `GameState` was promised it.

// MARK: - The day

/// The five ways to spend a day inside. One a day; a day nobody chooses is
/// a day with the head down, which is what a day nobody chooses is.
///
/// Raw values are written into saves (`PrisonState.todayChoice`), so they
/// are stable.
public enum PrisonDayChoice: String, Codable, Equatable, Sendable, CaseIterable {
    /// Nothing. Which is the point: nothing is what keeps you out of it.
    case headDown
    /// The library. Slow, quiet, and the parole board reads the ticket.
    case library
    /// The yard. Air, a wall to lean on, and other people.
    case yard
    /// Twelve minutes on the phone in the corridor.
    case callHome
    /// The favour somebody is asking. It pays, and it is on your record.
    case theDeal

    public var displayName: String {
        switch self {
        case .headDown: "Keep your head down"
        case .library: "Work in the library"
        case .yard: "The yard"
        case .callHome: "The phone call home"
        case .theDeal: "The deal"
        }
    }

    /// The one line under the name, before the numbers.
    public var blurb: String {
        switch self {
        case .headDown: "Breakfast, lunch, lights out. Nobody learns your name."
        case .library: "Two shelves of law and a paperback with the end torn out."
        case .yard: "Forty minutes of weather and everybody watching everybody."
        case .callHome: "There is a queue for the phone and it moves once."
        case .theDeal: "Somebody needs something carried. It is not far."
        }
    }

    public var symbol: String {
        switch self {
        case .headDown: "bed.double.fill"
        case .library: "books.vertical.fill"
        case .yard: "figure.walk"
        case .callHome: "phone.fill"
        case .theDeal: "shippingbox.fill"
        }
    }

    /// Whether the day can go wrong at all. Two of the five can.
    public var canGoWrong: Bool {
        switch self {
        case .headDown, .library, .callHome: false
        case .yard, .theDeal: true
        }
    }
}

// MARK: - The gang

/// Where the founder stands with the people who run the wing.
public enum PrisonGangStance: String, Codable, Equatable, Sendable {
    /// Nobody has asked yet.
    case unasked
    /// Asked, and not answered.
    case offered
    /// In. Protection, and a favour owed on the outside.
    case joined
    /// Out. Nothing owed, and nobody standing near you in the yard.
    case refused

    public var displayName: String {
        switch self {
        case .unasked: "Nobody has asked"
        case .offered: "They have asked"
        case .joined: "In"
        case .refused: "Out"
        }
    }
}

// MARK: - The log

/// One line of the sentence, in the founder's own words. `ordinal` is the
/// entry's position, so identical states encode identically and nothing
/// here draws from an RNG.
public struct PrisonLogEntry: Codable, Equatable, Sendable, Identifiable {
    public var ordinal: Int
    public var day: Int
    public var text: String
    /// Whether this is something that happened *to* the founder rather
    /// than a day they chose.
    public var isIncident: Bool

    public var id: Int { ordinal }

    public init(ordinal: Int, day: Int, text: String, isIncident: Bool) {
        self.ordinal = ordinal
        self.day = day
        self.text = text
        self.isIncident = isIncident
    }
}

// MARK: - The state

/// The founder inside: the sentence, the days, the cellmate, the gang, the
/// record and the way out.
///
/// `nil` on `GameState` until a court sends the founder down. It survives
/// the release — `releasedDay` set, `report` filled — so the Life tab can
/// show what the weeks came to and the biography has something to quote.
/// Nothing in `PrisonSystem` reads it again once `releasedDay != nil`.
public struct PrisonState: Codable, Equatable, Sendable {
    public var sinceDay: Int
    public var untilDay: Int
    /// Weeks handed down, which is not always weeks served: parole cuts it
    /// and a failed wall doubles it.
    public var sentenceWeeks: Int
    /// Set the day the founder walks out, however they walk out.
    public var releasedDay: Int?

    // MARK: The record

    /// Things on the founder's record in here. Parole reads it.
    public var infractions: Int
    /// 0…100 with the wing. Bought in the yard and on the deal.
    public var gangStanding: Double
    public var gang: PrisonGangStance
    /// A favour owed on the outside, from joining. Cleared when it is
    /// called in.
    public var favourOwed: Bool

    // MARK: The days

    public var libraryDays: Int
    public var yardDays: Int
    public var callsHome: Int
    public var dealDays: Int
    /// The day the current choice was made, and what it was. A day the
    /// founder does not choose is served with the head down.
    public var lastChoiceDay: Int
    public var todayChoice: PrisonDayChoice?

    // MARK: The ways out

    /// The parole board sits once, at the halfway mark.
    public var paroleHeardDay: Int?
    public var paroleGranted: Bool
    /// The hearing in progress, `nil` outside it.
    public var parole: PrisonParoleHearing?
    /// One attempt, ever.
    public var escapeAttempted: Bool
    /// Over the wall and not caught. The founder is at large, the case
    /// never closes, and the sentence is not running any more.
    public var onTheRun: Bool

    // MARK: The people

    public var cellmateID: UUID?
    public var cellmateName: String
    public var cellmateSeed: UInt64
    /// 0…100, and the rapport they carry into the address book on release.
    public var cellmateBond: Double

    public var log: [PrisonLogEntry]
    /// The caretaker's report, copied out of the sabbatical slot on
    /// release so the release sheet can read it after the slot has been
    /// reused. `nil` on a run with nobody to leave the keys with.
    public var report: SabbaticalReport?

    public init(
        sinceDay: Int,
        untilDay: Int,
        sentenceWeeks: Int = 0,
        releasedDay: Int? = nil,
        infractions: Int = 0,
        gangStanding: Double = 0,
        gang: PrisonGangStance = .unasked,
        favourOwed: Bool = false,
        libraryDays: Int = 0,
        yardDays: Int = 0,
        callsHome: Int = 0,
        dealDays: Int = 0,
        lastChoiceDay: Int = 0,
        todayChoice: PrisonDayChoice? = nil,
        paroleHeardDay: Int? = nil,
        paroleGranted: Bool = false,
        parole: PrisonParoleHearing? = nil,
        escapeAttempted: Bool = false,
        onTheRun: Bool = false,
        cellmateID: UUID? = nil,
        cellmateName: String = "",
        cellmateSeed: UInt64 = 0,
        cellmateBond: Double = 0,
        log: [PrisonLogEntry] = [],
        report: SabbaticalReport? = nil
    ) {
        self.sinceDay = sinceDay
        self.untilDay = untilDay
        self.sentenceWeeks = sentenceWeeks
        self.releasedDay = releasedDay
        self.infractions = infractions
        self.gangStanding = gangStanding
        self.gang = gang
        self.favourOwed = favourOwed
        self.libraryDays = libraryDays
        self.yardDays = yardDays
        self.callsHome = callsHome
        self.dealDays = dealDays
        self.lastChoiceDay = lastChoiceDay
        self.todayChoice = todayChoice
        self.paroleHeardDay = paroleHeardDay
        self.paroleGranted = paroleGranted
        self.parole = parole
        self.escapeAttempted = escapeAttempted
        self.onTheRun = onTheRun
        self.cellmateID = cellmateID
        self.cellmateName = cellmateName
        self.cellmateSeed = cellmateSeed
        self.cellmateBond = cellmateBond
        self.log = log
        self.report = report
    }

    /// The founder is in a cell right now — the one fact the full-screen
    /// mode and every gate read.
    public var isInside: Bool { releasedDay == nil && !onTheRun }

    /// Days served so far, from `day`.
    public func daysServed(on day: Int) -> Int { max(0, min(day, untilDay) - sinceDay) }

    /// Days left, from `day`.
    public func daysLeft(from day: Int) -> Int { max(0, untilDay - day) }

    /// The whole sentence in days, never zero.
    public var lengthDays: Int { max(1, untilDay - sinceDay) }

    /// How far through, 0…1.
    public func progress(on day: Int) -> Double {
        min(1, max(0, Double(daysServed(on: day)) / Double(lengthDays)))
    }

    /// The parole board sits once the founder is halfway through and has
    /// not been heard yet.
    public func isParoleEligible(on day: Int, balance: BalanceConfig.PrisonBalance) -> Bool {
        guard isInside, paroleHeardDay == nil else { return false }
        return progress(on: day) >= balance.paroleAtProgress
    }

    /// A word for the standing, so no screen shows a bare number.
    public var standingLabel: String {
        switch gangStanding {
        case ..<10: "Nobody"
        case ..<30: "Known"
        case ..<55: "Useful"
        case ..<80: "Solid"
        default: "One of theirs"
        }
    }

    mutating func note(_ text: String, day: Int, isIncident: Bool) {
        log.append(PrisonLogEntry(
            ordinal: log.count, day: day, text: text, isIncident: isIncident
        ))
    }

    // Every field but the scaffold's three decodes if present, so a save
    // written against an earlier shape loads.
    private enum CodingKeys: String, CodingKey {
        case sinceDay, untilDay, sentenceWeeks, releasedDay
        case infractions, gangStanding, gang, favourOwed
        case libraryDays, yardDays, callsHome, dealDays, lastChoiceDay, todayChoice
        case paroleHeardDay, paroleGranted, parole, escapeAttempted, onTheRun
        case cellmateID, cellmateName, cellmateSeed, cellmateBond, log, report
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            sinceDay: try container.decode(Int.self, forKey: .sinceDay),
            untilDay: try container.decode(Int.self, forKey: .untilDay),
            sentenceWeeks: try container.decodeIfPresent(Int.self, forKey: .sentenceWeeks) ?? 0,
            releasedDay: try container.decodeIfPresent(Int.self, forKey: .releasedDay),
            infractions: try container.decodeIfPresent(Int.self, forKey: .infractions) ?? 0,
            gangStanding: try container.decodeIfPresent(Double.self, forKey: .gangStanding) ?? 0,
            gang: try container.decodeIfPresent(PrisonGangStance.self, forKey: .gang) ?? .unasked,
            favourOwed: try container.decodeIfPresent(Bool.self, forKey: .favourOwed) ?? false,
            libraryDays: try container.decodeIfPresent(Int.self, forKey: .libraryDays) ?? 0,
            yardDays: try container.decodeIfPresent(Int.self, forKey: .yardDays) ?? 0,
            callsHome: try container.decodeIfPresent(Int.self, forKey: .callsHome) ?? 0,
            dealDays: try container.decodeIfPresent(Int.self, forKey: .dealDays) ?? 0,
            lastChoiceDay: try container.decodeIfPresent(Int.self, forKey: .lastChoiceDay) ?? 0,
            todayChoice: try container.decodeIfPresent(PrisonDayChoice.self, forKey: .todayChoice),
            paroleHeardDay: try container.decodeIfPresent(Int.self, forKey: .paroleHeardDay),
            paroleGranted: try container.decodeIfPresent(Bool.self, forKey: .paroleGranted) ?? false,
            parole: try container.decodeIfPresent(PrisonParoleHearing.self, forKey: .parole),
            escapeAttempted: try container.decodeIfPresent(Bool.self, forKey: .escapeAttempted) ?? false,
            onTheRun: try container.decodeIfPresent(Bool.self, forKey: .onTheRun) ?? false,
            cellmateID: try container.decodeIfPresent(UUID.self, forKey: .cellmateID),
            cellmateName: try container.decodeIfPresent(String.self, forKey: .cellmateName) ?? "",
            cellmateSeed: try container.decodeIfPresent(UInt64.self, forKey: .cellmateSeed) ?? 0,
            cellmateBond: try container.decodeIfPresent(Double.self, forKey: .cellmateBond) ?? 0,
            log: try container.decodeIfPresent([PrisonLogEntry].self, forKey: .log) ?? [],
            report: try container.decodeIfPresent(SabbaticalReport.self, forKey: .report)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sinceDay, forKey: .sinceDay)
        try container.encode(untilDay, forKey: .untilDay)
        try container.encode(sentenceWeeks, forKey: .sentenceWeeks)
        try container.encodeIfPresent(releasedDay, forKey: .releasedDay)
        try container.encode(infractions, forKey: .infractions)
        try container.encode(gangStanding, forKey: .gangStanding)
        try container.encode(gang, forKey: .gang)
        try container.encode(favourOwed, forKey: .favourOwed)
        try container.encode(libraryDays, forKey: .libraryDays)
        try container.encode(yardDays, forKey: .yardDays)
        try container.encode(callsHome, forKey: .callsHome)
        try container.encode(dealDays, forKey: .dealDays)
        try container.encode(lastChoiceDay, forKey: .lastChoiceDay)
        try container.encodeIfPresent(todayChoice, forKey: .todayChoice)
        try container.encodeIfPresent(paroleHeardDay, forKey: .paroleHeardDay)
        try container.encode(paroleGranted, forKey: .paroleGranted)
        try container.encodeIfPresent(parole, forKey: .parole)
        try container.encode(escapeAttempted, forKey: .escapeAttempted)
        try container.encode(onTheRun, forKey: .onTheRun)
        try container.encodeIfPresent(cellmateID, forKey: .cellmateID)
        try container.encode(cellmateName, forKey: .cellmateName)
        try container.encode(cellmateSeed, forKey: .cellmateSeed)
        try container.encode(cellmateBond, forKey: .cellmateBond)
        try container.encode(log, forKey: .log)
        try container.encodeIfPresent(report, forKey: .report)
    }
}

// MARK: - The parole board

/// What the board can be told. The courtroom's five exchanges, in a small
/// room with three people in it and a folder on the table.
public enum PrisonParoleExchange: String, Codable, Equatable, Sendable, CaseIterable {
    /// The remorse they are waiting to hear.
    case remorse
    /// The company: there are people whose jobs are on the other side of
    /// this door.
    case theCompany
    /// The certificate from the library, and the ticket that came with it.
    case theCourse
    /// The family, and the weekends they have been making.
    case theFamily
    /// Nothing. Let the folder speak.
    case sayNothing

    public var displayName: String {
        switch self {
        case .remorse: "Say you're sorry"
        case .theCompany: "Talk about the company"
        case .theCourse: "Show them the certificate"
        case .theFamily: "Talk about your family"
        case .sayNothing: "Let the folder speak"
        }
    }

    public var symbol: String {
        switch self {
        case .remorse: "hand.raised.fill"
        case .theCompany: "building.2.fill"
        case .theCourse: "books.vertical.fill"
        case .theFamily: "house.fill"
        case .sayNothing: "folder.fill"
        }
    }

    /// The attribute the board grades it on.
    public var gradedOn: FounderSkill {
        switch self {
        case .remorse, .theFamily: .conversation
        case .theCompany: .leadership
        case .theCourse: .technical
        case .sayNothing: .finance
        }
    }

    /// What it is worth when it lands, and what it costs when it does not.
    /// `sayNothing` is the flat one: it neither wins nor loses much, which
    /// is why it is there.
    public var landed: Double {
        switch self {
        case .remorse: 22
        case .theCompany: 18
        case .theCourse: 20
        case .theFamily: 16
        case .sayNothing: 6
        }
    }

    public var missed: Double {
        switch self {
        case .remorse: -18
        case .theCompany: -14
        case .theCourse: -6
        case .theFamily: -9
        case .sayNothing: -3
        }
    }

    /// The line the founder says, landed or not.
    public func line(cellmateName: String, companyName: String) -> (landed: String, missed: String) {
        switch self {
        case .remorse:
            (
                "\"I did it. I have had a long time to think about why, and none of the reasons are any good.\"",
                "\"I regret the circumstances.\" The chair on the left writes one word down."
            )
        case .theCompany:
            (
                "\"There are eleven people at \(companyName) whose week I am part of. I would like to be part of it again.\"",
                "\"The company needs me.\" \"The company,\" says the chair, \"has managed.\""
            )
        case .theCourse:
            (
                "You put the certificate on the table. Somebody actually reads it.",
                "The certificate is in the folder already. They turn past it."
            )
        case .theFamily:
            (
                "\"They come on the first Saturday of the month. They have not missed one.\"",
                "\"My family—\" \"We have the visiting log,\" says the chair, kindly."
            )
        case .sayNothing:
            (
                "You say nothing. The folder is thin and dull and it is on your side.",
                "You say nothing. The folder is neither thin nor dull."
            )
        }
    }
}

/// A parole hearing in progress: three things to say, a standing, and the
/// board's face.
public struct PrisonParoleHearing: Codable, Equatable, Sendable {
    public var day: Int
    public var standing: Double
    public var exchangesLeft: Int
    public var said: [String]
    public var lastLine: String
    public var lastLanded: Bool?
    /// Set when the board has ruled.
    public var decided: Bool

    public init(
        day: Int,
        standing: Double,
        exchangesLeft: Int,
        said: [String] = [],
        lastLine: String = "",
        lastLanded: Bool? = nil,
        decided: Bool = false
    ) {
        self.day = day
        self.standing = standing
        self.exchangesLeft = exchangesLeft
        self.said = said
        self.lastLine = lastLine
        self.lastLanded = lastLanded
        self.decided = decided
    }
}

// MARK: - The arithmetic, pure

/// Everything the screens and the system both need to know, written once.
public enum Prison {
    /// The standing scale, both ways. The courtroom's, so the two rooms
    /// read the same.
    public static let standingLimit: Double = 100

    /// What a day inside does to the four meters, before anything goes
    /// wrong. Pure, so the button can print exactly what it will spend.
    public static func meterEffect(
        _ choice: PrisonDayChoice,
        balance: BalanceConfig.PrisonBalance
    ) -> (energy: Double, health: Double, mood: Double, relationships: Double) {
        switch choice {
        case .headDown:
            (balance.headDownEnergy, 0, balance.headDownMood, 0)
        case .library:
            (-balance.libraryEnergy, 0, balance.libraryMood, 0)
        case .yard:
            (balance.yardEnergy, balance.yardHealth, balance.yardMood, 0)
        case .callHome:
            (0, 0, balance.callMood, balance.callRelationships)
        case .theDeal:
            (-balance.dealEnergy, -balance.dealHealth, balance.dealMood, 0)
        }
    }

    /// What the day buys besides the meters, as a line on the button.
    public static func consequence(
        _ choice: PrisonDayChoice,
        state: PrisonState,
        balance: BalanceConfig.PrisonBalance
    ) -> String {
        let meters = meterEffect(choice, balance: balance)
        var parts: [String] = []
        func meter(_ name: String, _ value: Double) {
            guard abs(value) >= 0.05 else { return }
            parts.append("\(value > 0 ? "+" : "−")\(abs(value).prisonOneDecimal) \(name)")
        }
        meter("energy", meters.energy)
        meter("health", meters.health)
        meter("mood", meters.mood)
        meter("relationships", meters.relationships)
        switch choice {
        case .headDown:
            parts.append("nothing on your record")
        case .library:
            parts.append("the board reads the ticket")
        case .yard:
            parts.append("+\(balance.yardStanding.prisonOneDecimal) with the wing")
            parts.append("\(Int((wrongChance(choice, state: state, balance: balance) * 100).rounded()))% it goes wrong")
        case .callHome:
            parts.append("+\(balance.callAffection.prisonOneDecimal) affection")
        case .theDeal:
            parts.append("+\(balance.dealStanding.prisonOneDecimal) with the wing")
            parts.append("\(Int((wrongChance(choice, state: state, balance: balance) * 100).rounded()))% it goes on your record")
        }
        return parts.joined(separator: " · ")
    }

    /// The chance a day goes wrong. Standing with the wing buys the yard
    /// down; nothing buys the deal down very far.
    public static func wrongChance(
        _ choice: PrisonDayChoice,
        state: PrisonState,
        balance: BalanceConfig.PrisonBalance
    ) -> Double {
        guard choice.canGoWrong else { return 0 }
        let base = choice == .yard ? balance.yardTroubleChance : balance.dealTroubleChance
        let protection = state.gang == .joined
            ? balance.gangProtection
            : (state.gang == .refused ? balance.refusedPenalty : 1)
        let standing = 1 - min(0.5, state.gangStanding / 100 * balance.standingProtection)
        return min(0.9, max(0, base * protection * standing))
    }

    /// Where the board starts before anybody says anything: the record,
    /// the days spent well, and how much of the sentence is behind you.
    public static func paroleOpeningStanding(
        _ state: PrisonState,
        day: Int,
        balance: BalanceConfig.PrisonBalance
    ) -> Double {
        var standing = balance.paroleOpening
        standing -= Double(state.infractions) * balance.paroleInfractionCost
        standing += Double(state.libraryDays) * balance.paroleLibraryCredit
        standing += Double(state.callsHome) * balance.paroleCallCredit
        standing -= Double(state.dealDays) * balance.paroleDealCost
        if state.gang == .joined { standing -= balance.paroleGangCost }
        standing += (state.progress(on: day) - balance.paroleAtProgress) * balance.paroleServedCredit
        return min(standingLimit, max(-standingLimit, standing))
    }

    /// What the caretaker's company is worth to the board: a company that
    /// is still standing is a reason to let somebody out of a room.
    public static func caretakerCredit(
        opening: SabbaticalSnapshot?,
        closing: SabbaticalSnapshot,
        balance: BalanceConfig.PrisonBalance
    ) -> Double {
        guard let opening else { return 0 }
        var credit: Double = 0
        if closing.headcount >= opening.headcount { credit += balance.paroleCaretakerCredit }
        if closing.cash >= opening.cash { credit += balance.paroleCaretakerCredit }
        if closing.live > opening.live { credit += balance.paroleCaretakerCredit }
        return credit
    }

    /// How likely one thing said to the board lands.
    public static func paroleLandChance(
        _ exchange: PrisonParoleExchange,
        skill: Double,
        state: PrisonState,
        balance: BalanceConfig.PrisonBalance
    ) -> Double {
        var chance = balance.paroleLandBase + skill / balance.paroleSkillDivisor
        chance -= Double(state.infractions) * balance.paroleLandInfractionPenalty
        if exchange == .theCourse { chance += Double(state.libraryDays) * balance.paroleCourseCredit }
        if exchange == .theFamily { chance += Double(state.callsHome) * balance.paroleFamilyCredit }
        return min(0.92, max(0.08, chance))
    }

    /// The word under the bar, so the room says what it is thinking.
    public static func paroleLabel(_ standing: Double, balance: BalanceConfig.PrisonBalance) -> String {
        standing >= balance.paroleGrantStanding ? "Release" : "Serve it out"
    }

    /// The chance the wall works. One attempt, ever, and everything that
    /// makes it likelier makes the rest of the sentence worse.
    public static func escapeChance(
        _ state: PrisonState,
        day: Int,
        balance: BalanceConfig.PrisonBalance
    ) -> Double {
        var chance = balance.escapeBase
        chance += state.gangStanding / 100 * balance.escapeStandingCredit
        chance += Double(state.libraryDays) * balance.escapeLibraryCredit
        chance -= state.progress(on: day) * balance.escapeLateCost
        return min(0.6, max(0.02, chance))
    }

    /// The two lines over a release sheet: what the weeks came to, and
    /// what the caretaker made of the company while they passed.
    ///
    /// This is the sabbatical report's "inside" variant — the same
    /// numbers, the same log, a different door. `SabbaticalSystem`'s W4
    /// region calls it `prisonReportHeading`; it lives here because the
    /// sheet that reads it is in the app.
    public static func releaseHeading(
        _ report: SabbaticalReport?, weeksServed: Int
    ) -> (String, String) {
        let weeks = "\(weeksServed) week\(weeksServed == 1 ? "" : "s")"
        guard let report else {
            return ("Nobody had the keys", "\(weeks) inside, and an office that was dark for all of them.")
        }
        let name = report.caretakerName
        if !report.lost.isEmpty {
            return ("\(name) held it, mostly", "\(weeks) inside. You came back to an empty chair.")
        }
        if !report.shipped.isEmpty {
            return ("\(name) shipped without you", "\(weeks) inside, and \(report.shipped[0]) went out of the door.")
        }
        if report.closing.cash < report.opening.cash {
            return ("\(name) kept the lights on", "\(weeks) inside. It cost the company money, and it is still here.")
        }
        return ("Nothing broke", "\(weeks) inside, and the company did not notice as much as you hoped.")
    }

    /// The name of the wing's crew — one of five, chosen by the day the
    /// sentence started so it does not cost a draw.
    public static func gangName(sinceDay: Int) -> String {
        let names = ["the Landing", "the Kitchen", "D Wing", "the Old Firm", "the Committee"]
        return names[abs(sinceDay) % names.count]
    }
}

extension Double {
    /// One decimal place, for a consequence line. The engine has no
    /// formatter of the app's.
    var prisonOneDecimal: String {
        String(format: "%.1f", self)
    }
}
