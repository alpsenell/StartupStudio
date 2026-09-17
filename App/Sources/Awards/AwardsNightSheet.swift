import SwiftUI
import TycoonEngine

// MARK: Iteration 8 — awards night
// MARK: G8 (awards night, attended) — iteration 18

/// The ceremony.
///
/// Iteration 8 drew the year's winners on pixel paper the moment mid-
/// December arrived, and that was the whole night: a list, already
/// decided, with nothing to answer. Iteration 18 puts the question in
/// front of it and the room behind it.
///
/// * **The question.** *Take the team* — `awards.tableByTier`, one founder
///   evening — or *Stay home*. Both answers print what they do; the paid
///   one prints the after-state the house prints everywhere
///   (`DecisionPrompt.afterState`).
/// * **The envelopes.** One at a time, on a tap, with the team's row drawn
///   under them when the team is there. Reduce Motion takes the animation
///   off (`Theme.Motion.entrance` is `nil` then) and leaves the tapping,
///   which is the scene rather than the movement.
///
/// The judging is unchanged and still the app's (`AwardsJudge`). The
/// answer goes to the engine as one `.recordCeremony(year:attended:wins:)`
/// once, from here; the engine files the night and pays it out
/// (`AwardsSystem`). A year already in the book — a save reloaded on the
/// ceremony day — opens straight on the envelopes with every one turned
/// over, and sends nothing.
struct AwardsNightSheet: View {
    let night: AwardsNight
    let companyName: String
    // MARK: G8
    /// The live engine: the price, the refusals, the team, and where the
    /// answer is sent. Optional so a night can still be drawn without one
    /// (a preview, or any caller that only wants the paper).
    var engine: GameEngine? = nil
    // MARK: end G8
    var onClose: () -> Void = {}

    // MARK: Iteration 9 — L7 (furnish)
    /// A night the company won something leaves the pennant, which hangs
    /// on a wall at home from then on.
    @Environment(\.gameSession) private var session
    // MARK: end of Iteration 9 — L7

    // MARK: G8
    private enum Phase: Equatable {
        /// Take the team, or stay home.
        case question
        /// The envelopes, `revealed` of them turned over. `attended` is
        /// what was answered; `nil` when there was no question to answer.
        case envelopes(revealed: Int, attended: Bool?)
    }

