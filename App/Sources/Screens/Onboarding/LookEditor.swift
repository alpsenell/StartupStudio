import PixelKit
import SwiftUI

struct LookEditor: View {
    @Binding var appearance: CharacterAppearance
    @State private var tab = LookTab.face

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Picker(String(localized: "Section", comment: "Character creator section picker"), selection: $tab.animation(Theme.Motion.selection)) {
                ForEach(LookTab.allCases, id: \.self) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            switch tab {
            case .face: faceTab
            case .hair: hairTab
            case .outfit: outfitTab
            case .extras: extrasTab
            }
        }
    }

    private var faceTab: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            LookSwatchRow(
                title: String(localized: "Skin", comment: "Character creator row: skin tone"),
                options: CharacterAppearance.skinToneDisplayOrder.enumerated().map { position, index in
                    LookSwatch(
                        value: index,
                        color: Color(pixel: CharacterAppearance.skinSwatch(index)),
                        name: String(localized: "Skin tone \(position + 1)", comment: "Accessibility name of a skin tone swatch in the character creator")
                    )
                },
                selection: $appearance.skinTone
            )
            strip(String(localized: "Face shape", comment: "Character creator row: face shape"), LookNames.faceShapes, \.faceShape)
            strip(String(localized: "Eyes", comment: "Character creator row: eye shape"), LookNames.eyeShapes, \.eyeShape, crop: .face)
            LookSwatchRow(
                title: String(localized: "Eye colour", comment: "Character creator row: eye colour"),
                options: LookNames.eyeColors.enumerated().map { index, name in
                    LookSwatch(value: index, color: Color(pixel: CharacterAppearance.eyeSwatch(index)), name: name)
                },
                selection: $appearance.eyeColor
            )
            strip(String(localized: "Brows", comment: "Character creator row: eyebrow style"), LookNames.brows, \.browStyle, crop: .face)
            strip(String(localized: "Nose", comment: "Character creator row: nose style"), LookNames.noses, \.noseStyle, crop: .face)
            strip(String(localized: "Mouth", comment: "Character creator row: mouth and expression"), LookNames.mouths, \.mouthStyle, crop: .face)
            Toggle(isOn: $appearance.freckles.animation(Theme.Motion.selection)) {
                Text("Freckles")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(Theme.accent)
        }
    }

    private var hairTab: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            strip(String(localized: "Hair", comment: "Character creator row: hair style"), LookNames.hairStyles, \.hairStyle)
            LookSwatchRow(
                title: String(localized: "Hair colour", comment: "Character creator row: hair colour"),
                options: LookNames.hairColors.enumerated().map { index, name in
                    LookSwatch(value: index, color: Color(pixel: CharacterAppearance.hairSwatch(index)), name: name)
                },
                selection: $appearance.hairColor
            )
            strip(String(localized: "Facial hair", comment: "Character creator row: beard style"), LookNames.facialHair, \.facialHairChoice, crop: .face)
        }
    }

    private var outfitTab: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            strip(String(localized: "Outfit", comment: "Character creator row: what the founder wears"), LookNames.outfits, \.outfitChoice)
            if appearance.wearsFounderHoodie {
                Text("The indigo hoodie is how your team spots you across the office.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                LookSwatchRow(
                    title: String(localized: "Colour", comment: "Character creator row: outfit colour"),
                    options: LookNames.outfitColors.enumerated().map { index, name in
                        LookSwatch(value: index, color: Color(pixel: CharacterAppearance.shirtSwatch(index)), name: name)
                    },
                    selection: $appearance.shirtColor
                )
            }
            strip(String(localized: "Neckwear", comment: "Character creator row: scarf, necklace or bow tie"), LookNames.neckwear, \.neckwearChoice)
        }
    }

    private var extrasTab: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            strip(String(localized: "Glasses", comment: "Character creator row: glasses style"), LookNames.glasses, \.glassesChoice, crop: .face)
            strip(String(localized: "Headwear", comment: "Character creator row: hat style"), LookNames.headwear, \.headwearChoice)
            strip(String(localized: "Earrings", comment: "Character creator row: earring style"), LookNames.earrings, \.earringsChoice, crop: .face)
        }
    }

    private func strip(
        _ title: String,
        _ names: [String],
        _ keyPath: WritableKeyPath<CharacterAppearance, Int>,
        crop: LookThumbnail.Crop = .bust
    ) -> some View {
        LookOptionStrip(title: title, names: names, crop: crop, appearance: $appearance, keyPath: keyPath)
    }
}

