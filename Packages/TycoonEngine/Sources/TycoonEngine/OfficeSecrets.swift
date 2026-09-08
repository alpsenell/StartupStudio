import Foundation

// Iteration 11 — N5 owns this file. The slow-burn threads inside the
// office: a mole, a romance, embezzlement, a clique, a union drive, a
// coup. Each is a `SecretThread` with a stage, the clues it has dropped,
// and the people in it.
//
// Identity: nothing here is written until the founder has actually looked
// at the team (`OfficeSecretsState.watching`, set by the Team tab through
// `.watchTheOffice`). A pacing bot, a fixture replay and every headless
// run never switch tabs, so `state.secrets` stays `.empty`, is never
// encoded, and `OfficeSecretsSystem` returns before its first read.

/// The six things that go on behind the founder's back.
///
/// Raw values are persisted inside `SecretThread.kind` and named by
/// `-autoSecret <kind>`, so this list is append-only.
public enum SecretKind: String, Codable, Equatable, Sendable, CaseIterable {
    /// Somebody is selling the roadmap to a rival.
    case mole
    /// Two people are together, and one of them signs the other's reviews.
    case romance
    /// The expense line has been carrying somebody's weekends.
    case embezzlement
    /// A clique has closed around the newest hire.
    case clique
    /// A union drive, started the week the round closed.
    case unionDrive
    /// The co-founder is counting votes.
    case coup

    // MARK: W3 (espionage) — the three a rival runs against you

    /// Somebody here is on a competitor's payroll as well as yours.
    case rivalMole
    /// A competitor has put an investigator on the founder.
    case rivalTail
    /// A competitor's contractor is inside the storefront.
    case rivalHack

    // MARK: end W3

    public var displayName: String {
        switch self {
        case .mole: "The mole"
        case .romance: "Two people, one desk"
        case .embezzlement: "The expense line"
        case .clique: "The clique"
        case .unionDrive: "The union drive"
        case .coup: "The count"
        // MARK: W3 (espionage)
        case .rivalMole: "Their mole"
        case .rivalTail: "The car outside"
        case .rivalHack: "Somebody in the storefront"
        // MARK: end W3
        }
    }

    /// The one-line thing the card says it is, before anyone is named.
    public var summary: String {
        switch self {
        case .mole: "Something that only leaves this room is leaving this room."
        case .romance: "Two people who work for each other are not only working."
        case .embezzlement: "The expenses have a shape, and it is not the company's."
        case .clique: "Four people have a table, and the newest hire is not at it."
        case .unionDrive: "There is a meeting you were not invited to."
        case .coup: "Somebody is asking the board what a vote would look like."
        // MARK: W3 (espionage)
        case .rivalMole: "One of yours is being paid twice, and not by you."
        case .rivalTail: "The same car has been on your street four evenings running."
        case .rivalHack: "Somebody who is not a customer has been trying the doors."
        // MARK: end W3
        }
    }

    public var systemImageName: String {
        switch self {
        case .mole: "doc.on.doc.fill"
        case .romance: "heart.slash.fill"
        case .embezzlement: "creditcard.trianglebadge.exclamationmark"
        case .clique: "person.3.sequence.fill"
        case .unionDrive: "figure.stand.line.dotted.figure.stand"
        case .coup: "hand.raised.slash.fill"
        // MARK: W3 (espionage)
        case .rivalMole: "person.badge.key.fill"
        case .rivalTail: "car.fill"
        case .rivalHack: "bolt.horizontal.circle.fill"
        // MARK: end W3
        }
    }

    /// The staff moment a confrontation raises.
    public var staffEventKind: StaffEventKind {
        switch self {
        case .mole: .officeMole
        case .romance: .officeRomance
        case .embezzlement: .officeExpenses
        case .clique: .officeClique
        case .unionDrive: .officeUnion
        case .coup: .officeCoup
        // MARK: W3 (espionage)
        // A rival's operation still ends in a conversation with somebody
        // on your own payroll — the person they got to, the person whose
        // laptop it was — so it reuses the leak's staff moment rather than
        // widening `StaffEventKind`, which is another lane's file. The
        // *def* it resolves against is W3's own (`confrontDefID`).
        case .rivalMole, .rivalTail, .rivalHack: .officeMole
        // MARK: end W3
        }
    }

