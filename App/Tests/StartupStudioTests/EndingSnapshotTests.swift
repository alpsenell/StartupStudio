import SwiftUI
import TycoonContent
import TycoonEngine
import XCTest

@testable import StartupStudio

/// The two endings WS-B added or changed, drawn by the real biography on
/// real state: a distress sale ("Sold up", with the post-mortem) and an
/// acquisition closed over an earn-out with a round bought back along the
/// way (the money card's three numbers and the buyback line). Both themes.
@MainActor
final class EndingSnapshotTests: XCTestCase {
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
            // A blank frame of the background colour is a valid PNG of a
            // plausible size, which is how a scroll view rendering nothing
            // went unnoticed. A page of cards inks well over a tenth of it.
            XCTAssertGreaterThan(inkCoverage(image), 0.1, "\(name) (\(suffix)) rendered blank")
            let url = outputDirectory.appendingPathComponent("\(name)_\(suffix).png")
            XCTAssertNoThrow(try data.write(to: url), "could not write \(url.path)")
        }
    }

    /// The share of sampled pixels that differ from the top-left one (the
    /// background): 0 for a blank frame, well above a tenth for a page.
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

    /// A company a month in, with a rival on the field to make the offer.
    private func company() -> (state: GameState, balance: BalanceConfig, content: ContentCatalog) {
        let fresh = GameEngine.newGame(
            companyName: "Rooftop",
            seed: 4242,
            difficulty: .normal,
            founder: FounderProfile(name: "Mira Okafor", archetype: .hacker, appearanceSeed: 0x5EED)
        )
        var state = fresh.state
        for _ in 0..<30 { _ = Reducer.tick(&state, balance: fresh.balance, content: fresh.content) }
        return (state, fresh.balance, fresh.content)
    }

    private func biography(_ engine: GameEngine) -> some View {
        FounderBiographyView(engine: engine, info: engine.state.gameOver!, onNewGame: { _, _, _ in })
            .biographyContent
            .environment(GameShell())
            .environment(AppRouter())
    }

    func testSoldUpShowsThePostMortem() throws {
        var (state, balance, content) = company()
        let buyer = try XCTUnwrap(state.rivals.rivals.first, "no rival was founded")
        state.company.cash = 3_450
        state.company.reputation = 12
        state.rivals.pendingBuyout = BuyoutOffer(rivalID: buyer.id, amount: 20_460, respondByDay: state.day + 5)
        state.rivals.lastBuyoutWasStrategic = false
        _ = Reducer.apply(.acceptBuyout, to: &state, balance: balance, content: content)
        XCTAssertEqual(state.gameOver?.kind, .soldUp)
        XCTAssertEqual(state.gameOver?.kind.isSuccess, false)

        let engine = GameEngine.resume(state: state)
        XCTAssertFalse(
            PostMortem.lines(for: engine.state, balance: engine.balance, weeklyBurn: engine.weeklyBurn).isEmpty,
            "a sold-up company with nothing shipped has a post-mortem"
        )
        snapshot("ending_sold_up") { biography(engine) }
    }

    func testAnEarnOutAcquisitionShowsTheThreeNumbersAndTheBuyback() throws {
        var (state, balance, content) = company()
        let buyer = try XCTUnwrap(state.rivals.rivals.first, "no rival was founded")
        state.company.cash = 900_000
        state.company.reputation = 72
        // A round bought back on the way, for the money card's line.
        state.investors.boughtOut = [RaisedRound(
            investorID: "lantern_partners", investorName: "Lantern Partners",
            amount: 400_000, equity: 15, valuation: 2_600_000, day: 12,
            takesBoardSeat: true, expects: .headcount,
            boughtOutDay: 20, buybackPrice: 240_000
        )]
        state.rivals.pendingBuyout = BuyoutOffer(rivalID: buyer.id, amount: 1_240_000, respondByDay: state.day + 5)
        state.rivals.lastBuyoutWasStrategic = true
        _ = Reducer.apply(.acceptBuyoutEarnOut, to: &state, balance: balance, content: content)
        XCTAssertNotNil(state.investors.earnOut)
        state.investors.earnOut?.expectation = .profitability

        // Miss the first review, meet the second: 80% paid, 20% forfeited.
        let interval = balance.investors.reviewIntervalDays
        state.investors.lastQuarterCash = Int.max / 2
        while state.gameOver == nil, state.day % interval != 0 || state.investors.earnOut?.remainingReviews == 2 {
            _ = Reducer.tick(&state, balance: balance, content: content)
            if state.investors.earnOut?.remainingReviews == 1, state.investors.earnOut?.missedReviews == 1 {
                state.investors.lastQuarterCash = 1
            }
        }
        XCTAssertNil(state.gameOver)
        while state.gameOver == nil, state.day < interval * 3 {
            _ = Reducer.tick(&state, balance: balance, content: content)
        }
        XCTAssertEqual(state.gameOver?.kind, .acquired)
        XCTAssertEqual(state.investors.earnOut?.paid, 992_000)
        XCTAssertEqual(state.investors.earnOut?.outstanding, 248_000)

        let engine = GameEngine.resume(state: state)
        snapshot("ending_acquired_earn_out") { biography(engine) }
    }
}
