import PixelKit
import SwiftUI
import TycoonContent
import TycoonEngine
import XCTest

@testable import StartupStudio

/// The market map (iteration 6, U3): the model that turns state into
/// districts, and the screen, light and dark, on a mid-game fixture.
@MainActor
final class MarketMapSnapshotTests: XCTestCase {
    static let content: ContentCatalog = {
        guard let bundled = try? ContentCatalog.loadBundled() else {
            fatalError("TycoonContent is missing its bundled resources")
        }
        return bundled
    }()

    static let balance: BalanceConfig = {
        guard let bundled = try? BalanceConfig.loadBundled() else {
            fatalError("TycoonEngine is missing its bundled Balance.json resource")
        }
        return bundled
    }()

    private var outputDirectory: URL {
        let path = ProcessInfo.processInfo.environment["PIXELKIT_PREVIEW_DIR"]
            ?? NSTemporaryDirectory() + "/startupstudio-previews"
        let url = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// A studio a year and a half in: household name in Fitness, holding
    /// Finance, known in Music, a foot in Travel; three live products; two
    /// ordinary rivals and the incumbent across the board; the incumbent's
    /// opening challenge on the clock in Fitness; demand spread across the
    /// clamp so the districts come in every size.
    static func fixture() -> (engine: GameEngine, rivals: [Rival], incumbent: Rival) {
        var state = GameState.newGame(
            companyName: "Northgate Softworks", seed: 4242, balance: balance,
            founder: FounderProfile(name: "Mira Okafor", archetype: .hacker, appearanceSeed: 0x5EED)
        )
        state.day = 546
        // A studio worth having: enough to buy the minnow outright, not
        // the copycat, nowhere near the giant.
        state.company.cash = 180_000
        state.company.reputation = 55

        func released(_ name: String, _ topic: String, _ quality: Double, launched: Int) -> Product {
            Product(
                id: UUID(), name: name, typeID: "mobile_app", topicID: topic,
                stage: .released(ReleaseInfo(
                    launchDay: launched, quality: quality,
                    reviews: ["TechDaily", "AppVerdict"].map {
                        Review(outlet: $0, score: Int(quality), blurb: "Fine.")
                    },
                    weeklySales: [], offMarket: false
                ))
            )
        }
        state.products = [
            released("Stride", "fitness", 72, launched: 420),
            released("Stride Pro", "fitness", 66, launched: 500),
            released("Ledger", "finance", 70, launched: 460),
            released("Chord", "music", 58, launched: 520),
        ]
        state.market.standing = ["fitness": 88, "finance": 58, "music": 40, "travel": 12]
        for (topic, multiplier) in [
            "fitness": 1.42, "finance": 0.96, "social": 1.18, "travel": 0.62,
            "food_delivery": 1.0, "education": 1.31, "music": 0.88, "gaming": 1.74,
            "productivity": 0.74, "health": 1.05, "dating": 0.45, "logistics": 0.91,
        ] {
            state.market.topics[topic] = TopicMarket(multiplier: multiplier, lastChange: 0)
        }

        let parallaxID = UUID(uuidString: "00000000-0000-0000-0000-00000000A001")!
        let halcyonID = UUID(uuidString: "00000000-0000-0000-0000-00000000A002")!
        let meridianID = UUID(uuidString: "00000000-0000-0000-0000-00000000A003")!
        func history(from start: Double, to end: Double, weeks: Int = 52) -> [Double] {
            (0..<weeks).map { week in
                let t = Double(week) / Double(weeks - 1)
                let wobble = 3 * sin(Double(week) * 0.9) + 1.5 * cos(Double(week) * 2.3)
                return min(100, max(5, start + (end - start) * t + wobble))
            }
        }
        let parallax = Rival(
            id: parallaxID, name: "Parallax", strength: 46, reputation: 38,
            focusTopicIDs: ["music", "travel"], lastShippedDay: 530, foundedDay: 1,
            appearanceSeed: 0x1A2B,
            products: [
                RivalProduct(id: UUID(), name: "Kite Notes", topicID: "music", typeID: "mobile_app", quality: 55, launchDay: 530, weeklyUnits: 900),
                RivalProduct(id: UUID(), name: "Harbor Loop", topicID: "travel", typeID: "mobile_app", quality: 41, launchDay: 470, weeklyUnits: 400),
                RivalProduct(id: UUID(), name: "Pebble Deck", topicID: "social", typeID: "mobile_app", quality: 48, launchDay: 300, weeklyUnits: 0),
            ],
            personality: .copycat,
            strengthHistory: history(from: 28, to: 46)
        )
        let halcyon = Rival(
            id: halcyonID, name: "Halcyon Systems", strength: 22, reputation: 24,
            focusTopicIDs: ["finance"], lastShippedDay: 510, foundedDay: 200,
            appearanceSeed: 0x3C4D,
            products: [
                RivalProduct(id: UUID(), name: "Anchor Base", topicID: "finance", typeID: "mobile_app", quality: 47, launchDay: 510, weeklyUnits: 500),
            ],
            personality: .poacher,
            strengthHistory: history(from: 40, to: 22, weeks: 30)
        )
        let meridian = Rival(
            id: meridianID, name: "Meridian Works", strength: 95, reputation: 74,
            focusTopicIDs: ["fitness", "finance"], lastShippedDay: 539, foundedDay: 539,
            appearanceSeed: 0xBEEF,
            products: [
                RivalProduct(id: UUID(), name: "Vector Signal", topicID: "fitness", typeID: "mobile_app", quality: 76, launchDay: 539, weeklyUnits: 2_600),
            ],
            personality: .deepPockets, isIncumbent: true,
            strengthHistory: [95, 95]
        )
        state.rivals.rivals = [parallax, halcyon, meridian]
        state.rivals.playerShare = ["fitness": 0.47, "finance": 0.71, "music": 0.53]
        state.rivals.challenges = [CategoryChallenge(
            rivalID: meridianID, topicID: "fitness", productName: "Vector Signal",
            quality: 76, startedDay: 539, settlesDay: 539 + 42, answeredDay: 540
        )]
        state.rivals.lastChallengeDay = ["fitness": 539]
        state.rivals.incumbentFoundedDay = 539
        state.rivals.lastBuyoutDay = 500

        // The history between the studio and its rivals, oldest first.
        let employeeID = state.employees.first?.id ?? UUID()
        state.eventLog += [
            .rivalFounded(rivalID: parallaxID, name: "Parallax", day: 1),
            .rivalFounded(rivalID: halcyonID, name: "Halcyon Systems", day: 200),
            .rivalProductLaunched(rivalID: parallaxID, productName: "Pebble Deck", topicID: "social", quality: 48, day: 300),
            .poachAttempt(rivalID: halcyonID, employeeID: employeeID, offeredWeeklySalary: 1_450, respondByDay: 336, day: 331),
            .employeePoached(employeeID: UUID(), name: "Dev Anand", rivalID: halcyonID, day: 360),
            .rivalCopycat(rivalID: parallaxID, topicID: "music", day: 460),
            .rivalProductLaunched(rivalID: parallaxID, productName: "Harbor Loop", topicID: "travel", quality: 41, day: 470),
            .priceWarStarted(rivalID: parallaxID, topicID: "music", untilDay: 518, day: 490),
            .buyoutOffered(rivalID: parallaxID, amount: 240_000, respondByDay: 505, day: 500),
            .buyoutWithdrawn(rivalID: parallaxID, day: 506),
            .sponsoredContractDelivered(rivalID: halcyonID, topicID: "finance", quality: 71, day: 512),
            .categoryChallenged(rivalID: parallaxID, topicID: "music", productName: "Kite Notes", quality: 55, respondByDay: 572, day: 530),
            .incumbentArrived(rivalID: meridianID, name: "Meridian Works", day: 539),
            .rivalProductLaunched(rivalID: meridianID, productName: "Vector Signal", topicID: "fitness", quality: 76, day: 539),
            .categoryChallenged(rivalID: meridianID, topicID: "fitness", productName: "Vector Signal", quality: 76, respondByDay: 581, day: 539),
        ]
        let engine = GameEngine(state: state, balance: balance, content: content)
        return (engine, [parallax, halcyon], meridian)
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

    // MARK: - The model

    func testTheModelReadsStandingDemandRivalsAndTheFight() throws {
        let (engine, _, incumbent) = Self.fixture()
        let snapshot = MarketMapSnapshot(state: engine.state, content: engine.content, balance: engine.balance)
        let byID = Dictionary(uniqueKeysWithValues: snapshot.input.districts.map { ($0.id, $0) })
        XCTAssertEqual(snapshot.input.districts.count, 12)
        XCTAssertEqual(snapshot.input.districts.map(\.id), engine.content.topics.map(\.id), "districts keep catalog order")

        let fitness = try XCTUnwrap(byID["fitness"])
        XCTAssertEqual(fitness.standing, .household)
        XCTAssertEqual(fitness.playerProducts, 2)
        XCTAssertEqual(fitness.rivalCount, 0, "the incumbent is the fortress, not a flag")
        XCTAssertTrue(fitness.hasFortress)
        XCTAssertTrue(fitness.underSiege)
        XCTAssertNotNil(fitness.weather, "a held category has its forecast")
        XCTAssertGreaterThan(fitness.size, 0.7)

        let finance = try XCTUnwrap(byID["finance"])
        XCTAssertEqual(finance.standing, .established)
        XCTAssertEqual(finance.rivalCount, 1)
        XCTAssertTrue(finance.hasFortress, "the incumbent's second market, before it has shipped there")
        XCTAssertNotNil(finance.weather)

        let music = try XCTUnwrap(byID["music"])
        XCTAssertEqual(music.standing, .known)
        XCTAssertNil(music.weather, "below the threshold there is no read")
        XCTAssertEqual(music.rivalCount, 1)

        XCTAssertEqual(byID["travel"]?.standing, .newcomer)
        XCTAssertEqual(byID["travel"]?.rivalCount, 1)
        XCTAssertEqual(byID["social"]?.rivalCount, 0, "a faded product is not a flag")
        XCTAssertEqual(byID["dating"]?.standing, StandingBand.none)
        XCTAssertEqual(try XCTUnwrap(byID["dating"]).size, 0.0357, accuracy: 0.001, "the coldest market is the smallest district")
        XCTAssertEqual(try XCTUnwrap(byID["gaming"]).size, 0.957, accuracy: 0.001)
        XCTAssertEqual(snapshot.heldCount, 2)

        let summary = try XCTUnwrap(snapshot.summaries["fitness"])
        // R7: the rung moved out of the label and into the district's
        // `accessibilityValue`, where VoiceOver expects a thing's current
        // setting — the label used to say it twice.
        XCTAssertTrue(summary.hasPrefix("Fitness, demand"), summary)
        XCTAssertFalse(summary.contains("household"), "the rung is the value, not the label")
        XCTAssertTrue(
            try XCTUnwrap(byID["fitness"]).accessibilityValue.hasPrefix("household name"),
            "the rung is spoken as the value"
        )
        XCTAssertTrue(summary.contains("2 of your products"), summary)
        XCTAssertTrue(summary.contains("\(incumbent.name) is here"), summary)
        XCTAssertTrue(summary.contains("under challenge"), summary)
        XCTAssertTrue(summary.contains("forecast"), summary)
    }

    func testTheBandsMatchTheCategoryTiers() {
        let balance = Self.balance
        let threshold = balance.market.standing.forecastThreshold
        let max = balance.market.standing.maxStanding
        XCTAssertEqual(MarketMapSnapshot.band(standing: 0, balance: balance), StandingBand.none)
        XCTAssertEqual(MarketMapSnapshot.band(standing: 1, balance: balance), .newcomer)
        XCTAssertEqual(MarketMapSnapshot.band(standing: threshold / 2, balance: balance), .known)
        XCTAssertEqual(MarketMapSnapshot.band(standing: threshold, balance: balance), .established)
        XCTAssertEqual(MarketMapSnapshot.band(standing: max, balance: balance), .household)
        // The same rungs the category rows name.
        var state = GameState.newGame(companyName: "Fixture", seed: 7, balance: balance)
        let topic = Self.content.topics[0]
        for standing in [0.0, 1, threshold / 2, threshold, max] {
            state.market.standing[topic.id] = standing
            let tier = CategorySnapshot(topic: topic, state: state, balance: balance).tier
            let band = MarketMapSnapshot.band(standing: standing, balance: balance)
            XCTAssertEqual(MarketMapSnapshot.tierName(band), tier == "Household name" ? "Household" : tier)
        }
    }

    func testTheWeatherFollowsTheForecastsLean() {
        let market = Self.balance.market
        XCTAssertNil(MarketMapSnapshot.weather(forecast: nil, driftSigma: market.driftSigma))
        // Near the ceiling the band can only lean down; near the floor only up.
        let high = MarketForecast.project(topicID: "t", current: market.multiplierMax, weeks: 3, market: market)
        XCTAssertEqual(MarketMapSnapshot.weather(forecast: high, driftSigma: market.driftSigma), .rain)
        let low = MarketForecast.project(topicID: "t", current: market.multiplierMin, weeks: 3, market: market)
        XCTAssertEqual(MarketMapSnapshot.weather(forecast: low, driftSigma: market.driftSigma), .sunny)
        let middle = MarketForecast.project(topicID: "t", current: 1.0, weeks: 3, market: market)
        XCTAssertEqual(MarketMapSnapshot.weather(forecast: middle, driftSigma: market.driftSigma), .overcast)
        let volatile = MarketForecast(topicID: "t", weeksAhead: 3, current: 1, expected: 1, low: 0.8, high: 1.2, jumpChance: 0.6)
        XCTAssertEqual(MarketMapSnapshot.weather(forecast: volatile, driftSigma: market.driftSigma), .storm)
    }

    func testAFreshGameIsTwelveBareDistricts() {
        let engine = GameEngine.newGame(
            companyName: "Northgate Softworks", seed: 4242, difficulty: .normal,
            founder: FounderProfile(name: "Mira Okafor", archetype: .hacker, appearanceSeed: 0x5EED)
        )
        let snapshot = MarketMapSnapshot(state: engine.state, content: engine.content, balance: engine.balance)
        XCTAssertEqual(snapshot.input.districts.count, 12)
        XCTAssertTrue(snapshot.input.districts.allSatisfy { $0.standing == StandingBand.none && $0.weather == nil && $0.playerProducts == 0 })
        XCTAssertEqual(snapshot.heldCount, 0)
    }

    // MARK: - The screen

    func testRendersTheMarketMapMidGame() {
        let (engine, _, _) = Self.fixture()
        var selected: String?
        snapshot("market_map_midgame") {
            MarketMapScreen(engine: engine) { selected = $0 }
                .environment(AppRouter())
                .environment(GameShell())
        }
        XCTAssertNil(selected)
    }

    // MARK: - The route

    func testTheMarketMapRouteLandsOnTheBusinessTab() {
        let router = AppRouter()
        router.go(.marketMap)
        XCTAssertEqual(router.tab, .business)
        XCTAssertTrue(router.take(.marketMap))
        XCTAssertNil(router.pendingPush)
    }
}
