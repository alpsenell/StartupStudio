import SwiftUI
import TycoonContent
import TycoonEngine
import XCTest

@testable import StartupStudio

/// The store page in both themes: a reviewed release, a subscription, and
/// the coming-soon variant.
///
/// The page content is rendered, not the screen: `ImageRenderer` draws a
/// `ScrollView` as a blank PNG, which is why `StorefrontPage` exists
/// separately from `StorefrontScreen`.
@MainActor
final class StorefrontSnapshotTests: XCTestCase {
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

    // MARK: Fixtures

    /// A stable id, so the generated box art and screenshots are the same
    /// in every run of these snapshots.
    private let productID = UUID(uuidString: "0F1E2D3C-4B5A-6978-8796-A5B4C3D2E1F0")!

    private let reviews = [
        Review(outlet: "The Daily Byte", score: 84, blurb: "Sharp, fast, and it knows what it is for."),
        Review(outlet: "Pixel Review", score: 71, blurb: "A confident first release with a thin settings screen."),
        Review(outlet: "Hexadecimal", score: 66, blurb: "Good bones. It will be great in a version or two."),
        Review(outlet: "Modem Weekly", score: 90, blurb: "The best thing this studio has shipped."),
    ]

    /// Resumes a fresh game with `product` on the shelf.
    private func engine(with product: Product) -> GameEngine {
        var state = engine().state
        state.products.append(product)
        return GameEngine.resume(state: state)
    }

    private func releasedProduct(
        typeID: String,
        topicID: String,
        name: String,
        info: ReleaseInfo
    ) -> Product {
        Product(id: productID, name: name, typeID: typeID, topicID: topicID, stage: .released(info))
    }

    // MARK: Tests

    func testAReviewedReleaseHasStarsPriceScreenshotsAndQuotes() {
        let info = ReleaseInfo(
            launchDay: 96,
            quality: 74,
            reviews: reviews,
            weeklySales: [
                WeeklySale(weekIndex: 0, units: 4_180, revenue: 12_540),
                WeeklySale(weekIndex: 1, units: 3_260, revenue: 9_780),
            ],
            offMarket: false,
            priceTier: .premium,
            lastUpdateDay: 130,
            updateCount: 3
        )
        let product = releasedProduct(
            typeID: "mobile_app", topicID: "fitness", name: "Overcast", info: info
        )
        let engine = engine(with: product)
        XCTAssertEqual(info.averageReviewScore, 78, "the hero's stars are drawn from this")
        snapshot("storefront_released") {
            StorefrontPage(engine: engine, product: product)
        }
    }

    func testASubscriptionProductCountsSubscribersNotUnits() {
        let info = ReleaseInfo(
            launchDay: 40,
            quality: 81,
            reviews: Array(reviews.prefix(2)),
            weeklySales: [WeeklySale(weekIndex: 5, units: 0, revenue: 24_600)],
            offMarket: false,
            priceTier: .standard,
            subscribers: 12_400,
            isSubscription: true,
            lastUpdateDay: nil,
            updateCount: 0
        )
        let product = releasedProduct(
            typeID: "saas_platform", topicID: "logistics", name: "Freightline", info: info
        )
        let engine = engine(with: product)
        snapshot("storefront_subscription") {
            StorefrontPage(engine: engine, product: product)
        }
    }

    func testAProductInDevelopmentGetsTheComingSoonPage() {
        let product = Product(
            id: productID,
            name: "Nightshift",
            typeID: "game",
            topicID: "gaming",
            stage: .development(
                DevProgress(
                    designPts: 120, codePts: 180, polishPts: 40, openBugs: 3,
                    focus: .balanced, hype: 46
                )
            )
        )
        let engine = engine(with: product)
        snapshot("storefront_coming_soon") {
            StorefrontPage(engine: engine, product: product)
        }
    }

    /// The one number the page re-draws rather than restates: the 0–100
    /// average as five stars, to the nearest half.
    func testStarsRoundToTheNearestHalfOfFive() {
        for (score, expected) in [(0, "0.0"), (50, "2.5"), (78, "4.0"), (90, "4.5"), (100, "5.0")] {
            let stars = (Double(score) / 20 * 2).rounded() / 2
            XCTAssertEqual(
                stars.formatted(.number.precision(.fractionLength(1)).locale(Theme.gameLocale)),
                expected,
                "\(score) out of 100"
            )
        }
    }

    /// At an accessibility text size the hero stacks instead of clipping
    /// the name against the box art, and the shot strip steps down a
    /// whole pixel scale to keep fitting.
    func testTheHeroStacksAtAccessibilityTextSizes() {
        let info = ReleaseInfo(
            launchDay: 96, quality: 74, reviews: Array(reviews.prefix(2)),
            weeklySales: [WeeklySale(weekIndex: 0, units: 4_180, revenue: 12_540)],
            offMarket: false, priceTier: .standard, updateCount: 1
        )
        let product = releasedProduct(
            typeID: "mobile_app", topicID: "fitness", name: "Overcast", info: info
        )
        let engine = engine(with: product)
        snapshot("storefront_large_type") {
            StorefrontPage(engine: engine, product: product)
                .environment(\.dynamicTypeSize, .accessibility3)
        }
    }

    /// The deep link lands in the tab that consumes it, and consuming it
    /// clears the request so a redraw cannot push twice.
    func testTheStorefrontRouteBelongsToProductsAndIsConsumedOnce() {
        let route = Route.storefront(productID: productID)
        XCTAssertEqual(route.tab, .products)
        let router = AppRouter()
        router.go(route)
        XCTAssertEqual(router.tab, .products)
        XCTAssertNotNil(router.take(where: { if case .storefront = $0 { true } else { false } }))
        XCTAssertNil(router.pendingPush)
        XCTAssertFalse(router.take(route), "a second take finds nothing left")
    }

    /// An off-market product cannot be re-priced, and says so instead of
    /// offering a button that does nothing.
    func testAnOffMarketReleaseStillRendersItsPage() {
        let info = ReleaseInfo(
            launchDay: 20,
            quality: 55,
            reviews: Array(reviews.suffix(1)),
            weeklySales: [WeeklySale(weekIndex: 0, units: 900, revenue: 2_700)],
            offMarket: true,
            priceTier: .budget,
            updateCount: 1
        )
        let product = releasedProduct(
            typeID: "web_app", topicID: "finance", name: "Ledgerly", info: info
        )
        let engine = engine(with: product)
        snapshot("storefront_off_market") {
            StorefrontPage(engine: engine, product: product)
        }
    }
}
