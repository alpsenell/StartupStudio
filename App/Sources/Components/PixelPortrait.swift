import PixelKit
import SwiftUI

/// Small pixel-art portrait for an employee or candidate: the PixelKit
/// person sprite (first frame, no animation) on a rounded chip, rendered
/// with nearest-neighbor scaling so the pixels stay crisp.
struct PixelPortrait: View {
    /// The employee/candidate's `appearanceSeed`; PixelKit derives the
    /// deterministic look from it.
    let seed: UInt64
    var isFounder: Bool = false
    /// Edge length of the square chip. Keep in the 28–36pt range so the
    /// sprite reads at list-row sizes.
    var size: CGFloat = 34

    var body: some View {
        let sprite = SpriteLibrary.person(
            appearance: CharacterAppearance(seed: seed),
            isFounder: isFounder
        )
        Image(decorative: sprite.cgImage(frame: 0), scale: 1)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .padding(2)
            .frame(width: size, height: size)
            .background(
                Theme.chipBackground,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}
