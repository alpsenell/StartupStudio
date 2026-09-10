import SwiftUI
import TycoonContent
import TycoonEngine

/// The HQ dashboard: the pixel office scene, departments, company overview,
/// burn rate, the product in development (or the start-a-product call to
/// action), activity feed, and the Settings entry point.
struct HQScreen: View {
    let engine: GameEngine
    /// Opens the new-game flow (Settings → "Start a new game…"). Owned by
    /// the session, not the engine.
    let onNewGame: () -> Void

    @State private var showingNewProduct = false
    @State private var showingSettings = false
    /// The story screens (the front page, the timeline) push onto this;
    /// the cards' own `NavigationLink`s resolve through the same
    /// destination, so a deep link and a tap land on the same screen.
    @State private var path = NavigationPath()

    @Environment(AppRouter.self) private var router

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { scroller in
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    if engine.state.company.daysInDebt > 0 {
                        DebtBanner(
                            daysInDebt: engine.state.company.daysInDebt,
                            graceDays: engine.balance.bankruptcyGraceDays
                        )
                    }
                    // What is happening and what to do next leads; the
                    // office, the game's face, comes straight after it.
                    NowCard(engine: engine) { showingNewProduct = true }
                        .hqMeasured("now")
                    OfficeCard(engine: engine)
                        .hqMeasured("office")
                        // MARK: S1 (seating) — where an `s1-…` screenshot scrolls to.
                        .id(SeatingDebug.officeID)
                        // MARK: end S1
                    // MARK: V3 (ux: card weights, the Now card)
                    // C11: below the office, one Company card with three
                    // rows — Burn and runway, Chapter, Journal. Each row
                    // pushes the card it used to be (the burn card, the
                    // chapter card with its goals, perks and teaser, the
                    // journal), so nothing is gone; it is one tap in.
                    CompanyCard(engine: engine)
                        .hqMeasured("company")
                    // MARK: end V3
                    // In-content settings entry point: nav-bar toolbars are
                    // hidden on tab roots (the HUD takes that slot).
                    SettingsButton { showingSettings = true }
                        .hqMeasured("settings")
                        .id(HQDebug.bottomID)
                }
                .padding(Theme.Spacing.lg)
            }
            // The HUD inset lives on the stack's root content (not on the
            // NavigationStack) so the root scrolls below it and any pushed
            // destination shows the navigation bar instead.
            .withTopHUD(engine: engine)
            .background(Theme.screenBackground)
            .navigationTitle("HQ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingNewProduct) {
                NewProductFlow(engine: engine)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsSheet(engine: engine, onNewGame: onNewGame)
            }
            .navigationDestination(for: StoryDestination.self) { destination in
                switch destination {
                case .newspaper: NewspaperScreen(engine: engine)
                case .timeline: TimelineScreen(engine: engine)
                }
            }
            // MARK: V3 (ux: card weights, the Now card)
            .navigationDestination(for: CompanyDestination.self) { destination in
                companyPage(destination)
            }
            // `-autoRoute hq-money|hq-chapter|hq-journal` pushes a Company
            // row's page on launch, for a headless screenshot. Debug only
            // in effect: the name is only ever set by a debug flag.
            .task {
                if let destination = CompanyDestination.launched { path.append(destination) }
            }
            // MARK: end V3
            .onChange(of: router.pendingPush, initial: true) { _, _ in
                consumeRoute()
            }
            // A headless screenshot pass cannot tap the journal card:
            // `-autoRoute newspaper|timeline` opens the screen on launch.
            // (`-autoAnswer` starts from `AppRootView.game`, so it runs
            // whichever tab the pass opened on — R5, fix 4.)
            .task {
                if let route = DebugLaunch.launchStoryRoute { router.go(route) }
                // R2: `-autoRoute settings` opens the sheet for the iCloud row.
                if DebugLaunch.autoRouteName == "settings" { showingSettings = true }
            }
            // V3: `-autoHQBottom` scrolls to Settings, so a headless pass
            // can photograph the bottom of HQ. Debug only.
            .task { await HQDebug.scrollToBottomIfAsked(scroller) }
            // MARK: S1 (seating)
            .task {
                #if DEBUG
                guard SeatingDebug.route != nil else { return }
                try? await Task.sleep(for: .seconds(2))
                scroller.scrollTo(SeatingDebug.officeID, anchor: .top)
                #endif
            }
            // MARK: end S1
            }
        }
    }

    // MARK: V3 (ux: card weights, the Now card)

    /// A Company row's page: the card the row folds, on its own.
    private func companyPage(_ destination: CompanyDestination) -> some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                switch destination {
                case .money:
                    BurnRateCard(
                        weeklyBurn: engine.weeklyBurn,
                        cash: engine.state.company.cash,
                        engineForSheet: engine,
                        codebases: engine.state.codebases,
                        accruingDebt: engine.state.productsInDevelopment.reduce(0.0) {
                            guard case .development(let dev) = $1.stage else { return $0 }
                            return $0 + dev.debtAccrued
                        },
                        balance: engine.balance
                    )
                case .chapter:
                    // The only place the other goals, the perks and the
                    // next chapter's teaser live.
                    GoalsCard(engine: engine)
                case .journal:
                    JournalCard(engine: engine)
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.screenBackground)
        .navigationTitle(destination.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: end V3

    /// Deep links into this tab: the week's front page and the timeline.
    private func consumeRoute() {
        // MARK: Iteration 10
        // MARK: M3 (incident room)
        // The room presents itself from the app root for as long as
        // something is on fire, so the route only has to land the player
        // on this tab and clear itself.
        if router.take(.incidentRoom) { return }
        // MARK: M6 (bug hunt)
        // MARK: end of Iteration 10
        // MARK: Iteration 11
        // MARK: N5 (office secrets)
        // `.secrets` lives on the Team tab and is consumed there; the room
        // shows its clues in `OfficeCard` without a route.
        // MARK: end of Iteration 11
        if router.take(.newspaper) {
            path.append(StoryDestination.newspaper)
        } else if router.take(.timeline) {
            path.append(StoryDestination.timeline)
        }
    }
}

