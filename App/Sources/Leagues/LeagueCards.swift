import SwiftUI
import TycoonEngine

// MARK: Iteration 10 — M4 (leagues)

/// This week's league, before it is played: the rung you are on, the
/// table so far, the week everyone in your tier is playing, and one
/// button.
struct LeagueCard: View {
    let week: LeagueWeek
    let record: LeagueRecord
    /// Set when an attempt is already under way: the day it stopped on.
    var resumingFromDay: Int?
    var onPlay: () -> Void = {}

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                PixelSectionTitle(title: "This week's league")

                LeagueTierBadge(tier: record.tier)

                Text(week.dateRangeText)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Theme.pixelInk)
                    .fixedSize(horizontal: false, vertical: true)

                Text("One company, one attempt, one game year — the same seed for everyone in \(record.tier.displayName). Top four go up on Monday, bottom four go down.")
                    .font(.footnote)
                    .foregroundStyle(Theme.pixelInk.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)

                facts

                if let line = record.lastWeekLine {
                    Text(line)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.pixelInk.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(week.closingText())
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)

                if let resumingFromDay {
                    Text("Under way — day \(resumingFromDay) of \(LeagueWeek.horizonDays).")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }

                Button(action: onPlay) {
                    Label(
                        resumingFromDay == nil ? "Play the week" : "Resume",
                        systemImage: resumingFromDay == nil ? "play.fill" : "arrow.clockwise"
                    )
                    .font(.system(.headline, design: .rounded))
                }
                .buttonStyle(PixelButtonStyle())
                .accessibilityHint("One attempt. The company is the same for everyone in your tier")

                LeagueSeedLine(code: week.seedCode)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "This week's league, \(record.tier.displayName). \(week.dateRangeText). "
                + "\(week.origin.displayName), \(week.difficulty.displayName)."
        )
    }

    @ViewBuilder
    private var facts: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.sm))
            : AnyLayout(HStackLayout(alignment: .top, spacing: Theme.Spacing.md))
        layout {
            LeagueFact(icon: week.origin.systemImageName, title: week.origin.displayName, detail: week.origin.blurb)
            LeagueFact(icon: "dial.medium", title: week.difficulty.displayName, detail: week.difficulty.blurb)
        }
    }
}

/// This week's league, after it is played: what the company was worth,
/// where it put you, and the challenge you can send from it.
struct LeagueResultCard: View {
    let week: LeagueWeek
    let tier: LeagueTier
    let entry: LeagueLedger.Entry
    /// The line a *Beat my company* share pastes; nothing when the run
    /// left no year behind.
    var challengeText: String?

    var body: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                PixelSectionTitle(title: "This week's league")

                LeagueTierBadge(tier: tier)

                Text(week.dateRangeText)
                    .font(.footnote)
                    .foregroundStyle(Theme.pixelInk.opacity(0.7))

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    ViewThatFits(in: .horizontal) {
                        PixelText(text: entry.score.money, scale: 4, color: scoreTint)
                        PixelText(text: entry.score.money, scale: 3, color: scoreTint)
                        PixelText(text: entry.score.money, scale: 2, color: scoreTint)
                    }
                    Text("what you walked away with")
                        .font(.caption)
                        .foregroundStyle(Theme.pixelInk.opacity(0.7))
                }

                Text("\(entry.headline) · day \(entry.gameDay) of \(LeagueWeek.horizonDays)")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.pixelInk)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    ForEach(Array(entry.lines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.caption)
                            .foregroundStyle(Theme.pixelInk.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let grid = entry.grid, !grid.isEmpty {
                    Text(YearGrid.wrapped(grid))
                        .font(.system(.caption, design: .monospaced))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(YearGrid.spoken(grid))
                }

                if let challengeText {
                    ShareLink(item: challengeText) {
                        Label("Beat my company", systemImage: "flag.checkered")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    }
                    .buttonStyle(PixelButtonStyle())
                    .simultaneousGesture(TapGesture().onEnded {
                        Haptics.tap()
                        Sounds.play(.tap)
                    })
                    .accessibilityHint("Sends your year, your score and a link that founds the same company")
                }

                Label(boardNote, systemImage: entry.submitted ? "checkmark.seal.fill" : "clock.badge.xmark")
                    .font(.caption)
                    .foregroundStyle(entry.submitted ? Theme.positiveCash : Theme.pixelInk.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)

                Text(entry.isSettled
                     ? "\(LeagueTable.placeText(rank: entry.rank, fieldSize: entry.fieldSize)) · \(entry.outcome.headline)."
                     : "The table settles when the week rolls over on Monday.")
                    .font(.caption)
                    .foregroundStyle(Theme.pixelInk.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "This week's league, finished. \(entry.score.money), \(entry.headline), day \(entry.gameDay). \(boardNote)"
        )
    }

    private var scoreTint: Color {
        entry.score >= 0 ? Theme.pixelAccent : Theme.negativeCash
    }

    private var boardNote: String {
        entry.submitted
            ? "Sent to the \(tier.displayName) board."
            : "The week had already closed — this one isn't on the board."
    }
}

