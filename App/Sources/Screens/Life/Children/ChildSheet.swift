import SwiftUI
import TycoonEngine

// MARK: Iteration 9 — L3 (children who grow up, and remember)

/// One child in full: the sprite at their age, the bond, every memory with
/// the day it happened, and the two things an evening can still buy.
///
/// Every button carries its consequence, and a refused one says why —
/// "No evenings left this week", "Summer only — March is term time".
struct ChildSheet: View {
    let engine: GameEngine
    let childID: UUID
    var onClose: () -> Void = {}

    @Environment(GameShell.self) private var injectedShell: GameShell?
    private var shell: GameShell { injectedShell ?? .shared }
    @State private var confirmingEndSummer = false

    private var child: Child? {
        engine.state.life.family.children.first { $0.id == childID }
    }

    private var stage: ChildStage {
        child?.stage(on: engine.state.day, balance: engine.balance.childhood) ?? .school
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let child {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        header(child)
                        actions(child)
                        // MARK: Iteration 11 — N2 (people menus)
                        PeopleMenuButton(engine: engine, target: .child(child.id))
                        // MARK: end of Iteration 11 — N2
                        ledger(child)
                    }
                    .padding(Theme.Spacing.lg)
                } else {
                    Text("They are not here.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(Theme.Spacing.lg)
                }
            }
            .background(Theme.screenBackground)
            .navigationTitle(child?.name ?? "The kid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onClose() }
                }
            }
        }
        .confirmationDialog(
            "End the summer early?",
            isPresented: $confirmingEndSummer,
            titleVisibility: .visible
        ) {
            Button("End it", role: .destructive) {
                shell.toasts.send(
                    .endChildInternship(childID: childID),
                    to: engine,
                    ack: "They cleared the desk in four minutes.",
                    rejected: "Nothing to end."
                )
            }
            Button("Let it run", role: .cancel) {}
        } message: {
            Text("They lose the rest of the summer and \(Int(-engine.balance.childhood.internQuitBondPenalty)) points of bond, and they remember this one.")
        }
    }

    // MARK: - Header

    private func header(_ child: Child) -> some View {
        CardView("Right now", systemImage: "figure.child") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .bottom, spacing: Theme.Spacing.lg) {
                    ChildSprite(seed: child.appearanceSeed, stage: stage, boxHeight: 92)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(child.ageLabel(on: engine.state.day, balance: engine.balance.childhood))
                            .font(.system(.headline, design: .rounded))
                            .monospacedDigit()
                        Text(stage.note)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(child.bornLabel(on: engine.state.day, balance: engine.balance.childhood))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                BondBar(bond: child.bond, label: child.bondLabel)
                if child.internSummers > 0 {
                    Label(
                        "\(child.internSummers) summer\(child.internSummers == 1 ? "" : "s") at the studio",
                        systemImage: "briefcase.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
                }
            }
        }
    }

    // MARK: - What an evening buys

    private func actions(_ child: Child) -> some View {
        CardView("Tonight", systemImage: "moon.stars") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                let eveningReason = ChildhoodSystem.eveningRefusal(
                    childID: childID, state: engine.state, balance: engine.balance
                )
                ChildAction(
                    title: "An evening with \(child.name)",
                    detail: "−1 evening · bond +\(Int(engine.balance.childhood.bondPerEvening)) · mood +6",
                    reason: eveningReason
                ) {
                    shell.toasts.send(
                        .spendTimeWithChild(childID: childID),
                        to: engine,
                        ack: ChildhoodSystem.vignette(child.name, stage: stage),
                        rejected: eveningReason ?? "Not tonight."
                    )
                }

                Divider()

                if child.isInterning(on: engine.state.day), let until = child.internUntilDay {
                    Text("At the studio for \(max(0, until - engine.state.day)) more days, on no salary, sitting in the corner nearest the coffee.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(role: .destructive) {
                        confirmingEndSummer = true
                    } label: {
                        Text("End the summer early (bond \(Int(engine.balance.childhood.internQuitBondPenalty)))")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.xs)
                    }
                    .buttonStyle(.bordered)
                } else {
                    let internReason = ChildhoodSystem.internRefusal(
                        childID: childID, state: engine.state, balance: engine.balance
                    )
                    ChildAction(
                        title: "A summer at the studio",
                        detail: "\(engine.balance.childhood.internWeeks) weeks · no salary · bond +\(Int(engine.balance.childhood.internBondBonus))",
                        reason: internReason
                    ) {
                        shell.toasts.send(
                            .hireChildIntern(childID: childID),
                            to: engine,
                            ack: "\(child.name) starts on Monday.",
                            rejected: internReason ?? "Not this summer."
                        )
                    }
                }
            }
        }
    }

    // MARK: - The ledger

    private func ledger(_ child: Child) -> some View {
        CardView("What they remember", systemImage: "book.closed") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                if child.memories.isEmpty {
                    Text("Nothing yet. Babies remember nothing; everybody older keeps a ledger, and the last \(engine.balance.childhood.memoryCap) entries stay on it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(Array(child.memories.reversed().enumerated()), id: \.offset) { _, memory in
                        MemoryRow(memory: memory, day: engine.state.day)
                    }
                    Text("The last \(engine.balance.childhood.memoryCap) go with them into the next company.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - A gated action with its consequence on the button

private struct ChildAction: View {
    let title: String
    /// The consequence, always on the button.
    let detail: String
    /// `nil` when the action is open; otherwise why it is not.
    let reason: String?
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Button(action: action) {
                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    Text(detail)
                        .font(.caption)
                        .monospacedDigit()
                        .opacity(0.85)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.xs)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .disabled(reason != nil)
            .accessibilityLabel(title)
            .accessibilityHint(reason ?? detail)

            if let reason {
                Text(reason)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