// MARK: - Settings button

/// Small gear button at the bottom of the dashboard.
private struct SettingsButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Settings", systemImage: "gearshape.fill")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
        }
        .buttonStyle(.bordered)
        .tint(.secondary)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Settings")
        .accessibilityHint("Difficulty, new game, and app version")
    }
}

// MARK: - Debt banner

private struct DebtBanner: View {
    let daysInDebt: Int
    /// The engine's own grace period, already scaled for difficulty — read
    /// rather than mirrored, so easy (+7) and hard (−4) count down right.
    let graceDays: Int

    private var daysLeft: Int {
        max(0, graceDays - daysInDebt)
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("In debt")
                    .font(.system(.headline, design: .rounded))
                Text("\(daysLeft) day\(daysLeft == 1 ? "" : "s") until bankruptcy")
                    .font(.subheadline)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.negativeCash)
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Theme.negativeCash.opacity(0.12),
            in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Burn rate card

private struct BurnRateCard: View {
    let weeklyBurn: Int
    let cash: Int
    /// The whole money story, one tap away from its summary.
    var engineForSheet: GameEngine?
    /// The studio's codebases, for the second kind of debt this card
    /// reports. Empty until something ships, and the line is hidden then.
    let codebases: [Codebase]
    /// The mess the builds currently in flight have made and not yet
    /// handed over. It lands on a codebase at ship — which is the point,
    /// and the reason it is worth watching before then.
    let accruingDebt: Double
    let balance: BalanceConfig

