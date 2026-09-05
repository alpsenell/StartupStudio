import SwiftUI
import TycoonContent
import TycoonEngine
import TycoonSave
import XCTest

@testable import StartupStudio

/// Iteration 7 (R1): the tour's nine beats against fixture states, the
/// start condition, the exit, the rail's ordering, the ship beat's
/// silence, and the card's picture.
@MainActor
final class TutorialScriptTests: XCTestCase {
    private var directory: URL!
    private var savedCompleted = false
    private var savedTips: Set<String> = []
    private var savedManualOpens = 0
    private var suiteDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TutorialScriptTests-\(UUID().uuidString)", isDirectory: true)
        savedCompleted = GameSettings.tutorialCompleted
        savedTips = GameSettings.dismissedTips
        savedManualOpens = GameSettings.weeklyReportManualOpens
        GameSettings.tutorialCompleted = false
        GameSettings.resetTips()
        // The tour's per-slot bookmark goes into a suite of its own, so a
        // test never reads what a real launch on this simulator left.
        suiteDefaults = UserDefaults(suiteName: "TutorialScriptTests-\(UUID().uuidString)")
        GameSession.tutorialStore = TutorialStore(defaults: suiteDefaults)
    }

    override func tearDown() {
        GameSettings.tutorialCompleted = savedCompleted
        GameSettings.dismissedTips = savedTips
        GameSettings.weeklyReportManualOpens = savedManualOpens
        GameSession.tutorialStore = TutorialStore()
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    // MARK: - Fixtures

    private var content: ContentCatalog { StoryFixtures.content }
    private var balance: BalanceConfig { StoryFixtures.balance }

    private func fresh(day: Int = 0) -> GameState {
        StoryFixtures.newState(day: day)
    }

    private func founder(_ name: String) -> FounderProfile {
        FounderProfile(name: name, archetype: .hacker, appearanceSeed: 0x5EED)
    }

    /// A build with the whole studio on it, `codePts` into the code pool.
    private func building(_ state: inout GameState, codePts: Double) -> Product {
        let type = content.productType("mobile_app")
        let gate = balance.shipCodeThreshold * (type?.codePts ?? 100)
        let product = Product(
            id: UUID(), name: "Nimbus Notes", typeID: "mobile_app", topicID: "productivity",
            stage: .development(DevProgress(
                designPts: gate, codePts: codePts, polishPts: gate / 2,
                openBugs: 0, focus: .balanced, hype: 0
            ))
        )
        state.products.append(product)
        for index in state.employees.indices {
            state.employees[index].assignment = .product(product.id)
        }
        return product
    }

    private var shipGate: Double {
        balance.shipCodeThreshold * (content.productType("mobile_app")?.codePts ?? 100)
    }

    // MARK: - Every predicate

    func testNoBeatIsDoneOnADayZeroCompany() {
        let state = fresh()
        for step in TutorialStep.allCases {
            XCTAssertFalse(TutorialScript.isDone(step, state: state), "\(step) is done on day 0")
        }
    }

    func testTheWelcomeIsNeverDoneByTheState() {
        var state = fresh(day: 400)
        state.employees.append(StoryFixtures.staffer(StoryFixtures.priyaID, "Priya", role: .backend, hiredDay: 5, seed: 21))
        XCTAssertFalse(TutorialScript.isDone(.welcome, state: state), "the welcome ends on the card or the clock, not the state")
    }

    func testNameAProductEndsOnTheFirstProduct() {
        var state = fresh()
        _ = building(&state, codePts: 0)
        XCTAssertTrue(TutorialScript.isDone(.nameAProduct, state: state))
    }

    func testHireEndsOnTheSecondPersonInTheRoom() {
        var state = fresh()
        XCTAssertEqual(state.employees.count, 1, "the founder alone")
        state.employees.append(StoryFixtures.staffer(StoryFixtures.priyaID, "Priya", role: .backend, hiredDay: 5, seed: 21))
        XCTAssertTrue(TutorialScript.isDone(.hire, state: state))
    }

    func testRunTheClockEndsOnDaySeven() {
        XCTAssertFalse(TutorialScript.isDone(.runTheClock, state: fresh(day: 6)))
        XCTAssertTrue(TutorialScript.isDone(.runTheClock, state: fresh(day: 7)))
    }

    func testReadTheWeekEndsOnTheReportClosingAndFallsBackToTheCalendar() {
        XCTAssertTrue(TutorialScript.isDone(.readTheWeek, after: .reportDismissed))
        XCTAssertFalse(TutorialScript.isDone(.readTheWeek, after: .launchDayDismissed))
        XCTAssertFalse(TutorialScript.isDone(.readTheWeek, state: fresh(day: 13)))
        XCTAssertTrue(TutorialScript.isDone(.readTheWeek, state: fresh(day: 14)))
    }

    func testYourEveningsEndsOnAnEveningSpentOrDayFourteen() {
        var state = fresh(day: 8)
        XCTAssertFalse(TutorialScript.isDone(.yourEvenings, state: state))
        state.life.eveningsSpentThisWeek = 1
        XCTAssertTrue(TutorialScript.isDone(.yourEvenings, state: state))
        XCTAssertTrue(TutorialScript.isDone(.yourEvenings, state: fresh(day: 14)))
    }

    func testTheDeskEndsOnAContractOrDayTwentyEight() {
        var state = fresh(day: 15)
        XCTAssertFalse(TutorialScript.isDone(.theDesk, state: state))
        state.activeContracts.append(
            ContractJob(
                id: UUID(), clientName: "Harbour Dental",
                requiredCodePts: 60, requiredDesignPts: 30,
                progressCode: 0, progressDesign: 0,
                deadlineDay: 40, payout: 9_000, penalty: 2_000,
                acceptedDay: 15, requiredSkill: 40,
                skillDaySum: 0, skillDays: 0
            )
        )
        XCTAssertTrue(TutorialScript.isDone(.theDesk, state: state))
        XCTAssertTrue(TutorialScript.isDone(.theDesk, state: fresh(day: 28)))
    }

    func testShipItEndsOnALaunchAndLaunchDayAWeekLater() {
        var state = fresh(day: 60)
        _ = building(&state, codePts: 0)
        XCTAssertFalse(TutorialScript.isDone(.shipIt, state: state))
        state.products = [
            StoryFixtures.released(StoryFixtures.overcastID, "Overcast", typeID: "mobile_app", topicID: "fitness", launchDay: 60, score: 58),
        ]
        XCTAssertTrue(TutorialScript.isDone(.shipIt, state: state))
        XCTAssertFalse(TutorialScript.isDone(.launchDay, state: state), "the reviews are read on the sheet, not the calendar")
        XCTAssertTrue(TutorialScript.isDone(.launchDay, after: .launchDayDismissed))
        state.day = 67
        XCTAssertTrue(TutorialScript.isDone(.launchDay, state: state), "a week on, the beat lets go")
    }

    func testTabsOpenOneBeatAtATimeAndAllFiveByTheDesk() {
        XCTAssertEqual(TutorialScript.tabsOpen(through: .welcome), [.hq])
        XCTAssertEqual(TutorialScript.tabsOpen(through: .nameAProduct), [.hq, .products])
        XCTAssertEqual(TutorialScript.tabsOpen(through: .hire), [.hq, .products, .team])
        XCTAssertEqual(TutorialScript.tabsOpen(through: .readTheWeek), [.hq, .products, .team])
        XCTAssertEqual(TutorialScript.tabsOpen(through: .yourEvenings), [.hq, .products, .team, .life])
        XCTAssertEqual(TutorialScript.tabsOpen(through: .theDesk), TutorialScript.allTabs)
        XCTAssertEqual(TutorialScript.tabsOpen(through: .launchDay), TutorialScript.allTabs)
    }

    // MARK: - The ship beat's silence

    func testTheShipBeatIsSilentUntilTheBuildIsReady() {
        var state = fresh(day: 40)
        _ = building(&state, codePts: 0)
        XCTAssertTrue(TutorialScript.isDormant(.shipIt, state: state, balance: balance, content: content))
        var progress = TutorialProgress(step: .shipIt, openTabs: TutorialScript.allTabs, isDormant: true)
        XCTAssertNil(progress.activeStep, "a dormant beat draws nothing")
        progress.isDormant = false
        XCTAssertEqual(progress.activeStep, .shipIt)

        // Ready: the code pool at the gate with the crew still on it.
        var ready = fresh(day: 40)
        _ = building(&ready, codePts: shipGate)
        XCTAssertEqual(ready.shipETAs(balance: balance, content: content).first?.isReady, true)
        XCTAssertFalse(TutorialScript.isDormant(.shipIt, state: ready, balance: balance, content: content))
        XCTAssertEqual(TutorialScript.beat(for: .shipIt, state: ready).action, .route(.warRoom))

        // Nothing building at all: the beat asks for a build rather than waiting forever.
        let idle = fresh(day: 40)
        XCTAssertFalse(TutorialScript.isDormant(.shipIt, state: idle, balance: balance, content: content))
        XCTAssertEqual(TutorialScript.beat(for: .shipIt, state: idle).action, .route(.newProduct(topicID: nil)))
    }

    func testOnlyTheShipBeatIsEverSilent() {
        var state = fresh(day: 40)
        _ = building(&state, codePts: 0)
        for step in TutorialStep.allCases where step != .shipIt {
            XCTAssertFalse(TutorialScript.isDormant(step, state: state, balance: balance, content: content), "\(step)")
        }
    }

    // MARK: - The start condition

    func testStartsForTheFirstCompanyOnAFreshInstall() {
        let session = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        session.beginNewGame(inSlot: 0)
        session.startNewGame(profile: founder("Mira Okafor"), companyName: "Northgate", difficulty: .normal)
        XCTAssertTrue(session.canStartTour)

        let shell = GameShell()
        session.tourEngineChanged(shell: shell)
        XCTAssertEqual(session.tutorial?.step, .welcome)
        XCTAssertEqual(session.tutorial?.visibleTabs, [.hq])
        XCTAssertTrue(shell.tour === session)
        XCTAssertNotNil(session.engine.eventSink, "the tour observes the engine's events")
    }

    func testDoesNotStartWhenAnotherSlotHoldsASave() {
        let session = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        session.beginNewGame(inSlot: 0)
        session.startNewGame(profile: founder("Mira Okafor"), companyName: "Northgate", difficulty: .normal)
        session.returnToFrontDoor()

        session.beginNewGame(inSlot: 1)
        session.startNewGame(profile: founder("Dev Anand"), companyName: "Rooftop", difficulty: .hard)
        XCTAssertEqual(session.currentSlot, 1)
        XCTAssertFalse(session.canStartTour, "slot 0 holds a save")
        session.tourEngineChanged(shell: GameShell())
        XCTAssertNil(session.tutorial)
    }

    func testDoesNotStartOnceCompletedOrWithALedgerOrForADailyOrACustomCompany() {
        let session = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        session.beginNewGame(inSlot: 0)
        session.startNewGame(profile: founder("Mira Okafor"), companyName: "Northgate", difficulty: .normal)
        XCTAssertTrue(session.canStartTour)

        GameSettings.tutorialCompleted = true
        XCTAssertFalse(session.canStartTour, "seen once is seen")
        GameSettings.tutorialCompleted = false

        session.ledger.runs.append(
            LegacyRun(
                id: UUID(), companyName: "Before", founderName: "Mira", seed: 1,
                origin: .garage, difficulty: .normal, ending: .bankruptcy, day: 200, founderNetWorth: 0
            )
        )
        XCTAssertFalse(session.canStartTour, "a finished company means a returning player")
        session.ledger = .empty

        var daily = session.engine.state
        daily.mode = .daily(day: 100)
        XCTAssertFalse(TutorialEligibility.canStart(
            tutorialCompleted: false, slots: session.slots, currentSlot: 0, ledger: .empty, state: daily
        ))
        var custom = session.engine.state
        custom.mode = .custom
        XCTAssertFalse(TutorialEligibility.canStart(
            tutorialCompleted: false, slots: session.slots, currentSlot: 0, ledger: .empty, state: custom
        ))
        var midRun = session.engine.state
        midRun.day = 30
        XCTAssertFalse(TutorialEligibility.canStart(
            tutorialCompleted: false, slots: session.slots, currentSlot: 0, ledger: .empty, state: midRun
        ), "a save from before the tour existed never sees it")
    }

    // MARK: - Moving and ending

    func testABeatAlreadyDoneIsPassedAndItsTabOpened() {
        let session = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        session.beginNewGame(inSlot: 0)
        session.startNewGame(profile: founder("Mira Okafor"), companyName: "Northgate", difficulty: .normal)
        session.tourEngineChanged(shell: GameShell())
        session.advanceTour(from: .welcome)
        XCTAssertEqual(session.tutorial?.step, .nameAProduct)

        // The player starts a build: the beat ends on the engine's event.
        let events = session.engine.send(.startProduct(typeID: "mobile_app", topicID: "productivity", name: "Nimbus", focus: .balanced))
        XCTAssertFalse(events.isEmpty)
        XCTAssertEqual(session.tutorial?.step, .hire, "the beat passed on the event")
        XCTAssertEqual(session.tutorial?.openTabs, [.hq, .products, .team])
        XCTAssertEqual(GameSession.tutorialStore.load(slot: 0)?.step, .hire, "and the bookmark moved")

        // A save that already satisfies the next beats — a build, a hire,
        // a week gone — resumes past all of them.
        session.returnToFrontDoor()
        var ahead = fresh(day: 7)
        _ = building(&ahead, codePts: 0)
        ahead.employees.append(StoryFixtures.staffer(StoryFixtures.priyaID, "Priya", role: .backend, hiredDay: 5, seed: 21))
        let store = SaveStore<GameState>(directory: directory, currentFormatVersion: 1)
        try? store.save(ahead, appVersion: "test", summary: SaveSummary(state: ahead), slot: 0)
        GameSession.tutorialStore.save(TutorialStore.Saved(step: .nameAProduct, seed: ahead.seed, day: 0), slot: 0)

        let resumed = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        resumed.continueGame()
        resumed.tourEngineChanged(shell: GameShell())
        XCTAssertEqual(resumed.tutorial?.step, .readTheWeek, "three beats already done")
        XCTAssertEqual(resumed.tutorial?.openTabs, [.hq, .products, .team])
    }

    func testSkipWritesTheSixTipIdsAndOpensEveryTab() {
        let session = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        session.beginNewGame(inSlot: 0)
        session.startNewGame(profile: founder("Mira Okafor"), companyName: "Northgate", difficulty: .normal)
        session.tourEngineChanged(shell: GameShell())
        XCTAssertNotNil(session.tutorial)
        XCTAssertFalse(GameSettings.dismissedTips.contains("tip.first_product"))

        session.skipTour()
        XCTAssertEqual(session.tutorial?.isComplete, true)
        XCTAssertEqual(session.tutorial?.visibleTabs, TutorialScript.allTabs)
        XCTAssertTrue(GameSettings.tutorialCompleted, "skipping counts as completing")
        XCTAssertEqual(GameSettings.dismissedTips, Set(CoachTip.all.map(\.id)))
        XCTAssertEqual(CoachTip.all.count, 6)
        XCTAssertNil(GameSession.tutorialStore.load(slot: 0), "the bookmark is gone")
        XCTAssertNil(session.engine.eventSink, "and the tour stops listening")

        // A second company on the same install shows nothing.
        session.returnToFrontDoor()
        session.deleteSlot(0)
        session.beginNewGame(inSlot: 0)
        session.startNewGame(profile: founder("Dev Anand"), companyName: "Rooftop", difficulty: .normal)
        session.tourEngineChanged(shell: GameShell())
        XCTAssertNil(session.tutorial)
    }

    func testProgressResumesForTheSlotAndNotForARefoundedCompany() {
        let first = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        first.beginNewGame(inSlot: 0)
        first.startNewGame(profile: founder("Mira Okafor"), companyName: "Northgate", difficulty: .normal)
        first.tourEngineChanged(shell: GameShell())
        first.advanceTour(from: .welcome)
        first.returnToFrontDoor()
        XCTAssertEqual(GameSession.tutorialStore.load(slot: 0)?.step, .nameAProduct)

        // The next launch picks the slot up where it was.
        let second = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        second.continueGame()
        second.tourEngineChanged(shell: GameShell())
        XCTAssertEqual(second.tutorial?.step, .nameAProduct)
        XCTAssertEqual(second.tutorial?.openTabs, [.hq, .products])

        // A company refounded in the slot is a different seed: the tour starts over.
        second.returnToFrontDoor()
        second.deleteSlot(0)
        second.beginNewGame(inSlot: 0)
        second.startNewGame(profile: founder("Mira Okafor"), companyName: "Northgate II", difficulty: .normal)
        second.tourEngineChanged(shell: GameShell())
        XCTAssertEqual(second.tutorial?.step, .welcome)
    }

    func testTheWeekOneReportOpensForTheTourWhateverTheManualOpensRuleSays() {
        let session = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        session.beginNewGame(inSlot: 0)
        session.startNewGame(profile: founder("Mira Okafor"), companyName: "Northgate", difficulty: .normal)
        let shell = GameShell()
        session.tourEngineChanged(shell: shell)
        session.tutorial = TutorialProgress(step: .readTheWeek, openTabs: TutorialScript.tabsOpen(through: .readTheWeek))
        XCTAssertTrue(session.tourWantsReportOpened(week: 1))
        XCTAssertFalse(session.tourWantsReportOpened(week: 2))

        // The player has opened the report twice by hand: the ordinary
        // rule would leave week 1 on the rail.
        GameSettings.weeklyReportManualOpens = 2
        let saturday = GameEngine.resume(state: fresh(day: 6))
        let sunday = GameEngine.resume(state: fresh(day: 7))
        sunday.setSpeed(.x1)
        shell.rebase(to: saturday)
        shell.dayAdvanced(engine: sunday)
        XCTAssertTrue(shell.showingWeeklyReport, "the tour opened it")
        XCTAssertEqual(GameSettings.weeklyReportManualOpens, 2, "and the counter is untouched")

        // Closing it ends the beat and opens Life.
        shell.showingWeeklyReport = false
        XCTAssertEqual(session.tutorial?.step, .yourEvenings)
        XCTAssertEqual(session.tutorial?.openTabs.contains(.life), true)
        sunday.shutdown()
        saturday.shutdown()
    }

    func testLaunchDayClosingEndsTheTour() {
        let session = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        session.beginNewGame(inSlot: 0)
        session.startNewGame(profile: founder("Mira Okafor"), companyName: "Northgate", difficulty: .normal)
        let shell = GameShell()
        session.tourEngineChanged(shell: shell)
        session.tutorial = TutorialProgress(step: .launchDay, openTabs: TutorialScript.allTabs)

        shell.launchDayProductID = UUID()
        XCTAssertEqual(session.tutorial?.isComplete, false)
        shell.launchDayProductID = nil
        XCTAssertEqual(session.tutorial?.isComplete, true)
        XCTAssertTrue(GameSettings.tutorialCompleted)
    }

    func testARouteIntoATabTheTourHasNotReachedOpensIt() {
        let session = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        session.beginNewGame(inSlot: 0)
        session.startNewGame(profile: founder("Mira Okafor"), companyName: "Northgate", difficulty: .normal)
        session.tourEngineChanged(shell: GameShell())
        XCTAssertEqual(session.tutorial?.visibleTabs, [.hq])
        session.tourReached(.team)
        XCTAssertEqual(session.tutorial?.visibleTabs, [.hq, .team])
    }

    // MARK: - The rail

    func testThePauseLeadsTheTourLineAndTheTourLeadsEverythingElse() {
        let notices: [RailNotice] = [
            .tip(CoachTip.all[0]),
            .report(week: 1),
            .deferred(id: "d", title: "t", daysLeft: 3, category: nil),
            .tour(.nameAProduct),
            .pause(.bankruptcyWarning(day: 30), more: 0),
        ]
        let sorted = notices.sorted { $0.priority < $1.priority }.map(\.id)
        XCTAssertEqual(sorted, ["pause", "tour-1", "deferred-d", "report-1", "tip-\(CoachTip.all[0].id)"])
    }

    func testEveryBeatHasARailLineAndACardThatFit() {
        let state = fresh(day: 10)
        for step in TutorialStep.allCases {
            let beat = TutorialScript.beat(for: step, state: state)
            XCTAssertEqual(beat.step, step)
            XCTAssertFalse(beat.railLine.isEmpty)
            XCTAssertFalse(beat.body.isEmpty)
            XCTAssertFalse(beat.buttonLabel.isEmpty)
            XCTAssertLessThanOrEqual(beat.railLine.count, 96, "\(step)'s rail line is a line, not a paragraph")
        }
        XCTAssertEqual(TutorialScript.railLine(for: .runTheClock, state: state), "Press play. A day is a second.")
    }

    // MARK: - The card's picture

    private var outputDirectory: URL {
        let path = ProcessInfo.processInfo.environment["PIXELKIT_PREVIEW_DIR"]
            ?? NSTemporaryDirectory() + "/startupstudio-previews"
        let url = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func snapshot(
        _ name: String,
        width: CGFloat = 393,
        @ViewBuilder _ content: () -> some View
    ) {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let suffix = style == .light ? "light" : "dark"
            let renderer = ImageRenderer(
                content: content()
                    .frame(width: width)
                    .background(Theme.screenBackground)
                    .environment(\.colorScheme, style == .light ? .light : .dark)
            )
            renderer.scale = 2
            guard let image = renderer.uiImage, let data = image.pngData() else {
                XCTFail("failed to render \(name) (\(suffix))")
                continue
            }
            XCTAssertGreaterThan(data.count, 512, "\(name) (\(suffix)) rendered empty")
            let url = outputDirectory.appendingPathComponent("\(name)_\(suffix).png")
            XCTAssertNoThrow(try data.write(to: url), "could not write \(url.path)")
        }
    }

    func testRendersTheTutorialCard() {
        let state = fresh()
        snapshot("tutorial_card") {
            TutorialCard(beat: TutorialScript.beat(for: .hire, state: state), onAction: {}, onSkip: {})
                .padding(Theme.Spacing.md)
        }
        snapshot("tutorial_card_accessibility") {
            TutorialCard(beat: TutorialScript.beat(for: .nameAProduct, state: state), onAction: {}, onSkip: {})
                .padding(Theme.Spacing.md)
                .environment(\.dynamicTypeSize, .accessibility3)
        }
        snapshot("rail_tour") {
            NoticeRail(engine: GameEngine.resume(state: state), onRoute: { _ in }, fixedQueue: [.tour(.runTheClock)])
                .environment(GameShell())
                .environment(AppRouter())
        }
    }
}
