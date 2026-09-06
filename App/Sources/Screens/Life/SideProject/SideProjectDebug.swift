import Foundation
import SwiftUI
import TycoonEngine

/// `-autoSideProject <track>`: starts that track and then keeps giving it
/// the founder's evenings, so a headless screenshot pass can photograph a
/// project three chapters in without anybody tapping anything.
///
/// It plays the game rather than writing the state: every evening it
/// spends goes through `Reducer.apply`, is refused by the same gates a
/// player meets (one session a day, the weekly evening budget, the
/// wallet), and lands where a played evening lands. Debug builds only.
enum SideProjectDebug {
    /// Starts the asked-for track once, then works on it for as long as
    /// the surface is on screen. Returns immediately in release builds and
    /// whenever the flag is absent.
    @MainActor
    static func runIfAsked(engine: GameEngine) async {
        #if DEBUG
        guard let name = DebugLaunch.launchSideProjectTrack,
              let track = SideProjectTrack.allCases.first(
                  where: { $0.rawValue.lowercased() == name }
              )
        else { return }

        if engine.state.life.sideProject?.track == nil {
            _ = engine.send(.startSideProject(track: track.rawValue))
        }
        // One attempt per tick of the clock: refused sessions cost nothing
        // and the loop simply waits for tomorrow's evening.
        while !Task.isCancelled, engine.state.gameOver == nil,
              engine.state.life.sideProject?.track != nil {
            _ = engine.send(.workOnSideProject)
            try? await Task.sleep(for: .milliseconds(250))
        }
        #endif
    }
}
