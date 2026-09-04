import PixelKit
import SwiftUI
import TycoonContent
import TycoonEngine
import XCTest

@testable import StartupStudio

/// The rival profile (iteration 6, U3): the history between you compiled
/// from the event log, the acquisition terms the screen explains, the
/// scene's mapping, and the screen for an ordinary rival and for the
/// incumbent, light and dark.
@MainActor
final class RivalProfileSnapshotTests: XCTestCase {
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
                    .padding(Theme.Spacing.lg)
                    .frame(width: width)
                    .background(Theme.screenBackground)
                    .environment(\.colorScheme, style == .light ? .light : .dark)
                    .environment(\.dynamicTypeSize, .large)
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

    // MARK: - The history between you

    func testTheHistoryKeepsOnlyThatRivalsEventsNewestFirst() throws {
        let (engine, rivals, incumbent) = MarketMapSnapshotTests.fixture()
        let parallax = rivals[0]
        let history = RivalHistory.compile(for: parallax.id, state: engine.state, content: engine.content)
        XCTAssertEqual(history.entries.map(\.kind), [
            .challenge, .buyoutWithdrawn, .buyoutOffered, .priceWar, .launch, .copycat, .launch, .arrived,
        ])
        XCTAssertEqual(history.entries.map(\.day), history.entries.map(\.day).sorted(by: >))
        XCTAssertEqual(history.entries.first?.text, "Challenged you in Music with Kite Notes, a 55")
        XCTAssertEqual(history.entries.last?.text, "Parallax entered the scene")
        XCTAssertTrue(history.entries.contains { $0.text == "Started a price war in Music" })
        XCTAssertTrue(history.entries.contains { $0.text == "Offered $240,000 for the company" })
        XCTAssertTrue(history.entries.contains { $0.text == "Cloned your Music play" })
        XCTAssertTrue(history.entries.contains { $0.text == "Launched Harbor Loop into Travel — a 41" })
        XCTAssertEqual(history.summary, "1 price war · 1 challenge open · 1 buyout offer")
        // Ids are the log's own indices, so two entries never collide.
        XCTAssertEqual(Set(history.entries.map(\.id)).count, history.entries.count)

        let meridian = RivalHistory.compile(for: incumbent.id, state: engine.state, content: engine.content)
        XCTAssertEqual(meridian.entries.map(\.kind), [.challenge, .launch, .arrived])
        XCTAssertEqual(meridian.entries.last?.text, "Meridian Works arrived in your best markets, with money to lose")
        XCTAssertNil(meridian.summary?.range(of: "poach"))
    }

    func testTheHistoryNamesPeopleAndJobs() throws {
        let (engine, rivals, _) = MarketMapSnapshotTests.fixture()
        let halcyon = rivals[1]
        let history = RivalHistory.compile(for: halcyon.id, state: engine.state, content: engine.content)
        let founder = try XCTUnwrap(engine.state.employees.first?.name)
        XCTAssertEqual(history.entries.map(\.kind), [.sponsored, .poached, .poachAttempt, .arrived])
        XCTAssertEqual(history.entries[2].text, "Made \(founder) an offer — $1,450/wk")
        XCTAssertEqual(history.entries[1].text, "Hired Dev Anand away from you")
        XCTAssertEqual(history.entries[0].text, "Shipped the Finance app you built for them, at 71")
        XCTAssertEqual(history.summary, "1 poach (1 landed) · 1 job built for them")
    }

    func testTheHistoryFallsBackWhenThePersonHasLeftAndSettlesTheTally() {
        var state = GameState.newGame(companyName: "Fixture", seed: 7, balance: MarketMapSnapshotTests.balance)
        let rivalID = UUID()
        let other = UUID()
        state.eventLog = [
            .poachAttempt(rivalID: rivalID, employeeID: UUID(), offeredWeeklySalary: 900, respondByDay: 9, day: 4),
            .poachAttempt(rivalID: other, employeeID: UUID(), offeredWeeklySalary: 900, respondByDay: 9, day: 5),
            .categoryChallenged(rivalID: rivalID, topicID: "fitness", productName: "X", quality: 60, respondByDay: 50, day: 8),
            .categoryHeld(rivalID: rivalID, topicID: "fitness", day: 50),
            .categoryChallenged(rivalID: rivalID, topicID: "music", productName: "Y", quality: 61, respondByDay: 100, day: 58),
            .categoryLost(rivalID: rivalID, topicID: "music", day: 100),
            .marketBoom(topicID: "fitness", day: 101),
            .incumbentRetreated(rivalID: rivalID, name: "Giant", day: 120),
        ]
        let history = RivalHistory.compile(for: rivalID, state: state, content: MarketMapSnapshotTests.content)
        XCTAssertEqual(history.entries.count, 6, "the other rival's poach and the boom are not theirs")
        XCTAssertEqual(history.entries.last?.text, "Made one of your people an offer — $900/wk")
        XCTAssertEqual(history.entries.first?.text, "Gave up your categories")
        XCTAssertEqual(history.summary, "1 poach · held 1 of 2 challenges")
        XCTAssertEqual(RivalHistory.compile(for: UUID(), state: state, content: MarketMapSnapshotTests.content), .empty)
        XCTAssertNil(RivalHistory.empty.summary)
    }

    // MARK: - The terms and the scene

