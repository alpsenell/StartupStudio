import Foundation
import TycoonContent

// Iteration 12 — J1. Nobody asks permission.
//
// Four one-time doors from the company game into rooms that already
// exist and would otherwise stay dormant until the player went looking:
// the shark, the vices, the feed and the family room. Each is one
// question with a deadline. Yes wakes the room; no, or silence, leaves
// it asleep for the rest of the run.
//
// Identity: nothing here runs until the app arms it (`.armDoors`, sent by
// the HUD once a person is playing), so every bot, replay, fixture and
// engine test writes the bytes it always wrote. Once armed, a door that
// opens writes its record and one phone message; nothing else moves until
// the player answers, and a door nobody answers closes as a no. Every
// condition is a plain read of the state. Nothing draws.

/// The four doors.
public enum DoorKind: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    /// Runway four weeks or less, day 90 or later, Finances never opened.
    case shark
    /// The founder on crunch for 21 of the last 28 days.
    case vices
    /// A launch reviewed 80 or better, or reputation 60 or more.
    case fame
    /// Day 365 or later and a parent reaches the age the seed gave their fall.
    case care
}

/// What the founder said at a door.
public enum DoorChoice: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    /// Yes, at the shark, vices and fame doors.
    case accept
    /// No — said out loud.
    case decline
    /// Nobody answered and the deadline did. The same as a no.
    case lapsed
    /// The care door's three answers. Each of them opens the family room.
    case careHome
    case careSpareRoom
    case careSibling

    /// Whether this answer walks through the door.
    public var opens: Bool {
        switch self {
        case .accept, .careHome, .careSpareRoom, .careSibling: true
        case .decline, .lapsed: false
        }
    }

    /// The answers a door takes from a thumb. `.lapsed` is the clock's.
    public static func choices(for kind: DoorKind) -> [DoorChoice] {
        switch kind {
        case .care: [.careHome, .careSpareRoom, .careSibling, .decline]
        case .shark, .vices, .fame: [.accept, .decline]
        }
    }
}

/// One door that opened: when, until when, and what was said.
public struct DoorRecord: Codable, Equatable, Sendable, Identifiable {
    public var kind: DoorKind
    public var openedDay: Int
    public var respondByDay: Int
    /// For the care door, the relation (`FamilyRelation.rawValue`) whose
    /// fall it was. `nil` for the other three.
    public var subject: String?
    public var answer: DoorChoice?
    public var answeredDay: Int?

    public var id: String { kind.rawValue }

    public init(
        kind: DoorKind,
        openedDay: Int,
        respondByDay: Int,
        subject: String? = nil,
        answer: DoorChoice? = nil,
        answeredDay: Int? = nil
    ) {
        self.kind = kind
        self.openedDay = openedDay
        self.respondByDay = respondByDay
        self.subject = subject
        self.answer = answer
        self.answeredDay = answeredDay
    }

    /// Still waiting on the founder on `day`.
    public func isOpen(on day: Int) -> Bool {
        answer == nil && day <= respondByDay
    }

    /// Days left to answer on `day`, zero on the last one.
    public func daysLeft(on day: Int) -> Int { max(0, respondByDay - day) }
}

/// The doors' slot on `GameState`. Decoded if present, written only when
/// something is in it.
public struct DoorState: Codable, Equatable, Sendable {
    /// Whether a person is at the controls. The app's HUD sends
    /// `.armDoors` once per game; nothing else sets it. The reducer, the
    /// pacing bots, the replayed fixtures and every test that drives the
    /// engine directly never send it, so for them the doors do not exist
    /// — which is what keeps every save they write byte-identical. The
    /// same pattern as `.noticeFinancesOpened`, one level up: it asks
    /// "is somebody playing", not "did they open the room".
    public var armed: Bool
    /// Every door that has opened, in the order they opened. At most one
    /// per kind, ever.
    public var records: [DoorRecord]
    /// The last 28 days of the founder's schedule, newest in bit 0: a set
    /// bit is a day kept on crunch. Only recorded from day 62, and cleared
    /// for good once the vices door has opened or the Assets room is
    /// engaged by other means, so it is zero in every save that does not
    /// need it.
    public var crunchMask: UInt32

    public init(armed: Bool = false, records: [DoorRecord] = [], crunchMask: UInt32 = 0) {
        self.armed = armed
        self.records = records
        self.crunchMask = crunchMask
    }

    public static let empty = DoorState()

    /// The record for `kind`, if that door ever opened.
    public func record(_ kind: DoorKind) -> DoorRecord? {
        records.first { $0.kind == kind }
    }

    /// The doors waiting on an answer on `day`, oldest first.
    public func open(on day: Int) -> [DoorRecord] {
        records.filter { $0.isOpen(on: day) }
    }

    /// Days on crunch in the last 28.
    public var crunchDaysInWindow: Int { crunchMask.nonzeroBitCount }

    /// Whether the founder gave a parent the spare room at the care door,
    /// which costs one evening every week from then on.
    public var careTakesAnEvening: Bool {
        record(.care)?.answer == .careSpareRoom
    }

    private enum CodingKeys: String, CodingKey { case armed, records, crunchMask }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            armed: try c.decodeIfPresent(Bool.self, forKey: .armed) ?? false,
            records: try c.decodeIfPresent([DoorRecord].self, forKey: .records) ?? [],
            crunchMask: try c.decodeIfPresent(UInt32.self, forKey: .crunchMask) ?? 0
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if armed { try c.encode(armed, forKey: .armed) }
        if !records.isEmpty { try c.encode(records, forKey: .records) }
        if crunchMask != 0 { try c.encode(crunchMask, forKey: .crunchMask) }
    }
}

