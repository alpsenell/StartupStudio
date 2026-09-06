import SwiftUI
import TycoonEngine

// MARK: Iteration 8 — awards night

/// The ceremony: the year's winners on pixel paper, the player's wins lit.
struct AwardsNightSheet: View {
    let night: AwardsNight
    let companyName: String
    var onClose: () -> Void = {}

    // MARK: Iteration 9 — L7 (furnish)
    /// A night the company won something leaves the pennant, which hangs
    /// on a wall at home from then on.
    @Environment(\.gameSession) private var session
    // MARK: end of Iteration 9 — L7

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    PixelPanel {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            PixelText(text: "THE INDUSTRY AWARDS", scale: 3, color: Theme.pixelAccent)
                            PixelText(text: "YEAR \(night.year)", scale: 2, color: Theme.pixelInk)
                            Text(headline)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(Theme.pixelInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    ForEach(night.categories) { category in
                        AwardRow(category: category)
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Theme.screenBackground.ignoresSafeArea())
            // MARK: Iteration 9 — L7 (furnish)
            .onAppear {
                if !night.playerWins.isEmpty { session?.unlockAwardsPennant() }
            }
            // MARK: end of Iteration 9 — L7
            .navigationTitle("Awards night")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                }
            }
        }
    }

    private var headline: String {
        let wins = night.playerWins.count
        switch wins {
        case 0: return "\(companyName) went home empty-handed. The press noticed who did not."
        case 1: return "\(companyName) took one home: \(night.playerWins[0].title)."
        default: return "\(companyName) took \(wins) home, \(night.playerWins.map(\.title).joined(separator: ", "))."
        }
    }
}

private struct AwardRow: View {
    let category: AwardCategory

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: category.winner?.isPlayer == true ? "trophy.fill" : "trophy")
                .font(.body)
                .foregroundStyle(category.winner?.isPlayer == true ? Theme.accent : Color.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(category.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let winner = category.winner {
                    Text(winner.name)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(winner.isPlayer ? Theme.accent : .primary)
                    Text(winner.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Nobody shipped.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if category.winner?.isPlayer == true {
                Text("YOU")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
