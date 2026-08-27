import SwiftUI
import TycoonEngine

/// Root of the app: the tab bar, the acknowledgement layer (toasts,
/// launch day, weekly report), the new-game flow, the game-over cover, and
/// the one-time load-failure notice.
///
/// The persistent top HUD is NOT attached here. Each tab's root screen
/// attaches it inside its own `NavigationStack` (see `TopHUD`), so that
/// pinned content in the stack root sits below the HUD and pushed
/// destinations get a regular navigation bar with Back instead.
struct AppRootView: View {
    let session: GameSession

    /// Cross-tab navigation, read by every screen.
    @State private var router = AppRouter()
    /// Toasts, the weekly-report loop, and the launch-day moment.
    @State private var shell = GameShell()

    var body: some View {
        let engine = session.engine
        tabs(engine: engine)
            .tint(Theme.accent)
            .environment(router)
            .environment(shell)
            // One observation point for the whole app: everything the
            // world does reaches the player from here.
            //
            // The rebase runs first and on appear, so a resumed save never
            // replays its backlog as toasts and a swapped-in engine starts
            // from its own day.
            .onChange(of: ObjectIdentifier(engine), initial: true) { _, _ in
                shell.rebase(to: engine)
            }
            .onChange(of: engine.state.eventLog.count) { _, _ in
                shell.eventsChanged(engine: engine)
            }
            .onChange(of: engine.state.day) { _, _ in
                shell.dayAdvanced(engine: engine)
            }
            .overlay(alignment: .top) {
                ToastStack(center: shell.toasts)
                    .padding(.top, Theme.Spacing.xl * 3)
            }
            .fullScreenCover(isPresented: onboardingPresented) {
                NewGameFlow(
                    content: engine.content,
                    onStart: { profile, companyName, difficulty in
                        session.startNewGame(
                            profile: profile, companyName: companyName, difficulty: difficulty
                        )
                        shell.rebase(to: session.engine)
                        router.tab = .hq
                    },
                    onCancel: session.needsOnboarding && engine.state.day > 0
                        ? { session.cancelOnboarding() }
                        : nil
                )
                .interactiveDismissDisabled()
            }
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
            .sheet(isPresented: launchDayPresented) {
                if let productID = shell.launchDayProductID,
                   let product = engine.state.product(id: productID) {
                    LaunchDaySheet(engine: engine, product: product)
                }
            }
            .sheet(isPresented: weeklyReportPresented) {
                if let report = shell.report {
                    WeeklyReportSheet(
                        engine: engine,
                        report: report,
                        resumeSpeed: shell.resumeSpeed
                    ) { route in
                        router.go(route)
                    }
                }
            }
            .alert("Couldn't load your save", isPresented: loadFailurePresented) {
                Button("OK") { session.clearLoadFailure() }
            } message: {
                Text(session.loadFailureMessage ?? "")
            }
    }

    private func tabs(engine: GameEngine) -> some View {
        TabView(selection: Binding(get: { router.tab }, set: { router.tab = $0 })) {
            HQScreen(engine: engine) { session.requestOnboarding() }
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
    }

    /// Presented on a first launch with no save, and whenever Settings
    /// asks for a new game. The setter only handles a cancel gesture; the
    /// flow's own buttons clear it through the session.
    private var onboardingPresented: Binding<Bool> {
        Binding(
            get: { session.needsOnboarding },
            set: { presented in
                if !presented { session.cancelOnboarding() }
            }
        )
    }

    /// Presented whenever the engine reports game over. The setter is a
    /// no-op: dismissal happens when "New game" swaps in a fresh engine
    /// whose state has no `gameOver`.
    private var gameOverPresented: Binding<Bool> {
        Binding(
            get: { session.engine.state.gameOver != nil && !session.needsOnboarding },
            set: { _ in }
        )
    }

    /// Launch day: shown once for each product that ships.
    private var launchDayPresented: Binding<Bool> {
        Binding(
            get: { shell.launchDayProductID != nil && session.engine.state.gameOver == nil },
            set: { presented in
                if !presented { shell.launchDayProductID = nil }
            }
        )
    }

    private var weeklyReportPresented: Binding<Bool> {
        Binding(
            get: { shell.showingWeeklyReport },
            set: { shell.showingWeeklyReport = $0 }
        )
    }

    /// The pending offer needing an answer, if any. The setter is a no-op:
    /// dismissal happens when an option's action clears the pending offer
    /// (interactive dismissal is disabled on the sheet).
    private var pendingDecision: Binding<DecisionPrompt?> {
        Binding(
            get: {
                guard session.engine.state.gameOver == nil else { return nil }
                guard shell.launchDayProductID == nil, !shell.showingWeeklyReport else { return nil }
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
