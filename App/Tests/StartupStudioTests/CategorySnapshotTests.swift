import TycoonContent
import TycoonEngine
import XCTest

@testable import StartupStudio

/// The view model behind the Category strip, the new-product topic step and
/// the topic detail. The rule these tests protect is that the forward read
/// is the *reward*: it appears in a category the studio holds and nowhere
/// else, and where it is absent the copy says what it would take rather
/// than showing an empty row.
final class CategorySnapshotTests: XCTestCase {
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

    private func makeState() -> GameState {
        GameState.newGame(companyName: "Fixture Softworks", seed: 7, balance: Self.balance)
    }

    private func topic() -> TopicDef {
        guard let first = Self.content.topics.first else {
            fatalError("The bundled catalog has no topics")
        }
        return first
    }

    private func snapshot(standing: Double, state: GameState? = nil) -> CategorySnapshot {
        var state = state ?? makeState()
        state.market.standing[topic().id] = standing
        return CategorySnapshot(topic: topic(), state: state, balance: Self.balance)
    }

    func testAnUntouchedCategoryReadsAsNoPresence() {
        let category = CategorySnapshot(
            topic: topic(), state: makeState(), balance: Self.balance
        )
        XCTAssertEqual(category.standing, 0)
        XCTAssertEqual(category.standingFraction, 0)
        XCTAssertEqual(category.tier, "No presence")
        XCTAssertFalse(category.holdsCategory)
        XCTAssertNil(category.forecast)
    }

    func testTheForwardReadArrivesExactlyAtTheThreshold() {
        let threshold = Self.balance.market.standing.forecastThreshold
        let below = snapshot(standing: threshold - 1)
        XCTAssertNil(below.forwardRead(driftSigma: Self.balance.market.driftSigma))
        XCTAssertFalse(below.holdsCategory)

        let held = snapshot(standing: threshold)
        XCTAssertTrue(held.holdsCategory)
        let read = held.forwardRead(driftSigma: Self.balance.market.driftSigma)
        XCTAssertNotNil(read)
        // The read has to name the horizon and the odds, or it is decoration.
        XCTAssertTrue(
            read?.contains("\(Self.balance.market.forecastHorizonWeeks) weeks out") == true,
            "the forward read did not name its horizon: \(read ?? "nil")"
        )
        XCTAssertTrue(read?.contains("%") == true)
    }

    func testTheTiersClimbWithStanding() {
        let max = Self.balance.market.standing.maxStanding
        let tiers = [0, 1, max / 2, max].map { snapshot(standing: $0).tier }
        XCTAssertEqual(tiers.first, "No presence")
        XCTAssertEqual(tiers.last, "Household name")
        XCTAssertEqual(Set(tiers).count, tiers.count, "two standings share a tier name")
    }

    func testTheFieldLabelNamesWhoIsActuallyInTheCategory() {
        var state = makeState()
        XCTAssertEqual(
            snapshot(standing: 10, state: state).fieldLabel,
            "Nobody is selling here"
        )

        state.products.append(Product(
            id: UUID(), name: "Gizmo", typeID: Self.content.productTypes[0].id,
            topicID: topic().id,
            stage: .released(ReleaseInfo(
                launchDay: 0, quality: 70,
                reviews: [Review(outlet: "TechDaily", score: 70, blurb: "")],
                weeklySales: [], offMarket: false, hypeAtLaunch: 0, adoptionWeeks: 1
            ))
        ))
        XCTAssertEqual(snapshot(standing: 10, state: state).fieldLabel, "Yours alone")
    }

    func testTheOrderPutsTheCategoriesYouHoldFirst() {
        var state = makeState()
        let topics = Self.content.topics
        XCTAssertGreaterThan(topics.count, 2, "this test needs a real catalog")
        state.market.standing[topics[2].id] = 80
        state.market.standing[topics[1].id] = 40

        let ordered = MarketAnalysis.categories(
            state: state, content: Self.content, balance: Self.balance
        )
        XCTAssertEqual(ordered.count, topics.count)
        XCTAssertEqual(ordered[0].id, topics[2].id)
        XCTAssertEqual(ordered[1].id, topics[1].id)
    }
}
