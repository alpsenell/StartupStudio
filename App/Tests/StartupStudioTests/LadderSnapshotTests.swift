import SwiftUI
import TycoonContent
import TycoonEngine
import XCTest

@testable import StartupStudio

/// The two ladders (WS-G): the goals card with its ladder label, the
/// *Staying independent* card beside the IPO desk, the term-sheet line,
/// and the new biography banner — both themes.
@MainActor
final class LadderSnapshotTests: XCTestCase {
    private var outputDirectory: URL {
        let path = ProcessInfo.processInfo.environment["PIXELKIT_PREVIEW_DIR"]
            ?? NSTemporaryDirectory() + "/startupstudio-previews"
        let url = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func engine() -> GameEngine {
        GameEngine.newGame(
            companyName: "Northgate Softworks",
            seed: 4242,
            difficulty: .normal,
            founder: FounderProfile(name: "Mira Okafor", archetype: .hacker, appearanceSeed: 0x5EED)
        )
    }

    /// A card, sized by its content — the HQ snapshot pattern.
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

    /// A whole screen, hosted in a window and drawn through UIKit:
    /// `ImageRenderer` lays a `ScrollView` out at nothing, so the
    /// biography — which scrolls — has to be rendered the way the app
    /// renders it.
    private func screenSnapshot(
        _ name: String,
        size: CGSize = CGSize(width: 393, height: 852),
        @ViewBuilder _ content: () -> some View
    ) {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let suffix = style == .light ? "light" : "dark"
            let host = UIHostingController(rootView: content())
            host.overrideUserInterfaceStyle = style
            let window = UIWindow(frame: CGRect(origin: .zero, size: size))
            window.rootViewController = host
            window.makeKeyAndVisible()
            host.view.frame = window.bounds
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            // Let SwiftUI commit its first layout pass before drawing.
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            let format = UIGraphicsImageRendererFormat()
            format.scale = 2
            let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { context in
                window.layer.render(in: context.cgContext)
            }
            window.isHidden = true
            guard let data = image.pngData() else {
                XCTFail("failed to render \(name) (\(suffix))")
                continue
            }
            XCTAssertGreaterThan(data.count, 4_096, "\(name) (\(suffix)) rendered empty")
            let url = outputDirectory.appendingPathComponent("\(name)_\(suffix).png")
            XCTAssertNoThrow(try data.write(to: url), "could not write \(url.path)")
        }
    }

    /// A studio in chapter 3 that turned a term sheet down: the
    /// independent ladder, refreshed by one tick.
    private func independentEngine() -> GameEngine {
        let fresh = engine()
        var state = fresh.state
        state.progression.chapter = 3
        state.progression.independentSinceDay = 140
        state.investors.profitableQuarters = 2
        _ = Reducer.tick(&state, balance: fresh.balance, content: fresh.content)
        return GameEngine.resume(state: state)
    }

    func testTheGoalsCardNamesTheLadder() {
        let engine = independentEngine()
        XCTAssertEqual(engine.state.goalTrack, .independent)
        XCTAssertEqual(engine.state.declaredGoalTrack, .independent)
        let ids = Set(engine.state.progression.activeGoals.map(\.id))
        XCTAssertTrue(ids.contains("g3i_six_tenured"), "the card is not showing the independent goals: \(ids)")
        XCTAssertFalse(ids.contains("g3_reach_the_studio"))
        snapshot("goals_card_independent") {
            GoalsCard(engine: engine)
        }
    }

    /// The same chapter, undeclared: today's goals and the question.
    func testTheGoalsCardAsksTheQuestionWhileItIsOpen() {
        let fresh = engine()
        var state = fresh.state
        state.progression.chapter = 3
        _ = Reducer.tick(&state, balance: fresh.balance, content: fresh.content)
        let engine = GameEngine.resume(state: state)
        XCTAssertNil(engine.state.declaredGoalTrack)
        XCTAssertTrue(engine.state.progression.activeGoals.contains { $0.id == "g3_reach_the_studio" })
        snapshot("goals_card_undeclared") {
            GoalsCard(engine: engine)
        }
    }

    func testEveryIndependentGoalHasAnActionButTimePassing() {
        let engine = independentEngine()
        for chapter in ProgressionState.firstSplitChapter...ProgressionState.chapterCount {
            for goal in engine.content.goals(inChapter: chapter, track: .independent) {
                if goal.id == "g5i_five_years_in" { continue }
                XCTAssertNotNil(NowAction.action(for: goal.id, state: engine.state), "no action for \(goal.id)")
            }
        }
        XCTAssertEqual(NowAction.action(for: "g3i_buy_the_office", state: engine.state)?.route, .city)
    }

    func testTheIndependenceCardShowsItsGates() {
        let engine = independentEngine()
        XCTAssertNotNil(engine.state.independenceBlocker(balance: engine.balance))
        snapshot("independence_card") {
            IndependenceCard(engine: engine)
        }
    }

    /// The card once every gate is met: the button is live.
    func testTheIndependenceCardOpensAtTheGate() {
        let fresh = engine()
        var state = fresh.state
        let config = fresh.balance.investors
        state.day = config.independentMinDay
        state.investors.profitableQuarters = config.independentProfitableQuarters
        state.company.reputation = config.independentMinReputation
        let engine = GameEngine.resume(state: state)
        XCTAssertTrue(engine.state.canStayIndependent(balance: engine.balance))
        snapshot("independence_card_ready") {
            IndependenceCard(engine: engine)
        }
    }

    func testTheTermSheetSaysSigningIsOneWay() {
        let fresh = engine()
        var state = fresh.state
        state.investors.pendingOffer = InvestmentOffer(
            investorID: "test_angel", investorName: "Harbour Angels", amount: 80_000,
            equity: 12, valuation: 650_000, takesBoardSeat: false,
            expects: .profitability, respondByDay: state.day + 7
        )
        let prompt = DecisionPrompt.pending(in: state, content: fresh.content, balance: fresh.balance)
        let accept = prompt?.options.first { $0.label == "Take the money" }
        XCTAssertNotNil(accept)
        XCTAssertTrue(
            accept?.detail?.contains("Still yours") == true,
            "the accept button does not say the ending closes: \(accept?.detail ?? "")"
        )
        XCTAssertEqual(prompt?.options.last?.label, "Stay independent")

        // Already funded: nothing left to give up, so the line is gone.
        state.investors.equityRemaining = 88
        let funded = DecisionPrompt.pending(in: state, content: fresh.content, balance: fresh.balance)
        XCTAssertFalse(funded?.options.first?.detail?.contains("Still yours") == true)
    }

    func testTheBiographyLeadsWithStillYours() {
        let fresh = engine()
        var state = fresh.state
        let config = fresh.balance.investors
        state.day = config.independentMinDay
        state.investors.profitableQuarters = config.independentProfitableQuarters
        state.company.reputation = config.independentMinReputation
        let engine = GameEngine.resume(state: state)
        engine.send(.declareIndependence)
        guard let info = engine.state.gameOver else {
            return XCTFail("declaring independence at the gate did not end the run")
        }
        XCTAssertEqual(info.kind, .independent)
        XCTAssertTrue(info.kind.isSuccess)
        XCTAssertTrue(info.reason.hasPrefix("You still owned 100%."))
        screenSnapshot("biography_independent") {
            FounderBiographyView(engine: engine, info: info, onNewGame: { _, _ in })
                .environment(AppRouter())
                .environment(GameShell())
        }
    }
}
