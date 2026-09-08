import Foundation

// Iteration 11 — N1 owns this file. The founder's notoriety, the shady
// things they did, the case against them and the courtroom.
//
// Wave two (dirty money, espionage, family drama, prison) reads
// `CrimeState.notoriety` (0…100) and `CrimeState.cases`, so those two keep
// their names and their meaning whatever else moves here.
//
// **Identity at the default.** `GameState.crime` is `.empty` until the
// player presses one of six buttons, it is encoded only while it is
// non-empty, and `CrimeSystem` returns on the first line of its tick
// while it is empty. Nothing in this file is reached by a pacing bot, a
// fixture replay or a save written before it existed. Every offence's
// gain is a balance number that is only ever *added* to something, and it
// is added exactly once, at the moment the player commits — there is no
// multiplier anywhere that a clean run passes through.
//
// **Draws.** `socialRNG` only, and only while the record is non-empty:
// one word a week for the discovery sweep (one per entry), one an
// exchange in the courtroom, one for the NDA poach and one for the
// planted story. `rng` and `worldRNG` are never touched.
//
// Types here are prefixed `Crime…` (rule 8); `LegalCase` keeps the
// scaffold's name because wave two was promised it.

// MARK: - The six offences

/// The six things a founder can do that they should not.
///
/// Each is a real action with a priced gain, a notoriety cost and a
/// weekly chance of being found out. The raw values are written into
/// saves (`CrimeRecordEntry.offence`, `LegalCase.kind`), so they are
/// stable.
public enum CrimeOffence: String, Codable, Equatable, Sendable, CaseIterable {
    /// The quarter's numbers, rewritten upwards. Investors read them.
    case cookBooks
    /// A creative return: the quarter's tax bill, halved.
    case dodgeTaxes
    /// A rival's senior engineer, out from under a non-compete.
    case ndaPoach
    /// An envelope, and a review that comes back a notch kinder.
    case bribeJournalist
    /// A demo that only works in the video.
    case fakeDemo
    /// A story about a rival, placed with somebody who owed you.
    case plantStory
    // MARK: W1 (dirty money) — the seventh
    /// Money that went out through a backer and came back clean.
    /// Committed by `DirtyMoneySystem`, never by a button of N1's.
    case launderMoney
    // MARK: end of W1

    public var displayName: String {
        switch self {
        case .cookBooks: "Cook the books"
        case .dodgeTaxes: "Dodge the tax"
        case .ndaPoach: "The NDA poach"
        case .bribeJournalist: "Bribe a journalist"
        case .fakeDemo: "Fake the demo"
        case .plantStory: "Plant a story"
        // MARK: W1
        case .launderMoney: "Wash it"
        // MARK: end of W1
        }
    }

    /// The one-line pitch on the button, before the numbers.
    public var pitch: String {
        switch self {
        case .cookBooks: "Move next quarter's revenue into this one. Nobody counts twice."
        case .dodgeTaxes: "File it creatively. Everyone does; most of them are better at it."
        case .ndaPoach: "They signed a non-compete. Non-competes are paper."
        case .bribeJournalist: "Buy the reviewer a very good lunch, and a car."
        case .fakeDemo: "Record the demo. Nobody has to know it was recorded."
        case .plantStory: "Give a friendly desk a document you shouldn't have."
        // MARK: W1
        case .launderMoney: "Put it through them. It comes back the right colour."
        // MARK: end of W1
        }
    }

    /// What the record calls it, in the founder's own diary.
    public var recordLine: String {
        switch self {
        case .cookBooks: "You signed a set of accounts you knew were wrong."
        case .dodgeTaxes: "You filed a return that was, at best, imaginative."
        case .ndaPoach: "You hired somebody you knew you could not hire."
        case .bribeJournalist: "You paid for a review and got one."
        case .fakeDemo: "You showed a demo that did not exist."
        case .plantStory: "You put a story about a rival where it would be found."
        // MARK: W1
        case .launderMoney: "You moved money through people who move money."
        // MARK: end of W1
        }
    }

    /// What the prosecution calls it.
    public var chargeName: String {
        switch self {
        case .cookBooks: "false accounting"
        case .dodgeTaxes: "tax fraud"
        case .ndaPoach: "inducing a breach of contract"
        case .bribeJournalist: "commercial bribery"
        case .fakeDemo: "misrepresentation"
        case .plantStory: "malicious falsehood"
        // MARK: W1
        case .launderMoney: "money laundering"
        // MARK: end of W1
        }
    }

    /// Who comes for you when it surfaces.
    public var accuser: String {
        switch self {
        case .cookBooks: "An auditor"
        case .dodgeTaxes: "The revenue service"
        case .ndaPoach: "A rival's lawyer"
        case .bribeJournalist: "The outlet's own editor"
        case .fakeDemo: "A customer, and then forty of them"
        case .plantStory: "The studio you wrote about"
        // MARK: W1
        case .launderMoney: "A bank's compliance desk"
        // MARK: end of W1
        }
    }

