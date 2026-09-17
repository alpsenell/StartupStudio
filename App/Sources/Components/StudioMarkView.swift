import PixelKit
import SwiftUI
import TycoonEngine

// MARK: Iteration 18 — the studio mark

/// The studio's generated glyph, drawn crisp at any size.
///
/// Every stamp site in the game goes through this view, and every one of
/// them draws *nothing at all* for a company that never picked a mark —
/// which is every save from before iteration 18, every release fixture and
/// every bot run. `markSeed` nil is not a placeholder: it is the absence
/// of the feature.
struct StudioMarkView: View {
    let seed: UInt64
    var size: CGFloat = 16
    /// A hairline of the card's own ink around the glyph, for the stamps
    /// that sit on busy art (the box-art corner, the HQ plate).
    var border: Color?

    var body: some View {
        let sprite = StudioMarkBuilder.sprite(seed: seed)
        Image(decorative: sprite.cgImage(frame: 0), scale: 1)
            .interpolation(.none)
            .resizable()
            .frame(width: size, height: size)
            .overlay {
                if let border {
                    Rectangle()
                        .strokeBorder(border, lineWidth: max(1, size / 16))
                }
            }
            .accessibilityHidden(true)
    }
}

/// Where a mark comes from, in one place, so no surface has to remember
/// whether it is looking at the player or a rival.
enum StudioMark {
    /// The player's mark, or `nil` when they never picked one.
    static func seed(for state: GameState) -> UInt64? {
        state.company.markSeed
    }

    /// A rival's mark. Derived from the name, so it costs no state, needs
    /// no migration, and the same studio wears the same glyph in every
    /// run that meets it.
    static func seed(forRival name: String) -> UInt64 {
        StudioMarkBuilder.seed(forName: name)
    }
}

/// The player's mark where one was picked, and nothing where one was not —
/// the shape almost every stamp site wants.
struct StudioMarkStamp: View {
    let state: GameState
    var size: CGFloat = 16
    var border: Color?

    var body: some View {
        if let seed = StudioMark.seed(for: state) {
            StudioMarkView(seed: seed, size: size, border: border)
        }
    }
}

/// A rival's mark beside its name. Always drawn: a rival's glyph is a
/// function of the name it already has.
struct RivalMarkView: View {
    let name: String
    var size: CGFloat = 16

    var body: some View {
        StudioMarkView(seed: StudioMark.seed(forRival: name), size: size)
    }
}

// MARK: end of Iteration 18
