import SwiftUI
import TycoonEngine

/// Iteration 11 — N3. Three tables, one stake picker, and the house edge
/// printed on every one of them.
///
/// The edge is on the card on purpose. A casino that hid its numbers would
/// be a slot machine; a casino that shows them and is still tempting is a
/// character note about the founder.
struct AssetCasinoSheet: View {
    let engine: GameEngine

    @Environment(\.dismiss) private var dismiss
    @Environment(GameShell.self) private var injectedShell: GameShell?
    private var shell: GameShell { injectedShell ?? .shared }

    /// The stake the picker is on, per table.
    @State private var stakes: [String: Int] = [:]
    /// The last hand's line, kept on screen so a tap has a consequence you
    /// can read rather than a toast you might miss.
    @State private var lastLine: String?

    var body: some View {
        let state = engine.state
        let config = engine.balance.assets

        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    CardView("The floor", systemImage: "suit.spade.fill") {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            HStack(alignment: .top, spacing: Theme.Spacing.xl) {
                                CasinoFigure(label: "In your wallet", value: state.life.wallet.money,
                                             tint: state.life.wallet < 0 ? Theme.negativeCash : .primary)
                                CasinoFigure(label: "Staked this week",
                                             value: state.assets.stakedThisWeek.money,
                                             tint: .secondary)
                            }
                            Text("The house will take \(config.weeklyStakeCap.money) off you in a week and then politely stop.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            if let lastLine {
                                Text(lastLine)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Theme.accent)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    ForEach(config.games) { game in
                        CasinoTable(
                            engine: engine,
                            game: game,
                            stake: binding(for: game),
                            play: { play(game) }
                        )
                    }

                    CardView("What it is doing to you", systemImage: "exclamationmark.triangle.fill") {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            let dependency = state.assets.dependency("gambling")
                            let threshold = config.vice("gambling")?.interventionAt ?? 55
                            AssetMeterBar(
                                label: "Gambling", systemImage: "suit.spade.fill",
                                value: dependency,
                                tint: AssetsPresentation.viceTint(dependency, threshold: threshold),
                                caption: AssetsPresentation.viceBand(dependency, threshold: threshold)
                            )
                            Text("Every hand adds to it, win or lose. Past \(Int(threshold)) somebody who loves you says something.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle("The casino")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Leave") { dismiss() }
                }
            }
        }
    }

    private func binding(for game: BalanceConfig.AssetsBalance.AssetGameDef) -> Binding<Int> {
        Binding(
            get: { stakes[game.id] ?? game.minStake },
            set: { stakes[game.id] = $0 }
        )
    }

    /// One hand, through the ordinary reducer, and the line it produced.
    private func play(_ game: BalanceConfig.AssetsBalance.AssetGameDef) {
        let stake = stakes[game.id] ?? game.minStake
        Haptics.commit()
        let events = shell.toasts.send(.playCasinoGame(gameID: game.id, stake: stake), to: engine)
        for event in events {
            guard case let .casinoHandPlayed(_, staked, returned, _) = event else { continue }
            lastLine = returned > staked
                ? "\(game.name): \(staked.money) came back as \(returned.money)."
                : "\(game.name): \(staked.money) gone, in the time it takes to say it."
        }
    }
}

private struct CasinoFigure: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value)
                .font(Theme.Typography.number(.title3))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .animation(Theme.Motion.valueChange, value: value)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct CasinoTable: View {
    let engine: GameEngine
    let game: BalanceConfig.AssetsBalance.AssetGameDef
    @Binding var stake: Int
    let play: () -> Void

    /// The four chips every table offers, clamped to its own limits.
    private var chips: [Int] {
        [game.minStake, game.minStake * 4, game.maxStake / 2, game.maxStake]
            .map { min(game.maxStake, max(game.minStake, $0)) }
            .reduce(into: [Int]()) { if !$0.contains($1) { $0.append($1) } }
    }

    var body: some View {
        let blocker = engine.state.assetGambleBlocker(game.id, stake: stake, balance: engine.balance)

        CardView(game.name, systemImage: "rectangle.grid.2x2.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text(game.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(oddsLine)
                    .font(Theme.Typography.number(.caption))
                    .foregroundStyle(Theme.warning)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(chips, id: \.self) { amount in
                        Button {
                            Haptics.tap()
                            stake = amount
                        } label: {
                            Text(amount.money)
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(stake == amount ? Theme.accent : Color.secondary)
                    }
                }

                Button {
                    play()
                } label: {
                    Label("Stake \(stake.money)", systemImage: "hand.tap.fill")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(blocker != nil)
                AssetRefusalNote(reason: blocker)
            }
        }
    }

    /// The honest sentence: what a dollar comes back as, on average.
    private var oddsLine: String {
        let ret = game.expectedReturn
        let edge = (1 - ret) * 100
        return "Wins \(Int((game.winChance * 100).rounded()))% of the time and pays ×\(game.payout.formatted(.number.precision(.fractionLength(0)).locale(Theme.gameLocale))). Every dollar comes back as \(ret.formatted(.number.precision(.fractionLength(2)).locale(Theme.gameLocale))) — a \(edge.formatted(.number.precision(.fractionLength(1)).locale(Theme.gameLocale)))% edge, to them."
    }
}
