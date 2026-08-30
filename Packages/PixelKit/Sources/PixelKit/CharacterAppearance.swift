/// Deterministic visual identity for a person, derived from a seed.
///
/// The derivation is a pure SplitMix64 stream — no system randomness — so the
/// same seed always produces the same appearance on every platform and run.
///
/// Version 2 adds glasses, a beard and a body outfit. They are drawn from
/// *further* steps of the same stream, after the four original fields, so
/// every seed that existed before keeps exactly the skin, hair and shirt it
/// always had (`CharacterAppearanceTests.oldSeedsKeepTheirOriginalLook`).
public struct CharacterAppearance: Sendable, Equatable, Hashable, Codable {
    public var skinTone: Int
    public var hairStyle: Int
    public var hairColor: Int
    public var shirtColor: Int
    /// `nil` for no glasses, otherwise an index into the glasses styles.
    public var glasses: Int?
    public var hasBeard: Bool
    /// 0 hoodie, 1 shirt, 2 blazer.
    public var outfit: Int

    /// Number of skin tones in the sprite palette set.
    public static var skinToneCount: Int { Palettes.skinTones.count }
    /// Number of authored hair styles.
    public static var hairStyleCount: Int { PersonArt.hairOverlays.count }
    /// Number of hair colors in the sprite palette set.
    public static var hairColorCount: Int { Palettes.hairColors.count }
    /// Number of shirt colors in the sprite palette set.
    public static var shirtColorCount: Int { Palettes.shirtColors.count }
    /// Number of authored glasses styles.
    public static var glassesStyleCount: Int { PersonArt.glassesOverlays.count }
    /// Number of authored body outfits.
    public static var outfitCount: Int { PersonArt.outfitOverlays.count }

    /// How often a seed produces glasses / a beard, out of 100.
    private static let glassesChance: UInt64 = 34
    private static let beardChance: UInt64 = 28

    public init(seed: UInt64) {
        var state = seed
        skinTone = Int(SplitMix64.next(&state) % UInt64(Self.skinToneCount))
        hairStyle = Int(SplitMix64.next(&state) % UInt64(Self.hairStyleCount))
        hairColor = Int(SplitMix64.next(&state) % UInt64(Self.hairColorCount))
        shirtColor = Int(SplitMix64.next(&state) % UInt64(Self.shirtColorCount))
        // v2 fields — appended to the stream, never inserted into it.
        let glassesRoll = SplitMix64.next(&state) % 100
        glasses = glassesRoll < Self.glassesChance
            ? Int(SplitMix64.next(&state) % UInt64(Self.glassesStyleCount))
            : nil
        hasBeard = SplitMix64.next(&state) % 100 < Self.beardChance
        outfit = Int(SplitMix64.next(&state) % UInt64(Self.outfitCount))
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case skinTone, hairStyle, hairColor, shirtColor, glasses, hasBeard, outfit
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        skinTone = try container.decode(Int.self, forKey: .skinTone)
        hairStyle = try container.decode(Int.self, forKey: .hairStyle)
        hairColor = try container.decode(Int.self, forKey: .hairColor)
        shirtColor = try container.decode(Int.self, forKey: .shirtColor)
        // Appearances persisted before v2 simply have no accessories.
        glasses = try container.decodeIfPresent(Int.self, forKey: .glasses)
        hasBeard = try container.decodeIfPresent(Bool.self, forKey: .hasBeard) ?? false
        outfit = try container.decodeIfPresent(Int.self, forKey: .outfit) ?? 0
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(skinTone, forKey: .skinTone)
        try container.encode(hairStyle, forKey: .hairStyle)
        try container.encode(hairColor, forKey: .hairColor)
        try container.encode(shirtColor, forKey: .shirtColor)
        try container.encodeIfPresent(glasses, forKey: .glasses)
        try container.encode(hasBeard, forKey: .hasBeard)
        try container.encode(outfit, forKey: .outfit)
    }
}

/// One SplitMix64 step: tiny, local, and fully deterministic.
enum SplitMix64 {
    static func next(_ state: inout UInt64) -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
