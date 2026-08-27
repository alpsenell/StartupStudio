import XCTest

@testable import StartupStudio

/// The router is what turned "go to the Team tab" into a button; a route
/// that is consumed twice pushes twice, and one that is never consumed
/// pushes forever.
final class AppRouterTests: XCTestCase {
    func testGoSwitchesToTheDestinationsTab() {
        let router = AppRouter()
        router.go(.hiring)
        XCTAssertEqual(router.tab, .team)
        XCTAssertEqual(router.pendingPush, .hiring)

        router.go(.research)
        XCTAssertEqual(router.tab, .products)

        router.go(.marketReport(topicID: "fitness"))
        XCTAssertEqual(router.tab, .business)

        router.go(.life)
        XCTAssertEqual(router.tab, .life)
    }

    func testTakeConsumesOnlyItsOwnRoute() {
        let router = AppRouter()
        router.go(.contracts)

        XCTAssertFalse(router.take(.hiring))
        XCTAssertEqual(router.pendingPush, .contracts, "a mismatch must not swallow the route")

        XCTAssertTrue(router.take(.contracts))
        XCTAssertNil(router.pendingPush)
        XCTAssertFalse(router.take(.contracts), "a route is consumed exactly once")
    }

    func testTakeWhereMatchesAFamilyOfRoutes() {
        let router = AppRouter()
        let productID = UUID()
        router.go(.product(productID))

        let unmatched = router.take { route in
            if case .marketReport = route { return true } else { return false }
        }
        XCTAssertNil(unmatched)
        XCTAssertNotNil(router.pendingPush)

        let matched = router.take { route in
            if case .product = route { return true } else { return false }
        }
        XCTAssertEqual(matched, .product(productID))
        XCTAssertNil(router.pendingPush)
    }

    func testEveryRouteHasATab() {
        // A route with no home would deep-link into nothing.
        let routes: [Route] = [
            .hiring, .research, .product(UUID()), .contracts,
            .marketReport(topicID: "fitness"), .market, .finances, .marketing, .life,
        ]
        for route in routes {
            XCTAssertNotNil(GameTab.allTabs.firstIndex(of: route.tab), "\(route) has no tab")
        }
    }
}

extension GameTab {
    /// Every tab, for the coverage check above.
    static let allTabs: [GameTab] = [.hq, .life, .team, .products, .business]
}
