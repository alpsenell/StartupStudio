import SwiftUI
import TycoonContent
import TycoonEngine

/// The one screen every run ends on: a short biography of the founder the
/// player made, whichever way it went.
///
/// Bankruptcy, an acquisition, an ousting and an IPO all land here — the
/// tone and the headline change, the shape does not. Chapters reached, the
/// best thing they shipped, the person who stayed longest, the family, the
/// money, and then a way back to the beginning with a new identity.
/// Iteration 7: what the biography can offer beyond the two it always
/// had. Both optional, both rendered only when set — the share button
/// (R4) and *Keep running it* (R5, IPO and *Still yours* only).
struct BiographyActions {
    var onShare: (() -> Void)?
    var onContinueRunning: (() -> Void)?

    init(onShare: (() -> Void)? = nil, onContinueRunning: (() -> Void)? = nil) {
        self.onShare = onShare
        self.onContinueRunning = onContinueRunning
    }
}

struct FounderBiographyView: View {
    let engine: GameEngine
    let info: GameOverInfo
    let onNewGame: (Difficulty, FounderProfile, FoundingOrigin) -> Void
    /// The same year again: same seed, same founder, same company. The
    /// engine is deterministic, so the same events and candidates come
    /// round and the player can play them differently.
    var onReplay: (() -> Void)?
    /// Iteration 7: share, and keep running.
    var actions: BiographyActions = BiographyActions()

    @State private var startingOver = false

    @Environment(\.dynamicTypeSize) private var typeSize

    /// U7: "Start a new company" goes through the front door and its slot
    /// picker when there is one. Without a session (a snapshot, a preview)
    /// the founder setup sheet stands in, as it did before slots.
    @Environment(\.gameSession) private var session

    private var state: GameState { engine.state }
    private var balance: BalanceConfig { engine.balance }
    private var founder: FounderProfile { state.progression.founder }

    var body: some View {
        ZStack {
            Theme.screenBackground.ignoresSafeArea()

            ScrollView {
                biographyContent
                    .padding(Theme.Spacing.lg)
            }
        }
        // Iteration 7 (R4): the share button, only when a lane set it.
        .overlay(alignment: .topTrailing) {
            if let onShare = actions.onShare {
                Button {
                    Haptics.tap()
                    Sounds.play(.tap)
                    onShare()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body.weight(.semibold))
                        .padding(Theme.Spacing.sm)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
                .padding(Theme.Spacing.lg)
                .accessibilityLabel("Share this life")
            }
        }
        .sheet(isPresented: $startingOver) {
            FounderSetupSheet(defaultCompanyName: state.company.name) { difficulty, profile, origin in
                startingOver = false
                onNewGame(difficulty, profile, origin)
            }
        }
    }

    /// The biography as one column, without the scroll view, so the
    /// snapshot tests can draw it: `ImageRenderer` draws nothing inside a
    /// `ScrollView`, the same reason `DecisionSheetContent` exists.
    var biographyContent: some View {
        VStack(spacing: Theme.Spacing.lg) {
            banner
            if !info.kind.isSuccess {
                postMortemCard
            }
            // MARK: P3 (purchases: surfaces and copy)
            // Bankruptcy only, and only when the rule would take it.
            ShopReceiverCall(engine: engine, info: info)
            // MARK: end P3
            chaptersCard
            if let product = bestProduct { productCard(product) }
            if let longest = longestServing { peopleCard(longest) }
            lifeCard
            moneyCard
            playAgainButton
        }
    }

    // MARK: - Banner

