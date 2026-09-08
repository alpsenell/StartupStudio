import PixelKit
import SwiftUI
import TycoonEngine
import TycoonSave

/// The front door: the office at night, the game's name, Continue for the
/// slot the player was in, New company, and the three slots.
///
/// Shown at every launch, before onboarding and after an ending. Every
/// way into the game leaves through here: Continue closes the door on
/// the current slot, a slot row opens that slot, an empty row or New
/// company opens the new-game flow into a slot. Deleting a slot asks
/// first.
struct TitleScreen: View {
    let session: GameSession

    /// The slot a delete is being confirmed for.
    @State private var slotToDelete: Int?
    /// New company with every slot taken: which one goes.
    @State private var choosingSlotToReplace = false
    /// The content settles in on arrival; Reduce Motion drops the drift.
    @State private var arrived = false
    /// Iteration 7 (R4): the *From a code* sheet.
    @State private var enteringCode = false
    /// Iteration 7 (R3): today's company, while its sheet is up.
    @State private var dailyEntry: DailyEntry?
    /// Iteration 8: the Scenarios room, and a finished scenario's card.
    @State private var showingScenarios = false
    @State private var showingHall = false
    @State private var showingDynasty = false
    @State private var seasonEntry: SeasonEntry?
    @State private var scenarioResult: ScenarioResult?
    // MARK: Iteration 10 — M5 (morning desk)
    /// The desk, while it is up.
    @State private var showingDesk = false
    // MARK: end of Iteration 10 — M5
    // MARK: Iteration 10 — M4 (leagues)
    /// The League sheet, once the table has been gathered.
    @State private var leagueView: LeagueView?
    /// A *Beat my company* link waiting to be taken on or left.
    @State private var challengeOffer: LeagueChallenge?
    /// The comparison a finished challenge owes the player.
    @State private var challengeResult: LeagueChallengeResult?
    // MARK: end of Iteration 10

