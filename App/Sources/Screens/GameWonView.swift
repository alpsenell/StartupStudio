import SwiftUI
import TycoonEngine

/// The screen a successful run ends on — an acquisition, or the bell.
///
/// A thin wrapper: every ending, win or lose, is told by
/// `FounderBiographyView`, which picks its headline and tone from
/// `GameOverInfo.kind`.
struct GameWonView: View {
    let engine: GameEngine
    let info: GameOverInfo
    let onNewGame: (Difficulty, FounderProfile, FoundingOrigin) -> Void
    var onReplay: (() -> Void)?
    /// Iteration 7: share and keep-running, passed through to the biography.
    var actions: BiographyActions = BiographyActions()

    var body: some View {
        FounderBiographyView(engine: engine, info: info, onNewGame: onNewGame, onReplay: onReplay, actions: actions)
    }
}
