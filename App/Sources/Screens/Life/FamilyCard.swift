import SwiftUI
import TycoonEngine

/// The founder's family: relationship stage, partner and children with
/// portraits, and the actions that move life forward (next relationship
/// stage, trying for a baby). Button states mirror the engine's gates with
/// a short reason while they're closed.
struct FamilyCard: View {
    let engine: GameEngine

    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI
    /// updates this property for presented content before the
    /// environment is installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }
    @State private var confirmingProposal = false
    @State private var confirmingChild = false

    /// Every gate below is the engine's own number, read from balance
    /// rather than copied — the thresholds used to be literals here and
    /// silently disagreed with the reducer on easy and hard.
    private var lifeBalance: BalanceConfig.LifeBalance { engine.balance.life }

    var body: some View {
        let state = engine.state
        let life = state.life
        let family = life.family

        CardView("Family", systemImage: "person.2.heart") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                StageHeader(stage: family.stage, relationships: life.meters.relationships)

                if family.stage != .single,
                   life.meters.relationships < engine.balance.life.breakupThreshold + 10 {
                    BreakupWarning()
                }

                if family.stage != .single, let seed = family.partnerAppearanceSeed {
                    PersonRow(
                        seed: seed,
                        name: family.partnerName ?? "Partner",
                        detail: family.stage.displayName
                    )
                }

                ForEach(family.children) { child in
                    PersonRow(
                        seed: child.appearanceSeed,
                        name: child.name,
                        detail: ageLabel(bornDay: child.bornDay, day: state.day)
                    )
                }

                if let step = advanceStep(life: life, day: state.day) {
                    Divider()
                    GatedAction(title: step.title, reason: step.reason) {
                        if family.stage.next == .married {
                            confirmingProposal = true
                        } else {
                            shell.toasts.send(
                                .advanceRelationship,
                                to: engine,
                                rejected: "Not yet — give it time."
                            )
                        }
                    }
                }

                if family.stage == .married {
                    Divider()
                    let child = childStep(life: life, day: state.day)
                    GatedAction(title: child.title, reason: child.reason) {
                        confirmingChild = true
                    }
                }
            }
        }
        .confirmationDialog(
            "Propose?",
            isPresented: $confirmingProposal,
            titleVisibility: .visible
        ) {
            Button("Propose (\(engine.balance.life.weddingCost.money))") {
                shell.toasts.send(
                    .advanceRelationship,
                    to: engine,
                    rejected: "The moment was not right."
                )
            }
            Button("Not yet", role: .cancel) {}
        } message: {
            Text(
                "The wedding costs \(engine.balance.life.weddingCost.money) out of your own wallet."
            )
        }
        .confirmationDialog(
            "Try for a baby?",
            isPresented: $confirmingChild,
            titleVisibility: .visible
        ) {
            Button("Yes (\(engine.balance.life.childStartCost.money))") {
                shell.toasts.send(
                    .haveChild,
                    to: engine,
                    rejected: "Not right now."
                )
            }
            Button("Not yet", role: .cancel) {}
        } message: {
            Text(
                "\(engine.balance.life.childStartCost.money) up front, then \(engine.balance.life.childWeeklyCost.money) a week out of your wallet — for the rest of the run."
            )
        }
    }

    // MARK: - Gates (read from the engine's balance; the engine enforces)

    private struct Step {
        let title: String
        /// `nil` when the action is open.
        let reason: String?
    }

    /// The next relationship step, or `nil` once married.
    private func advanceStep(life: LifeState, day: Int) -> Step? {
        guard let next = life.family.stage.next else { return nil }
        let rel = life.meters.relationships
        let daysAtStage = day - life.family.stageSinceDay

        switch next {
        case .dating:
            return Step(
                title: "Ask them out",
                reason: rel >= lifeBalance.datingMinRelationships
                    ? nil
                    : "Relationships need to reach \(Int(lifeBalance.datingMinRelationships)) — get out more on weekends."
            )
        case .partner:
            let minDays = lifeBalance.partnerMinDaysAtStage
            let reason: String? = if rel < lifeBalance.partnerMinRelationships {
                "Relationships need to reach \(Int(lifeBalance.partnerMinRelationships))."
            } else if daysAtStage < minDays {
                "Give it \(minDays - daysAtStage) more day\(minDays - daysAtStage == 1 ? "" : "s") of dating."
            } else {
                nil
            }
            return Step(title: "Move in together", reason: reason)
        case .married:
            let cost = lifeBalance.weddingCost
            let minDays = lifeBalance.marriedMinDaysAtStage
            let reason: String? = if rel < lifeBalance.marriedMinRelationships {
                "Relationships need to reach \(Int(lifeBalance.marriedMinRelationships))."
            } else if daysAtStage < minDays {
                "Give it \(minDays - daysAtStage) more day\(minDays - daysAtStage == 1 ? "" : "s") together."
            } else if life.wallet < cost {
                "Need \((cost - life.wallet).money) more in your wallet."
            } else {
                nil
            }
            return Step(title: "Propose (\(cost.money))", reason: reason)
        case .single:
            return nil
        }
    }

    private func childStep(life: LifeState, day: Int) -> Step {
        let config = lifeBalance
        let cost = config.childStartCost
        let family = life.family
        let sinceLast = family.lastChildDay.map { day - $0 }
        let spacing = config.childSpacingDays
        let reason: String? = if family.children.count >= config.maxChildren {
            "\(config.maxChildren) kids is a full house."
        } else if !life.home.allowsChildren {
            "Needs at least an apartment — upgrade your home first."
        } else if life.meters.relationships < config.childMinRelationships {
            "Relationships need to reach \(Int(config.childMinRelationships))."
        } else if let sinceLast, sinceLast < spacing {
            "Wait \(spacing - sinceLast) more day\(spacing - sinceLast == 1 ? "" : "s")."
        } else if life.wallet < cost {
            "Need \((cost - life.wallet).money) more in your wallet."
        } else {
            nil
        }
        return Step(title: "Try for a baby (\(cost.money))", reason: reason)
    }
}

// MARK: - Stage header

private struct StageHeader: View {
    let stage: RelationshipStage
    let relationships: Double

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            StatPill(systemImage: stageIcon, value: stage.displayName, tint: Theme.accent)
            StatPill(
                systemImage: "heart.fill",
                value: "\(Int(relationships.rounded()))",
                tint: lifeMeterTint(relationships)
            )
            .accessibilityLabel("Relationships \(Int(relationships.rounded())) of 100")
        }
    }

    private var stageIcon: String {
        switch stage {
        case .single: "person.fill"
        case .dating: "heart"
        case .partner: "house.fill"
        case .married: "heart.circle.fill"
        }
    }
}

private struct BreakupWarning: View {
    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline)
            Text("Things are strained — plan a date night before it's over.")
                .font(.footnote)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.negativeCash)
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Theme.negativeCash.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Person row

/// Partner or child: pixel portrait, name, and a detail line (stage or age).
private struct PersonRow: View {
    let seed: UInt64
    let name: String
    let detail: String

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            PixelPortrait(seed: seed)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .lineLimit(1)
                Text(detail)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Gated action

/// A prominent action button that's disabled with a short reason while its
/// engine gate is closed.
private struct GatedAction: View {
    let title: String
    let reason: String?
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Button(action: action) {
                Text(title)
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.xs)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .disabled(reason != nil)
            .accessibilityLabel(title)
            .accessibilityHint(reason ?? "")

            if let reason {
                Text(reason)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}
