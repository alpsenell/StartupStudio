import SwiftUI
import TycoonEngine

/// The team's pace — relaxed, normal, crunch — with what it costs under
/// it, as one control that writes the same `setWorkPace` state wherever it
/// appears: on the build in the Products list, on the product detail, and
/// on the Life tab's work card. The company's crunch used to live only on
/// the founder's tab; the screen where "we need to ship sooner" is decided
/// had no control and no line saying the team was already on it.
struct WorkPaceControl: View {
    let engine: GameEngine
    /// Tighter type for a card that already carries a lot.
    var compact = false

    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI
    /// updates this property for presented content before the
    /// environment is installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }

    private var pace: WorkPace { engine.state.economy.workPace }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Picker("Team pace", selection: binding) {
                ForEach(WorkPace.allCases, id: \.self) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Company work pace")

            Text(pace.consequence)
                .font(compact ? .caption : .footnote)
                .foregroundStyle(pace == .crunch ? Theme.warning : .secondary)
                .fixedSize(horizontal: false, vertical: true)
                .animation(.default, value: pace)

            if pace == .crunch,
               let evenings = engine.balance.life.evenings(for: engine.state.life.schedule) {
                // The other price of a crunch: the founder's own week.
                Label(
                    "Your own schedule leaves \(evenings) evening\(evenings == 1 ? "" : "s") a week.",
                    systemImage: "moon.stars.fill"
                )
                .font(.caption)
                .foregroundStyle(evenings <= 1 ? Theme.warning : .secondary)
            }
        }
    }

    /// Reads the live pace from state and sends `.setWorkPace` on change.
    private var binding: Binding<WorkPace> {
        Binding(
            get: { engine.state.economy.workPace },
            set: { pace in
                shell.toasts.send(
                    .setWorkPace(pace),
                    to: engine,
                    ack: "The team is on \(pace.displayName.lowercased()) pace"
                )
            }
        )
    }
}

/// "Crunching": the pace, as a pill for a header that should say so.
struct WorkPacePill: View {
    let pace: WorkPace

    var body: some View {
        if pace != .normal {
            StatPill(
                systemImage: pace == .crunch ? "flame.fill" : "leaf.fill",
                value: pace == .crunch ? String(localized: "Crunching", comment: "Pill on a header: the team is on the hardest work pace") : String(localized: "Relaxed", comment: "Pill on a header: the team is on the easiest work pace"),
                tint: pace == .crunch ? Theme.warning : Theme.positiveCash
            )
        }
    }
}
