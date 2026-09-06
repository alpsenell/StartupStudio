import SwiftUI
import TycoonEngine

/// The three people from before the company: a face each, the bond as a
/// small bar, and the last thing they said.
///
/// Sits under Family because that is what these are — the founder's own
/// people, not contacts. Tapping anywhere opens the room; tapping one of
/// them opens their sheet.
struct FriendsCard: View {
    let engine: GameEngine
    let onOpen: () -> Void

    var body: some View {
        let state = engine.state
        let friends = state.friendRoster(content: engine.content)

        CardView("Friends", systemImage: "person.3.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                ForEach(friends) { friend in
                    FriendRow(
                        friend: friend,
                        lastLine: state.lastLine(from: friend.id)?.text,
                        day: state.day
                    )
                }
                Divider()
                Button(action: onOpen) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Text(footerLine(friends))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
    }

    /// What the card is for, in one line: the person who has heard least
    /// from you, or the money you owe.
    private func footerLine(_ friends: [Friend]) -> String {
        let owed = engine.state.life.friends.debtToFriends
        if owed > 0 {
            return "You owe \(owed.money) between them. Open to call, see them, or square up."
        }
        guard let quietest = friends.filter({ !$0.hasMovedAway && !$0.isOnPayroll })
            .min(by: { $0.bond < $1.bond })
        else { return "Open to call somebody." }
        return "\(quietest.firstName) has heard least from you. A call is free."
    }
}

// MARK: - One friend

/// A portrait, a name, where the friendship is, and the last thing they
/// texted. Deliberately the same shape as `FamilyCard`'s `PersonRow`, with
/// the bond bar added — a friend reads as family, not as a contact.
struct FriendRow: View {
    let friend: Friend
    let lastLine: String?
    let day: Int
    var showsChevron = false

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            PixelPortrait(seed: friend.appearanceSeed)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: Theme.Spacing.sm) {
                    Text(friend.name)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .lineLimit(1)
                    Text(status)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    if showsChevron {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                BondBar(bond: friend.bond)
                if let lastLine {
                    Text("“\(lastLine)”")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(friend.archetype.blurb)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(friend.name), \(friend.archetype.displayName), \(friend.bondLabel), bond \(Int(friend.bond.rounded())) of 100"
        )
    }

    private var status: String {
        if friend.isOnPayroll { return "· on the payroll" }
        if friend.hasMovedAway { return "· abroad" }
        return "· \(friend.archetype.displayName.lowercased())"
    }
}

/// The bond, as a short bar with its word next to it. Same gauge the
/// contact sheet uses for rapport, at row scale.
struct BondBar: View {
    let bond: Double
    /// The header already prints the number beside the word, so it asks
    /// for the bar alone.
    var showsValue = true

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Gauge(value: min(max(bond / 100, 0), 1)) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(tint)
                .frame(maxWidth: 110)
                .animation(Theme.Motion.valueChange, value: bond)
            if showsValue {
                Text("\(Int(bond.rounded()))")
                    .font(Theme.Typography.number(.caption2))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
            }
            Spacer(minLength: 0)
        }
        .accessibilityHidden(true)
    }

    private var tint: Color {
        if bond < 25 {
            Theme.negativeCash
        } else if bond < 55 {
            Theme.warning
        } else {
            Theme.positiveCash
        }
    }
}
