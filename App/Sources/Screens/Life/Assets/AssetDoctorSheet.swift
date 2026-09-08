import SwiftUI
import TycoonEngine

/// Iteration 11 — N3. The doctor's office: five named things the founder
/// can pick up, what caused each one, what it is doing to the meters right
/// now, and what a course of treatment costs.
///
/// Everything on the list that is *not* on the file is shown greyed with
/// its cause, so the screen answers "how would I get that?" as well as
/// "what have I got?" — the causes are all things the player chose, and
/// none of them is a dice roll.
struct AssetDoctorSheet: View {
    let engine: GameEngine

    @Environment(\.dismiss) private var dismiss
    @Environment(GameShell.self) private var injectedShell: GameShell?
    private var shell: GameShell { injectedShell ?? .shared }

    var body: some View {
        let state = engine.state

        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    CardView("On your file", systemImage: "list.clipboard.fill") {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            if state.assets.ailments.isEmpty, !state.economy.chronicCondition {
                                Text("Nothing. She asks how work is and you say fine, and she writes something down anyway.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            ForEach(engine.balance.assets.ailments) { def in
                                AilmentRow(engine: engine, def: def, shell: shell)
                            }
                            if state.economy.chronicCondition {
                                ChronicNote()
                            }
                        }
                    }

                    CardView("What she is looking at", systemImage: "waveform.path.ecg") {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            AssetMeterBar(
                                label: "Health", systemImage: "heart.fill",
                                value: state.life.meters.health,
                                tint: lifeMeterTint(state.life.meters.health),
                                caption: "\(Int(state.life.meters.health.rounded()))"
                            )
                            AssetMeterBar(
                                label: "Energy", systemImage: "bolt.fill",
                                value: state.life.meters.energy,
                                tint: lifeMeterTint(state.life.meters.energy),
                                caption: "\(Int(state.life.meters.energy.rounded()))"
                            )
                            Text(historyLine(state))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle("The doctor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// The two facts about the founder's body that predate this lane, said
    /// as a doctor would say them.
    private func historyLine(_ state: GameState) -> String {
        let hospital = state.economy.hospitalizationDays.count
        let burnout = state.economy.burnoutDays.count
        switch (hospital, burnout) {
        case (0, 0): return "No admissions, no collapses. She says that like it is unusual, and it is."
        case (0, _): return "\(burnout) collapse\(burnout == 1 ? "" : "s") on the file, no admissions. She underlines one of those."
        case (_, 0): return "\(hospital) admission\(hospital == 1 ? "" : "s"). She reads the dates back to you without comment."
        default: return "\(hospital) admission\(hospital == 1 ? "" : "s") and \(burnout) collapse\(burnout == 1 ? "" : "s"). She turns the screen so you can see it too."
        }
    }
}

private struct AilmentRow: View {
    let engine: GameEngine
    let def: BalanceConfig.AssetsBalance.AssetAilmentDef
    let shell: GameShell

    var body: some View {
        let state = engine.state
        let held = state.assets.ailments.first { $0.id == def.id }
        let blocker = state.assetTreatBlocker(def.id, balance: engine.balance)

        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Image(systemName: AssetsPresentation.ailmentIcon(def.id))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(iconTint(held))
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(def.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(held == nil ? .secondary : .primary)
                    Text(held == nil ? def.cause : def.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(driftLine)
                        .font(Theme.Typography.number(.caption2))
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
            }

            if held != nil {
                HStack(spacing: Theme.Spacing.sm) {
                    Button {
                        Haptics.commit()
                        shell.toasts.send(
                            .treatAilment(ailmentID: def.id), to: engine,
                            ack: "\(def.treatmentDays) days of it, starting today", icon: "cross.case.fill"
                        )
                    } label: {
                        Label("Treat it — \(def.treatmentCost.money), \(def.treatmentDays) days",
                              systemImage: "cross.case.fill")
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(blocker != nil)
                    Spacer(minLength: 0)
                }
                AssetRefusalNote(reason: blocker)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            (held == nil ? Theme.chipBackground : Theme.negativeCash.opacity(held?.isBeingTreated == true ? 0 : 0.10)),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    /// Grey while it is not on the file, the accent while a course is
    /// running, and the red the rest of the time.
    private func iconTint(_ held: AssetAilment?) -> Color {
        guard let held else { return Color.secondary.opacity(0.5) }
        return held.isBeingTreated ? Theme.accent : Theme.negativeCash
    }

    /// What it takes off the meters every day it is held.
    private var driftLine: String {
        var parts: [String] = []
        func add(_ label: String, _ value: Double) {
            guard value != 0 else { return }
            parts.append("\(label) \(value.formatted(.number.precision(.fractionLength(2)).locale(Theme.gameLocale)))/day")
        }
        add("energy", def.energy)
        add("health", def.health)
        add("mood", def.mood)
        add("relationships", def.relationships)
        return parts.isEmpty ? "No drift." : parts.joined(separator: " · ")
    }
}

/// The one thing on the file this office cannot touch.
private struct ChronicNote: View {
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: "bandage.fill").font(.footnote.weight(.semibold))
            Text("The chronic condition is on your file too. There is no course for it — three restorative weekends in a row is the only thing that has ever cleared it.")
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.warning)
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Theme.warning.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }
}
