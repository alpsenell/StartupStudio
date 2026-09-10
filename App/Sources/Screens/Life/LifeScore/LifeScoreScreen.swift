import SwiftUI
import TycoonEngine

// MARK: Iteration 9 — L2 (a life score)

/// The whole score: every component with its number, its bar, its one
/// fact and what would raise it — and, when the founder has earned it,
/// the way out.
///
/// The company has had a screen that says what it is worth since the
/// first week. This is the other one.
struct LifeScoreScreen: View {
    let engine: GameEngine

    // MARK: K5 (hand over the keys)
    @State private var handingOver = DebugLaunch.opensHandOverSheet
    // MARK: end K5

    var body: some View {
        ScrollView {
            LifeScoreContent(
                score: LifeScore.score(engine.state, balance: engine.balance),
                netWorth: engine.state.founderNetWorth(balance: engine.balance),
                components: LifeScore.breakdown(state: engine.state, balance: engine.balance),
                gap: LifeScore.biggestGap(state: engine.state, balance: engine.balance),
                walkAway: WalkAwayTerms(state: engine.state, balance: engine.balance),
                onWalkAway: { engine.send(.walkAway) },
                // MARK: K5 (hand over the keys)
                handOver: HandOverGate(state: engine.state, balance: engine.balance),
                onHandOver: { handingOver = true }
                // MARK: end K5
            )
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.screenBackground)
        .navigationTitle("Your life")
        .navigationBarTitleDisplayMode(.inline)
        // MARK: K5 (hand over the keys)
        .sheet(isPresented: $handingOver) {
            HandOverSheet(engine: engine) { handingOver = false }
        }
        // MARK: end K5
    }
}

/// The gates on *Walked away*, read once so the screen and its button
/// agree: a row per condition, and the blocker the founder would be
/// refused with.
struct WalkAwayTerms: Equatable {
    let companyName: String
    let day: Int
    let minDay: Int
    let debtFree: Bool
    let boardFree: Bool
    let hasSuccessor: Bool
    let netWorth: Int
    let minNetWorth: Int
    let life: Int
    let minLife: Int
    let blocker: String?

    init(state: GameState, balance: BalanceConfig) {
        let config = balance.lifeScore
        companyName = state.company.name
        day = state.day
        minDay = config.walkAwayMinDay
        debtFree = state.company.cash >= 0 && state.loanBalance <= 0
        boardFree = !state.investors.hasBoard
        hasSuccessor = state.headcount > 1
        netWorth = state.founderNetWorth(balance: balance)
        minNetWorth = config.walkAwayMinNetWorth
        life = LifeScore.score(state, balance: balance)
        minLife = config.walkAwayMinLifeScore
        blocker = state.walkAwayBlocker(balance: balance)
    }

    var ready: Bool { blocker == nil }

    /// The gate in weeks, not years: the default is a year and a half,
    /// and "1 years in" is what integer division does to that.
    var minWeeks: Int { max(1, minDay / GameState.daysPerWeek) }
}

/// The screen's content without the scroll view, so it can be rendered
/// directly — an `ImageRenderer` over a `ScrollView` draws nothing.
struct LifeScoreContent: View {
    let score: Int
    let netWorth: Int
    let components: [LifeScore.Component]
    let gap: LifeScore.Component?
    let walkAway: WalkAwayTerms
    let onWalkAway: () -> Void
    // MARK: K5 (hand over the keys)
    /// The second answer. `nil` draws the card exactly as it was, which is
    /// how the snapshot tests build it.
    var handOver: HandOverGate? = nil
    var onHandOver: () -> Void = {}
    // MARK: end K5

    @State private var confirming = false