/// The tier as a badge: the rung, its colour, and what it means.
struct LeagueTierBadge: View {
    let tier: LeagueTier

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: tier.systemImageName)
                .font(.title2)
                .foregroundStyle(tier.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(tier.displayName) league")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Theme.pixelInk)
                Text(tier.blurb)
                    .font(.caption)
                    .foregroundStyle(Theme.pixelInk.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The week's table: twenty rows at most, your own row marked, and the
/// promotion and relegation lines drawn where they fall.
struct LeagueTableView: View {
    let standings: [LeagueStanding]
    let source: LeagueView.Source

    var body: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                PixelSectionTitle(title: "The table")
                if standings.isEmpty {
                    Text(LeagueView.Source.none.line)
                        .font(.caption)
                        .foregroundStyle(Theme.pixelInk.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(Array(standings.enumerated()), id: \.element.id) { index, row in
                        LeagueRow(
                            rank: index + 1,
                            standing: row,
                            outcome: LeagueRules.outcome(rank: index + 1, fieldSize: standings.count)
                        )
                    }
                    Text(source.line)
                        .font(.caption2)
                        .foregroundStyle(Theme.pixelInk.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// One row of the table: place, name, what they walked away with, and
/// the arrow saying which way that place goes on Monday.
struct LeagueRow: View {
    let rank: Int
    let standing: LeagueStanding
    let outcome: LeagueOutcome

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            PixelText(text: "\(rank)", scale: 2, color: Theme.pixelInk)
                .frame(width: 28, alignment: .leading)
                .accessibilityHidden(true)
            Text(standing.name)
                .font(.system(.subheadline, design: .rounded).weight(standing.isYou ? .bold : .regular))
                .foregroundStyle(Theme.pixelInk)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: Theme.Spacing.sm)
            Text(standing.score.money)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(standing.score >= 0 ? Theme.pixelInk : Theme.negativeCash)
            Image(systemName: outcome.systemImageName)
                .font(.caption)
                .foregroundStyle(outcome.tint)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, Theme.Spacing.xs)
        .background(
            standing.isYou ? Theme.accent.opacity(0.12) : Color.clear,
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(rank). \(standing.name), \(standing.score.money)\(standing.isYou ? ", you" : ""). \(outcome.headline)."
        )
    }
}

/// The seed under the card, so anybody can found the same company by
/// hand — the daily's code line, with a league's wording.
struct LeagueSeedLine: View {
    let code: SeedCode

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Seed")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.pixelInk.opacity(0.6))
            Text(code.encoded)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Theme.pixelInk.opacity(0.8))
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("This week's seed code, \(code.encoded)")
    }
}

/// What last week did to your tier, shown once.
struct LeagueSettlementCard: View {
    let settlement: LeagueView.Settlement

    var body: some View {
        PixelPanel {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Image(systemName: settlement.outcome.systemImageName)
                    .font(.title)
                    .foregroundStyle(settlement.outcome.tint)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(settlement.outcome.headline)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(Theme.pixelInk)
                    Text(settlement.line)
                        .font(.caption)
                        .foregroundStyle(Theme.pixelInk.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(settlement.outcome.headline). \(settlement.line)")
    }
}

private struct LeagueFact: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: icon)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.pixelInk)
            Text(detail)
                .font(.caption)
                .foregroundStyle(Theme.pixelInk.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - The screen

/// The League: your rung, what last week did to it, the week's company,
/// and the table you are climbing.
struct LeagueScreen: View {
    let view: LeagueView
    var onPlay: (LeagueWeek) -> Void = { _ in }
    var challengeText: String?

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            if let settlement = view.settlement {
                LeagueSettlementCard(settlement: settlement)
            }
            switch view.entry {
            case .play(let week):
                LeagueCard(week: week, record: view.record) { onPlay(week) }
            case .resume(let week, let day):
                LeagueCard(week: week, record: view.record, resumingFromDay: day) { onPlay(week) }
            case .result(let week, let entry):
                LeagueResultCard(
                    week: week, tier: entry.tier, entry: entry, challengeText: challengeText
                )
            }
            LeagueTableView(standings: view.standings, source: view.source)
        }
    }
}

/// The sheet the title screen's *League* row opens.
struct LeagueSheet: View {
    let view: LeagueView
    var challengeText: String?
    var onPlay: (LeagueWeek) -> Void = { _ in }
    var onClose: () -> Void = {}

    var body: some View {
        NavigationStack {
            ScrollView {
                LeagueScreen(view: view, onPlay: onPlay, challengeText: challengeText)
                    .padding(Theme.Spacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Theme.screenBackground.ignoresSafeArea())
            .navigationTitle("League")
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.large])
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("This week") {
    LeagueSheet(view: LeagueView(
        week: LeagueWeek.forWeek(36),
        record: LeagueRecord(
            tier: .silver, settledWeek: 35, lastRank: 6, lastFieldSize: 20,
            lastOutcome: .held, bestTier: .silver, weeksPlayed: 4
        ),
        entry: .play(LeagueWeek.forWeek(36)),
        standings: [
            LeagueStanding(name: "Rune", score: 412_000),
            LeagueStanding(name: "Okafor", score: 380_500),
            LeagueStanding(name: "You", score: 274_000, isYou: true),
            LeagueStanding(name: "Vess", score: 190_000),
            LeagueStanding(name: "Halloran", score: 42_000),
        ],
        source: .ghosts
    ))
}
