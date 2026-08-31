import SwiftUI
import TycoonEngine

/// The weekend plan: a two-column grid of the eight activities with icon,
/// cost, and effect. The planned activity is highlighted; tapping another
/// sends `.planWeekend`. Activities that fall back to something else in the
/// founder's current situation say so instead of being disabled — the
/// engine accepts them and applies the fallback.
struct WeekendCard: View {
    let engine: GameEngine

    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI
    /// updates this property for presented content before the
    /// environment is installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.md),
        GridItem(.flexible(), spacing: Theme.Spacing.md),
    ]

    var body: some View {
        let state = engine.state
        let life = state.life

        CardView("Weekend plan", systemImage: "calendar") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
                    ForEach(WeekendActivity.allCases, id: \.self) { activity in
                        ActivityCell(
                            activity: activity,
                            cost: weekendActivityCost(activity, balance: engine.balance),
                            note: note(for: activity, life: life, day: state.day),
                            isSelected: life.plannedActivity == activity
                        ) {
                            shell.toasts.send(
                                .planWeekend(activity),
                                to: engine,
                                ack: "This weekend: \(activity.displayName.lowercased())",
                                icon: activity.systemImage
                            )
                        }
                    }
                }
                Text(state.dayOfWeek >= 6
                    ? "It's the weekend — the plan is in motion."
                    : "Plays out on days 6–7 of the week; costs come from your wallet.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// Situational annotation shown under the activity name.
    private func note(for activity: WeekendActivity, life: LifeState, day: Int) -> String? {
        switch activity {
        case .dateNight where life.family.stage == .single:
            "Single — acts like Friends"
        case .familyTime where life.family.stage == .single && life.family.children.isEmpty:
            "No family yet — acts like Rest"
        case .doctor where !life.hasCold(day: day):
            "No cold to treat"
        default:
            nil
        }
    }
}

// MARK: - Activity cell

private struct ActivityCell: View {
    let activity: WeekendActivity
    let cost: Int
    let note: String?
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: activity.systemImage)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isSelected ? Theme.accent : .primary)
                        .frame(width: 22)
                    Text(activity.displayName)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Theme.accent)
                    }
                }
                Text(cost > 0 ? cost.money : "Free")
                    .font(Theme.Typography.number(.caption))
                    .foregroundStyle(.secondary)
                Text(activity.effectSummary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let note {
                    Text(note)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.warning)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(
                Theme.chipBackground,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.pressableRow)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var accessibilityText: String {
        var text = "\(activity.displayName), \(cost > 0 ? cost.money : "free"). \(activity.effectSummary)."
        if let note {
            text += " \(note)."
        }
        return text
    }
}
