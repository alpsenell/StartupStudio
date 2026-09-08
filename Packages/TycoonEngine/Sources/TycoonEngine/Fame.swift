import Foundation
import TycoonContent

// Iteration 11 — N4 owns this file. The founder's public feed, followers,
// fame, and the things fame brings.
//
// The whole lane hangs off one invariant: **fame zero is the game that
// shipped**. `FameState.empty` is what every run starts with and what
// every run that never opens the feed still holds on the last day, so
// `GameState` writes no `fame` key at all, `FameSystem.run` returns on its
// first line, and the four places fame reaches into the rest of the game
// (`MarketingSystem`, `HiringSystem`, `PitchSystem`, the newspaper) each
// multiply by one. No bot posts. No fixture posts. Nothing here draws a
// number until the founder taps *Post*.

// MARK: - What a post is

/// The four things the founder can put on the feed, plus the reply they
/// can fire back inside a beef.
///
/// The kind is the whole of the risk model: a subtweet reaches furthest
/// and is the only one that can start a beef, a photo reaches least and
/// cannot hurt anybody.
public enum FamePostKind: String, Codable, Equatable, Sendable, CaseIterable {
    /// An opinion about the industry. The bread and butter.
    case take
    /// Something the company actually did. Reaches further while a build
    /// is close to shipping, because there is a thing to point at.
    case launch
    /// The office, the desk, the whiteboard. Small, safe, warm.
    case photo
    /// A named rival, addressed sideways. The only kind that opens a beef.
    case subtweet
    /// A line inside a beef. Never composed on its own.
    case reply

    public var displayName: String {
        switch self {
        case .take: "Take"
        case .launch: "Launch"
        case .photo: "Photo"
        case .subtweet: "Subtweet"
        case .reply: "Reply"
        }
    }

    /// The one-line promise on the compose sheet's button.
    public var promise: String {
        switch self {
        case .take: "An opinion. Reaches the people who already follow you."
        case .launch: "What you are building. Reaches furthest with a build close to shipping."
        case .photo: "The office as it stands. Small reach, no enemies."
        case .subtweet: "A rival, named sideways. The furthest reach and a grudge with it."
        case .reply: "A line back."
        }
    }

    public var systemImage: String {
        switch self {
        case .take: "quote.bubble.fill"
        case .launch: "shippingbox.fill"
        case .photo: "camera.fill"
        case .subtweet: "flame.fill"
        case .reply: "arrowshape.turn.up.left.fill"
        }
    }
}

/// One line the world said back under a post. Written from `Feed.json`, so
/// two identical states hold identical replies.
public struct FameReply: Codable, Equatable, Sendable, Identifiable {
    /// Ordinal within the post, so identical states encode identically.
    public var id: Int
    /// "@half_a_cto".
    public var handle: String
    public var text: String

    public init(id: Int, handle: String, text: String) {
        self.id = id
        self.handle = handle
        self.text = text
    }
}

public struct FeedPost: Codable, Equatable, Sendable, Identifiable {
    /// Ordinal, so identical states encode identically.
    public var id: Int
    public var day: Int
    public var text: String
    public var reach: Int
    /// What was posted. Defaults to `.take` so a save written by the
    /// scaffold's three-field `FeedPost` still decodes.
    public var kind: FamePostKind
    /// The `Feed.json` template this came from, for the record.
    public var templateID: String
    /// The rival a subtweet was about, empty otherwise.
    public var subject: String
    /// Followers this post brought in.
    public var followerGain: Int
    /// Whether the reach roll came up long. The feed draws a flame on it.
    public var viral: Bool
    /// What the world said back.
    public var replies: [FameReply]

    public init(
        id: Int,
        day: Int,
        text: String,
        reach: Int,
        kind: FamePostKind = .take,
        templateID: String = "",
        subject: String = "",
        followerGain: Int = 0,
        viral: Bool = false,
        replies: [FameReply] = []
    ) {
        self.id = id
        self.day = day
        self.text = text
        self.reach = reach
        self.kind = kind
        self.templateID = templateID
        self.subject = subject
        self.followerGain = followerGain
        self.viral = viral
        self.replies = replies
    }

    private enum CodingKeys: String, CodingKey {
        case id, day, text, reach, kind, templateID, subject, followerGain, viral, replies
    }

