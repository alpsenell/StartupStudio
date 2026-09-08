import SwiftUI
import TycoonEngine

/// Iteration 11 — N2. The menu every person in the game gets: who they
/// are, the bar you are about to move, and everything you could do to
/// them, grouped nice / mean / money / serious, each row carrying its
/// cost, its odds and the consequence on the button.
///
/// Like `FriendSheet` and `ContactSheet`, it reads the person out of
/// `engine.state` on every body pass rather than holding a copy: a bar
/// that just moved redraws in place, and a row that just went on cooldown
/// greys out under your thumb.
struct PeopleMenuSheet: View {
    let engine: GameEngine
    let target: InteractionTarget

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                PeopleMenuContent(engine: engine, target: target)
                    .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle(engine.state.interactionName(target, content: engine.content))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// The menu without its chrome, so both the sheet and the pushed screen
/// draw the same thing.
struct PeopleMenuContent: View {
    let engine: GameEngine
    let target: InteractionTarget

    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI updates
    /// this property for presented content before the environment is
    /// installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }

    /// The row waiting on a yes: the serious ones ask first.
    @State private var confirming: InteractionRule?

    /// Every shelf, unless a screenshot pass asked for one of them:
    /// `-autoPeopleGroup mean` draws the mean half without scrolling.
    private var shelves: [InteractionGroup] {
        guard let only = DebugLaunch.autoPeopleGroup,
              let group = InteractionGroup(rawValue: only)
        else { return InteractionGroup.allCases }
        return [group]
    }

    private var rules: [InteractionRule] {
        engine.state.peopleMenu(for: target, content: engine.content)
    }

    /// The outcome paper only shows the line for *this* person, so opening
    /// somebody else's menu does not replay a row you had with your CTO.
    private var outcome: InteractionOutcome? {
        guard let last = engine.state.interactions.lastOutcome, last.target == target
        else { return nil }
        return last
    }

    var body: some View {
        if let bar = engine.state.interactionBar(target, content: engine.content) {
            VStack(spacing: Theme.Spacing.lg) {
                PeopleMenuHeader(engine: engine, target: target, bar: bar)
                if let outcome {
                    PeopleOutcomePaper(
                        engine: engine, target: target, outcome: outcome
                    )
                }
                EveningPips(engine: engine)
                ForEach(shelves, id: \.self) { group in
                    let inGroup = rules.filter { $0.group == group }
                    if !inGroup.isEmpty {
                        CardView(group.displayName, systemImage: group.systemImage) {
                            VStack(spacing: Theme.Spacing.sm) {
                                ForEach(inGroup) { rule in
                                    PeopleActionRow(
                                        engine: engine, target: target, rule: rule
                                    ) { perform(rule) }
                                }
                                // The actions the game already had, in the
                                // same menu, so nothing moved and nothing
                                // the bots do changed.
                                PeopleLegacyRows(
                                    engine: engine, target: target, group: group
                                )
                            }
                        }
                    }
                }
            }
            .confirmationDialog(
                confirming.map { "\($0.title)?" } ?? "",
                isPresented: Binding(
                    get: { confirming != nil },
                    set: { if !$0 { confirming = nil } }
                ),
                titleVisibility: .visible,
                presenting: confirming
            ) { rule in
                Button(rule.title, role: .destructive) { send(rule) }
                Button("Cancel", role: .cancel) { confirming = nil }
            } message: { rule in
                Text(rule.note ?? "There's no version of this you take back.")
            }
            // A screenshot pass cannot tap a row: `-autoInteract <id>`
            // performs one, once, through the ordinary reducer.
            .task { DebugLaunch.takeAutoInteraction(engine: engine, target: target) }
        } else {
            ContentUnavailableView(
                "Not in your life any more",
                systemImage: "person.slash",
                description: Text("This one isn't somebody you can call.")
            )
            .padding(.top, Theme.Spacing.xl)
        }
    }

    private func perform(_ rule: InteractionRule) {
        if rule.confirms {
            confirming = rule
        } else {
            send(rule)
        }
    }

    private func send(_ rule: InteractionRule) {
        confirming = nil
        Haptics.tap()
        shell.toasts.send(
            .interact(target: target, interaction: rule.id),
            to: engine,
            ack: nil,
            rejected: "Not right now.",
            icon: rule.icon
        )
    }
}

// MARK: - Who they are, and the bar you're about to move

private struct PeopleMenuHeader: View {
    let engine: GameEngine
    let target: InteractionTarget
    let bar: Double

    var body: some View {
        CardView(relation, systemImage: icon) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                if let seed = engine.state.interactionSeed(target, content: engine.content) {
                    PixelPortrait(seed: seed, size: 56)
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(engine.state.interactionName(target, content: engine.content))
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                    HStack {
                        Text(target.kind.barLabel.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(bar.rounded()))")
                            .font(Theme.Typography.number(.caption))
                            .contentTransition(.numericText())
                    }
                    PeopleBar(value: bar, tint: tint)
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// A grudge is a bar you want *low*, so it is drawn in the warning
    /// colour rather than the accent one.
    private var tint: Color { target.kind == .rival ? Theme.negativeCash : Theme.accent }

    private var relation: String {
        switch target {
        case .partner: engine.state.phoneRelation(for: .partner)
        case .child: "Your kid"
        case .friend: "A friend"
        case .employee: "On payroll"
        case .contact: "In the book"
        case .rival: engine.state.isNemesis(target.personID ?? UUID())
            ? "Your nemesis" : "A rival studio"
        }
    }

    private var icon: String {
        switch target {
        case .partner: "heart.fill"
        case .child: "figure.child"
        case .friend: "figure.2"
        case .employee: "person.badge.shield.checkmark.fill"
        case .contact: "person.crop.rectangle.stack.fill"
        case .rival: "flag.2.crossed.fill"
        }
    }

    private var note: String {
        switch target.kind {
        case .partner: "Only your own time moves this one."
        case .child: "They keep a ledger. You are in it."
        case .friend: "Silence costs more than a bad evening."
        case .employee: "The bond carries their morale with it."
        case .contact: "Rapport is what the book is actually for."
        case .rival: "The highest grudge in the game is your nemesis."
        }
    }
}

/// The one bar this person owns, drawn the way every other meter is.
struct PeopleBar: View {
    let value: Double
    var tint: Color = Theme.accent

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.chipBackground)
                Capsule()
                    .fill(tint)
                    .frame(width: proxy.size.width * min(1, max(0, value / 100)))
            }
        }
        .frame(height: 6)
        .animation(Theme.Motion.valueChange, value: value)
        .accessibilityHidden(true)
    }
}
