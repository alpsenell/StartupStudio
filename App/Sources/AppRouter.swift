import Observation
import SwiftUI

/// The five tabs of the game.
enum GameTab: Hashable {
    case hq
    case life
    case team
    case products
    case business
}

/// A destination inside a tab, for cross-tab deep links ("go hire
/// someone", "open the market report for fitness"). Every screen that used
/// to tell the player to "go to the Team tab" now hands them one of these.
enum Route: Hashable {
    case hiring
    case research
    case product(UUID)
    case contracts
    case marketReport(topicID: String)
    case market
    case finances
    case marketing
    case life
    /// Opens the new-product flow, optionally with a topic already chosen
    /// (a market screen saying "start a product in Dating"). Iteration 4
    /// seam: the first coach tip, HQ's Now card and the topic detail all
    /// route here.
    case newProduct(topicID: String?)
    /// The two Business sections that had no deep link: a goal about
    /// raising a round or buying a rival needs somewhere to send you.
    case investors
    case rivals

    /// The tab this destination lives in.
    var tab: GameTab {
        switch self {
        case .hiring: .team
        case .research, .product, .newProduct: .products
        case .contracts, .marketReport, .market, .finances, .marketing, .investors, .rivals: .business
        case .life: .life
        }
    }
}

/// Cross-tab navigation, injected into the environment at the app root.
///
/// `go(_:)` switches to the destination's tab and leaves the route in
/// `pendingPush` for that tab's root to consume — a screen calls
/// `router.take(.hiring)` when it appears, which both answers "was I
/// deep-linked?" and clears the request so a later redraw doesn't push
/// twice.
@Observable
final class AppRouter {
    /// The tab currently on screen.
    var tab: GameTab = .hq
    /// A destination the frontmost tab should push as soon as it appears.
    var pendingPush: Route?

    init(tab: GameTab = .hq) {
        self.tab = tab
    }

    /// Switches to `route`'s tab and queues the destination.
    func go(_ route: Route) {
        tab = route.tab
        pendingPush = route
    }

    /// Consumes a pending push if it matches `route`, returning whether it
    /// did. Screens call this from `onAppear`/`onChange`.
    @discardableResult
    func take(_ route: Route) -> Bool {
        guard pendingPush == route else { return false }
        pendingPush = nil
        return true
    }

    /// Consumes a pending push if it matches `predicate`, returning the
    /// matched route. For screens that handle a family of routes (a
    /// product id, a topic id).
    func take(where predicate: (Route) -> Bool) -> Route? {
        guard let pending = pendingPush, predicate(pending) else { return nil }
        pendingPush = nil
        return pending
    }
}