    /// Decode-if-present on everything the scaffold's `FeedPost` did not
    /// have, so a save written before this lane still loads.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(Int.self, forKey: .id),
            day: try container.decode(Int.self, forKey: .day),
            text: try container.decode(String.self, forKey: .text),
            reach: try container.decode(Int.self, forKey: .reach),
            kind: try container.decodeIfPresent(FamePostKind.self, forKey: .kind) ?? .take,
            templateID: try container.decodeIfPresent(String.self, forKey: .templateID) ?? "",
            subject: try container.decodeIfPresent(String.self, forKey: .subject) ?? "",
            followerGain: try container.decodeIfPresent(Int.self, forKey: .followerGain) ?? 0,
            viral: try container.decodeIfPresent(Bool.self, forKey: .viral) ?? false,
            replies: try container.decodeIfPresent([FameReply].self, forKey: .replies) ?? []
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(day, forKey: .day)
        try container.encode(text, forKey: .text)
        try container.encode(reach, forKey: .reach)
        try container.encode(kind, forKey: .kind)
        if !templateID.isEmpty { try container.encode(templateID, forKey: .templateID) }
        if !subject.isEmpty { try container.encode(subject, forKey: .subject) }
        if followerGain != 0 { try container.encode(followerGain, forKey: .followerGain) }
        if viral { try container.encode(viral, forKey: .viral) }
        if !replies.isEmpty { try container.encode(replies, forKey: .replies) }
    }
}

// MARK: - The beef

/// A rival founder answering back in public. Opened by a subtweet, kept
/// alive by escalating, closed by letting it go — or by a fortnight of
/// silence, which is the same thing said slower.
public struct FameBeef: Codable, Equatable, Sendable {
    /// The rival's name as it is printed. Names, not ids, because a rival
    /// can leave the board and the beef is still a thing that happened.
    public var rivalName: String
    public var openedDay: Int
    /// How many times it has gone around. Each round is louder.
    public var rounds: Int
    /// The last thing they said.
    public var theirLine: String
    /// The last thing the founder said.
    public var yourLine: String
    /// Set the day the founder escalated, so the feed can say "your move".
    public var waitingOnYou: Bool

    public init(
        rivalName: String,
        openedDay: Int,
        rounds: Int = 1,
        theirLine: String,
        yourLine: String = "",
        waitingOnYou: Bool = true
    ) {
        self.rivalName = rivalName
        self.openedDay = openedDay
        self.rounds = rounds
        self.theirLine = theirLine
        self.yourLine = yourLine
        self.waitingOnYou = waitingOnYou
    }
}

// MARK: - The cancellation

/// An old post surfaces. Three ways out, none of them clean.
public enum FameCancelResponse: String, Codable, Equatable, Sendable, CaseIterable {
    /// Costs followers, keeps the fame. The adult answer.
    case apologise
    /// Keeps the followers you have left and burns the rest of the room.
    case doubleDown
    /// Cheapest and worst: everybody screenshots a deletion.
    case delete

    public var displayName: String {
        switch self {
        case .apologise: "Apologise"
        case .doubleDown: "Double down"
        case .delete: "Delete it"
        }
    }
}

public struct FameCancellation: Codable, Equatable, Sendable {
    public var raisedDay: Int
    /// The line somebody dug up, drawn from `Feed.json`.
    public var quote: String
    /// The id of the founder's own post it was dug out of, when it was one
    /// of theirs; `nil` when the world invented it.
    public var postID: Int?
    /// Set once answered, so the card can show what was said.
    public var response: FameCancelResponse?

    public init(
        raisedDay: Int, quote: String, postID: Int? = nil, response: FameCancelResponse? = nil
    ) {
        self.raisedDay = raisedDay
        self.quote = quote
        self.postID = postID
        self.response = response
    }
}

// MARK: - Levels

/// What fame is worth, in five steps. Every step is a threshold in
/// `BalanceConfig.FameBalance`, and step zero — *unknown* — is the game
/// that shipped.
public enum FameLevel: Int, Codable, Equatable, Sendable, CaseIterable, Comparable {
    case unknown = 0
    case known
    case followed
    case notable
    case famous
    case star

