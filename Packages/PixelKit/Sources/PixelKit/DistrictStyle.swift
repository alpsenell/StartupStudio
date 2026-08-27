/// City districts as PixelKit sees them. Raw values deliberately mirror the
/// engine's `DistrictID` — the app maps between them with `init(rawValue:)`
/// and a defensive fallback; PixelKit never imports TycoonEngine.
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
        case .oldTown: RGBA(r: 189, g: 172, b: 152)   // worn sandstone
        case .suburbs: RGBA(r: 148, g: 178, b: 128)   // lawn green
        case .midtown: RGBA(r: 172, g: 168, b: 176)   // pale concrete
        case .techPark: RGBA(r: 158, g: 178, b: 186)  // cool slate
        case .downtown: RGBA(r: 150, g: 148, b: 162)  // city asphalt-gray
        }
    }

    /// (base, shade) building wall tones.
    var wall: (base: RGBA, shade: RGBA) {
        switch self {
        case .oldTown: (RGBA(r: 214, g: 178, b: 138), RGBA(r: 186, g: 150, b: 112))
        case .suburbs: (RGBA(r: 234, g: 222, b: 198), RGBA(r: 206, g: 192, b: 166))
        case .midtown: (RGBA(r: 202, g: 198, b: 208), RGBA(r: 172, g: 168, b: 180))
        case .techPark: (RGBA(r: 186, g: 206, b: 214), RGBA(r: 152, g: 176, b: 186))
        case .downtown: (RGBA(r: 158, g: 160, b: 178), RGBA(r: 128, g: 130, b: 148))
        }
    }

    /// (base, shade) roof tones.
    var roof: (base: RGBA, shade: RGBA) {
        switch self {
        case .oldTown: (RGBA(r: 168, g: 88, b: 70), RGBA(r: 138, g: 70, b: 56))
        case .suburbs: (RGBA(r: 130, g: 96, b: 74), RGBA(r: 106, g: 76, b: 58))
        case .midtown: (RGBA(r: 110, g: 112, b: 132), RGBA(r: 88, g: 90, b: 108))
        case .techPark: (RGBA(r: 86, g: 130, b: 146), RGBA(r: 66, g: 104, b: 118))
        case .downtown: (RGBA(r: 84, g: 86, b: 108), RGBA(r: 64, g: 66, b: 86))
        }
    }
}
