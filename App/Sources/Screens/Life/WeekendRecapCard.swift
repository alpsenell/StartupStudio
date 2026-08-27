import SwiftUI
import TycoonEngine

/// What last weekend actually did.
///
/// The weekend is planned days ahead and resolves silently on the week
/// boundary; without this card the only trace was one line in the feed.
/// It reads the most recent `.weekendSpent` event and reports the meter
/// changes the engine's own balance attaches to that activity — no rules
/// duplicated, just the numbers that were applied.
struct WeekendRecapCard: View {
    let engine: GameEngine

    /// The most recent resolved weekend, and the day it happened.
    private var lastWeekend: (activity: WeekendActivity, day: Int)? {
        for event in engine.state.eventLog.reversed() {
            if case .weekendSpent(let activity, let day) = event {
                return (activity, day)
            }
        }
        return nil
    }

    private var partnerName: String? {
        engine.state.life.family.partnerName
    }

    var body: some View {
        if let last = lastWeekend {
            let def = engine.balance.life.activity(last.activity)
            CardView("Last weekend", systemImage: last.activity.systemImage) {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Text(last.activity.displayName)
                            .font(.system(.headline, design: .rounded))
                        Spacer(minLength: Theme.Spacing.sm)
                        Text(GameCalendar(day: last.day).longLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(recapLine(last.activity, def: def))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: Theme.Spacing.md) {
                        MeterChange(label: "Energy", delta: def.energy, systemImage: "bolt.fill")
                        MeterChange(label: "Health", delta: def.health, systemImage: "heart.fill")
                        MeterChange(label: "Mood", delta: def.mood, systemImage: "face.smiling")
                        MeterChange(label: "People", delta: def.relationships, systemImage: "person.2.fill")
                    }

                    if def.cost > 0 {
                        Text("Cost you \(def.cost.money) out of the wallet.")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    /// A sentence in the founder's voice, using the partner's name where
    /// the activity involves them.
    private func recapLine(
        _ activity: WeekendActivity,
        def: BalanceConfig.LifeBalance.ActivityDef
    ) -> String {
        let partner = partnerName
        switch activity {
        case .rest:
            return "You did nothing at all, and it worked."
        case .gym:
            return "Two sessions and a long walk. The body is holding up."
        case .dateNight:
            return partner.map { "Dinner with \($0). They loved it." }
                ?? "A night out that turned into a late one."
        case .friends:
            return "Drinks with the old crowd — nobody talked about work for a whole hour."
        case .hobby:
            return "A weekend in the workshop with the phone face down."
        case .familyTime:
            return engine.state.life.family.children.isEmpty
                ? "A slow weekend at home with \(partner ?? "the people who matter")."
                : "The park, then pancakes. The drawing went on the fridge."
        case .vacation:
            return "You left town. The office will survive without you."
        case .spa:
            return "A whole day of nothing scheduled. Rare."
        case .doctor:
            return "You finally went. The doctor was unimpressed but not alarmed."
        case .networking:
            return "A room full of business cards. Two of them might matter."
        @unknown default:
            return "A weekend off the clock."
        }
    }
}

/// A single meter's change from the weekend, hidden when it didn't move.
private struct MeterChange: View {
    let label: String
    let delta: Double
    let systemImage: String

    var body: some View {
        if abs(delta) >= 0.5 {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text((delta > 0 ? "+" : "") + delta.formatted(.number.precision(.fractionLength(0))))
                    .font(.system(.footnote, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(delta > 0 ? Theme.positiveCash : Theme.negativeCash)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(label) \(delta > 0 ? "up" : "down") \(Int(abs(delta)))")
        }
    }
}

/// The things the founder has bought: what they cost, and what each one
/// still does for them every day.
struct PossessionsCard: View {
    let engine: GameEngine

    private var owned: [(id: String, def: BalanceConfig.InstantLifeBalance.ItemDef)] {
        engine.state.life.possessions
            .compactMap { id in
                engine.balance.instantLife.items[id].map { (id: id, def: $0) }
            }
            // Priciest first: the shelf reads like a trophy case.
            .sorted { $0.def.cost > $1.def.cost }
    }

    private var dailyMood: Double {
        owned.reduce(0) { $0 + $1.def.dailyMoodDrift }
    }

    var body: some View {
        if !owned.isEmpty {
            CardView("Things you own", systemImage: "shippingbox.fill") {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    ForEach(owned, id: \.id) { item in
                        HStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundStyle(Theme.positiveCash)
                            Text(item.def.name)
                                .font(.subheadline)
                            Spacer(minLength: Theme.Spacing.sm)
                            if item.def.dailyMoodDrift > 0 {
                                Text("+\(item.def.dailyMoodDrift.formatted(.number.precision(.fractionLength(0...1)))) mood/day")
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                    if dailyMood > 0 {
                        Text(
                            "Your things add \(dailyMood.formatted(.number.precision(.fractionLength(0...1)))) mood a day."
                        )
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
}
