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
/// Version 3 adds beard styles, eye colour, headwear and freckles, and
/// version 4 the face (shape, eyes, brows, nose, mouth), earrings,
/// neckwear and the founder's choice to leave the hoodie off — all appended
/// to the stream the same way. The creator offers more skin tones, hair
/// colours, hair styles, glasses, outfits and headwear than a seed draws.
/// A look built in the creator travels as a `customSeed`: a tagged seed
/// that decodes straight back into the chosen fields, so every place that
/// stores a seed can store a hand-made face without a new save field.
public struct CharacterAppearance: Sendable, Equatable, Hashable, Codable {
    public var skinTone: Int
    public var hairStyle: Int
    public var hairColor: Int
    public var shirtColor: Int
    /// `nil` for no glasses, otherwise an index into the glasses styles.
    public var glasses: Int?
    public var hasBeard: Bool
    /// 0 hoodie, 1 shirt, 2 blazer, 3 turtleneck, 4 tee.
    public var outfit: Int
    public var beardStyle: Int
    public var eyeColor: Int
    public var headwear: Int?
    public var freckles: Bool
    public var faceShape: Int
    public var eyeShape: Int
    public var browStyle: Int
    public var noseStyle: Int
    public var mouthStyle: Int
    public var earrings: Int?
    public var neckwear: Int?
    public var wearsFounderHoodie: Bool

    // Seeds draw from the original ranges only; the art holds more for the
    // creator. Changing these changes every existing face.
    public static let skinToneCount = 5
    public static let hairStyleCount = 6
    public static let hairColorCount = 6
    public static let glassesStyleCount = 2
    public static let outfitCount = 3
    private static let seededHeadwearCount = 3

    public static var shirtColorCount: Int { Palettes.shirtColors.count }
    public static var selectableSkinToneCount: Int { Palettes.skinTones.count }
    public static var selectableHairStyleCount: Int { PersonArt.hairOverlays.count }
    public static var selectableHairColorCount: Int { Palettes.hairColors.count }
    public static var selectableGlassesStyleCount: Int { PersonArt.glassesOverlays.count }
    public static var selectableOutfitCount: Int { PersonArt.outfitOverlays.count }
    public static var headwearStyleCount: Int { PersonArt.headwearOverlays.count }
    public static var eyeColorCount: Int { Palettes.eyeColors.count }
    public static var beardStyleCount: Int { PersonArt.beardOverlays.count }
    public static let faceShapeCount = 4
    public static let eyeShapeCount = 4
    public static let browStyleCount = 4
    public static let noseStyleCount = 4
    public static let mouthStyleCount = 4
    public static let earringStyleCount = 2
    public static let neckwearStyleCount = 3

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

    public static func shirtSwatch(_ index: Int) -> PixelSprite.RGBA {
        Palettes.shirtColors[index % Palettes.shirtColors.count].base
    }