    /// The bitmap kicker over the figure. Localized: PixelFont has no
    /// lowercase and no accents, so a translation has to survive being
    /// upper-cased and stripped to ASCII.
    static let kicker = String(
        localized: "LIFE SCORE",
        comment: "Kicker over the founder's life score on its own screen. Drawn in the pixel bitmap font: uppercase ASCII only, no accents, keep it short."
    )

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            header
            breakdownCard
            walkAwayCard
        }
    }

    // MARK: - The number

    private var header: some View {
        PixelPanel(thickness: 4, contentPadding: Theme.Spacing.lg) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                PixelText(text: Self.kicker, scale: 2, color: Theme.pixelAccent)
                LifeScoreFigure(score: score, scale: 9)
                Text(LifeScoreFigure.verdict(score))
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Theme.pixelInk)
                    .fixedSize(horizontal: false, vertical: true)
                Divider()
                // The two numbers, together, which is the whole point of
                // there being a second one.
                HStack(alignment: .lastTextBaseline, spacing: Theme.Spacing.sm) {
                    Text(netWorth.money)
                        .font(Theme.Typography.number(.subheadline, weight: .bold))
                        .foregroundStyle(netWorth >= 0 ? Theme.positiveCash : Theme.negativeCash)
                    Text("net worth · Life \(score)")
                        .font(.caption)
                        .foregroundStyle(Theme.pixelInk.opacity(0.7))
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Net worth \(netWorth.money), life score \(score) of 100")
            }
        }
    }

    // MARK: - The breakdown

    private var breakdownCard: some View {
        CardView("What it is made of", systemImage: "chart.bar.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                ForEach(components) { component in
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        LifeScoreBar(component: component)
                        if let advice = component.advice, component.headroom > 0.5 {
                            Text(advice)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(
                                    component.id == gap?.id ? Theme.accent : .secondary
                                )
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if let gap, let advice = gap.advice {
                    Divider()
                    Label(
                        "Most on the table: \(gap.label). \(advice)",
                        systemImage: "arrow.up.right"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - The way out

    private var walkAwayCard: some View {
        CardView("Walking away", systemImage: "figure.walk.departure") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text(
                    "Hand \(walkAway.companyName) over and go, with it standing and both "
                        + "numbers good. Nobody buys anything and nothing is cashed in — "
                        + "the company carries on without you, and the run ends here."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 2) {
                    gateRow(
                        "\(walkAway.minWeeks) weeks in (day \(walkAway.day) of \(walkAway.minDay))",
                        met: walkAway.day >= walkAway.minDay
                    )
                    gateRow("No debt, nothing overdrawn", met: walkAway.debtFree)
                    gateRow("No board in the room", met: walkAway.boardFree)
                    gateRow("Somebody to hand it to", met: walkAway.hasSuccessor)
                    gateRow(
                        "\(walkAway.minNetWorth.money) behind you (\(walkAway.netWorth.money) now)",
                        met: walkAway.netWorth >= walkAway.minNetWorth
                    )
                    gateRow(
                        "Life \(walkAway.minLife) (\(walkAway.life) now)",
                        met: walkAway.life >= walkAway.minLife
                    )
                }

                Button {
                    confirming = true
                } label: {
                    Label(
                        "Walk away — \(walkAway.netWorth.money) · Life \(walkAway.life)",
                        systemImage: "figure.walk.departure"
                    )
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.positiveCash)
                .disabled(!walkAway.ready)
                .accessibilityLabel(
                    walkAway.ready
                        ? "Walk away. Ends the run with the company standing."
                        : "Walk away. Not available: \(walkAway.blocker ?? "")"
                )

                if let blocker = walkAway.blocker {
                    Text(blocker)
                        .font(.caption)
                        .foregroundStyle(Theme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // MARK: K5 (hand over the keys)
                if let handOver {
                    handOverBlock(handOver)
                }
                // MARK: end K5
            }
        }
        .confirmationDialog(
            "Leave \(walkAway.companyName)?",
            isPresented: $confirming,
            titleVisibility: .visible
        ) {
            // K5: "Hand over the keys" is the other door's name now.
            Button("Walk away") {
                Haptics.commit()
                onWalkAway()
            }
            Button("Not yet", role: .cancel) {}
        } message: {
            Text(
                "This ends the run. \(walkAway.companyName) keeps going without you, "
                    + "with \(walkAway.netWorth.money) behind you and a life at \(walkAway.life)."
            )
        }
    }

    // MARK: K5 (hand over the keys)

    /// *Hand it to…*, under *Walk away*: the same card, the other answer,
    /// and why it is shut when it is.
    private func handOverBlock(_ gate: HandOverGate) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Divider()
            Text(
                "Or stay in it. Hand the keys to somebody here, keep 10, 25 or 50% of your "
                    + "stake as a silent share, and play on as them — unranked from then on."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Button {
                Haptics.tap()
                onHandOver()
            } label: {
                Label("Hand it to…", systemImage: "key.fill")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent)
            .disabled(!gate.ready)
            .accessibilityLabel(
                gate.ready
                    ? "Hand it to someone. Opens the choice of successor and stake."
                    : "Hand it to someone. Not available: \(gate.blocker ?? "")"
            )

            if let blocker = gate.blocker, blocker != walkAway.blocker {
                Text(blocker)
                    .font(.caption)
                    .foregroundStyle(Theme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: end K5

    private func gateRow(_ label: String, met: Bool) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundStyle(met ? AnyShapeStyle(Theme.positiveCash) : AnyShapeStyle(.tertiary))
            Text(label)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(met ? .primary : .secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label). \(met ? "Met" : "Not met")")
    }
}
