import SwiftUI
import TycoonEngine

/// The weekend plan: a two-column grid of the eight activities with icon,
/// cost, and effect. The planned activity is highlighted; tapping another
/// sends `.planWeekend`. Activities that fall back to something else in the
/// founder's current situation say so instead of being disabled — the
/// engine accepts them and applies the fallback.
///
/// Iteration 15 — K6: the family holiday sits beside the vacation once
/// there is somebody to take, and the solo vacation finally prints what it
/// costs the partner.
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

    // MARK: K6 (home and rooms)
    /// One cell of the grid: an activity, or the family holiday beside the
    /// vacation.
    private enum Cell: Hashable {
        case activity(WeekendActivity)
        case familyHoliday
    }

    private var cells: [Cell] {
        var cells: [Cell] = []
        for activity in WeekendActivity.allCases {
            cells.append(.activity(activity))
            if activity == .vacation, engine.state.familyHolidayQuote(balance: engine.balance) != nil {
                cells.append(.familyHoliday)
            }
        }
        return cells
    }
    // MARK: end K6

    var body: some View {
        let state = engine.state
        let life = state.life

        CardView("Weekend plan", systemImage: "calendar") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                EveningPips(engine: engine, compact: true)
                LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
                    ForEach(cells, id: \.self) { cell in
                        switch cell {
                        case .activity(let activity):
                            ActivityCell(
                                title: activity.displayName,
                                systemImage: activity.systemImage,
                                cost: weekendActivityCost(activity, balance: engine.balance),
                                summary: activity.effectSummary,
                                note: note(for: activity, life: life, day: state.day),
                                isSelected: life.plannedActivity == activity
                                    && !(activity == .vacation && life.familyHoliday)
                            ) {
                                shell.toasts.send(
                                    .planWeekend(activity),
                                    to: engine,
                                    ack: "This weekend: \(activity.displayName.lowercased())",
                                    icon: activity.systemImage
                                )
                            }
                        // MARK: K6 (home and rooms)
                        case .familyHoliday:
                            if let quote = state.familyHolidayQuote(balance: engine.balance) {
                                ActivityCell(
                                    title: "Family holiday",
                                    systemImage: "beach.umbrella.fill",
                                    cost: quote.cost,
                                    summary: familyHolidaySummary(quote),
                                    // MARK: T6 (away) — the same clash: the family holiday is the same week away.
                                    note: weekAwayClash,
                                    // MARK: end T6
                                    isSelected: life.plannedActivity == .vacation && life.familyHoliday
                                ) {
                                    planFamilyHoliday()
                                }
                            }
                        // MARK: end K6
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
        // MARK: K6 (home and rooms)
        // The drift runs doubled while the founder is gone; the row has
        // been charging it without saying so since iteration 9.
        case .vacation:
            // MARK: T6 (away) — J3: the launch inside the week away, beside the affection.
            [
                engine.state.vacationAffectionCost(balance: engine.balance).map {
                    $0 < 0 ? "Affection −\(-$0) while you are away" : "Affection +\($0) while you are away"
                },
                weekAwayClash,
            ].compactMap { $0 }.joined(separator: " · ").nilIfEmpty
            // MARK: end T6
        // MARK: end K6
        default:
            nil
        }
    }

    // MARK: T6 (away)
    /// J3: "Round 9 ships on day 4 of the week away · hype ×0.85, no party"
    /// — a build whose ship gate falls inside the week the vacation (or the
    /// family holiday) takes, from the Now card's ETA. `nil` when nothing
    /// is due. The networking weekend never takes the founder away, so it
    /// has no clash to print.
    private var weekAwayClash: String? {
        let state = engine.state
        return state.launchClash(
            awayFrom: state.nextWeekendResolveDay,
            days: engine.balance.life.vacationDays,
            absence: "the week away",
            balance: engine.balance,
            content: engine.content
        )
    }
    // MARK: end T6

    // MARK: K6 (home and rooms)

    /// The family holiday's trade against the solo one, in numbers.
    private func familyHolidaySummary(_ quote: FamilyHolidayQuote) -> String {
        var parts = ["Away a week together", "energy +\(quote.energy) (not +\(soloEnergy))"]
        if quote.hasPartner { parts.append("affection +\(quote.affection)") }
        if quote.children > 0 { parts.append("kids' bond +\(quote.childBond)") }
        return parts.joined(separator: " · ")
    }

    private var soloEnergy: Int {
        Int(engine.balance.life.activity(.vacation).energy.rounded())
    }

    private func planFamilyHoliday() {
        engine.send(.planFamilyHoliday)
        guard engine.state.life.familyHoliday else {
            shell.toasts.show(
                "Nobody to take with you.",
                icon: "exclamationmark.triangle.fill",
                tint: Theme.warning,
                severity: .notable
            )
            return
        }
        Haptics.commit()
        shell.toasts.show("This weekend: a family holiday", icon: "beach.umbrella.fill", tint: Theme.accent)
    }
    // MARK: end K6
}

// MARK: T6 (away)
private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
// MARK: end T6

// MARK: - Activity cell

private struct ActivityCell: View {
    let title: String
    let systemImage: String
    let cost: Int
    let summary: String
    let note: String?
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: systemImage)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isSelected ? Theme.accent : .primary)
                        .frame(width: 22)
                    Text(title)
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
                Text(summary)
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
        var text = "\(title), \(cost > 0 ? cost.money : "free"). \(summary)."
        if let note {
            text += " \(note)."
        }
        return text
    }
}
