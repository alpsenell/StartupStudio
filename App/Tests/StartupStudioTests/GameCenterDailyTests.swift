import Foundation
import TycoonContent
import TycoonEngine
import TycoonSave
import XCTest

@testable import StartupStudio

/// R3: what the game reports to Game Center, and what the daily does with
/// its own store, its horizon and its one attempt a day.
///
/// Game Center itself cannot authenticate on a simulator with no account,
/// so everything here runs against `NoopGameCenter` — which is exactly
/// what a signed-out player gets, and the reason the protocol exists.
@MainActor
final class GameCenterDailyTests: XCTestCase {
    private var directory: URL!
    private var noop: NoopGameCenter!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("R3-\(UUID().uuidString)", isDirectory: true)
        noop = NoopGameCenter()
        noop.isAuthenticated = true
        GameCenterHub.install(noop)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        GameCenterHub.reset()
        super.tearDown()
    }

    // MARK: - The id table

    func testTheIdTableIsTheFortyEightAchievementsAndEightBoardsTheOwnerCreates() throws {
        let content = try ContentCatalog.loadBundled()
        let goals = GameCenterCatalog.goalAchievements(content: content)
        XCTAssertEqual(goals.count, 42, "one achievement per goal in Goals.json")
        XCTAssertEqual(GameCenterCatalog.endingAchievements.count, 6)
        XCTAssertEqual(GameCenterCatalog.achievements(content: content).count, 48)

        XCTAssertEqual(goals.first?.id, "com.alpsenel.startupstudio.goal.g1_name_a_product")
        XCTAssertTrue(goals.contains { $0.id == "com.alpsenel.startupstudio.goal.g1_ship_it" })
        XCTAssertTrue(goals.contains { $0.id == "com.alpsenel.startupstudio.goal.g4i_marry" })
        XCTAssertTrue(goals.allSatisfy { $0.points == 10 })
        XCTAssertTrue(GameCenterCatalog.endingAchievements.allSatisfy { $0.points == 50 })
        // The doc's budget: 420 + 300 of the 1,000 Game Center allows.
        let points = GameCenterCatalog.achievements(content: content).reduce(0) { $0 + $1.points }
        XCTAssertEqual(points, 720)

        XCTAssertEqual(
            GameCenterCatalog.endingAchievements.map(\.id),
            [
                "com.alpsenel.startupstudio.ending.bankruptcy",
                "com.alpsenel.startupstudio.ending.acquired",
                "com.alpsenel.startupstudio.ending.ipo",
                "com.alpsenel.startupstudio.ending.oustedByBoard",
                "com.alpsenel.startupstudio.ending.soldUp",
                "com.alpsenel.startupstudio.ending.independent",
            ]
        )

        XCTAssertEqual(
            GameCenterCatalog.leaderboards.map(\.id),
            [
                "com.alpsenel.startupstudio.lb.ipo_days.easy",
                "com.alpsenel.startupstudio.lb.ipo_days.normal",
                "com.alpsenel.startupstudio.lb.ipo_days.hard",
                "com.alpsenel.startupstudio.lb.still_yours_net_worth.easy",
                "com.alpsenel.startupstudio.lb.still_yours_net_worth.normal",
                "com.alpsenel.startupstudio.lb.still_yours_net_worth.hard",
                "com.alpsenel.startupstudio.lb.tenure_days",
                "com.alpsenel.startupstudio.lb.daily",
                // Iteration 8: the weekly scenario and the stakes ladder.
                "com.alpsenel.startupstudio.lb.scenario",
                "com.alpsenel.startupstudio.lb.season",
                "com.alpsenel.startupstudio.lb.stakes",
            ]
        )
        let daily = try XCTUnwrap(GameCenterCatalog.leaderboards.first { $0.id.hasSuffix(".daily") })
        XCTAssertTrue(daily.isRecurring, "lb.daily recurs")
        XCTAssertEqual(GameCenterCatalog.leaderboards.filter(\.isRecurring).count, 3, "the daily, the weekly scenario, the season")
        XCTAssertEqual(
            GameCenterCatalog.leaderboards.first { $0.id.hasSuffix("ipo_days.normal") }?.sort,
            .ascending
        )
    }

    // MARK: - The mapping

    /// Every ending, at every difficulty, ranked and unranked.
    func testEveryEndingAtEveryDifficultyReportsTheRightIds() throws {
        for difficulty in Difficulty.allCases {
            let engine = company(difficulty: difficulty)
            for kind in GameCenterCatalog.endings {
                for ranked in [true, false] {
                    var state = engine.state
                    state.mode = ranked ? .standard : .custom
                    state.day = 300
                    state.gameOver = try endingInfo(kind: kind, day: 300)
                    let reports = GameCenterMapping.reports(
                        for: [.gameOver(day: 300)], state: state, balance: engine.balance
                    )
                    let achievements = reports.compactMap(\.achievement)
                    let boards = reports.compactMap(\.leaderboard)

                    XCTAssertEqual(
                        achievements, ["com.alpsenel.startupstudio.ending.\(kind.rawValue)"],
                        "\(kind) \(difficulty) ranked=\(ranked)"
                    )
                    // The tenure board takes any ending in any mode; the
                    // fixture has hires, so it is always there.
                    XCTAssertTrue(
                        boards.contains("com.alpsenel.startupstudio.lb.tenure_days"),
                        "\(kind) \(difficulty) ranked=\(ranked)"
                    )
                    let ranking = boards.filter { $0 != "com.alpsenel.startupstudio.lb.tenure_days" }
                    switch (kind, ranked) {
                    case (.ipo, true):
                        XCTAssertEqual(
                            ranking, ["com.alpsenel.startupstudio.lb.ipo_days.\(difficulty.rawValue)"]
                        )
                        XCTAssertEqual(reports.first { $0.leaderboard?.contains("ipo_days") == true }?.score, 300)
                    case (.independent, true):
                        XCTAssertEqual(
                            ranking,
                            ["com.alpsenel.startupstudio.lb.still_yours_net_worth.\(difficulty.rawValue)"]
                        )
                        XCTAssertEqual(
                            reports.first { $0.leaderboard?.contains("still_yours") == true }?.score,
                            state.founderNetWorth(balance: engine.balance)
                        )
                    default:
                        XCTAssertTrue(ranking.isEmpty, "\(kind) ranked=\(ranked) posts no ranked board")
                    }
                }
            }
        }
    }

    func testAGoalCompletedBecomesItsAchievementInEveryMode() {
        let engine = company(difficulty: .normal)
        for mode in [RunMode.standard, .custom, .daily(day: 248)] {
            var state = engine.state
            state.mode = mode
            let reports = GameCenterMapping.reports(
                for: [.goalCompleted(goalID: "g1_ship_it", day: 40)],
                state: state, balance: engine.balance
            )
            XCTAssertEqual(
                reports.compactMap(\.achievement),
                ["com.alpsenel.startupstudio.goal.g1_ship_it"], "\(mode)"
            )
        }
    }

    func testTheTenureBoardSkipsAFounderWhoNeverHiredAnyone() throws {
        let engine = company(difficulty: .normal)
        var state = engine.state
        state.employees = state.employees.filter(\.isFounder)
        state.day = 200
        state.gameOver = try endingInfo(kind: .bankruptcy, day: 200)
        let reports = GameCenterMapping.reports(
            for: [.gameOver(day: 200)], state: state, balance: engine.balance
        )
        XCTAssertNil(GameCenterMapping.longestTenure(in: state))
        XCTAssertTrue(reports.compactMap(\.leaderboard).isEmpty, "nobody stayed, so nothing to post")
    }

    // MARK: - The queue

    func testReportsQueueWhileSignedOutAndFlushOnAuthentication() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "R3Queue-\(UUID().uuidString)"))
        let queue = GameCenterReportQueue(defaults: defaults, key: "gc.queue")
        let base = NoopGameCenter()
        let client = QueueingGameCenter(base: base, queue: queue)

        client.report(achievement: "com.alpsenel.startupstudio.goal.g1_ship_it")
        client.submit(score: 1_200, to: GameCenterID.daily)
        XCTAssertTrue(base.reportedAchievements.isEmpty, "signed out, nothing reaches GameKit")
        XCTAssertTrue(base.submittedScores.isEmpty)
        XCTAssertEqual(queue.count, 2)

        // A flush while still signed out keeps the queue.
        client.flushQueue()
        XCTAssertEqual(queue.count, 2)

        base.isAuthenticated = true
        client.flushQueue()
        XCTAssertEqual(base.reportedAchievements, ["com.alpsenel.startupstudio.goal.g1_ship_it"])
        XCTAssertEqual(base.submittedScores.map(\.score), [1_200])
        XCTAssertEqual(base.submittedScores.map(\.leaderboard), ["com.alpsenel.startupstudio.lb.daily"])
        XCTAssertEqual(queue.count, 0, "a drained queue never replays twice")

        // Signed in, nothing queues at all.
        client.report(achievement: "com.alpsenel.startupstudio.ending.ipo")
        XCTAssertEqual(queue.count, 0)
        XCTAssertEqual(base.reportedAchievements.count, 2)
        queue.removeAll()
    }

    func testTheQueueIsCappedAtAHundredAndDropsTheOldest() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "R3Cap-\(UUID().uuidString)"))
        let queue = GameCenterReportQueue(defaults: defaults, key: "gc.queue")
        for index in 0..<130 {
            queue.append(.achievement("id-\(index)"))
        }
        XCTAssertEqual(queue.count, GameCenterReportQueue.capacity)
        XCTAssertEqual(queue.reports.first?.achievement, "id-30", "the oldest went")
        XCTAssertEqual(queue.reports.last?.achievement, "id-129")
        queue.removeAll()
        XCTAssertEqual(queue.count, 0)
    }

    // MARK: - The horizon

    func testTheHorizonGateRefusesDay364AndAllowsDay363() {
        let gate = DailyHorizonGate()
        let engine = company(difficulty: .normal)
        var state = engine.state
        state.mode = .daily(day: 248)

        state.day = 363
        XCTAssertTrue(gate.allows(state), "the last day of the year still runs")
        state.day = 364
        XCTAssertFalse(gate.allows(state), "day 364 is the horizon: the clock stops")
        state.day = 400
        XCTAssertFalse(gate.allows(state))

        // A slot's game is not this gate's business.
        state.mode = .standard
        XCTAssertTrue(gate.allows(state))
        XCTAssertEqual(gate.id, "daily")
        XCTAssertEqual(DailyChallenge.horizonDays, 364)
    }

    /// The gate through the real engine: a daily that has reached its
    /// horizon will not take a speed, and one short of it will.
    func testAGatedEngineRefusesToRunAtTheHorizon() {
        let engine = GameEngine.newGame(
            companyName: "Daily", seed: 99, difficulty: .normal, mode: .daily(day: 1)
        )
        engine.advanceGate = { DailyHorizonGate(horizon: 3).allows($0) }
        XCTAssertTrue(engine.mayAdvance, "day 0 of a 3-day horizon runs")
        engine.setSpeed(.x1)
        XCTAssertEqual(engine.state.speed, .x1)
        engine.setSpeed(.paused)

        // At the horizon the same engine refuses every speed but paused,
        // and every action, screen and save still works.
        engine.advanceGate = { DailyHorizonGate(horizon: 0).allows($0) }
        XCTAssertFalse(engine.mayAdvance)
        engine.setSpeed(.x1)
        XCTAssertEqual(engine.state.speed, .paused, "the horizon stopped the clock")
    }

    // MARK: - The daily's own store

    func testPlayingTheDailyNeverTouchesASlot() throws {
        let session = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        session.beginNewGame(inSlot: 0)
        session.startNewGame(
            profile: FounderProfile(name: "Mira Okafor", archetype: .hacker),
            companyName: "Northgate", difficulty: .normal
        )
        let slotBytes = try Data(contentsOf: directory.appendingPathComponent("slot0.json"))
        session.returnToFrontDoor()

        let challenge = DailyChallenge.forDay(248)
        session.playDaily(challenge)

        XCTAssertTrue(session.isDetached, "the daily plays outside the slots")
        XCTAssertFalse(session.isAtFrontDoor)
        XCTAssertEqual(session.engine.state.mode, .daily(day: 248))
        XCTAssertEqual(session.engine.state.seed, challenge.seed)
        XCTAssertEqual(session.engine.state.difficulty, challenge.difficulty)
        XCTAssertEqual(session.engine.state.origin, challenge.origin)
        XCTAssertEqual(session.daily?.challenge, challenge)
        XCTAssertTrue(session.gates.contains { $0.id == "daily" })

        let dailyFile = directory.appendingPathComponent("Daily/slot0.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: dailyFile.path), "the attempt has its own file")
        XCTAssertEqual(
            try Data(contentsOf: directory.appendingPathComponent("slot0.json")), slotBytes,
            "the slot is byte-identical after a daily"
        )

        // Leaving hands the slot's own game back.
        session.returnToFrontDoor()
        XCTAssertFalse(session.isDetached)
        XCTAssertEqual(session.engine.state.company.name, "Northgate")
        XCTAssertTrue(session.hasCurrentGame)
    }

    func testTheYearRunningOutScoresThePostsAndTheLedgerRemembers() {
        let session = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        let challenge = DailyChallenge.forDay(248)
        session.playDaily(challenge)

        var state = session.engine.state
        state.day = DailyChallenge.horizonDays
        state.life.wallet = 41_000
        // The daily's own balance: the engine goes back to the slot's
        // when the run hands itself in, and this run is on the day's
        // difficulty, not the slot's.
        let score = state.founderNetWorth(balance: session.engine.balance)
        // Midnight has not passed: the board's period is still open.
        session.dailyRunChanged(state, now: challenge.date.addingTimeInterval(3_600))
        XCTAssertEqual(noop.submittedScores.map(\.leaderboard), ["com.alpsenel.startupstudio.lb.daily"])
        XCTAssertEqual(noop.submittedScores.first?.score, score)

        let entry = session.dailyResult(forDay: 248)
        XCTAssertEqual(entry?.score, score)
        XCTAssertEqual(entry?.submitted, true)
        XCTAssertNil(entry?.ending, "the year ran out; nothing ended the company")
        XCTAssertEqual(entry?.gameDay, DailyChallenge.horizonDays)
        XCTAssertEqual(entry?.lines.count, 3)
        XCTAssertEqual(entry?.headline, "The year is up")

        // The run handed itself back, and the entry is now the result card.
        XCTAssertTrue(session.isAtFrontDoor)
        XCTAssertFalse(session.isDetached)
        guard case .result(_, let recorded) = session.dailyEntry(for: challenge) else {
            return XCTFail("a recorded day shows its result, not Play")
        }
        XCTAssertEqual(recorded.score, score)

        // One attempt: playing again is refused.
        session.playDaily(challenge)
        XCTAssertTrue(session.isAtFrontDoor, "a finished day cannot be played again")
    }

    func testAnAttemptFinishedAfterMidnightIsNotPosted() {
        let session = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        let challenge = DailyChallenge.forDay(248)
        session.playDaily(challenge)

        var state = session.engine.state
        state.day = DailyChallenge.horizonDays
        // Finished a day and a bit later: the board's period has closed.
        session.dailyRunChanged(state, now: challenge.date.addingTimeInterval(90_000))

        XCTAssertTrue(noop.submittedScores.isEmpty, "a closed period is not posted to")
        let entry = session.dailyResult(forDay: 248)
        XCTAssertEqual(entry?.submitted, false)
        XCTAssertNotNil(entry?.score, "but the attempt is still recorded and still scored")
    }

    func testAnUnfinishedAttemptComesBackAsResume() {
        let session = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        let challenge = DailyChallenge.forDay(248)
        session.playDaily(challenge)
        session.returnToFrontDoor()

        // A second session — the app was killed and relaunched.
        let next = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        guard case .resume(let same, let day) = next.dailyEntry(for: challenge) else {
            return XCTFail("a stored attempt is resumable")
        }
        XCTAssertEqual(same, challenge)
        XCTAssertGreaterThanOrEqual(day, 0)
        next.playDaily(challenge)
        XCTAssertEqual(next.engine.state.mode, .daily(day: 248))
        XCTAssertFalse(next.isAtFrontDoor)

        // Yesterday's attempt is not today's: a different day starts fresh.
        guard case .play = next.dailyEntry(for: DailyChallenge.forDay(249)) else {
            return XCTFail("another day is a new company")
        }
    }

    func testTheDailyIsTheSameCompanyEverywhereAndIsRanked() {
        let challenge = DailyChallenge.forDay(248)
        let first = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        first.playDaily(challenge)
        let other = directory.appendingPathComponent("second", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: other) }
        let second = GameSession(saveDirectory: other, slot: 0, remembersSlot: false)
        second.playDaily(challenge)

        XCTAssertEqual(first.engine.state.company.name, second.engine.state.company.name)
        XCTAssertEqual(
            first.engine.state.progression.founder.name,
            second.engine.state.progression.founder.name
        )
        XCTAssertEqual(first.engine.state.seed, second.engine.state.seed)
        XCTAssertTrue(first.engine.state.isRanked, "a daily is a ranked run: no heirloom, no custom rules")
    }

    // MARK: - The launch flag

    func testAutoDailyParsesAUTCDate() {
        // 2026-09-05 is 247 days after 2026-01-01.
        XCTAssertEqual(DailyChallenge.dayNumber(fromLaunchArgument: "20260905"), 247)
        XCTAssertEqual(DailyChallenge.dayNumber(fromLaunchArgument: "20260101"), 0)
        XCTAssertEqual(
            DailyChallenge.fromLaunchArgument("20260905"), DailyChallenge.forDay(247)
        )
        XCTAssertNil(DailyChallenge.dayNumber(fromLaunchArgument: "2026-09-05"))
        XCTAssertNil(DailyChallenge.dayNumber(fromLaunchArgument: "20261301"), "no thirteenth month")
        XCTAssertNil(DailyChallenge.dayNumber(fromLaunchArgument: "20260231"), "no 31 February")
        XCTAssertNil(DailyChallenge.dayNumber(fromLaunchArgument: "nope"))
    }

    func testTheDateTheWorldIsPlayingReadsInUTC() {
        XCTAssertEqual(DailyChallenge.forDay(247).dateText, "Saturday, 5 September 2026")
        XCTAssertEqual(DailyChallenge.forDay(0).dateText, "Thursday, 1 January 2026")
    }

    // MARK: - Fixtures

    /// A company a season in, with hires on the payroll.
    private func company(difficulty: Difficulty) -> GameEngine {
        let fresh = GameEngine.newGame(
            companyName: "Northgate Softworks", seed: 4242, difficulty: difficulty,
            founder: FounderProfile(name: "Mira Okafor", archetype: .hacker, appearanceSeed: 0x5EED)
        )
        var state = fresh.state
        for _ in 0..<60 { _ = Reducer.tick(&state, balance: fresh.balance, content: fresh.content) }
        state.employees.append(StoryFixtures.staffer(
            UUID(), "Devi Raman", role: .backend, hiredDay: 12, seed: 0x1234
        ))
        return GameEngine(state: state, balance: fresh.balance, content: fresh.content)
    }

    /// `GameOverInfo`'s memberwise init is internal to the engine; its
    /// `Decodable` one is not, so a fixture ending is decoded.
    private func endingInfo(kind: EndingKind, day: Int) throws -> GameOverInfo {
        let json = #"{"day": \#(day), "reason": "a fixture ending", "kind": "\#(kind.rawValue)"}"#
        return try JSONDecoder().decode(GameOverInfo.self, from: Data(json.utf8))
    }
}
