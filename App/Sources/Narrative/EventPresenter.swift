import SwiftUI
import TycoonContent
import TycoonEngine

/// One rendered line in the activity feed / journal.
struct EventLine {
    let icon: String
    let message: String
    let day: Int
    let tint: Color
}

/// Turns a `GameEvent` the App doesn't otherwise know about into a feed
/// line.
///
/// This is the App's fallback for events added after the scaffold: the
/// activity feed's own switch handles today's cases and hands anything else
/// to `describe`, so a workstream can append a `GameEvent` case without the
/// App failing to build or silently dropping the line.
///
/// Scaffold behavior: returns `nil` (there are no unhandled cases yet), and
/// the feed falls back to a neutral line. WS-B owns this file and describes
/// every event it adds; WS-E's journal uses the same entry point.
enum EventPresenter {
    static func describe(
        _ event: GameEvent,
        state: GameState,
        content: ContentCatalog,
        balance: BalanceConfig
    ) -> EventLine? {
        nil
    }
}
