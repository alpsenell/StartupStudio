/// Time-of-day, weather and season for every scene that can show them
/// (office, home, city). Cosmetic only: nothing here comes from — or feeds
/// back into — the simulation.
///
/// WS-D authors the art variants behind these; WS-C drives the office ones
/// from the scene's own clock. Every consumer defaults to `.day` / `.clear`,
/// which is the brightest, most readable version of each scene.

/// Where the day is.
public enum TimeOfDay: String, Sendable, Equatable, Codable, CaseIterable {
    case morning, day, dusk, night

    /// How far this hour is toward full night, 0 (noon) … 1 (midnight).
    /// Room builders and the lighting overlay both key off this.
    var darkness: Double {
        switch self {
        case .morning: 0.10
        case .day: 0.0
        case .dusk: 0.32
        case .night: 0.58
        }
    }

    /// The warm/cool cast of the hour: morning is cool-blue, dusk is amber,
    /// night is deep indigo, midday is neutral.
    var cast: (color: RGBA, amount: Double) {
        switch self {
        case .morning: (Palettes.sky[1], 0.14)
        case .day: (Palettes.stone[0], 0.0)
        case .dusk: (Palettes.ember[2], 0.20)
        case .night: (Palettes.indigo[4], 0.26)
        }
    }

    /// Whether interior lights, lit windows and lamps should read as "on".
    public var needsArtificialLight: Bool { self == .dusk || self == .night }
}

/// What it is doing outside the window.
public enum Weather: String, Sendable, Equatable, Codable, CaseIterable {
    case clear, rain, snow
}

/// Which window a scene is asking for. Office and home windows have their
/// own day/dusk/night/rain/snow frames.
public enum WindowStyle: String, Sendable, Equatable, Codable, CaseIterable {
    case office, home
}

/// The season, which tints the city's trees.
public enum Season: String, Sendable, Equatable, Codable, CaseIterable {
    case spring, summer, autumn, winter

    /// (leaf, highlight) foliage tones for the season.
    var foliage: (base: RGBA, highlight: RGBA) {
        switch self {
        case .spring: (Palettes.moss[2], Palettes.moss[0])
        case .summer: (Palettes.moss[3], Palettes.moss[1])
        case .autumn: (Palettes.ember[3], Palettes.gold[2])
        case .winter: (Palettes.stone[3], Palettes.stone[1])
        }
    }
}

/// What the home scene needs to know about the world outside the founder's
/// evening. Defaults reproduce the scene as it looked before: an evening at
/// home on a clear weekday.
public struct HomeAmbience: Sendable, Equatable, Hashable {
    public var timeOfDay: TimeOfDay
    public var weather: Weather
    public var isWeekend: Bool

    public init(timeOfDay: TimeOfDay = .night, weather: Weather = .clear, isWeekend: Bool = false) {
        self.timeOfDay = timeOfDay
        self.weather = weather
        self.isWeekend = isWeekend
    }

    /// The evening the Life tab has always shown.
    public static let evening = HomeAmbience()
}

/// What the city map needs to know: the hour, the season, and how big the
/// player's own headquarters has grown.
public struct CityAmbience: Sendable, Equatable, Hashable {
    public var timeOfDay: TimeOfDay
    public var season: Season
    /// The player's office tier — their HQ building grows with it.
    public var playerTier: OfficeTierStyle
    // MARK: Iteration 18 — the studio mark
    /// The studio's mark, for the sign on the player's HQ. `nil` — the
    /// default, and every caller that predates marks — draws the map
    /// exactly as it always was.
    public var markSeed: UInt64?
    // MARK: end of Iteration 18

    public init(
        timeOfDay: TimeOfDay = .day, season: Season = .summer, playerTier: OfficeTierStyle = .garage,
        markSeed: UInt64? = nil
    ) {
        self.timeOfDay = timeOfDay
        self.season = season
        self.playerTier = playerTier
        self.markSeed = markSeed
    }

    /// Midday in high summer, the map as it looked before ambience existed.
    public static let noon = CityAmbience()
}
