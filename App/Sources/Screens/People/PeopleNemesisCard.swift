import SwiftUI
import TycoonEngine

/// Iteration 11 — N2. The strip on a rival's profile that says how
/// personal this has got: the grudge as a bar, whether they are *the*
/// nemesis, and the three things you can do about it — taunt, sabotage,
/// or offer to bury it.
///
/// Drawn only once there is a grudge or the rival is one you have already
/// touched, so a run that never opens a people menu sees the profile it
/// has always seen.
struct PeopleNemesisCard: View {
    let engine: GameEngine
    let rivalID: UUID

    private var rival: Rival? { engine.state.rivals.rival(id: rivalID) }
    private var target: InteractionTarget { .rival(rivalID) }

    private var rules: [InteractionRule] {
        engine.state.peopleMenu(for: target, content: engine.content)
    }

    private var outcome: InteractionOutcome? {
        guard let last = engine.state.interactions.lastOutcome, last.target == target
        else { return nil }
        return last
    }

    var body: some View {
        if let rival {
            CardView(
                engine.state.isNemesis(rivalID) ? "Your nemesis" : "How personal this is",
                systemImage: "flame.fill"
            ) {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Grudge")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(rival.grudge.rounded()))")
                                .font(Theme.Typography.number(.caption))
                                .contentTransition(.numericText())
                        }
                        PeopleBar(value: rival.grudge, tint: Theme.negativeCash)
                        Text(blurb(rival))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let outcome {
                        PeopleOutcomePaper(
                            engine: engine, target: target, outcome: outcome
                        )
                    }
                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(rules) { rule in
                            PeopleNemesisRow(engine: engine, rivalID: rivalID, rule: rule)
                        }
                    }
                }
            }
            // A screenshot pass cannot tap a row: `-autoInteract taunt`
            // on `-autoRoute rivalProfile` performs one, once, through the
            // ordinary reducer.
            .task { DebugLaunch.takeAutoInteraction(engine: engine, target: target) }
        }
    }

    private func blurb(_ rival: Rival) -> String {
        switch rival.grudge {
        case ..<1: "Nothing personal yet. That is a choice you can make."
        case ..<25: "They have noticed you. That is all, so far."
        case ..<60: "You are a name in their standup."
        default: "They think about you on Sundays."
        }
    }
}

/// One nemesis action, with a confirmation on the one that is deniable
/// rather than legal.
private struct PeopleNemesisRow: View {
    let engine: GameEngine
    let rivalID: UUID
    let rule: InteractionRule

    @Environment(GameShell.self) private var injectedShell: GameShell?
    private var shell: GameShell { injectedShell ?? .shared }
    @State private var confirming = false

    var body: some View {
        PeopleActionRow(
            engine: engine, target: .rival(rivalID), rule: rule
        ) {
            if rule.confirms { confirming = true } else { send() }
        }
        .confirmationDialog(
            "\(rule.title)?",
            isPresented: $confirming,
            titleVisibility: .visible
        ) {
            Button(rule.title, role: .destructive) { send() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(rule.note ?? "This one leaves a trace.")
        }
    }

    private func send() {
        Haptics.tap()
        shell.toasts.send(
            .interact(target: .rival(rivalID), interaction: rule.id),
            to: engine,
            rejected: "Not right now.",
            icon: rule.icon
        )
    }
}
