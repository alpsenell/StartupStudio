import SwiftUI
import TycoonEngine

// MARK: Iteration 11 — N4 (fame and the feed)

/// `-autoFame`: posts once a game day for as long as the feed is on
/// screen, so a headless pass has a feed to photograph.
///
/// It sends the same `.postToFeed` action a thumb sends and nothing else —
/// no state is fabricated — so the follower curve in the screenshots is
/// the curve the balance actually produces. Debug builds only, and the
/// whole thing returns on its first line without the flag.
enum FeedDebug {
    @MainActor
    static func runIfAsked(engine: GameEngine) async {
        #if DEBUG
        guard DebugLaunch.seedsFame else { return }
        var posted = 0
        while !Task.isCancelled, engine.state.gameOver == nil {
            // A pass that runs for game-weeks walks into sheets a
            // simulator cannot tap away.
            GameShell.shared.pendingAwardsYear = nil
            GameShell.shared.launchDayProductID = nil
            if engine.state.speed == .paused { engine.setSpeed(.x4) }

            // A pass that runs for game-weeks also walks into the life
            // events the founder's week throws up; answer the first
            // option that is not the end of the run, exactly as the bug
            // hunt's own pass does, so the feed stays on screen.
            if let prompt = DecisionPrompt.pending(
                in: engine.state, content: engine.content, balance: engine.balance
            ), let option = prompt.options.first(where: { option in
                guard option.disabledReason == nil else { return false }
                switch option.action {
                case .acceptBuyout, .acceptBuyoutEarnOut: return false
                default: return true
                }
            }) {
                _ = engine.send(option.action)
            }

            // Mostly takes, so the curve is the ordinary one, with a
            // subtweet every fifth day — which is what opens the beef the
            // screenshots are for. A beef waiting on an answer is left
            // waiting: that card is the picture.
            let beefWaiting = engine.state.fame.beef?.waitingOnYou == true
            let kind: FamePostKind = (posted % 5 == 4 && !beefWaiting) ? .subtweet : .take
            if Fame.postBlocker(
                kind: kind, state: engine.state, content: engine.content
            ) == nil {
                _ = engine.send(.postToFeed(kind: kind, subject: nil))
                posted += 1
            }
            try? await Task.sleep(for: .milliseconds(120))
        }
        #endif
    }
}
