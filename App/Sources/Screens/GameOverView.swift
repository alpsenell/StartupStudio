import SwiftUI
import TycoonEngine

/// The screen a failed run ends on — bankruptcy, or a board that ran out of
/// patience.
///
/// A thin wrapper: every ending, win or lose, is told by
/// `FounderBiographyView`. This exists so `AppRootView`'s cover keeps its
/// two names, and so the difficulty-only `onNewGame` callback the app shell
/// hands down still works — the biography's setup sheet supplies the
/// founder profile alongside it.
struct GameOverView: View {
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