    var body: some View {
        ScrollView {
            TitleScreenContent(
                scene: scene,
                current: session.currentSummary,
                currentSlot: session.currentSlot,
                slots: session.slots,
                onContinue: {
                    Haptics.tap()
                    Sounds.play(.tap)
                    session.continueGame()
                },
                onNewCompany: newCompany,
                onOpenSlot: { slot in
                    Haptics.tap()
                    Sounds.play(.tap)
                    session.openSlot(slot)
                },
                onDeleteSlot: { slot in slotToDelete = slot },
                // R2: "Slot 2 · updated from iCloud, day 340", when it was.
                notice: session.cloud.titleNotice,
                // Iteration 7: each row is behind its lane's flag in
                // `TitleMenu.Flags`; the closures are the lanes' to fill.
                menu: .make(
                    onDaily: { openDaily(DailyChallenge.today()) },
                    onCustom: { customCompany(code: nil) },
                    onFromCode: { enteringCode = true },
                    onScenarios: { showingScenarios = true },
                    onHall: { showingHall = true },
                    onDynasty: { showingDynasty = true },
                    onSeason: { seasonEntry = session.seasonEntry(for: .current()) },
                    // MARK: Iteration 10 — M5 (morning desk)
                    onDesk: { showingDesk = true },
                    // MARK: end of Iteration 10 — M5
                    // MARK: Iteration 10 — M4 (leagues)
                    onLeague: { openLeague() }
                    // MARK: end of Iteration 10
                ),
                // MARK: Iteration 10 — M5 (morning desk)
                // The desk card over the slots, and the sunrise a long
                // streak earns under the masthead. Both absent until
                // there is a company to have a morning about.
                desk: MorningDeskCard.make(session: session) { showingDesk = true },
                deskFlourish: DeskRewards.hasFlourish(bestStreak: session.ledger.deskBestStreak)
                // MARK: end of Iteration 10 — M5
            )
            .padding(Theme.Spacing.lg)
            .opacity(arrived ? 1 : 0)
            .offset(y: arrived || Theme.Motion.isReduced ? 0 : 12)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Theme.screenBackground.ignoresSafeArea())
        // Iteration 7 (R6): once per install, after the first biography.
        .reviewPromptOnReturn(session: session)
        .onAppear {
            session.refreshSlots()
            withAnimation(Theme.Motion.entrance) { arrived = true }
            // A code that arrived by URL while the door was shut. Not
            // when the flow already has it (`-autoCustom`, a row's tap).
            if session.pendingSeedCode != nil, !session.needsOnboarding { enteringCode = true }
            // Iteration 7 (R3): Game Center authenticates once per launch,
            // from the one screen every launch passes through, and starts
            // mapping the run's events onto achievements. Idempotent.
            session.startGameCenter()
            // Iteration 8: yesterday's ghosts, ahead of today's Play.
            Task { await session.refreshGhosts(forDailyDay: DailyChallenge.today().day) }
            // MARK: Iteration 10 — M4 (leagues)
            // This week's tier, ahead of the League row's Play, and the
            // three things the league can owe the player at the door: a
            // week just scored, a challenge that arrived by link, and a
            // comparison a finished challenge is waiting to show.
            Task { await session.refreshLeagueGhosts(week: LeagueWeek.current().week, tier: session.leagueRecord.tier) }
            if let finished = session.league, finished.score != nil {
                session.league = nil
                openLeague()
            } else if DebugLaunch.opensLeague {
                openLeagueFromLaunchArguments()
            } else if let offer = session.pendingChallenge {
                challengeOffer = offer
            } else if let result = session.challengeResult() {
                challengeResult = result
            }
            // MARK: end of Iteration 10
            // Iteration 8: a scenario just decided shows its card once;
            // `-autoScenario <id>` starts one from here.
            if let result = session.scenarioResult {
                session.scenarioResult = nil
                scenarioResult = result
            } else if DebugLaunch.opensMorningDesk {
                // MARK: Iteration 10 — M5: `-autoDesk` opens the desk over
                // the door, on whatever slot 0 holds.
                showingDesk = true
            } else if DebugLaunch.value(after: "-autoRoom") == "hall" {
                showingHall = true
            } else if DebugLaunch.value(after: "-autoRoom") == "dynasty" {
                showingDynasty = true
            } else if DebugLaunch.value(after: "-autoRoom") == "season" {
                // `-autoRoom season` opens the card; with `-autoSpeed` it
                // plays the season through, like the daily.
                let season = GameSeason.current()
                if ProcessInfo.processInfo.arguments.contains("-autoSpeed") {
                    session.playSeason(season)
                } else {
                    seasonEntry = session.seasonEntry(for: season)
                }
            }
            // A season just scored hands itself back here too.
            if let finished = session.season_, finished.score != nil {
                session.season_ = nil
                seasonEntry = session.seasonEntry(for: finished.season)
            } else if let id = DebugLaunch.launchScenarioID {
                // `-autoScenario room` opens the room; an id plays it.
                if let scenario = ScenarioCatalog.scenario(id) {
                    session.playScenario(scenario)
                } else {
                    showingScenarios = true
                }
            }
            // A daily that has just been scored — the year ran out, or the
            // company ended — hands itself back here, and the result card
            // is the only thing that says so. Shown once.
            if let finished = session.daily, finished.score != nil {
                session.daily = nil
                openDaily(finished.challenge)
            } else if let challenge = DebugLaunch.launchDailyChallenge {
                // `-autoDaily 20260905` lands a headless pass on the card;
                // with a speed as well it plays the day through, which is
                // how the result card is photographed without tapping.
                openDaily(challenge)
                if DebugLaunch.playsDailyAutomatically {
                    dailyEntry = nil
                    session.playDaily(challenge)
                }
            }
        }
        // R4: a code arriving by URL at the front door opens the sheet.
        .onChange(of: session.pendingSeedCode) { _, code in
            if code != nil, !session.needsOnboarding { enteringCode = true }
        }
        // MARK: Iteration 10 — M5 (morning desk)
        .sheet(isPresented: $showingDesk) {
            MorningDeskSheet(
                session: session,
                // From the door, the decision's *Open it* goes back into
                // the company; the section it points at is the HUD's job.
                onOpen: { _ in
                    showingDesk = false
                    session.continueGame()
                },
                isAtFrontDoor: true,
                onClose: { showingDesk = false }
            )
        }
        // MARK: end of Iteration 10 — M5
        .sheet(isPresented: $enteringCode) {
            SeedCodeEntrySheet(prefill: session.pendingSeedCode) { code in
                customCompany(code: code)
            }
        }
        // Iteration 8: the Scenarios room and a finished scenario's card.
        .sheet(isPresented: $showingScenarios) {
            ScenariosSheet(
                entries: session.scenarioEntries(),
                totalStars: session.scenarioLedger.totalStars,
                onPlay: { scenario in
                    showingScenarios = false
                    session.playScenario(scenario)
                },
                onClose: { showingScenarios = false }
            )
        }
        // MARK: Iteration 10 — M4 (leagues)
        .onChange(of: session.pendingChallenge) { _, offer in
            if let offer, !session.needsOnboarding { challengeOffer = offer }
        }
        .sheet(item: $leagueView) { view in
            LeagueSheet(
                view: view,
                challengeText: leagueChallengeText(for: view),
                onPlay: { week in
                    leagueView = nil
                    session.playLeague(week)
                },
                onClose: { leagueView = nil }
            )
        }
        .sheet(item: $challengeOffer) { offer in
            LeagueChallengeSheet(
                challenge: offer,
                onAccept: {
                    challengeOffer = nil
                    if !session.acceptChallenge(offer) { choosingSlotToReplace = true }
                },
                onDecline: {
                    challengeOffer = nil
                    session.declineChallenge(offer)
                }
            )
        }
        .sheet(item: $challengeResult) { result in
            LeagueChallengeResultSheet(result: result) { challengeResult = nil }
        }
        // MARK: end of Iteration 10
        .sheet(item: $seasonEntry) { entry in
            SeasonSheet(
                entry: entry,
                onPlay: { season in
                    seasonEntry = nil
                    session.playSeason(season)
                },
                onClose: { seasonEntry = nil }
            )
        }
        .sheet(isPresented: $showingDynasty) {
            DynastySheet(ledger: session.ledger) { showingDynasty = false }
        }
        .sheet(isPresented: $showingHall) {
            HallOfFameSheet(entries: session.ledger.hall, content: session.engine.content) { showingHall = false }
        }
        .sheet(item: $scenarioResult) { result in
            ScenarioResultSheet(result: result) { scenarioResult = nil }
        }
        // Iteration 7 (R3): today's company — the challenge, the attempt
        // under way, or the result once the day is recorded.
        .sheet(item: $dailyEntry) { entry in
            DailySheet(
                entry: entry,
                onPlay: { challenge in
                    dailyEntry = nil
                    session.playDaily(challenge)
                },
                onClose: { dailyEntry = nil }
            )
        }
        .confirmationDialog(
            "Delete this save?",
            isPresented: deleting,
            titleVisibility: .visible,
            presenting: slotToDelete
        ) { slot in
            Button("Delete \(name(of: slot))", role: .destructive) {
                Haptics.warning()
                session.deleteSlot(slot)
            }
            Button("Keep it", role: .cancel) {}
        } message: { slot in
            Text(deleteMessage(for: slot))
        }
        .confirmationDialog(
            "Every slot is taken",
            isPresented: $choosingSlotToReplace,
            titleVisibility: .visible
        ) {
            ForEach(session.slots) { row in
                Button("Replace \(name(of: row.slot)) in slot \(row.slot + 1)", role: .destructive) {
                    session.beginNewGame(inSlot: row.slot)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Pick the slot the new company takes. Its save goes when the new one starts, not before.")
        }
    }

    /// The current slot's office after hours, or the garage nobody has
    /// moved into yet.
    private var scene: OfficeSceneInput {
        session.hasCurrentGame ? TitleScene.input(for: session.engine.state) : TitleScene.emptyGarage
    }

    // MARK: Iteration 10 — M4 (leagues)

    /// Gathers the week's table — which settles last week's, and so is
    /// where promotion happens — and opens the sheet on it.
    private func openLeague(week: LeagueWeek = .current()) {
        Task {
            leagueView = await session.leagueView(for: week)
        }
    }

    /// The line the result card's *Beat my company* share pastes.
    private func leagueChallengeText(for view: LeagueView) -> String? {
        guard case .result(let week, let entry) = view.entry, let grid = entry.grid, !grid.isEmpty
        else { return nil }
        let challenge = session.challenge(from: entry, week: week)
        guard let link = GameSession.challengeURL(for: challenge)?.absoluteString else { return nil }
        return YearGrid.challengeText(
            title: "STARTUP STUDIO · \(entry.tier.displayName) league, \(week.dateRangeText)",
            strip: grid,
            scoreLine: "\(entry.score.money) · \(entry.headline) on day \(entry.gameDay)",
            link: link
        )
    }

    /// `-autoLeague [demo|challenge|result|<yyyymmdd>]`, and with
    /// `-autoSpeed` as well the week plays itself through.
    private func openLeagueFromLaunchArguments() {
        #if DEBUG
        let week = DebugLaunch.leagueArgument.flatMap(LeagueWeek.fromLaunchArgument) ?? .current()
        if DebugLaunch.seedsLeagueDemoField {
            LeagueDemoField.seed(into: session, week: week, tier: session.leagueRecord.tier)
        }
        if DebugLaunch.opensLeagueChallenge {
            challengeOffer = LeagueChallenge(
                code: week.seedCode,
                grid: YearGrid.letters("🟩🟩🟨🟥🟩🟪🟩🟩⬛🟩🟨🟩🟥🟩🟩🟩🟨🟩🟩🟪🟩🟩🟩"),
                score: 312_400, challenger: "Mira Okafor"
            )
            return
        }
        if DebugLaunch.opensLeagueChallengeResult {
            challengeResult = LeagueChallengeResult(
                challenger: "Mira Okafor", challengerScore: 312_400,
                challengerGrid: YearGrid.letters("🟩🟩🟨🟥🟩🟪🟩🟩⬛🟩🟨🟩🟥🟩🟩🟩🟨🟩🟩🟪🟩🟩🟩"),
                yourScore: 401_900,
                yourGrid: YearGrid.letters("🟩🟩🟩🟨🟩🟪🟩🟥🟩🟩🟨🟩🟩🟩🟩⬛🟨🟩🟩🟩🟩🟩🟨"),
                companyName: "Northgate Softworks"
            )
            return
        }
        if ProcessInfo.processInfo.arguments.contains("-autoSpeed") {
            session.playLeague(week)
        } else {
            openLeague(week: week)
        }
        #endif
    }

    // MARK: end of Iteration 10

    /// Iteration 7 (R3): opens today's company on whatever it is now —
    /// a challenge, an attempt to resume, or the day's result.
    private func openDaily(_ challenge: DailyChallenge) {
        dailyEntry = session.dailyEntry(for: challenge)
    }

    /// New company goes into the first empty slot; with none, the player
    /// picks which save it replaces.
    private func newCompany() {
        Haptics.tap()
        Sounds.play(.tap)
        // R4: the plain path never opens on the custom page.
        session.clearCustomGameRequest()
        if let empty = session.slots.first(where: \.isEmpty) {
            session.beginNewGame(inSlot: empty.slot)
        } else {
            choosingSlotToReplace = true
        }
    }

    /// R4: *Custom company*, or *From a code* with the code: the flow
    /// opens on the custom page. With every slot taken the request stays
    /// parked and the replace dialog's `beginNewGame` picks it up.
    private func customCompany(code: SeedCode?) {
        if !session.beginCustomGame(code: code) {
            choosingSlotToReplace = true
        }
    }

    private var deleting: Binding<Bool> {
        Binding(
            get: { slotToDelete != nil },
            set: { presented in if !presented { slotToDelete = nil } }
        )
    }

    private func name(of slot: Int) -> String {
        guard let row = session.slots.first(where: { $0.slot == slot }) else { return String(localized: "slot \(slot + 1)", comment: "Stand-in name for a save slot with nothing in it, used inside a sentence") }
        switch row.contents {
        case .saved(let summary, _): return summary.companyName
        case .corrupt: return String(localized: "the damaged save", comment: "Stand-in name for a save file that could not be read, used inside a sentence")
        case .futureFormat: return String(localized: "the newer save", comment: "Stand-in name for a save written by a newer app version, used inside a sentence")
        case .empty: return String(localized: "slot \(slot + 1)", comment: "Stand-in name for a save slot with nothing in it, used inside a sentence")
        }
    }

    private func deleteMessage(for slot: Int) -> String {
        guard let summary = session.slots.first(where: { $0.slot == slot })?.summary else {
            return String(localized: "Slot \(slot + 1) is cleared. This can\'t be undone.", comment: "Confirmation message for deleting an empty save slot")
        }
        return String(localized: "Slot \(slot + 1): \(summary.companyName), \(summary.founderName), day \(summary.day). This can\'t be undone.", comment: "Confirmation message for deleting a save: slot number, company, founder and the day reached")
    }
}

// MARK: - Content

/// The title screen as one column, without the scroll view, so the
/// snapshot suite can draw it (`ImageRenderer` draws nothing inside a
/// `ScrollView`) and so it is a function of plain values, not a session.
struct TitleScreenContent: View {
    let scene: OfficeSceneInput
    /// The current slot's game, for the Continue card; `nil` when the
    /// slot is empty.
    let current: SaveSummary?
    let currentSlot: Int
    let slots: [SlotSummary]
    var onContinue: () -> Void = {}
    var onNewCompany: () -> Void = {}
    var onOpenSlot: (Int) -> Void = { _ in }
    var onDeleteSlot: (Int) -> Void = { _ in }
    /// R2: one line under the masthead when a slot came in from iCloud;
    /// nothing when `nil`.
    var notice: String? = nil
    /// Iteration 7: the rows under New company. Nothing is drawn while
    /// every row is off.
    var menu: TitleMenu = TitleMenu()
    // MARK: Iteration 10 — M5 (morning desk)
    /// The desk card, over the slots; nothing when there is no game.
    var desk: MorningDeskCard? = nil
    /// Whether a 30-day streak has earned the sunrise under the masthead.
    var deskFlourish: Bool = false
    // MARK: end of Iteration 10 — M5

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            hero
            masthead
            if let notice {
                Label(notice, systemImage: "icloud.and.arrow.down")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(notice)
            }
            if let current {
                ContinueCard(summary: current, action: onContinue)
            }
            // MARK: Iteration 10 — M5 (morning desk)
            if let desk { desk }
            // MARK: end of Iteration 10 — M5
            newCompanyButton
            TitleMenuView(menu: menu)
            SlotList(
                slots: slots,
                currentSlot: current == nil ? nil : currentSlot,
                onOpen: onOpenSlot,
                onDelete: onDeleteSlot
            )
        }
    }