    public static func < (lhs: FameLevel, rhs: FameLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var displayName: String {
        switch self {
        case .unknown: "Unknown"
        case .known: "Known"
        case .followed: "Followed"
        case .notable: "Notable"
        case .famous: "Famous"
        case .star: "A name"
        }
    }

    /// The single sentence the fame card prints for "what this buys".
    public var buys: String {
        switch self {
        case .unknown: "Nothing yet. Nobody has heard of you."
        case .known: "A little hype on everything you build."
        case .followed: "People apply without being asked."
        case .notable: "Journalists sit down warm. The book deal comes."
        case .famous: "The keynote, the podcast, and a queue at the door."
        case .star: "Television. And everything television brings."
        }
    }

    /// The story flag this level raises. `fame_*` life events gate on
    /// these, which is what keeps them out of a run that never posts:
    /// the flag is never raised, the events are never eligible, and the
    /// weighted pick draws exactly the word it drew before.
    public var flag: String? {
        switch self {
        case .unknown: nil
        case .known: "fame_public"
        case .followed: "fame_followed"
        case .notable: "fame_notable"
        case .famous: "fame_famous"
        case .star: "fame_star"
        }
    }

    public var next: FameLevel? {
        FameLevel(rawValue: rawValue + 1)
    }
}

// MARK: - The state

public struct FameState: Codable, Equatable, Sendable {
    public var followers: Int
    /// 0…100.
    public var fame: Double
    public var posts: [FeedPost]
    /// The next post's ordinal. Never reused, so a deleted post does not
    /// hand its id to the next one.
    public var nextPostID: Int
    /// The last day the founder posted. One post a day.
    public var lastPostDay: Int?
    /// The highest level reached, so `.fameLevelReached` fires once per
    /// step even when fame slides back down and climbs again.
    public var highWaterLevel: Int
    public var beef: FameBeef?
    public var cancellation: FameCancellation?
    /// The things fame has bought, in the order they arrived: "book",
    /// "podcast", "keynote", "tv". Content ids, so the card can print them.
    public var perks: [String]
    /// The last week `HiringSystem` was asked for inbound applicants, so
    /// the pool widens once a week rather than once a day.
    public var lastInboundWeek: Int

    public init(
        followers: Int = 0,
        fame: Double = 0,
        posts: [FeedPost] = [],
        nextPostID: Int = 0,
        lastPostDay: Int? = nil,
        highWaterLevel: Int = 0,
        beef: FameBeef? = nil,
        cancellation: FameCancellation? = nil,
        perks: [String] = [],
        lastInboundWeek: Int = -1
    ) {
        self.followers = followers
        self.fame = fame
        self.posts = posts
        self.nextPostID = nextPostID
        self.lastPostDay = lastPostDay
        self.highWaterLevel = highWaterLevel
        self.beef = beef
        self.cancellation = cancellation
        self.perks = perks
        self.lastInboundWeek = lastInboundWeek
    }

    public static let empty = FameState()

    private enum CodingKeys: String, CodingKey {
        case followers, fame, posts, nextPostID, lastPostDay, highWaterLevel
        case beef, cancellation, perks, lastInboundWeek
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            followers: try container.decodeIfPresent(Int.self, forKey: .followers) ?? 0,
            fame: try container.decodeIfPresent(Double.self, forKey: .fame) ?? 0,
            posts: try container.decodeIfPresent([FeedPost].self, forKey: .posts) ?? [],
            nextPostID: try container.decodeIfPresent(Int.self, forKey: .nextPostID) ?? 0,
            lastPostDay: try container.decodeIfPresent(Int.self, forKey: .lastPostDay),
            highWaterLevel: try container.decodeIfPresent(Int.self, forKey: .highWaterLevel) ?? 0,
            beef: try container.decodeIfPresent(FameBeef.self, forKey: .beef),
            cancellation: try container.decodeIfPresent(FameCancellation.self, forKey: .cancellation),
            perks: try container.decodeIfPresent([String].self, forKey: .perks) ?? [],
            lastInboundWeek: try container.decodeIfPresent(Int.self, forKey: .lastInboundWeek) ?? -1
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(followers, forKey: .followers)
        try container.encode(fame, forKey: .fame)
        if !posts.isEmpty { try container.encode(posts, forKey: .posts) }
        if nextPostID != 0 { try container.encode(nextPostID, forKey: .nextPostID) }
        try container.encodeIfPresent(lastPostDay, forKey: .lastPostDay)
        if highWaterLevel != 0 { try container.encode(highWaterLevel, forKey: .highWaterLevel) }
        try container.encodeIfPresent(beef, forKey: .beef)
        try container.encodeIfPresent(cancellation, forKey: .cancellation)
        if !perks.isEmpty { try container.encode(perks, forKey: .perks) }
        if lastInboundWeek != -1 { try container.encode(lastInboundWeek, forKey: .lastInboundWeek) }
    }

