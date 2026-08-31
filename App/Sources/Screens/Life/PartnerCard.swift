import SwiftUI
import TycoonEngine

/// The founder's partner, as a person rather than a line on the family
/// card: how they are actually feeling about all this, and the four things
/// the founder can do about it.
///
/// The relationships meter can be topped up by a night out with anybody.
/// Affection cannot — only the founder's own time moves it, which is why
/// it gets its own card with its own buttons. It falls a little every day
/// and faster once a fortnight has gone by with no contact, so a founder
/// who is "too busy right now" can watch the number they are going to lose
/// the relationship over.
struct PartnerCard: View {
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
        let family = state.life.family

        if family.stage != .single {
            CardView(family.partnerName ?? "Your partner", systemImage: "heart.fill") {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    HStack(alignment: .top, spacing: Theme.Spacing.md) {
                        if let seed = family.partnerAppearanceSeed {
                            PixelPortrait(seed: seed, size: 44)
                        }
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            AffectionMeter(affection: family.affection)
                            Text(status(family: family, day: state.day))
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(
                                    family.affection < 35 ? Theme.warning : .secondary
                                )
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
                        ForEach(PartnerActivity.allCases, id: \.self) { activity in
                            if let def = engine.balance.relationships.partnerActivity(activity) {
                                PartnerActivityCell(
                                    activity: activity,
                                    cost: def.cost,
                                    affection: def.affection,
                                    blocker: state.partnerActivityBlocker(
                                        activity, balance: engine.balance
                                    )
                                ) {
                                    shell.toasts.send(
                                        .spendTimeWithPartner(activity),
                                        to: engine,
                                        ack: ack(activity, name: family.partnerName),
                                        rejected: "Not right now.",
                                        icon: activity.systemImage
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /// One line saying where the relationship actually is — the number
    /// alone tells a player nothing the first time they see it.
    private func status(family: FamilyState, day: Int) -> String {
        let name = family.partnerName.map { $0.split(separator: " ").first.map(String.init) ?? $0 }
            ?? "They"
        let since = day - (family.lastPartnerDay ?? family.stageSinceDay)
        switch family.affection {
        case ..<20: return "\(name) is barely here any more."
        case ..<35: return "\(name) has stopped asking how work is going."
        case ..<55:
            return since >= engine.balance.relationships.neglectDays
                ? "It's been \(since) days. \(name) has noticed."
                : "Getting by, but they'd like to see more of you."
        case ..<80: return "\(name) is happy with how things are."
        default: return "\(name) thinks you two are unstoppable."
        }
    }

    private func ack(_ activity: PartnerActivity, name: String?) -> String {
        let first = name.map { $0.split(separator: " ").first.map(String.init) ?? $0 } ?? "They"
        switch activity {
        case .call: return "You call \(first)."
        case .dateNight: return "A proper evening with \(first)."
        case .gift: return "\(first) loved it."
        case .weekendAway: return "Two days with \(first), phone off."
        }
    }
}

// MARK: - Meter

private struct AffectionMeter: View {
    let affection: Double

    private var tint: Color {
        if affection < 25 { return Theme.negativeCash }
        if affection < 50 { return Theme.warning }
        return Theme.romance
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Affection")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(affection.rounded()))")
                    .font(Theme.Typography.number(.caption))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
                    .animation(Theme.Motion.valueChange, value: affection)
            }
            Gauge(value: min(max(affection / 100, 0), 1)) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(tint)
                .animation(Theme.Motion.valueChange, value: affection)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Affection \(Int(affection.rounded())) of 100")
    }
}

// MARK: - Cell

private struct PartnerActivityCell: View {
    let activity: PartnerActivity
    let cost: Int
    let affection: Double
    let blocker: String?
    let act: () -> Void

    var body: some View {
        Button(action: act) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: activity.systemImage)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(blocker == nil ? Theme.romance : .secondary)
                        .frame(width: 22)
                    Text(activity.displayName)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                }
                Text(cost > 0 ? cost.money : "Free")
                    .font(Theme.Typography.number(.caption))
                    .foregroundStyle(.secondary)
                Text("+\(Int(affection)) affection")
                    .font(Theme.Typography.number(.caption2, weight: .regular))
                    .foregroundStyle(.secondary)
                if let blocker {
                    Text(blocker)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(Theme.chipBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.pressableRow)
        .disabled(blocker != nil)
        .accessibilityLabel("\(activity.displayName). \(blocker ?? "")")
    }
}

// MARK: - Presentation helpers

extension PartnerActivity {
    var systemImage: String {
        switch self {
        case .call: "phone.fill"
        case .dateNight: "wineglass.fill"
        case .gift: "gift.fill"
        case .weekendAway: "suitcase.fill"
        }
    }
}
