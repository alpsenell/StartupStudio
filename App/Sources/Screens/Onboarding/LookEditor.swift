import PixelKit
import SwiftUI

struct LookEditor: View {
    @Binding var appearance: CharacterAppearance

    var body: some View {
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
            LookStepperRow(
                title: String(localized: "Hair", comment: "Character creator row: hair style"),
                options: LookNames.hairStyles,
                selection: $appearance.hairStyle
            )
            LookSwatchRow(
                title: String(localized: "Hair colour", comment: "Character creator row: hair colour"),
                options: LookNames.hairColors.enumerated().map { index, name in
                    LookSwatch(value: index, color: Color(pixel: CharacterAppearance.hairSwatch(index)), name: name)
                },
                selection: $appearance.hairColor
            )
            LookSwatchRow(
                title: String(localized: "Eyes", comment: "Character creator row: eye colour"),
                options: LookNames.eyeColors.enumerated().map { index, name in
                    LookSwatch(value: index, color: Color(pixel: CharacterAppearance.eyeSwatch(index)), name: name)
                },
                selection: $appearance.eyeColor
            )
            LookStepperRow(
                title: String(localized: "Facial hair", comment: "Character creator row: beard style"),
                options: LookNames.facialHair,
                selection: $appearance.facialHairChoice
            )
            LookStepperRow(
                title: String(localized: "Glasses", comment: "Character creator row: glasses style"),
                options: LookNames.glasses,
                selection: $appearance.glassesChoice
            )
            LookStepperRow(
                title: String(localized: "Headwear", comment: "Character creator row: hat style"),
                options: LookNames.headwear,
                selection: $appearance.headwearChoice
            )
            Toggle(isOn: $appearance.freckles.animation(Theme.Motion.selection)) {
                Text("Freckles")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(Theme.accent)
        }
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
    ]

    static let headwear = [
        String(localized: "None", comment: "Character creator option: no beard, no glasses or no hat"),
        String(localized: "Beanie", comment: "Hat style in the character creator"),
        String(localized: "Cap", comment: "Hat style in the character creator"),
        String(localized: "Headband", comment: "Hat style in the character creator"),
    ]

    static func summary(of look: CharacterAppearance) -> String {
        var parts = [
            "\(name(hairStyles, look.hairStyle)) \(name(hairColors, look.hairColor).lowercased()) hair",
            name(eyeColors, look.eyeColor).lowercased(),
        ]
        if look.facialHairChoice > 0 { parts.append(name(facialHair, look.facialHairChoice).lowercased()) }
        if look.glassesChoice > 0 { parts.append(name(glasses, look.glassesChoice).lowercased()) }
        if look.headwearChoice > 0 { parts.append(name(headwear, look.headwearChoice).lowercased()) }
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
        look.glassesChoice = Int.random(in: 0..<100) < 35 ? .random(in: 1...glassesStyleCount) : 0
        look.facialHairChoice = Int.random(in: 0..<100) < 35 ? .random(in: 1...beardStyleCount) : 0
        look.headwearChoice = Int.random(in: 0..<100) < 25 ? .random(in: 1...headwearStyleCount) : 0
        look.freckles = Int.random(in: 0..<100) < 20
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

private struct LookStepperRow: View {
    let title: String
    let options: [String]
    @Binding var selection: Int

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Button { step(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.bordered)
            .accessibilityHidden(true)
            Text(options.indices.contains(selection) ? options[selection] : "")
                .font(.subheadline)
                .frame(minWidth: 96)
                .contentTransition(.opacity)
            Button { step(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.bordered)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(options.indices.contains(selection) ? options[selection] : "")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(1)
            case .decrement: step(-1)
            @unknown default: break
            }
        }
    }

    private func step(_ delta: Int) {
        Haptics.tap()
        withAnimation(Theme.Motion.selection) {
            selection = (selection + delta + options.count) % options.count
        }
    }
}