    /// The office after hours, in the pixel frame every scene card has.
    private var hero: some View {
        PixelPanel(contentPadding: Theme.Spacing.sm) {
            OfficeSceneView(input: scene)
                .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            scene.occupants.isEmpty
                ? "An empty garage at night"
                : "The \(scene.tier.rawValue) at night, \(scene.occupants.count) at their desks"
        )
    }

    /// The name in the game's own hand, at the largest scale the width
    /// takes, and the line under it.
    private var masthead: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ViewThatFits(in: .horizontal) {
                PixelText(text: "Startup Studio", scale: 4, color: Theme.pixelAccent)
                PixelText(text: "Startup Studio", scale: 3, color: Theme.pixelAccent)
            }
            // MARK: Iteration 10 — M5 (morning desk): the sunrise a
            // month of mornings earns. Cosmetic, and only ever here.
            if deskFlourish {
                PixelText(
                    text: String(localized: "- SUNRISE -", comment: "Bitmap flourish under the game's name on the title screen, earned by a month of morning-desk streaks. Uppercase: the pixel face has no lowercase"),
                    scale: 1,
                    color: Theme.pixelAccent.opacity(0.8)
                )
                    .accessibilityLabel("Sunrise masthead, earned at the morning desk")
            }
            // MARK: end of Iteration 10 — M5
            Text(current == nil
                 ? "Two people in a garage, one laptop, and a name to defend."
                 : "The lights are still on.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .padding(.vertical, Theme.Spacing.xs)
    }

