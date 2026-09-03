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
struct FounderBiographyView: View {
    let engine: GameEngine
    let info: GameOverInfo
    let onNewGame: (Difficulty, FounderProfile) -> Void
    /// The same year again: same seed, same founder, same company. The
    /// engine is deterministic, so the same events and candidates come
    /// round and the player can play them differently.
    var onReplay: (() -> Void)?

    @State private var startingOver = false

    private var state: GameState { engine.state }
    private var balance: BalanceConfig { engine.balance }
    private var founder: FounderProfile { state.progression.founder }

    var body: some View {
        ZStack {
            Theme.screenBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    banner
                    if !info.kind.isSuccess {
                        postMortemCard
                    }
                    chaptersCard
                    if let product = bestProduct { productCard(product) }
                    if let longest = longestServing { peopleCard(longest) }
                    lifeCard
                    moneyCard
                    playAgainButton
                }
                .padding(Theme.Spacing.lg)
            }
        }
        .sheet(isPresented: $startingOver) {
            FounderSetupSheet(defaultCompanyName: state.company.name) { difficulty, profile in
                startingOver = false
                onNewGame(difficulty, profile)
            }
        }
    }

    // MARK: - Banner

    private var banner: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: bannerIcon)
                .font(.system(size: 56))
                .foregroundStyle(bannerTint)
                .padding(.top, Theme.Spacing.xl)

            Text(info.kind.headline)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))

            HStack(spacing: Theme.Spacing.sm) {
                PixelPortrait(
                    seed: state.employees.first?.appearanceSeed ?? 0,
                    isFounder: true,
                    size: 40
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(founder.displayName)
                        .font(.system(.headline, design: .rounded))
                    Label(
                        "\(founder.archetype.displayName) · \(state.company.name)",
                        systemImage: founder.archetype.systemImageName
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)

            Text(info.reason)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Theme.Spacing.sm) {
                StatPill(systemImage: "calendar", value: "Day \(info.day)")
                StatPill(systemImage: "clock", value: state.dateLabel)
            }
        }
    }

    private var bannerIcon: String {
        switch info.kind {
        case .bankruptcy: "xmark.octagon.fill"
        case .acquired: "crown.fill"
        case .ipo: "bell.fill"
        case .oustedByBoard: "person.crop.circle.badge.xmark"
        case .soldUp: "tag.fill"
        case .independent: "flag.checkered"
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
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                        Text("\(entry.chapter)")
                            .font(Theme.Typography.number(.caption, weight: .bold))
                            .frame(width: 18)
                            .foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(ChapterDef.title(for: entry.chapter))
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            Text(ChapterDef.teaser(for: entry.chapter))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: Theme.Spacing.sm)
                        Text(entry.day == 0 ? "Day one" : "Day \(entry.day)")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.tertiary)
                    }
                    .accessibilityElement(children: .combine)
                }

                Divider()
                HStack {
                    Label(
                        "\(state.progression.completedGoalIDs.count) goals finished",
                        systemImage: "checkmark.seal.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Spacer()
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
            }
        }
    }

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
                HStack(alignment: .firstTextBaseline) {
                    Text(netWorth.money)
                        .font(Theme.Typography.number(.title2, weight: .bold))
                        .foregroundStyle(netWorth >= 0 ? Theme.positiveCash : Theme.negativeCash)
                    Text("final net worth")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
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

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(Theme.Typography.number(.caption))
        }
    }

    // MARK: - Again

    private var playAgainButton: some View {
        VStack(spacing: Theme.Spacing.sm) {
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
                startingOver = true
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
