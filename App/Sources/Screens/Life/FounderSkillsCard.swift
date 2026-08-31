import SwiftUI
import TycoonEngine

/// The founder's own five attributes, with what each one is currently
/// worth and a way to train it.
///
/// The point of the card is that a player can read down it and know why
/// they would spend an evening on any given row: every attribute names the
/// thing it moves, and the row's right-hand chip shows the *live*
/// multiplier the simulation is applying because of it, not a promise.
struct FounderSkillsCard: View {
    let engine: GameEngine

    @State private var training: FounderSkill?

    var body: some View {
        let state = engine.state
        let skills = state.life.skills

        CardView("You", systemImage: "brain.head.profile") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                ForEach(FounderSkill.allCases, id: \.self) { skill in
                    Button {
                        training = skill
                    } label: {
                        SkillRow(
                            skill: skill,
                            value: skills[skill],
                            effect: effectChip(for: skill, state: state)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressableRow)
                }
                Text(state.life.trainingsToday > 0
                    ? "You've done your studying for today."
                    : "Tap an attribute to train it. Training is your evening and your money.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .sheet(item: $training) { skill in
            TrainingSheet(engine: engine, skill: skill)
        }
    }

    /// The live multiplier this attribute is applying right now, in the
    /// units the player already reads elsewhere on the tab.
    private func effectChip(for skill: FounderSkill, state: GameState) -> String? {
        let balance = engine.balance
        switch skill {
        case .technical: return factor(state.founderTalentFactor(balance), "output")
        case .marketKnowledge: return factor(state.founderMarketFactor(balance), "sales")
        case .finance: return factor(state.founderDealFactor(balance), "payouts")
        case .conversation: return factor(state.founderCharmFactor(balance), "charm")
        case .leadership:
            let delta = state.founderLeadershipMoraleDelta(balance)
            guard abs(delta) >= 0.05 else { return nil }
            return "\(delta > 0 ? "+" : "")\(delta.formatted(.number.precision(.fractionLength(1)))) morale"
        }
    }

    private func factor(_ value: Double, _ label: String) -> String? {
        guard abs(value - 1) >= 0.005 else { return nil }
        return "×\(value.formatted(.number.precision(.fractionLength(2)))) \(label)"
    }
}

// MARK: - Row

private struct SkillRow: View {
    let skill: FounderSkill
    let value: Double
    let effect: String?

    private var rounded: Int { Int(value.rounded()) }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: skill.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 18)
                Text(skill.displayName)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer(minLength: Theme.Spacing.sm)
                if let effect {
                    Text(effect)
                        .font(Theme.Typography.number(.caption2))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text("\(rounded)")
                    .font(Theme.Typography.number(.caption))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(Theme.Motion.valueChange, value: rounded)
            }
            Gauge(value: min(max(value / 100, 0), 1)) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(Theme.accent)
                .animation(Theme.Motion.valueChange, value: value)
            Text(skill.effectSummary)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(skill.displayName) \(rounded) of 100. \(skill.effectSummary).")
        .accessibilityHint("Train this attribute")
    }
}

// MARK: - Training sheet

/// The three rungs of the training ladder for one attribute. The disabled
/// reasons come straight from the engine, so the sheet cannot promise a
/// session the reducer would refuse.
private struct TrainingSheet: View {
    let engine: GameEngine
    let skill: FounderSkill

    @Environment(\.dismiss) private var dismiss
    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI
    /// updates this property for presented content before the
    /// environment is installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }

    var body: some View {
        let state = engine.state
        let config = engine.balance.founder

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    CardView(skill.displayName, systemImage: skill.systemImage) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text(skill.effectSummary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack {
                                Text("Now")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                Spacer()
                                Text("\(Int(state.life.skills[skill].rounded())) / 100")
                                    .font(Theme.Typography.number(.subheadline))
                            }
                            Text("The closer you get to 100, the less each session adds.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    CardView("Train", systemImage: "book.fill") {
                        VStack(spacing: Theme.Spacing.md) {
                            ForEach(TrainingMethod.allCases, id: \.self) { method in
                                if let def = config.training(method) {
                                    MethodRow(
                                        method: method,
                                        def: def,
                                        gain: projectedGain(def, from: state.life.skills[skill]),
                                        blocker: state.trainingBlocker(method, balance: engine.balance)
                                    ) {
                                        shell.toasts.send(
                                            .trainFounderSkill(skill: skill, method: method),
                                            to: engine,
                                            ack: "\(method.displayName): \(skill.displayName.lowercased()) up",
                                            icon: skill.systemImage
                                        )
                                        dismiss()
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle("Training")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// What this session would actually add, after the diminishing-returns
    /// curve — the same arithmetic `FounderSkillSet.grow` does, so the
    /// sheet quotes the number the player will get rather than the raw one
    /// from the balance.
    private func projectedGain(
        _ def: BalanceConfig.FounderBalance.TrainingDef,
        from value: Double
    ) -> Double {
        var skills = engine.state.life.skills
        skills.grow(skill, by: def.gain)
        return skills[skill] - value
    }
}

private struct MethodRow: View {
    let method: TrainingMethod
    let def: BalanceConfig.FounderBalance.TrainingDef
    let gain: Double
    let blocker: String?
    let train: () -> Void

    var body: some View {
        Button(action: train) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Image(systemName: method.systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(blocker == nil ? Theme.accent : .secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(method.displayName)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("+\(gain.formatted(.number.precision(.fractionLength(1)))) · −\(Int(def.energy)) energy")
                        .font(Theme.Typography.number(.caption, weight: .regular))
                        .foregroundStyle(.secondary)
                    if let blocker {
                        Text(blocker)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.warning)
                    }
                }
                Spacer(minLength: 0)
                Text(def.cost > 0 ? def.cost.money : "Free")
                    .font(Theme.Typography.number(.subheadline))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(Theme.chipBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.pressableRow)
        .disabled(blocker != nil)
    }
}

// MARK: - Presentation helpers

extension FounderSkill: @retroactive Identifiable {
    public var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .conversation: "bubble.left.and.bubble.right.fill"
        case .technical: "chevron.left.forwardslash.chevron.right"
        case .marketKnowledge: "chart.line.uptrend.xyaxis"
        case .leadership: "flag.fill"
        case .finance: "banknote.fill"
        }
    }
}

extension TrainingMethod {
    var systemImage: String {
        switch self {
        case .selfStudy: "book.closed.fill"
        case .course: "play.rectangle.fill"
        case .coach: "person.fill.badge.plus"
        }
    }
}
