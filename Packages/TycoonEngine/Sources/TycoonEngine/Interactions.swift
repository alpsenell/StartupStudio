import Foundation
import TycoonContent

// Iteration 11 — N2 owns this file. The BitLife-sized interaction menu for
// every person in the game, and the per-person bookkeeping (cooldowns, the
// affair, the disowned, the fired-with-cause, the last outcome line)
// behind it. The bars it moves already exist: `Employee.founderBond` /
// `morale`, `FamilyState.affection`, `Child.bond`, `Friend.bond`,
// `Contact.rapport`, and the `Rival.grudge` this lane adds.
//
// Identity at the default: a run that never opens a menu never writes a
// cooldown, never raises the `people_meddler` flag that gates this lane's
// life events, and encodes `InteractionState.empty`, which `GameState`
// omits entirely.

/// Who the founder is interacting with.
public enum InteractionTarget: Codable, Equatable, Hashable, Sendable {
    case partner
    case child(UUID)
    case friend(UUID)
    case employee(UUID)
    case contact(UUID)
    case rival(UUID)

    /// The person's id, for the five cases that name somebody.
    public var personID: UUID? {
        switch self {
        case .partner: nil
        case let .child(id), let .friend(id), let .employee(id),
             let .contact(id), let .rival(id): id
        }
    }

    /// Which set of content lines and which bar this target uses.
    public var kind: InteractionTargetKind {
        switch self {
        case .partner: .partner
        case .child: .child
        case .friend: .friend
        case .employee: .employee
        case .contact: .contact
        case .rival: .rival
        }
    }

    /// The stable half of a cooldown key, and a deterministic sort order.
    public var key: String {
        switch self {
        case .partner: "partner"
        case .child(let id): "child:\(id.uuidString)"
        case .friend(let id): "friend:\(id.uuidString)"
        case .employee(let id): "employee:\(id.uuidString)"
        case .contact(let id): "contact:\(id.uuidString)"
        case .rival(let id): "rival:\(id.uuidString)"
        }
    }

    /// The phone thread this target's outcome line is posted to. A rival
    /// has no thread — they are not in the founder's phone.
    public var phoneCounterpart: PhoneCounterpart? {
        switch self {
        case .partner: .partner
        case .child(let id): .child(id)
        case .friend(let id): .friend(id)
        case .employee(let id): .employee(id)
        case .contact(let id): .contact(id)
        case .rival: nil
        }
    }
}

/// The six kinds of person, which is how `Interactions.json` keys its
/// outcome lines and its per-kind delta overrides.
public enum InteractionTargetKind: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    case partner, child, friend, employee, contact, rival

    /// What the bar this kind moves is called, on the button and in the
    /// outcome card.
    public var barLabel: String {
        switch self {
        case .partner: "affection"
        case .child, .friend, .employee: "bond"
        case .contact: "rapport"
        case .rival: "grudge"
        }
    }
}

/// The four shelves the menu is grouped onto.
public enum InteractionGroup: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    case nice, mean, money, serious

    public var displayName: String {
        switch self {
        case .nice: "Nice"
        case .mean: "Mean"
        case .money: "Money"
        case .serious: "Serious"
        }
    }

    public var systemImage: String {
        switch self {
        case .nice: "hands.and.sparkles.fill"
        case .mean: "flame.fill"
        case .money: "banknote.fill"
        case .serious: "exclamationmark.triangle.fill"
        }
    }
}

/// What an interaction costs. A negative wallet amount is money coming the
/// founder's way.
public enum InteractionCost: Equatable, Hashable, Sendable {
    case free
    case evening
    case wallet(Int)
    /// An evening *and* money — dinner out with somebody.
    case eveningAndWallet(Int)

    public var walletAmount: Int {
        switch self {
        case .free, .evening: 0
        case .wallet(let amount), .eveningAndWallet(let amount): amount
        }
    }

    public var spendsEvening: Bool {
        switch self {
        case .free, .wallet: false
        case .evening, .eveningAndWallet: true
        }
    }
}