    /// The `StaffEvents.json` def a confrontation resolves against. It is
    /// the kind's own id — so the catalog has a definition for every kind,
    /// the way every other staff moment does — behind an
    /// `office_confrontation` gate that nothing ever raises, so the weekly
    /// staff roll can never pick one. These arrive when the founder says
    /// something, and only then.
    public var confrontDefID: String {
        // MARK: W3 (espionage)
        // W3's three resolve against their own `spy_` defs, behind their
        // own never-raised gate, so the confrontation reads as what it is:
        // somebody else's operation, run through your own people.
        switch self {
        case .rivalMole, .rivalTail, .rivalHack: return "spy_confront_\(rawValue.lowercased())"
        default: return staffEventKind.rawValue
        }
        // MARK: end W3
    }

    /// The `Events.json` id for a stage's beat, an ending, or a response.
    public func eventID(_ suffix: String) -> String {
        // MARK: W3 (espionage)
        // A thread a rival is running is W3's content, so it takes W3's
        // prefix — and `scheduledEventIDs`, which is built from this, keeps
        // covering every kind without a second list.
        if isRivalRun { return "spy_\(rawValue.lowercased())_\(suffix)" }
        // MARK: end W3
        return "office_\(rawValue.lowercased())_\(suffix)"
    }

    // MARK: W3 (espionage)

    /// Whether this thread is somebody else's operation rather than the
    /// office's own weather. The counterintelligence answers are the only
    /// ones that apply to these, and only to these.
    public var isRivalRun: Bool {
        switch self {
        case .rivalMole, .rivalTail, .rivalHack: true
        default: false
        }
    }

    /// The three, in the order the card offers them.
    public static let rivalRunCases: [SecretKind] = [.rivalMole, .rivalTail, .rivalHack]

    // MARK: end W3
}

/// Where a clue turned up. The card groups by it, so the founder can see
/// that they read this in the ledger rather than heard it in the room.
public enum SecretClueSource: String, Codable, Equatable, Sendable {
    /// The journal — a company event landed.
    case journal
    /// Somebody texted the founder about it.
    case phone
    /// The room itself changed: a shredder, a closed door, two at one desk.
    case office
    /// A line in the ledger.
    case ledger

    public var displayName: String {
        switch self {
        case .journal: "Noticed"
        case .phone: "Told"
        case .office: "Seen"
        case .ledger: "Booked"
        }
    }

    public var systemImageName: String {
        switch self {
        case .journal: "eye.fill"
        case .phone: "bubble.left.fill"
        case .office: "building.2.fill"
        case .ledger: "list.bullet.rectangle.portrait.fill"
        }
    }
}

/// One thing the founder now knows, in the order they learned it.
public struct SecretClue: Codable, Equatable, Sendable, Identifiable {
    public var id: Int
    public var day: Int
    public var text: String
    public var source: SecretClueSource

    public init(id: Int, day: Int, text: String, source: SecretClueSource) {
        self.id = id
        self.day = day
        self.text = text
        self.source = source
    }
}

/// What the room shows while a thread runs — the office scene's clue strip
/// reads exactly this, so a prop is never drawn for a thread that has not
/// dropped the clue it belongs to.
public enum SecretOfficeProp: String, Codable, Equatable, Sendable, CaseIterable {
    /// Two people at one desk.
    case sharedDesk
    /// A shredder that did not use to be by the printer.
    case shredder
    /// The meeting-room door, closed.
    case closedDoor

    public var caption: String {
        switch self {
        case .sharedDesk: "Two at one desk"
        case .shredder: "A new shredder"
        case .closedDoor: "The door is shut"
        }
    }
}

/// How a thread ended, for the card and the history.
public enum SecretEnding: String, Codable, Equatable, Sendable {
    /// The founder let it run to the end of its rope.
    case ignored
    /// Answered through HR, by the book.
    case handled
    /// A deal: money, a policy, or a reporting line moved.
    case dealt
    /// Somebody left over it — fired, or walked.
    case departed
    /// The confrontation settled it.
    case confronted

    public var displayName: String {
        switch self {
        case .ignored: "Ran its course"
        case .handled: "Handled by HR"
        case .dealt: "Settled"
        case .departed: "Somebody left"
        case .confronted: "Faced"
        }
    }
}

