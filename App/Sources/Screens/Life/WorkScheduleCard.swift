import SwiftUI
import TycoonEngine

/// Chill / Normal / Crunch picker bound straight to the engine, with the
/// one-line consequence of the current choice underneath.
struct WorkScheduleCard: View {
    let engine: GameEngine

    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI
    /// updates this property for presented content before the
    /// environment is installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }

    var body: some View {
        let schedule = engine.state.life.schedule

        CardView("Work schedule", systemImage: "clock.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Picker("Work schedule", selection: scheduleBinding) {
                    ForEach(WorkSchedule.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Work schedule")

                Text(schedule.consequence)
                    .font(.footnote)
                    .foregroundStyle(schedule == .crunch ? Theme.warning : .secondary)
                    .animation(.default, value: schedule)
            }
        }
    }

    /// Reads the live schedule from state and sends `.setWorkSchedule` on
    /// every change.
    private var scheduleBinding: Binding<WorkSchedule> {
        Binding(
            get: { engine.state.life.schedule },
            set: { schedule in
                shell.toasts.send(
                    .setWorkSchedule(schedule),
                    to: engine,
                    ack: "Working \(schedule.displayName.lowercased()) from now on",
                    icon: "clock.fill"
                )
            }
        )
    }
}