/// The line the founder just got back, kept on the state so the sheet can
/// play it after the action and the card can show the last thing that
/// happened with this person.
public struct InteractionOutcome: Codable, Equatable, Sendable {
    public var target: InteractionTarget
    public var interactionID: String
    /// Whether the roll landed the way the founder wanted.
    public var good: Bool
    /// What they said, or what happened, in the game's voice.
    public var line: String
    /// The delta actually applied to the bar, after clamping.
    public var delta: Double
    /// "affection", "bond", "rapport", "grudge".
    public var barLabel: String
    public var day: Int

    public init(
        target: InteractionTarget, interactionID: String, good: Bool,
        line: String, delta: Double, barLabel: String, day: Int
    ) {
        self.target = target
        self.interactionID = interactionID
        self.good = good
        self.line = line
        self.delta = delta
        self.barLabel = barLabel
        self.day = day
    }
}

/// The founder's meddling, as state. Every field is empty in a run that
/// never opens a menu, which is what keeps `.empty` — and therefore the
/// whole slot — out of the save.
public struct InteractionState: Codable, Equatable, Sendable {
    /// Last day each `(target.key)|(interaction id)` pair was used.
    public var cooldowns: [String: Int]
    /// The contact the founder is having an affair with. Wave two's family
    /// drama reads this: the flag, the day it started, and whether it has
    /// been found out yet.
    public var affairContactID: UUID?
    public var affairSinceDay: Int?
    public var affairDiscoveredDay: Int?
    /// Children the founder disowned. They stay on the family card — this
    /// is a life, not a delete key — but the bond is gone.
    public var disownedChildIDs: [UUID]
    /// People fired with a named cause: the boomerang does not bring them
    /// back, and their alumnus entry is closed as lost.
    public var firedWithCauseIDs: [UUID]
    /// The last thing that happened, for the sheet's paper.
    public var lastOutcome: InteractionOutcome?
    /// How many interactions the founder has performed at all — the
    /// biography's number, and the cheapest "has this player ever touched
    /// this feature" test there is.
    public var performedCount: Int
    // MARK: J2 (record)
    /// The days a mean interaction was used on somebody on payroll, oldest
    /// first, pruned to the window the founder's name remembers. Empty —
    /// and not written — for a founder who never did.
    public var standingMeanDays: [Int] = []
    // MARK: end J2

    public init(
        cooldowns: [String: Int] = [:],
        affairContactID: UUID? = nil,
        affairSinceDay: Int? = nil,
        affairDiscoveredDay: Int? = nil,
        disownedChildIDs: [UUID] = [],
        firedWithCauseIDs: [UUID] = [],
        lastOutcome: InteractionOutcome? = nil,
        performedCount: Int = 0
    ) {
        self.cooldowns = cooldowns
        self.affairContactID = affairContactID
        self.affairSinceDay = affairSinceDay
        self.affairDiscoveredDay = affairDiscoveredDay
        self.disownedChildIDs = disownedChildIDs
        self.firedWithCauseIDs = firedWithCauseIDs
        self.lastOutcome = lastOutcome
        self.performedCount = performedCount
    }

    public static let empty = InteractionState()

    /// Wave two's seam: is there an affair running, and has it surfaced?
    public var hasAffair: Bool { affairContactID != nil }
    public var affairIsSecret: Bool { hasAffair && affairDiscoveredDay == nil }

    public func lastUsedDay(_ target: InteractionTarget, _ id: String) -> Int? {
        cooldowns["\(target.key)|\(id)"]
    }

    public mutating func markUsed(_ target: InteractionTarget, _ id: String, day: Int) {
        cooldowns["\(target.key)|\(id)"] = day
    }

    public func isDisowned(_ childID: UUID) -> Bool { disownedChildIDs.contains(childID) }

    // MARK: Iteration 11, wave two — W2 (family drama): discovery

    /// How long the affair has been running, in weeks. W2's weekly
    /// discovery roll scales on it: a fortnight is a secret, a year is a
    /// habit.
    public func affairWeeksRunning(day: Int) -> Double {
        guard let affairSinceDay else { return 0 }
        return Double(max(0, day - affairSinceDay)) / Double(GameState.daysPerWeek)
    }