/// One slow-burn thread: what it is, how far it has run, who is in it,
/// and everything the founder has managed to learn.
public struct SecretThread: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    /// What it is — `SecretKind`'s raw value.
    public var kind: String
    public var startedDay: Int
    /// 0…3. Stage 3 is the ending; a thread that reaches it is over.
    public var stage: Int
    public var employeeIDs: [UUID]
    /// The first day the next stage may land.
    public var nextStageDay: Int
    /// What the founder has learned, oldest first.
    public var clues: [SecretClue]
    /// Whether the people in it have been named to the founder — an
    /// investigation, a PI or a confrontation does this.
    public var named: Bool
    /// Props the room is showing for this thread.
    public var props: [SecretOfficeProp]
    /// The mole's leaked topic, once there is one.
    public var topicID: String?
    /// What the expense line has taken so far.
    public var taken: Int
    /// The day it closed, and how.
    public var closedDay: Int?
    public var ending: String?
    /// Responses already spent, so the card can grey them.
    public var usedResponses: [String]

    public init(
        id: String,
        kind: String,
        startedDay: Int,
        stage: Int = 0,
        employeeIDs: [UUID] = [],
        nextStageDay: Int = 0,
        clues: [SecretClue] = [],
        named: Bool = false,
        props: [SecretOfficeProp] = [],
        topicID: String? = nil,
        taken: Int = 0,
        closedDay: Int? = nil,
        ending: String? = nil,
        usedResponses: [String] = []
    ) {
        self.id = id
        self.kind = kind
        self.startedDay = startedDay
        self.stage = stage
        self.employeeIDs = employeeIDs
        self.nextStageDay = nextStageDay
        self.clues = clues
        self.named = named
        self.props = props
        self.topicID = topicID
        self.taken = taken
        self.closedDay = closedDay
        self.ending = ending
        self.usedResponses = usedResponses
    }

    public var secretKind: SecretKind? { SecretKind(rawValue: kind) }
    public var isOpen: Bool { closedDay == nil }
    public var endingKind: SecretEnding? { ending.flatMap(SecretEnding.init(rawValue:)) }

    /// Whether a response has been spent on this thread already.
    public func hasUsed(_ response: SecretResponse) -> Bool {
        usedResponses.contains(response.rawValue)
    }

    // Every field beyond the scaffold's five decodes if present, so a save
    // written against the scaffold still reads.
    private enum CodingKeys: String, CodingKey {
        case id, kind, startedDay, stage, employeeIDs, nextStageDay
        case clues, named, props, topicID, taken, closedDay, ending, usedResponses
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            kind: try container.decode(String.self, forKey: .kind),
            startedDay: try container.decode(Int.self, forKey: .startedDay),
            stage: try container.decodeIfPresent(Int.self, forKey: .stage) ?? 0,
            employeeIDs: try container.decodeIfPresent([UUID].self, forKey: .employeeIDs) ?? [],
            nextStageDay: try container.decodeIfPresent(Int.self, forKey: .nextStageDay) ?? 0,
            clues: try container.decodeIfPresent([SecretClue].self, forKey: .clues) ?? [],
            named: try container.decodeIfPresent(Bool.self, forKey: .named) ?? false,
            props: try container.decodeIfPresent([SecretOfficeProp].self, forKey: .props) ?? [],
            topicID: try container.decodeIfPresent(String.self, forKey: .topicID),
            taken: try container.decodeIfPresent(Int.self, forKey: .taken) ?? 0,
            closedDay: try container.decodeIfPresent(Int.self, forKey: .closedDay),
            ending: try container.decodeIfPresent(String.self, forKey: .ending),
            usedResponses: try container.decodeIfPresent([String].self, forKey: .usedResponses) ?? []
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(startedDay, forKey: .startedDay)
        try container.encode(stage, forKey: .stage)
        try container.encode(employeeIDs, forKey: .employeeIDs)
        try container.encode(nextStageDay, forKey: .nextStageDay)
        if !clues.isEmpty { try container.encode(clues, forKey: .clues) }
        if named { try container.encode(named, forKey: .named) }
        if !props.isEmpty { try container.encode(props, forKey: .props) }
        try container.encodeIfPresent(topicID, forKey: .topicID)
        if taken != 0 { try container.encode(taken, forKey: .taken) }
        try container.encodeIfPresent(closedDay, forKey: .closedDay)
        try container.encodeIfPresent(ending, forKey: .ending)
        if !usedResponses.isEmpty { try container.encode(usedResponses, forKey: .usedResponses) }
    }
}

/// The founder's answers to a thread. Each is a `GameAction`; the card
/// shows every one with what it costs and why it is refused.
public enum SecretResponse: String, Codable, Equatable, Sendable, CaseIterable {
    /// An evening asking around: names the people and pulls the next clue
    /// forward.
    case investigate
    /// A private investigator, out of the founder's own wallet: every clue
    /// this thread has left to give, at once.
    case privateEye
    /// Say it to their face — a staff moment, through the machinery every
    /// other staff moment uses.
    case confront
    /// Hand it to People & HR. Needs the department; ends it cleanly.
    case callHR
    /// Money, a policy, or a reporting line moved.
    case makeDeal
    /// Let it run. The ending comes early and the founder chose it.
    case ignore

    // MARK: W3 (espionage) — counterintelligence