    /// Prominent on a fresh install, where it is the only way in; beside
    /// Continue it steps back.
    @ViewBuilder
    private var newCompanyButton: some View {
        let label = Label("New company", systemImage: "plus")
            .font(.system(.headline, design: .rounded))
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.xs)
        let hint = slots.contains(where: \.isEmpty)
            ? "Starts the new-game flow in an empty slot"
            : "Every slot is taken; you choose which one to replace"
        if current == nil {
            Button(action: onNewCompany) { label }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .accessibilityHint(hint)
        } else {
            Button(action: onNewCompany) { label }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
                .accessibilityHint(hint)
        }
    }
}

// MARK: - Continue

/// The game the player was in: the founder's face, the company in pixel
/// caps, the founder, the day and chapter — or the ending — and the one
/// button that goes back in.
private struct ContinueCard: View {
    let summary: SaveSummary
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        portrait
                        facts
                    }
                } else {
                    HStack(alignment: .top, spacing: Theme.Spacing.md) {
                        portrait
                        facts
                    }
                }
                Button(action: action) {
                    Label(
                        summary.endingKind == nil ? "Continue" : "Read the ending",
                        systemImage: summary.endingKind == nil ? "play.fill" : "book.fill"
                    )
                    .font(.system(.headline, design: .rounded))
                }
                .buttonStyle(PixelButtonStyle())
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var portrait: some View {
        PixelPortrait(seed: summary.founderAppearanceSeed ?? 0, isFounder: true, size: 56)
    }

    private var facts: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            PixelCompanyName(name: summary.companyName)
            Text(summary.founderName)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.pixelInk)
            Text(whereItStands)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(Theme.pixelInk.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "Day 214 · Chapter 3 · The loft", or the ending when the run is over.
    private var whereItStands: String {
        var parts = ["Day \(summary.day)"]
        if let ending = summary.endingKind {
            parts.append(ending.headline)
        } else if let epilogue = summary.epilogueKind {
            // Iteration 7 (R5): a company running past its own ending says
            // so on the door, the way the biography does.
            parts.append("\(epilogue.epilogueNoun) · still running")
        } else if let chapter = summary.chapter {
            var line = "Chapter \(chapter)"
            if let title = summary.chapterTitle, !title.isEmpty { line += " · \(title)" }
            parts.append(line)
        }
        return parts.joined(separator: " · ")
    }

    private var accessibilityLabel: String {
        "\(summary.endingKind == nil ? "Continue" : "Read the ending of") \(summary.companyName), "
            + "\(summary.founderName), \(whereItStands)"
    }
}

