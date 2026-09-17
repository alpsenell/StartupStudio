import SwiftUI
import TycoonContent
import TycoonEngine
import TycoonSave
import UIKit
import XCTest

@testable import StartupStudio

/// Iteration 7 (R5) — what the app does with an epilogue.
///
/// The engine's half is `EndlessTests`; this is the three places the
/// player sees it: the button on the biography, the line under the
/// banner, and the Continue card on the front door.
@MainActor
final class EndlessAppTests: XCTestCase {
    private var outputDirectory: URL {
        let path = ProcessInfo.processInfo.environment["PIXELKIT_PREVIEW_DIR"]
            ?? NSTemporaryDirectory() + "/startupstudio-previews"
        let url = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeTempDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("Endless-\(UUID().uuidString)", isDirectory: true)
    }

    /// `GameOverInfo`'s memberwise init is the engine's own; from out here
    /// an ending is built the way a save reads one.
    private func ending(_ kind: EndingKind, day: Int = 200, reason: String = "r") throws -> GameOverInfo {
        let json = #"{"day": \#(day), "reason": "\#(reason)", "kind": "\#(kind.rawValue)"}"#
        return try JSONDecoder().decode(GameOverInfo.self, from: Data(json.utf8))
    }

    /// A company that went public on day 200.
    private func publicEngine() -> GameEngine {
        let fresh = GameEngine.newGame(
            companyName: "Rooftop",
            seed: 4242,
            difficulty: .normal,
            founder: FounderProfile(name: "Mira Okafor", archetype: .hacker, appearanceSeed: 0x5EED)
        )
        var state = fresh.state
        for _ in 0..<30 { _ = Reducer.tick(&state, balance: fresh.balance, content: fresh.content) }
        state.day = 200
        state.company.cash = fresh.balance.investors.ipoValuationFloor * 2
        state.company.reputation = 65
        state.investors.profitableQuarters = fresh.balance.investors.ipoProfitableQuarters
        state.products.append(Product(
            id: UUID(), name: "Ledger", typeID: "saas_platform", topicID: "productivity",
            stage: .released(ReleaseInfo(
                launchDay: 150, quality: 78,
                reviews: [Review(outlet: "TechDaily", score: 78, blurb: "Quietly excellent.")],
                weeklySales: [], offMarket: false, isSubscription: true
            ))
        ))
        _ = Reducer.apply(.fileIPO(), to: &state, balance: fresh.balance, content: fresh.content)
        return GameEngine.resume(state: state)
    }

    // MARK: - The button

    /// The rule the biography's button follows is the reducer's rule: the
    /// two endings the founder chose, and only before an epilogue exists.
    func testKeepRunningItIsOfferedOnTheTwoEndingsTheFounderChose() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        let root = AppRootView(session: session)