    /// A firm with a van and a spectrum analyser goes over the office.
    /// Only for a thread somebody outside is running.
    case sweepOffice
    /// A quiet evening with the roster, the badge log and the payroll.
    case auditRoster
    /// Let their mole keep reporting, and give them something to report.
    case feedFalsePlans

    // MARK: end W3

    public var displayName: String {
        switch self {
        case .investigate: "Ask around"
        case .privateEye: "Hire a PI"
        case .confront: "Say it to their face"
        case .callHR: "Take it to HR"
        case .makeDeal: "Make a deal"
        case .ignore: "Leave it alone"
        // MARK: W3 (espionage)
        case .sweepOffice: "Sweep the office"
        case .auditRoster: "Audit the roster"
        case .feedFalsePlans: "Feed them false plans"
        // MARK: end W3
        }
    }

    public var systemImageName: String {
        switch self {
        case .investigate: "magnifyingglass"
        case .privateEye: "eyeglasses"
        case .confront: "exclamationmark.bubble.fill"
        case .callHR: "person.badge.shield.checkmark.fill"
        case .makeDeal: "hands.and.sparkles.fill"
        case .ignore: "hand.raised.slash"
        // MARK: W3 (espionage)
        case .sweepOffice: "antenna.radiowaves.left.and.right.slash"
        case .auditRoster: "list.clipboard.fill"
        case .feedFalsePlans: "theatermasks.fill"
        // MARK: end W3
        }
    }
}

/// Why a response cannot be taken right now, in the player's words.
public enum SecretRefusal: String, Equatable, Sendable {
    case noThread, alreadyUsed, noEvening, noWallet, noCompanyCash, noHR, notNamed, closed
    // MARK: W3 (espionage)
    /// The three counterintelligence answers only apply to a thread
    /// somebody outside the building is running.
    case notRivalRun
    /// And feeding false plans needs somebody to feed them to.
    case noMoleToFeed
    // MARK: end W3

    public func message(_ balance: BalanceConfig) -> String {
        switch self {
        case .noThread: "There is nothing to answer."
        case .alreadyUsed: "You have already done that on this one."
        case .noEvening: "No evenings left this week."
        case .noWallet: "Your own wallet will not cover the retainer."
        case .noCompanyCash: "The company cannot cover it."
        case .noHR: "Nobody here does People & HR."
        case .notNamed: "You do not know who yet — ask around first."
        case .closed: "That one is over."
        // MARK: W3 (espionage)
        case .notRivalRun: "This one is coming from inside the building. There is nothing to sweep."
        case .noMoleToFeed: "Nobody is carrying anything out of here to be lied to."
        // MARK: end W3
        }
    }
}

/// Everything the office is keeping from the founder.
public struct OfficeSecretsState: Codable, Equatable, Sendable {
    /// Live and closed threads, oldest first. Closed ones are kept so the
    /// card can show what happened; capped at `maxThreads`.
    public var threads: [SecretThread]
    /// Kinds already run this company, so nothing repeats.
    public var history: [String]
    /// The gate. Set the first time the founder opens the Team tab; the
    /// system reads nothing and rolls nothing until it is true, which is
    /// what keeps every headless run byte-identical.
    public var watching: Bool
    /// The day the last thread closed, for the gap between them.
    public var lastClosedDay: Int?

    static let maxThreads = 8

    public init(
        threads: [SecretThread] = [],
        history: [String] = [],
        watching: Bool = false,
        lastClosedDay: Int? = nil
    ) {
        self.threads = threads
        self.history = history
        self.watching = watching
        self.lastClosedDay = lastClosedDay
    }

    public static let empty = OfficeSecretsState()

    /// The thread that is still running, if any. At most one ever is.
    public var open: SecretThread? { threads.first { $0.isOpen } }

    public var closed: [SecretThread] { threads.filter { !$0.isOpen } }

    private enum CodingKeys: String, CodingKey {
        case threads, history, watching, lastClosedDay
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            threads: try container.decodeIfPresent([SecretThread].self, forKey: .threads) ?? [],
            history: try container.decodeIfPresent([String].self, forKey: .history) ?? [],
            watching: try container.decodeIfPresent(Bool.self, forKey: .watching) ?? false,
            lastClosedDay: try container.decodeIfPresent(Int.self, forKey: .lastClosedDay)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !threads.isEmpty { try container.encode(threads, forKey: .threads) }
        if !history.isEmpty { try container.encode(history, forKey: .history) }
        if watching { try container.encode(watching, forKey: .watching) }
        try container.encodeIfPresent(lastClosedDay, forKey: .lastClosedDay)
    }
}
