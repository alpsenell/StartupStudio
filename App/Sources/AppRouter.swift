import Observation
import SwiftUI
// Iteration 9 — L1: `Route.phoneThread` names a `PhoneCounterpart`.
import TycoonEngine

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
    /// The city map, which the office card on HQ opens: a goal about
    /// buying the office needs somewhere to send you (WS-G).
    case city

    // MARK: Iteration 6 — new surfaces

    // Scaffolded so seven lanes never edit this enum at once. Each lane's
    // tab root consumes its own route with `router.take`.

    /// The launch-week war room for the build that is about to ship (U1).
    case warRoom
    /// This week's front page (U2).
    case newspaper
    /// The company's timeline (U2).
    case timeline
    /// The market as a map (U3).
    case marketMap
    /// One rival's profile (U3).
    case rivalProfile(rivalID: UUID)
    /// The week ahead (U5).
    case agenda
    /// The org chart (U5).
    case orgChart
    /// A product's storefront page (U6).
    case storefront(productID: UUID)

    // MARK: Iteration 9 — the Life tab

    // Each lane appends its route between its own markers and adds the
    // same route to the tab switch below, inside its markers there.

    // MARK: L1 (phone)
    /// The founder's phone: every thread.
    case phone
    /// One conversation.
    case phoneThread(counterpart: PhoneCounterpart)

    // MARK: L2 (life score)

    /// The founder's own number and its breakdown (L2).
    case lifeScore

    // MARK: L3 (children)

    /// The kids, at whatever age they are today (L3).
    case children

    // MARK: L4 (friends)
    /// The founder's three friends (L4).
    case friends

    // MARK: L5 (side project)
    /// The thing the founder is building that is not the company (L5).
    case sideProject

    // MARK: L6 (sabbatical)

    /// Handing the company over and going away (L6).
    case sabbatical

    // MARK: L7 (furnish)

    /// L7: the Life tab, with the furnish sheet open on the home card.
    case furnish

    // MARK: end of Iteration 9

    /// The tab this destination lives in.
    var tab: GameTab {
        switch self {
        case .hiring: .team
        case .research, .product, .newProduct: .products
        case .contracts, .marketReport, .market, .finances, .marketing, .investors, .rivals: .business
        case .life: .life
        case .city: .hq
        // Iteration 6
        case .warRoom, .storefront: .products
        case .newspaper, .timeline: .hq
        case .marketMap, .rivalProfile: .business
        case .agenda: .life
        case .orgChart: .team

        // MARK: Iteration 9 — the Life tab
        // MARK: L1 (phone)
        case .phone, .phoneThread: .life
        // MARK: L2 (life score)
        case .lifeScore: .life
        // MARK: L3 (children)
        case .children: .life
        // MARK: L4 (friends)
        case .friends: .life
        // MARK: L5 (side project)
        case .sideProject: .life
        // MARK: L6 (sabbatical)
        case .sabbatical: .life
        // MARK: L7 (furnish)
        case .furnish: .life
        // MARK: end of Iteration 9
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
