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
    // MARK: Iteration 11, wave two — W2 (family drama)
    /// Whether the settlement is open over the family room. Held here for
    /// the same reason the courtroom is: `-autoRoute divorce` sets it as
    /// it pushes.
    @State private var showingDivorce = false
    // MARK: end of Iteration 11, wave two — W2

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
        case assets
        // MARK: N4 (fame and the feed)
        case feed
        // MARK: Iteration 11, wave two
        // MARK: W1 (dirty money)
        // MARK: W2 (family drama)
        case family
        // MARK: W3 (espionage)
        // MARK: W4 (inside)
        case inside
        // MARK: J1 (doors)
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
        // MARK: P1 (purchases: engine)
        // MARK: end P1
        // MARK: P2 (purchases: StoreKit and the session)
        // MARK: end P2
        // MARK: P3 (purchases: surfaces and copy)
        // MARK: end P3
        // MARK: U1 (ux: the first-hour fixes)
        // MARK: end U1
        // MARK: V1 (ux: Life folded, rooms dormant)
        /// A person who had a card and no page: People's row pushes the
        /// card, on its own (`LifeCardPageView`).
        case lifeCard(LifeCardPage)
        // MARK: end V1
        // MARK: V2 (ux: one inbox, one home per thing)
        // MARK: end V2
        // MARK: V3 (ux: card weights, the Now card)
        // MARK: end V3
        // MARK: K1 (founder money)
        // MARK: end K1
        // MARK: K2 (product lifecycle)
        // MARK: end K2
        // MARK: K3 (the ladder)
        // MARK: end K3
        // MARK: K4 (deals and exits)
        // MARK: end K4
        // MARK: K5 (hand over the keys)
        // MARK: end K5
        // MARK: K6 (home and rooms)
        // MARK: end K6
        // MARK: K7 (partner and diary)
        // MARK: end K7
        // MARK: end of Iteration 15
        // MARK: end of Iteration 14
        // MARK: end of Iteration 13
        // MARK: end of Iteration 12
        // MARK: end of Iteration 11, wave two
        // MARK: end of Iteration 11
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // MARK: V1 (ux: Life folded, rooms dormant) — the five sections
                    // Iteration 14 — C1. Twenty-five peers under four
                    // headers became five folded sections: the week, the
                    // people, the money and the home, the founder's own
                    // sheet, and the rooms. Every card below is still the
                    // card it was; a section is what it folds into, and a
                    // row is what a person or a room folds into. Pushes do
                    // not depend on any of this: `consumeRoute` is as it
                    // was.
                    let state = engine.state
                    let rooms = LifeRoom.allCases
                    let openRooms = rooms.filter { $0.isOpen(in: state, balance: engine.balance) }
                    let waitingRooms = openRooms.filter { $0.isWaiting(in: state, balance: engine.balance) }
                    let dormantRooms = rooms.filter { !$0.isOpen(in: state, balance: engine.balance) }
                    let doors = state.doors.open(on: state.day).count
                    let asking = LifeSummary.asking(state, content: engine.content)

                    // This week: the fortnight and "Your week" as one card
                    // (both types kept, the fortnight nested), then what
                    // has to be answered, then today's activities.
                    LifeSection(.thisWeek, summary: LifeSummary.thisWeek(engine), badge: doors) {
                        ThisWeekCard(
                            engine: engine,
                            fortnight: AgendaCard(
                                engine: engine,
                                onOpen: { path = [.agenda] },
                                onRoute: { router.go($0) },
                                nested: true
                            )
                        )
                        // MARK: J1 (doors)
                        // The doors waiting on an answer, under the week
                        // they are due in. Nothing at all while none is
                        // open.
                        DoorsCard(engine: engine) { path = [.door($0)] }
                        // MARK: end J1
                        // MARK: W4 (inside)
                        // Nothing at all until a court has sent the founder
                        // down; the card draws itself only while
                        // `state.prison` is non-nil.
                        InsideCard(engine: engine) { path = [.inside] }
                        ActivitiesCard(engine: engine)
                        // The weekend's plan and last weekend's recap, one
                        // row: "Your week" already says what is planned,
                        // and the eight-option grid is a Friday decision.
                        LifeUnfold(
                            "weekend",
                            title: "The weekend",
                            systemImage: "sun.horizon.fill",
                            value: "\(state.life.plannedActivity.displayName) planned"
                        ) {
                            VStack(spacing: Theme.Spacing.lg) {
                                WeekendCard(engine: engine)
                                WeekendRecapCard(engine: engine)
                            }
                        }
                    } hooks: {
                        InsideCard(engine: engine) { path = [.inside] }
                    }

                    // People: one row each, one number each, each pushing
                    // its page. L1's phone, L4's friends, the partner, the
                    // family (L3's children are on its page) and the
                    // networking floor.
                    LifeSection(.people, summary: LifeSummary.people(engine), badge: asking) {
                        peopleRows
                    }

                    // Money and home. `-autoRoute city|furnish|loftpack`
                    // open their sheets from the home card, so a launch
                    // that asks for one opens the section with it.
                    LifeSection(
                        .moneyHome,
                        summary: LifeSummary.money(engine),
                        forcedOpen: DebugLaunch.launchRoute.map { ["city", "furnish", "loftpack"].contains($0) } ?? false
                    ) {
                        MoneyCard(engine: engine)
                        // MARK: L7 (furnish)
                        HomeCard(engine: engine)
                        PossessionsCard(engine: engine)
                    }

                    // You: the attributes and the meters.
                    LifeSection(.you, summary: LifeSummary.you(engine)) {
                        FounderSkillsCard(engine: engine)
                        LifeMetersCard(engine: engine)
                    }

                    // More of your life: the rooms (L2, L5, L6, N1, N3,
                    // N4, W2). C2: an open room is a row that unfolds to
                    // its card, lit while it waits on you, those that wait
                    // first; a room nobody has opened is a quiet row under
                    // "Other rooms". Every card stays in the hierarchy
                    // (drawn, folded or as a hook) so its debug hooks run.
                    LifeSection(
                        .more,
                        summary: LifeSummary.more(
                            open: openRooms.count, waiting: waitingRooms.count,
                            dormant: dormantRooms.count, doors: 0
                        ),
                        badge: waitingRooms.count
                    ) {
                        ForEach(waitingRooms + openRooms.filter { !waitingRooms.contains($0) }) { room in
                            LifeRoomBlock(room: room, engine: engine) { roomCard(room) }
                        }
                        if !dormantRooms.isEmpty {
                            LifeOtherRooms(rooms: dormantRooms, onOpen: { path = [$0.destination] }) {
                                ForEach(dormantRooms) { roomCard($0) }
                            }
                        }
                    } hooks: {
                        ForEach(rooms) { roomCard($0) }
                    }
                    // MARK: end V1 — the five sections
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
                    // MARK: P1 (purchases: engine)
                    // MARK: end P1
                    // MARK: P2 (purchases: StoreKit and the session)
                    // MARK: end P2
                    // MARK: P3 (purchases: surfaces and copy)
                    // MARK: end P3
                    // MARK: U1 (ux: the first-hour fixes)
                    // MARK: end U1
                    // MARK: V1 (ux: Life folded, rooms dormant)
                    // MARK: end V1
                    // MARK: V2 (ux: one inbox, one home per thing)
                    // MARK: end V2
                    // MARK: V3 (ux: card weights, the Now card)
                    // MARK: end V3
                    // MARK: K1 (founder money)
                    // MARK: end K1
                    // MARK: K2 (product lifecycle)
                    // MARK: end K2
                    // MARK: K3 (the ladder)
                    // MARK: end K3
                    // MARK: K4 (deals and exits)
                    // MARK: end K4
                    // MARK: K5 (hand over the keys)
                    // MARK: end K5
                    // MARK: K6 (home and rooms)
                    // MARK: end K6
                    // MARK: K7 (partner and diary)
                    // MARK: end K7
                    // MARK: end of Iteration 15
                    // MARK: end of Iteration 14
                    // MARK: end of Iteration 13
                    // MARK: end of Iteration 12
                    // MARK: end of Iteration 11, wave two
                    // MARK: end of Iteration 11
                }
                .padding(Theme.Spacing.lg)
                // MARK: V1 (ux: Life folded, rooms dormant)
                // L3's children route: a zero-height view that pushes the
                // children's page on `.children`. It used to sit between
                // two cards; it keeps its place in the hierarchy here,
                // whatever is folded.
                .background { ChildrenLink(onOpen: { path = [.children] }) }
                // `-autoLifeOffset`: photograph below the fold.
                .offset(y: -DebugLaunch.lifeOffset)
                // MARK: end V1
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
                case .assets:
                    AssetsScreen(engine: engine)
                // MARK: N4 (fame and the feed)
                case .feed:
                    FeedScreen(engine: engine)
                // MARK: Iteration 11, wave two
                // MARK: W1 (dirty money)
                // MARK: W2 (family drama)
                case .family:
                    FamilyDramaScreen(engine: engine, showingDivorce: $showingDivorce)
                // MARK: W3 (espionage)
                // MARK: W4 (inside)
                case .inside:
                    InsideReleaseScreen(engine: engine)
                // MARK: J1 (doors)
                case .door(let kind):
                    DoorSheet(engine: engine, kind: kind)
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
                // MARK: P1 (purchases: engine)
                // MARK: end P1
                // MARK: P2 (purchases: StoreKit and the session)
                // MARK: end P2
                // MARK: P3 (purchases: surfaces and copy)
                // MARK: end P3
                // MARK: U1 (ux: the first-hour fixes)
                // MARK: end U1
                // MARK: V1 (ux: Life folded, rooms dormant)
                case .lifeCard(let page):
                    LifeCardPageView(engine: engine, page: page)
                // MARK: end V1
                // MARK: V2 (ux: one inbox, one home per thing)
                // MARK: end V2
                // MARK: V3 (ux: card weights, the Now card)
                // MARK: end V3
                // MARK: K1 (founder money)
                // MARK: end K1
                // MARK: K2 (product lifecycle)
                // MARK: end K2
                // MARK: K3 (the ladder)
                // MARK: end K3
                // MARK: K4 (deals and exits)
                // MARK: end K4
                // MARK: K5 (hand over the keys)
                // MARK: end K5
                // MARK: K6 (home and rooms)
                // MARK: end K6
                // MARK: K7 (partner and diary)
                // MARK: end K7
                // MARK: end of Iteration 15
                // MARK: end of Iteration 14
                // MARK: end of Iteration 13
                // MARK: end of Iteration 12
                // MARK: end of Iteration 11, wave two
                // MARK: end of Iteration 11
                }
            }
            .onChange(of: router.pendingPush, initial: true) { _, _ in
                consumeRoute()
            }
        }
    }

    // MARK: V1 (ux: Life folded, rooms dormant)
    /// People's five rows: one line and one number each, lit while the
    /// person is waiting on you.
    @ViewBuilder
    private var peopleRows: some View {
        let state = engine.state
        let family = state.life.family
        let asking = LifeSummary.asking(state, content: engine.content)
        let unread = TabBadge.unread(state.life.phone)
        let threads = state.life.phone.threads.count
        // MARK: L1 (phone)
        // Like the card it replaces, nothing until somebody has written.
        if threads > 0 {
            LifeRow(
                title: "Phone",
                systemImage: "bubble.left.and.bubble.right.fill",
                value: asking > 0 ? "\(asking) asking"
                    : unread > 0 ? "\(unread) unread"
                    : "\(threads) thread\(threads == 1 ? "" : "s")",
                isLit: asking > 0
            ) { path = [.phone] }
        }
        if family.stage != .single {
            LifeRow(
                title: family.partnerName ?? "Your partner",
                systemImage: "heart.fill",
                value: "\(Int(family.affection.rounded())) ♥ · \(family.stage.displayName)",
                isLit: family.affection < 35
            ) { path = [.lifeCard(.partner)] }
        }
        // MARK: L3 (children) — on the family's page
        let kids = family.children.count
        let relationships = Int(state.life.meters.relationships.rounded())
        LifeRow(
            title: "Family",
            systemImage: "figure.and.child.holdinghands",
            value: kids > 0
                ? "\(kids) kid\(kids == 1 ? "" : "s")"
                : "\(family.stage.displayName) · ♥ \(relationships)"
        ) { path = [.lifeCard(.family)] }
        // MARK: L4 (friends)
        let friends = state.friendRoster(content: engine.content).count
        LifeRow(
            title: "Friends",
            systemImage: "person.3.fill",
            value: "\(friends) friend\(friends == 1 ? "" : "s")"
        ) { path = [.friends] }
        let networking = state.networking
        LifeRow(
            title: "Networking",
            systemImage: "person.2.wave.2.fill",
            value: networking.pendingEvent.map { "At the \($0.venue.displayName)" }
                ?? "\(networking.contacts.count(where: \.isOpen)) contacts",
            isLit: networking.pendingEvent != nil
        ) { path = [.lifeCard(.networking)] }
    }

    /// A room's card, with the push its own button makes.
    @ViewBuilder
    private func roomCard(_ room: LifeRoom) -> some View {
        switch room {
        // MARK: N1 (crime and the courtroom)
        case .crime: CrimeCard(engine: engine) { path = [.crime] }
        // MARK: N3 (assets, vices and the doctor)
        case .assets: AssetsCard(engine: engine, onOpen: { path = [.assets] })
        // MARK: N4 (fame and the feed)
        case .fame: FameCard(engine: engine) { path = [.feed] }
        // MARK: W2 (family drama)
        case .familyDrama: FamilyDramaCard(engine: engine) { path = [.family] }
        // MARK: L5 (side project)
        case .sideProject: SideProjectCard(engine: engine) { path = [.sideProject] }
        // MARK: L6 (sabbatical)
        case .sabbatical: SabbaticalCard(engine: engine, onOpen: { path = [.sabbatical] })
        // MARK: L2 (life score)
        case .lifeScore: LifeScoreCard(engine: engine, onOpen: { path = [.lifeScore] })
        }
    }
    // MARK: end V1

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
        // `-autoRoute assets` (and `doctor` / `casino`, which land on the
        // same screen and open a sheet from there) push the founder's own
        // balance sheet, once. Taken before the launch-route block below
        // so the lane's own flag is read in its own region.
        if !tookLaunchRoute, Route.launchRoute == .assets {
            tookLaunchRoute = true
            path = [.assets]
            return
        }
        if router.take(.assets) {
            path = [.assets]
            return
        }
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
        // MARK: Iteration 11, wave two — launch routes
        // MARK: W1 (dirty money)
        // MARK: W2 (family drama)
        // Both of W2's routes land on the family room; `.divorce` opens the
        // settlement over it, which is the only way to the table.
        if router.pendingPush == .family || router.pendingPush == .divorce {
            let wantsTable = router.pendingPush == .divorce
            path = [.family]
            showingDivorce = wantsTable
            router.take(wantsTable ? .divorce : .family)
            return
        }
        if !tookLaunchRoute, Route.launchRoute == .family || Route.launchRoute == .divorce {
            tookLaunchRoute = true
            path = [.family]
            showingDivorce = Route.launchRoute == .divorce
            return
        }
        // MARK: W3 (espionage)
        // MARK: W4 (inside)
        if router.take(.inside) {
            path = [.inside]
            return
        }
        // MARK: J1 (doors)
        // `-autoRoute door -autoDoor <kind>` opens the door today and
        // lands on it, once; in the game, the card, a tip and the rail
        // send `.door(kind)`.
        DoorDebug.showLaunchDayIfAsked(engine: engine)
        // With any other route, `-autoDoor` still opens the door — so the
        // phone, the journal or the card can be photographed with it.
        if !tookLaunchRoute, DoorDebug.requestedKind != nil {
            if case .door = Route.launchRoute {} else { DoorDebug.openIfAsked(engine: engine) }
        }
        if !tookLaunchRoute, case .door(let kind)? = Route.launchRoute {
            tookLaunchRoute = true
            DoorDebug.openIfAsked(engine: engine)
            path = [.door(kind)]
            return
        }
        if let route = router.take(where: { if case .door = $0 { true } else { false } }),
           case .door(let kind) = route {
            path = [.door(kind)]
            return
        }
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
        // MARK: P1 (purchases: engine)
        // MARK: end P1
        // MARK: P2 (purchases: StoreKit and the session)
        // MARK: end P2
        // MARK: P3 (purchases: surfaces and copy)
        // MARK: end P3
        // MARK: U1 (ux: the first-hour fixes)
        // MARK: end U1
        // MARK: V1 (ux: Life folded, rooms dormant)
        // MARK: end V1
        // MARK: V2 (ux: one inbox, one home per thing)
        // MARK: end V2
        // MARK: V3 (ux: card weights, the Now card)
        // MARK: end V3
        // MARK: K1 (founder money)
        // MARK: end K1
        // MARK: K2 (product lifecycle)
        // MARK: end K2
        // MARK: K3 (the ladder)
        // MARK: end K3
        // MARK: K4 (deals and exits)
        // MARK: end K4
        // MARK: K5 (hand over the keys)
        // MARK: end K5
        // MARK: K6 (home and rooms)
        // MARK: end K6
        // MARK: K7 (partner and diary)
        // MARK: end K7
        // MARK: end of Iteration 15
        // MARK: end of Iteration 14
        // MARK: end of Iteration 13
        // MARK: end of Iteration 12
        // MARK: end of Iteration 11, wave two
        // MARK: end of Iteration 11
        // A headless screenshot pass cannot tap: `-autoRoute agenda` lands
        // on the fortnight, once.
        if !tookLaunchRoute {
            tookLaunchRoute = true
            if Route.launchRoute == .agenda {
                path = [.agenda]
                return
            }
            // MARK: Iteration 11, wave two — W4 (inside)
            if Route.launchRoute == .inside {
                path = [.inside]
                return
            }
            // MARK: end of Iteration 11, wave two — W4
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
