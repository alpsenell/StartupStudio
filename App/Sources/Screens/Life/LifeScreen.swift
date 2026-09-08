import SwiftUI
import TycoonEngine

/// The Life tab, in the order the founder's week runs: this week's
/// decisions first, then the people in it, then the money and the home,
/// then the founder's own sheet.
///
/// The home scene used to lead and the weekly cards sat fourth, sixth,
/// seventh and ninth in a twelve-card stack; now the week is the first
/// card and the rest is grouped under headers.
struct LifeScreen: View {
    let engine: GameEngine

    @Environment(AppRouter.self) private var router
    @State private var path: [LifeDestination] = []
    /// Whether the debug `-autoRoute` landing has already been taken.
    @State private var tookLaunchRoute = false
    // MARK: Iteration 11 — N1 (crime and the courtroom)
    /// Whether the hearing is open over the ledger. Held here rather than
    /// in `CrimeScreen` so `-autoRoute courtroom` can set it as it pushes.
    @State private var showingCourtroom = false
    // MARK: end of Iteration 11 — N1

    /// What Life can push. One case today; an enum rather than a
    /// `NavigationPath` so the deep link can ask "am I already there?".
    enum LifeDestination: Hashable {
        case agenda

        // MARK: Iteration 9 — one destination per lane that pushes a screen
        // MARK: L1 (phone)
        case phone
        case phoneThread(PhoneCounterpart)
        // MARK: L2 (life score)
        case lifeScore
        // MARK: L3 (children)
        case children
        // MARK: L4 (friends)
        case friends
        // MARK: L5 (side project)
        case sideProject
        // MARK: L6 (sabbatical)
        case sabbatical
        // MARK: L7 (furnish)
        // MARK: end of Iteration 9
        // MARK: Iteration 11
        // MARK: N1 (crime and the courtroom)
        case crime
        // MARK: N2 (people menus)
        /// One person's whole menu, pushed. The sheet is the usual door
        /// (`PeopleMenuButton` on each card); this is the deep link's.
        case people(InteractionTarget)
        // MARK: N3 (assets, vices and the doctor)
        // MARK: N4 (fame and the feed)
        case feed
        // MARK: end of Iteration 11
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // The fortnight leads: it is the only card that answers
                    // "what is coming" — everything under it answers "what
                    // is true now".
                    AgendaCard(
                        engine: engine,
                        onOpen: { path = [.agenda] },
                        onRoute: { router.go($0) }
                    )
                    ThisWeekCard(engine: engine)
                    // Iteration 9 — L1: the phone card goes here, under the
                    // week, because a message is the next thing to answer.
                    // MARK: L1 (phone)
                    PhoneCard(
                        engine: engine,
                        onOpen: { path = [.phone] },
                        onOpenThread: { path = [.phone, .phoneThread($0)] }
                    )

                    BusinessSectionHeader(title: "This week", systemImage: "calendar")
                    ActivitiesCard(engine: engine)
                    WeekendCard(engine: engine)
                    WeekendRecapCard(engine: engine)
                    // The networking floor and the address book. Placed
                    // after the weekend plan, which is what opens a room.
                    NetworkingCard(engine: engine)

                    BusinessSectionHeader(title: "People", systemImage: "person.2.fill")
                    PartnerCard(engine: engine)
                    FamilyCard(engine: engine)
                    // Iteration 9 — L3 owns FamilyCard.swift (the children
                    // draw there); L4 adds the friends card after it.
                    // MARK: L3 (children)
                    ChildrenLink(onOpen: { path = [.children] })
                    // MARK: L4 (friends)
                    FriendsCard(engine: engine) { path = [.friends] }

                    BusinessSectionHeader(title: "Money and home", systemImage: "house.fill")
                    MoneyCard(engine: engine)
                    HomeCard(engine: engine)
                    PossessionsCard(engine: engine)
                    // Iteration 9 — L7 owns HomeCard.swift and
                    // ShoppingSheet.swift (furnishing opens from the home).
                    // MARK: L7 (furnish)