    /// SF Symbol for the row.
    public var symbol: String {
        switch self {
        case .cookBooks: "book.closed.fill"
        case .dodgeTaxes: "percent"
        case .ndaPoach: "person.badge.shield.checkmark.fill"
        case .bribeJournalist: "envelope.badge.fill"
        case .fakeDemo: "play.rectangle.fill"
        case .plantStory: "newspaper.fill"
        // MARK: W1
        case .launderMoney: "arrow.triangle.2.circlepath.circle.fill"
        // MARK: end of W1
        }
    }

    /// How bad a court thinks it is, 0…1. Scales the fine, the settlement
    /// and the sentence.
    public var gravity: Double {
        switch self {
        case .cookBooks: 0.9
        case .dodgeTaxes: 0.8
        case .ndaPoach: 0.45
        case .bribeJournalist: 0.5
        case .fakeDemo: 0.65
        case .plantStory: 0.6
        // MARK: W1 — the gravest of the seven: it is the one with a
        // counterparty who will also be standing in the room.
        case .launderMoney: 1.0
        // MARK: end of W1
        }
    }
}

// MARK: - Why an offence was refused

/// Rule 7: a refused action says why, in the founder's words.
public enum CrimeRefusal: String, Sendable, Equatable, CaseIterable {
    /// A case is pending; the last thing you need is a second one.
    case casePending
    /// You are already inside.
    case away
    /// Not enough in the personal wallet for the envelope.
    case noWallet
    /// There is no quarter's trading to lie about yet.
    case nothingToDeclare
    /// No rival studio to steal from or write about.
    case noRival
    /// Nothing in development to fake.
    case noBuild
    /// This one is already running.
    case alreadyRunning
    /// Once a quarter is once a quarter.
    case tooSoon

    public var sentence: String {
        switch self {
        case .casePending: "You have a hearing on the books. Do it after, if you still want to."
        case .away: "You're not at your desk, and this needs your signature."
        case .noWallet: "This is cash out of your own pocket, and your pocket is empty."
        case .nothingToDeclare: "There's no trading quarter to lie about yet."
        case .noRival: "Nobody to do it to. The field is empty."
        case .noBuild: "Nothing in development to put in front of a camera."
        case .alreadyRunning: "That one's already running. Let it land first."
        case .tooSoon: "You did this last quarter. Doing it again this soon is not clever, it's a pattern."
        }
    }
}

// MARK: - The record

/// One thing the founder did, and whether the world has found it yet.
public struct CrimeRecordEntry: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var offence: CrimeOffence
    public var day: Int
    /// What it was worth, in dollars where that means anything and in
    /// points where it does not. Shown on the record and read by the
    /// settlement price.
    public var gain: Int
    /// One line about what it actually bought, for the record and the
    /// courtroom's evidence bundle.
    public var note: String
    /// Set once this entry is the subject of a case.
    public var discoveredDay: Int?
    /// Set once a court has dealt with it — an entry answered for is not
    /// rolled for again.
    public var settledDay: Int?

    public init(
        id: String,
        offence: CrimeOffence,
        day: Int,
        gain: Int,
        note: String,
        discoveredDay: Int? = nil,
        settledDay: Int? = nil
    ) {
        self.id = id
        self.offence = offence
        self.day = day
        self.gain = gain
        self.note = note
        self.discoveredDay = discoveredDay
        self.settledDay = settledDay
    }

    /// Still exposed: not answered for, and not already in front of a
    /// judge.
    public var isOpen: Bool { settledDay == nil && discoveredDay == nil }
}

// MARK: - The lawyer and the defence

/// Three tiers of representation, bought out of the founder's own wallet.
public enum CrimeLawyer: String, Codable, Equatable, Sendable, CaseIterable {
    /// Whoever the court appoints.
    case dutySolicitor
    /// A competent high-street firm.
    case highStreet
    /// The one whose name is on the building.
    case silk

    public var displayName: String {
        switch self {
        case .dutySolicitor: "Duty solicitor"
        case .highStreet: "High-street firm"
        case .silk: "The one on the building"
        }
    }

    public var blurb: String {
        switch self {
        case .dutySolicitor: "Free, tired, and reading your file in the corridor."
        case .highStreet: "Reads everything twice. Will not be theatrical."
        case .silk: "Bills by the sentence. Worth every sentence."
        }
    }

    /// How much of the courtroom's grade the lawyer carries. Zero is the
    /// founder alone.
    public var weight: Double {
        switch self {
        case .dutySolicitor: 0
        case .highStreet: 0.18
        case .silk: 0.38
        }
    }

    /// Objections available in the hearing.
    public var objections: Int {
        switch self {
        case .dutySolicitor: 0
        case .highStreet: 1
        case .silk: 2
        }
    }

    public static let ladder: [CrimeLawyer] = [.dutySolicitor, .highStreet, .silk]
}

