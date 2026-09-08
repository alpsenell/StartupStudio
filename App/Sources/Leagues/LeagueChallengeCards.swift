import SwiftUI
import TycoonEngine

// MARK: Iteration 10 — M4 (leagues): Beat my company

/// A challenge that arrived by link: whose company it is, the year they
/// had, what they walked away with, and the two buttons.
struct LeagueChallengeCard: View {
    let challenge: LeagueChallenge
    var onAccept: () -> Void = {}
    var onDecline: () -> Void = {}

    private var strip: String { YearGrid.strip(fromLetters: challenge.grid) }

    var body: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                PixelSectionTitle(title: "Beat my company")

                Text("\(challenge.challenger) ran this company for a year.")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Theme.pixelInk)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    ViewThatFits(in: .horizontal) {
                        PixelText(text: challenge.score.money, scale: 4, color: Theme.pixelAccent)
                        PixelText(text: challenge.score.money, scale: 3, color: Theme.pixelAccent)
                        PixelText(text: challenge.score.money, scale: 2, color: Theme.pixelAccent)
                    }
                    Text("what they walked away with")
                        .font(.caption)
                        .foregroundStyle(Theme.pixelInk.opacity(0.7))
                }

                if !strip.isEmpty {
                    Text(YearGrid.wrapped(strip))
                        .font(.system(.caption, design: .monospaced))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(YearGrid.spoken(strip))
                }

                Text("Same seed, same founder, same first day — \(challenge.code.origin.displayName), \(challenge.code.difficulty.displayName). The rest is yours.")
                    .font(.footnote)
                    .foregroundStyle(Theme.pixelInk.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onAccept) {
                    Label("Take it on", systemImage: "flag.checkered")
                        .font(.system(.headline, design: .rounded))
                }
                .buttonStyle(PixelButtonStyle())
                .accessibilityHint("Starts their company in a save slot; you are told how you did when it ends")

                Button("Not now", action: onDecline)
                    .font(.system(.subheadline, design: .rounded))
                    .buttonStyle(.borderless)
                    .tint(Theme.accent)

                LeagueSeedLine(code: challenge.code)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "Beat my company. \(challenge.challenger) walked away with \(challenge.score.money)."
        )
    }
}

/// The comparison, once the player's own run on that seed has stopped:
/// two years, two numbers, one verdict.
struct LeagueChallengeResultCard: View {
    let result: LeagueChallengeResult

    var body: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                PixelSectionTitle(title: "Beat my company")

                Text(result.headline)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(result.youWon ? Theme.positiveCash : Theme.pixelInk)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Both of you ran \(result.companyName) from the same first day.")
                    .font(.footnote)
                    .foregroundStyle(Theme.pixelInk.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)

                LeagueGridColumn(
                    title: "You", score: result.yourScore,
                    strip: YearGrid.strip(fromLetters: result.yourGrid),
                    isWinner: result.youWon
                )
                LeagueGridColumn(
                    title: result.challenger, score: result.challengerScore,
                    strip: YearGrid.strip(fromLetters: result.challengerGrid),
                    isWinner: !result.youWon && result.yourScore != result.challengerScore
                )

                ShareLink(item: shareText) {
                    Label("Share the two years", systemImage: "square.and.arrow.up")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                }
                .buttonStyle(PixelButtonStyle())
                .simultaneousGesture(TapGesture().onEnded {
                    Haptics.tap()
                    Sounds.play(.tap)
                })
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "\(result.headline) You finished on \(result.yourScore.money); "
                + "\(result.challenger) on \(result.challengerScore.money)."
        )
    }

    private var shareText: String {
        [
            "STARTUP STUDIO · \(result.companyName)",
            result.headline,
            "You  \(result.yourScore.money)",
            YearGrid.wrapped(YearGrid.strip(fromLetters: result.yourGrid)),
            "\(result.challenger)  \(result.challengerScore.money)",
            YearGrid.wrapped(YearGrid.strip(fromLetters: result.challengerGrid)),
        ].joined(separator: "\n")
    }
}

/// One side of the comparison: a name, a number and a year of squares.
private struct LeagueGridColumn: View {
    let title: String
    let score: Int
    let strip: String
    let isWinner: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.pixelInk)
                    .lineLimit(1)
                if isWinner {
                    Image(systemName: "crown.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.pixelAccent)
                        .accessibilityHidden(true)
                }
                Spacer(minLength: Theme.Spacing.sm)
                Text(score.money)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(score >= 0 ? Theme.pixelInk : Theme.negativeCash)
            }
            if strip.isEmpty {
                Text("No year to show.")
                    .font(.caption2)
                    .foregroundStyle(Theme.pixelInk.opacity(0.6))
            } else {
                Text(YearGrid.wrapped(strip))
                    .font(.system(.caption, design: .monospaced))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(YearGrid.spoken(strip))
            }
        }
        .padding(Theme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isWinner ? Theme.accent.opacity(0.12) : Theme.pixelInk.opacity(0.05),
            in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }
}

/// The sheets the front door puts these two cards in.
struct LeagueChallengeSheet: View {
    let challenge: LeagueChallenge
    var onAccept: () -> Void = {}
    var onDecline: () -> Void = {}

    var body: some View {
        NavigationStack {
            ScrollView {
                LeagueChallengeCard(challenge: challenge, onAccept: onAccept, onDecline: onDecline)
                    .padding(Theme.Spacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Theme.screenBackground.ignoresSafeArea())
            .navigationTitle("A challenge")
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.medium, .large])
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close", action: onDecline)
                }
            }
        }
    }
}

struct LeagueChallengeResultSheet: View {
    let result: LeagueChallengeResult
    var onClose: () -> Void = {}

    var body: some View {
        NavigationStack {
            ScrollView {
                LeagueChallengeResultCard(result: result)
                    .padding(Theme.Spacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Theme.screenBackground.ignoresSafeArea())
            .navigationTitle("Beat my company")
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.medium, .large])
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("A challenge") {
    LeagueChallengeSheet(challenge: LeagueChallenge(
        code: SeedCode(seed: 0xC0FFEE, origin: .garage, difficulty: .normal),
        grid: "QQUULDDULUUCRUUUDDLUUUQ",
        score: 312_400,
        challenger: "Mira"
    ))
}

#Preview("The comparison") {
    LeagueChallengeResultSheet(result: LeagueChallengeResult(
        challenger: "Mira",
        challengerScore: 312_400,
        challengerGrid: "QQUULDDULUUCRUUUDDLUUUQ",
        yourScore: 401_900,
        yourGrid: "QQUUUDLUURUUCUUUDDLUUUL",
        companyName: "Northgate Softworks"
    ))
}
