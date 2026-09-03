import SwiftUI
import TycoonEngine

/// The founder's evening budget for the week as a row of pips: one per
/// evening the schedule allows, filled while unspent.
///
/// Iteration 4 seam. Everything that spends an evening — a course, a date,
/// an evening out with a hire, a networking room — shows this strip above
/// its buttons, so the price and the balance are on the same screen. Reads
/// `GameState.eveningsLeftThisWeek` and the schedule's allowance; renders
/// nothing when the schedule has no budget (crunch with zero evenings still
/// shows an empty row, which is the point).
struct EveningPips: View {
    let engine: GameEngine
    /// Compact fits inside a card footer; regular gets a label.
    var compact = false

    private var total: Int? {
        engine.balance.life.evenings(for: engine.state.life.schedule)
    }

    private var left: Int? {
        engine.state.eveningsLeftThisWeek(engine.balance)
    }

    var body: some View {
        if let total, let left {
            HStack(spacing: Theme.Spacing.sm) {
                if !compact {
                    Text("Evenings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    ForEach(0..<max(total, 1), id: \.self) { index in
                        Circle()
                            .fill(index < left ? Theme.accent : Theme.chipBackground)
                            .overlay(Circle().strokeBorder(Theme.accent.opacity(0.35), lineWidth: 1))
                            .frame(width: 10, height: 10)
                    }
                }
                Text("\(left) of \(total) left")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(left == 0 ? Theme.warning : .secondary)
                    .contentTransition(.numericText())
                    .animation(Theme.Motion.valueChange, value: left)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(left) of \(total) evenings left this week")
        }
    }
}
