import SwiftUI
import TycoonEngine

/// The clock: four chunky pixel buttons (Paused / 1× / 2× / 4×) that read
/// the current speed from the engine and call `engine.setSpeed(_:)`.
///
/// Drawn as pixel chrome rather than a system segmented control — it sits
/// beside the bitmap cash and date, and it is the control the player
/// touches most.
struct SpeedControl: View {
    let engine: GameEngine

    var body: some View {
        HStack(spacing: 2) {
            ForEach(SimSpeed.allCases, id: \.self) { speed in
                segment(for: speed)
            }
        }
        .padding(2)
        .background(Theme.pixelInk.opacity(0.12))
        .overlay {
            PixelPanelBorder(thickness: 2, corner: 2)
                .fill(Theme.pixelInk.opacity(0.35))
        }
        .animation(.spring(duration: 0.25), value: engine.state.speed)
        .accessibilityLabel("Simulation speed")
    }

    @ViewBuilder
    private func segment(for speed: SimSpeed) -> some View {
        let isSelected = engine.state.speed == speed
        Button {
            Haptics.tap()
            Sounds.play(.tap)
            engine.setSpeed(speed)
        } label: {
            segmentLabel(for: speed, isSelected: isSelected)
                .frame(minWidth: 26, minHeight: 22)
                .background(isSelected ? Theme.pixelAccent : Color.clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(speed.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func segmentLabel(for speed: SimSpeed, isSelected: Bool) -> some View {
        let ink: Color = isSelected ? .white : .secondary
        switch speed {
        case .paused:
            // Two bars: the pixel pause glyph.
            HStack(spacing: 2) {
                Rectangle().frame(width: 3, height: 10)
                Rectangle().frame(width: 3, height: 10)
            }
            .foregroundStyle(ink)
        case .x1:
            PixelText(text: "▶", scale: 2, color: ink)
        default:
            PixelText(text: speed.label, scale: 2, color: ink)
        }
    }
}
