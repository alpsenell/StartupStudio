import Foundation

/// Versioned envelope written to disk. `state` is stored as raw JSON so the
/// envelope can be inspected and migrated without decoding the game payload.
public struct SaveEnvelope: Sendable, Equatable {
    public var formatVersion: Int
    public var savedAt: Date
    public var appVersion: String
    /// What the picker needs to say about this save without decoding the
    /// state. `nil` for a file written before summaries existed; the
    /// store's `slots()` then decodes the state once and summarizes it.
    public var summary: SaveSummary?

    public init(
        formatVersion: Int,
        savedAt: Date,
        appVersion: String,
        summary: SaveSummary? = nil
    ) {
        self.formatVersion = formatVersion
        self.savedAt = savedAt
        self.appVersion = appVersion
        self.summary = summary
    }
}

/// The few facts a slot picker shows about a save, written beside the
/// state in the envelope so listing three slots costs three small reads
/// and no decode.
///
/// Every field decodes with a default, so a summary written by a newer
/// app (more fields) or an older one (fewer) still reads. An app that
/// predates summaries reads the envelope key by key and never sees this.
public struct SaveSummary: Codable, Sendable, Equatable, Hashable {
    public var companyName: String
    public var founderName: String
    /// The game day the save was written on.
    public var day: Int
    /// The ending's name when the run is over (`EndingKind.rawValue`);
    /// `nil` while the company is still running.
    public var ending: String?
    /// The chapter the run has reached, and its title, for the Continue
    /// card. Optional: a save summarized from a state with no progression
    /// (there is none such today) would leave them out.
    public var chapter: Int?
    public var chapterTitle: String?
    /// The founder's appearance seed, so the picker can draw their face.
    public var founderAppearanceSeed: UInt64?

    public init(
        companyName: String,
        founderName: String,
        day: Int,
        ending: String? = nil,
        chapter: Int? = nil,
        chapterTitle: String? = nil,
        founderAppearanceSeed: UInt64? = nil
    ) {
        self.companyName = companyName
        self.founderName = founderName
        self.day = day
        self.ending = ending
        self.chapter = chapter
        self.chapterTitle = chapterTitle
        self.founderAppearanceSeed = founderAppearanceSeed
    }

    private enum CodingKeys: String, CodingKey {
        case companyName, founderName, day, ending, chapter, chapterTitle, founderAppearanceSeed
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            companyName: try container.decodeIfPresent(String.self, forKey: .companyName) ?? "",
            founderName: try container.decodeIfPresent(String.self, forKey: .founderName) ?? "",
            day: try container.decodeIfPresent(Int.self, forKey: .day) ?? 0,
            ending: try container.decodeIfPresent(String.self, forKey: .ending),
            chapter: try container.decodeIfPresent(Int.self, forKey: .chapter),
            chapterTitle: try container.decodeIfPresent(String.self, forKey: .chapterTitle),
            founderAppearanceSeed: try container.decodeIfPresent(UInt64.self, forKey: .founderAppearanceSeed)
        )
    }
}

/// One row of the slot picker: what is in slot `slot`, or why it cannot
/// be read. A slot that cannot be read never stops the others listing.
public struct SlotSummary: Sendable, Equatable, Identifiable {
    public enum Contents: Sendable, Equatable {
        /// No save file in this slot.
        case empty
        /// A readable save, with its summary and envelope.
        case saved(summary: SaveSummary, envelope: SaveEnvelope)
        /// Both the save and its backup failed to read or migrate.
        case corrupt
        /// Written by a newer app (`formatVersion` beyond this one's).
        case futureFormat(Int)
    }

    public var slot: Int
    public var contents: Contents

    public var id: Int { slot }

    public init(slot: Int, contents: Contents) {
        self.slot = slot
        self.contents = contents
    }

    /// The summary, when the slot holds a readable save.
    public var summary: SaveSummary? {
        if case .saved(let summary, _) = contents { return summary }
        return nil
    }

    /// When the save was last written, when the slot holds a readable save.
    public var lastPlayed: Date? {
        if case .saved(_, let envelope) = contents { return envelope.savedAt }
        return nil
    }

    public var isEmpty: Bool { contents == .empty }
}

public enum SaveStoreError: Error, Equatable {
    /// Both the main save and the backup failed to decode/migrate.
    case corruptSave
    /// The save was written by a NEWER app (formatVersion > current).
    case futureFormat(Int)
}

/// One migration step: transforms the raw JSON *state dictionary* from
/// version N to N+1. Steps are pure and run in ascending order.
public struct MigrationStep: Sendable {
    public var fromVersion: Int
    public var migrate: @Sendable (inout [String: Any]) throws -> Void

    public init(
        fromVersion: Int,
        migrate: @escaping @Sendable (inout [String: Any]) throws -> Void
    ) {
        self.fromVersion = fromVersion
        self.migrate = migrate
    }
}
