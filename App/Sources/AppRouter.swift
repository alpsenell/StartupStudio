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

    // MARK: Iteration 10 — interactive rooms

    // MARK: M1 (feature board)

    /// M1: the board a product is assembled from, for a product still in
    /// development.
    case featureBoard(productID: UUID)

    // MARK: M2 (pitch room)

    /// M2: the Business tab, on whichever segment has somebody waiting to
    /// be talked to — the term sheet, or the offers.
    case pitch

    // MARK: M3 (incident room)

    /// M3: HQ, with the incident room over it. The room only opens when
    /// something is actually on fire; the route is how the Now card's row
    /// and the debug pass ask for it.
    case incidentRoom

    // MARK: M4 (leagues)

    // MARK: M5 (morning desk)

    // MARK: M6 (bug hunt)

    // MARK: end of Iteration 10

    // MARK: Iteration 11 — the founder's darker life

    // MARK: N1 (crime and the courtroom)

    /// N1: the founder's own ledger of things they should not have done,
    /// with the pending case at the top of it. `.courtroom` is the same
    /// screen with the hearing open over it — one route rather than two,
    /// because the room is only ever reachable through the ledger.
    case crimeLedger
    case courtroom
    /// N1: a studio's own profile, opened for the two things that belong
    /// there — the planted story and the suit. Carries no id: it means
    /// "the studio the founder is most likely to be angry at", which is
    /// the first on the board. The in-game link is `.rivalProfile`; this
    /// exists so `-autoRoute suit` can reach a page no command line can
    /// name a UUID for.
    case rivalSuit

    // MARK: N2 (people menus)

    /// The people menu for one person, pushed inside the Life tab.
    case peopleMenu(InteractionTarget)
    /// The Team tab's door onto the same menu: open the manage sheet for
    /// the first person on the roster. Used by `-autoRoute peopleTeam`,
    /// which is the only caller that cannot name an employee id.
    case peopleTeamMenu

    // MARK: N3 (assets, vices and the doctor)

    /// N3: the Life tab, with the founder's own balance sheet — the
    /// garage, the deeds, the household, the wallet games, the doctor and
    /// the habits — pushed over it.
    case assets

    // MARK: N4 (fame and the feed)

    /// N4: the founder's public feed, on the Life tab.
    case feed

    // MARK: N5 (office secrets)

    /// The Team tab, on the thread the office is running.
    case secrets

    // MARK: end of Iteration 11

    // MARK: Iteration 11, wave two

    // MARK: W1 (dirty money)

    /// The Business tab's finances, on whatever the other money is doing.
    case dirtyMoney

    // MARK: W2 (family drama)

    /// W2: the rest of the family, on the Life tab. `.divorce` is the same
    /// room with the settlement open over it — one door rather than two,
    /// because the table is only ever reachable through the room.
    case family
    case divorce

    // MARK: W3 (espionage)

    /// W3: a studio's own page, opened for the five things that belong
    /// there. Carries no id — it means "the studio the founder is most
    /// likely to want something done to", which is the first on the board
    /// — so that `-autoRoute spy` can reach a page no command line can
    /// name a UUID for. The in-game link is `.rivalProfile`.
    case spy

    // MARK: W4 (inside)
    /// What the weeks came to, read after the gate. The sentence itself is
    /// a full-screen mode, not a route.
    case inside

    // MARK: J1 (doors)
    /// J1: one of the four doors, on its sheet of paper. Lands on Life,
    /// which pushes it; reached from the doors' card, their coach tips,
    /// and (once hooked up) the rail's deferred row.
    case door(DoorKind)
    // MARK: end J1
    // MARK: J2 (record)
    // MARK: end J2
    // MARK: J3 (rivals and the market)
    // MARK: end J3
    // MARK: J4 (house field)
    // MARK: end J4
    // MARK: J5 (announce)
    // MARK: end J5
    // MARK: J6 (queue)
    // MARK: end J6
    // MARK: end of Iteration 12
    // MARK: end of Iteration 11, wave two

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

        // MARK: Iteration 10
        // MARK: M1 (feature board)
        case .featureBoard: .products
        // MARK: M2 (pitch room)
        case .pitch: .business
        // MARK: M3 (incident room)
        case .incidentRoom: .hq
        // MARK: M4 (leagues)
        // MARK: M5 (morning desk)
        // MARK: M6 (bug hunt)
        // MARK: end of Iteration 10

        // MARK: Iteration 11
        // MARK: N1 (crime and the courtroom)
        case .crimeLedger, .courtroom: .life
        case .rivalSuit: .business
        // MARK: N2 (people menus)
        case .peopleMenu: .life
        case .peopleTeamMenu: .team
        // MARK: N3 (assets, vices and the doctor)
        case .assets: .life
        // MARK: N4 (fame and the feed)
        case .feed: .life
        // MARK: N5 (office secrets)
        case .secrets: .team
        // MARK: end of Iteration 11

        // MARK: Iteration 11, wave two
        // MARK: W1 (dirty money)
        case .dirtyMoney: .business
        // MARK: W2 (family drama)
        case .family, .divorce: .life
        // MARK: W3 (espionage)
        case .spy: .business
        // MARK: W4 (inside)
        case .inside: .life
        // MARK: J1 (doors)
        case .door: .life
        // MARK: end J1
        // MARK: J2 (record)
        // MARK: end J2
        // MARK: J3 (rivals and the market)
        // MARK: end J3
        // MARK: J4 (house field)
        // MARK: end J4
        // MARK: J5 (announce)
        // MARK: end J5
        // MARK: J6 (queue)
        // MARK: end J6
        // MARK: end of Iteration 12
        // MARK: end of Iteration 11, wave two
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
