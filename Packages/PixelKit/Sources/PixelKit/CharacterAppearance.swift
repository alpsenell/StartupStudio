/// Deterministic visual identity for a person, derived from a seed.
///
/// The derivation is a pure SplitMix64 stream — no system randomness — so the
/// same seed always produces the same appearance on every platform and run.
///
/// Version 2 adds glasses, a beard and a body outfit. They are drawn from
/// *further* steps of the same stream, after the four original fields, so
/// every seed that existed before keeps exactly the skin, hair and shirt it
/// always had (`CharacterAppearanceTests.oldSeedsKeepTheirOriginalLook`).
///
/// Version 3 adds beard styles, eye colour, headwear and freckles the same
/// way, and a creator-only range of extra skin tones, hair colours and hair
/// styles that a random seed never draws. A look built in the character
/// creator travels as a `customSeed`: a tagged seed that decodes straight
/// back into the chosen fields, so every place that stores a seed can store
/// a hand-made face without a new save field.
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
    public var beardStyle: Int
    public var eyeColor: Int
    public var headwear: Int?
    public var freckles: Bool

    // Seeds draw from the original ranges only; the palettes hold more for
    // the creator. Changing these changes every existing face.
    public static let skinToneCount = 5
    public static let hairStyleCount = 6
    public static let hairColorCount = 6
    public static var selectableSkinToneCount: Int { Palettes.skinTones.count }
    public static var selectableHairStyleCount: Int { PersonArt.hairOverlays.count }
    public static var selectableHairColorCount: Int { Palettes.hairColors.count }
    public static var eyeColorCount: Int { Palettes.eyeColors.count }
    public static var beardStyleCount: Int { PersonArt.beardOverlays.count }
    public static var headwearStyleCount: Int { PersonArt.headwearOverlays.count }
    /// Number of shirt colors in the sprite palette set.
    public static var shirtColorCount: Int { Palettes.shirtColors.count }
    /// Number of authored glasses styles.
    public static var glassesStyleCount: Int { PersonArt.glassesOverlays.count }
    /// Number of authored body outfits.
    public static var outfitCount: Int { PersonArt.outfitOverlays.count }

    public static let skinToneDisplayOrder = [5, 0, 1, 6, 2, 3, 4, 7]

    public static func skinSwatch(_ index: Int) -> PixelSprite.RGBA {
        Palettes.skinTones[index % Palettes.skinTones.count].base
    }

    public static func hairSwatch(_ index: Int) -> PixelSprite.RGBA {
        Palettes.hairColors[index % Palettes.hairColors.count].base
    }

    public static func eyeSwatch(_ index: Int) -> PixelSprite.RGBA {
        Palettes.eyeColors[index % Palettes.eyeColors.count]
    }

    /// How often a seed produces glasses / a beard, out of 100.
    private static let glassesChance: UInt64 = 34
    private static let beardChance: UInt64 = 28
    private static let headwearChance: UInt64 = 11
    private static let frecklesChance: UInt64 = 14

    public init(seed: UInt64) {
        if let custom = Self(customSeed: seed) {
            self = custom
            return
        }
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
        // v3 fields — appended after v2, for the same reason.
        beardStyle = [0, 0, 0, 0, 1, 1, 2, 2, 3, 3][Int(SplitMix64.next(&state) % 10)]
        let eyeRoll = Int(SplitMix64.next(&state) % 10)
        eyeColor = eyeRoll < 5 ? 0 : 1 + (eyeRoll - 5) % (Self.eyeColorCount - 1)
        headwear = SplitMix64.next(&state) % 100 < Self.headwearChance
            ? Int(SplitMix64.next(&state) % UInt64(Self.headwearStyleCount))
            : nil
        freckles = SplitMix64.next(&state) % 100 < Self.frecklesChance
    }

    // MARK: Custom seeds

    private static let customTag: UInt64 = 0xC0FFE
    private static let customTagShift: UInt64 = 44

    public var customSeed: UInt64 {
        let fields: [Int] = [
            skinTone, hairStyle, hairColor, shirtColor,
            glasses.map { $0 + 1 } ?? 0,
            hasBeard ? beardStyle + 1 : 0,
            outfit, eyeColor,
            headwear.map { $0 + 1 } ?? 0,
            freckles ? 1 : 0,
        ]
        var packed = Self.customTag << Self.customTagShift
        for (index, value) in fields.enumerated() {
            packed |= UInt64(value & 0xF) << UInt64(index * 4)
        }
        return packed
    }

    public static func isCustomSeed(_ seed: UInt64) -> Bool {
        seed >> customTagShift == customTag
    }

    private init?(customSeed seed: UInt64) {
        guard Self.isCustomSeed(seed) else { return nil }
        func field(_ index: Int) -> Int { Int((seed >> UInt64(index * 4)) & 0xF) }
        func clamp(_ value: Int, _ count: Int) -> Int { min(value, count - 1) }
        skinTone = clamp(field(0), Self.selectableSkinToneCount)
        hairStyle = clamp(field(1), Self.selectableHairStyleCount)
        hairColor = clamp(field(2), Self.selectableHairColorCount)
        shirtColor = clamp(field(3), Self.shirtColorCount)
        glasses = field(4) == 0 ? nil : clamp(field(4) - 1, Self.glassesStyleCount)
        hasBeard = field(5) != 0
        beardStyle = hasBeard ? clamp(field(5) - 1, Self.beardStyleCount) : 0
        outfit = clamp(field(6), Self.outfitCount)
        eyeColor = clamp(field(7), Self.eyeColorCount)
        headwear = field(8) == 0 ? nil : clamp(field(8) - 1, Self.headwearStyleCount)
        freckles = field(9) != 0
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case skinTone, hairStyle, hairColor, shirtColor, glasses, hasBeard, outfit
        case beardStyle, eyeColor, headwear, freckles
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
        beardStyle = try container.decodeIfPresent(Int.self, forKey: .beardStyle) ?? 0
        eyeColor = try container.decodeIfPresent(Int.self, forKey: .eyeColor) ?? 0
        headwear = try container.decodeIfPresent(Int.self, forKey: .headwear)
        freckles = try container.decodeIfPresent(Bool.self, forKey: .freckles) ?? false
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
        try container.encode(beardStyle, forKey: .beardStyle)
        try container.encode(eyeColor, forKey: .eyeColor)
        try container.encodeIfPresent(headwear, forKey: .headwear)
        try container.encode(freckles, forKey: .freckles)
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