                    BusinessSectionHeader(title: "You", systemImage: "person.fill")
                    FounderSkillsCard(engine: engine)
                    LifeMetersCard(engine: engine)
                    // Iteration 9 — the founder's own sheet grows three
                    // cards, in this order.
                    // MARK: L2 (life score)
                    LifeScoreCard(engine: engine, onOpen: { path = [.lifeScore] })
                    // MARK: L5 (side project)
                    SideProjectCard(engine: engine) { path = [.sideProject] }
                    // MARK: L6 (sabbatical)
                    SabbaticalCard(engine: engine, onOpen: { path = [.sabbatical] })
                    // MARK: Iteration 11 — new cards, in this order
                    // MARK: N1 (crime and the courtroom)
                    CrimeCard(engine: engine) { path = [.crime] }
                    // MARK: N3 (assets, vices and the doctor)
                    // MARK: N4 (fame and the feed)
                    FameCard(engine: engine) { path = [.feed] }
                    // MARK: end of Iteration 11
                }
                .padding(Theme.Spacing.lg)
            }
            // The HUD inset lives on the stack's root content (not on the
            // NavigationStack) so the root scrolls below it and any pushed
            // destination shows the navigation bar instead.
            .withTopHUD(engine: engine)
            .background(Theme.screenBackground)
            .navigationTitle("Life")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: LifeDestination.self) { destination in
                switch destination {
                case .agenda:
                    AgendaScreen(engine: engine)

                // MARK: Iteration 9
                // MARK: L1 (phone)
                case .phone:
                    PhoneScreen(engine: engine) { path.append(.phoneThread($0)) }
                case .phoneThread(let counterpart):
                    ThreadView(engine: engine, counterpart: counterpart)
                // MARK: L2 (life score)
                case .lifeScore:
                    LifeScoreScreen(engine: engine)
                // MARK: L3 (children)
                case .children:
                    ChildrenScreen(engine: engine)
                // MARK: L4 (friends)
                case .friends:
                    FriendsScreen(engine: engine)
                // MARK: L5 (side project)
                case .sideProject:
                    SideProjectScreen(engine: engine)
                // MARK: L6 (sabbatical)
                case .sabbatical:
                    SabbaticalScreen(engine: engine)
                // MARK: L7 (furnish)
                // MARK: end of Iteration 9
                // MARK: Iteration 11
                // MARK: N1 (crime and the courtroom)
                case .crime:
                    CrimeScreen(engine: engine, showingCourtroom: $showingCourtroom)
                // MARK: N2 (people menus)
                case .people(let target):
                    PeopleMenuScreen(engine: engine, target: target)
                // MARK: N3 (assets, vices and the doctor)
                // MARK: N4 (fame and the feed)
                case .feed:
                    FeedScreen(engine: engine)
                // MARK: end of Iteration 11
                }
            }
            .onChange(of: router.pendingPush, initial: true) { _, _ in
                consumeRoute()
            }
        }
    }

    /// Deep links into this tab: `.agenda` pushes the fortnight, and
    /// `.life` — which the agenda's own diary rows send — means "the Life
    /// tab itself", so it pops back to the root.
    private func consumeRoute() {
        // MARK: Iteration 11 — a launch route per lane, consumed first
        // MARK: N1 (crime and the courtroom)
        // `-autoCase` starts here rather than in a `.task`: a pass that
        // lands on Life with a decision sheet already up never runs the
        // root's tasks, and `consumeRoute` is called from an
        // `onChange(initial: true)` that does. No-ops without the flag.
        CrimeDebug.startIfAsked(engine: engine)
        // Both of N1's routes land on the ledger; `.courtroom` opens the
        // hearing over it, which is the only way into the room.
        if router.pendingPush == .crimeLedger || router.pendingPush == .courtroom {
            let wantsRoom = router.pendingPush == .courtroom
            path = [.crime]
            showingCourtroom = wantsRoom
            router.take(wantsRoom ? .courtroom : .crimeLedger)
            return
        }
        if !tookLaunchRoute,
           Route.launchRoute == .crimeLedger || Route.launchRoute == .courtroom {
            tookLaunchRoute = true
            path = [.crime]
            // `-autoRoute courtroom` lands on the ledger and lets
            // `CrimeDebug.openWhenListed` open the room the day the case
            // is actually called — opening an empty room at launch would
            // put a sheet with nothing in it over the whole pass.
            return
        }
        // MARK: end of Iteration 11 — N1
        // MARK: N2 (people menus)
        // `-autoRoute people` opens the partner's menu; on a run with no
        // partner it falls through to the first child and then the first
        // friend, so the flag always lands on somebody.
        func peopleTarget(_ requested: InteractionTarget) -> InteractionTarget? {
            // `-autoPeopleKind employee` overrides the partner default, so
            // a screenshot pass can photograph any of the six menus.
            let wanted: InteractionTarget? = switch DebugLaunch.autoPeopleKind {
            case .partner: .partner
            case .child: engine.state.life.family.children.first.map { .child($0.id) }
            case .friend: engine.state.friendRoster(content: engine.content).first.map { .friend($0.id) }
            case .employee: engine.state.employees.first { !$0.isFounder }.map { .employee($0.id) }
            case .contact: engine.state.networking.contacts.first.map { .contact($0.id) }
            case .rival: engine.state.rivals.rivals.first.map { .rival($0.id) }
            case nil: nil
            }
            if let wanted, engine.state.interactionBar(wanted, content: engine.content) != nil { return wanted }
            if engine.state.interactionBar(requested, content: engine.content) != nil { return requested }
            if let child = engine.state.life.family.children.first { return .child(child.id) }
            if let friend = engine.state.life.friends.friends.first { return .friend(friend.id) }
            if let employee = engine.state.employees.first(where: { !$0.isFounder }) {
                return .employee(employee.id)
            }
            return nil
        }
        if !tookLaunchRoute, let launch = Route.launchRoute,
           case .peopleMenu(let requested) = launch {
            tookLaunchRoute = true
            if let target = peopleTarget(requested) { path = [.people(target)] }
            return
        }
        if let route = router.take(where: { if case .peopleMenu = $0 { true } else { false } }),
           case .peopleMenu(let requested) = route {
            if let target = peopleTarget(requested) { path = [.people(target)] }
            return
        }
        // MARK: N3 (assets, vices and the doctor)
        // MARK: N4 (fame and the feed)
        // `-autoRoute feed` lands on the founder's feed, once. It is
        // consumed before the shared landing below so `-autoFame`'s
        // posting loop has its screen from the first frame.
        if !tookLaunchRoute, Route.launchRoute == .feed {
            tookLaunchRoute = true
            path = [.feed]
            return
        }
        // The router's own pushes, from the fame card's toast and from
        // anywhere else that says "go and look at the feed".
        if router.take(.feed) {
            path = [.feed]
            return
        }
        // MARK: end of Iteration 11
        // A headless screenshot pass cannot tap: `-autoRoute agenda` lands
        // on the fortnight, once.
        if !tookLaunchRoute {
            tookLaunchRoute = true
            if Route.launchRoute == .agenda {
                path = [.agenda]
                return
            }
            // MARK: L5 (side project)
            if Route.launchRoute == .sideProject {
                path = [.sideProject]
                return
            }
            // MARK: end L5 (side project)
            // MARK: Iteration 9 — L2 (life score)
            if Route.launchRoute == .lifeScore {
                path = [.lifeScore]
                return
            }
            // MARK: end of Iteration 9
            // MARK: Iteration 9 — L4 (friends)
            // The scaffold marked the cards, the destinations and the
            // destination switch but not this function, and a route that
            // nothing consumes is a route that does not work. One line
            // per lane, in its own region.
            if Route.launchRoute == .friends {
                path = [.friends]
                return
            }
            // MARK: end of Iteration 9 — L4
            // MARK: Iteration 9 — L1 (phone)
            if Route.launchRoute == .phone {
                path = [.phone]
                if DebugLaunch.opensNewestPhoneThread {
                    let threads = engine.state.life.phone.byRecency
                    let index = max(0, DebugLaunch.phoneThreadIndex)
                    if threads.indices.contains(index) {
                        path.append(.phoneThread(threads[index].counterpart))
                    }
                }
                return
            }
            // MARK: end L1
            // MARK: L6 (sabbatical)
            if Route.launchRoute == .sabbatical {
                path = [.sabbatical]
                return
            }
            // MARK: end L6
        }
        // MARK: L5 (side project)
        if router.take(.sideProject) {
            path = [.sideProject]
            return
        }
        // MARK: end L5 (side project)
        // MARK: Iteration 9 — L1 (phone)
        if router.take(.phone) {
            path = [.phone]
            return
        }
        if let route = router.take(where: { if case .phoneThread = $0 { true } else { false } }),
           case .phoneThread(let counterpart) = route {
            path = [.phone, .phoneThread(counterpart)]
            return
        }
        // MARK: end L1
        if router.take(.agenda) {
            path = [.agenda]
        // MARK: Iteration 9 — L2 (life score)
        } else if router.take(.lifeScore) {
            path = [.lifeScore]
        // MARK: end of Iteration 9
        } else if router.take(.life) {
            path = []
        // MARK: Iteration 9 — L4 (friends)
        } else if router.take(.friends) {
            path = [.friends]
        // MARK: end of Iteration 9 — L4
        // MARK: L6 (sabbatical)
        } else if router.take(.sabbatical) {
            path = [.sabbatical]
        // MARK: end L6
        }
    }
}
