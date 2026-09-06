import PixelKit
import SwiftUI
import TycoonEngine

/// The room where the founder's three friends live: the vignette of a
/// night out at the top, the three of them under it, and the weekend that
/// goes to whoever has heard least from you.
struct FriendsScreen: View {
    let engine: GameEngine

    @State private var opened: OpenedFriend?
    /// Debug: whether `-autoFriends warm` has already been applied.
    @State private var warmed = false

    var body: some View {
        let state = engine.state
        let friends = state.friendRoster(content: engine.content)

        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                header(friends: friends)
                EveningPips(engine: engine)

                CardView("The three of them", systemImage: "person.3.fill") {
                    VStack(spacing: Theme.Spacing.md) {
                        ForEach(friends) { friend in
                            Button {
                                Haptics.tap()
                                opened = OpenedFriend(id: friend.id)
                            } label: {
                                FriendRow(
                                    friend: friend,
                                    lastLine: state.lastLine(from: friend.id)?.text,
                                    day: state.day,
                                    showsChevron: true
                                )
                                .padding(Theme.Spacing.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    Theme.chipBackground,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                            }
                            .buttonStyle(.pressableRow)
                        }
                    }
                }

                WeekendNote(engine: engine, friends: friends)
                if state.life.friends.debtToFriends > 0 {
                    DebtNote(owed: state.life.friends.debtToFriends)
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.screenBackground)
        .navigationTitle("Friends")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // `-autoFriends warm`: the taps a screenshot pass cannot make,
            // sent through the normal reducer.
            if DebugLaunch.warmsFriends, !warmed {
                warmed = true
                for friend in friends {
                    engine.send(.callFriend(friendID: friend.id))
                }
                if let first = friends.first {
                    engine.send(.seeFriend(friendID: first.id))
                }
            }
            // A headless screenshot pass cannot tap a row:
            // `-autoRoute friendsheet` opens the first one, once.
            if DebugLaunch.opensFirstFriendSheet, opened == nil, let first = friends.first {
                opened = OpenedFriend(id: first.id)
            }
        }
        .sheet(item: $opened) { opened in
            FriendSheet(engine: engine, friendID: opened.id)
        }
    }

    /// The pixel vignette of a night out, with the neglected friend beside
    /// the founder — the same scene the weekend plays.
    private func header(friends: [Friend]) -> some View {
        let companion = friends.filter { !$0.hasMovedAway }
            .min { $0.lastSeenDay < $1.lastSeenDay } ?? friends.first
        return PixelSceneView(
            placements: ActivitySceneComposer.compose(
                style: .friends,
                appearance: CharacterAppearance(seed: founderAppearanceSeed),
                isFounder: true,
                companion: companion.map { CharacterAppearance(seed: $0.appearanceSeed) }
            ),
            sceneSize: ActivitySceneComposer.sceneSize(),
            accessibilityLabel: "Drinks with friends"
        )
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }

    private var founderAppearanceSeed: UInt64 {
        engine.state.employees.first(where: \.isFounder)?.appearanceSeed ?? 7
    }
}

// MARK: - Notes

private struct WeekendNote: View {
    let engine: GameEngine
    let friends: [Friend]

    var body: some View {
        let planned = engine.state.life.plannedActivity == .friends
        let neglected = friends.filter { !$0.hasMovedAway && !$0.isOnPayroll }
            .min { $0.lastSeenDay < $1.lastSeenDay }
        return CardView("The weekend", systemImage: "calendar") {
            Text(copy(planned: planned, neglected: neglected))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func copy(planned: Bool, neglected: Friend?) -> String {
        guard let neglected else {
            return "Plan a friends weekend and it goes to whoever you have seen least."
        }
        return planned
            ? "This weekend goes to \(neglected.firstName) — the one you have seen least. The other two hear about it."
            : "Plan a friends weekend and it goes to \(neglected.firstName), the one you have seen least."
    }
}

private struct DebtNote: View {
    let owed: Int

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline)
            Text("You owe \(owed.money) between them. Nothing happens for six months — after that the friendship pays the interest.")
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.warning)
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Theme.warning.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }
}

/// `sheet(item:)` wants an `Identifiable`; the friend's id is the whole
/// of it, and the sheet re-reads them out of the engine every pass.
private struct OpenedFriend: Identifiable {
    let id: UUID
}
