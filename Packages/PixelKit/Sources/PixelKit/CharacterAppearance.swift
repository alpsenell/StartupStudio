/// Deterministic visual identity for a person, derived from a seed.
///
/// The derivation is a pure SplitMix64 stream — no system randomness — so the
/// same seed always produces the same appearance on every platform and run.
public struct CharacterAppearance: Sendable, Equatable, Codable {
    public var skinTone: Int
    public var hairStyle: Int
    public var hairColor: Int
    public var shirtColor: Int

    /// Number of skin tones in the sprite palette set.
    public static var skinToneCount: Int { Palettes.skinTones.count }
    /// Number of authored hair styles.
    public static var hairStyleCount: Int { PersonArt.hairOverlays.count }
    /// Number of hair colors in the sprite palette set.
    public static var hairColorCount: Int { Palettes.hairColors.count }
    /// Number of shirt colors in the sprite palette set.
    public static var shirtColorCount: Int { Palettes.shirtColors.count }

    public init(seed: UInt64) {
        var state = seed
        skinTone = Int(SplitMix64.next(&state) % UInt64(Self.skinToneCount))
        hairStyle = Int(SplitMix64.next(&state) % UInt64(Self.hairStyleCount))
        hairColor = Int(SplitMix64.next(&state) % UInt64(Self.hairColorCount))
        shirtColor = Int(SplitMix64.next(&state) % UInt64(Self.shirtColorCount))
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
