import SwiftUI
import TycoonEngine

/// The Business tab: client contracts, the market, marketing campaigns,
/// finances, rivals and investors, switched with a pill bar pinned above
/// the scroll content (nav-bar toolbars sit underneath the opaque top HUD
/// in this design, and content inside the ScrollView would scroll under
/// the HUD).
struct BusinessScreen: View {
    let engine: GameEngine

    private enum BusinessSection: String, CaseIterable, Identifiable {
        case contracts = "Contracts"
        case market = "Market"
        case marketing = "Marketing"
        case finances = "Finances"
        case rivals = "Rivals"
        case investors = "Investors"

        var id: String { rawValue }

        init?(desk: DeskSection) {
            switch desk {
            case .contracts: self = .contracts
            case .market: self = .market
            case .marketing: self = .marketing
            case .finances: self = .finances
            case .rivals: self = .rivals
            case .investors: self = .investors
            }
        }

        /// The section a route lands in, when it is one of ours.
        init?(route: Route) {
            switch route {
            case .contracts: self = .contracts
            case .market, .marketReport, .marketMap: self = .market
            case .marketing: self = .marketing
            case .finances: self = .finances
            case .rivals, .rivalProfile: self = .rivals
            case .investors: self = .investors
            default: return nil
            }
        }

        /// Each section's own icon, taken from the headers inside it, so
        /// the pill and the screen it opens agree.
        var systemImage: String {
            switch self {
            case .contracts: "briefcase.fill"
            case .market: "chart.xyaxis.line"
            case .marketing: "megaphone.fill"
            case .finances: "banknote.fill"
            case .rivals: "flag.2.crossed.fill"
            case .investors: "chart.pie.fill"
            }
        }
    }

    @State private var section: BusinessSection = .contracts
    /// Report or map on the Market section (U3): held here so the
    /// `.marketMap` deep link can pick the map before the section draws.
    @State private var marketLens: MarketLens = .report
    /// Pushed screens: a rival's profile (U3).
    @State private var path = NavigationPath()

