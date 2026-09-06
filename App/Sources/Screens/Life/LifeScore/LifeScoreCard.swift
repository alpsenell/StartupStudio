import SwiftUI
import TycoonEngine

// MARK: Iteration 9 — L2 (a life score)

/// The founder's own number, in the You section: the score, the four
/// biggest components as bars, and the one thing that would raise it most.
///
/// It sits under the wellbeing meters because it is what the meters add up
/// to — plus the people, the evenings and the home the meters never see.
struct LifeScoreCard: View {
    let engine: GameEngine
    /// Opens the full breakdown.
    let onOpen: () -> Void

    private var score: Int { LifeScore.score(engine.state, balance: engine.balance) }

    private var components: [LifeScore.Component] {
        LifeScore.breakdown(state: engine.state, balance: engine.balance)
    }

    /// The four widest bars plus the penalty when it bites: the card is a
    /// glance, the screen is the audit.
    private var shown: [LifeScore.Component] {
        let scored = components.filter { $0.max > 0 }
        let penalty = components.first { $0.max <= 0 && $0.points < 0 }
        return Array(scored.prefix(4)) + (penalty.map { [$0] } ?? [])
    }

    var body: some View {
        let gap = LifeScore.biggestGap(state: engine.state, balance: engine.balance)
        let canWalk = engine.state.canWalkAway(balance: engine.balance)

        CardView("Your life", systemImage: "heart.text.square.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                PixelPanel(thickness: 3) {
                    HStack(alignment: .center, spacing: Theme.Spacing.md) {
                        LifeScoreFigure(score: score, scale: 6)
                        Text(LifeScoreFigure.verdict(score))
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.pixelInk)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }

                LifeScoreBreakdown(components: shown, showsDetail: false)

                if let gap, let advice = gap.advice {
                    Label(advice, systemImage: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Would raise it most: \(advice)")
                }

                Divider()

                HStack {
                    if canWalk {
                        Label("You could walk away", systemImage: "figure.walk.departure")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.positiveCash)
                    }
                    Spacer(minLength: Theme.Spacing.sm)
                    Button {
                        Haptics.tap()
                        onOpen()
                    } label: {
                        HStack(spacing: 4) {
                            Text("The whole score")
                                .font(.footnote.weight(.semibold))
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.bold))
                        }
                        .foregroundStyle(Theme.accent)
                    }
                    .accessibilityLabel("Open the life score breakdown")
                }
            }
        }
    }
}
