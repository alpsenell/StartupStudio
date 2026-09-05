import SwiftUI
import TycoonEngine

/// Root of the app: the front door (U7's title screen with the save
/// slots) or the game — the tab bar, the acknowledgement layer (toasts,
/// launch day, weekly report), the game-over cover — with the new-game
/// flow and the one-time load-failure notice over either.
///
/// The persistent top HUD is NOT attached here. Each tab's root screen
/// attaches it inside its own `NavigationStack` (see `TopHUD`), so that
/// pinned content in the stack root sits below the HUD and pushed
/// destinations get a regular navigation bar with Back instead.
struct AppRootView: View {
    let session: GameSession

    /// Cross-tab navigation, read by every screen. Starts on WS-F's
    /// `GameTab.launchTab`, which is `.hq` except under the DEBUG
    /// `-autoTab` flag a headless screenshot pass uses.
    @State private var router = AppRouter(tab: .launchTab)
    /// Toasts, the weekly-report loop, and the launch-day moment.
    @State private var shell = GameShell.shared

    var body: some View {
        let engine = session.engine
        // U7: the front door in front of the game. The title screen and
        // the tabs swap at the root, so leaving for the door tears the
        // game's covers down and coming back re-presents whichever one
        // the engine's state calls for.
        ZStack {
            if session.isAtFrontDoor {
                TitleScreen(session: session)
                    .transition(Theme.Motion.transition(.opacity))
            } else {
                game(engine: engine)
                    .transition(Theme.Motion.transition(.opacity))
            }
        }
        .animation(Theme.Motion.entrance, value: session.isAtFrontDoor)
        .environment(\.gameSession, session)
        // Iteration 7 (R6): the gate on the clock and the store's answer,
        // once, for the app's life.
        .task { session.installUnlock() }
        // The new-game flow is opened from the front door, into the slot
        // the player picked there; cancelling goes back to the door.
        .fullScreenCover(isPresented: onboardingPresented) {
            NewGameFlow(
                content: engine.content,
                onStart: { profile, companyName, difficulty, origin in
                    session.startNewGame(
                        profile: profile, companyName: companyName, difficulty: difficulty,
                        origin: origin
                    )
                    shell.rebase(to: session.engine)
                    router.tab = .hq
                },
                onCancel: { session.cancelOnboarding() }
            )
            .interactiveDismissDisabled()
        }
        .alert("Couldn't load your save", isPresented: loadFailurePresented) {
            Button("OK") { session.clearLoadFailure() }
        } message: {
            Text(session.loadFailureMessage ?? "")
        }
    }

    /// The game itself: the tabs and every layer that sits over them.
    private func game(engine: GameEngine) -> some View {
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
            // Iteration 7 (R6): Continue on a gated save brings the paywall
            // back; the clock stopping (the gate refusing a tick) brings it
            // up a beat later, after the chapter's own line has landed.
            .onAppear { session.reconsiderPaywall() }
            .onChange(of: engine.state.speed) { _, speed in
                guard speed == .paused else { return }
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    session.reconsiderPaywall()
                }
            }
            .sheet(isPresented: paywallPresented) {
                PaywallSheet(session: session)
            }
            // The weekly report yields to a decision sheet, and its "Next
            // week" button resumes the clock before it closes. A question
            // that was waiting behind the report must stop the clock
            // again, or days tick behind a modal nobody can dismiss.
            .onChange(of: shell.showingWeeklyReport) { _, showing in
                guard !showing, engine.state.speed != .paused,
                      let prompt = currentPrompt(), prompt.id != shell.deferredChoiceID
                else { return }
                engine.setSpeed(.paused)
            }
            // Toasts are no longer overlaid here: the notice rail under
            // each tab's HUD shows the newest one as its transient line,
            // so an acknowledgement can never land across the pause
            // reason or the report chip.
            .fullScreenCover(isPresented: gameOverPresented) {
                if let info = engine.state.gameOver {
                    // WS-F: four endings now, graded by `EndingKind.isSuccess`
                    // rather than one named case, and both screens are thin
                    // wrappers on the founder biography, so they take the
                    // engine and hand back the founder to play again as.
                    if info.kind.isSuccess {
                        GameWonView(
                            engine: engine, info: info,
                            onNewGame: { difficulty, founder, origin in
                                session.startNewGame(difficulty: difficulty, founder: founder, origin: origin)
                            },
                            onReplay: { session.replayCurrentGame() }
                        )
                    } else {
                        GameOverView(
                            engine: engine, info: info,
                            onNewGame: { difficulty, founder, origin in
                                session.startNewGame(difficulty: difficulty, founder: founder, origin: origin)
                            },
                            onReplay: { session.replayCurrentGame() }
                        )
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
                .badge(EmployeeStatus.attentionCount(in: engine.state, balance: engine.balance, content: engine.content))
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

    /// Iteration 7 (R6): the paywall yields to every other sheet — a
    /// question, launch day, the report — and comes up when they are down.
    /// Pulling it down is "Not now".
    private var paywallPresented: Binding<Bool> {
        Binding(
            get: {
                session.unlock.isPresentingPaywall
                    && session.engine.state.gameOver == nil
                    && !shell.showingWeeklyReport
                    && shell.launchDayProductID == nil
                    && pendingDecision.wrappedValue == nil
            },
            set: { presented in
                if !presented { session.dismissPaywall() }
            }
        )
    }

    private var weeklyReportPresented: Binding<Bool> {
        Binding(
            get: { shell.showingWeeklyReport },
            set: { shell.showingWeeklyReport = $0 }
        )
    }

    /// The pending offer needing an answer, if any. A story question the
    /// player has put off is not re-presented: it lives on the notice rail
    /// with its countdown until they tap it or the deadline answers. The
    /// setter only sees a pull-down, which is "let me think" for a
    /// deferrable prompt and impossible for the others.
    private var pendingDecision: Binding<DecisionPrompt?> {
        Binding(
            get: {
                guard session.engine.state.gameOver == nil else { return nil }
                guard shell.launchDayProductID == nil, !shell.showingWeeklyReport else { return nil }
                guard let prompt = currentPrompt() else { return nil }
                return prompt.id == shell.deferredChoiceID ? nil : prompt
            },
            set: { newValue in
                guard newValue == nil, let prompt = currentPrompt(),
                      prompt.isDeferrable, shell.deferredChoiceID != prompt.id
                else { return }
                shell.postpone(prompt, engine: session.engine)
            }
        )
    }

    private func currentPrompt() -> DecisionPrompt? {
        DecisionPrompt.pending(
            in: session.engine.state,
            content: session.engine.content,
            balance: session.engine.balance
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
