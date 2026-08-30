/// Employee bios and spoken lines, loaded from `Dialogue.json`.
///
/// Two catalogs in one:
///
/// - **Bios** — a one-liner for the hiring sheet and the team roster,
///   chosen from the candidate's traits ("Writes the tests first and will
///   tell you about it").
/// - **Lines** — what somebody says in a moment, filtered by context
///   (heads-down coding, a ship, a resignation, their first day, the coffee
///   machine), mood bucket, and traits.
///
/// Selection is a pure function of a caller-supplied `seed` — never a
/// system RNG — so the office can put a speech bubble over someone without
/// touching the simulation's determinism.
public struct DialogueCatalog: Codable, Equatable, Sendable {
    /// A one-line character sketch.
    public struct Bio: Codable, Equatable, Sendable, Identifiable {
        public var id: String
        /// Offered only to someone with at least one of these traits.
        /// Empty means it fits anybody.
        public var traits: [String]
        public var text: String

        public init(id: String, traits: [String] = [], text: String) {
            self.id = id
            self.traits = traits
            self.text = text
        }

        private enum CodingKeys: String, CodingKey { case id, traits, text }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
                id: try container.decode(String.self, forKey: .id),
                traits: try container.decodeIfPresent([String].self, forKey: .traits) ?? [],
                text: try container.decode(String.self, forKey: .text)
            )
        }
    }

    /// A bundle of interchangeable lines for one situation.
    public struct LineSet: Codable, Equatable, Sendable, Identifiable {
        public var id: String
        /// Where these lines belong.
        public var context: DialogueContext
        /// Mood buckets the set covers ("low", "okay", "high"). Empty means
        /// any mood.
        public var moods: [String]
        /// Traits the set is written for. Empty means anybody.
        public var traits: [String]
        public var lines: [String]

        public init(
            id: String,
            context: DialogueContext,
            moods: [String] = [],
            traits: [String] = [],
            lines: [String]
        ) {
            self.id = id
            self.context = context
            self.moods = moods
            self.traits = traits
            self.lines = lines
        }

        private enum CodingKeys: String, CodingKey { case id, context, moods, traits, lines }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
                id: try container.decode(String.self, forKey: .id),
                context: try container.decode(DialogueContext.self, forKey: .context),
                moods: try container.decodeIfPresent([String].self, forKey: .moods) ?? [],
                traits: try container.decodeIfPresent([String].self, forKey: .traits) ?? [],
                lines: try container.decode([String].self, forKey: .lines)
            )
        }
    }

    public var bios: [Bio]
    public var lines: [LineSet]

    public init(bios: [Bio] = [], lines: [LineSet] = []) {
        self.bios = bios
        self.lines = lines
    }

    /// The catalog a missing or empty `Dialogue.json` yields. Every entry
    /// point returns `nil`, and callers use their own fallback.
    public static let empty = DialogueCatalog()

    /// The mood bucket a 0...100 morale falls into.
    public static func moodBucket(_ mood: Int) -> String {
        switch mood {
        case ..<40: "low"
        case ..<70: "okay"
        default: "high"
        }
    }

    /// A one-line bio for somebody with these traits, or `nil` when
    /// nothing is written. Trait-specific bios are preferred over generic
    /// ones; `seed` picks among equally good candidates.
    public func bio(for traits: [String], seed: UInt64) -> String? {
        let traitSet = Set(traits)
        let specific = bios.filter { !$0.traits.isEmpty && !traitSet.isDisjoint(with: $0.traits) }
        let pool = specific.isEmpty ? bios.filter(\.traits.isEmpty) : specific
        guard !pool.isEmpty else { return nil }
        return pool[Int(seed % UInt64(pool.count))].text
    }

    /// A line for this person in this moment, or `nil` when nothing is
    /// written for the combination. A set written for one of their traits
    /// wins over a generic one, and a set that names their mood bucket
    /// wins over one that does not.
    public func line(
        for traits: [String],
        mood: Int,
        context: DialogueContext,
        seed: UInt64
    ) -> String? {
        let bucket = Self.moodBucket(mood)
        let traitSet = Set(traits)
        let candidates = lines.filter { set in
            set.context == context
                && (set.moods.isEmpty || set.moods.contains(bucket))
                && (set.traits.isEmpty || !traitSet.isDisjoint(with: set.traits))
        }
        guard !candidates.isEmpty else { return nil }

        // Rank: trait-and-mood, then trait, then mood, then generic.
        func rank(_ set: LineSet) -> Int {
            (set.traits.isEmpty ? 0 : 2) + (set.moods.isEmpty ? 0 : 1)
        }
        let best = candidates.map(rank).max() ?? 0
        let pool = candidates.filter { rank($0) == best }.flatMap(\.lines)
        guard !pool.isEmpty else { return nil }
        return pool[Int(seed % UInt64(pool.count))]
    }

    private enum CodingKeys: String, CodingKey { case bios, lines }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            bios: try container.decodeIfPresent([Bio].self, forKey: .bios) ?? [],
            lines: try container.decodeIfPresent([LineSet].self, forKey: .lines) ?? []
        )
    }
}

/// Where a line is spoken. WS-B may append cases; consumers switch with a
/// `default`.
public enum DialogueContext: String, Codable, Equatable, Sendable, CaseIterable {
    case coding, shipped, quit, hired, coffee
    /// Deep in a crunch week.
    case crunch
    /// Nothing assigned; waiting for something to do.
    case idle
    /// Just praised, promoted, or given a raise.
    case praised
    /// Standing at the whiteboard with somebody else.
    case huddle
}
