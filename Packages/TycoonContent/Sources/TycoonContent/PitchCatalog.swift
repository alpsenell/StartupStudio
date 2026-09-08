import Foundation

// Iteration 10 — M2. What the four people across the table say.
//
// The pitch room reuses the networking floor's four-topic grammar
// (`ConversationTopic`), so what a counterpart needs is not a new
// mechanic but new *words*: an opener, a hidden want with a tell and a
// reveal, and the lines each topic gets back when it lands and when it
// does not. All of it lives here so a writer can change the room without
// touching the engine.
//
// The whole catalog is optional (`Pitches.json`, decode-if-present). A
// build without the file falls back to `PitchCatalog.fallback`, which is
// terse but complete — the room still works, it just reads flatter.

/// The lines one topic gets back, split by whether the exchange landed.
public struct PitchLineSet: Codable, Equatable, Sendable {
    /// What they say when it works.
    public let land: [String]
    /// What they say when it does not. Empty for the two topics that
    /// cannot fail; the engine never asks for it there.
    public let miss: [String]

    public init(land: [String], miss: [String] = []) {
        self.land = land
        self.miss = miss
    }
}

/// The one thing this person actually came to hear. Hidden until the
/// founder listens; the tell is showing from the first exchange.
public struct PitchWantDef: Codable, Equatable, Sendable {
    public let id: String
    /// What the room names it once it is known ("Traction").
    public let name: String
    /// The body language before the founder has listened.
    public let tell: String
    /// The line that reveals it.
    public let reveal: String
    /// The `ConversationTopic` raw value this want pays double for —
    /// `smallTalk`, `shopTalk`, `listen` or `pitch`.
    public let favors: String
    /// What they say when the founder plays straight into it.
    public let hit: String

    public init(
        id: String, name: String, tell: String, reveal: String, favors: String, hit: String
    ) {
        self.id = id
        self.name = name
        self.tell = tell
        self.reveal = reveal
        self.favors = favors
        self.hit = hit
    }
}

/// One person the founder can sit down with: the investor holding a term
/// sheet, the client with a job, the journalist in launch week, or the
/// board at a quarterly review.
public struct PitchCounterpartDef: Codable, Equatable, Sendable {
    /// Matches `PitchCounterpart`'s raw value in the engine.
    public let id: String
    /// What the room is called at the top of the sheet.
    public let title: String
    /// The line the room opens with, picked per session.
    public let openers: [String]
    /// The wants this counterpart draws from.
    public let wants: [PitchWantDef]
    /// Lines per `ConversationTopic` raw value.
    public let lines: [String: PitchLineSet]
    /// What the sheet says the conversation ended as, by band raw value
    /// (`hostile`, `cool`, `even`, `warm`, `sold`).
    public let closings: [String: String]

    public init(
        id: String,
        title: String,
        openers: [String],
        wants: [PitchWantDef],
        lines: [String: PitchLineSet],
        closings: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.openers = openers
        self.wants = wants
        self.lines = lines
        self.closings = closings
    }
}

/// `Pitches.json`.
public struct PitchCatalog: Codable, Equatable, Sendable {
    public let counterparts: [PitchCounterpartDef]

    public init(counterparts: [PitchCounterpartDef]) {
        self.counterparts = counterparts
    }

    /// O(n) over four entries — small enough that an index would cost
    /// more than it saves.
    public func counterpart(_ id: String) -> PitchCounterpartDef? {
        counterparts.first { $0.id == id }
    }

    /// A room with no `Pitches.json` behind it. Every counterpart has one
    /// want and one line per topic, so the engine's lookups never come
    /// back empty and the sheet never shows a blank quote.
    public static let fallback = PitchCatalog(counterparts: [
        terse(
            id: "investor", title: "The term sheet",
            opener: "So. Convince me this is the round I should be in.",
            want: PitchWantDef(
                id: "traction", name: "Traction",
                tell: "They keep glancing back at your weekly numbers.",
                reveal: "They want one number going up and to the right. Nothing else.",
                favors: "pitch",
                hit: "\u{201C}That's the line I wanted to see.\u{201D}"
            ),
            land: "They nod, and write something down.",
            miss: "They look at the door."
        ),
        terse(
            id: "client", title: "The client meeting",
            opener: "We've read the brief. Talk us through the work.",
            want: PitchWantDef(
                id: "certainty", name: "Certainty",
                tell: "They ask twice about the date before the money.",
                reveal: "They have been burned by a late delivery and will not be again.",
                favors: "shopTalk",
                hit: "\u{201C}Good. That's the answer we needed.\u{201D}"
            ),
            land: "They relax a little.",
            miss: "They exchange a look."
        ),
        terse(
            id: "journalist", title: "The interview",
            opener: "Twenty minutes, on the record. Why does this exist?",
            want: PitchWantDef(
                id: "story", name: "A story",
                tell: "They stopped taking notes and started listening.",
                reveal: "They do not want the feature list. They want the reason.",
                favors: "listen",
                hit: "\u{201C}Say that again — slower.\u{201D}"
            ),
            land: "The recorder is still running.",
            miss: "They circle something on the page."
        ),
        terse(
            id: "board", title: "The board room",
            opener: "The quarter's in front of us. Explain it.",
            want: PitchWantDef(
                id: "aplan", name: "A plan",
                tell: "They want to hear about next quarter, not this one.",
                reveal: "They are not angry about the miss. They are angry about the silence.",
                favors: "shopTalk",
                hit: "\u{201C}Fine. Hold yourself to that.\u{201D}"
            ),
            land: "The room settles.",
            miss: "Somebody sighs."
        ),
    ])

    private static func terse(
        id: String, title: String, opener: String,
        want: PitchWantDef, land: String, miss: String
    ) -> PitchCounterpartDef {
        PitchCounterpartDef(
            id: id, title: title, openers: [opener], wants: [want],
            lines: [
                "smallTalk": PitchLineSet(land: [land]),
                "listen": PitchLineSet(land: [land]),
                "shopTalk": PitchLineSet(land: [land], miss: [miss]),
                "pitch": PitchLineSet(land: [land], miss: [miss]),
            ],
            closings: [:]
        )
    }
}