/// What the founder decided to argue, picked before the hearing.
public enum CrimeDefence: String, Codable, Equatable, Sendable, CaseIterable {
    /// It never happened.
    case itNeverHappened
    /// It happened and it was legal.
    case everybodyDoesThis
    /// It happened and somebody else did it.
    case notMyDepartment
    /// It happened, it was me, and I am sorry.
    case fullCooperation

    public var displayName: String {
        switch self {
        case .itNeverHappened: "It never happened"
        case .everybodyDoesThis: "Everybody does this"
        case .notMyDepartment: "Not my department"
        case .fullCooperation: "Full cooperation"
        }
    }

    public var blurb: String {
        switch self {
        case .itNeverHappened: "Deny the lot. Enormous upside, no floor under it."
        case .everybodyDoesThis: "Argue the industry, not the act. Steady either way."
        case .notMyDepartment: "It was signed downstairs. Works, and costs you the room."
        case .fullCooperation: "Hands up. The ceiling is low and so is the floor."
        }
    }

    /// Which exchange this defence rewards, and by how much.
    public var favours: CrimeExchange {
        switch self {
        case .itNeverHappened: .deny
        case .everybodyDoesThis: .explain
        case .notMyDepartment: .blameTheCFO
        case .fullCooperation: .apologise
        }
    }

    /// Standing the founder walks in with, before a word is said. A denial
    /// starts low and a confession starts level.
    public var openingStanding: Double {
        switch self {
        case .itNeverHappened: -14
        case .everybodyDoesThis: -4
        case .notMyDepartment: -8
        case .fullCooperation: 6
        }
    }

    /// How far the verdict can swing under this defence. Denial is the
    /// wide one.
    public var swing: Double {
        switch self {
        case .itNeverHappened: 1.35
        case .everybodyDoesThis: 1.0
        case .notMyDepartment: 1.1
        case .fullCooperation: 0.75
        }
    }
}

/// The five things the founder can say from the box.
public enum CrimeExchange: String, Codable, Equatable, Sendable, CaseIterable {
    case deny, explain, apologise, blameTheCFO, objection

    public var displayName: String {
        switch self {
        case .deny: "Deny it"
        case .explain: "Explain the numbers"
        case .apologise: "Apologise"
        case .blameTheCFO: "Blame the CFO"
        case .objection: "Let the lawyer object"
        }
    }

    public var symbol: String {
        switch self {
        case .deny: "hand.raised.fill"
        case .explain: "chart.bar.doc.horizontal.fill"
        case .apologise: "heart.text.square.fill"
        case .blameTheCFO: "arrow.turn.down.right"
        case .objection: "exclamationmark.bubble.fill"
        }
    }

    /// The attribute the room grades this on.
    public var gradedOn: FounderSkill {
        switch self {
        case .deny: .conversation
        case .explain: .finance
        case .apologise: .conversation
        case .blameTheCFO: .leadership
        case .objection: .conversation
        }
    }

    /// What a landed exchange is worth, before the defence and the lawyer.
    public var reward: Double {
        switch self {
        case .deny: 26
        case .explain: 18
        case .apologise: 14
        case .blameTheCFO: 22
        case .objection: 20
        }
    }

    /// What a missed one costs, as a fraction of the reward. Denying badly
    /// is the expensive mistake in the room.
    public var missFactor: Double {
        switch self {
        case .deny: 1.15
        case .explain: 0.6
        case .apologise: 0.35
        case .blameTheCFO: 1.0
        case .objection: 0.5
        }
    }

    /// What it does to the room's opinion of you outside the verdict —
    /// blaming the CFO is free in law and expensive at the office.
    public var moraleCost: Double {
        self == .blameTheCFO ? 6 : 0
    }
}

// MARK: - The verdict

/// How a hearing ended.
public enum CrimeVerdict: String, Codable, Equatable, Sendable, CaseIterable {
    case acquitted
    case fine
    case settlement
    case sentence

    public var displayName: String {
        switch self {
        case .acquitted: "Acquitted"
        case .fine: "Fined"
        case .settlement: "Settled"
        case .sentence: "Sentenced"
        }
    }

    public var isGood: Bool { self == .acquitted }
}

/// The hearing in progress: three exchanges in front of a judge.
public struct CrimeHearing: Codable, Equatable, Sendable {
    /// The case this is about.
    public var caseID: String
    public var openedDay: Int
    public var exchangesLeft: Int
    public var exchangesTaken: Int
    /// Objections the lawyer has left.
    public var objectionsLeft: Int
    /// −100…100. Below zero the bench is against you.
    public var standing: Double
    /// The last thing said across the table.
    public var lastLine: String
    /// Who said it: `true` when it was the prosecutor answering.
    public var lastLanded: Bool?

    public init(
        caseID: String,
        openedDay: Int,
        exchangesLeft: Int,
        exchangesTaken: Int = 0,
        objectionsLeft: Int,
        standing: Double,
        lastLine: String,
        lastLanded: Bool? = nil
    ) {
        self.caseID = caseID
        self.openedDay = openedDay
        self.exchangesLeft = exchangesLeft
        self.exchangesTaken = exchangesTaken
        self.objectionsLeft = objectionsLeft
        self.standing = standing
        self.lastLine = lastLine
        self.lastLanded = lastLanded
    }
}