    var body: some View {
        CardView("Burn rate", systemImage: "flame.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .top, spacing: Theme.Spacing.xl) {
                    StatBlock(
                        label: "Weekly burn",
                        value: "\(weeklyBurn.money)/wk",
                        tint: weeklyBurn > 0 ? Theme.warning : .primary
                    )
                    StatBlock(label: "Runway", value: runwayValue, tint: runwayTint)
                }
                if cash < 0 {
                    Text("Out of cash — expenses are digging the hole deeper.")
                        .font(.footnote)
                        .foregroundStyle(Theme.negativeCash)
                }
                MoneySheetLink(engine: engineForSheet)
                // The other debt. It is on the burn card and not on a
                // screen of its own because it is the same kind of number
                // as the runway: something that is quietly getting worse
                // while you are looking at the products.
                let worst = codebases.max(by: { $0.debt < $1.debt })
                if (worst?.debt ?? 0) >= 1 || accruingDebt >= 1 {
                    Divider()
                    codebaseDebtLine(worst)
                }
            }
        }
    }

    @ViewBuilder
    private func codebaseDebtLine(_ codebase: Codebase?) -> some View {
        let debt = codebase?.debt ?? 0
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(debtTint(debt))
                Text("Technical debt")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if accruingDebt >= 1 {
                    // What this crunch is costing, before it costs it.
                    Text("+\(Int(accruingDebt.rounded()))")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(Theme.warning)
                }
                Text("\(Int(debt.rounded()))")
                    .font(.system(.headline, design: .rounded).monospacedDigit())
                    .foregroundStyle(debtTint(debt))
            }
            Text(explanation(codebase))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Technical debt \(Int(debt.rounded()))"
                + (accruingDebt >= 1 ? ", \(Int(accruingDebt.rounded())) more in the build" : "")
        )
    }

    private func explanation(_ codebase: Codebase?) -> String {
        guard let codebase, codebase.debt >= 1 else {
            return "The build in flight is cutting corners. It lands on the "
                + "codebase you leave behind, not on this product."
        }
        let ceiling = balance.codebase.debtCeiling(codebase.debt)
        let base = "\(codebase.name) caps anything built on it at "
            + "\(Int((ceiling * 100).rounded()))%. Refactoring is the only way down."
        return accruingDebt >= 1
            ? base + " The build in flight will add \(Int(accruingDebt.rounded())) more at launch."
            : base
    }

    /// Debt reads neutral, then warning, then the colour cash uses when
    /// the company is underwater — because by then it is the same problem.
    private func debtTint(_ debt: Double) -> Color {
        let ceiling = balance.codebase.debtCeiling(debt)
        if ceiling <= 0.80 { return Theme.negativeCash }
        if ceiling <= 0.92 { return Theme.warning }
        return .secondary
    }

    private var runwayValue: String {
        if cash < 0 { return "—" }
        guard weeklyBurn > 0 else { return "∞" }
        return "\(cash / weeklyBurn) wk"
    }

    private var runwayTint: Color {
        if cash < 0 { return Theme.negativeCash }
        guard weeklyBurn > 0 else { return Theme.positiveCash }
        return cash / weeklyBurn <= 4 ? Theme.warning : .primary
    }
}

private struct StatBlock: View {
    let label: String
    let value: String
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(Theme.Typography.number(.title3))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .animation(Theme.Motion.valueChange, value: value)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - V3: debug measuring

/// Two debug-only aids for measuring HQ the way the audit did, since
/// `simctl` cannot scroll: `-autoHQBottom` scrolls to Settings, and
/// `-autoHQMeasure` writes each measured card's frame (in points, in the
/// scroll content) to `tmp/hq-measure.txt` in the app's container. Both
/// do nothing in a release build or without their flag.
enum HQDebug {
    static let bottomID = "hq-bottom"
    static let coordinateSpace = "hq-content"

    static var measures: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-autoHQMeasure")
        #else
        false
        #endif
    }

    @MainActor
    static func scrollToBottomIfAsked(_ scroller: ScrollViewProxy) async {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-autoHQBottom") else { return }
        try? await Task.sleep(for: .seconds(2))
        scroller.scrollTo(bottomID, anchor: .bottom)
        #endif
    }

    @MainActor private static var frames: [String: CGRect] = [:]

    @MainActor
    static func record(_ name: String, _ frame: CGRect) {
        #if DEBUG
        frames[name] = frame
        let lines = frames.keys.sorted().map { key -> String in
            let rect = frames[key] ?? .zero
            return "\(key) minY=\(Int(rect.minY)) maxY=\(Int(rect.maxY)) height=\(Int(rect.height)) width=\(Int(rect.width))"
        }
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("hq-measure.txt")
        try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        #endif
    }
}

private struct HQMeasured: ViewModifier {
    let name: String

    func body(content: Content) -> some View {
        if HQDebug.measures {
            content.onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .scrollView)
            } action: { frame in
                HQDebug.record(name, frame)
            }
        } else {
            content
        }
    }
}

extension View {
    /// Debug: records this card's frame under `-autoHQMeasure`.
    func hqMeasured(_ name: String) -> some View {
        modifier(HQMeasured(name: name))
    }
}

// MARK: - V3: the Company card

/// The three pages HQ's Company card pushes.
enum CompanyDestination: Hashable {
    case money
    case chapter
    case journal

    var title: String {
        switch self {
        case .money: "Burn and runway"
        case .chapter: "Chapter"
        case .journal: "Journal"
        }
    }

    /// `-autoRoute hq-money|hq-chapter|hq-journal`, for a screenshot pass.
    static var launched: CompanyDestination? {
        switch DebugLaunch.autoRouteName ?? "" {
        case "hq-money": .money
        case "hq-chapter": .chapter
        case "hq-journal": .journal
        default: nil
        }
    }
}

