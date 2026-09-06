import PixelKit
import SwiftUI
import TycoonEngine

// MARK: Iteration 9 — L3 (children who grow up, and remember)

/// A child drawn at their own age: the swaddled baby, the stubby toddler,
/// the school-age chibi, the too-tall teenager, or the adult they become.
///
/// The two-frame bounce is PixelKit's, so a row of children on the Family
/// card breathes the same way the home scene does.
struct ChildSprite: View {
    let seed: UInt64
    let stage: ChildStage
    /// Height of the box the sprite is fitted into. The sprite keeps its
    /// aspect ratio inside it, so a baby genuinely reads smaller than a
    /// teenager standing next to them.
    var boxHeight: CGFloat = 46

    private static let frameDuration: TimeInterval = 0.6

    private var sprite: PixelSprite {
        SpriteLibrary.child(appearance: CharacterAppearance(seed: seed), stage: stage.pixelStyle)
    }

    /// How much of the box this age fills — the whole point of the four
    /// sizes is that they are not the same size on screen.
    private var scale: CGFloat {
        switch stage {
        case .baby: 0.45
        case .toddler: 0.62
        case .school: 0.74
        case .teen: 0.94
        case .grown: 1
        }
    }

    var body: some View {
        TimelineView(.periodic(from: .init(timeIntervalSinceReferenceDate: 0), by: Self.frameDuration)) { timeline in
            let tick = Int(timeline.date.timeIntervalSinceReferenceDate / Self.frameDuration)
            let frame = (tick + Int(seed % 2)) % max(1, sprite.frameCount)
            Image(decorative: sprite.cgImage(frame: frame), scale: 1)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(height: boxHeight * scale)
                .frame(width: boxHeight * 0.8, height: boxHeight, alignment: .bottom)
        }
        .accessibilityHidden(true)
    }
}

extension ChildStage {
    /// The engine's stage as PixelKit knows it. The two enums share their
    /// raw values on purpose; PixelKit never imports the engine.
    var pixelStyle: ChildStageStyle {
        ChildStageStyle(rawValue: rawValue) ?? .school
    }
}
