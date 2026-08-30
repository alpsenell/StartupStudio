/// The `"narrative"` block of `Balance.json` — event cadences, choice
/// deadlines, storyline pacing and the industry-news drumbeat.
///
/// The two cadence overrides are deliberately optional. When they are
/// absent the narrative system falls back to the legacy top-level
/// `eventCheckIntervalDays` / `eventChance` keys, so every balance written
/// before the narrative engine existed — including the hand-tuned quiet
/// configurations the engine tests are built on — rolls exactly as it did.
/// The shipped `Balance.json` sets them, which is what moves the game from
/// "one event a month, maybe" to a weekly beat.
extension BalanceConfig {
    public struct NarrativeBalance: Codable, Equatable, Sendable {
        /// How often the company-event roll happens. `nil` = the legacy
        /// `eventCheckIntervalDays`.
        public var companyEventIntervalDays: Int?
        /// The chance the roll hits. `nil` = the legacy `eventChance`.
        public var companyEventChance: Double?
        /// How often the life-event roll happens. `nil` = the legacy
        /// `life.lifeEventIntervalDays`.
        public var lifeEventIntervalDays: Int?
        /// The chance the life roll hits. `nil` = `life.lifeEventChance`.
        public var lifeEventChance: Double?
        /// The default number of days a choice stays open when its def
        /// doesn't say.
        public var respondByDays: Int
        /// A narrative beat never fires within this many days of the last
        /// one, whichever catalog it came from. Keeps a company roll and a
        /// life roll landing on the same day from double-pausing.
        public var minDaysBetweenBeats: Int
        /// Days an event that doesn't set its own `cooldownDays` waits
        /// before it can be drawn again.
        public var defaultCooldownDays: Int
        /// How often an industry-news headline is generated (0 = never).
        public var newsIntervalDays: Int
        /// The chance the news roll produces a headline.
        public var newsChance: Double

        public init(
            companyEventIntervalDays: Int? = nil,
            companyEventChance: Double? = nil,
            lifeEventIntervalDays: Int? = nil,
            lifeEventChance: Double? = nil,
            respondByDays: Int = 5,
            minDaysBetweenBeats: Int = 0,
            defaultCooldownDays: Int = 0,
            newsIntervalDays: Int = 7,
            newsChance: Double = 0.55
        ) {
            self.companyEventIntervalDays = companyEventIntervalDays
            self.companyEventChance = companyEventChance
            self.lifeEventIntervalDays = lifeEventIntervalDays
            self.lifeEventChance = lifeEventChance
            self.respondByDays = respondByDays
            self.minDaysBetweenBeats = minDaysBetweenBeats
            self.defaultCooldownDays = defaultCooldownDays
            self.newsIntervalDays = newsIntervalDays
            self.newsChance = newsChance
        }

        /// What a balance file with no `"narrative"` object gets: the
        /// legacy cadence, no cooldowns, no spacing rule and no news —
        /// i.e. exactly the pre-narrative behavior. Every number that
        /// makes the story engine feel like a story engine is set in the
        /// shipped `Balance.json`.
        public static let `default` = NarrativeBalance(newsIntervalDays: 0)

        private enum CodingKeys: String, CodingKey {
            case companyEventIntervalDays, companyEventChance
            case lifeEventIntervalDays, lifeEventChance
            case respondByDays, minDaysBetweenBeats, defaultCooldownDays
            case newsIntervalDays, newsChance
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
                companyEventIntervalDays: try container.decodeIfPresent(
                    Int.self, forKey: .companyEventIntervalDays
                ),
                companyEventChance: try container.decodeIfPresent(
                    Double.self, forKey: .companyEventChance
                ),
                lifeEventIntervalDays: try container.decodeIfPresent(
                    Int.self, forKey: .lifeEventIntervalDays
                ),
                lifeEventChance: try container.decodeIfPresent(
                    Double.self, forKey: .lifeEventChance
                ),
                respondByDays: try container.decodeIfPresent(Int.self, forKey: .respondByDays) ?? 5,
                minDaysBetweenBeats: try container.decodeIfPresent(
                    Int.self, forKey: .minDaysBetweenBeats
                ) ?? 0,
                defaultCooldownDays: try container.decodeIfPresent(
                    Int.self, forKey: .defaultCooldownDays
                ) ?? 0,
                newsIntervalDays: try container.decodeIfPresent(
                    Int.self, forKey: .newsIntervalDays
                ) ?? 0,
                newsChance: try container.decodeIfPresent(Double.self, forKey: .newsChance) ?? 0.55
            )
        }
    }
}

// Lets `BalanceConfig`'s synthesized decoder read a balance file that has
// no `"narrative"` object at all: the concrete overload wins over the generic
// `decode(_:forKey:)`, turning the required key into
// `decodeIfPresent ?? .default`.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.NarrativeBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.NarrativeBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}
