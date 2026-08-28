/// City districts as PixelKit sees them. Raw values deliberately mirror the
/// engine's `DistrictID` — the app maps between them with `init(rawValue:)`
/// and a defensive fallback; PixelKit never imports TycoonEngine.
///
/// Each district gets one ground tone, one wall pair and one roof pair, all
/// from the master palette. Five districts, five silhouettes, five colour
/// stories: sandstone Old Town, green Suburbs, grey Midtown, glass Tech
/// Park, slate Downtown.
public enum DistrictStyle: String, Sendable, CaseIterable {
    case oldTown, suburbs, midtown, techPark, downtown

    public var displayName: String {
        switch self {
        case .oldTown: "Old Town"
        case .suburbs: "Suburbs"
        case .midtown: "Midtown"
        case .techPark: "Tech Park"
        case .downtown: "Downtown"
        }
    }

    // MARK: Palette accents (internal)

    /// Ground tint the map builder fills the district block with.
    var ground: RGBA {
        switch self {
        case .oldTown: Palettes.sand[1]    // worn sandstone
        case .suburbs: Palettes.moss[1]    // lawn green
        case .midtown: Palettes.stone[2]   // pale concrete
        case .techPark: Palettes.stone[1]  // cool slate
        case .downtown: Palettes.stone[3]  // city asphalt-grey
        }
    }

    /// (base, shade) building wall tones.
    var wall: (base: RGBA, shade: RGBA) {
        switch self {
        case .oldTown: Palettes.sand.pair(1)
        case .suburbs: Palettes.sand.pair(0)
        case .midtown: Palettes.stone.pair(1)
        case .techPark: Palettes.sky.pair(1)
        case .downtown: Palettes.stone.pair(2)
        }
    }

    /// (base, shade) roof tones.
    var roof: (base: RGBA, shade: RGBA) {
        switch self {
        case .oldTown: Palettes.ember.pair(3)
        case .suburbs: Palettes.sand.pair(3)
        case .midtown: Palettes.ink.pair(0)
        case .techPark: Palettes.teal.pair(3)
        case .downtown: Palettes.ink.pair(1)
        }
    }
}
