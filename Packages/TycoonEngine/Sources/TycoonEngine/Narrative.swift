import Foundation

/// Where a narrative beat came from — which catalog holds its definition.
public enum NarrativeSource: String, Codable, Equatable, Sendable, CaseIterable {
    /// `Events.json`: something that happened to the company.
    case company
    /// `LifeEvents.json`: something that happened to the founder.
    case life
}

/// One answer offered by a pending choice, snapshotted out of the catalog
/// so the sheet renders from state alone (and keeps rendering after a
/// relaunch, exactly like the poach and buyout prompts).
public struct ChoiceOption: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var label: String
    /// The one-line consequence under the label.
    public var detail: String?
    /// The option's index in the definition's `choices`, which is what
    /// `GameAction.resolveChoice` carries — options the player can't take
    /// are filtered out, so positions do not line up.
    public var index: Int

    public init(id: String, label: String, detail: String? = nil, index: Int) {
        self.id = id
        self.label = label
        self.detail = detail
        self.index = index
    }
}

/// A story beat waiting on the founder's answer.
///
/// The text is copied in rather than looked up so the sheet survives a
/// relaunch and a content edit mid-run, and so the app never needs the
/// catalog to draw it.
public struct PendingChoice: Codable, Equatable, Sendable {
    /// The definition's id.
    public var id: String
    /// Which catalog to resolve it against.
    public var source: NarrativeSource
    public var title: String
    public var body: String
    public var options: [ChoiceOption]
    /// The last day an answer counts. Past it the deadline answers for the
    /// founder with `autoOptionIndex`.
    public var respondByDay: Int
    /// The definition index the deadline picks.
    public var autoOptionIndex: Int
    /// Icon/tint bucket, the `EventCategory` raw value.
    public var category: String
    /// The day the choice arrived.
    public var raisedDay: Int

    public init(
        id: String,
        source: NarrativeSource,
        title: String,
        body: String,
        options: [ChoiceOption],
        respondByDay: Int,
        autoOptionIndex: Int,
        category: String,
        raisedDay: Int
    ) {
        self.id = id
        self.source = source
        self.title = title
        self.body = body
        self.options = options
        self.respondByDay = respondByDay
        self.autoOptionIndex = autoOptionIndex
        self.category = category
        self.raisedDay = raisedDay
    }
}

/// A follow-up an earlier choice scheduled.
public struct ScheduledNarrativeEvent: Codable, Equatable, Sendable {
    /// The day it fires (the first tick on or after it).
    public var day: Int
    public var eventID: String
    public var source: NarrativeSource

    public init(day: Int, eventID: String, source: NarrativeSource) {
        self.day = day
        self.eventID = eventID
        self.source = source
    }
}

/// Everything the narrative engine persists: the pending choice, the story
/// flags earlier answers raised, per-event cooldowns, scheduled follow-ups
/// and once-only bookkeeping.
///
/// Every field decodes with a default, so a save written before the
/// narrative engine existed reads as `.initial` and `saveFormatVersion`
/// stays 1. Sets and dictionaries encode in sorted order so identical
/// states stay byte-identical.
public struct NarrativeState: Codable, Equatable, Sendable {
    /// The beat waiting on an answer, if any.
    public var pendingChoice: PendingChoice?
    /// Flags raised by past answers, e.g. `"cofounder_settled"`.
    public var flags: Set<String>
    /// Event id → the first day it may be drawn again.
    public var cooldowns: [String: Int]
    /// Follow-ups an earlier answer queued, kept sorted by (day, id).
    public var scheduled: [ScheduledNarrativeEvent]
    /// Ids of `once` events that have already fired.
    public var firedOnce: Set<String>
    /// The last day any narrative beat fired — the one-beat-per-window
    /// guard the pause budget depends on.
    public var lastFiredDay: Int
    /// The last day an industry-news headline was generated.
    public var lastNewsDay: Int

    public init(
        pendingChoice: PendingChoice? = nil,
        flags: Set<String> = [],
        cooldowns: [String: Int] = [:],
        scheduled: [ScheduledNarrativeEvent] = [],
        firedOnce: Set<String> = [],
        lastFiredDay: Int = -1_000,
        lastNewsDay: Int = -1_000
    ) {
        self.pendingChoice = pendingChoice
        self.flags = flags
        self.cooldowns = cooldowns
        self.scheduled = scheduled
        self.firedOnce = firedOnce
        self.lastFiredDay = lastFiredDay
        self.lastNewsDay = lastNewsDay
    }

    /// A fresh company's narrative state.
    public static let initial = NarrativeState()

    /// Whether `flag` has been raised.
    public func hasFlag(_ flag: String) -> Bool { flags.contains(flag) }
}

// MARK: - Codable

// Hand-written so the set and dictionary fields encode in sorted order
// (`Set` and `Dictionary` iteration order is not stable across processes,
// and the determinism tests compare save bytes), and so every key decodes
// as optional: a save written before the field existed keeps loading.

extension NarrativeState {
    private enum CodingKeys: String, CodingKey {
        case pendingChoice, flags, cooldowns, scheduled, firedOnce
        case lastFiredDay, lastNewsDay
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            pendingChoice: try container.decodeIfPresent(PendingChoice.self, forKey: .pendingChoice),
            flags: Set(try container.decodeIfPresent([String].self, forKey: .flags) ?? []),
            cooldowns: try container.decodeIfPresent([String: Int].self, forKey: .cooldowns) ?? [:],
            scheduled: try container.decodeIfPresent(
                [ScheduledNarrativeEvent].self, forKey: .scheduled
            ) ?? [],
            firedOnce: Set(try container.decodeIfPresent([String].self, forKey: .firedOnce) ?? []),
            lastFiredDay: try container.decodeIfPresent(Int.self, forKey: .lastFiredDay) ?? -1_000,
            lastNewsDay: try container.decodeIfPresent(Int.self, forKey: .lastNewsDay) ?? -1_000
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(pendingChoice, forKey: .pendingChoice)
        try container.encode(flags.sorted(), forKey: .flags)
        try container.encode(
            Dictionary(uniqueKeysWithValues: cooldowns.sorted { $0.key < $1.key }),
            forKey: .cooldowns
        )
        try container.encode(scheduled, forKey: .scheduled)
        try container.encode(firedOnce.sorted(), forKey: .firedOnce)
        try container.encode(lastFiredDay, forKey: .lastFiredDay)
        try container.encode(lastNewsDay, forKey: .lastNewsDay)
    }
}
