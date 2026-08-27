import SwiftUI
import TycoonEngine

/// Root of the app: the tab bar, the game-over cover, and the one-time
/// load-failure notice.
///
/// The persistent top HUD is NOT attached here. Each tab's root screen
/// attaches it inside its own `NavigationStack` (see `TopHUD`), so that
/// pinned content in the stack root sits below the HUD and pushed
/// destinations get a regular navigation bar with Back instead.
struct AppRootView: View {
    let session: GameSession

    @State private var selectedTab: GameTab = .hq
    /// Cross-tab navigation, injected for the screens to read. WS-E takes
    /// over `selectedTab` with `router.tab` and fills in the deep links.
    @State private var router = AppRouter()

    var body: some View {
        let engine = session.engine
        TabView(selection: $selectedTab) {
            HQScreen(engine: engine) { difficulty in
                session.startNewGame(difficulty: difficulty)
            }
            .tabItem { Label("HQ", systemImage: "building.2") }
            .tag(GameTab.hq)

            LifeScreen(engine: engine)
                .tabItem { Label("Life", systemImage: "heart.fill") }
                .tag(GameTab.life)

            TeamScreen(engine: engine)
                .tabItem { Label("Team", systemImage: "person.2.fill") }
                .tag(GameTab.team)

            // Products and R&D share one tab (segmented inside) to keep the
            // bar at five tabs.
            ProductsScreen(engine: engine)
                .tabItem { Label("Products", systemImage: "shippingbox.fill") }
                .tag(GameTab.products)

            BusinessScreen(engine: engine)
                .tabItem { Label("Business", systemImage: "briefcase.fill") }
                .tag(GameTab.business)
        }
        .tint(Theme.accent)
        .environment(router)
        .fullScreenCover(isPresented: gameOverPresented) {
            if let info = engine.state.gameOver {
                if info.kind == .acquired {
                    GameWonView(info: info, dateLabel: engine.state.dateLabel) { difficulty in
                        session.startNewGame(difficulty: difficulty)
                    }
                } else {
                    GameOverView(info: info, dateLabel: engine.state.dateLabel) { difficulty in
                        session.startNewGame(difficulty: difficulty)
                    }
                }
            }
        }
        // Pending rival offers surface here (not per tab) so the paused
        // timeline always has its question on screen.
        .sheet(item: pendingDecision) { prompt in
            DecisionSheet(prompt: prompt, engine: engine)
        }
        .alert("Couldn't load your save", isPresented: loadFailurePresented) {
            Button("OK") { session.clearLoadFailure() }
        } message: {
            Text(session.loadFailureMessage ?? "")
        }
    }

    /// Presented whenever the engine reports game over. The setter is a
    /// no-op: dismissal happens when "New game" swaps in a fresh engine
    /// whose state has no `gameOver`.
    private var gameOverPresented: Binding<Bool> {
        Binding(
            get: { session.engine.state.gameOver != nil },
            set: { _ in }
        )
    }

    /// The pending offer needing an answer, if any. The setter is a no-op:
    /// dismissal happens when an option's action clears the pending offer
    /// (interactive dismissal is disabled on the sheet).
    private var pendingDecision: Binding<DecisionPrompt?> {
        Binding(
            get: {
                guard session.engine.state.gameOver == nil else { return nil }
                return DecisionPrompt.pending(
                    in: session.engine.state,
                    content: session.engine.content,
                    balance: session.engine.balance
                )
            },
            set: { _ in }
        )
    }

    /// One-time dismissible notice when the save failed to load.
    private var loadFailurePresented: Binding<Bool> {
        Binding(
            get: { session.loadFailureMessage != nil },
            set: { presented in
                if !presented { session.clearLoadFailure() }
            }
        )
    }
}
