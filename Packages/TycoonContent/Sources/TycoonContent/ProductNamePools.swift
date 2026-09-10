import Foundation

// MARK: S3 (product names)

/// Iteration 16 — S3. The vocabulary the new-product flow suggests names
/// from (`ProductNames.json`): a dozen stems per topic, a dozen suffixes per
/// product type, a shared pool of standalone words, prefixes and tails, the
/// patterns that join them, and the real names a suggestion must never be.
///
/// Content, not state: nothing here is saved, and nothing the engine
/// simulates reads it. `ProductNameGenerator` turns it into names.
public struct ProductNamePools: Codable, Equatable, Sendable {
    /// One way of joining the pools, e.g. `"{stem}{suffix}"` or
    /// `"{word} {tail}"`. `weight` is its share of the draw.
    public struct Pattern: Codable, Equatable, Sendable {
        public var template: String
        public var weight: Int

        public init(template: String, weight: Int) {
            self.template = template
            self.weight = weight
        }
    }

    /// `TopicDef.id` → the front halves that say the topic ("Fit", "Stride").
    public var stemsByTopic: [String: [String]]
    /// `ProductTypeDef.id` → the back halves that say the type ("Track", "Hub").
    public var suffixesByType: [String: [String]]
    /// Standalone words that say nothing about either ("Cedar", "Otter").
    public var words: [String]
    /// Front halves that go before a stem or a suffix ("Hyper", "Pocket").
    public var prefixes: [String]
    /// Words that trail a name after a space ("Pro", "HQ", "Labs").
    public var tails: [String]
    public var patterns: [Pattern]
    /// What a v2 can be called besides a number ("Next").
    public var sequelTails: [String]
    /// Real products and companies. A suggestion is refused when it is one
    /// of these, or when any of its space-separated words is.
    public var banned: [String]

    public init(
        stemsByTopic: [String: [String]],
        suffixesByType: [String: [String]],
        words: [String],
        prefixes: [String],
        tails: [String],
        patterns: [Pattern],
        sequelTails: [String] = [],
        banned: [String] = []
    ) {
        self.stemsByTopic = stemsByTopic
        self.suffixesByType = suffixesByType
        self.words = words
        self.prefixes = prefixes
        self.tails = tails
        self.patterns = patterns
        self.sequelTails = sequelTails
        self.banned = banned
    }

    /// What a build without `ProductNames.json` suggests from: the stems and
    /// suffixes the flow used to hard-code, so it still names things.
    public static let fallback = ProductNamePools(
        stemsByTopic: [
            "fitness": ["Fit"], "finance": ["Fin"], "social": ["Social"],
            "travel": ["Trip"], "food_delivery": ["Bite"], "education": ["Learn"],
            "music": ["Tune"], "gaming": ["Play"], "productivity": ["Task"],
            "health": ["Vita"], "dating": ["Match"], "logistics": ["Ship"],
        ],
        suffixesByType: [
            "mobile_app": ["Go", "Track", "Snap", "Dash"],
            "web_app": ["Hub", "Board", "Space", "Link"],
            "desktop_tool": ["Studio", "Bench", "Works", "Forge"],
            "game": ["Quest", "Rush", "Land", "Saga"],
            "saas_platform": ["Base", "Stack", "Cloud", "HQ"],
            "enterprise_tool": ["Suite", "Core", "Ops", "Desk"],
        ],
        words: ["Nova", "Cedar", "Otter", "Comet"],
        prefixes: ["Neo", "Hyper"],
        tails: ["Pro", "HQ", "Labs"],
        patterns: [
            Pattern(template: "{stem}{suffix}", weight: 3),
            Pattern(template: "{prefix}{stem}", weight: 1),
            Pattern(template: "{stem}{suffix} {tail}", weight: 1),
        ],
        sequelTails: ["Next"]
    )
}

private extension ProductNamePools {
    enum CodingKeys: String, CodingKey {
        case stemsByTopic, suffixesByType, words, prefixes, tails, patterns
        case sequelTails, banned
    }
}

extension ProductNamePools {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            stemsByTopic: try container.decodeIfPresent([String: [String]].self, forKey: .stemsByTopic) ?? [:],
            suffixesByType: try container.decodeIfPresent([String: [String]].self, forKey: .suffixesByType) ?? [:],
            words: try container.decodeIfPresent([String].self, forKey: .words) ?? [],
            prefixes: try container.decodeIfPresent([String].self, forKey: .prefixes) ?? [],
            tails: try container.decodeIfPresent([String].self, forKey: .tails) ?? [],
            patterns: try container.decodeIfPresent([Pattern].self, forKey: .patterns) ?? [],
            sequelTails: try container.decodeIfPresent([String].self, forKey: .sequelTails) ?? [],
            banned: try container.decodeIfPresent([String].self, forKey: .banned) ?? []
        )
    }
}

// MARK: - The generator

