import SwiftUI
import TycoonEngine

/// The first card on Life: the founder's week on one card.
///
/// Evenings left as pips, the schedule and the team's pace (the two
/// crunches, side by side, as the README promises), the weekend plan, and
/// what a day of the founder is worth right now. The cards that spend an
/// evening sit under it; the pips are repeated on each of them.
struct ThisWeekCard: View {
    let engine: GameEngine

    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI
    /// updates this property for presented content before the
    /// environment is installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }

    var body: some View {
        let state = engine.state
        let life = state.life
        let schedule = life.schedule
        let pace = state.economy.workPace
        let hasTeam = state.employees.contains { !$0.isFounder }
        let multiplier = state.founderOutputMultiplier(balance: engine.balance)
        let isAway = life.isAway(day: state.day)
        let moraleImpact = state.founderMoraleImpact(balance: engine.balance)

        CardView("Your week", systemImage: "calendar") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                EveningPips(engine: engine)

                Divider()

                controlRow(
                    label: "Your schedule",
                    systemImage: "clock.fill",
                    value: schedule.displayName,
                    tint: schedule == .crunch ? Theme.warning : Theme.accent
                ) {
                    ForEach(WorkSchedule.allCases, id: \.self) { option in
                        Button {
                            shell.toasts.send(
                                .setWorkSchedule(option),
                                to: engine,
                                ack: "Working \(option.displayName.lowercased()) from now on"
                            )
                        } label: {
                            Label(option.displayName, systemImage: option == schedule ? "checkmark" : "clock")
                        }
                    }
                }
                Text(schedule.consequence)
                    .font(.caption)
                    .foregroundStyle(schedule == .crunch ? Theme.warning : .secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if hasTeam {
                    controlRow(
                        label: "The team's pace",
                        systemImage: "person.3.fill",
                        value: pace.displayName,
                        tint: pace == .crunch ? Theme.warning : Theme.accent
                    ) {
                        ForEach(WorkPace.allCases, id: \.self) { option in
                            Button {
                                shell.toasts.send(
                                    .setWorkPace(option),
                                    to: engine,
                                    ack: "The team is on \(option.displayName.lowercased()) pace"
                                )
                            } label: {
                                Label(option.displayName, systemImage: option == pace ? "checkmark" : "person.3")
                            }
                        }
                    }
                    Text(pace.consequence)
                        .font(.caption)
                        .foregroundStyle(pace == .crunch ? Theme.warning : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if moraleImpact < 0 {
                        Label(
                            "Morale \(Int(moraleImpact.rounded()))/day from how you are showing up",
                            systemImage: "arrow.down.right"
                        )
                        .font(.caption)
                        .foregroundStyle(Theme.negativeCash)
                    }
                }

                Divider()

                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "sun.horizon.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.warning)
                        .frame(width: 20)
                    Text("Weekend")
                        .font(.subheadline)
                    Spacer()
                    Text(life.plannedActivity.displayName)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)

                Divider()

                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        "Founder output ×"
                            + multiplier.formatted(.number.precision(.fractionLength(2)).locale(Theme.gameLocale))
                    )
                    .font(Theme.Typography.number(.subheadline))
                    .foregroundStyle(outputTint(multiplier, isAway: isAway))
                    .contentTransition(.numericText())
                    .animation(Theme.Motion.valueChange, value: multiplier)
                    Text(isAway ? "Away from the office — no output today." : "Schedule × wellbeing × health.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func controlRow<Options: View>(
        label: String,
        systemImage: String,
        value: String,
        tint: Color,
        @ViewBuilder options: () -> Options
    ) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
            Spacer()
            Menu {
                options()
            } label: {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(value)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(tint)
                .padding(.horizontal, Theme.Spacing.sm + 2)
                .padding(.vertical, Theme.Spacing.xs + 1)
                .background(Theme.chipBackground, in: Capsule())
            }
            .accessibilityLabel(label)
            .accessibilityValue(value)
        }
    }

    private func outputTint(_ multiplier: Double, isAway: Bool) -> Color {
        if isAway || multiplier < 0.7 { return Theme.negativeCash }
        if multiplier < 0.9 { return Theme.warning }
        return Theme.positiveCash
    }
}