    /// Newest first — the order a feed reads in.
    public var byRecency: [FeedPost] {
        posts.sorted { ($0.day, $0.id) > ($1.day, $1.id) }
    }

    /// The reach of everything posted inside the trailing window. The
    /// second half of the fame formula, and the half that fades.
    public func recentReach(day: Int, window: Int) -> Int {
        posts.filter { $0.day > day - window }.reduce(0) { $0 + $1.reach }
    }
}

// MARK: - The pure half

/// What a follower count is worth, what a post reaches, and what fame
/// buys. Pure functions with the balance passed in, so the app can print
/// the same numbers the tick applies — and so every one of them reads
/// exactly one, or exactly zero, at fame zero.
public enum Fame {

    /// The level a fame reads as.
    public static func level(_ fame: Double, balance: BalanceConfig.FameBalance) -> FameLevel {
        if fame >= balance.starAt { return .star }
        if fame >= balance.famousAt { return .famous }
        if fame >= balance.notableAt { return .notable }
        if fame >= balance.followedAt { return .followed }
        if fame >= balance.knownAt { return .known }
        return .unknown
    }

    /// The fame a level starts at, for the card's "next thing" progress.
    public static func threshold(
        _ level: FameLevel, balance: BalanceConfig.FameBalance
    ) -> Double {
        switch level {
        case .unknown: 0
        case .known: balance.knownAt
        case .followed: balance.followedAt
        case .notable: balance.notableAt
        case .famous: balance.famousAt
        case .star: balance.starAt
        }
    }

    /// **The fame formula.** A slow function of followers and of what the
    /// last fortnight actually reached, approached a little each day and
    /// leaking a little each day — so a founder who stops posting fades
    /// rather than freezes.
    ///
    ///     followerScore = min(cap, sqrt(followers) × famePerRootFollower)
    ///     reachScore    = min(cap, recentReach / reachPerFamePoint)
    ///     target        = followerScore + reachScore
    ///     fame'         = clamp(fame + (target − fame) × approach − decay)
    ///
    /// At zero followers and no posts the target is zero, the approach
    /// moves nothing, and the decay has nothing to take: identity.
    public static func target(
        followers: Int, recentReach: Int, balance: BalanceConfig.FameBalance
    ) -> Double {
        let followerScore = min(
            balance.followerScoreCap,
            (Double(max(0, followers))).squareRoot() * balance.famePerRootFollower
        )
        let reachScore = balance.reachPerFamePoint > 0
            ? min(balance.reachScoreCap, Double(max(0, recentReach)) / balance.reachPerFamePoint)
            : 0
        return min(100, followerScore + reachScore)
    }

    /// **The reach formula.** One `socialRNG` word, and everything else is
    /// the state the founder built:
    ///
    ///     audience = reachBase + ceiling × f / (f + ceiling/perFollower)
    ///     fameMult = 1 + fame/100 × reachFameSpan
    ///     roll     = rollFloor … rollCeiling, uniform
    ///     reach    = audience × fameMult × kindMult × newsMult × roll
    ///     viral    = roll ≥ viralRoll  → reach × viralMultiplier
    ///
    /// The audience **saturates**, and that is the whole balance argument
    /// of this lane. A linear `followers × perFollower` compounds — every
    /// post buys followers, which buy reach, which buy followers — and a
    /// founder who posts daily for three game years ends with tens of
    /// millions of them, which is not a tycoon game, it is a spreadsheet
    /// with a flame on it. The curve above has slope `reachPerFollower` at
    /// zero followers, so the first hundred are exactly as hard as they
    /// look, and an asymptote at `reachBase + reachAudienceCeiling`, so
    /// the thousandth post reaches barely more than the five-hundredth and
    /// the follower count settles in the hundreds of thousands rather than
    /// running away. Fame's own multiplier is what still grows past that.
    ///
    /// `newsMult` is the day's weather: a post that lands the week the
    /// industry is talking about something travels further.
    public static func reach(
        followers: Int,
        fame: Double,
        kindMultiplier: Double,
        newsMultiplier: Double,
        roll: Double,
        balance: BalanceConfig.FameBalance
    ) -> (reach: Int, viral: Bool) {
        let people = Double(max(0, followers))
        let half = balance.reachPerFollower > 0
            ? balance.reachAudienceCeiling / balance.reachPerFollower
            : .infinity
        let audience = balance.reachBase
            + (half.isFinite ? balance.reachAudienceCeiling * people / (people + half) : 0)
        let fameMult = 1 + (fame / 100) * balance.reachFameSpan
        let viral = roll >= balance.viralRoll
        let raw = audience * fameMult * kindMultiplier * newsMultiplier * roll
            * (viral ? balance.viralMultiplier : 1)
        return (Int(max(0, raw).rounded()), viral)
    }

