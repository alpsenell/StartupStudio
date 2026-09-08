import PixelKit
import SwiftUI
import TycoonEngine

// Iteration 11 — N3. The words and the small parts the Assets screen, the
// doctor's office, the casino and the vices card all share. Nothing here
// reads state: it turns a catalog id into a name, an icon and a tint.

enum AssetsPresentation {
    /// The icon for a kind of thing you own.
    static func icon(_ kind: AssetKind) -> String {
        switch kind {
        case .car: "car.fill"
        case .property: "building.2.fill"
        case .pet: "pawprint.fill"
        }
    }

    /// The one-line heading over each section of the screen.
    static func sectionNote(_ kind: AssetKind) -> String {
        switch kind {
        case .car: "It costs you every week and it can be gone by morning."
        case .property: "One pays rent. One is four hours away and helps anyway."
        case .pet: "The best money you will spend and the worst vet bill."
        }
    }

    static func viceIcon(_ id: String) -> String {
        switch id {
        case "drink": "wineglass.fill"
        case "caffeine": "cup.and.saucer.fill"
        case "gambling": "suit.spade.fill"
        case "phone": "iphone"
        default: "exclamationmark.triangle.fill"
        }
    }

    /// The band a dependency sits in, and its colour. Under fifteen is not
    /// worth a word; over sixty is where somebody says something.
    static func viceTint(_ dependency: Double, threshold: Double) -> Color {
        if dependency >= threshold { return Theme.negativeCash }
        if dependency >= threshold * 0.6 { return Theme.warning }
        return Theme.accent
    }

    /// How the founder would describe where they are with it.
    static func viceBand(_ dependency: Double, threshold: Double) -> String {
        if dependency <= 0 { return "Not a thing" }
        if dependency < 20 { return "Now and again" }
        if dependency < threshold * 0.6 { return "A habit" }
        if dependency < threshold { return "More than a habit" }
        return "A problem, said out loud"
    }

    static func ailmentIcon(_ id: String) -> String {
        switch id {
        case "burnoutSyndrome": "battery.0percent"
        case "rsi": "hand.raised.fill"
        case "insomnia": "moon.zzz.fill"
        case "badBack": "figure.walk.motion"
        case "liverWarning": "cross.case.fill"
        default: "stethoscope"
        }
    }

    /// The pixel sprite for a thing on the drive or in the room, if it has
    /// one. Properties do not: a flat across town is not in the picture.
    static func sprite(for catalogID: String) -> PixelSprite? {
        SpriteLibrary.HomeDecorName(rawValue: HomeDecor.assetDecorID(catalogID))
            .map { SpriteLibrary.homeDecor($0) }
    }

    /// One sprite on its own transparent canvas, for a garage row.
    static func vignette(for catalogID: String) -> ([PlacedSprite], (width: Int, height: Int))? {
        guard let sprite = sprite(for: catalogID) else { return nil }
        let size = (width: sprite.width + 4, height: sprite.height + 2)
        return ([PlacedSprite(
            sprite: sprite, x: 2, y: 1, kind: .prop, animation: sprite.frameCount > 1 ? .toggle(period: 4) : .still,
            phase: 0
        )], size)
    }
}

/// A thing on the drive or in the room, drawn at its own size.
struct AssetSpriteView: View {
    let catalogID: String
    var scale: Int = 2

    var body: some View {
        if let (placements, size) = AssetsPresentation.vignette(for: catalogID) {
            PixelSceneView(
                placements: placements,
                sceneSize: size,
                scale: .fixed(scale),
                accessibilityLabel: ""
            )
            .accessibilityHidden(true)
        }
    }
}

/// The bar every dependency and every condition is drawn with — the same
/// gauge the wellbeing card uses, so a vice reads as another meter rather
/// than a new kind of thing.
struct AssetMeterBar: View {
    let label: String
    let systemImage: String
    let value: Double
    let tint: Color
    /// The right-hand caption: a band, a stake, a price.
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 18)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: Theme.Spacing.sm)
                Text(caption)
                    .font(Theme.Typography.number(.caption))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
                    .animation(Theme.Motion.valueChange, value: caption)
            }
            Gauge(value: min(max(value / 100, 0), 1)) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(tint)
                .animation(Theme.Motion.valueChange, value: value)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(caption)")
    }
}

/// The refusal line under a button, in the game's voice. Nothing at all
/// when the action is allowed — rule 7: every action shows its
/// consequence, and a refused one says why.
struct AssetRefusalNote: View {
    let reason: String?

    var body: some View {
        if let reason {
            Text(reason)
                .font(.caption2)
                .foregroundStyle(Theme.warning)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
