import SwiftUI
import TycoonEngine

// MARK: Iteration 7 — the daily (R3)

/// Today's company, before it is played: the date everyone else is
/// playing, the origin and difficulty the day's seed dealt, and one
/// button.
///
/// Drawn in the pixel language — panel, bitmap headings, the game's own
/// number formatting — and laid out so the accessibility type sizes stack
/// instead of truncating.
struct DailyCard: View {
    let challenge: DailyChallenge
    /// Set when an attempt is already under way: the day it stopped on.
    var resumingFromDay: Int?
    var onPlay: () -> Void = {}

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                PixelSectionTitle(title: "Today's company")

                Text(challenge.dateText)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Theme.pixelInk)
                    .fixedSize(horizontal: false, vertical: true)

                Text("The same seed, the same company, everywhere. One attempt, one game year.")
                    .font(.footnote)
                    .foregroundStyle(Theme.pixelInk.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)

                facts

                if let resumingFromDay {
                    Text("Under way — day \(resumingFromDay) of \(DailyChallenge.horizonDays).")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }

                Button(action: onPlay) {
                    Label(
                        resumingFromDay == nil ? "Play" : "Resume",
                        systemImage: resumingFromDay == nil ? "play.fill" : "arrow.clockwise"
                    )
                    .font(.system(.headline, design: .rounded))
                }
                .buttonStyle(PixelButtonStyle())
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "Today's company, \(challenge.dateText). "
                + "\(challenge.origin.displayName), \(challenge.difficulty.displayName)."
        )
    }

    /// Origin and difficulty side by side, stacked at the accessibility
    /// sizes where two columns stop fitting.
    @ViewBuilder
    private var facts: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                fact(icon: challenge.origin.systemImageName, title: challenge.origin.displayName, detail: challenge.origin.blurb)
                fact(icon: "dial.medium", title: challenge.difficulty.displayName, detail: challenge.difficulty.blurb)
            }
        } else {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                fact(icon: challenge.origin.systemImageName, title: challenge.origin.displayName, detail: challenge.origin.blurb)
                fact(icon: "dial.medium", title: challenge.difficulty.displayName, detail: challenge.difficulty.blurb)
            }
        }
    }

    private func fact(icon: String, title: String, detail: String) -> some View {
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

/// Today's company, after it is played: what it was worth, how it
/// stopped, the three lines, and whether the board took it.
struct DailyResultCard: View {
    let challenge: DailyChallenge
    let entry: DailyLedger.Entry

    var body: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                PixelSectionTitle(title: "Today's company")

                Text(challenge.dateText)
                    .font(.footnote)
                    .foregroundStyle(Theme.pixelInk.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)

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

                Text("\(entry.headline) · day \(entry.gameDay) of \(DailyChallenge.horizonDays)")
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

                Label(boardNote, systemImage: entry.submitted ? "checkmark.seal.fill" : "clock.badge.xmark")
                    .font(.caption)
                    .foregroundStyle(entry.submitted ? Theme.positiveCash : Theme.pixelInk.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)

                Text("Come back tomorrow for a new one.")
                    .font(.caption)
                    .foregroundStyle(Theme.pixelInk.opacity(0.7))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "Today's company, finished. \(entry.score.money), \(entry.headline), "
                + "day \(entry.gameDay). \(boardNote)"
        )
    }

    private var scoreTint: Color {
        entry.score >= 0 ? Theme.pixelAccent : Theme.negativeCash
    }

    private var boardNote: String {
        entry.submitted
            ? "Sent to today's board."
            : "The day had already closed — this one isn't on the board."
    }
}

/// The sheet the title screen's *Today's company* row opens: the
/// challenge, the attempt under way, or the result.
struct DailySheet: View {
    let entry: DailyEntry
    var onPlay: (DailyChallenge) -> Void = { _ in }
    var onClose: () -> Void = {}

    var body: some View {
        NavigationStack {
            ScrollView {
                content
                    .padding(Theme.Spacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Theme.screenBackground.ignoresSafeArea())
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.medium, .large])
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch entry {
        case .play(let challenge):
            DailyCard(challenge: challenge) { onPlay(challenge) }
        case .resume(let challenge, let day):
            DailyCard(challenge: challenge, resumingFromDay: day) { onPlay(challenge) }
        case .result(let challenge, let result):
            DailyResultCard(challenge: challenge, entry: result)
        }
    }
}

// MARK: - Previews

#Preview("Today") {
    DailySheet(entry: .play(DailyChallenge.forDay(247)))
}

#Preview("Finished") {
    DailySheet(entry: .result(
        DailyChallenge.forDay(247),
        DailyLedger.Entry(
            day: 247, score: 184_500, submitted: true, ending: nil, gameDay: 364,
            lines: [
                "Shipped 4 products, best reviewed 81.",
                "9 people on payroll, the longest 300 days in.",
                "Company worth $1,240,000; you still owned 74%.",
            ],
            finishedAt: Date()
        )
    ))
}
