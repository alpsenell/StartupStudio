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
    /// Something is waiting on the player (the clock stopped for a reason,
    /// a report is unread, a deferred question is counting down): a dot on
    /// the control's corner says so from every tab.
    var attention = false

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
        .overlay(alignment: .topTrailing) {
            if attention {
                Circle()
                    .fill(Theme.warning)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().strokeBorder(Theme.pixelPaper, lineWidth: 1.5))
                    .offset(x: 3, y: -3)
                    .transition(Theme.Motion.transition(.scale.combined(with: .opacity)))
                    .accessibilityLabel("Something needs you")
            }
        }
        .animation(Theme.Motion.selection, value: engine.state.speed)
        .animation(Theme.Motion.selection, value: attention)
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
            // The painted chip stays 26x22 — it has to sit in a HUD bar
            // beside the bitmap cash and date — but the *hit* area is
            // grown around it, downward only. A 44pt target is not
            // available in a persistent bar, and the width is spoken for:
            // four segments each 6pt wider pushed the "4X" off the end of
            // the bar. The height is free, so the target takes it — half
            // again the tappable area, and the bar lays out unchanged.
            segmentLabel(for: speed, isSelected: isSelected)
                .frame(minWidth: 26, minHeight: 22)
                .background(isSelected ? Theme.pixelAccent : Color.clear)
                .frame(minHeight: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(speed.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func segmentLabel(for speed: SimSpeed, isSelected: Bool) -> some View {
        let ink: Color = isSelected ? Theme.ink(on: Theme.pixelAccent) : .secondary
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