// MARK: - Slots

/// The three slots: company, founder, day and ending or "Running" on a
/// saved one; "Empty" on the rest. The current slot is marked. Tapping
/// a row opens it; the trash asks before it deletes.
private struct SlotList: View {
    let slots: [SlotSummary]
    /// The slot the engine is in, when it holds a game.
    let currentSlot: Int?
    let onOpen: (Int) -> Void
    let onDelete: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            PixelSectionTitle(title: String(localized: "Saves", comment: "Bitmap section heading over the three save slots. Uppercased by the pixel face"))
            ForEach(slots) { row in
                SlotRow(
                    row: row,
                    isCurrent: row.slot == currentSlot,
                    onOpen: { onOpen(row.slot) },
                    onDelete: { onDelete(row.slot) }
                )
            }
        }
    }
}

private struct SlotRow: View {
    let row: SlotSummary
    let isCurrent: Bool
    let onOpen: () -> Void
    let onDelete: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button(action: onOpen) {
                // The number, the face and the company sit on one line
                // until the company's name needs the whole width. At the
                // accessibility sizes the row was three ellipses.
                let layout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.sm))
                    : AnyLayout(HStackLayout(spacing: Theme.Spacing.md))
                layout {
                    HStack(spacing: Theme.Spacing.md) {
                        slotNumber
                        if let summary = row.summary {
                            PixelPortrait(seed: summary.founderAppearanceSeed ?? 0, isFounder: true, size: 34)
                        }
                        if typeSize.isAccessibilitySize {
                            Spacer(minLength: 0)
                            trailingIcon
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(row.isEmpty ? .secondary : .primary)
                            .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                            .minimumScaleFactor(0.85)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(detail)
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                            .fixedSize(horizontal: false, vertical: true)
                        if let footnote {
                            Text(footnote)
                                .font(.caption2.weight(isCurrent ? .semibold : .regular))
                                .foregroundStyle(isCurrent ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.tertiary))
                                .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if !typeSize.isAccessibilitySize {
                        Spacer(minLength: 0)
                        trailingIcon
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressableRow)
            .disabled(!isOpenable)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(hint)

            if !row.isEmpty {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.body)
                        .frame(width: 28, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .tint(Theme.negativeCash)
                .accessibilityLabel("Delete slot \(row.slot + 1)")
            }
        }
        .padding(Theme.Spacing.md)
        .background(
            isCurrent ? Theme.accent.opacity(0.10) : Theme.cardBackground,
            in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
        )
    }

    /// The mark at the end of the row: the tick on the game you are in,
    /// the plus on an empty slot, the chevron on anything else.
    @ViewBuilder
    private var trailingIcon: some View {
        if isCurrent {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.accent)
        } else if row.isEmpty {
            Image(systemName: "plus.circle")
                .foregroundStyle(.tertiary)
        } else if row.summary != nil {
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    /// "Current · Played an hour ago", or just when it was played.
    private var footnote: String? {
        var parts: [String] = []
        if isCurrent { parts.append(String(localized: "Current", comment: "Footnote on the save slot the player is in right now")) }
        if let lastPlayed = row.lastPlayed {
            parts.append(String(localized: "Played \(Self.relative.localizedString(for: lastPlayed, relativeTo: Date()))", comment: "Footnote on a save slot: when it was last opened, as a relative date"))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .full
        return formatter
    }()

    /// The slot's number in the pixel face, on its own small tile.
    private var slotNumber: some View {
        PixelText(text: "\(row.slot + 1)", scale: 2, color: Theme.pixelInk)
            .frame(width: 28, height: 28)
            .background(Theme.pixelPaper)
            .overlay {
                PixelPanelBorder(thickness: 2, corner: 2)
                    .fill(Theme.pixelInk)
            }
            .accessibilityHidden(true)
    }

    private var isOpenable: Bool {
        switch row.contents {
        case .empty, .saved: true
        case .corrupt, .futureFormat: false
        }
    }

    private var title: String {
        switch row.contents {
        case .empty: String(localized: "Empty", comment: "Save slot title: nothing saved here")
        case .saved(let summary, _): summary.companyName
        case .corrupt: String(localized: "Damaged save", comment: "Save slot title: the file could not be decoded")
        case .futureFormat: String(localized: "Needs a newer app", comment: "Save slot title: written by a newer version of the game")
        }
    }

    private var detail: String {
        switch row.contents {
        case .empty:
            String(localized: "Start a company here", comment: "Save slot detail line for an empty slot")
        case .saved(let summary, _):
            String(localized: "\(summary.founderName) · Day \(summary.day) · \(summary.endingKind?.headline ?? String(localized: "Running", comment: "Save slot state: the company has not ended yet"))", comment: "Save slot detail: founder, day reached, and how the run ended or that it is still going")
        case .corrupt:
            String(localized: "The file couldn\'t be read. Delete it to free the slot.", comment: "Save slot detail for a corrupt file")
        case .futureFormat(let version):
            String(localized: "Saved by a newer version (format \(version)).", comment: "Save slot detail for a save from a newer app version")
        }
    }

    private var accessibilityLabel: String {
        "Slot \(row.slot + 1), \(title). \(detail)"
            + (isCurrent ? ". Current game" : "")
    }

    private var hint: String {
        switch row.contents {
        case .empty: String(localized: "Starts a new company in this slot", comment: "Spoken hint on an empty save slot")
        case .saved: isCurrent ? String(localized: "Continues this game", comment: "Spoken hint on the save slot the player is in") : String(localized: "Opens this game", comment: "Spoken hint on a save slot the player is not in")
        case .corrupt, .futureFormat: ""
        }
    }
}

// MARK: - Previews

#Preview("With a save") {
    let engine = GameEngine.newGame(
        companyName: "Northgate Softworks", seed: 4242,
        founder: FounderProfile(name: "Mira Okafor", archetype: .hacker, appearanceSeed: 0x5EED)
    )
    let summary = SaveSummary(state: engine.state)
    return ScrollView {
        TitleScreenContent(
            scene: TitleScene.input(for: engine.state),
            current: summary,
            currentSlot: 0,
            slots: [
                SlotSummary(slot: 0, contents: .saved(
                    summary: summary,
                    envelope: SaveEnvelope(formatVersion: 1, savedAt: Date(), appVersion: "0.1.0", summary: summary)
                )),
                SlotSummary(slot: 1, contents: .empty),
                SlotSummary(slot: 2, contents: .corrupt),
            ]
        )
        .padding()
    }
    .background(Theme.screenBackground)
}

#Preview("Fresh install") {
    ScrollView {
        TitleScreenContent(
            scene: TitleScene.emptyGarage,
            current: nil,
            currentSlot: 0,
            slots: (0..<3).map { SlotSummary(slot: $0, contents: .empty) }
        )
        .padding()
    }
    .background(Theme.screenBackground)
}