private enum LookTab: CaseIterable {
    case face, hair, outfit, extras

    var title: String {
        switch self {
        case .face: String(localized: "Face", comment: "Character creator section: face, eyes, nose, mouth")
        case .hair: String(localized: "Hair", comment: "Character creator section: hair and beard")
        case .outfit: String(localized: "Outfit", comment: "Character creator section: clothes")
        case .extras: String(localized: "Extras", comment: "Character creator section: glasses, hats, earrings")
        }
    }
}

struct LookThumbnail: View {
    enum Crop { case bust, face }

    let appearance: CharacterAppearance
    var crop: Crop = .bust
    var size: CGFloat = 56

    private var image: CGImage {
        let full = SpriteLibrary.hiResPortrait(appearance: appearance, isFounder: true, role: .founder).cgImage(frame: 0)
        guard crop == .face else { return full }
        return full.cropping(to: CGRect(x: 7, y: 7, width: 18, height: 18)) ?? full
    }

    var body: some View {
        Image(decorative: image, scale: 1)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

private struct LookOptionStrip: View {
    let title: String
    let names: [String]
    let crop: LookThumbnail.Crop
    @Binding var appearance: CharacterAppearance
    let keyPath: WritableKeyPath<CharacterAppearance, Int>

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(names.indices.contains(appearance[keyPath: keyPath]) ? names[appearance[keyPath: keyPath]] : "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(names.indices, id: \.self) { index in
                            option(index)
                                .id(index)
                        }
                    }
                    .padding(3)
                }
                .onAppear { proxy.scrollTo(appearance[keyPath: keyPath], anchor: .center) }
            }
        }
    }

    private func option(_ index: Int) -> some View {
        let isSelected = appearance[keyPath: keyPath] == index
        var variant = appearance
        variant[keyPath: keyPath] = index
        return Button {
            Haptics.tap()
            withAnimation(Theme.Motion.selection) { appearance[keyPath: keyPath] = index }
        } label: {
            LookThumbnail(appearance: variant, crop: crop)
                .padding(4)
                .background(Theme.chipBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(isSelected ? Theme.accent : Color.clear, lineWidth: 2.5)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(names[index])
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

struct FounderFigure: View {
    let appearance: CharacterAppearance
    var height: CGFloat = 120
    @State private var poseIndex = 0

    private static let poses: [SpriteLibrary.PersonPose] = [.standing, .walkDown, .coffee, .chat, .walkRight]
    private static let tick: TimeInterval = 0.4

    private var sprite: PixelSprite {
        SpriteLibrary.person(
            appearance: appearance,
            pose: Self.poses[poseIndex % Self.poses.count],
            isFounder: true,
            role: .founder
        )
    }

    var body: some View {
        Button {
            Haptics.tap()
            poseIndex += 1
        } label: {
            TimelineView(.periodic(from: .init(timeIntervalSinceReferenceDate: 0), by: Self.tick)) { timeline in
                let sprite = sprite
                let frame = Int(timeline.date.timeIntervalSinceReferenceDate / Self.tick) % sprite.frameCount
                Image(decorative: sprite.cgImage(frame: frame), scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
            }
            .frame(height: height)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Change pose")
    }
}

enum LookNames {
    static let hairStyles = [
        String(localized: "Short", comment: "Hair style in the character creator"),
        String(localized: "Spiky", comment: "Hair style in the character creator"),
        String(localized: "Curly", comment: "Hair style in the character creator"),
        String(localized: "Bun", comment: "Hair style in the character creator"),
        String(localized: "Long", comment: "Hair style in the character creator"),
        String(localized: "Bald", comment: "Hair style in the character creator"),
        String(localized: "Side part", comment: "Hair style in the character creator"),
        String(localized: "Mohawk", comment: "Hair style in the character creator"),
        String(localized: "Ponytail", comment: "Hair style in the character creator"),
        String(localized: "Afro", comment: "Hair style in the character creator"),
        String(localized: "Buzz cut", comment: "Hair style in the character creator"),
    ]

    static let hairColors = [
        String(localized: "Black", comment: "Hair colour in the character creator"),
        String(localized: "Dark brown", comment: "Hair colour in the character creator"),
        String(localized: "Chestnut", comment: "Hair colour in the character creator"),
        String(localized: "Blonde", comment: "Hair colour in the character creator"),
        String(localized: "Auburn", comment: "Hair colour in the character creator"),
        String(localized: "Indigo grey", comment: "Hair colour in the character creator"),
        String(localized: "Silver", comment: "Hair colour in the character creator"),
        String(localized: "Ginger", comment: "Hair colour in the character creator"),
        String(localized: "Pink", comment: "Hair colour in the character creator"),
        String(localized: "Teal", comment: "Hair colour in the character creator"),
    ]

    static let eyeColors = [
        String(localized: "Dark eyes", comment: "Eye colour in the character creator"),
        String(localized: "Brown eyes", comment: "Eye colour in the character creator"),
        String(localized: "Blue eyes", comment: "Eye colour in the character creator"),
        String(localized: "Green eyes", comment: "Eye colour in the character creator"),
        String(localized: "Grey eyes", comment: "Eye colour in the character creator"),
    ]

    static let facialHair = [
        String(localized: "None", comment: "Character creator option: no beard, no glasses or no hat"),
        String(localized: "Full beard", comment: "Beard style in the character creator"),
        String(localized: "Moustache", comment: "Beard style in the character creator"),
        String(localized: "Goatee", comment: "Beard style in the character creator"),
        String(localized: "Stubble", comment: "Beard style in the character creator"),
    ]

    static let glasses = [
        String(localized: "None", comment: "Character creator option: no beard, no glasses or no hat"),
        String(localized: "Wire rims", comment: "Glasses style in the character creator"),
        String(localized: "Bold frames", comment: "Glasses style in the character creator"),
        String(localized: "Round", comment: "Glasses style in the character creator"),
        String(localized: "Sunglasses", comment: "Glasses style in the character creator"),
    ]

    static let headwear = [
        String(localized: "None", comment: "Character creator option: no beard, no glasses or no hat"),
        String(localized: "Beanie", comment: "Hat style in the character creator"),
        String(localized: "Cap", comment: "Hat style in the character creator"),
        String(localized: "Headband", comment: "Hat style in the character creator"),
        String(localized: "Headphones", comment: "Hat style in the character creator"),
        String(localized: "Bucket hat", comment: "Hat style in the character creator"),
    ]

    static let earrings = [
        String(localized: "None", comment: "Character creator option: no beard, no glasses or no hat"),
        String(localized: "Studs", comment: "Earring style in the character creator"),
        String(localized: "Hoops", comment: "Earring style in the character creator"),
    ]

    static let neckwear = [
        String(localized: "None", comment: "Character creator option: no beard, no glasses or no hat"),
        String(localized: "Scarf", comment: "Neckwear in the character creator"),
        String(localized: "Necklace", comment: "Neckwear in the character creator"),
        String(localized: "Bow tie", comment: "Neckwear in the character creator"),
    ]

    static let outfits = [
        String(localized: "Founder hoodie", comment: "Outfit in the character creator: the indigo hoodie the founder wears by default"),
        String(localized: "Hoodie", comment: "Outfit in the character creator"),
        String(localized: "Shirt", comment: "Outfit in the character creator"),
        String(localized: "Blazer", comment: "Outfit in the character creator"),
        String(localized: "Turtleneck", comment: "Outfit in the character creator"),
        String(localized: "T-shirt", comment: "Outfit in the character creator"),
    ]

    static let outfitColors = [
        String(localized: "Indigo", comment: "Outfit colour in the character creator"),
        String(localized: "Coral", comment: "Outfit colour in the character creator"),
        String(localized: "Mustard", comment: "Outfit colour in the character creator"),
        String(localized: "Teal", comment: "Outfit colour in the character creator"),
        String(localized: "Brick red", comment: "Outfit colour in the character creator"),
        String(localized: "Dusty pink", comment: "Outfit colour in the character creator"),
        String(localized: "Olive", comment: "Outfit colour in the character creator"),
        String(localized: "Slate blue", comment: "Outfit colour in the character creator"),
    ]

    static let faceShapes = [
        String(localized: "Oval", comment: "Face shape in the character creator"),
        String(localized: "Round", comment: "Face shape in the character creator"),
        String(localized: "Square", comment: "Face shape in the character creator"),
        String(localized: "Heart", comment: "Face shape in the character creator"),
    ]

    static let eyeShapes = [
        String(localized: "Round", comment: "Eye shape in the character creator"),
        String(localized: "Almond", comment: "Eye shape in the character creator"),
        String(localized: "Sleepy", comment: "Eye shape in the character creator"),
        String(localized: "Wide", comment: "Eye shape in the character creator"),
    ]

    static let brows = [
        String(localized: "Soft", comment: "Eyebrow style in the character creator"),
        String(localized: "Bold", comment: "Eyebrow style in the character creator"),
        String(localized: "Arched", comment: "Eyebrow style in the character creator"),
        String(localized: "Straight", comment: "Eyebrow style in the character creator"),
    ]

    static let noses = [
        String(localized: "Button", comment: "Nose style in the character creator"),
        String(localized: "Straight", comment: "Nose style in the character creator"),
        String(localized: "Broad", comment: "Nose style in the character creator"),
        String(localized: "Pointed", comment: "Nose style in the character creator"),
    ]

    static let mouths = [
        String(localized: "Smile", comment: "Mouth and expression in the character creator"),
        String(localized: "Neutral", comment: "Mouth and expression in the character creator"),
        String(localized: "Grin", comment: "Mouth and expression in the character creator"),
        String(localized: "Smirk", comment: "Mouth and expression in the character creator"),
    ]

    static func summary(of look: CharacterAppearance) -> String {
        var parts = [
            "\(name(hairStyles, look.hairStyle)) \(name(hairColors, look.hairColor).lowercased()) hair",
            name(eyeColors, look.eyeColor).lowercased(),
        ]
        if look.facialHairChoice > 0 { parts.append(name(facialHair, look.facialHairChoice).lowercased()) }
        if look.glassesChoice > 0 { parts.append(name(glasses, look.glassesChoice).lowercased()) }
        if look.headwearChoice > 0 { parts.append(name(headwear, look.headwearChoice).lowercased()) }
        if look.earringsChoice > 0 { parts.append(name(earrings, look.earringsChoice).lowercased()) }
        if look.neckwearChoice > 0 { parts.append(name(neckwear, look.neckwearChoice).lowercased()) }
        parts.append(name(outfits, look.outfitChoice).lowercased())
        if look.freckles { parts.append(String(localized: "freckles", comment: "Part of the spoken description of a founder's look")) }
        return parts.joined(separator: ", ")
    }

    private static func name(_ names: [String], _ index: Int) -> String {
        names.indices.contains(index) ? names[index] : ""
    }
}

extension CharacterAppearance {
    static func randomLook() -> CharacterAppearance {
        var look = CharacterAppearance(seed: .random(in: 0..<(1 << 40)))
        look.skinTone = .random(in: 0..<selectableSkinToneCount)
        look.hairStyle = .random(in: 0..<selectableHairStyleCount)
        look.hairColor = .random(in: 0..<selectableHairColorCount)
        look.eyeColor = .random(in: 0..<eyeColorCount)
        look.glassesChoice = Int.random(in: 0..<100) < 35 ? .random(in: 1...selectableGlassesStyleCount) : 0
        look.facialHairChoice = Int.random(in: 0..<100) < 35 ? .random(in: 1...beardStyleCount) : 0
        look.headwearChoice = Int.random(in: 0..<100) < 25 ? .random(in: 1...headwearStyleCount) : 0
        look.earringsChoice = Int.random(in: 0..<100) < 25 ? .random(in: 1...earringStyleCount) : 0
        look.neckwearChoice = Int.random(in: 0..<100) < 20 ? .random(in: 1...neckwearStyleCount) : 0
        look.freckles = Int.random(in: 0..<100) < 20
        look.faceShape = .random(in: 0..<faceShapeCount)
        look.eyeShape = .random(in: 0..<eyeShapeCount)
        look.browStyle = .random(in: 0..<browStyleCount)
        look.noseStyle = .random(in: 0..<noseStyleCount)
        look.mouthStyle = .random(in: 0..<mouthStyleCount)
        look.outfitChoice = Int.random(in: 0..<100) < 50 ? 0 : .random(in: 1...selectableOutfitCount)
        look.shirtColor = .random(in: 0..<shirtColorCount)
        return look
    }

    var facialHairChoice: Int {
        get { hasBeard ? beardStyle + 1 : 0 }
        set {
            hasBeard = newValue > 0
            beardStyle = max(newValue - 1, 0)
        }
    }

    var glassesChoice: Int {
        get { glasses.map { $0 + 1 } ?? 0 }
        set { glasses = newValue > 0 ? newValue - 1 : nil }
    }

    var headwearChoice: Int {
        get { headwear.map { $0 + 1 } ?? 0 }
        set { headwear = newValue > 0 ? newValue - 1 : nil }
    }

    var earringsChoice: Int {
        get { earrings.map { $0 + 1 } ?? 0 }
        set { earrings = newValue > 0 ? newValue - 1 : nil }
    }

    var neckwearChoice: Int {
        get { neckwear.map { $0 + 1 } ?? 0 }
        set { neckwear = newValue > 0 ? newValue - 1 : nil }
    }

    var outfitChoice: Int {
        get { wearsFounderHoodie ? 0 : outfit + 1 }
        set {
            wearsFounderHoodie = newValue == 0
            if newValue > 0 { outfit = newValue - 1 }
        }
    }
}

extension Color {
    init(pixel: PixelSprite.RGBA) {
        self.init(
            .sRGB,
            red: Double(pixel.r) / 255,
            green: Double(pixel.g) / 255,
            blue: Double(pixel.b) / 255,
            opacity: Double(pixel.a) / 255
        )
    }
}

private struct LookSwatch: Identifiable {
    let value: Int
    let color: Color
    let name: String
    var id: Int { value }
}

private struct LookSwatchRow: View {
    let title: String
    let options: [LookSwatch]
    @Binding var selection: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(options) { option in
                        swatch(option)
                    }
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 3)
            }
        }
    }

    private func swatch(_ option: LookSwatch) -> some View {
        let isSelected = option.value == selection
        return Button {
            Haptics.tap()
            withAnimation(Theme.Motion.selection) { selection = option.value }
        } label: {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(option.color)
                .frame(width: 28, height: 28)
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                }
                .padding(2)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(isSelected ? Theme.accent : Color.clear, lineWidth: 2.5)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.name)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}
