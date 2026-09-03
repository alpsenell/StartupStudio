import SwiftUI
import TycoonContent
import TycoonEngine
import XCTest

@testable import StartupStudio

/// HQ's new first card and the Products tab's day-0 catalog, both themes.
@MainActor
final class HQSnapshotTests: XCTestCase {
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

    /// Ticks once so progression has opened chapter 1's goals. The tick
    /// loop is the engine's own; from outside the package the way to
    /// advance a day synchronously is the public reducer on a copy of the
    /// state, resumed into a fresh engine.
    private func tickedEngine() -> GameEngine {
        let fresh = engine()
        var state = fresh.state
        _ = Reducer.tick(&state, balance: fresh.balance, content: fresh.content)
        return GameEngine.resume(state: state)
    }

    func testTheNowCardLeadsWithTheFirstGoalAndItsAction() {
        let engine = tickedEngine()
        XCTAssertFalse(engine.state.progression.activeGoals.isEmpty, "chapter 1 should be open after a tick")
        let first = engine.state.progression.activeGoals[0]
        XCTAssertNotNil(NowAction.action(for: first.id, state: engine.state), "the first goal has an action")
        snapshot("now_card_goal") {
            NowCard(engine: engine, startNewProduct: {})
                .environment(AppRouter())
                .environment(GameShell())
        }
    }

    func testTheNowCardShowsTheBuildInFlight() {
        let engine = tickedEngine()
        let type = engine.content.productTypes.first { engine.state.isProductTypeUnlocked($0.id, content: engine.content) }!
        let topic = engine.content.topics.first!
        engine.send(.startProduct(typeID: type.id, topicID: topic.id, name: "Overcast", focus: .balanced))
        XCTAssertNotNil(engine.state.productInDevelopment)
        snapshot("now_card_build") {
            NowCard(engine: engine, startNewProduct: {})
                .environment(AppRouter())
                .environment(GameShell())
        }
    }

    func testEveryChapterOneGoalHasAnAction() {
        // The first chapter is the one a new player reads; every goal in
        // it should be one tap from its screen.
        let engine = tickedEngine()
        for goal in engine.content.goals(inChapter: 1) {
            XCTAssertNotNil(NowAction.action(for: goal.id, state: engine.state), "no action for \(goal.id)")
        }
    }

    func testTheDayZeroCatalogListsEveryType() {
        let engine = engine()
        snapshot("products_day0_catalog") {
            TypeCatalogPreview(engine: engine)
        }
        let locked = engine.content.productTypes.filter {
            !engine.state.isProductTypeUnlocked($0.id, content: engine.content)
        }
        XCTAssertFalse(locked.isEmpty, "some types are gated behind research on day 0")
    }
}