    /// Followers a reach brings in. Linear and small: the follower count
    /// is the slow number and reach is the fast one.
    public static func followerGain(
        reach: Int, balance: BalanceConfig.FameBalance
    ) -> Int {
        Int((Double(max(0, reach)) * balance.followersPerReach).rounded())
    }

    // MARK: What fame buys

    /// Daily hype a fame adds to every build in development
    /// (`MarketingSystem`'s N4 region). Exactly zero at fame zero.
    public static func dailyHype(_ fame: Double, balance: BalanceConfig.FameBalance) -> Double {
        max(0, fame) * balance.hypePerFamePointDaily
    }

    /// Applicants a week fame brings to the hiring desk without being
    /// asked (`HiringSystem`'s N4 region). Zero below `followedAt`.
    public static func inboundApplicants(
        _ fame: Double, balance: BalanceConfig.FameBalance
    ) -> Int {
        guard fame >= balance.followedAt else { return 0 }
        let over = fame - balance.followedAt
        return min(
            balance.inboundApplicantsMax,
            1 + Int(over / max(1, balance.famePerExtraApplicant))
        )
    }

    /// The warmth a journalist sits down with (`PitchSystem`'s N4 region).
    /// Zero at fame zero, so the pitch room's own invariant — warmth zero
    /// is the paper as written — is untouched by a founder who never
    /// posted.
    public static func journalistWarmth(
        _ fame: Double, balance: BalanceConfig.FameBalance
    ) -> Double {
        guard fame > 0 else { return 0 }
        return min(balance.journalistWarmthCap, fame * balance.journalistWarmthPerFamePoint)
    }

    /// The perk a level brings with it, once. `nil` for the levels that
    /// bring a number rather than a thing.
    public static func perk(for level: FameLevel) -> String? {
        switch level {
        case .unknown, .known: nil
        case .followed: "podcast"
        case .notable: "book"
        case .famous: "keynote"
        case .star: "tv"
        }
    }

    // MARK: What the app asks

    /// Why the founder cannot post this kind right now, or `nil`. The
    /// compose sheet prints it under the row — rule 7: a refused action
    /// says why before it is tapped.
    public static func postBlocker(
        kind: FamePostKind, state: GameState, content: ContentCatalog
    ) -> String? {
        FameSystem.postBlocker(kind: kind, state: state, content: content)
    }

    // MARK: Filling copy

    /// `{company}`, `{product}`, `{topic}`, `{rival}`, `{followers}` — the
    /// five placeholders `Feed.json` may use. Public because the
    /// newspaper's beef column fills a headline from the app side.
    public static func fill(_ text: String, state: GameState, rival: String) -> String {
        var out = text
        if out.contains("{company}") {
            out = out.replacingOccurrences(of: "{company}", with: state.company.name)
        }
        if out.contains("{product}") {
            let name = state.productsInDevelopment.first?.name
                ?? state.products.last?.name
                ?? "the thing"
            out = out.replacingOccurrences(of: "{product}", with: name)
        }
        if out.contains("{topic}") {
            let topic = state.market.standing.keys.sorted().first ?? "software"
            out = out.replacingOccurrences(
                of: "{topic}", with: topic.replacingOccurrences(of: "_", with: " ")
            )
        }
        if out.contains("{rival}") {
            out = out.replacingOccurrences(
                of: "{rival}", with: rival.isEmpty ? "a certain studio" : rival
            )
        }
        if out.contains("{followers}") {
            out = out.replacingOccurrences(
                of: "{followers}", with: "\(state.fame.followers)"
            )
        }
        return out
    }

    /// The line the fame card prints for an earned perk.
    public static func perkLine(_ perk: String) -> String {
        switch perk {
        case "podcast": "A podcast wants an hour of your time."
        case "book": "A publisher wants the book. They have a title already."
        case "keynote": "The conference wants the keynote slot, unpaid, honoured."
        case "tv": "A television producer left three voicemails."
        default: perk
        }
    }
}
