import SwiftUI
import TycoonEngine

/// Compact segmented-style control for the simulation speed
/// (Paused / 1x / 2x / 4x). Reads the current speed from the engine state
/// and calls `engine.setSpeed(_:)` on taps.
struct SpeedControl: View {
    let engine: GameEngine

    var body: some View {
        HStack(spacing: 2) {
            ForEach(SimSpeed.allCases, id: \.self) { speed in
                segment(for: speed)
            }
        }
        .padding(3)
        .background(Theme.chipBackground, in: Capsule())
        .animation(.spring(duration: 0.25), value: engine.state.speed)
        .accessibilityLabel("Simulation speed")
    }

    @ViewBuilder
    private func segment(for speed: SimSpeed) -> some View {
        let isSelected = engine.state.speed == speed
        Button {
            engine.setSpeed(speed)
        } label: {
            segmentLabel(for: speed)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .monospacedDigit()
                .frame(minWidth: 26, minHeight: 22)
                .foregroundStyle(isSelected ? Color.white : Color.secondary)
                .background(isSelected ? Theme.accent : Color.clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(speed.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func segmentLabel(for speed: SimSpeed) -> some View {
        switch speed {
        case .paused:
            Image(systemName: "pause.fill")
        case .x1:
            Image(systemName: "play.fill")
        default:
            Text(speed.label)
        }
    }
}
