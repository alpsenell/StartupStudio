import SwiftUI
import TycoonEngine

/// Iteration 11 — N3. The four habits, as four bars, with the one evening
/// you can spend on any of them tonight.
///
/// Dependency is 0…100 and drifts the meters in proportion, so a bar at
/// twelve is texture and a bar at seventy is the reason the health line is
/// falling. Above a vice's own threshold somebody who loves the founder
/// has already said something, and the card says who.
struct AssetVicesCard: View {
    let engine: GameEngine

    @Environment(GameShell.self) private var injectedShell: GameShell?
    private var shell: GameShell { injectedShell ?? .shared }

    /// What a run of evenings actually is, in one sentence.
    private var quitRule: String {
        let rules = engine.balance.assets.quitting
        return "A run is \(rules.evenings) evenings, one at a time. Each takes \(Int(rules.perEvening)) off the bar and costs a little mood, and about one in \(Int((1 / rules.relapseChance).rounded())) goes wrong and puts \(Int(rules.relapseGain)) back."
    }

    var body: some View {
        let state = engine.state
        let vices = engine.balance.assets.vices

        CardView("Habits", systemImage: "arrow.trianglehead.2.clockwise.rotate.90") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                if state.assets.vices.isEmpty {
                    Text("Nothing has crept in yet. Launch parties, crunch weeks and the tables are how it starts.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(vices) { def in
                    AssetViceRow(engine: engine, def: def, shell: shell)
                }
                // Said once, at the bottom, rather than four times.
                Text(quitRule)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Divider()
                AssetTherapyRow(engine: engine, shell: shell)
            }
        }
    }
}

private struct AssetViceRow: View {
    let engine: GameEngine
    let def: BalanceConfig.AssetsBalance.AssetViceDef
    let shell: GameShell

    var body: some View {
        let state = engine.state
        let dependency = state.assets.dependency(def.id)
        let quit = state.assets.quit(def.id)
        let rules = engine.balance.assets.quitting
        let tint = AssetsPresentation.viceTint(dependency, threshold: def.interventionAt)

        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            AssetMeterBar(
                label: def.name,
                systemImage: AssetsPresentation.viceIcon(def.id),
                value: dependency,
                tint: tint,
                caption: AssetsPresentation.viceBand(dependency, threshold: def.interventionAt)
            )
            Text(dependency > 0 ? def.note : "Not yet.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if dependency > 0 {
                let blocker = state.assetQuitBlocker(def.id, balance: engine.balance)
                HStack(spacing: Theme.Spacing.sm) {
                    Button {
                        Haptics.commit()
                        shell.toasts.send(
                            .quitVice(viceID: def.id), to: engine,
                            ack: "An evening off it", icon: "figure.walk"
                        )
                    } label: {
                        Label(buttonLabel(quit: quit, rules: rules), systemImage: "figure.walk")
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .disabled(blocker != nil)

                    if quit != nil {
                        Button {
                            Haptics.tap()
                            shell.toasts.send(
                                .abandonQuit(viceID: def.id), to: engine,
                                ack: "The run is over", icon: "xmark.circle"
                            )
                        } label: {
                            Text("Stop trying").font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }
                    Spacer(minLength: 0)
                }
                AssetRefusalNote(reason: blocker)
            }
        }
    }

    private func buttonLabel(quit: AssetQuit?, rules: BalanceConfig.AssetsBalance.AssetQuitDef) -> String {
        guard let quit else { return "Start a run of evenings off it" }
        return "Another evening — \(quit.eveningsDone + 1) of \(rules.evenings)"
    }
}

/// The hour a week that takes a notch off everything.
private struct AssetTherapyRow: View {
    let engine: GameEngine
    let shell: GameShell

    var body: some View {
        let def = engine.balance.assets.therapy
        let blocker = engine.state.assetTherapyBlocker(balance: engine.balance)

        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("An hour on the couch").font(.subheadline.weight(.semibold))
                    Text("\(def.cost.money) and one evening. Every habit down \(Int(def.viceRelief)), mood +\(Int(def.mood)). Once a week.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button {
                    Haptics.commit()
                    shell.toasts.send(
                        .attendTherapy, to: engine,
                        ack: "You said most of it out loud", icon: "brain.head.profile"
                    )
                } label: {
                    Label("Go", systemImage: "brain.head.profile").font(.footnote.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .disabled(blocker != nil)
            }
            AssetRefusalNote(reason: blocker)
        }
    }
}