    /// How often a seed produces glasses / a beard, out of 100.
    private static let glassesChance: UInt64 = 34
    private static let beardChance: UInt64 = 28
    private static let headwearChance: UInt64 = 11
    private static let frecklesChance: UInt64 = 14
    private static let earringChance: UInt64 = 16
    private static let neckwearChance: UInt64 = 10

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
            ? Int(SplitMix64.next(&state) % UInt64(Self.seededHeadwearCount))
            : nil
        freckles = SplitMix64.next(&state) % 100 < Self.frecklesChance
        // v4 fields — appended after v3.
        faceShape = Int(SplitMix64.next(&state) % UInt64(Self.faceShapeCount))
        eyeShape = Int(SplitMix64.next(&state) % UInt64(Self.eyeShapeCount))
        browStyle = Int(SplitMix64.next(&state) % UInt64(Self.browStyleCount))
        noseStyle = Int(SplitMix64.next(&state) % UInt64(Self.noseStyleCount))
        mouthStyle = [0, 0, 0, 1, 1, 1, 2, 3][Int(SplitMix64.next(&state) % 8)]
        earrings = SplitMix64.next(&state) % 100 < Self.earringChance
            ? Int(SplitMix64.next(&state) % UInt64(Self.earringStyleCount))
            : nil
        neckwear = SplitMix64.next(&state) % 100 < Self.neckwearChance
            ? Int(SplitMix64.next(&state) % UInt64(Self.neckwearStyleCount))
            : nil
        wearsFounderHoodie = true
    }

    // MARK: Custom seeds

    // A custom seed is a 22-bit tag over a mixed-radix number, one digit per
    // field. The radices are the format: growing an option list past its
    // radix needs a new tag, or older custom seeds decode differently.
    private static let customTag: UInt64 = 0x3C_0FFE
    private static let customTagShift: UInt64 = 42
    private static let radices: [UInt64] = [8, 11, 10, 8, 5, 5, 5, 5, 6, 2, 4, 4, 4, 4, 4, 3, 4, 2]

    private var customDigits: [Int] {
        [
            skinTone, hairStyle, hairColor, shirtColor,
            glasses.map { $0 + 1 } ?? 0,
            hasBeard ? beardStyle + 1 : 0,
            outfit, eyeColor,
            headwear.map { $0 + 1 } ?? 0,
            freckles ? 1 : 0,
            faceShape, eyeShape, browStyle, noseStyle, mouthStyle,
            earrings.map { $0 + 1 } ?? 0,
            neckwear.map { $0 + 1 } ?? 0,
            wearsFounderHoodie ? 0 : 1,
        ]
    }

    public var customSeed: UInt64 {
        var packed: UInt64 = 0
        for (digit, radix) in zip(customDigits, Self.radices).reversed() {
            packed = packed * radix + UInt64(min(max(digit, 0), Int(radix) - 1))
        }
        return Self.customTag << Self.customTagShift | packed
    }

    public static func isCustomSeed(_ seed: UInt64) -> Bool {
        seed >> customTagShift == customTag
    }

    private init?(customSeed seed: UInt64) {
        guard Self.isCustomSeed(seed) else { return nil }
        var rest = seed & ((1 << Self.customTagShift) - 1)
        var digits: [Int] = []
        for radix in Self.radices {
            digits.append(Int(rest % radix))
            rest /= radix
        }
        func clamp(_ value: Int, _ count: Int) -> Int { min(value, count - 1) }
        func optional(_ value: Int, _ count: Int) -> Int? { value == 0 ? nil : clamp(value - 1, count) }
        skinTone = clamp(digits[0], Self.selectableSkinToneCount)
        hairStyle = clamp(digits[1], Self.selectableHairStyleCount)
        hairColor = clamp(digits[2], Self.selectableHairColorCount)
        shirtColor = clamp(digits[3], Self.shirtColorCount)
        glasses = optional(digits[4], Self.selectableGlassesStyleCount)
        hasBeard = digits[5] != 0
        beardStyle = hasBeard ? clamp(digits[5] - 1, Self.beardStyleCount) : 0
        outfit = clamp(digits[6], Self.selectableOutfitCount)
        eyeColor = clamp(digits[7], Self.eyeColorCount)
        headwear = optional(digits[8], Self.headwearStyleCount)
        freckles = digits[9] != 0
        faceShape = digits[10]
        eyeShape = digits[11]
        browStyle = digits[12]
        noseStyle = digits[13]
        mouthStyle = digits[14]
        earrings = optional(digits[15], Self.earringStyleCount)
        neckwear = optional(digits[16], Self.neckwearStyleCount)
        wearsFounderHoodie = digits[17] == 0
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case skinTone, hairStyle, hairColor, shirtColor, glasses, hasBeard, outfit
        case beardStyle, eyeColor, headwear, freckles
        case faceShape, eyeShape, browStyle, noseStyle, mouthStyle, earrings, neckwear, wearsFounderHoodie
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
        faceShape = try container.decodeIfPresent(Int.self, forKey: .faceShape) ?? 0
        eyeShape = try container.decodeIfPresent(Int.self, forKey: .eyeShape) ?? 0
        browStyle = try container.decodeIfPresent(Int.self, forKey: .browStyle) ?? 0
        noseStyle = try container.decodeIfPresent(Int.self, forKey: .noseStyle) ?? 0
        mouthStyle = try container.decodeIfPresent(Int.self, forKey: .mouthStyle) ?? 0
        earrings = try container.decodeIfPresent(Int.self, forKey: .earrings)
        neckwear = try container.decodeIfPresent(Int.self, forKey: .neckwear)
        wearsFounderHoodie = try container.decodeIfPresent(Bool.self, forKey: .wearsFounderHoodie) ?? true
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
        try container.encode(faceShape, forKey: .faceShape)
        try container.encode(eyeShape, forKey: .eyeShape)
        try container.encode(browStyle, forKey: .browStyle)
        try container.encode(noseStyle, forKey: .noseStyle)
        try container.encode(mouthStyle, forKey: .mouthStyle)
        try container.encodeIfPresent(earrings, forKey: .earrings)
        try container.encodeIfPresent(neckwear, forKey: .neckwear)
        try container.encode(wearsFounderHoodie, forKey: .wearsFounderHoodie)
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
