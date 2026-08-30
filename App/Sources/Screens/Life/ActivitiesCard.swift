import PixelKit
import SwiftUI
import TycoonEngine

/// Same-day life actions (BitLife-style): a two-column grid of instant
/// activities plus the shop. Tapping an activity sends the action right
/// away and plays its little pixel vignette; the engine owns every gate,
/// this card mirrors them only to disable buttons with reasons.
struct ActivitiesCard: View {
    let engine: GameEngine

    @State private var playing: PlayingActivity?
    @State private var showingShop = false

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
        let instant = engine.balance.instantLife
        let remainingToday = max(0, instant.maxPerDay - state.life.instantActionsToday)
        let eveningsLeft = state.eveningsLeftThisWeek(engine.balance)

        CardView("Today", systemImage: "figure.walk.circle.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
                    ForEach(InstantActivity.allCases, id: \.self) { activity in
                        if let def = instant.activity(activity) {
                            InstantActivityCell(
                                title: activity.displayName,
                                systemImage: activity.systemImage,
                                cost: def.cost,
                                summary: effectSummary(def),
                                blocker: blocker(for: activity)
                            ) {
                                // Only celebrate what actually happened:
                                // the vignette waits for the engine's
                                // `.instantActivityDone`, so a rejected
                                // action no longer plays a scene and a
                                // summary the player never got.
                                let events = shell.toasts.send(
                                    .doInstantActivity(activity),
                                    to: engine,
                                    rejected: "Not today — \(activity.displayName.lowercased()) is out of reach."
                                )
                                let happened = events.contains { event in
                                    if case .instantActivityDone(let done, _) = event {
                                        return done == activity
                                    }
                                    return false
                                }
                                guard happened else { return }
                                playing = PlayingActivity(
                                    style: ActivitySceneStyle(rawValue: activity.rawValue) ?? .walk,
                                    title: activity.displayName,
                                    summary: effectSummary(def, cost: def.cost)
                                )
                            }
                        }
                    }
                    InstantActivityCell(
                        title: "Shopping",
                        systemImage: "bag.fill",
                        cost: nil,
                        summary: "Treat yourself — owned things lift your days",
                        blocker: founderAway ? "The founder is away" : nil
                    ) {
                        showingShop = true
                    }
                }
                Text(activityFooter(remainingToday: remainingToday, eveningsLeft: eveningsLeft))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
        .sheet(item: $playing) { playing in
            ActivityPlaybackSheet(
                playing: playing,
                appearanceSeed: founderAppearanceSeed
            )
        }
        .sheet(isPresented: $showingShop) {
            ShoppingSheet(engine: engine)
        }
    }

    private var founderAway: Bool {
        engine.state.life.isAway(day: engine.state.day)
    }

    /// Whichever budget is actually about to run out. The week is the
    /// scarcer one once it is down to its last evening or two, and saying
    /// "2 left today" while the week has none is how a player ends up
    /// tapping a grey button and wondering why.
    private func activityFooter(remainingToday: Int, eveningsLeft: Int?) -> String {
        if let eveningsLeft {
            guard eveningsLeft > 0 else {
                return "No evenings left this week — these cost one, like everything else you do for yourself."
            }
            if eveningsLeft <= remainingToday {
                return "\(eveningsLeft) evening\(eveningsLeft == 1 ? "" : "s") left this week · paid from your wallet"
            }
        }
        return remainingToday > 0
            ? "\(remainingToday) activit\(remainingToday == 1 ? "y" : "ies") left today · paid from your wallet"
            : "Done for today — more energy tomorrow."
    }

    private var founderAppearanceSeed: UInt64 {
        engine.state.employees.first(where: \.isFounder)?.appearanceSeed ?? 7
    }

    /// Asked of the engine rather than re-derived here. This used to be a
    /// hand-copied mirror of `LifeSystem.doInstantActivity`'s gates, which
    /// is the shape of bug where a button looks available and does
    /// nothing — and it would have missed the evening budget entirely.
    private func blocker(for activity: InstantActivity) -> String? {
        engine.state.instantActivityBlocker(activity, balance: engine.balance)
    }

    private func effectSummary(
        _ def: BalanceConfig.InstantLifeBalance.InstantActivityDef,
        cost: Int? = nil
    ) -> String {
        var parts: [String] = []
        func term(_ value: Double, _ label: String) {
            guard value != 0 else { return }
            parts.append("\(value > 0 ? "+" : "")\(Int(value)) \(label)")
        }
        term(def.energy, "energy")
        term(def.health, "health")
        term(def.mood, "mood")
        term(def.relationships, "social")
        if let cost, cost > 0 { parts.append("−\(cost.money)") }
        return parts.joined(separator: " · ")
    }
}

/// One playing vignette (drives the playback sheet).
struct PlayingActivity: Identifiable {
    let id = UUID()
    let style: ActivitySceneStyle
    let title: String
    let summary: String
}

// MARK: - Cell

private struct InstantActivityCell: View {
    let title: String
    let systemImage: String
    /// nil hides the price line (the shop entry).
    let cost: Int?
    let summary: String
    let blocker: String?
    let act: () -> Void

    var body: some View {
        Button(action: act) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: systemImage)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(blocker == nil ? Theme.accent : .secondary)
                        .frame(width: 22)
                    Text(title)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                }
                if let cost {
                    Text(cost > 0 ? cost.money : "Free")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Text(summary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let blocker {
                    Text(blocker)
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
        }
        .buttonStyle(.plain)
        .disabled(blocker != nil)
        .accessibilityLabel("\(title). \(summary). \(blocker ?? "")")
    }
}

// MARK: - Presentation helpers

extension InstantActivity {
    var displayName: String {
        switch self {
        case .gymSession: "Gym session"
        case .walk: "Take a walk"
        case .cinema: "Cinema"
        case .restaurant: "Eat out"
        }
    }

    var systemImage: String {
        switch self {
        case .gymSession: "dumbbell.fill"
        case .walk: "figure.walk"
        case .cinema: "film.fill"
        case .restaurant: "fork.knife"
        }
    }
}
