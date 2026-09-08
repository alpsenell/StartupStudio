import SwiftUI
import TycoonEngine

/// Iteration 11 — N2. The people menu as a pushed screen, for the deep
/// link (`-autoRoute people`, and `Route.peopleMenu`). Same content as the
/// sheet — one view, two doors.
struct PeopleMenuScreen: View {
    let engine: GameEngine
    let target: InteractionTarget

    var body: some View {
        ScrollView {
            PeopleMenuContent(engine: engine, target: target)
                .padding(Theme.Spacing.lg)
        }
        .background(Theme.screenBackground)
        .navigationTitle(engine.state.interactionName(target, content: engine.content))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}