    /// Internal so the snapshot suite can render the banner on its own:
    /// `ImageRenderer` cannot lay out the screen's scroll view.
    var banner: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: bannerIcon)
                .font(.system(size: 56))
                .foregroundStyle(bannerTint)
                .padding(.top, Theme.Spacing.xl)

            Text(info.kind.headline)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))

            // WS-G: the independent ending's one line under the headline.
            if info.kind == .independent {
                Text("Built on your own money, and still yours.")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.positiveCash)
            }

            // Iteration 7 (R5): the ending this company already had and
            // kept going past. The banner above is untouched — this is one
            // line under it, and it is the only thing on the screen that
            // knows the run has been here before.
            if let epilogue = state.epilogue {
                Text(Self.epilogueLine(epilogue, endedOn: state.gameOver?.day))
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Iteration 8: where the founder came from, when from the ledger.
            if let lineage = state.lineage {
                Text(Successors.line(for: lineage))
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Iteration 8: the stake the run was played at.
            if state.rules.stake > 0, let stake = StakeLadder.stake(state.rules.stake) {
                Label("Stake \(stake.level) · \(stake.title)", systemImage: "flag.checkered")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .accessibilityLabel("Played at stake \(stake.level), \(stake.title)")
            }

            // The portrait sits beside the name until the name needs the
            // width, and then above it.
            let headerLayout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.sm))
                : AnyLayout(HStackLayout(spacing: Theme.Spacing.sm))
            headerLayout {
                PixelPortrait(
                    seed: state.employees.first?.appearanceSeed ?? 0,
                    isFounder: true,
                    size: 40
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(founder.displayName)
                        .font(.system(.headline, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                    Label(
                        "\(founder.archetype.displayName) · \(state.company.name)",
                        systemImage: founder.archetype.systemImageName
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    // How it started (WS-H): the biography's first line.
                    Label(state.origin.biographyLine, systemImage: state.origin.systemImageName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)

            Text(info.reason)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: Theme.Spacing.sm) {
                    StatPill(systemImage: "calendar", value: "Day \(info.day)")
                    StatPill(systemImage: "clock", value: state.dateLabel)
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    StatPill(systemImage: "calendar", value: "Day \(info.day)")
                    StatPill(systemImage: "clock", value: state.dateLabel)
                }
            }
        }
    }

    /// "Public since day 812 · still running" while the company is
    /// running, and what it did with the extra time once something finally
    /// stopped it — "still running" under a bankruptcy headline would be
    /// the screen contradicting itself.
    static func epilogueLine(_ epilogue: Epilogue, endedOn endDay: Int?) -> String {
        let since = "\(epilogue.ending.epilogueNoun) since day \(epilogue.day)"
        guard let endDay else { return since + " · still running" }
        let extra = max(0, endDay - epilogue.day)
        return since + " · ran on for \(extra) more day\(extra == 1 ? "" : "s")"
    }

    private var bannerIcon: String {
        switch info.kind {
        case .bankruptcy: "xmark.octagon.fill"
        case .acquired: "crown.fill"
        case .ipo: "bell.fill"
        case .oustedByBoard: "person.crop.circle.badge.xmark"
        case .soldUp: "tag.fill"
        case .independent: "flag.checkered"
        case .walkedAway: "figure.walk.departure"
        }
    }

    private var bannerTint: Color {
        info.kind.isSuccess ? Theme.positiveCash : Theme.negativeCash
    }

    // MARK: - Chapters

    private var chaptersCard: some View {
        CardView("The story so far", systemImage: "book.closed.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                ForEach(state.progression.chapterLog, id: \.chapter) { entry in
                    BiographyChapterRow(entry: entry)
                }

                Divider()
                HStack {
                    Label(
                        "\(state.progression.completedGoalIDs.count) goals finished"
                            + Self.awardsSuffix(state: state, content: engine.content),
                        systemImage: "checkmark.seal.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }

                if !state.progression.earnedPerks.isEmpty {
                    HStack(spacing: Theme.Spacing.xs) {
                        ForEach(state.progression.earnedPerks, id: \.rawValue) { perk in
                            Label(perk.displayName, systemImage: perk.systemImageName)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                                .padding(.horizontal, Theme.Spacing.sm)
                                .padding(.vertical, 3)
                                .background(Theme.chipBackground, in: Capsule())
                        }
                    }
                }
            }
        }
    }

    // MARK: - The work

    /// The best thing they shipped, by review score; ties break on revenue.
    private var bestProduct: (product: Product, info: ReleaseInfo)? {
        state.products
            .compactMap { product -> (Product, ReleaseInfo)? in
                guard case .released(let release) = product.stage else { return nil }
                return (product, release)
            }
            .max { lhs, rhs in
                if lhs.1.averageReviewScore != rhs.1.averageReviewScore {
                    return lhs.1.averageReviewScore < rhs.1.averageReviewScore
                }
                return lhs.1.totalRevenue < rhs.1.totalRevenue
            }
    }

    private func productCard(_ best: (product: Product, info: ReleaseInfo)) -> some View {
        CardView("Best thing you shipped", systemImage: "shippingbox.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text(best.product.name)
                        .font(.system(.headline, design: .rounded))
                    Spacer()
                    ScoreBadge(score: best.info.averageReviewScore)
                }
                Text(
                    "\(topicName(best.product.topicID)) · shipped day \(best.info.launchDay) · "
                        + "\(best.info.totalRevenue.money) lifetime"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                if let review = best.info.reviews.max(by: { $0.score < $1.score }) {
                    Text("\u{201C}\(review.blurb)\u{201D} — \(review.outlet)")
                        .font(.caption)
                        .italic()
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("\(shippedCount) product\(shippedCount == 1 ? "" : "s") shipped in all.")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var shippedCount: Int {
        state.products.count { if case .released = $0.stage { true } else { false } }
    }

    // MARK: - The people

    /// The longest-serving hire still on payroll at the end.
    private var longestServing: Employee? {
        state.employees
            .filter { !$0.isFounder }
            .min { lhs, rhs in
                if lhs.hiredDay != rhs.hiredDay { return lhs.hiredDay < rhs.hiredDay }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    private func peopleCard(_ longest: Employee) -> some View {
        CardView("The people", systemImage: "person.2.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(spacing: Theme.Spacing.md) {
                    PixelPortrait(seed: longest.appearanceSeed)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(longest.name)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        Text(
                            "Joined day \(longest.hiredDay) · \(tenureLabel(longest)) · "
                                + longest.role.displayName
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Longest serving: \(longest.name), joined day \(longest.hiredDay)")

                TraitChipRow(traits: longest.traits, content: engine.content)

                Text(
                    "\(state.headcount) on payroll at the end. "
                        + "The team peaked at \(state.progression.stats.peakHeadcount)."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    // l10n: NOT LOCALIZED, deliberately (R9, iteration 7). `tenureLabel`,
    // `childrenList`, `homeSummary` and `familySummary` below are the
    // biography's four sentence builders: they join clauses with commas and
    // "and", and pluralise with a trailing s. Converting them means one
    // format per sentence with an explicit list format, not a wrapper per
    // fragment -
    //   "bio.tenure"   = "%1$@, %2$lld years" (+ plural variants)
    //   "bio.children" = a ListFormatter over localized names
    //   "bio.home"     = "A %1$@ in %2$@."
    //   "bio.family"   = "Married to %1$@, %2$lld children."
    // English word order is baked into all four today. Wave 2.
    private func tenureLabel(_ employee: Employee) -> String {
        let weeks = max(0, (info.day - employee.hiredDay) / GameState.daysPerWeek)
        return weeks >= 52
            ? "\(weeks / 52) year\(weeks / 52 == 1 ? "" : "s") with you"
            : "\(weeks) week\(weeks == 1 ? "" : "s") with you"
    }

    // MARK: - The life

    private var lifeCard: some View {
        let family = state.life.family
        return CardView("The rest of your life", systemImage: "heart.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                // Iteration 9 — L2: the second number, at the top of the
                // card that is about the person rather than the company.
                LifeScoreSummaryRow(
                    score: LifeScore.score(state, balance: balance),
                    components: LifeScore.breakdown(state: state, balance: balance)
                )
                Text(familySummary)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(homeSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !family.children.isEmpty {
                    Text(childrenList(family.children) + ".")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                // MARK: L5 (side project)
                // One line per track the founder actually finished. The
                // copy is L5's, in the engine catalog; this is the call.
                ForEach(sideProjectLines, id: \.self) { line in
                    Text(line)
                        .font(.subheadline)
                        .foregroundStyle(Theme.accent)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // MARK: end L5 (side project)
            }
        }
    }

    // MARK: L5 (side project)
    private var sideProjectLines: [String] {
        state.life.sideProject?.biographyLines(balance: balance) ?? []
    }
    // MARK: end L5 (side project)

    /// "Mika", "Mika and Sam", "Mika, Sam and Noor".
    private func childrenList(_ children: [Child]) -> String {
        let names = children.map(\.name)
        guard names.count > 1 else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " and " + (names.last ?? "")
    }

    private var homeSummary: String {
        let weekends = state.progression.stats.weekendsOff
        let home = state.life.home.displayName.lowercased()
        let plural = weekends == 1 ? "weekend was" : "weekends were"
        return "You finished in a \(home). \(weekends) \(plural) actually spent on something."
    }

    private var familySummary: String {
        let family = state.life.family
        switch family.stage {
        case .single:
            return family.children.isEmpty
                ? "You ended it single. There was always something shipping."
                : "You raised \(family.children.count) on your own."
        case .dating:
            return "You were seeing \(family.partnerName ?? "someone"), which mostly meant texting from the office."
        case .partner:
            return "You lived with \(family.partnerName ?? "your partner")."
        case .married:
            return "You married \(family.partnerName ?? "your partner")"
                + (family.children.isEmpty ? "." : " and had \(family.children.count) children.")
        }
    }

    // MARK: - The money

    private var moneyCard: some View {
        let balance = engine.balance
        let netWorth = state.founderNetWorth(balance: balance)
        return CardView("The money", systemImage: "dollarsign.circle.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) {
                        netWorthFigure(netWorth)
                        // Iteration 9 — L2: "$4.2M · Life 71".
                        Text("final net worth · Life \(LifeScore.score(state, balance: balance))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        netWorthFigure(netWorth)
                        // Iteration 9 — L2: "$4.2M · Life 71".
                        Text("final net worth · Life \(LifeScore.score(state, balance: balance))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    // WS-B: an earn-out is a sale in three numbers.
                    if let earnOut = state.investors.earnOut {
                        Text(
                            "Sold for \(earnOut.price.money) · \(earnOut.paid.money) paid · "
                                + "\(earnOut.outstanding.money) forfeited"
                        )
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    row("Company at the end", state.companyValuation(balance: balance).money)
                    row("You still owned", "\(state.investors.equityRemaining.oneDecimal)%")
                    // WS-B: every round bought back out of the cap table.
                    ForEach(state.investors.boughtOut) { round in
                        row(
                            "Bought out \(round.investorName) in year "
                                + "\(yearOf(round.boughtOutDay ?? round.day))",
                            (round.buybackPrice ?? 0).money
                        )
                    }
                    if state.investors.totalRaised > 0 {
                        row(
                            "Raised across \(state.investors.rounds.count) round"
                                + "\(state.investors.rounds.count == 1 ? "" : "s"),",
                            state.investors.totalRaised.money
                        )
                    }
                    row("Reached", state.company.officeTier.displayName)
                    // MARK: P3 (purchases: surfaces and copy)
                    if let bought = ShopBoughtLine.text(state.purchases) {
                        Text(bought)
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    // MARK: end P3
                }
            }
            .accessibilityElement(children: .contain)
        }
    }

    /// The game year a day falls in: fifty-two weeks to the year, as the
    /// engine's own calendar counts it.
    private func yearOf(_ day: Int) -> Int {
        day / (GameState.daysPerWeek * 52) + 1
    }

    private func netWorthFigure(_ netWorth: Int) -> some View {
        Text(netWorth.money)
            .font(Theme.Typography.number(.title2, weight: .bold))
            .foregroundStyle(netWorth >= 0 ? Theme.positiveCash : Theme.negativeCash)
            .lineLimit(1)
            .fixedSize()
    }

    /// A label and its figure on one line where they fit, and the figure
    /// under the label where they do not — never a money figure broken
    /// across two lines, which is what a plain `HStack` does at the
    /// accessibility sizes.
    private func row(_ label: String, _ value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                rowLabel(label)
                Spacer(minLength: Theme.Spacing.sm)
                rowValue(value)
            }
            VStack(alignment: .leading, spacing: 1) {
                rowLabel(label)
                rowValue(value)
            }
        }
    }

    private func rowLabel(_ label: String) -> some View {
        Text(label)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func rowValue(_ value: String) -> some View {
        Text(value)
            .font(Theme.Typography.number(.caption))
            .lineLimit(1)
            .fixedSize()
    }

    // MARK: - Again

    private var playAgainButton: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // Iteration 7 (R5): keep the company running past an ending
            // that allows it. Rendered only when the lane set it.
            if let onContinueRunning = actions.onContinueRunning {
                Button {
                    Haptics.commit()
                    onContinueRunning()
                } label: {
                    Label("Keep running it", systemImage: "play.fill")
                        .font(.system(.headline, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.sm)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
                .accessibilityHint("Carries on after the ending: no board, no buyers, the work continues")
            }
            if let onReplay, state.seed != 0 {
                Button {
                    Haptics.commit()
                    onReplay()
                } label: {
                    Label(
                        info.kind.isSuccess ? "Run it back" : "Try that year again",
                        systemImage: "arrow.uturn.backward"
                    )
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .accessibilityLabel("Play the same year again with the same founder and company")
                Text("Same seed, same events, same candidates — with what you know now.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                if let session {
                    Haptics.tap()
                    session.returnToFrontDoor()
                } else {
                    startingOver = true
                }
            } label: {
                Label("Start a new company", systemImage: "arrow.counterclockwise")
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent)
            .accessibilityLabel("Start a new company with a new founder")
        }
        .padding(.top, Theme.Spacing.sm)
        .padding(.bottom, Theme.Spacing.xl)
    }

    // MARK: - What went wrong

    /// Three facts with numbers, from the ledger and the roster, on a
    /// failed ending. Never a scold: the reader can see what to try.
    @ViewBuilder
    private var postMortemCard: some View {
        let lines = PostMortem.lines(for: state, balance: balance, weeklyBurn: engine.weeklyBurn)
        if !lines.isEmpty {
            PostMortemCard(lines: lines)
        }
    }

    private func topicName(_ id: String) -> String {
        engine.content.topic(id)?.name ?? id
    }
}

/// One line of the chapter log: the number, the chapter and its teaser,
/// and the day it opened.
///
/// Its own view, not a method on the page, so that it reads the reader's
/// text size wherever it is drawn — including through the page's
/// `biographyContent`, which is a value, not a view in the hierarchy, and
/// so has no environment of its own.
private struct BiographyChapterRow: View {
    let entry: ChapterEntry

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
            Text("\(entry.chapter)")
                .font(Theme.Typography.number(.caption, weight: .bold))
                .frame(width: 18)
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(ChapterDef.title(for: entry.chapter))
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(ChapterDef.teaser(for: entry.chapter))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                // At the accessibility sizes the day cannot share the
                // line: a two-word column beside a sentence turns the
                // sentence into a stack of single words.
                if typeSize.isAccessibilitySize { dayStamp }
            }
            if !typeSize.isAccessibilitySize {
                Spacer(minLength: Theme.Spacing.sm)
                dayStamp
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var dayStamp: some View {
        Text(entry.day == 0 ? "Day one" : "Day \(entry.day)")
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.tertiary)
            .lineLimit(1)
            .fixedSize()
    }
}

// MARK: - Iteration 8: the awards

extension FounderBiographyView {
    /// " · Product of the Year, year 2 — Overcast" for each ceremony won.
    static func awardsSuffix(state: GameState, content: ContentCatalog) -> String {
        let lines = AwardsJudge.playerWinLines(state: state, content: content)
        guard !lines.isEmpty else { return "" }
        return " · " + lines.joined(separator: " · ")
    }
}
