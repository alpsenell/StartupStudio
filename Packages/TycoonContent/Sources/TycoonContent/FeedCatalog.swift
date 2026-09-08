import Foundation

// Iteration 11 — N4. What the founder posts, what the world says back, and
// what the paper prints about it.
//
// All copy, no rules: the engine picks by kind and gate and fills the
// placeholders. `{company}`, `{product}`, `{topic}`, `{rival}` and
// `{followers}` are the five the engine knows how to fill; anything else
// is left alone.

/// One thing the founder can post, in their own voice.
public struct FeedTemplateDef: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    /// `FamePostKind` raw value: "take", "launch", "photo", "subtweet".
    public var kind: String
    /// The line. Placeholders as above.
    public var text: String
    /// Relative pick weight, >= 1.
    public var weight: Int
    /// Only offered at or above this fame. 0 = always.
    public var minFame: Double
    /// Only offered while the studio has a build in development.
    public var requiresBuild: Bool
    /// Only offered while the studio has something on the market.
    public var requiresLiveProduct: Bool
    /// Only offered once there is somebody else on the payroll.
    public var requiresTeam: Bool

    public init(
        id: String,
        kind: String,
        text: String,
        weight: Int = 1,
        minFame: Double = 0,
        requiresBuild: Bool = false,
        requiresLiveProduct: Bool = false,
        requiresTeam: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.weight = weight
        self.minFame = minFame
        self.requiresBuild = requiresBuild
        self.requiresLiveProduct = requiresLiveProduct
        self.requiresTeam = requiresTeam
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, text, weight, minFame, requiresBuild, requiresLiveProduct, requiresTeam
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            kind: try container.decode(String.self, forKey: .kind),
            text: try container.decode(String.self, forKey: .text),
            weight: try container.decodeIfPresent(Int.self, forKey: .weight) ?? 1,
            minFame: try container.decodeIfPresent(Double.self, forKey: .minFame) ?? 0,
            requiresBuild: try container.decodeIfPresent(Bool.self, forKey: .requiresBuild) ?? false,
            requiresLiveProduct: try container.decodeIfPresent(
                Bool.self, forKey: .requiresLiveProduct
            ) ?? false,
            requiresTeam: try container.decodeIfPresent(Bool.self, forKey: .requiresTeam) ?? false
        )
    }
}

/// A stranger, under the post.
public struct FeedReplyDef: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    /// "@half_a_cto".
    public var handle: String
    public var text: String
    /// "warm", "cold", "weird". The engine picks warm above the reach the
    /// post deserved and cold below it; weird is always in the pool,
    /// because the internet is.
    public var tone: String
    /// Only drawn on a post of this kind. Empty = any.
    public var kind: String

    public init(id: String, handle: String, text: String, tone: String = "weird", kind: String = "") {
        self.id = id
        self.handle = handle
        self.text = text
        self.tone = tone
        self.kind = kind
    }

    private enum CodingKeys: String, CodingKey {
        case id, handle, text, tone, kind
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            handle: try container.decode(String.self, forKey: .handle),
            text: try container.decode(String.self, forKey: .text),
            tone: try container.decodeIfPresent(String.self, forKey: .tone) ?? "weird",
            kind: try container.decodeIfPresent(String.self, forKey: .kind) ?? ""
        )
    }
}

/// A line the newspaper's beef column can print.
public struct FeedHeadlineDef: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var text: String
    /// `FameLevel` raw value the founder must have reached. 0 = any.
    public var minLevel: Int
    /// "fame", "beef", "cancel" — which of the paper's three fame stories
    /// this belongs to.
    public var strand: String

    public init(id: String, text: String, minLevel: Int = 0, strand: String = "fame") {
        self.id = id
        self.text = text
        self.minLevel = minLevel
        self.strand = strand
    }

    private enum CodingKeys: String, CodingKey {
        case id, text, minLevel, strand
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            text: try container.decode(String.self, forKey: .text),
            minLevel: try container.decodeIfPresent(Int.self, forKey: .minLevel) ?? 0,
            strand: try container.decodeIfPresent(String.self, forKey: .strand) ?? "fame"
        )
    }
}

/// The whole file.
public struct FeedCatalog: Codable, Equatable, Sendable {
    /// What the founder can post.
    public var templates: [FeedTemplateDef]
    /// What the world says back.
    public var replies: [FeedReplyDef]
    /// What the paper prints.
    public var headlines: [FeedHeadlineDef]
    /// What a rival says when a subtweet lands, in escalation order: the
    /// engine takes round *n* modulo the list.
    public var beefLines: [String]
    /// What the founder says back when they escalate.
    public var beefReplies: [String]
    /// The lines that get dug up years later.
    public var cancelQuotes: [String]

    public init(
        templates: [FeedTemplateDef] = [],
        replies: [FeedReplyDef] = [],
        headlines: [FeedHeadlineDef] = [],
        beefLines: [String] = [],
        beefReplies: [String] = [],
        cancelQuotes: [String] = []
    ) {
        self.templates = templates
        self.replies = replies
        self.headlines = headlines
        self.beefLines = beefLines
        self.beefReplies = beefReplies
        self.cancelQuotes = cancelQuotes
    }

    public static let empty = FeedCatalog()

    private enum CodingKeys: String, CodingKey {
        case templates, replies, headlines, beefLines, beefReplies, cancelQuotes
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            templates: try container.decodeIfPresent([FeedTemplateDef].self, forKey: .templates) ?? [],
            replies: try container.decodeIfPresent([FeedReplyDef].self, forKey: .replies) ?? [],
            headlines: try container.decodeIfPresent([FeedHeadlineDef].self, forKey: .headlines) ?? [],
            beefLines: try container.decodeIfPresent([String].self, forKey: .beefLines) ?? [],
            beefReplies: try container.decodeIfPresent([String].self, forKey: .beefReplies) ?? [],
            cancelQuotes: try container.decodeIfPresent([String].self, forKey: .cancelQuotes) ?? []
        )
    }

    /// Every template of one kind, in file order.
    public func templates(kind: String) -> [FeedTemplateDef] {
        templates.filter { $0.kind == kind }
    }

    /// The terse fallback, used when `Feed.json` is not in the bundle at
    /// all — so the feed still works rather than posting empty strings.
    public static let fallback = FeedCatalog(
        templates: [
            FeedTemplateDef(id: "take_fallback", kind: "take", text: "Building is the easy part."),
            FeedTemplateDef(id: "launch_fallback", kind: "launch", text: "{product}. Soon."),
            FeedTemplateDef(id: "photo_fallback", kind: "photo", text: "The office, today."),
            FeedTemplateDef(id: "subtweet_fallback", kind: "subtweet", text: "Some studios ship. Some announce."),
        ],
        replies: [FeedReplyDef(id: "reply_fallback", handle: "@anon", text: "ok")],
        beefLines: ["We both know who you mean."],
        beefReplies: ["I did not say a name."],
        cancelQuotes: ["Anyone who takes a holiday in year one is not serious."]
    )
}