/// A pending legal case: who brought it, what for, and when it is heard.
///
/// The scaffold's four fields keep their names and meaning; everything
/// after them is N1's, decoded with a default so a case written by wave
/// two's raise-a-case seam still loads.
public struct LegalCase: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    /// What it is about — the `CrimeOffence` raw value for a case the
    /// world raised against the founder, or `"suit"` for one the founder
    /// brought.
    public var kind: String
    public var raisedDay: Int
    public var hearingDay: Int

    // MARK: N1's half

    /// The record entry this case is about, when there is one.
    public var entryID: String?
    /// The rival on the other side: the studio suing you over the poach or
    /// the story, or the studio you are suing.
    public var rivalID: UUID?
    /// True when the founder brought this one.
    public var isFounderSuing: Bool
    /// Bought representation. Nothing until the founder pays.
    public var lawyer: CrimeLawyer
    /// The line the founder decided to run. Nothing until they pick.
    public var defence: CrimeDefence?
    /// What the other side will take to make it go away today.
    public var settlementPrice: Int
    /// How much paper the other side has, 0…1. Grows with the offence's
    /// gravity and shrinks with the entry's age and a Legal department.
    public var evidence: Double
    /// Set once the hearing has happened.
    public var verdict: CrimeVerdict?
    /// Money the verdict cost, and the sentence in weeks. Zero when there
    /// was neither.
    public var penalty: Int
    public var sentenceWeeks: Int
    /// Set when the founder paid the other side off before the hearing.
    public var settledDay: Int?

    public init(
        id: String,
        kind: String,
        raisedDay: Int,
        hearingDay: Int,
        entryID: String? = nil,
        rivalID: UUID? = nil,
        isFounderSuing: Bool = false,
        lawyer: CrimeLawyer = .dutySolicitor,
        defence: CrimeDefence? = nil,
        settlementPrice: Int = 0,
        evidence: Double = 0.5,
        verdict: CrimeVerdict? = nil,
        penalty: Int = 0,
        sentenceWeeks: Int = 0,
        settledDay: Int? = nil
    ) {
        self.id = id
        self.kind = kind
        self.raisedDay = raisedDay
        self.hearingDay = hearingDay
        self.entryID = entryID
        self.rivalID = rivalID
        self.isFounderSuing = isFounderSuing
        self.lawyer = lawyer
        self.defence = defence
        self.settlementPrice = settlementPrice
        self.evidence = evidence
        self.verdict = verdict
        self.penalty = penalty
        self.sentenceWeeks = sentenceWeeks
        self.settledDay = settledDay
    }

    /// The offence behind a case the world raised, when there is one.
    public var offence: CrimeOffence? { CrimeOffence(rawValue: kind) }

    /// Still to be heard.
    public var isPending: Bool { verdict == nil && settledDay == nil }

    /// Days until the hearing, never below zero.
    public func daysToHearing(from day: Int) -> Int { max(0, hearingDay - day) }

    private enum CodingKeys: String, CodingKey {
        case id, kind, raisedDay, hearingDay
        case entryID, rivalID, isFounderSuing, lawyer, defence, settlementPrice
        case evidence, verdict, penalty, sentenceWeeks, settledDay
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            kind: try container.decode(String.self, forKey: .kind),
            raisedDay: try container.decode(Int.self, forKey: .raisedDay),
            hearingDay: try container.decode(Int.self, forKey: .hearingDay),
            entryID: try container.decodeIfPresent(String.self, forKey: .entryID),
            rivalID: try container.decodeIfPresent(UUID.self, forKey: .rivalID),
            isFounderSuing: try container.decodeIfPresent(Bool.self, forKey: .isFounderSuing) ?? false,
            lawyer: try container.decodeIfPresent(CrimeLawyer.self, forKey: .lawyer) ?? .dutySolicitor,
            defence: try container.decodeIfPresent(CrimeDefence.self, forKey: .defence),
            settlementPrice: try container.decodeIfPresent(Int.self, forKey: .settlementPrice) ?? 0,
            evidence: try container.decodeIfPresent(Double.self, forKey: .evidence) ?? 0.5,
            verdict: try container.decodeIfPresent(CrimeVerdict.self, forKey: .verdict),
            penalty: try container.decodeIfPresent(Int.self, forKey: .penalty) ?? 0,
            sentenceWeeks: try container.decodeIfPresent(Int.self, forKey: .sentenceWeeks) ?? 0,
            settledDay: try container.decodeIfPresent(Int.self, forKey: .settledDay)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(raisedDay, forKey: .raisedDay)
        try container.encode(hearingDay, forKey: .hearingDay)
        try container.encodeIfPresent(entryID, forKey: .entryID)
        try container.encodeIfPresent(rivalID, forKey: .rivalID)
        if isFounderSuing { try container.encode(isFounderSuing, forKey: .isFounderSuing) }
        if lawyer != .dutySolicitor { try container.encode(lawyer, forKey: .lawyer) }
        try container.encodeIfPresent(defence, forKey: .defence)
        try container.encode(settlementPrice, forKey: .settlementPrice)
        try container.encode(evidence, forKey: .evidence)
        try container.encodeIfPresent(verdict, forKey: .verdict)
        if penalty != 0 { try container.encode(penalty, forKey: .penalty) }
        if sentenceWeeks != 0 { try container.encode(sentenceWeeks, forKey: .sentenceWeeks) }
        try container.encodeIfPresent(settledDay, forKey: .settledDay)
    }
}

