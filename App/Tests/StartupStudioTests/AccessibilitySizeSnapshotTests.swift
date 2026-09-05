import PixelKit
import SwiftUI
import TycoonContent
import TycoonEngine
import TycoonSave
import UIKit
import XCTest

@testable import StartupStudio

/// R7's Dynamic Type sweep: every pixel screen at `.accessibility3` and
/// `.accessibility5`, in both themes, written out as review artifacts.
///
/// `PixelText` ignores Dynamic Type by design — a bitmap font has no
/// intermediate sizes and scaling it produces mush — so every pixel site
/// carries a real label beside it, and *that* is what has to grow. So the
/// suite asserts two things per screen beyond "it rendered":
///
/// - the page is **taller** at `.accessibility5` than at `.large`. A screen
///   that comes out the same height has clamped its way out of the problem,
///   which is the failure this sweep exists to catch;
/// - the page is inked, so a layout that collapsed rather than wrapped is
///   not passing as a blank rectangle.
///
/// The images themselves are the other half: they are how the wrapping was
/// checked by eye at both sizes.
@MainActor
final class AccessibilitySizeSnapshotTests: XCTestCase {
    /// The two sizes the sweep runs at, named for the file suffix.
    static let sweep: [(name: String, size: DynamicTypeSize)] = [
        ("a3", .accessibility3),
        ("a5", .accessibility5),
    ]

    private var outputDirectory: URL {
        let path = ProcessInfo.processInfo.environment["PIXELKIT_PREVIEW_DIR"]
            ?? NSTemporaryDirectory() + "/startupstudio-previews"
        let url = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - The harness

    private func image(
        _ content: some View, width: CGFloat, size: DynamicTypeSize, style: UIUserInterfaceStyle
    ) -> UIImage? {
        let renderer = ImageRenderer(
            content: content
                .padding(Theme.Spacing.lg)
                .frame(width: width)
                .background(Theme.screenBackground)
                .environment(\.colorScheme, style == .light ? .light : .dark)
                .environment(\.dynamicTypeSize, size)
        )
        // 1×, not the 2× the other suites use: a page that wraps every
        // line at `.accessibility5` is several thousand points tall, and
        // at 2× the biography's PNG is too big to encode at all ("No
        // IDATs written into file"). These are read by eye, not compared
        // pixel for pixel.
        renderer.scale = 1
        return renderer.uiImage
    }

    /// Renders `content` at both accessibility sizes in both themes, writes
    /// the four PNGs, and checks that the page actually grew rather than
    /// clamping itself back to the ordinary layout.
    private func sweep(
        _ name: String,
        width: CGFloat = 393,
        @ViewBuilder _ content: () -> some View
    ) {
        let baseline = image(content(), width: width, size: .large, style: .light)
        XCTAssertNotNil(baseline, "failed to render \(name) at .large")

        for (suffix, size) in Self.sweep {
            for style in [UIUserInterfaceStyle.light, .dark] {
                let theme = style == .light ? "light" : "dark"
                guard let rendered = image(content(), width: width, size: size, style: style),
                      let data = rendered.pngData()
                else {
                    XCTFail("failed to render \(name) at \(suffix) (\(theme))")
                    continue
                }
                XCTAssertGreaterThan(data.count, 512, "\(name)_\(suffix)_\(theme) rendered empty")
                XCTAssertGreaterThan(
                    inkCoverage(rendered), 0.05,
                    "\(name)_\(suffix)_\(theme) rendered blank — the layout collapsed rather than wrapped"
                )
                if style == .light, let baseline {
                    XCTAssertGreaterThan(
                        rendered.size.height, baseline.size.height,
                        "\(name) is no taller at \(suffix) than at .large — it clamped instead of wrapping"
                    )
                }
                let url = outputDirectory.appendingPathComponent("a11y_\(name)_\(suffix)_\(theme).png")
                XCTAssertNoThrow(try data.write(to: url), "could not write \(url.path)")
            }
        }
    }

    /// The share of sampled pixels that differ from the top-left one.
    private func inkCoverage(_ image: UIImage) -> Double {
        guard let cg = image.cgImage,
              let data = cg.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data)
        else { return 0 }
        let bytesPerPixel = max(1, cg.bitsPerPixel / 8)
        let background = (0..<bytesPerPixel).map { Int(bytes[$0]) }
        var inked = 0
        var sampled = 0
        for y in stride(from: 0, to: cg.height, by: 8) {
            for x in stride(from: 0, to: cg.width, by: 8) {
                let offset = y * cg.bytesPerRow + x * bytesPerPixel
                sampled += 1
                if (0..<bytesPerPixel).contains(where: { abs(Int(bytes[offset + $0]) - background[$0]) > 8 }) {
                    inked += 1
                }
            }
        }
        return sampled == 0 ? 0 : Double(inked) / Double(sampled)
    }

