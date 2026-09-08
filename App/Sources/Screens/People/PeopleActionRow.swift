import SwiftUI
import TycoonEngine

/// Iteration 11 — N2. One row of the people menu: the icon, what you would
/// be doing, what it costs, which way the bar goes on each side of the
/// roll, the odds, and — when it is refused — why.
///
/// Every number on this row is read out of the engine, so the percentage
/// the player sees is the percentage `InteractionSystem` rolls against.
struct PeopleActionRow: View {
    let engine: GameEngine
    let target: InteractionTarget
    let rule: InteractionRule
    let act: () -> Void

    private var blocker: String? {
        engine.state.interactionBlocker(
            target, rule.id, balance: engine.balance, content: engine.content
        )
    }

    var body: some View {
        PeopleRow(
            icon: rule.icon,
            title: rule.title,
            terms: terms,
            footnote: rule.note,
            blocker: blocker,
            destructive: rule.group != .nice,
            act: act
        )
    }

    /// "Free · affection +4 / −1 · 84%" — the cost, the swing and the odds
    /// in the order a player reads them.
    private var terms: String {
        var parts: [String] = [costText]
        let deltas = rule.deltas(for: target.kind)
        // The one-way rows (end it, disown, fire with cause) do not roll
        // for an outcome — the roll only picks which line you get — so
        // they say what they take and no percentage at all.
        let oneWay = deltas.good <= -100
        if oneWay {
            parts.append("\(target.kind.barLabel) gone")
            parts.append("no way back")
        } else {
            if deltas.good != 0 || deltas.bad != 0 {
                let label = target.kind.barLabel
                if deltas.good == deltas.bad {
                    parts.append("\(label) \(signed(deltas.good))")
                } else {
                    parts.append("\(label) \(signed(deltas.good)) / \(signed(deltas.bad))")
                }
            }
            parts.append("\(Int((engine.state.interactionOdds(target, rule, content: engine.content) * 100).rounded()))%")
        }
        if rule.cooldownDays > 0 {
            parts.append("once every \(rule.cooldownDays)d")
        }
        return parts.joined(separator: " · ")
    }

    private func signed(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        if rounded <= -100 { return "gone" }
        return rounded > 0 ? "+\(rounded)" : "\(rounded)"
    }

    private var costText: String {
        let wallet = engine.state.life.wallet
        switch rule.cost {
        case .free:
            return "Free"
        case .evening:
            return "−1 evening"
        case .wallet(let amount):
            return amount >= 0
                ? "−\(amount.money) → \((wallet - amount).money)"
                : "+\((-amount).money) if they say yes"
        case .eveningAndWallet(let amount):
            return "−1 evening · −\(amount.money) → \((wallet - amount).money)"
        }
    }
}

/// The shared row shape: `FriendSheet`'s `ActionRow`, with room for the
/// one-line note the darker rows carry.
struct PeopleRow: View {
    let icon: String
    let title: String
    let terms: String
    var footnote: String?
    var blocker: String?
    var destructive = false
    let act: () -> Void

    private var tint: Color {
        guard blocker == nil else { return .secondary }
        return destructive ? Theme.warning : Theme.accent
    }

    var body: some View {
        Button(action: act) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(terms)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let footnote, blocker == nil {
                        Text(footnote)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let blocker {
                        Text(blocker)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(
                Theme.chipBackground,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .buttonStyle(.pressableRow)
        .disabled(blocker != nil)
        .accessibilityLabel("\(title). \(terms). \(blocker ?? "")")
    }
}