    /// The one place `affairDiscoveredDay` is written. N2 starts the
    /// affair; W2 ends the secret, and does it through a named seam so the
    /// field is never set from three places.
    public mutating func markAffairDiscovered(day: Int) {
        guard affairContactID != nil, affairDiscoveredDay == nil else { return }
        affairDiscoveredDay = day
    }

    /// The affair is over, discovered or not — the founder ended it.
    public mutating func endAffair() {
        affairContactID = nil
        affairSinceDay = nil
    }

    // MARK: end of Iteration 11, wave two — W2

    public func wasFiredWithCause(_ employeeID: UUID) -> Bool {
        firedWithCauseIDs.contains(employeeID)
    }

    // MARK: J2 (record)

    /// Mean acts on staff after `day`.
    public func standingMeanActs(since day: Int) -> Int {
        standingMeanDays.count { $0 > day }
    }

    /// Remembers a mean act on staff, and forgets the ones older than the
    /// window, so the list stays the size of a bad half-year.
    public mutating func standingRecordMeanAct(day: Int, window: Int) {
        standingMeanDays.removeAll { $0 <= day - window }
        standingMeanDays.append(day)
    }

    // MARK: end J2
}

// MARK: - Codable

// Hand-written so the cooldown map encodes as a sorted array of entries
// (the same determinism argument as `FamilyState.partnerCooldowns`) and so
// every field is written only once it has something to say — an untouched
// state encodes as `{}`, and `GameState` does not write it at all.
extension InteractionState {
    private enum CodingKeys: String, CodingKey {
        case cooldowns, affairContactID, affairSinceDay, affairDiscoveredDay
        case disownedChildIDs, firedWithCauseIDs, lastOutcome, performedCount
        // MARK: J2 (record)
        case standingMeanDays
        // MARK: end J2
    }

    private struct CooldownEntry: Codable {
        var key: String
        var day: Int
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entries = try container.decodeIfPresent([CooldownEntry].self, forKey: .cooldowns) ?? []
        self.init(
            cooldowns: Dictionary(
                entries.map { ($0.key, $0.day) }, uniquingKeysWith: { _, last in last }
            ),
            affairContactID: try container.decodeIfPresent(UUID.self, forKey: .affairContactID),
            affairSinceDay: try container.decodeIfPresent(Int.self, forKey: .affairSinceDay),
            affairDiscoveredDay: try container.decodeIfPresent(
                Int.self, forKey: .affairDiscoveredDay
            ),
            disownedChildIDs: try container.decodeIfPresent(
                [UUID].self, forKey: .disownedChildIDs
            ) ?? [],
            firedWithCauseIDs: try container.decodeIfPresent(
                [UUID].self, forKey: .firedWithCauseIDs
            ) ?? [],
            lastOutcome: try container.decodeIfPresent(
                InteractionOutcome.self, forKey: .lastOutcome
            ),
            performedCount: try container.decodeIfPresent(Int.self, forKey: .performedCount) ?? 0
        )
        // MARK: J2 (record)
        standingMeanDays = try container.decodeIfPresent(
            [Int].self, forKey: .standingMeanDays
        ) ?? []
        // MARK: end J2
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !cooldowns.isEmpty {
            try container.encode(
                cooldowns.keys.sorted().map { CooldownEntry(key: $0, day: cooldowns[$0] ?? 0) },
                forKey: .cooldowns
            )
        }
        try container.encodeIfPresent(affairContactID, forKey: .affairContactID)
        try container.encodeIfPresent(affairSinceDay, forKey: .affairSinceDay)
        try container.encodeIfPresent(affairDiscoveredDay, forKey: .affairDiscoveredDay)
        if !disownedChildIDs.isEmpty {
            try container.encode(disownedChildIDs, forKey: .disownedChildIDs)
        }
        if !firedWithCauseIDs.isEmpty {
            try container.encode(firedWithCauseIDs, forKey: .firedWithCauseIDs)
        }
        try container.encodeIfPresent(lastOutcome, forKey: .lastOutcome)
        if performedCount != 0 { try container.encode(performedCount, forKey: .performedCount) }
        // MARK: J2 (record)
        if !standingMeanDays.isEmpty {
            try container.encode(standingMeanDays, forKey: .standingMeanDays)
        }
        // MARK: end J2
    }
}