// MARK: - The state

public struct CrimeState: Codable, Equatable, Sendable {
    /// 0…100. How much the world suspects the founder. Decays slowly.
    public var notoriety: Double
    /// Cases raised. Heard ones stay for the record, capped.
    public var cases: [LegalCase]
    /// What was done and when — the record the courtroom reads.
    public var record: [CrimeRecordEntry]
    /// The hearing on right now, if the founder is standing in one.
    public var hearing: CrimeHearing?
    /// While `day < booksCookedUntilDay` a term sheet arrives inflated.
    public var booksCookedUntilDay: Int?
    /// Outlet names holding an envelope: the next launch's review from
    /// each comes back a notch kinder, once.
    public var bribedOutlets: [String]
    /// Product ids whose demo was faked, and the day it was faked, so a
    /// launch inside the fortnight collapses. Encoded sorted.
    public var fakedDemos: [String: Int]
    /// The last day each offence was committed, so the once-a-quarter
    /// offences can say no. Encoded sorted.
    public var lastCommitted: [String: Int]
    /// The last day the weekly sweep ran, so a save loaded mid-week does
    /// not roll twice.
    public var lastSweepDay: Int?
    /// Weeks of sentence still to serve, set when a verdict sends the
    /// founder away. Wave two's *Inside* lane reads it.
    public var sentenceUntilDay: Int?

    public init(
        notoriety: Double = 0,
        cases: [LegalCase] = [],
        record: [CrimeRecordEntry] = [],
        hearing: CrimeHearing? = nil,
        booksCookedUntilDay: Int? = nil,
        bribedOutlets: [String] = [],
        fakedDemos: [String: Int] = [:],
        lastCommitted: [String: Int] = [:],
        lastSweepDay: Int? = nil,
        sentenceUntilDay: Int? = nil
    ) {
        self.notoriety = notoriety
        self.cases = cases
        self.record = record
        self.hearing = hearing
        self.booksCookedUntilDay = booksCookedUntilDay
        self.bribedOutlets = bribedOutlets
        self.fakedDemos = fakedDemos
        self.lastCommitted = lastCommitted
        self.lastSweepDay = lastSweepDay
        self.sentenceUntilDay = sentenceUntilDay
    }

    public static let empty = CrimeState()

    /// A record is kept this long before the oldest entries fall off.
    static let maxRecord = 24
    /// Cases kept for the history.
    static let maxCases = 12

    /// The case waiting to be heard, if any. At most one at a time.
    public var pendingCase: LegalCase? { cases.first { $0.isPending } }

    /// Entries still exposed to a discovery roll.
    public var openRecord: [CrimeRecordEntry] { record.filter(\.isOpen) }

    /// Whether the founder is inside on a given day.
    public func isInside(on day: Int) -> Bool {
        guard let sentenceUntilDay else { return false }
        return day < sentenceUntilDay
    }

    // Sorted dictionaries so two runs that did the same things in the same
    // order write the same bytes.
    private enum CodingKeys: String, CodingKey {
        case notoriety, cases, record, hearing, booksCookedUntilDay, bribedOutlets
        case fakedDemos, lastCommitted, lastSweepDay, sentenceUntilDay
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            notoriety: try container.decodeIfPresent(Double.self, forKey: .notoriety) ?? 0,
            cases: try container.decodeIfPresent([LegalCase].self, forKey: .cases) ?? [],
            record: try container.decodeIfPresent([CrimeRecordEntry].self, forKey: .record) ?? [],
            hearing: try container.decodeIfPresent(CrimeHearing.self, forKey: .hearing),
            booksCookedUntilDay: try container.decodeIfPresent(Int.self, forKey: .booksCookedUntilDay),
            bribedOutlets: try container.decodeIfPresent([String].self, forKey: .bribedOutlets) ?? [],
            fakedDemos: try container.decodeIfPresent([String: Int].self, forKey: .fakedDemos) ?? [:],
            lastCommitted: try container.decodeIfPresent([String: Int].self, forKey: .lastCommitted) ?? [:],
            lastSweepDay: try container.decodeIfPresent(Int.self, forKey: .lastSweepDay),
            sentenceUntilDay: try container.decodeIfPresent(Int.self, forKey: .sentenceUntilDay)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if notoriety != 0 { try container.encode(notoriety, forKey: .notoriety) }
        if !cases.isEmpty { try container.encode(cases, forKey: .cases) }
        if !record.isEmpty { try container.encode(record, forKey: .record) }
        try container.encodeIfPresent(hearing, forKey: .hearing)
        try container.encodeIfPresent(booksCookedUntilDay, forKey: .booksCookedUntilDay)
        if !bribedOutlets.isEmpty { try container.encode(bribedOutlets.sorted(), forKey: .bribedOutlets) }
        if !fakedDemos.isEmpty { try container.encode(fakedDemos, forKey: .fakedDemos) }
        if !lastCommitted.isEmpty { try container.encode(lastCommitted, forKey: .lastCommitted) }
        try container.encodeIfPresent(lastSweepDay, forKey: .lastSweepDay)
        try container.encodeIfPresent(sentenceUntilDay, forKey: .sentenceUntilDay)
    }
}

