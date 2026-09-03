import SwiftUI
import TycoonContent
import TycoonEngine
import XCTest

@testable import StartupStudio

/// The category fight and the incumbent on screen: the challenge sheet
/// with the rival's face and the numbers the decision is made of, the
/// incumbent's card with its two markets and the retreat clock, both
/// themes — and the five events as sentences.
@MainActor
final class RivalFightSnapshotTests: XCTestCase {
    private static let content: ContentCatalog = {
        guard let bundled = try? ContentCatalog.loadBundled() else {
            fatalError("TycoonContent is missing its bundled resources")
        }
        return bundled
    }()

    private static let balance: BalanceConfig = {
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

    /// A studio a year in, holding Fitness at 78 with a 66-scoring app,
    /// live in Music too, an incumbent on the board in both — a 71 in
    /// Fitness, nothing in Music yet — and its opening challenge on the
    /// clock, three weeks from settling.
    private func fixture() -> (engine: GameEngine, incumbent: Rival) {
        var state = GameState.newGame(
            companyName: "Northgate Softworks", seed: 4242, balance: Self.balance,
            founder: FounderProfile(name: "Mira Okafor", archetype: .hacker, appearanceSeed: 0x5EED)
        )
        state.day = 371
        let fitness = Product(
            id: UUID(), name: "Stride", typeID: "mobile_app", topicID: "fitness",
            stage: .released(ReleaseInfo(
                launchDay: 300, quality: 66,
                reviews: ["TechDaily", "AppVerdict", "The Stack Review", "ByteSized"].map {
                    Review(outlet: $0, score: 66, blurb: "Polished where it counts.")
                },
                weeklySales: [], offMarket: false
            ))
        )
        let music = Product(
            id: UUID(), name: "Chord", typeID: "mobile_app", topicID: "music",
            stage: .released(ReleaseInfo(
                launchDay: 340, quality: 58,
                reviews: [Review(outlet: "TechDaily", score: 58, blurb: "Fine.")],
                weeklySales: [], offMarket: false
            ))
        )
        state.products = [fitness, music]
        state.market.standing["fitness"] = 78
        state.market.standing["music"] = 52
        let incumbent = Rival(
            id: UUID(), name: "Meridian Works", strength: 95, reputation: 72,
            focusTopicIDs: ["fitness", "music"], lastShippedDay: 364, foundedDay: 364,
            appearanceSeed: 0xBEEF,
            products: [RivalProduct(
                id: UUID(), name: "Kite Notes", topicID: "fitness", typeID: "mobile_app",
                quality: 71, launchDay: 364, weeklyUnits: 2_400
            )],
            personality: .deepPockets, isIncumbent: true
        )
        state.rivals.rivals = [incumbent]
        state.rivals.playerShare = ["fitness": 0.46, "music": 1.0]
        state.rivals.challenges = [CategoryChallenge(
            rivalID: incumbent.id, topicID: "fitness", productName: "Kite Notes",
            quality: 71, startedDay: 364, settlesDay: 364 + 42
        )]
        state.rivals.lastChallengeDay = ["fitness": 364]
        state.rivals.incumbentFoundedDay = 364
        let engine = GameEngine(state: state, balance: Self.balance, content: Self.content)
        return (engine, incumbent)
    }

    private func snapshot(
        _ name: String,
        width: CGFloat = 393,
        height: CGFloat = 560,
        @ViewBuilder _ content: () -> some View
    ) {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let suffix = style == .light ? "light" : "dark"
            let renderer = ImageRenderer(
                content: content()
                    .frame(width: width, height: height)
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

    // MARK: - The challenge sheet

    func testTheChallengeIsThePendingDecisionAndCarriesTheNumbers() throws {
        let (engine, incumbent) = fixture()
        let prompt = try XCTUnwrap(
            DecisionPrompt.pending(in: engine.state, content: engine.content, balance: engine.balance)
        )
        XCTAssertEqual(prompt.kicker, "CHALLENGE")
        XCTAssertEqual(prompt.title, "Meridian Works launched into Fitness")
        XCTAssertEqual(prompt.portraitSeed, incumbent.appearanceSeed)
        XCTAssertTrue(prompt.message.contains("Kite Notes scores 71"), prompt.message)
        XCTAssertTrue(prompt.message.contains("Stride scores 66"), prompt.message)
        XCTAssertTrue(prompt.message.contains("46%"), prompt.message)
        XCTAssertEqual(prompt.stats.map(\.label), ["Your share", "Them · you", "Settles in"])
        XCTAssertEqual(prompt.stats[1].value, "71 · 66")
        XCTAssertEqual(prompt.stats[2].value, "35d")
        // Every answer routes to an action the game already has; the last
        // lets it go. The garage slot is free, so the patch is on offer.
        XCTAssertEqual(prompt.options.map(\.label), ["Cut the price", "Patch Stride", "Run a campaign", "Let it go"])
        XCTAssertEqual(prompt.options.last?.action, .concedeCategory)
        XCTAssertEqual(prompt.options[0].action, .defendCategory(topicID: "fitness", defense: .budgetPrice))
        XCTAssertEqual(prompt.options[1].action, .defendCategory(topicID: "fitness", defense: .patch))
        XCTAssertEqual(prompt.options[2].action, .defendCategory(topicID: "fitness", defense: .campaign))
        XCTAssertEqual(prompt.options[2].cashDelta, -(engine.balance.socialPushDailyCost * engine.balance.socialPushDurationDays))
        XCTAssertFalse(prompt.isDeferrable, "offers stay modal; the six weeks are the deadline")
    }

    func testOnlyTheAnswersThatWouldLandAreOffered() throws {
        let (engine, _) = fixture()
        var state = engine.state
        // The one garage slot taken and the product already budget: two
        // of the three defences are gone, the rest stay.
        _ = Reducer.apply(
            .startProduct(typeID: "mobile_app", topicID: "travel", name: "Next", focus: .balanced),
            to: &state, balance: engine.balance, content: engine.content
        )
        if case .released(var info) = state.products[0].stage {
            info.priceTier = .budget
            state.products[0].stage = .released(info)
        }
        let prompt = try XCTUnwrap(
            DecisionPrompt.pending(in: state, content: engine.content, balance: engine.balance)
        )
        XCTAssertEqual(prompt.options.map(\.label), ["Run a campaign", "Let it go"])
    }

    func testRendersTheChallengeSheetWithTheRivalsFace() throws {
        let (engine, _) = fixture()
        let prompt = try XCTUnwrap(
            DecisionPrompt.pending(in: engine.state, content: engine.content, balance: engine.balance)
        )
        snapshot("decision_challenge", height: 640) {
            DecisionSheetContent(prompt: prompt, engine: engine, choose: { _ in }, postpone: nil)
                .environment(GameShell())
                .environment(AppRouter())
        }
    }

    // MARK: - The incumbent card

    func testRendersTheIncumbentCardWithItsMarketsAndTheClock() {
        let (engine, incumbent) = fixture()
        snapshot("rivals_incumbent_card", height: 720) {
            ScrollView {
                RivalCard(engine: engine, rival: incumbent)
                    .padding()
            }
            .environment(GameShell())
            .environment(AppRouter())
        }
    }

    // MARK: - The desk and the copy

    func testTheChallengeIsOnTheDeskWithItsClock() {
        let (engine, _) = fixture()
        let items = Desk.items(in: engine.state, balance: engine.balance, content: engine.content)
        let row = items.first { $0.id.hasPrefix("challenge-") }
        XCTAssertNotNil(row)
        XCTAssertEqual(row?.daysLeft, 35)
        XCTAssertEqual(row?.route, .rivals)
        XCTAssertTrue(row?.text.contains("Meridian Works is challenging Fitness") == true, row?.text ?? "")
        XCTAssertTrue(row?.text.contains("46%") == true, row?.text ?? "")
    }

    func testTheFiveEventsReadAsSentencesUnderRivals() {
        let (engine, incumbent) = fixture()
        let copy = EventCopy(state: engine.state, content: engine.content, balance: engine.balance)
        let events: [GameEvent] = [
            .categoryChallenged(
                rivalID: incumbent.id, topicID: "fitness", productName: "Kite Notes",
                quality: 71, respondByDay: 406, day: 364
            ),
            .categoryHeld(rivalID: incumbent.id, topicID: "fitness", day: 406),
            .categoryLost(rivalID: incumbent.id, topicID: "fitness", day: 406),
            .incumbentArrived(rivalID: incumbent.id, name: "Meridian Works", day: 364),
            .incumbentRetreated(rivalID: incumbent.id, name: "Meridian Works", day: 546),
        ]
        for event in events {
            let line = copy.line(for: event)
            XCTAssertFalse(line.message.isEmpty, "no message for \(event)")
            XCTAssertNotEqual(line.message, "Something happened", "no copy for \(event)")
            XCTAssertEqual(line.day, EventDay.of(event))
            XCTAssertEqual(copy.category(of: event), .rivals)
        }
        XCTAssertTrue(copy.line(for: events[0]).message.contains("Meridian Works launched Kite Notes into Fitness"))
        XCTAssertTrue(copy.line(for: events[1]).message.contains("You held Fitness"))
        XCTAssertTrue(copy.line(for: events[2]).message.contains("Meridian Works took Fitness"))
    }
}
