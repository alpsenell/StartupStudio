import SwiftUI
import TycoonContent
import TycoonEngine
import XCTest

@testable import StartupStudio

/// The launch week war room (U1): the room five days out and on launch
/// day mid-reveal, both themes; the offer window; and the press strip's
/// determinism.
@MainActor
final class WarRoomSnapshotTests: XCTestCase {
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

    // MARK: - The room

    func testTheRoomFiveDaysOut() throws {
        let engine = WarRoomFixture.engine(.countdown(daysOut: 5))
        let product = try XCTUnwrap(engine.state.productInDevelopment)
        let eta = try XCTUnwrap(engine.state.buildETA(productID: product.id, balance: engine.balance, content: engine.content))
        let days = try XCTUnwrap(eta.daysToComplete)
        XCTAssertLessThanOrEqual(days, 5, "the fixture lands inside five days of the ETA")
        XCTAssertGreaterThan(days, 0, "…but not on the day itself")
        XCTAssertTrue(WarRoomOffer.isOffered(for: product, engine: engine))
        XCTAssertTrue(engine.state.campaigns.contains { $0.productID == product.id }, "a campaign feeds the meter")

        snapshot("war_room_countdown") {
            WarRoomContent(engine: engine, product: product)
                .environment(AppRouter())
                .environment(GameShell())
        }
    }

    func testLaunchDayMidReveal() throws {
        let engine = WarRoomFixture.engine(.launchDay)
        let product = try XCTUnwrap(engine.state.products.first)
        guard case .released(let info) = product.stage else {
            return XCTFail("the fixture shipped")
        }
        XCTAssertEqual(info.launchDay, engine.state.day, "it shipped today")
        XCTAssertEqual(info.reviews.count, engine.balance.reviewOutlets.count, "every outlet filed")
        XCTAssertTrue(WarRoomOffer.isLaunchDay(for: product, state: engine.state))
        XCTAssertEqual(WarRoomOffer.candidate(in: engine)?.id, product.id, "the route opens the launch")

        snapshot("war_room_launch_reveal") {
            WarRoomContent(
                engine: engine, product: product,
                revealed: 2, celebrationToken: 1, revealTypes: false
            )
            .environment(AppRouter())
            .environment(GameShell())
        }
    }

    // MARK: - The offer

    func testAFreshBuildIsNotOfferedTheRoom() throws {
        let engine = GameEngine.newGame(
            companyName: "Northgate Softworks",
            seed: 4242,
            founder: FounderProfile(name: "Mira Okafor", archetype: .hacker, appearanceSeed: 0x5EED)
        )
        let type = try XCTUnwrap(engine.content.productTypes.first {
            engine.state.isProductTypeUnlocked($0.id, content: engine.content)
        })
        let topic = try XCTUnwrap(engine.content.topics.first)
        engine.send(.startProduct(typeID: type.id, topicID: topic.id, name: "Overcast", focus: .balanced))
        let product = try XCTUnwrap(engine.state.productInDevelopment)

        let days = try XCTUnwrap(WarRoomOffer.daysOut(for: product, engine: engine))
        XCTAssertGreaterThan(days, WarRoomOffer.windowDays, "day one is weeks from the ETA")
        XCTAssertFalse(WarRoomOffer.isOffered(for: product, engine: engine))
        // The route still has a build to watch: any build the player picks.
        XCTAssertEqual(WarRoomOffer.candidate(in: engine)?.id, product.id)
    }

    // MARK: - The press

    func testThePressStripIsDeterministicForAState() throws {
        let engine = WarRoomFixture.engine(.countdown(daysOut: 5))
        let product = try XCTUnwrap(engine.state.productInDevelopment)
        let first = PressStrip.lines(for: product, state: engine.state, balance: engine.balance, content: engine.content)
        let again = PressStrip.lines(for: product, state: engine.state, balance: engine.balance, content: engine.content)
        XCTAssertEqual(first, again, "the same day shows the same lines")
        XCTAssertEqual(first.count, 6)
        XCTAssertTrue(first.allSatisfy { !$0.text.isEmpty && !$0.text.contains("{") }, "every placeholder is filled")
        XCTAssertTrue(first.allSatisfy { engine.balance.reviewOutlets.contains($0.outlet) }, "bylines are the review outlets")
        XCTAssertTrue(first.contains { $0.text.contains(product.name) }, "the build gets a mention")

        // Tomorrow is a different strip; the RNG streams are untouched.
        var tomorrow = engine.state
        let rngBefore = tomorrow.rng
        let worldBefore = tomorrow.worldRNG
        tomorrow.day += 1
        let next = PressStrip.lines(for: product, state: tomorrow, balance: engine.balance, content: engine.content)
        XCTAssertNotEqual(first, next, "a new day rolls new lines")
        XCTAssertEqual(tomorrow.rng, rngBefore)
        XCTAssertEqual(tomorrow.worldRNG, worldBefore)
    }

    func testTheStripKnowsLaunchDay() throws {
        let engine = WarRoomFixture.engine(.launchDay)
        let product = try XCTUnwrap(engine.state.products.first)
        XCTAssertEqual(
            PressStrip.phase(of: product, state: engine.state, balance: engine.balance, content: engine.content),
            .launchDay
        )
        let lines = PressStrip.lines(for: product, state: engine.state, balance: engine.balance, content: engine.content)
        let mentions = lines.filter { $0.id.isMultiple(of: 2) }
        XCTAssertTrue(mentions.allSatisfy { $0.text.contains(product.name) }, "launch day is about the launch")
    }
}
