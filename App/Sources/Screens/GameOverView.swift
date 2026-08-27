import SwiftUI
import TycoonEngine

/// Full-screen bankruptcy screen. "New game" wipes the save and starts a
/// fresh run via the session at the chosen difficulty.
struct GameOverView: View {
    let info: GameOverInfo
    let dateLabel: String
    let onNewGame: (Difficulty) -> Void

    /// Starting over deletes the save, so a stray tap the moment bankruptcy
    /// hits can't silently wipe the run: "New game" first opens the
    /// difficulty choice (with Cancel); picking one starts the game.
    @State private var choosingDifficulty = false

    var body: some View {
        ZStack {
            Theme.screenBackground.ignoresSafeArea()

            VStack(spacing: Theme.Spacing.xl) {
                Spacer()

                Image(systemName: "xmark.octagon.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.negativeCash)

                VStack(spacing: Theme.Spacing.sm) {
                    Text("Bankrupt")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    Text(info.reason)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.xl)
                }

                HStack(spacing: Theme.Spacing.sm) {
                    StatPill(systemImage: "calendar", value: "Day \(info.day)")
                    StatPill(systemImage: "clock", value: dateLabel)
                }

                Spacer()

                Button {
                    choosingDifficulty = true
                } label: {
                    Text("New game")
                        .font(.system(.headline, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.sm)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .accessibilityLabel("Start a new game")
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
        .sheet(isPresented: $choosingDifficulty) {
            DifficultyPickerSheet { difficulty in
                choosingDifficulty = false
                onNewGame(difficulty)
            }
        }
    }
}