// MARK: - Reading a definition

/// The engine's view of one row in `Interactions.json`, with the strings
/// resolved into the engine's own enums. `InteractionDef` is the content
/// type; this is what the system and the menu actually work with.
///
/// Identity is the id: two rules with the same id are the same rule, which
/// is all any caller compares.
public struct InteractionRule: Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var icon: String
    public var group: InteractionGroup
    public var kinds: Set<InteractionTargetKind>
    public var cost: InteractionCost
    public var cooldownDays: Int
    public var baseChance: Double
    /// The bar delta on a good and a bad roll, before any per-kind
    /// override.
    public var good: Double
    public var bad: Double
    public var overrides: [InteractionTargetKind: InteractionDeltaPair]
    public var minBar: Double?
    public var maxBar: Double?
    /// Minimum relationship stage, for the partner-only serious ones.
    public var minStage: RelationshipStage?
    /// Minimum child stage, for disown.
    public var minChildStage: ChildStage?
    /// This one asks before it does anything.
    public var confirms: Bool
    /// One line under the title, in the founder's own words.
    public var note: String?
    public var lines: [InteractionTargetKind: InteractionLinePair]

    public static func == (lhs: InteractionRule, rhs: InteractionRule) -> Bool {
        lhs.id == rhs.id
    }

    /// The deltas this rule applies to a given kind of person.
    public func deltas(for kind: InteractionTargetKind) -> InteractionDeltaPair {
        overrides[kind] ?? InteractionDeltaPair(good: good, bad: bad)
    }

    /// The lines this rule can produce for a given kind of person.
    public func lines(for kind: InteractionTargetKind, good: Bool) -> [String] {
        guard let pair = lines[kind] else { return [] }
        return good ? pair.good : pair.bad
    }

    public init(_ def: InteractionDef) {
        id = def.id
        title = def.title
        icon = def.icon
        group = InteractionGroup(rawValue: def.group) ?? .nice
        kinds = Set(def.targets.compactMap(InteractionTargetKind.init(rawValue:)))
        cooldownDays = def.cooldownDays
        baseChance = def.baseChance
        good = def.good
        bad = def.bad
        minBar = def.minBar
        maxBar = def.maxBar
        minStage = def.minStage.flatMap(RelationshipStage.init(rawValue:))
        minChildStage = def.minChildStage.flatMap(ChildStage.init(rawValue:))
        confirms = def.confirms
        note = def.note
        switch def.cost {
        case "evening": cost = def.wallet == 0 ? .evening : .eveningAndWallet(def.wallet)
        default: cost = def.wallet == 0 ? .free : .wallet(def.wallet)
        }
        overrides = Dictionary(
            uniqueKeysWithValues: def.overrides.compactMap { key, value in
                InteractionTargetKind(rawValue: key).map {
                    ($0, InteractionDeltaPair(good: value.good, bad: value.bad))
                }
            }
        )
        lines = Dictionary(
            uniqueKeysWithValues: def.lines.compactMap { key, value in
                InteractionTargetKind(rawValue: key).map {
                    ($0, InteractionLinePair(good: value.good, bad: value.bad))
                }
            }
        )
    }
}

/// What a rule does to the bar on each side of the roll.
public struct InteractionDeltaPair: Equatable, Hashable, Sendable {
    public var good: Double
    public var bad: Double

    public init(good: Double, bad: Double) {
        self.good = good
        self.bad = bad
    }
}

/// The two pools of outcome lines for one kind of person.
public struct InteractionLinePair: Equatable, Sendable {
    public var good: [String]
    public var bad: [String]

    public init(good: [String], bad: [String]) {
        self.good = good
        self.bad = bad
    }
}

extension ContentCatalog {
    /// Every interaction, in JSON order, as engine rules. Empty without
    /// the file, which means an empty menu rather than a crash.
    public var interactionRules: [InteractionRule] {
        (interactions?.interactions ?? []).map(InteractionRule.init)
    }
}

// MARK: - Queries the app asks

