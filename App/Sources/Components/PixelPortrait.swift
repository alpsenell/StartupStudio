import PixelKit
import SwiftUI

/// Small pixel-art portrait for an employee, candidate or rival: the
/// PixelKit `.portrait` bust — a 10×10 head-and-shoulders crop that keeps
/// the glasses, beard, outfit and role accessory — on a rounded chip,
/// rendered with nearest-neighbor scaling so the pixels stay crisp.
///
/// The portrait blinks about once every four seconds. It is the cheapest
/// possible signal that the person in the list row is a person.
struct PixelPortrait: View {
    /// The employee/candidate's `appearanceSeed`; PixelKit derives the
    /// deterministic look from it.
    let seed: UInt64
    var isFounder: Bool = false
    /// The role accessory drawn on the bust (headset, beret, tie…).
    var role: RoleLook = .none
    /// Edge length of the square chip. Keep in the 28–36pt range so the
    /// sprite reads at list-row sizes.
    var size: CGFloat = 34

    /// Seconds between blinks, and how long a blink lasts. One tick of the
    /// timeline is `blinkDuration`, so the whole cycle is a whole number of
    /// ticks and every portrait blinks on its own beat.
    private static let blinkDuration: TimeInterval = 0.2
    private static let ticksBetweenBlinks = 20

    private var sprite: PixelSprite {
        SpriteLibrary.person(
            appearance: CharacterAppearance(seed: seed),
            pose: .portrait,
            isFounder: isFounder,
            role: role
        )
    }

    /// Frame 1 is the blink. Each seed gets its own offset into the cycle so
    /// a roster of twenty people does not blink in unison.
    private func frame(at date: Date) -> Int {
        let tick = Int(date.timeIntervalSinceReferenceDate / Self.blinkDuration)
        let offset = Int(seed % UInt64(Self.ticksBetweenBlinks))
        return (tick + offset) % Self.ticksBetweenBlinks == 0 ? 1 : 0
    }

    var body: some View {
        TimelineView(.periodic(from: .init(timeIntervalSinceReferenceDate: 0), by: Self.blinkDuration)) { timeline in
            Image(decorative: sprite.cgImage(frame: frame(at: timeline.date)), scale: 1)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        }
        .padding(2)
        .frame(width: size, height: size)
        .background(
            Theme.chipBackground,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .accessibilityHidden(true)
    }
}

#Preview("Portraits") {
    HStack(spacing: 8) {
        PixelPortrait(seed: 7, isFounder: true)
        PixelPortrait(seed: 21, role: .qa)
        PixelPortrait(seed: 34, role: .designer)
        PixelPortrait(seed: 42, role: .lawyer)
        PixelPortrait(seed: 55, role: .ops)
    }
    .padding()
}