    func testTheAcquisitionTermsMirrorTheEngineGates() {
        let (engine, rivals, incumbent) = MarketMapSnapshotTests.fixture()
        let balance = engine.balance
        var state = engine.state
        let halcyon = rivals[1]
        let cost = Int((Double(halcyon.valuation(balance: balance)) * balance.rivals.acquirePremium).rounded())

        state.company.cash = cost - 1_000
        let short = RivalAcquisitionTerms(rival: halcyon, state: state, balance: balance)
        XCTAssertEqual(short.cost, cost)
        // A studio a year and a half in with three products is worth more
        // than a 22-strength minnow; only the cash is missing.
        XCTAssertEqual(short.blocker, "Need $1,000 more cash")
        XCTAssertFalse(short.isAffordable)

        state.company.cash = cost
        let ready = RivalAcquisitionTerms(rival: halcyon, state: state, balance: balance)
        XCTAssertNil(ready.blocker)
        XCTAssertTrue(ready.isAffordable)
        XCTAssertEqual(ready.absorbedShelfCount, 0, "a 47 in Finance does not beat the studio's 70")

        // The engine agrees: the purchase goes through exactly when the
        // terms say it can.
        var refused = state
        refused.company.cash = cost - 1
        XCTAssertTrue(Reducer.apply(.acquireRival(rivalID: halcyon.id), to: &refused, balance: balance, content: engine.content).isEmpty)
        var bought = state
        XCTAssertFalse(Reducer.apply(.acquireRival(rivalID: halcyon.id), to: &bought, balance: balance, content: engine.content).isEmpty)

        let giant = RivalAcquisitionTerms(rival: incumbent, state: state, balance: balance)
        XCTAssertEqual(giant.blocker, "You're not big enough yet — grow your valuation first")
        XCTAssertEqual(giant.absorbedShelfCount, 1, "their 76 in Fitness beats the studio's 72")
    }

    func testTheSceneMapsStrengthReputationAndTheFortress() {
        let (engine, rivals, incumbent) = MarketMapSnapshotTests.fixture()
        XCTAssertEqual(RivalProfileScreen.band(for: 10), .minnow)
        XCTAssertEqual(RivalProfileScreen.band(for: 25), .small)
        XCTAssertEqual(RivalProfileScreen.band(for: 50), .mid)
        XCTAssertEqual(RivalProfileScreen.band(for: 95), .large)

        let giant = RivalProfileScreen.studioInput(for: incumbent, forSale: false)
        XCTAssertTrue(giant.isFortress)
        XCTAssertEqual(giant.band, .large)
        XCTAssertEqual(giant.reputation, 0.74, accuracy: 0.001)
        XCTAssertEqual(giant.founderSeed, 0xBEEF)

        let terms = RivalAcquisitionTerms(rival: rivals[1], state: engine.state, balance: engine.balance)
        let minnow = RivalProfileScreen.studioInput(for: rivals[1], forSale: terms.isAffordable)
        XCTAssertFalse(minnow.isFortress)
        XCTAssertEqual(minnow.band, .minnow)
        XCTAssertEqual(minnow.forSale, terms.isAffordable)
    }

    // MARK: - The screen

    func testRendersTheProfileForARival() {
        let (engine, rivals, _) = MarketMapSnapshotTests.fixture()
        snapshot("rival_profile_copycat") {
            RivalProfileContent(engine: engine, rivalID: rivals[0].id)
                .environment(AppRouter())
                .environment(GameShell())
        }
    }

    func testRendersTheProfileOfAStudioForSale() {
        let (engine, rivals, _) = MarketMapSnapshotTests.fixture()
        let terms = RivalAcquisitionTerms(rival: rivals[1], state: engine.state, balance: engine.balance)
        XCTAssertTrue(terms.isAffordable, "the fixture can buy the minnow: \(terms.blocker ?? "")")
        snapshot("rival_profile_for_sale") {
            RivalProfileContent(engine: engine, rivalID: rivals[1].id)
                .environment(AppRouter())
                .environment(GameShell())
        }
    }

    func testRendersTheProfileForTheIncumbent() {
        let (engine, _, incumbent) = MarketMapSnapshotTests.fixture()
        snapshot("rival_profile_incumbent") {
            RivalProfileContent(engine: engine, rivalID: incumbent.id)
                .environment(AppRouter())
                .environment(GameShell())
        }
    }

    func testRendersTheProfileWithAnOfferOnTheTable() {
        let (engine, rivals, _) = MarketMapSnapshotTests.fixture()
        var state = engine.state
        state.rivals.pendingBuyout = BuyoutOffer(rivalID: rivals[0].id, amount: 310_000, respondByDay: state.day + 4)
        state.rivals.lastBuyoutWasStrategic = true
        let offered = GameEngine(state: state, balance: engine.balance, content: engine.content)
        snapshot("rival_profile_offer") {
            RivalProfileContent(engine: offered, rivalID: rivals[0].id)
                .environment(AppRouter())
                .environment(GameShell())
        }
    }

    func testAMissingRivalReadsAsGone() {
        let (engine, _, _) = MarketMapSnapshotTests.fixture()
        snapshot("rival_profile_gone") {
            RivalProfileContent(engine: engine, rivalID: UUID())
                .environment(AppRouter())
                .environment(GameShell())
        }
    }

    // MARK: - The route

    func testTheProfileRouteLandsOnTheBusinessTabAndIsTakenByFamily() {
        let router = AppRouter()
        let id = UUID()
        router.go(.rivalProfile(rivalID: id))
        XCTAssertEqual(router.tab, .business)
        XCTAssertFalse(router.take(.marketMap), "another route does not take it")
        let taken = router.take(where: { if case .rivalProfile = $0 { return true } else { return false } })
        XCTAssertEqual(taken, .rivalProfile(rivalID: id))
        XCTAssertNil(router.pendingPush)
    }
}