    // MARK: - Fixtures

    private func company(days: Int = 30) -> GameEngine {
        let engine = GameEngine.newGame(
            companyName: "Northgate Softworks",
            seed: 4242,
            difficulty: .normal,
            founder: FounderProfile(name: "Mira Okafor", archetype: .hacker, appearanceSeed: 0x5EED)
        )
        var state = engine.state
        for _ in 0..<days { _ = Reducer.tick(&state, balance: engine.balance, content: engine.content) }
        return GameEngine.resume(state: state)
    }

    private func slot(_ index: Int, _ summary: SaveSummary) -> SlotSummary {
        SlotSummary(slot: index, contents: .saved(
            summary: summary,
            envelope: SaveEnvelope(
                formatVersion: 1,
                savedAt: Date(timeIntervalSinceNow: -3_600),
                appVersion: "0.1.0",
                summary: summary
            )
        ))
    }

    // MARK: - The screens

    func testTheTitleScreenHoldsAtTheAccessibilitySizes() {
        let engine = company(days: 90)
        let summary = SaveSummary(state: engine.state)
        sweep("title") {
            TitleScreenContent(
                scene: TitleScene.input(for: engine.state),
                current: summary,
                currentSlot: 0,
                slots: [
                    slot(0, summary),
                    SlotSummary(slot: 1, contents: .empty),
                    SlotSummary(slot: 2, contents: .empty),
                ]
            )
        }
    }

    func testTheWarRoomHoldsAtTheAccessibilitySizes() throws {
        let engine = WarRoomFixture.engine(.countdown(daysOut: 5))
        let product = try XCTUnwrap(engine.state.productInDevelopment)
        sweep("war_room") {
            WarRoomContent(engine: engine, product: product)
                .environment(AppRouter())
                .environment(GameShell())
        }
    }

    func testTheNewspaperHoldsAtTheAccessibilitySizes() {
        let state = StoryFixtures.fourWeeks()
        let composer = NewspaperComposer(
            state: state, content: StoryFixtures.content, balance: StoryFixtures.balance
        )
        sweep("newspaper") {
            NewspaperPage(issue: composer.issues()[3])
        }
    }

    func testTheStorefrontHoldsAtTheAccessibilitySizes() throws {
        let engine = company(days: 30)
        var state = engine.state
        let type = try XCTUnwrap(engine.content.productTypes.first)
        let topic = try XCTUnwrap(engine.content.topics.first)
        let product = Product(
            id: UUID(),
            name: "Overcast",
            typeID: type.id,
            topicID: topic.id,
            stage: .released(ReleaseInfo(
                launchDay: 20,
                quality: 74,
                reviews: [],
                weeklySales: [WeeklySale(weekIndex: 0, units: 4_180, revenue: 12_540)],
                offMarket: false,
                priceTier: .premium,
                lastUpdateDay: 28,
                updateCount: 2
            ))
        )
        state.products.append(product)
        let withProduct = GameEngine.resume(state: state)
        sweep("storefront") {
            StorefrontPage(engine: withProduct, product: product)
        }
    }

    func testTheFounderBiographyHoldsAtTheAccessibilitySizes() throws {
        let engine = company(days: 30)
        var state = engine.state
        let buyer = try XCTUnwrap(state.rivals.rivals.first, "no rival was founded")
        state.company.cash = 3_450
        state.rivals.pendingBuyout = BuyoutOffer(
            rivalID: buyer.id, amount: 20_460, respondByDay: state.day + 5
        )
        state.rivals.lastBuyoutWasStrategic = false
        _ = Reducer.apply(.acceptBuyout, to: &state, balance: engine.balance, content: engine.content)
        let ended = GameEngine.resume(state: state)
        let info = try XCTUnwrap(ended.state.gameOver)
        sweep("biography") {
            FounderBiographyView(engine: ended, info: info, onNewGame: { _, _, _ in })
                .biographyContent
                .environment(GameShell())
                .environment(AppRouter())
        }
    }

    func testTheMarketMapHoldsAtTheAccessibilitySizes() {
        let engine = company(days: 60)
        sweep("market_map") {
            MarketMapScreen(engine: engine) { _ in }
                .environment(AppRouter())
                .environment(GameShell())
        }
    }
}
