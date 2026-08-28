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
    let onNewGame: (Difficulty, FounderProfile) -> Void

    var body: some View {
        FounderBiographyView(engine: engine, info: info, onNewGame: onNewGame)
    }
}
