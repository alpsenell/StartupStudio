import SwiftUI
import TycoonEngine

/// The chapter/goals card on the HQ dashboard: chapter title, the active
/// goals with progress bars, and a teaser for the next chapter.
///
/// Scaffold placeholder: renders nothing, so HQ looks exactly as it does
/// today. WS-F owns this file and fills it in from
/// `engine.state.progression`; its slot in `HQScreen` (right under the
/// office scene) is already reserved, so landing it touches no shared line.
struct GoalsCard: View {
    let engine: GameEngine

    var body: some View {
        EmptyView()
    }
}
