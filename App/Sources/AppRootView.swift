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
                // R8: the front door takes the same centred column as the
                // game, so an iPad opens on a title screen the size of a
                // title screen rather than a wall of office.
                TitleScreen(session: session)
                    .gameColumn()
                    .transition(Theme.Motion.transition(.opacity))
            } else {
                game(engine: engine)
                    .transition(Theme.Motion.transition(.opacity))
            }
        }
        .animation(Theme.Motion.entrance, value: session.isAtFrontDoor)
        .environment(\.gameSession, session)
        // The new-game flow is opened from the front door, into the slot
        // the player picked there; cancelling goes back to the door.
        .fullScreenCover(isPresented: onboardingPresented) {
            newGameFlow(engine: engine)
                .gameColumn()
        }
        .alert("Couldn't load your save", isPresented: loadFailurePresented) {
            Button("OK") { session.clearLoadFailure() }
        } message: {
            Text(session.loadFailureMessage ?? "")
        }
    }

    /// The onboarding flow, in its own function so the cover above can put
    /// it in the column — a cover is presented at window level, where the
    /// game's own frame does not reach it.
    private func newGameFlow(engine: GameEngine) -> some View {
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

    /// The ending: the founder biography, won or lost. In its own function
    /// for the same reason as `newGameFlow` — a cover is outside the
    /// game's frame, so it takes the column itself.
    ///
    /// WS-F: four endings now, graded by `EndingKind.isSuccess` rather
    /// than one named case, and both screens are thin wrappers on the
    /// founder biography, so they take the engine and hand back the
    /// founder to play again as.
    @ViewBuilder
    private func endingCover(engine: GameEngine) -> some View {
        if let info = engine.state.gameOver {
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

    /// The widest the game's column is ever drawn (R8).
    ///
    /// The iPad runs the phone layout in a centred column rather than a
    /// second design: 640 points is a large phone's width plus a little,
    /// which is as wide as a one-column reading measure wants to be and
    /// exactly what the pixel scenes were drawn for. Everything outside
    /// it is `Theme.screenBackground`, so the letterbox is the game's own
    /// paper rather than a grey gutter. On every iPhone the cap is wider
    /// than the screen and therefore invisible.
    static let maxColumnWidth: CGFloat = 640

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
                endingCover(engine: engine)
                    .gameColumn()
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
                .gameColumn()
                .tabItem { Label("HQ", systemImage: "building.2") }
                .tag(GameTab.hq)

            LifeScreen(engine: engine)
                .gameColumn()
                .tabItem { Label("Life", systemImage: "heart.fill") }
                .tag(GameTab.life)

            TeamScreen(engine: engine)
                .gameColumn()
                .tabItem { Label("Team", systemImage: "person.2.fill") }
                .badge(EmployeeStatus.attentionCount(in: engine.state, balance: engine.balance, content: engine.content))
                .tag(GameTab.team)

            // Products and R&D share one tab (segmented inside) to keep the
            // bar at five tabs.
            ProductsScreen(engine: engine)
                .gameColumn()
                .tabItem { Label("Products", systemImage: "shippingbox.fill") }
                .tag(GameTab.products)

            BusinessScreen(engine: engine)
                .gameColumn()
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

// MARK: - The iPad column (iteration 7, R8)

extension View {
    /// Caps a tab's content at `AppRootView.maxColumnWidth` and centres it
    /// on the game's own paper.
    ///
    /// Applied per tab rather than to the whole `TabView` on purpose: the
    /// tab bar is the system's and wants the screen's full width — capped
    /// with the content, iPadOS runs out of room for the fifth tab and
    /// folds Business behind a chevron. So the chrome is native and
    /// full-width, and only what the player reads is a column.
    ///
    /// On every iPhone the cap is wider than the screen, so this is
    /// `maxWidth: .infinity` with a background nobody can see.
    func gameColumn() -> some View {
        frame(maxWidth: AppRootView.maxColumnWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.screenBackground.ignoresSafeArea())
    }
}
