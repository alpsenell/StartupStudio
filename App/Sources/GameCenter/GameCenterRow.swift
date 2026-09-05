import GameKit
import SwiftUI

// MARK: Iteration 7 — Game Center (R3)

/// The *Game Center* row in Settings' Services section: opens the
/// dashboard on the game's achievements. Signed out it says so and offers
/// the sign-in once more — the launch prompt is shown once and never
/// nagged, so this row is the way back to it.
struct GameCenterRow: View {
    @State private var showingDashboard = false

    var body: some View {
        Button {
            Haptics.tap()
            Sounds.play(.tap)
            if GameCenterHub.client.isAuthenticated {
                showingDashboard = true
            } else {
                GameCenterHub.client.authenticate()
            }
        } label: {
            LabeledContent {
                Text(GameCenterHub.client.isAuthenticated ? "Signed in" : "Signed out")
                    .foregroundStyle(.secondary)
            } label: {
                Label("Game Center", systemImage: "gamecontroller")
            }
        }
        .accessibilityHint(
            GameCenterHub.client.isAuthenticated
                ? "Opens achievements and leaderboards"
                : "Signs in to Game Center"
        )
        .sheet(isPresented: $showingDashboard) {
            GameCenterDashboard()
                .ignoresSafeArea()
        }
    }
}

/// `GKGameCenterViewController`, opened on achievements. The delegate is
/// the only way it closes, so it owns the dismissal.
struct GameCenterDashboard: UIViewControllerRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> GKGameCenterViewController {
        let controller = GKGameCenterViewController(state: .achievements)
        controller.gameCenterDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: GKGameCenterViewController, context: Context) {}

    /// GameKit calls the delegate on the main thread but does not say so
    /// in its types, so the one method is `nonisolated` and hops back.
    final class Coordinator: NSObject, GKGameCenterControllerDelegate {
        nonisolated func gameCenterViewControllerDidFinish(_ controller: GKGameCenterViewController) {
            MainActor.assumeIsolated {
                controller.dismiss(animated: true)
            }
        }
    }
}