// MARK: - The arithmetic

/// The lane's pure half: what an offence is worth, what the odds of being
/// found are, how a hearing is graded and what a verdict costs.
///
/// Nothing here mutates, draws or reads a clock. `CrimeSystem` is the only
/// caller that changes anything, and the app calls exactly these functions
/// to write the consequence on the button before the player commits — so
/// the number they read is the number the engine writes.
public enum Crime {
    /// Standing is clamped to this either way.
    public static let standingLimit: Double = 100

    // MARK: W1 (dirty money)

    /// The weekly base rate at which a payment through a backer is found.
    ///
    /// A constant rather than a balance key: `discoveryChance` is handed
    /// `BalanceConfig.CrimeBalance` and nothing else, and that block is
    /// N1's — a seventh field in it is not W1's to add.
    public static let launderDiscovery: Double = 0.035

    // MARK: end of W1

    // MARK: The offences

    /// The notoriety an offence adds. Read straight off the balance so a
    /// tuner can move one without touching the others.
    public static func notorietyCost(
        _ offence: CrimeOffence, balance: BalanceConfig.CrimeBalance
    ) -> Double {
        switch offence {
        case .cookBooks: balance.cookBooksNotoriety
        case .dodgeTaxes: balance.dodgeTaxesNotoriety
        case .ndaPoach: balance.ndaPoachNotoriety
        case .bribeJournalist: balance.bribeNotoriety
        case .fakeDemo: balance.fakeDemoNotoriety
        case .plantStory: balance.plantStoryNotoriety
        // MARK: W1 — the notoriety of a payment is a fraction of the
        // payment, so W1 adds it itself when it writes the entry, out of
        // its own balance block. Nothing is added twice: this offence is
        // never committed through `CrimeSystem.commit`.
        case .launderMoney: 0
        // MARK: end of W1
        }
    }

    /// What the offence costs out of the founder's own wallet, up front.
    public static func walletCost(
        _ offence: CrimeOffence, balance: BalanceConfig.CrimeBalance
    ) -> Int {
        switch offence {
        case .ndaPoach: balance.ndaPoachFee
        case .bribeJournalist: balance.bribeFee
        case .plantStory: balance.plantStoryFee
        default: 0
        }
    }

    /// The weekly chance this entry is found, before the Legal department
    /// halves it.
    ///
    /// Three things move it: the offence's own base rate, how loud the
    /// founder is (`notoriety`), and how long ago it was — paper goes
    /// cold. Nothing here can reach 1: a founder who does one small thing
    /// and then behaves has a real chance of never hearing about it.
    public static func discoveryChance(
        _ entry: CrimeRecordEntry,
        notoriety: Double,
        hasLegal: Bool,
        day: Int,
        balance: BalanceConfig.CrimeBalance
    ) -> Double {
        guard entry.isOpen else { return 0 }
        let base: Double = switch entry.offence {
        case .cookBooks: balance.cookBooksDiscovery
        case .dodgeTaxes: balance.dodgeTaxesDiscovery
        case .ndaPoach: balance.ndaPoachDiscovery
        case .bribeJournalist: balance.bribeDiscovery
        case .fakeDemo: balance.fakeDemoDiscovery
        case .plantStory: balance.plantStoryDiscovery
        // MARK: W1 — the crime block has no field for the seventh
        // offence, and `discoveryChance` takes that block alone, so the
        // rate is a constant of this file rather than a balance key that
        // could not reach here. Deliberately low: a laundered payment
        // surfaces when somebody else's file is opened, not when yours is.
        case .launderMoney: Crime.launderDiscovery
        // MARK: end of W1
        }
        let heat = 1 + notoriety / 100 * balance.notorietyDiscoveryFactor
        let weeksOld = Double(max(0, day - entry.day)) / Double(GameState.daysPerWeek)
        let cold = max(balance.coldCaseFloor, 1 - weeksOld / max(1, balance.coldCaseWeeks))
        let legal = hasLegal ? balance.legalDepartmentFactor : 1
        return min(balance.discoveryCeiling, base * heat * cold * legal)
    }