        for kind in [EndingKind.ipo, .independent] {
            XCTAssertTrue(try root.canContinue(ending(kind)), kind.rawValue)
        }
        for kind in [EndingKind.bankruptcy, .acquired, .oustedByBoard, .soldUp] {
            XCTAssertFalse(try root.canContinue(ending(kind)), kind.rawValue)
        }
    }

    /// Tapping it is one `send`: the epilogue lands, the game-over clears,
    /// and the cover's own binding — which reads the engine — closes.
    func testContinuingClearsTheCoverAndLetsTheClockRun() {
        let engine = publicEngine()
        XCTAssertEqual(engine.state.gameOver?.kind, .ipo)

        engine.send(.continueAfterEnding)

        XCTAssertNil(engine.state.gameOver, "the cover's binding reads this and dismisses")
        XCTAssertEqual(engine.state.epilogue?.ending, .ipo)
        engine.setSpeed(.x2)
        XCTAssertEqual(engine.state.speed, .x2, "the clock takes a speed again")
        engine.setSpeed(.paused)
    }

    // MARK: - The line

    func testTheEpilogueLineSaysSinceWhenAndWhatHappenedNext() {
        let running = FounderBiographyView.epilogueLine(
            Epilogue(ending: .ipo, day: 812), endedOn: nil
        )
        XCTAssertEqual(running, "Public since day 812 · still running")

        let ended = FounderBiographyView.epilogueLine(
            Epilogue(ending: .ipo, day: 812), endedOn: 1_052
        )
        XCTAssertEqual(ended, "Public since day 812 · ran on for 240 more days")

        XCTAssertEqual(
            FounderBiographyView.epilogueLine(Epilogue(ending: .independent, day: 700), endedOn: 701),
            "Yours since day 700 · ran on for 1 more day"
        )
    }

    /// The biography a company that kept running finally lands on: the
    /// bankruptcy banner, with the IPO it played past under it.
    func testTheBiographyOfACompanyThatKeptRunning() throws {
        let engine = publicEngine()
        engine.send(.continueAfterEnding)
        var state = engine.state
        state.day = 400
        state.gameOver = try ending(
            .bankruptcy, day: 400,
            reason: "The account hit zero and stayed there, two hundred days after the bell."
        )
        let info = try XCTUnwrap(state.gameOver)
        let ended = GameEngine.resume(state: state)

        snapshot("ending_epilogue_bankruptcy") {
            FounderBiographyView(engine: ended, info: info, onNewGame: { _, _, _ in })
                .banner
                .environment(GameShell())
                .environment(AppRouter())
        }
    }

    /// The whole flow, through a real presented cover: the biography goes
    /// up because the engine says the run is over, "Keep running it" sends
    /// the action, and the cover comes down because the same binding now
    /// reads nil. Nothing dismisses it by hand — that is the point.
    func testTheCoverGoesUpAndComesDownWithTheGameOver() {
        let engine = publicEngine()
        let host = UIHostingController(rootView: EndingCoverHost(engine: engine))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        XCTAssertNotNil(host.presentedViewController, "the biography never went up")

        // A picture of the cover as it goes up, and of the whole column
        // it scrolls — which is where the two buttons live.
        writeWindow(window, named: "ending_ipo_cover")
        snapshot("ending_ipo_keep_running") {
            FounderBiographyView(
                engine: engine, info: engine.state.gameOver!, onNewGame: { _, _, _ in },
                onReplay: {},
                actions: BiographyActions(onContinueRunning: {})
            )
            .biographyContent
            .environment(GameShell())
            .environment(AppRouter())
        }

        // The button's own action, and nothing else.
        engine.send(.continueAfterEnding)
        RunLoop.main.run(until: Date().addingTimeInterval(0.8))
        XCTAssertNil(host.presentedViewController, "the cover did not come down")
        XCTAssertNil(engine.state.gameOver)
        window.isHidden = true
    }

    /// `AppRootView`'s game-over cover, reduced to the two things this
    /// test is about: the binding that reads the engine, and the action
    /// the button sends.
    private struct EndingCoverHost: View {
        let engine: GameEngine

        var body: some View {
            Color.clear
                .fullScreenCover(isPresented: Binding(
                    get: { engine.state.gameOver != nil }, set: { _ in }
                )) {
                    if let info = engine.state.gameOver {
                        GameWonView(
                            engine: engine, info: info, onNewGame: { _, _, _ in },
                            actions: BiographyActions(
                                onContinueRunning: { engine.send(.continueAfterEnding) }
                            )
                        )
                        .environment(GameShell())
                        .environment(AppRouter())
                    }
                }
        }
    }

    /// Draws whatever is on screen, presented sheets included, the way
    /// `LadderSnapshotTests` draws a whole screen.
    private func writeWindow(_ window: UIWindow, named name: String) {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { context in
            window.layer.render(in: context.cgContext)
        }
        guard let data = image.pngData() else { return XCTFail("failed to render \(name)") }
        XCTAssertGreaterThan(data.count, 4_096, "\(name) rendered empty")
        XCTAssertNoThrow(
            try data.write(to: outputDirectory.appendingPathComponent("\(name).png")),
            "could not write \(name)"
        )
    }

    // MARK: - The front door

    /// The Continue card says the same thing the biography does, from the
    /// summary alone — the front door never decodes a state.
    func testTheContinueCardReadsTheEpilogueFromTheSummary() {
        let engine = publicEngine()
        engine.send(.continueAfterEnding)
        var state = engine.state
        state.day = 300

        let summary = SaveSummary(state: state)
        XCTAssertNil(summary.ending, "the run is not over")
        XCTAssertEqual(summary.epilogue, "ipo")
        XCTAssertEqual(summary.epilogueKind, .ipo)
        XCTAssertEqual(summary.epilogueKind?.epilogueNoun, "Public")

        // And a run that never continued says nothing about an epilogue.
        let plain = SaveSummary(state: GameEngine.newGame(companyName: "Plain", seed: 1).state)
        XCTAssertNil(plain.epilogue)
        XCTAssertNil(plain.epilogueKind)
    }

    // MARK: - Rendering

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
}