    @Environment(AppRouter.self) private var router

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                // Pinned below the top HUD inset, outside the ScrollView,
                // so it can never scroll under the opaque HUD.
                //
                // Six segments do not fit an iPhone as a segmented picker:
                // they truncate to "Contr…" / "Market…" / "Investo…" at the
                // default text size, and worse above it. The pill bar keeps
                // every label whole and scrolls instead.
                SegmentPillBar(
                    segments: BusinessSection.allCases,
                    title: \.rawValue,
                    systemImage: \.systemImage,
                    accessibilityLabel: "Business section",
                    selection: $section,
                    badges: badges
                )
                .padding(.top, Theme.Spacing.xs)
                .background(Theme.screenBackground)
                .overlay(alignment: .bottom) { Divider() }

                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        // What has a clock on it, whichever section is
                        // open: the tab used to land on two empty states
                        // with a contract three days out hidden behind
                        // the right pill.
                        DeskCard(items: deskItems) { route in
                            if let target = BusinessSection(route: route) {
                                withAnimation(Theme.Motion.selection) { section = target }
                                if case .marketReport = route { router.go(route) }
                            } else {
                                router.go(route)
                            }
                        }
                        switch section {
                        case .contracts:
                            ContractsView(engine: engine)
                        case .market:
                            MarketView(engine: engine, lens: $marketLens)
                        case .marketing:
                            MarketingView(engine: engine)
                        case .finances:
                            FinancesView(engine: engine)
                        case .rivals:
                            RivalsView(engine: engine)
                        case .investors:
                            InvestorsView(engine: engine)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.sm)
                    .padding(.bottom, Theme.Spacing.lg)
                }
            }
            // The HUD inset lives on the stack's root content (this VStack),
            // not on the NavigationStack, so the pill bar lands below it.
            .withTopHUD(engine: engine)
            .background(Theme.screenBackground)
            .navigationTitle("Business")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            // Registered on the always-present stack root (not inside the
            // segment switch) so a rival card's link and the deep link
            // both resolve, whichever segment is showing.
            .navigationDestination(for: RivalRoute.self) { route in
                RivalProfileScreen(engine: engine, rivalID: route.rivalID)
            }
            // Deep links into this tab pick their own segment.
            .onChange(of: router.pendingPush, initial: true) { _, _ in
                consumeRoute()
            }
            // A headless pass can ask for one of this tab's screens; the
            // profile waits for a rival to exist, so this is checked as
            // the days pass. Nil outside debug builds.
            .onChange(of: engine.state.day, initial: true) { _, _ in
                if let route = DebugLaunch.takeLaunchRoute(in: engine.state) {
                    router.go(route)
                }
            }
            // Land on the section the desk's most urgent row points at,
            // unless a deep link already chose one.
            .onAppear {
                guard router.pendingPush == nil, !landed, let first = deskItems.first,
                      let target = BusinessSection(desk: first.section)
                else { landed = true; return }
                section = target
                landed = true
            }
        }
    }

    @State private var landed = false

    private var deskItems: [DeskItem] {
        Desk.items(in: engine.state, balance: engine.balance, content: engine.content)
    }

    /// How many desk rows point at each section.
    private var badges: [String: Int] {
        var counts: [String: Int] = [:]
        for item in deskItems {
            if let target = BusinessSection(desk: item.section) {
                counts[target.id, default: 0] += 1
            }
        }
        return counts
    }

    /// Switches to the segment a deep link asked for.
    ///
    /// Routes this screen can satisfy on its own are consumed here;
    /// `.marketReport` only picks the segment and is left in place for
    /// `MarketView` to open the report on the right topic. `.marketMap`
    /// picks the segment and the map; `.rivalProfile` picks Rivals and
    /// pushes the profile.
    private func consumeRoute() {
        // MARK: Iteration 10
        // MARK: M2 (pitch room)
        // The pitch room is a sheet over a card, not a screen of its own,
        // so the route lands on the segment holding whoever is waiting —
        // the term sheet first, then the offers on the desk.
        // `-autoRoute pitch` is read here rather than pushed, the way
        // every other tab root reads its own launch route.
        if router.pendingPush == .pitch || (router.pendingPush == nil && Route.launchRoute == .pitch) {
            section = engine.state.investors.pendingOffer != nil ? .investors : .contracts
            router.take(.pitch)
            // The desk's own "land on the most urgent row" pass runs
            // after this one and would otherwise pick the segment back.
            landed = true
            return
        }
        // MARK: end of Iteration 10
        // MARK: Iteration 11
        // MARK: N1 (crime and the courtroom: sue a rival)
        // A suit is filed from a rival's profile, so the route lands on
        // Rivals with that studio's page pushed — the same shape
        // `.rivalProfile` takes below, read here so the launch flag works
        // as well as the in-game link.
        if case .rivalProfile(let rivalID) = Route.launchRoute,
           router.pendingPush == nil, !landed,
           engine.state.rivals.rival(id: rivalID) != nil {
            section = .rivals
            landed = true
            path.append(RivalRoute(rivalID: rivalID))
            return
        }
        if router.pendingPush == .rivalSuit
            || (router.pendingPush == nil && !landed && Route.launchRoute == .rivalSuit) {
            section = .rivals
            landed = true
            router.take(.rivalSuit)
            if let rival = engine.state.rivals.rivals.first {
                path.append(RivalRoute(rivalID: rival.id))
            }
            return
        }
        // MARK: end of Iteration 11
        // MARK: Iteration 11, wave two
        // MARK: W1 (dirty money)
        // The card and its sheets live in the Finances segment, so the
        // route only has to pick that segment; `DirtyMoneyCard`'s own
        // task opens the sheet once there is something in it.
        if router.pendingPush == .dirtyMoney
            || (router.pendingPush == nil && !landed && Route.launchRoute == .dirtyMoney) {
            section = .finances
            landed = true
            router.take(.dirtyMoney)
            return
        }
        // MARK: W3 (espionage)
        // The five operations live on a studio's page, so the route lands
        // on Rivals with the first studio pushed — the same shape N1's
        // suit takes above, for the same reason: a command line cannot
        // name a UUID.
        if router.pendingPush == .spy
            || (router.pendingPush == nil && !landed && Route.launchRoute == .spy) {
            section = .rivals
            landed = true
            router.take(.spy)
            if let rival = engine.state.rivals.rivals.first {
                path.append(RivalRoute(rivalID: rival.id))
            }
            return
        }
        // MARK: J1 (doors)
        // MARK: end J1
        // MARK: J2 (record)
        // `-autoRoute investors` lands on the cap table: the review line
        // and the key-person clause both live there.
        if router.pendingPush == nil && !landed && Route.launchRoute == .investors {
            section = .investors
            landed = true
            return
        }
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
        switch router.pendingPush {
        case .marketMap:
            section = .market
            marketLens = .map
            router.take(.marketMap)
        case .rivalProfile(let rivalID):
            section = .rivals
            router.take(where: {
                if case .rivalProfile = $0 { return true } else { return false }
            })
            guard engine.state.rivals.rival(id: rivalID) != nil else { return }
            path.append(RivalRoute(rivalID: rivalID))
        case .contracts:
            section = .contracts
            router.take(.contracts)
        case .market:
            section = .market
            router.take(.market)
        case .marketing:
            section = .marketing
            router.take(.marketing)
        case .finances:
            section = .finances
            router.take(.finances)
        case .investors:
            section = .investors
            router.take(.investors)
        case .rivals:
            section = .rivals
            router.take(.rivals)
        case .marketReport:
            section = .market
        default:
            break
        }
    }
}

// MARK: - Shared section header

/// Section label above a run of cards, matching the CardView header look.
struct BusinessSectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.accent)
            Text(title)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .textCase(.uppercase)
                .kerning(0.6)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.xs)
        .accessibilityAddTraits(.isHeader)
    }
}
