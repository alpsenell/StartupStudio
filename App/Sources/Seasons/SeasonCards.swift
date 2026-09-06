import SwiftUI
import TycoonEngine

// MARK: Iteration 8 — seasons

/// The season's card: the dates, the twist, the company, and Play — or
/// the result once the year is played.
struct SeasonSheet: View {
    let entry: SeasonEntry
    var onPlay: (GameSeason) -> Void = { _ in }
    var onClose: () -> Void = {}

    var body: some View {
        NavigationStack {
            ScrollView {
                content
                    .padding(Theme.Spacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Theme.screenBackground.ignoresSafeArea())
            .navigationTitle("This season")
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
        case .play(let season):
            SeasonCard(season: season) { onPlay(season) }
        case .resume(let season, let day):
            SeasonCard(season: season, resumingFromDay: day) { onPlay(season) }
        case .result(let season, let result):
            SeasonResultCard(season: season, entry: result)
        }
    }
}

struct SeasonCard: View {
    let season: GameSeason
    var resumingFromDay: Int?
    var onPlay: () -> Void = {}

    var body: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                PixelSectionTitle(title: "Season \(season.number)")
                Text(season.dateRangeText)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Theme.pixelInk)
                VStack(alignment: .leading, spacing: 2) {
                    Text(season.twist.title)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.pixelAccent)
                    Text(season.twist.detail)
                        .font(.footnote)
                        .foregroundStyle(Theme.pixelInk.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("\(season.origin.displayName) · \(season.difficulty.displayName). One attempt, one game year, everyone on the same seed. Finish it and the season's face is yours to found with.")
                    .font(.caption)
                    .foregroundStyle(Theme.pixelInk.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                if let resumingFromDay {
                    Text("Under way — day \(resumingFromDay) of \(GameSeason.horizonDays).")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
                Button(action: onPlay) {
                    Label(resumingFromDay == nil ? "Play" : "Resume", systemImage: resumingFromDay == nil ? "play.fill" : "arrow.clockwise")
                        .font(.system(.headline, design: .rounded))
                }
                .buttonStyle(PixelButtonStyle())
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("GameSeason \(season.number), \(season.dateRangeText). \(season.twist.title): \(season.twist.detail)")
    }
}

struct SeasonResultCard: View {
    let season: GameSeason
    let entry: SeasonLedger.Entry

    var body: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                PixelSectionTitle(title: "Season \(season.number)")
                Text(season.twist.title)
                    .font(.footnote)
                    .foregroundStyle(Theme.pixelInk.opacity(0.7))
                ViewThatFits(in: .horizontal) {
                    PixelText(text: entry.score.money, scale: 4, color: scoreTint)
                    PixelText(text: entry.score.money, scale: 3, color: scoreTint)
                }
                Text("\(entry.endingKind?.headline ?? "The year ran out") · day \(entry.gameDay) of \(GameSeason.horizonDays)")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.pixelInk)
                if let grid = entry.grid, !grid.isEmpty {
                    Text(YearGrid.wrapped(grid))
                        .font(.system(.caption, design: .monospaced))
                        .lineSpacing(2)
                        .accessibilityLabel(YearGrid.spoken(grid))
                    ShareLink(item: YearGrid.shareText(
                        title: "STARTUP STUDIO · GameSeason \(season.number) · \(season.twist.title)",
                        strip: grid,
                        scoreLine: "\(entry.score.money) · \(entry.endingKind?.headline ?? "the year ran out") on day \(entry.gameDay)",
                        code: SeedCode(seed: season.seed, origin: season.origin, difficulty: season.difficulty).encoded
                    )) {
                        Label("Share the season", systemImage: "square.and.arrow.up")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    }
                    .buttonStyle(PixelButtonStyle())
                }
                Label(entry.submitted ? "Sent to the season's board." : "The season had closed — not on the board.",
                      systemImage: entry.submitted ? "checkmark.seal.fill" : "clock.badge.xmark")
                    .font(.caption)
                    .foregroundStyle(entry.submitted ? Theme.positiveCash : Theme.pixelInk.opacity(0.7))
                Label("The season's face is in your looks.", systemImage: "face.smiling")
                    .font(.caption)
                    .foregroundStyle(Theme.pixelInk.opacity(0.7))
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var scoreTint: Color {
        entry.score >= 0 ? Theme.pixelAccent : Theme.negativeCash
    }
}