/// Iteration 16 — S3. Suggests product names for a type and a topic.
///
/// A pure function of the pools, a seed and the names already in use: no
/// engine RNG, no state. The same seed gives the same names, a different
/// seed (the flow's *Shuffle* adds one to the reroll index it hashes in)
/// gives different ones, and nothing that is already taken, banned, or a
/// repeat within the batch comes back.
public enum ProductNameGenerator {
    /// Up to `count` distinct names, the ones carrying a topic stem first,
    /// each group in the order the draw found them. Fewer only when the
    /// pools cannot make that many that are free.
    ///
    /// - Parameters:
    ///   - seed: any 64-bit value; the caller hashes the run's seed, the
    ///     product count and the reroll index into it.
    ///   - taken: names already in use; compared by `key(_:)`, so case,
    ///     spaces and punctuation do not make a duplicate free.
    ///   - topicName: the topic's display name, for a topic the pools
    ///     have no stems for (its first word becomes the stem).
    public static func suggest(
        typeID: String,
        topicID: String,
        seed: UInt64,
        taken: Set<String>,
        count: Int,
        pools: ProductNamePools = .fallback,
        topicName: String? = nil
    ) -> [String] {
        guard count > 0 else { return [] }
        let stems = nonEmpty(pools.stemsByTopic[topicID])
            ?? topicName.flatMap { $0.split(separator: " ").first.map { [String($0)] } }
            ?? ["Nova"]
        let suffixes = nonEmpty(pools.suffixesByType[typeID]) ?? ["One", "Pro", "Kit"]
        let words = nonEmpty(pools.words) ?? stems
        let prefixes = nonEmpty(pools.prefixes) ?? ["Neo"]
        let tails = nonEmpty(pools.tails) ?? ["Pro"]
        let patterns = pools.patterns.filter { $0.weight > 0 }
        let totalWeight = patterns.reduce(0) { $0 + $1.weight }

        let takenKeys = Set(taken.map(key))
        let bannedKeys = Set(pools.banned.map(key))
        var stream = NameStream(seed: mix(seed ^ stableHash(typeID) ^ (stableHash(topicID) &* 0x9E37_79B9_7F4A_7C15)))
        // Names that carry a topic stem lead the batch: the first one
        // pre-fills the field, and "PaceGo" says fitness where "Laurel
        // Mango" says nothing.
        var topical: [String] = []
        var other: [String] = []
        var seen: Set<String> = []
        var found: Int { topical.count + other.count }

        func offer(_ name: String, topical isTopical: Bool) {
            let k = key(name)
            guard !k.isEmpty, !takenKeys.contains(k), !seen.contains(k), !isBanned(name, bannedKeys: bannedKeys) else { return }
            seen.insert(k)
            if isTopical { topical.append(name) } else { other.append(name) }
        }

        // The draw: a weighted pattern, then one word per placeholder.
        var attempts = 0
        while found < count, totalWeight > 0, attempts < count * 60 {
            attempts += 1
            var roll = Int(stream.next() % UInt64(totalWeight))
            var pattern = patterns[0]
            for candidate in patterns {
                if roll < candidate.weight { pattern = candidate; break }
                roll -= candidate.weight
            }
            if let name = fill(pattern.template, stems: stems, suffixes: suffixes, words: words,
                               prefixes: prefixes, tails: tails, stream: &stream) {
                offer(name, topical: pattern.template.contains("{stem}"))
            }
        }

        // The walk: a pool too small or too taken for the draw still gets
        // its names, stem × suffix, then with every tail, in order.
        if found < count {
            outer: for tail in [""] + tails {
                for stem in stems {
                    for suffix in suffixes where !sameFragment(stem, suffix) {
                        offer(tail.isEmpty ? stem + suffix : "\(stem)\(suffix) \(tail)", topical: true)
                        if found >= count { break outer }
                    }
                }
            }
        }
        return topical + other
    }

    /// The comparison form of a name: lowercased letters and digits only, so
    /// "Fit Track", "fittrack" and "FitTrack!" are one name.
    public static func key(_ name: String) -> String {
        String(name.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(Character.init))
    }

    /// Whether `name` is one of the pools' real names, whole or as any of
    /// its space-separated words.
    public static func isBanned(_ name: String, pools: ProductNamePools) -> Bool {
        isBanned(name, bannedKeys: Set(pools.banned.map(key)))
    }

    // MARK: Private

    private static func isBanned(_ name: String, bannedKeys: Set<String>) -> Bool {
        if bannedKeys.contains(key(name)) { return true }
        return name.split(separator: " ").contains { bannedKeys.contains(key(String($0))) }
    }

    private static func nonEmpty(_ list: [String]?) -> [String]? {
        guard let list, !list.isEmpty else { return nil }
        return list
    }

    /// One pattern filled, or `nil` when it came out repeating itself
    /// ("Loop Loop", "FlowFlow") or too long for a product page.
    private static func fill(
        _ template: String,
        stems: [String], suffixes: [String], words: [String],
        prefixes: [String], tails: [String],
        stream: inout NameStream
    ) -> String? {
        var output = ""
        var fragments: [String] = []
        var rest = Substring(template)
        while let open = rest.firstIndex(of: "{") {
            output += rest[rest.startIndex..<open]
            guard let close = rest[open...].firstIndex(of: "}") else { return nil }
            let slot = rest[rest.index(after: open)..<close]
            let pool: [String] = switch slot {
            case "stem": stems
            case "suffix": suffixes
            case "word": words
            case "prefix": prefixes
            case "tail": tails
            default: []
            }
            guard !pool.isEmpty else { return nil }
            let fragment = pool[Int(stream.next() % UInt64(pool.count))]
            if fragments.contains(where: { sameFragment($0, fragment) }) { return nil }
            fragments.append(fragment)
            output += fragment
            rest = rest[rest.index(after: close)...]
        }
        output += rest
        let name = output.trimmingCharacters(in: .whitespaces)
        return name.count <= 20 ? name : nil
    }

    private static func sameFragment(_ a: String, _ b: String) -> Bool {
        a.caseInsensitiveCompare(b) == .orderedSame
    }

    /// FNV-1a: a stable hash of an id, the same on every launch (Swift's
    /// `hashValue` is not).
    private static func stableHash(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }

    /// SplitMix64's finalizer.
    static func mix(_ value: UInt64) -> UInt64 {
        var z = value
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A private SplitMix64 stream: the generator's own, never the game's.
    private struct NameStream {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            return ProductNameGenerator.mix(state)
        }
    }
}

// MARK: end S3