/// Everything HQ used to stack below the office — the burn card, the
/// chapter card and the journal — as one grouped card of three `.row`
/// lines (C11): the one number each is for, and a chevron into the card.
private struct CompanyCard: View {
    let engine: GameEngine

    var body: some View {
        let latest = latestEntry
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            CardHeader(title: "Company", systemImage: "building.columns.fill")
                .padding(.horizontal, Theme.Spacing.lg)
            VStack(spacing: 0) {
                NavigationLink(value: CompanyDestination.money) {
                    CardRowLabel("Burn and runway", systemImage: "flame.fill", subtitle: burnLine) {
                        Text(runwayValue).foregroundStyle(runwayTint)
                    }
                }
                .buttonStyle(.pressableRow)
                .accessibilityHint("Opens the burn rate, the runway and all the money")

                if showsChapter {
                    Divider().padding(.leading, CardRowLabel<EmptyView>.dividerInset)
                    NavigationLink(value: CompanyDestination.chapter) {
                        CardRowLabel(chapterTitle, systemImage: "flag.checkered", subtitle: chapterSubtitle) {
                            Text("\(chapterDone)/\(chapterTotal)")
                        }
                    }
                    .buttonStyle(.pressableRow)
                    .accessibilityHint("Opens the chapter's goals")
                }

                Divider().padding(.leading, CardRowLabel<EmptyView>.dividerInset)
                NavigationLink(value: CompanyDestination.journal) {
                    CardRowLabel(
                        "Journal",
                        systemImage: "book.closed.fill",
                        subtitle: latest?.line.message ?? "All quiet. Time to build something."
                    ) {
                        if let latest { Text("Week \(latest.week)") }
                    }
                }
                .buttonStyle(.pressableRow)
                .accessibilityHint("Opens the journal")
            }
            .background(
                Theme.cardBackground,
                in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        }
    }

    // MARK: Burn and runway

    private var weeklyBurn: Int { engine.weeklyBurn }
    private var cash: Int { engine.state.company.cash }

    private var burnLine: String {
        cash < 0 ? "Out of cash · \(weeklyBurn.money)/wk" : "Burning \(weeklyBurn.money)/wk"
    }

    /// The same runway the burn card shows.
    private var runwayValue: String {
        if cash < 0 { return "—" }
        guard weeklyBurn > 0 else { return "∞" }
        return "\(cash / weeklyBurn) wk"
    }

    private var runwayTint: Color {
        if cash < 0 { return Theme.negativeCash }
        guard weeklyBurn > 0 else { return Theme.positiveCash }
        return cash / weeklyBurn <= 4 ? Theme.warning : .primary
    }

    // MARK: Chapter

    private var progression: ProgressionState { engine.state.progression }

    /// The chapter card draws nothing before the first tick; neither does
    /// its row.
    private var showsChapter: Bool {
        !progression.activeGoals.isEmpty || !progression.completedGoalIDs.isEmpty
    }

    /// How many chapters the catalog has, counting up from this one.
    private var chapterCount: Int {
        var count = progression.chapter
        while !engine.content.goals(inChapter: count + 1).isEmpty { count += 1 }
        return count
    }

    private var chapterTitle: String {
        "Chapter \(progression.chapter) of \(chapterCount)"
    }

    /// "Studio", or from the split "Studio · Independent".
    private var chapterSubtitle: String {
        guard progression.chapter >= ProgressionState.firstSplitChapter,
              let track = engine.state.declaredGoalTrack?.displayName
        else { return progression.chapterTitle }
        return "\(progression.chapterTitle) · \(track)"
    }

    private var chapterGoals: [GoalDef] {
        engine.content.goals(inChapter: progression.chapter, track: engine.state.goalTrack)
    }

    private var chapterDone: Int {
        chapterGoals.count { progression.completedGoalIDs.contains($0.id) }
    }

    private var chapterTotal: Int { chapterGoals.count }

    // MARK: Journal

    /// The newest line the journal would lead with (routine weeks folded).
    private var latestEntry: JournalEntry? {
        let copy = EventCopy(state: engine.state, content: engine.content, balance: engine.balance)
        let rows = JournalBuilder.collapsingRoutine(
            JournalBuilder.entries(state: engine.state, copy: copy, limit: 40)
        )
        for row in rows {
            if case .entry(let entry) = row { return entry }
        }
        return nil
    }
}
