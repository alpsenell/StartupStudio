import SwiftUI
import TycoonEngine

/// The fortnight in three lines, at the top of Life: the next three dated
/// things with how far away each is, the evenings the week has left, and a
/// way into the whole calendar.
///
/// It leads the tab because it is the only card that answers "what is
/// coming"; everything below it answers "what is true now".
struct AgendaCard: View {
    let engine: GameEngine
    /// Opens the full fourteen days.
    let onOpen: () -> Void
    /// Follows one row to the screen that answers it.
    let onRoute: (Route) -> Void
    // MARK: V1 (ux: Life folded, rooms dormant)
    /// Iteration 14 — V1, C1. Drawn inside "Your week" rather than as a
    /// card of its own: the same rows and the same way into the fourteen
    /// days, without the second header and paper. Standalone (the
    /// default) is unchanged.
    var nested = false
    // MARK: end V1

    /// The next three things. Three is what fits above "Your week" without
    /// pushing it off the first screen.
    private var next: [AgendaItem] {
        Array(
            Agenda.items(in: engine.state, balance: engine.balance, content: engine.content)
                .prefix(3)
        )
    }

    var body: some View {
        // MARK: V1 (ux: Life folded, rooms dormant)
        if nested {
            rows
        } else {
            CardView("The fortnight", systemImage: "calendar") { rows }
        }
        // MARK: end V1
    }

    private var rows: some View {
        Group {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if next.isEmpty {
                    Text("Nothing is due for two weeks.")
                        .emptySectionText()
                } else {
                    VStack(spacing: 0) {
                        ForEach(next) { item in
                            row(item)
                            if item.id != next.last?.id {
                                Divider()
                            }
                        }
                    }
                }

                Divider()

                // No evening pips here: "Your week", directly below this
                // card, owns the evening budget, and the same three dots
                // twice on one screen reads as a bug. The fortnight's own
                // page carries them, per day, where they are the answer.
                HStack {
                    Spacer(minLength: Theme.Spacing.sm)
                    Button {
                        Haptics.tap()
                        onOpen()
                    } label: {
                        HStack(spacing: 4) {
                            Text("All 14 days")
                                .font(.footnote.weight(.semibold))
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.bold))
                        }
                        .foregroundStyle(Theme.accent)
                    }
                    .accessibilityLabel("Open the fortnight")
                }
            }
        }
    }

    private func row(_ item: AgendaItem) -> some View {
        Button {
            Haptics.tap()
            onRoute(item.route)
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: item.systemImage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(item.tint)
                    .frame(width: 22)
                Text(item.title)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: Theme.Spacing.xs)
                Text(Self.whenLabel(item.day - engine.state.day))
                    .font(Theme.Typography.number(.caption))
                    .foregroundStyle(item.day - engine.state.day <= 3 ? item.tint : .secondary)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 2)
                    .background(Theme.chipBackground, in: Capsule())
            }
            .padding(.vertical, Theme.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressableRow)
        .accessibilityLabel("\(item.title), \(Self.spokenWhen(item.day - engine.state.day))")
    }

    /// "today", "tomorrow", "6d" — the chip has room for a numeral, not a
    /// sentence.
    static func whenLabel(_ daysAway: Int) -> String {
        switch daysAway {
        case ..<1: "today"
        case 1: "tomorrow"
        default: "\(daysAway)d"
        }
    }

    static func spokenWhen(_ daysAway: Int) -> String {
        switch daysAway {
        case ..<1: "today"
        case 1: "tomorrow"
        default: "in \(daysAway) days"
        }
    }
}
