import SwiftUI
import TycoonEngine

/// The two work switches, on one card because they are one decision.
///
/// The founder's own schedule (chill / normal / crunch) and the pace the
/// company keeps used to be unrelated — and the company's had no UI at
/// all: `setWorkPace` existed in the engine and nothing in the app ever
/// sent it, so a documented feature was unreachable. Putting them together
/// is what makes the interaction legible: the line between them says what
/// the founder's hours are costing the room right now, so "put the team on
/// crunch and go home at five" is a choice with a number on it rather than
/// a morale drift nobody can explain.
struct WorkScheduleCard: View {
    let engine: GameEngine

    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// Iteration 9 — L6: optional for the same reason the shell is, and
    /// because this card is also presented from a sheet on HQ.
    @Environment(AppRouter.self) private var router: AppRouter?
    /// See `GameShell.shared`: read optionally, because SwiftUI
    /// updates this property for presented content before the
    /// environment is installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }

    var body: some View {
        let state = engine.state
        let schedule = state.life.schedule
        let pace = state.economy.workPace
        let evenings = engine.balance.life.evenings(for: schedule)
        let moraleImpact = state.founderMoraleImpact(balance: engine.balance)

        CardView("Work", systemImage: "clock.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    SwitchLabel("You")
                    Picker("Your schedule", selection: scheduleBinding) {
                        ForEach(WorkSchedule.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Your work schedule")

                    Text(schedule.consequence)
                        .font(.footnote)
                        .foregroundStyle(schedule == .crunch ? Theme.warning : .secondary)
                        .animation(.default, value: schedule)

                    // The schedule's other price. Without this line a
                    // player finds out they have one evening a week by
                    // tapping a grey button somewhere else on the tab.
                    if let evenings {
                        Label(
                            "\(evenings) evening\(evenings == 1 ? "" : "s") a week for anything that isn't work",
                            systemImage: "moon.stars.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(evenings <= 1 ? Theme.warning : .secondary)
                    }
                }

                // MARK: Iteration 9 — L6 (sabbatical)
                // The third setting on this card: not working at all. It
                // belongs next to chill/normal/crunch because it is the
                // same decision taken further — how much of the founder
                // the company gets this month.
                if !state.employees.filter({ !$0.isFounder }).isEmpty {
                    Divider()
                    stepAway(state)
                }
                // MARK: end Iteration 9 — L6

                if !state.employees.filter({ !$0.isFounder }).isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        SwitchLabel("The team")
                        // One control, shared with the product screens.
                        WorkPaceControl(engine: engine)

                        if moraleImpact < 0 {
                            FounderImpactNote(
                                points: moraleImpact,
                                reason: impactReason(state: state, schedule: schedule, pace: pace)
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: Iteration 9 — L6 (sabbatical)

    /// The "step away" entry: what the sabbatical would be right now, and
    /// the way through to the screen that sets one up.
    @ViewBuilder
    private func stepAway(_ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SwitchLabel("Not here at all")
            Button {
                router?.go(.sabbatical)
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "airplane.departure")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    Text(stepAwaySummary(state))
                        .font(.footnote.weight(.semibold))
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressableRow)
            .disabled(router == nil)

            Text(stepAwayConsequence(state))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func stepAwaySummary(_ state: GameState) -> String {
        if let sabbatical = state.life.sabbatical, sabbatical.isActive {
            let left = sabbatical.daysLeft(from: state.day)
            return "Away · \(left) day\(left == 1 ? "" : "s") left"
        }
        return "Take a sabbatical"
    }

    private func stepAwayConsequence(_ state: GameState) -> String {
        let config = engine.balance.sabbatical
        if let sabbatical = state.life.sabbatical, sabbatical.isActive {
            return "\(sabbatical.caretakerName) is running the company. You produce nothing until you land."
        }
        let eligible = state.sabbaticalCandidates(balance: engine.balance)
            .contains { state.caretakerBlocker($0, balance: engine.balance) == nil }
        return eligible
            ? "\(config.minWeeks)–\(config.maxWeeks) weeks off, \(config.weeklyCost.money) a week from your wallet. You produce nothing; somebody you trust runs it."
            : "Nobody has been here \(config.minTenureWeeks) weeks with a bond of \(Int(config.minBond)) yet."
    }

    // MARK: end Iteration 9 — L6

    /// Which of the two hooks is doing the damage — the founder's mood, or
    /// their hours during somebody else's crunch. The engine sums them;
    /// this only has to name the one the player can act on.
    private func impactReason(state: GameState, schedule: WorkSchedule, pace: WorkPace) -> String {
        if pace == .crunch, schedule != .crunch, !state.life.isAway(day: state.day) {
            return schedule == .chill
                ? "You're on chill while they're crunching. Everybody can see the car park."
                : "They're crunching and you're keeping normal hours."
        }
        return "You're in a bad way, and the room can tell."
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
                    rejected: "Not while you're signed off.",
                    icon: "clock.fill"
                )
            }
        )
    }

    private var paceBinding: Binding<WorkPace> {
        Binding(
            get: { engine.state.economy.workPace },
            set: { pace in
                shell.toasts.send(
                    .setWorkPace(pace),
                    to: engine,
                    ack: "The team is on \(pace.displayName.lowercased())",
                    icon: "person.3.fill"
                )
            }
        )
    }
}

// MARK: - Pieces

private struct SwitchLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .textCase(.uppercase)
            .kerning(0.5)
            .foregroundStyle(.tertiary)
    }
}

/// What the founder is costing the room, in the same units the manage
/// sheet shows morale in.
private struct FounderImpactNote: View {
    let points: Double
    let reason: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: "exclamationmark.bubble.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(points.formatted(.number.precision(.fractionLength(1)).locale(Theme.gameLocale))) morale across the team")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.warning)
                Text(reason)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Theme.warning.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Presentation helpers

extension WorkPace {
    /// One-line consequence, matching `WorkSchedule.consequence`'s shape.
    /// (`displayName` already lives on the engine's own enum.)
    var consequence: String {
        switch self {
        case .relaxed:
            "×0.85 output, but morale climbs and they learn faster."
        case .normal:
            "×1.0 output. The pace nobody complains about."
        case .crunch:
            "×1.25 output. Morale drops hard, bugs climb, and they notice whether you're here."
        }
    }
}
