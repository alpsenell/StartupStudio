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

    /// Iteration 7 (R6): the lock's tap goes to the session, which asks
    /// the refusing gate what it wants (the paywall, the daily's result).
    @Environment(\.gameSession) private var session

    /// Iteration 7: a gate on the clock is refusing to run it. The three
    /// running speeds give way to one lock; pausing is always allowed.
    private var isLocked: Bool {
        engine.state.gameOver == nil && !engine.mayAdvance
    }

    var body: some View {
        HStack(spacing: 2) {
            if isLocked {
                segment(for: .paused)
                lockSegment
            } else {
                ForEach(SimSpeed.allCases, id: \.self) { speed in
                    segment(for: speed)
                }
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
        .animation(Theme.Motion.selection, value: isLocked)
        .accessibilityLabel("Simulation speed")
    }

    /// Iteration 7 (R6): the lock where 1×/2×/4× were. Same height, the
    /// three chips' width, so the HUD bar lays out unchanged.
    private var lockSegment: some View {
        Button {
            Haptics.tap()
            Sounds.play(.tap)
            session?.clockLockTapped()
        } label: {
            HStack(spacing: 4) {
                PixelLockGlyph(color: Theme.pixelAccent)
                PixelText(text: "Unlock", scale: 2, color: Theme.pixelAccent)
            }
            .frame(minWidth: 26 * 3 + 4, minHeight: 22)
            .frame(minHeight: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Locked")
        .accessibilityHint("The clock is stopped at this chapter. Opens the unlock.")
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

/// A padlock on the pixel grid, 7 wide by 9 tall at scale 2, drawn the
/// way the bitmap font is so it sits beside it.
struct PixelLockGlyph: View {
    var color: Color = Theme.pixelInk
    var scale: CGFloat = 2

    /// Rows of the glyph, `#` for ink.
    private static let rows = [
        "..###..",
        ".#...#.",
        ".#...#.",
        "#######",
        "#######",
        "###.###",
        "###.###",
        "#######",
        "#######",
    ]

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, _ in
            for (y, row) in Self.rows.enumerated() {
                for (x, cell) in row.enumerated() where cell == "#" {
                    context.fill(
                        Path(CGRect(x: CGFloat(x) * scale, y: CGFloat(y) * scale, width: scale, height: scale)),
                        with: .color(color)
                    )
                }
            }
        }
        .frame(width: 7 * scale, height: 9 * scale)
        .accessibilityHidden(true)
    }
}
