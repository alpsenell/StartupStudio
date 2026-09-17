import SwiftUI
import TycoonContent
import TycoonEngine

/// The biography as a card: one 540×675 poster of a life, not the
/// biography in a frame.
///
/// The ending and its icon, the founder's face, the company in the
/// game's own hand, the chapters with the day each opened, the best thing
/// they shipped with its best line, the person who stayed longest, the
/// money, and the seed code along the bottom so the reader can play the
/// same life. Every size is fixed: this is an image, not a screen, and it
/// has to read at thumbnail size (270×338) — the company name and the
/// ending are the two things that must survive that.
struct BiographyCardView: View {
    let engine: GameEngine
    let info: GameOverInfo

    private var state: GameState { engine.state }
    private var founder: FounderProfile { state.progression.founder }

    /// The code a reader can type: this run's seed, origin and difficulty.
    var seedCode: SeedCode {
        SeedCode(seed: state.seed, origin: state.origin, difficulty: state.difficulty)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                banner
                founderRow
                ShareRule()
                chapters
                ShareRule(color: ShareInk.ink.opacity(0.35), height: 1)
                HStack(alignment: .top, spacing: Theme.Spacing.lg) {
                    if let best = bestProduct {
                        productColumn(best)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        nothingShipped
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Rectangle()
                        .fill(ShareInk.ink.opacity(0.35))
                        .frame(width: 1)
                    peopleColumn
                        .frame(width: 190, alignment: .leading)
                }
                .fixedSize(horizontal: false, vertical: true)
                ShareRule(color: ShareInk.ink.opacity(0.35), height: 1)
                life
                Spacer(minLength: 0)
                money
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            ShareFooter(line: state.rules.stake > 0 ? "Stake \(state.rules.stake)" : "Replay this life", code: seedCode)
        }
        .background(ShareInk.paper)
        .overlay {
            PixelPanelBorder(thickness: 6, corner: 6)
                .fill(ShareInk.ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(founder.displayName)'s biography card: \(info.kind.headline) on day \(info.day), "
                + "\(state.company.name). Replay this life with code \(seedCode.encoded)."
        )
    }

    // MARK: - Banner

    /// The ending: icon and headline at the largest scale the width takes.
    private var banner: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.md) {
            Image(systemName: bannerIcon)
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 6) {
                PixelText(text: info.kind.headline, scale: 5, color: tint)
                Text("Day \(info.day) · \(state.calendar.longLabel)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(ShareInk.faint)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
            // MARK: Iteration 18 — the studio mark at the banner's far
            // edge: the company's own seal on its own obituary. Nothing is
            // drawn for a company that never picked one.
            StudioMarkStamp(state: state, size: 40)
            // MARK: end of Iteration 18
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
        case .walkedAway: "figure.walk.departure"
        }
    }

    private var tint: Color {
        info.kind.isSuccess ? ShareInk.success : ShareInk.failure
    }

    // MARK: - The founder

