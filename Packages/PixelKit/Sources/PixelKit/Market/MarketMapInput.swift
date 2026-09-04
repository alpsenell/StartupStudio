import Foundation

/// How much of a category the studio's name is worth, in the five rungs
/// the market screens already name. PixelKit never imports the engine, so
/// the app maps standing onto a band and the map colours the district by
/// it — greyer is nobody's, greener is more yours.
public enum StandingBand: String, Sendable, Equatable, Hashable, CaseIterable {
    case none, newcomer, known, established, household

    /// The district's ground tone.
    var ground: RGBA {
        switch self {
        case .none: Palettes.stone[2]
        case .newcomer: Palettes.sand[1]
        case .known: Palettes.moss[1]
        case .established: Palettes.moss[2]
        case .household: Palettes.teal[2]
        }
    }
}

/// The forward read on a category the studio holds, drawn as weather over
/// the district. Absent where the studio has not earned the read — the
/// absence is the mechanic, so the map shows nothing rather than a guess.
public enum MarketWeather: String, Sendable, Equatable, Hashable, CaseIterable {
    /// The band leans warmer than today.
    case sunny
    /// The band sits on today's number.
    case overcast
    /// The band leans cooler.
    case rain
    /// A boom or crash is more likely than not inside the window.
    case storm
}

/// One topic as the map draws it. Plain data: the app fills it from the
/// engine, PixelKit never sees a `GameState`.
public struct MarketDistrictInfo: Sendable, Equatable, Hashable, Identifiable {
    /// The topic id, handed back on a tap.
    public var id: String
    /// The display name, for the label the app lays over the district.
    public var name: String
    /// How big the market is, 0…1 — the district's footprint.
    public var size: Double
    /// The studio's standing here — the district's colour.
    public var standing: StandingBand
    /// The studio's products on the market here, drawn as small buildings.
    public var playerProducts: Int
    /// Rival studios selling here, drawn as flags.
    public var rivalCount: Int
    /// The incumbent is in this market: its fortress stands here.
    public var hasFortress: Bool
    /// A category fight is on: the siege marker.
    public var underSiege: Bool
    /// The forecast, where the studio has one.
    public var weather: MarketWeather?

    public init(
        id: String,
        name: String,
        size: Double,
        standing: StandingBand,
        playerProducts: Int = 0,
        rivalCount: Int = 0,
        hasFortress: Bool = false,
        underSiege: Bool = false,
        weather: MarketWeather? = nil
    ) {
        self.id = id
        self.name = name
        self.size = min(1, max(0, size))
        self.standing = standing
        self.playerProducts = max(0, playerProducts)
        self.rivalCount = max(0, rivalCount)
        self.hasFortress = hasFortress
        self.underSiege = underSiege
        self.weather = weather
    }
}

/// Everything the market map is a function of. `Hashable` so a view can
/// memoize the composed scene per input.
public struct MarketMapInput: Sendable, Equatable, Hashable {
    /// The districts in catalog order. The layout is fixed by index — the
    /// first twelve get a slot; a catalog with fewer leaves cells empty.
    public var districts: [MarketDistrictInfo]

    public init(districts: [MarketDistrictInfo]) {
        self.districts = districts
    }
}