    /// How much paper the other side is holding, 0…1: the offence's
    /// gravity, warmed by notoriety, cooled by age and by a Legal
    /// department that shredded the right emails at the right time.
    public static func evidenceWeight(
        _ entry: CrimeRecordEntry,
        notoriety: Double,
        hasLegal: Bool,
        day: Int,
        balance: BalanceConfig.CrimeBalance
    ) -> Double {
        let weeksOld = Double(max(0, day - entry.day)) / Double(GameState.daysPerWeek)
        let age = max(0.35, 1 - weeksOld / max(1, balance.coldCaseWeeks))
        let heat = 1 + notoriety / 100 * 0.4
        let legal = hasLegal ? 0.8 : 1
        return min(1, max(0.1, entry.offence.gravity * age * heat * legal))
    }

    /// What the other side will take today to make it go away.
    ///
    /// Scaled by the offence, by what the founder made out of it, and by
    /// how much paper they are holding. Paid out of the wallet when the
    /// wallet can cover it, out of the company when it cannot.
    public static func settlementPrice(
        offence: CrimeOffence,
        gain: Int,
        evidence: Double,
        balance: BalanceConfig.CrimeBalance
    ) -> Int {
        let base = Double(balance.settlementBase) * offence.gravity
        let ofGain = Double(max(0, gain)) * balance.settlementGainFactor
        return max(balance.settlementFloor, Int(((base + ofGain) * (0.5 + evidence)).rounded()))
    }

    // MARK: The courtroom

    /// The band a standing falls into. Deliberately wide in the middle:
    /// most hearings end in money, which is what most hearings do.
    public static func verdict(_ standing: Double, balance: BalanceConfig.CrimeBalance) -> CrimeVerdict {
        switch standing {
        case balance.acquittalStanding...: .acquitted
        case balance.fineStanding..<balance.acquittalStanding: .fine
        case balance.settlementStanding..<balance.fineStanding: .settlement
        default: .sentence
        }
    }

    /// What the verdict costs. A fine and a settlement are money; a
    /// sentence is weeks, and `penalty` is zero.
    public static func penalty(
        verdict: CrimeVerdict,
        offence: CrimeOffence,
        gain: Int,
        standing: Double,
        balance: BalanceConfig.CrimeBalance
    ) -> (money: Int, weeks: Int) {
        switch verdict {
        case .acquitted:
            return (0, 0)
        case .fine:
            let base = Double(balance.fineBase) * offence.gravity + Double(max(0, gain)) * 0.5
            return (max(balance.settlementFloor, Int(base.rounded())), 0)
        case .settlement:
            let base = Double(balance.settlementBase) * offence.gravity * 1.4
                + Double(max(0, gain)) * balance.settlementGainFactor
            return (max(balance.settlementFloor, Int(base.rounded())), 0)
        case .sentence:
            // The further below the line, the longer. Clamped both ways so
            // a sentence is a season, never a run.
            let over = max(0, balance.settlementStanding - standing) / 100
            let weeks = Double(balance.sentenceWeeksMin)
                + over * Double(balance.sentenceWeeksMax - balance.sentenceWeeksMin) * 2
            return (0, max(
                balance.sentenceWeeksMin,
                min(balance.sentenceWeeksMax, Int((weeks * (0.6 + offence.gravity)).rounded()))
            ))
        }
    }

    /// How the room reads right now, in one word.
    public static func standingLabel(_ standing: Double, balance: BalanceConfig.CrimeBalance) -> String {
        switch verdict(standing, balance: balance) {
        case .acquitted: "Walking"
        case .fine: "Fine"
        case .settlement: "Settling"
        case .sentence: "Custodial"
        }
    }

    /// The chance an exchange lands: the founder's own attribute, the
    /// lawyer's weight, and the defence's opinion of what was just said.
    /// Never certain and never hopeless.
    public static func landChance(
        _ exchange: CrimeExchange,
        defence: CrimeDefence,
        lawyer: CrimeLawyer,
        skill: Double,
        evidence: Double,
        balance: BalanceConfig.CrimeBalance
    ) -> Double {
        var chance = balance.landBase
            + skill / max(1, balance.landSkillDivisor)
            + lawyer.weight
        if exchange == defence.favours { chance += balance.onDefenceBonus }
        // Paper the other side is holding argues back.
        chance -= evidence * balance.evidenceLandPenalty
        // An objection is the lawyer's own work, not the founder's.
        if exchange == .objection { chance = balance.landBase + lawyer.weight * 1.6 }
        return min(balance.landCeiling, max(balance.landFloor, chance))
    }

    /// The opening standing of a hearing: the defence's own footing, less
    /// the weight of the evidence.
    public static func openingStanding(
        defence: CrimeDefence,
        evidence: Double,
        balance: BalanceConfig.CrimeBalance
    ) -> Double {
        defence.openingStanding - evidence * balance.evidenceOpeningWeight
    }

    // MARK: Copy

