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
    /// Iteration 8: the speed to go back to after the awards.
    @State private var awardsResumeSpeed: SimSpeed?
    /// Iteration 7 (R4): the biography's share sheet.
    @State private var sharingBiography = false

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
        // Iteration 7 (R4): `-autoCustom [code]` lands on the custom page.
        .task { session.openCustomFlowFromLaunchArguments() }
        // Iteration 7 (R6): the gate on the clock and the store's answer,
        // once, for the app's life.
        .task { session.installUnlock() }
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
                // Iteration 7 (R4): the custom page and its prefill, the
                // ledger's endings for the locks; (R2): the Heirlooms page
                // when the ledger offers something. The heirloom rides in
                // the setup.
                options: session.newGameOptions,
                onStart: { profile, companyName, difficulty, origin, setup in
                    session.startNewGame(
                        profile: profile, companyName: companyName, difficulty: difficulty,
                        origin: origin, setup: setup
                    )
                    shell.rebase(to: session.engine)
                    router.tab = .hq
                },
                onCancel: { session.cancelCustomGame() }
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
            // WS-F: four endings now, graded by `EndingKind.isSuccess`
            // rather than one named case, and both screens are thin
            // wrappers on the founder biography, so they take the engine
            // and hand back the founder to play again as.
            // Iteration 7 (R4): the share button opens the biography card.
            // Iteration 7 (R5): "Keep running it", on the two endings the
            // founder chose for themselves. Sending it clears the game
            // over, which is what dismisses this cover — the binding reads
            // the engine, so there is nothing else to close.
            let actions = BiographyActions(
                onShare: { sharingBiography = true },
                onContinueRunning: canContinue(info) ? {
                    engine.send(.continueAfterEnding)
                } : nil
            )
            if info.kind.isSuccess {
                GameWonView(
                    engine: engine, info: info,
                    onNewGame: { difficulty, founder, origin in
                        session.startNewGame(difficulty: difficulty, founder: founder, origin: origin)
                    },
                    onReplay: { session.replayCurrentGame() },
                    actions: actions
                )
                .sheet(isPresented: $sharingBiography) {
                    ShareCardSheet(card: .biography(engine: engine, info: info))
                }
            } else {
                GameOverView(
                    engine: engine, info: info,
                    onNewGame: { difficulty, founder, origin in
                        session.startNewGame(difficulty: difficulty, founder: founder, origin: origin)
                    },
                    onReplay: { session.replayCurrentGame() },
                    actions: actions
                )
                .sheet(isPresented: $sharingBiography) {
                    ShareCardSheet(card: .biography(engine: engine, info: info))
                }
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
            // Iteration 8: the year's awards, mid-December. The clock
            // pauses under the ceremony and resumes when it closes.
            .onChange(of: shell.pendingAwardsYear) { _, year in
                guard year != nil, engine.state.speed != .paused else { return }
                awardsResumeSpeed = engine.state.speed
                engine.setSpeed(.paused)
            }
            .sheet(item: awardsNight(engine: engine)) { night in
                AwardsNightSheet(night: night, companyName: engine.state.company.name) {
                    shell.pendingAwardsYear = nil
                    if let speed = awardsResumeSpeed {
                        awardsResumeSpeed = nil
                        engine.setSpeed(speed)
                    }
                }
            }
            // Iteration 7 (R5, fix 4): `-autoAnswer` used to start from
            // HQ's own task, so a headless pass launched with
            // `-autoTab business` never answered anything and stopped at
            // the first story question. It belongs to the game, not to a
            // tab: started here, it runs whichever tab the pass opens on.
            .task {
                DebugLaunch.startAutoAnswering(engine: engine)
                // MARK: J5 (announce) — `-autoAnnounce [slip|void]` and
                // `-autoPremium`, whichever tab the pass opens on.
                AnnounceDebug.start(engine: engine)
                // MARK: end J5
                // MARK: J3 (rivals and the market)
                // `-autoRivalMarket`, `-autoPriceWar`, `-autoCopied`.
                RivalMarketDebug.startIfAsked(engine: engine)
                // MARK: end J3
                // Iteration 8: `-autoAwards <year>` shows that year's
                // ceremony at once, for the screenshot pass.
                if let year = DebugLaunch.value(after: "-autoAwards").flatMap(Int.init) {
                    shell.pendingAwardsYear = year
                }
            }
            // The weekly report yields to a decision sheet, and its "Next
            // week" button resumes the clock before it closes. A question
            // that was waiting behind the report must stop the clock
            // again, or days tick behind a modal nobody can dismiss.
            .onChange(of: shell.showingWeeklyReport) { _, showing in
                guard !showing, engine.state.speed != .paused,
                      let prompt = currentPrompt(), !shell.isDeferred(prompt.id) // J6 (queue)
                else { return }
                engine.setSpeed(.paused)
            }
            // MARK: J6 (queue)
            // Past two critical stops in a week the engine lets a question
            // through without stopping the clock (`QueueCap`); its sheet
            // goes straight to the rail, with the deadline that is really
            // counting down.
            .onChange(of: engine.queueHoldCount) { _, _ in
                shell.holdForCap(DecisionPrompt.queue(
                    in: engine.state, content: engine.content, balance: engine.balance
                ))
            }
            .task {
                await QueueDebug.startIfAsked(current: { session.engine }, shell: shell)
            }
            // MARK: end J6
            // Toasts are no longer overlaid here: the notice rail under
            // each tab's HUD shows the newest one as its transient line,
            // so an acknowledgement can never land across the pause
            // reason or the report chip.
            .fullScreenCover(isPresented: gameOverPresented) {
                endingCover(engine: engine)
                    .gameColumn()
            }
            // MARK: Iteration 10 — M3 (incident room)
            // A live product on fire opens its own room, the way the war
            // room is presented — full screen, at window level, over
            // whichever tab the player was on. It stays until the room is
            // closed: the clock is stopped and this *is* the interruption,
            // so there is nothing behind it to go back to.
            .fullScreenCover(isPresented: incidentPresented) {
                IncidentRoomScreen(engine: incidentEngine(engine))
            }
            // The one flag the engine's gate reads: incidents may only be
            // raised once the player has opened the Products tab in this
            // run. A pacing bot and a headless pass never switch tabs, so
            // they never set it and never see an incident.
            .onChange(of: router.tab, initial: true) { _, tab in
                guard tab == .products else { return }
                engine.send(.noticeProductsOpened)
            }
            // The Now card's row asks for the room back after it was put
            // aside; HQ takes the route itself a beat later.
            .onChange(of: router.pendingPush) { _, pending in
                guard pending == .incidentRoom else { return }
                incidentSetAside = nil
            }
            .task {
                #if DEBUG
                if incidentFixtureEngine == nil, let fixture = IncidentDebug.launchEngine() {
                    incidentFixtureEngine = fixture
                }
                #endif
            }
            // MARK: end M3
            // MARK: Iteration 11, wave two — W4 (inside)
            // A sentence is a place, and the place covers the game: full
            // screen, at window level, over whichever tab the player was
            // on, the way the incident room is presented. Unlike that room
            // this one cannot be put aside — the door is locked from the
            // outside and the way out is time — so the cover has no setter
            // and no close button.
            .fullScreenCover(isPresented: insidePresented) {
                InsideScreen(engine: engine)
            }
            .task {
                #if DEBUG
                await InsideDebug.startIfAsked(current: { session.engine })
                #endif
            }
            // MARK: end of Iteration 11, wave two — W4
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

    /// Iteration 7 (R1): the tour introduces the tabs one beat at a time,
    /// so the bar draws only the ones it has reached — all five by the
    /// desk beat, and always all five for anyone not on the tour.
    private func tabs(engine: GameEngine) -> some View {
        let visible = session.tutorial?.visibleTabs ?? TutorialScript.allTabs
        return TabView(selection: Binding(get: { router.tab }, set: { router.tab = $0 })) {
            if visible.contains(.hq) {
                HQScreen(engine: engine) { session.requestOnboarding() }
                    .tutorialCardInset(session: session, engine: engine)
                    .gameColumn()
                    .tabItem { Label("HQ", systemImage: "building.2") }
                    .tag(GameTab.hq)
            }

            if visible.contains(.life) {
                LifeScreen(engine: engine)
                    .tutorialCardInset(session: session, engine: engine)
                    .gameColumn()
                    .tabItem { Label("Life", systemImage: "heart.fill") }
                    // MARK: Iteration 9 — L1 (phone)
                    // Unread texts, the same badge the Team tab wears for
                    // people who need answering.
                    .badge(engine.state.life.phone.unreadCount)
                    // MARK: end L1
                    .tag(GameTab.life)
            }

            if visible.contains(.team) {
                TeamScreen(engine: engine)
                    .tutorialCardInset(session: session, engine: engine)
                    .gameColumn()
                    .tabItem { Label("Team", systemImage: "person.2.fill") }
                    .badge(EmployeeStatus.attentionCount(in: engine.state, balance: engine.balance, content: engine.content))
                    .tag(GameTab.team)
            }

            // Products and R&D share one tab (segmented inside) to keep the
            // bar at five tabs.
            if visible.contains(.products) {
                ProductsScreen(engine: engine)
                    .tutorialCardInset(session: session, engine: engine)
                    .gameColumn()
                    .tabItem { Label("Products", systemImage: "shippingbox.fill") }
                    .tag(GameTab.products)
            }

            if visible.contains(.business) {
                BusinessScreen(engine: engine)
                    .tutorialCardInset(session: session, engine: engine)
                    .gameColumn()
                    .tabItem { Label("Business", systemImage: "briefcase.fill") }
                    .tag(GameTab.business)
            }
        }
        .tutorialTourRoot(session: session, engine: engine)
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
    /// Iteration 7 (R5): the endings a company can be run past. The
    /// reducer is the authority and refuses the rest; this is the same
    /// rule, so the button is not offered where it would do nothing.
    func canContinue(_ info: GameOverInfo) -> Bool {
        (info.kind == .ipo || info.kind == .independent) && session.engine.state.epilogue == nil
    }

    // MARK: Iteration 10 — M3 (incident room)

    /// The room's own engine in DEBUG: `-autoIncident <kind>` plays a
    /// fixture company to a live product and raises one, because a
    /// headless launch has no shipped product to break. Every real launch
    /// gets the session's engine.
    @State private var incidentFixtureEngine: GameEngine?
    /// The incident the player has put aside — closed the room without
    /// closing the incident. Keyed by the day it started and the product,
    /// so a *new* incident opens its own room rather than inheriting the
    /// last one's dismissal. The Now card's row brings it back.
    @State private var incidentSetAside: String?

    private func incidentEngine(_ engine: GameEngine) -> GameEngine {
        incidentFixtureEngine ?? engine
    }

    /// A stable key for the open incident, for `incidentSetAside`.
    private var incidentKey: String? {
        #if DEBUG
        if let incident = incidentFixtureEngine?.state.incident {
            return "\(incident.productID)-\(incident.startedDay)"
        }
        #endif
        guard let incident = session.engine.state.incident else { return nil }
        return "\(incident.productID)-\(incident.startedDay)"
    }

    /// Open for as long as something is on fire and the player has not put
    /// it aside. Unlike the ending's cover this one can be closed — the
    /// incident stays open, the Now card carries it, and the clock stays
    /// stopped until the room is actually finished.
    private var incidentPresented: Binding<Bool> {
        Binding(
            get: {
                guard !session.needsOnboarding, session.engine.state.gameOver == nil,
                      let key = incidentKey
                else { return false }
                return incidentSetAside != key
            },
            set: { presented in
                guard !presented, let key = incidentKey else { return }
                incidentSetAside = key
            }
        )
    }

    // MARK: end M3

    // MARK: Iteration 11, wave two — W4 (inside)

    /// Open for as long as the founder is in a cell. The setter is a
    /// no-op: nothing on the screen dismisses it, and the engine closes it
    /// on the day of the release, the parole or the wall.
    private var insidePresented: Binding<Bool> {
        Binding(
            get: {
                guard !session.needsOnboarding, session.engine.state.gameOver == nil
                else { return false }
                return session.engine.state.prison?.isInside == true
            },
            set: { _ in }
        )
    }

    // MARK: end of Iteration 11, wave two — W4

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
                // MARK: Iteration 9 — L1 (phone)
                shell.deferBeatIfHeadless(prompt, engine: session.engine)
                if GameShell.headlessPassAnswersOnThePhone { return nil }
                // MARK: end L1
                return shell.isDeferred(prompt.id) ? nil : prompt // J6 (queue)
            },
            set: { newValue in
                guard newValue == nil, let prompt = currentPrompt(),
                      prompt.isDeferrable, !shell.isDeferred(prompt.id) // J6 (queue)
                else { return }
                shell.postpone(prompt, engine: session.engine)
            }
        )
    }

    private func currentPrompt() -> DecisionPrompt? {
        // MARK: J6 (queue)
        // The first question in the queue the founder has not put off — a
        // deferred one no longer hides the questions behind it.
        DecisionPrompt.queue(
            in: session.engine.state,
            content: session.engine.content,
            balance: session.engine.balance
        ).first { !shell.isDeferred($0.id) }
        // MARK: end J6
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

// MARK: - Iteration 8: awards night

extension AppRootView {
    /// The ceremony the shell is holding, judged on the live state.
    fileprivate func awardsNight(engine: GameEngine) -> Binding<AwardsNight?> {
        Binding(
            get: {
                guard let year = shell.pendingAwardsYear else { return nil }
                return AwardsJudge.judge(year: year, state: engine.state, content: engine.content)
            },
            set: { night in
                if night == nil { shell.pendingAwardsYear = nil }
            }
        )
    }
}

extension AwardsNight: Identifiable {
    var id: Int { year }
}