extension GameState {
    /// The interactions that apply to this person, in catalog order,
    /// whether or not they are currently allowed. The menu shows the
    /// refused ones with their reason under them.
    public func peopleMenu(
        for target: InteractionTarget, content: ContentCatalog
    ) -> [InteractionRule] {
        content.interactionRules.filter { $0.kinds.contains(target.kind) }
    }

    /// The friend behind an id, on whichever roster is live. Friends are
    /// materialised lazily — the roster is a pure function of the seed
    /// until the founder does something worth remembering — so every
    /// query here takes the catalog when it has one and falls back to what
    /// is actually in state when it does not.
    private func interactionFriend(_ id: UUID, _ content: ContentCatalog?) -> Friend? {
        if let content { return friend(id, content: content) }
        return life.friends.friends.first { $0.id == id }
    }

    /// The bar this target currently sits on, or `nil` when the person is
    /// no longer in the run.
    public func interactionBar(
        _ target: InteractionTarget, content: ContentCatalog? = nil
    ) -> Double? {
        switch target {
        case .partner:
            life.family.stage == .single ? nil : life.family.affection
        case .child(let id):
            life.family.children.first { $0.id == id }?.bond
        case .friend(let id):
            interactionFriend(id, content)?.bond
        case .employee(let id):
            employees.first { $0.id == id }?.founderBond
        case .contact(let id):
            networking.contacts.first { $0.id == id }?.rapport
        case .rival(let id):
            rivals.rival(id: id)?.grudge
        }
    }

    /// Their name, for the sheet's title and every outcome line.
    public func interactionName(
        _ target: InteractionTarget, content: ContentCatalog? = nil
    ) -> String {
        switch target {
        case .partner: life.family.partnerName ?? "Your partner"
        case .child(let id): life.family.children.first { $0.id == id }?.name ?? "Your kid"
        case .friend(let id): interactionFriend(id, content)?.name ?? "A friend"
        case .employee(let id): employees.first { $0.id == id }?.name ?? "Someone at work"
        case .contact(let id): networking.contacts.first { $0.id == id }?.name ?? "A contact"
        case .rival(let id): rivals.rival(id: id)?.name ?? "A rival"
        }
    }

    /// The face, when this target has one. A rival's founder portrait is
    /// its `appearanceSeed`, the same one the profile draws.
    public func interactionSeed(
        _ target: InteractionTarget, content: ContentCatalog? = nil
    ) -> UInt64? {
        switch target {
        case .partner: life.family.partnerAppearanceSeed
        case .child(let id): life.family.children.first { $0.id == id }?.appearanceSeed
        case .friend(let id): interactionFriend(id, content)?.appearanceSeed
        case .employee(let id): employees.first { $0.id == id }?.appearanceSeed
        case .contact(let id): networking.contacts.first { $0.id == id }?.appearanceSeed
        case .rival(let id): rivals.rival(id: id)?.appearanceSeed
        }
    }

    /// The rival the founder has annoyed most: the nemesis named on the
    /// profile. `nil` until somebody has a grudge worth the word. Ties
    /// break on the id so the answer is a pure function of the state.
    public var nemesis: Rival? {
        rivals.rivals
            .filter { $0.grudge >= InteractionTuning.nemesisGrudge }
            .max {
                ($0.grudge, $0.id.uuidString) < ($1.grudge, $1.id.uuidString)
            }
    }

    /// Whether this rival is *the* nemesis right now.
    public func isNemesis(_ rivalID: UUID) -> Bool { nemesis?.id == rivalID }

    /// Why this interaction is refused, in the player's words, or `nil`.
    public func interactionBlocker(
        _ target: InteractionTarget, _ id: String,
        balance: BalanceConfig, content: ContentCatalog
    ) -> String? {
        InteractionSystem.blocker(
            target: target, interactionID: id, state: self, balance: balance, content: content
        )
    }

    /// The chance the founder's next go at this lands, as the button's
    /// percentage. A pure function of the state, so the number on the
    /// button is the number the roll uses.
    public func interactionOdds(
        _ target: InteractionTarget, _ rule: InteractionRule, content: ContentCatalog? = nil
    ) -> Double {
        InteractionSystem.chance(
            rule: rule, bar: interactionBar(target, content: content) ?? 50, state: self
        )
    }
}