    /// What the judge or the prosecutor says back. Deterministic in the
    /// roll that graded the exchange, so no extra draw is needed.
    public static func reply(
        _ exchange: CrimeExchange,
        landed: Bool,
        offence: CrimeOffence,
        roll: Double
    ) -> String {
        let pool = landed ? landedLines(exchange) : missedLines(exchange)
        let index = min(pool.count - 1, Int(roll * Double(pool.count)))
        return pool[index].replacingOccurrences(of: "{charge}", with: offence.chargeName)
    }

    private static func landedLines(_ exchange: CrimeExchange) -> [String] {
        switch exchange {
        case .deny: [
            "\"Then the court is at a loss as to who did.\" The bench writes nothing down.",
            "The prosecutor turns a page, twice, and moves on.",
            "\"Noted.\" It is the first thing today they have not underlined.",
        ]
        case .explain: [
            "The judge asks a follow-up about accruals and seems, briefly, interested.",
            "\"So the figure is the figure.\" Two jurors stop looking at the clock.",
            "The prosecutor's own accountant leans over and whispers something unhelpful to her.",
        ]
        case .apologise: [
            "\"The court notes the defendant's candour.\" It costs you nothing you had.",
            "The room softens by about four degrees.",
            "The judge takes their glasses off, which is either very good or very bad.",
        ]
        case .blameTheCFO: [
            "\"And who signed it?\" \"They did.\" The bench accepts this, for now.",
            "Somewhere in the building, your CFO's phone starts ringing.",
            "The prosecutor recalibrates. That was not the afternoon she had planned.",
        ]
        case .objection: [
            "\"Sustained.\" Your lawyer sits down without looking pleased, which is the trick.",
            "\"Sustained. Move on, counsel.\" A whole line of questioning goes in the bin.",
            "Your lawyer objects on a ground you do not understand, and wins.",
        ]
        }
    }

    private static func missedLines(_ exchange: CrimeExchange) -> [String] {
        switch exchange {
        case .deny: [
            "The prosecutor produces the email. You are in the CC line.",
            "\"Denial is a position, Mr Founder. It is not evidence.\"",
            "\"You signed it.\" \"I sign a lot of things.\" \"Yes,\" she says. \"You do.\"",
        ]
        case .explain: [
            "You lose the room somewhere around the second slide.",
            "\"In plain English, please.\" In plain English it is {charge}.",
            "The judge asks whether the number went up or down. You take too long.",
        ]
        case .apologise: [
            "\"Sorry it happened, or sorry it was found?\" You do not answer quickly enough.",
            "The apology lands as an admission, because that is what it was.",
            "\"Thank you. The court will take that as agreed fact.\"",
        ]
        case .blameTheCFO: [
            "Your CFO is in the gallery. Everyone watches you point at them.",
            "\"They report to you.\" There is no second half to that sentence.",
            "The bench dislikes this more than it disliked the {charge}.",
        ]
        case .objection: [
            "\"Overruled. Sit down.\"",
            "\"Overruled — and counsel will not do that again.\"",
            "Your lawyer objects. The judge waits. Your lawyer sits.",
        ]
        }
    }

    /// The line the room prints when it closes.
    public static func closing(_ verdict: CrimeVerdict, weeks: Int, money: Int) -> String {
        switch verdict {
        case .acquitted:
            "\"The case is dismissed.\" Somebody behind you exhales. It is not your lawyer."
        case .fine:
            "\"Guilty, and a fine of \(money.crimeMoney).\" You are out by four o'clock."
        case .settlement:
            "\"The parties have reached terms.\" \(money.crimeMoney), and nobody may say why."
        case .sentence:
            "\"\(weeks) week\(weeks == 1 ? "" : "s"), custodial.\" They take your belt at the door."
        }
    }
}

extension FounderSkillSet {
    /// One attribute by case, public so the courtroom sheet can put the
    /// same odds on the button that the engine grades with.
    ///
    /// `PitchRoom` has an internal `value(for:)` of exactly this shape; it
    /// belongs to M2's file this round, so N1 carries its own rather than
    /// widening somebody else's.
    public func crimeValue(for skill: FounderSkill) -> Double {
        switch skill {
        case .conversation: conversation
        case .technical: technical
        case .marketKnowledge: marketKnowledge
        case .leadership: leadership
        case .finance: finance
        }
    }
}

// A tiny money formatter so the engine's own copy can print a figure
// without the app's `Int.money`, which lives in the app target.
extension Int {
    /// Grouped to the dollar, so a figure the courtroom says out loud
    /// matches the figure the ledger prints for the same event. (The app's
    /// own `Int.money` lives in the app target and cannot be reached from
    /// here.)
    var crimeMoney: String {
        let digits = String(abs(self))
        var grouped = ""
        for (offset, character) in digits.enumerated() {
            if offset > 0, (digits.count - offset).isMultiple(of: 3) { grouped.append(",") }
            grouped.append(character)
        }
        return "\(self < 0 ? "-" : "")$\(grouped)"
    }
}
