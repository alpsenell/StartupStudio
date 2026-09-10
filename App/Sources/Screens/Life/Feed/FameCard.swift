import SwiftUI
import TycoonEngine

// MARK: Iteration 11 — N4 (fame and the feed)

/// The founder's public standing, in the You section: the follower count,
/// fame as a meter with its five steps on it, and the one sentence that
/// says what the next step buys.
///
/// A founder who has never posted gets the invitation instead — one line
/// and a button — because a card that says "0 followers · Unknown" every
/// week for a run that is not about this is a card in the way.
struct FameCard: View {
    let engine: GameEngine
    /// Pushes `FeedScreen`.
    let onOpen: () -> Void

    var body: some View {
        let state = engine.state
        let config = engine.balance.fame
        let level = Fame.level(state.fame.fame, balance: config)

        Group {
            // MARK: V1 (ux: Life folded, rooms dormant) — C2
            // Nothing on Life until the room has something in it (a
            // door, an event, a case, a first post): until then it is a
            // quiet row under "Other rooms". The modifiers below stay on
            // the stand-in, so the card's debug hooks still run.
            if LifeRoom.fame.isOpen(in: engine.state, balance: engine.balance) {
                CardView("The feed", systemImage: "at") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        if state.fame.posts.isEmpty {
                            invitation
                        } else {
                            standing(state: state, level: level, config: config)
                        }
                        Button {
                            Haptics.tap()
                            onOpen()
                        } label: {
                            Label(openLabel(state), systemImage: "chevron.right")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .labelStyle(.trailingIcon)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.pressable)
                        .tint(Theme.accent)
                    }
                }
            } else {
                LifeRoomDormant()
            }
            // MARK: end V1
        }
        // `-autoFame` drives from the card as well as the screen, so a
        // headless pass can photograph either without tapping through.
        .task { await FeedDebug.runIfAsked(engine: engine) }
    }

    // MARK: - Nobody has heard of you

    private var invitation: some View {
        Text("You have an account and no posts on it. Nobody has heard of you, "
            + "which is the safest a founder ever gets.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Somebody has

    @ViewBuilder
    private func standing(
        state: GameState, level: FameLevel, config: BalanceConfig.FameBalance
    ) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            StatPill(
                systemImage: "person.2.fill",
                value: FeedFormat.count(state.fame.followers),
                tint: Theme.accent
            )
            StatPill(
                systemImage: "megaphone.fill",
                value: level.displayName,
                tint: level >= .notable ? Theme.warning : .primary
            )
            Spacer(minLength: 0)
            Text("\(Int(state.fame.fame.rounded()))")
                .font(Theme.Typography.number(.title3))
                .foregroundStyle(.primary)
        }

        FameMeter(fame: state.fame.fame, balance: config)

        // What the next step buys — and, at the top, what this one does.
        if let next = level.next {
            let to = Fame.threshold(next, balance: config)
            Text("\(next.displayName) at \(Int(to.rounded())): \(next.buys)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(level.buys)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        if let beef = state.fame.beef, beef.waitingOnYou {
            FameNotice(
                systemImage: "flame.fill",
                tint: Theme.warning,
                text: "\(beef.rivalName) answered you in public. Your move."
            )
        }
        if let cancellation = state.fame.cancellation, cancellation.response == nil {
            FameNotice(
                systemImage: "exclamationmark.bubble.fill",
                tint: Theme.negativeCash,
                text: "An old post of yours has surfaced. Everyone is waiting."
            )
        }
    }

    private func openLabel(_ state: GameState) -> String {
        if state.fame.posts.isEmpty { return "Open the feed · say something" }
        if let last = state.fame.lastPostDay, last >= state.day {
            return "Open the feed · posted today"
        }
        return "Open the feed · one post left today"
    }
}

/// Fame 0…100 with the five thresholds ticked on it, so the meter says
/// where the next thing is rather than only how full it is.
struct FameMeter: View {
    let fame: Double
    let balance: BalanceConfig.FameBalance

    private var ticks: [Double] {
        [balance.knownAt, balance.followedAt, balance.notableAt,
         balance.famousAt, balance.starAt]
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.chipBackground)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Theme.accent, Theme.warning],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: max(2, width * min(1, max(0, fame) / 100)))
                ForEach(ticks, id: \.self) { tick in
                    Rectangle()
                        .fill(Theme.pixelInk.opacity(0.35))
                        .frame(width: 1.5)
                        .offset(x: width * (tick / 100))
                }
            }
        }
        .frame(height: 10)
        .animation(Theme.Motion.valueChange, value: fame)
        .accessibilityElement()
        .accessibilityLabel("Fame \(Int(fame.rounded())) out of 100")
    }
}

/// A one-line flag inside a card: something is waiting.
struct FameNotice: View {
    let systemImage: String
    let tint: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.sm)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