    @State private var phase: Phase = .question
    @State private var didAnswer = false
    // MARK: end G8

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    marquee
                    // MARK: G8
                    switch phase {
                    case .question:
                        question
                    case let .envelopes(revealed, attended):
                        if let attended {
                            roomRow(attended: attended)
                        }
                        envelopes(revealed: revealed, attended: attended)
                    }
                    // MARK: end G8
                }
                .padding(Theme.Spacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Theme.screenBackground.ignoresSafeArea())
            // MARK: Iteration 9 — L7 (furnish)
            .onAppear {
                if !night.playerWins.isEmpty { session?.unlockAwardsPennant() }
                // MARK: G8 — a night already in the book has no question
                // left to ask, and neither has one drawn without an engine.
                if let record = engine?.state.ceremony(year: night.year) {
                    phase = .envelopes(revealed: night.categories.count, attended: record.attended)
                } else if engine == nil {
                    phase = .envelopes(revealed: night.categories.count, attended: nil)
                }
                // MARK: end G8
            }
            // MARK: end of Iteration 9 — L7
            .navigationTitle("Awards night")
            .navigationBarTitleDisplayMode(.inline)
            // MARK: G8 — the question has no Done button, so it must not
            // have a swipe either: a night dismissed rather than answered
            // leaves the clock paused with nothing to resume it.
            .interactiveDismissDisabled(phase == .question)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    // MARK: G8 — the question is answered, not dismissed.
                    if phase != .question {
                        Button("Done", action: onClose)
                    }
                    // MARK: end G8
                }
            }
        }
    }

    // MARK: - The marquee

    private var marquee: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                PixelText(text: "THE INDUSTRY AWARDS", scale: 3, color: Theme.pixelAccent)
                PixelText(text: "YEAR \(night.year)", scale: 2, color: Theme.pixelInk)
                Text(headline)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.pixelInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Before the envelopes the headline cannot name the winners, so it
    /// says what the night is instead.
    private var headline: String {
        if phase == .question {
            return "\(night.categories.count) sealed envelopes, and the floor is filling up."
        }
        let wins = night.playerWins.count
        switch wins {
        case 0: return "\(companyName) went home empty-handed. The press noticed who did not."
        case 1: return "\(companyName) took one home: \(night.playerWins[0].title)."
        default: return "\(companyName) took \(wins) home, \(night.playerWins.map(\.title).joined(separator: ", "))."
        }
    }

    // MARK: - G8: the question

    private var price: Int {
        guard let engine else { return 0 }
        return engine.state.ceremonyTablePrice(balance: engine.balance)
    }

    /// Why *Take the team* cannot be taken tonight, in the player's words.
    private var tableBlocker: String? {
        guard let engine else { return nil }
        return engine.state
            .ceremonyRefusal(year: night.year, attending: true, balance: engine.balance)?
            .sentence
    }

    @ViewBuilder
    private var question: some View {
        if let engine {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("A table seats the company down at the front, where the cameras are. The other answer is the sofa and the wire in the morning.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                answerButton(
                    title: "Take the team",
                    detail: "The floor is there when the envelope opens. One evening.",
                    money: DecisionPrompt.afterState(
                        delta: -price, cash: engine.state.company.cash, burn: engine.weeklyBurn
                    ),
                    blocker: tableBlocker,
                    prominent: true
                ) { answer(attended: true) }

                answerButton(
                    title: "Stay home",
                    detail: "A win is a line on the wire. You weren't there to collect it.",
                    money: nil,
                    blocker: nil,
                    prominent: false
                ) { answer(attended: false) }
            }
            .accessibilityElement(children: .contain)
        }
    }

    private func answerButton(
        title: String,
        detail: String,
        money: String?,
        blocker: String?,
        prominent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.tap()
            Sounds.play(.tap)
            action()
        } label: {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text(blocker ?? detail)
                    .font(.caption2)
                    .opacity(0.9)
                if let money, blocker == nil {
                    Text(money)
                        .font(.caption2.monospacedDigit())
                        .opacity(0.9)
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.xs)
        }
        .buttonStyle(.borderedProminent)
        .tint(prominent ? Theme.accent : Color.secondary.opacity(0.35))
        .disabled(blocker != nil)
        .accessibilityLabel("\(title). \(blocker ?? detail)")
    }

    /// Sends the one action, once, and opens the envelopes.
    private func answer(attended: Bool) {
        guard !didAnswer else { return }
        didAnswer = true
        engine?.send(.recordCeremony(
            year: night.year, attended: attended, wins: night.ceremonyWins
        ))
        withAnimation(Theme.Motion.entrance) {
            phase = .envelopes(revealed: 0, attended: attended)
        }
    }

    // MARK: - G8: the room, and the envelopes

    /// Your row: who is sitting in it, or the chairs you did not buy.
    @ViewBuilder
    private func roomRow(attended: Bool) -> some View {
        if let engine {
            let team = Array(engine.state.employees.prefix(8))
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(attended ? "Your row" : "At home")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if attended, !team.isEmpty {
                    HStack(spacing: Theme.Spacing.xs) {
                        ForEach(team, id: \.id) { person in
                            PixelPortrait(
                                seed: person.appearanceSeed,
                                isFounder: person.isFounder,
                                size: 28
                            )
                        }
                        if engine.state.employees.count > team.count {
                            Text("+\(engine.state.employees.count - team.count)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                } else {
                    Text(attended
                        ? "Nobody on payroll yet. The seat beside you stays empty."
                        : "The wire will say who won. It will not say you were there.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private func envelopes(revealed: Int, attended: Bool?) -> some View {
        ForEach(Array(night.categories.prefix(revealed))) { category in
            AwardRow(category: category)
                .transition(.opacity)
        }
        if revealed < night.categories.count {
            Button {
                Haptics.tap()
                Sounds.play(.tap)
                withAnimation(Theme.Motion.entrance) {
                    phase = .envelopes(revealed: revealed + 1, attended: attended)
                }
            } label: {
                Label(
                    revealed == 0 ? "Open the first envelope" : "Open the next envelope",
                    systemImage: "envelope.open.fill"
                )
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.xs)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .accessibilityHint("\(night.categories.count - revealed) envelopes left")

            Button("Open them all") {
                Haptics.tap()
                withAnimation(Theme.Motion.entrance) {
                    phase = .envelopes(revealed: night.categories.count, attended: attended)
                }
            }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct AwardRow: View {
    let category: AwardCategory

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: category.winner?.isPlayer == true ? "trophy.fill" : "trophy")
                .font(.body)
                .foregroundStyle(category.winner?.isPlayer == true ? Theme.accent : Color.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(category.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let winner = category.winner {
                    Text(winner.name)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(winner.isPlayer ? Theme.accent : .primary)
                    Text(winner.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Nobody shipped.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if category.winner?.isPlayer == true {
                Text("YOU")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: end G8