/// Why an answer at a door would be refused, printed on the button.
public enum DoorRefusal: Equatable, Sendable {
    case closed
    case notAnAnswer
    case wallet(Int)

    public var reason: String {
        switch self {
        case .closed: "That door has closed."
        case .notAnAnswer: "Not an answer this door takes."
        case .wallet(let bill): "The wallet does not cover a week of it (\(PhoneSystem.money(bill)))."
        }
    }
}

/// The doors' numbers and their conditions, all pure reads. The
/// thresholds are file constants, as the spec allows: none of them is a
/// balance knob anybody has asked to turn.
public enum DoorRules {
    /// No door opens before this day. The day-30 fixtures cannot reach it.
    public static let notBeforeDay = 90
    /// How long a door waits for an answer.
    public static let respondDays = 14

    /// The shark: the office scene's own "runway is short" line.
    public static let sharkRunwayWeeks = 4

    /// The vices: this many crunch days in the last `crunchWindowDays`.
    public static let crunchWindowDays = 28
    public static let crunchDaysNeeded = 21
    /// The first day the window records, so it can be full on day 90.
    public static let crunchTrackFromDay = notBeforeDay - crunchWindowDays
    static let crunchWindowMask: UInt32 = (1 << 28) - 1

    /// Fame: a launch reviewed this well, or a reputation this high.
    public static let fameReviewScore = 80
    public static let fameReputation = 60
    /// The journalist's piece: followers it brings on a yes.
    public static let fameFollowers = 240

    /// The care door: not before the second year.
    public static let careNotBeforeDay = 365
    /// Leaving it to the sibling costs this much of their bond.
    public static let careSiblingBond: Double = -20

    // MARK: The conditions

    /// Whether `kind`'s condition is met today — nothing about whether the
    /// door has opened before, which the system checks.
    public static func meets(
        _ kind: DoorKind,
        state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> Bool {
        guard state.day >= notBeforeDay else { return false }
        switch kind {
        case .shark:
            return state.dirtyMoney == .empty && runwayIsShort(state, balance)
        case .vices:
            return !state.assets.isEngaged && state.doors.crunchDaysInWindow >= crunchDaysNeeded
        case .fame:
            return state.fame == .empty && (bestReview(state) >= fameReviewScore
                || state.company.reputation >= Double(fameReputation))
        case .care:
            return careSubject(state: state, content: content) != nil
        }
    }

    /// What the company costs a week, the way the office and the HUD add
    /// it up: operating cost, rent, payroll, the founder's salary, upkeep.
    public static func weeklyBurn(_ state: GameState, _ balance: BalanceConfig) -> Int {
        // MARK: P1 (purchases: engine) — the formula lives on the state.
        state.weeklyBurn(balance: balance)
        // MARK: end P1
    }

    /// Four weeks of runway or less. A company already in debt has none.
    public static func runwayIsShort(_ state: GameState, _ balance: BalanceConfig) -> Bool {
        let cash = state.company.cash
        if cash < 0 { return true }
        let burn = weeklyBurn(state, balance)
        guard burn > 0 else { return false }
        return cash / burn <= sharkRunwayWeeks
    }

    /// The best average review any launch has had.
    public static func bestReview(_ state: GameState) -> Int {
        state.products.reduce(0) { best, product in
            guard case .released(let info) = product.stage, !info.reviews.isEmpty else { return best }
            return max(best, info.averageReviewScore)
        }
    }

    /// The age at which this run's first parent has the fall: 69 to 72,
    /// from a private stream off the seed, so nobody's draws move. The
    /// father starts at 68, so the fall lands in year two, year three, or
    /// — for half the seeds — after a two-year run is over. (At 69–71 the
    /// scratch check had it on 8–10 runs in 10: a nag.)
    public static func careAge(seed: UInt64) -> Int {
        var private_ = SeededRNG(seed: seed &* 0xA24B_AED4_963E_E407 &+ 12)
        return 69 + private_.nextInt(in: 0...3)
    }

    /// The parent the care door is about today, or `nil`: from day 365, a
    /// living parent at the seed's care age, in a family room nobody has
    /// opened.
    public static func careSubject(state: GameState, content: ContentCatalog) -> FamilyRelation? {
        guard state.day >= careNotBeforeDay, state.familyDrama.openedDay == nil else { return nil }
        let age = careAge(seed: state.seed)
        return state.familyRelatives(names: content.names)
            .filter { $0.relation.isParent && $0.age >= age }
            .filter { state.familyDrama.record($0.relation)?.isAlive != false }
            .max { $0.age < $1.age }?
            .relation
    }

    /// Why `choice` at `kind` would be refused today, or `nil`.
    public static func refusal(
        _ kind: DoorKind,
        _ choice: DoorChoice,
        state: GameState,
        balance: BalanceConfig
    ) -> DoorRefusal? {
        guard let record = state.doors.record(kind), record.isOpen(on: state.day) else { return .closed }
        guard DoorChoice.choices(for: kind).contains(choice) else { return .notAnAnswer }
        if choice == .careHome, state.life.wallet < balance.familyDrama.careWeeklyBill {
            return .wallet(balance.familyDrama.careWeeklyBill)
        }
        return nil
    }

    /// The story flag a spoken answer raises. Only a thumb raises one: a
    /// lapsed door raises nothing, so a bot's event pool never moves.
    public static func flag(_ kind: DoorKind, _ choice: DoorChoice) -> String? {
        switch choice {
        case .lapsed: nil
        case .decline: "door_\(kind.rawValue)_declined"
        case .accept, .careHome, .careSpareRoom, .careSibling: "door_\(kind.rawValue)"
        }
    }
}