    private var founderRow: some View {
        HStack(spacing: Theme.Spacing.md) {
            PixelPortrait(
                seed: state.employees.first(where: \.isFounder)?.appearanceSeed ?? founder.appearanceSeed ?? 0,
                isFounder: true,
                size: 84
            )
            .overlay {
                PixelPanelBorder(thickness: 3, corner: 3)
                    .fill(ShareInk.ink)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(founder.displayName)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(ShareInk.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                PixelCompanyName(name: state.company.name, scale: 3, color: ShareInk.ink)
                Text("\(founder.archetype.displayName) · \(state.origin.displayName) · \(state.difficulty.displayName)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(ShareInk.faint)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Chapters

    private var chapters: some View {
        VStack(alignment: .leading, spacing: 5) {
            PixelText(text: "The story", scale: 2, color: ShareInk.accent)
            ForEach(state.progression.chapterLog, id: \.chapter) { entry in
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                    PixelText(text: "\(entry.chapter)", scale: 2, color: ShareInk.accent)
                        .frame(width: 16, alignment: .leading)
                    Text(ChapterDef.title(for: entry.chapter))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(ShareInk.ink)
                        .lineLimit(1)
                    dots
                    Text(entry.day == 0 ? "Day one" : "Day \(entry.day)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(ShareInk.faint)
                        .monospacedDigit()
                }
            }
            HStack(spacing: Theme.Spacing.sm) {
                Text("\(state.progression.completedGoalIDs.count) goals finished")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(ShareInk.faint)
                if !state.progression.earnedPerks.isEmpty {
                    Text("· \(state.progression.earnedPerks.map(\.displayName).joined(separator: ", "))")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(ShareInk.faint)
                        .lineLimit(1)
                }
            }
        }
    }

    /// The leader dots between a chapter and its day.
    private var dots: some View {
        Rectangle()
            .fill(ShareInk.ink.opacity(0.25))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)
            .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 3 }
    }

    // MARK: - The work

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

    private func productColumn(_ best: (product: Product, info: ReleaseInfo)) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            PixelText(text: "Best thing shipped", scale: 2, color: ShareInk.accent)
            HStack(spacing: Theme.Spacing.sm) {
                ProductBoxArtView(
                    typeID: best.product.typeID, topicID: best.product.topicID,
                    seed: best.product.boxArtSeed, size: 56,
                    // MARK: Iteration 18 — the studio mark on the cover.
                    markSeed: state.company.markSeed
                    // MARK: end of Iteration 18
                )
                VStack(alignment: .leading, spacing: 3) {
                    Text(best.product.name)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(ShareInk.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    HStack(spacing: 6) {
                        PixelText(text: "\(best.info.averageReviewScore)", scale: 3, color: Theme.scoreTint(best.info.averageReviewScore))
                        Text("\(topicName(best.product.topicID)) · \(best.info.totalRevenue.money)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(ShareInk.faint)
                            .lineLimit(1)
                    }
                }
            }
            if let review = best.info.reviews.max(by: { $0.score < $1.score }) {
                Text("\u{201C}\(review.blurb)\u{201D} — \(review.outlet)")
                    .font(.system(size: 12, weight: .regular, design: .serif).italic())
                    .foregroundStyle(ShareInk.ink.opacity(0.8))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var nothingShipped: some View {
        VStack(alignment: .leading, spacing: 6) {
            PixelText(text: "Shipped", scale: 2, color: ShareInk.accent)
            Text("Nothing reached the shelf.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(ShareInk.faint)
        }
    }

    // MARK: - The people

    private var longestServing: Employee? {
        state.employees
            .filter { !$0.isFounder }
            .min { lhs, rhs in
                if lhs.hiredDay != rhs.hiredDay { return lhs.hiredDay < rhs.hiredDay }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    @ViewBuilder
    private var peopleColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            PixelText(text: "Stayed longest", scale: 2, color: ShareInk.accent)
            if let longest = longestServing {
                HStack(spacing: Theme.Spacing.sm) {
                    PixelPortrait(seed: longest.appearanceSeed, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(longest.name)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(ShareInk.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("\(longest.role.displayName) · day \(longest.hiredDay)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(ShareInk.faint)
                            .lineLimit(1)
                    }
                }
                Text(tenureLine(longest))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(ShareInk.faint)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Nobody but you, start to finish.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(ShareInk.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func tenureLine(_ employee: Employee) -> String {
        let weeks = max(0, (info.day - employee.hiredDay) / GameState.daysPerWeek)
        let tenure = weeks >= 52
            ? "\(weeks / 52) year\(weeks / 52 == 1 ? "" : "s")"
            : "\(weeks) week\(weeks == 1 ? "" : "s")"
        return "\(tenure) with you · \(state.headcount) on payroll at the end"
    }

    // MARK: - The life

    /// One line on the rest of it: who was at home, and where home was.
    private var life: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            PixelText(text: "The rest", scale: 2, color: ShareInk.accent)
                .padding(.top, 1)
            Text(lifeLine)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(ShareInk.ink.opacity(0.8))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var lifeLine: String {
        let family = state.life.family
        let home = state.life.home.displayName.lowercased()
        let weekends = state.progression.stats.weekendsOff
        let who: String = switch family.stage {
        case .single: family.children.isEmpty ? "Single" : "Raising \(family.children.count) alone"
        case .dating: "Seeing \(family.partnerName ?? "someone")"
        case .partner: "Living with \(family.partnerName ?? "your partner")"
        case .married:
            "Married to \(family.partnerName ?? "your partner")"
                + (family.children.isEmpty ? "" : ", \(family.children.count) \(family.children.count == 1 ? "child" : "children")")
        }
        // Iteration 9 — L2: the life score leads the line about the life.
        let life = LifeScore.score(state, balance: engine.balance)
        return "Life \(life) · \(who) · finished in a \(home) · "
            + "\(weekends) weekend\(weekends == 1 ? "" : "s") actually spent on something"
    }

    // MARK: - The money

    private var money: some View {
        let netWorth = state.founderNetWorth(balance: engine.balance)
        return HStack(alignment: .lastTextBaseline, spacing: Theme.Spacing.md) {
            PixelText(text: netWorth.money, scale: 4, color: netWorth >= 0 ? ShareInk.success : ShareInk.failure)
            VStack(alignment: .leading, spacing: 2) {
                // Iteration 9 — L2: "$4.2M · Life 71", the two numbers a
                // finished run is remembered by.
                Text("final net worth · Life \(LifeScore.score(state, balance: engine.balance))")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(ShareInk.faint)
                Text("Company at \(state.companyValuation(balance: engine.balance).money) · \(state.investors.equityRemaining.oneDecimal)% yours")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(ShareInk.faint)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private func topicName(_ id: String) -> String {
        engine.content.topic(id)?.name ?? id
    }
}

/// A company name in pixel caps when it fits on one line, in the rounded
/// face when it does not: the bitmap font is a display face for short
/// labels and cannot wrap. Shared by the title screen's Continue card and
/// the share cards.
struct PixelCompanyName: View {
    let name: String
    var scale: CGFloat = 2
    var color: Color = Theme.pixelInk

    var body: some View {
        ViewThatFits(in: .horizontal) {
            PixelText(text: name, scale: scale, color: color)
            PixelText(text: name, scale: max(2, scale - 1), color: color)
            Text(name)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(color)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }
}
