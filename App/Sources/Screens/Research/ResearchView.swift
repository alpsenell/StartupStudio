import SwiftUI
import TycoonContent
import TycoonEngine

/// The R&D segment of the Products tab: banked research points, the active
/// project, and the tech tree grouped by tier. Research points come only
/// from employees assigned to Research on the Team tab.
struct ResearchView: View {
    let engine: GameEngine

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            LabSummaryCard(engine: engine)
            ForEach(tiers, id: \.tier) { group in
                TierCard(engine: engine, tier: group.tier, nodes: group.nodes)
            }
        }
    }

    /// Tech nodes grouped by tier (1...5), keeping the catalog's stable
    /// order within each tier.
    private var tiers: [(tier: Int, nodes: [TechNode])] {
        Dictionary(grouping: engine.content.techTree, by: \.tier)
            .sorted { $0.key < $1.key }
            .map { (tier: $0.key, nodes: $0.value) }
    }
}

// MARK: - Lab summary

/// Top card: banked RP, researcher headcount, and a mini progress bar for
/// the active research project (if any).
private struct LabSummaryCard: View {
    let engine: GameEngine

    private var research: ResearchState { engine.state.research }

    private var bankedRP: Int { Int(research.banked.rounded()) }

    private var researcherCount: Int {
        engine.state.employees.filter { $0.assignment == .research }.count
    }

    private var activeNode: TechNode? {
        research.activeNodeID.flatMap { engine.content.tech($0) }
    }

    var body: some View {
        CardView("Research lab", systemImage: "flask.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(spacing: Theme.Spacing.sm) {
                    StatPill(systemImage: "flask.fill", value: "\(bankedRP) RP", tint: Theme.accent)
                        .accessibilityLabel("\(bankedRP) banked research points")
                    StatPill(
                        systemImage: "person.2.fill",
                        value: "\(researcherCount) researcher\(researcherCount == 1 ? "" : "s")"
                    )
                    .accessibilityLabel("\(researcherCount) researcher\(researcherCount == 1 ? "" : "s")")
                }

                if researcherCount == 0 {
                    Text("Assign someone to Research from the Team tab.")
                        .font(.footnote)
                        .foregroundStyle(Theme.warning)
                }

                if let activeNode {
                    activeProgress(for: activeNode)
                }
            }
        }
    }

    private func activeProgress(for node: TechNode) -> some View {
        let progress = Int(research.activeProgress.rounded())
        let cost = Int(node.researchCost.rounded())
        let fraction = node.researchCost > 0
            ? min(max(research.activeProgress / node.researchCost, 0), 1)
            : 0
        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text(node.name)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(progress) / \(cost) RP")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.35), value: progress)
            }
            Gauge(value: fraction) {
                EmptyView()
            }
            .gaugeStyle(.accessoryLinearCapacity)
            .tint(Theme.accent)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Researching \(node.name), \(progress) of \(cost) research points")
    }
}

// MARK: - Tier card

/// One tier of the tech tree: its nodes stacked with dividers.
private struct TierCard: View {
    let engine: GameEngine
    let tier: Int
    let nodes: [TechNode]

    var body: some View {
        CardView("Tier \(tier)", systemImage: "square.stack.3d.up.fill") {
            VStack(spacing: 0) {
                ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                    TechNodeRow(engine: engine, node: node)
                        .padding(.vertical, Theme.Spacing.sm)
                    if index < nodes.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }
}

// MARK: - Tech node row

private struct TechNodeRow: View {
    let engine: GameEngine
    let node: TechNode

    private enum Status {
        case owned, active, available, locked
    }

    private var research: ResearchState { engine.state.research }

    private var status: Status {
        if research.unlocked.contains(node.id) { return .owned }
        if research.activeNodeID == node.id { return .active }
        let prerequisitesMet = node.prerequisites.allSatisfy { research.unlocked.contains($0) }
        return prerequisitesMet ? .available : .locked
    }

    private var effectSummary: String {
        techEffectSummary(node.effect, content: engine.content)
    }

    var body: some View {
        switch status {
        case .owned: ownedRow
        case .active: activeRow
        case .available: availableRow
        case .locked: lockedRow
        }
    }

    // MARK: Owned

    private var ownedRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(Theme.positiveCash)
            Text(node.name)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: Theme.Spacing.sm)
            Text(effectSummary)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(node.name), researched. \(effectSummary)")
    }

    // MARK: Active

    private var activeRow: some View {
        let progress = Int(research.activeProgress.rounded())
        let cost = Int(node.researchCost.rounded())
        let fraction = node.researchCost > 0
            ? min(max(research.activeProgress / node.researchCost, 0), 1)
            : 0
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "flask.fill")
                    .font(.subheadline)
                    .foregroundStyle(Theme.accent)
                Text(node.name)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Spacer(minLength: Theme.Spacing.sm)
                EffectChip(text: effectSummary)
            }

            Gauge(value: fraction) {
                EmptyView()
            }
            .gaugeStyle(.accessoryLinearCapacity)
            .tint(Theme.accent)

            HStack {
                Text("\(progress) / \(cost) RP")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.35), value: progress)
                Spacer()
                // No confirmation needed: cancelling refunds progress to
                // the banked pool.
                Button("Cancel") {
                    engine.send(.cancelResearch)
                }
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .buttonStyle(.bordered)
                .accessibilityLabel("Cancel research on \(node.name)")
                .accessibilityHint("Progress refunds to banked research points")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Researching \(node.name), \(progress) of \(cost) research points")
    }

    // MARK: Available

    private var availableRow: some View {
        // Starting while another project is active refunds that project's
        // progress to the banked pool — hence "Switch".
        let isSwitch = research.activeNodeID != nil
        let canAffordCash = engine.state.company.cash >= node.cashCost
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(node.name)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
            Text(node.blurb)
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: Theme.Spacing.sm) {
                EffectChip(text: effectSummary)
                Spacer(minLength: 0)
            }

            HStack(spacing: Theme.Spacing.md) {
                Label("\(Int(node.researchCost.rounded())) RP", systemImage: "flask")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                if node.cashCost > 0 {
                    Label(node.cashCost.money, systemImage: "dollarsign.circle")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(canAffordCash ? Color.secondary : Theme.negativeCash)
                }
                Spacer(minLength: Theme.Spacing.sm)
                Button(isSwitch ? "Switch" : "Research") {
                    engine.send(.startResearch(nodeID: node.id))
                }
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(!canAffordCash)
                .accessibilityLabel(isSwitch ? "Switch research to \(node.name)" : "Research \(node.name)")
                .accessibilityHint(
                    canAffordCash
                        ? (isSwitch ? "Current progress refunds to banked research points" : "")
                        : "Needs \(node.cashCost.money) cash"
                )
            }
        }
    }

    // MARK: Locked

    private var lockedRow: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: "lock.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(node.name)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Requires: \(prerequisiteNames)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .opacity(0.6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(node.name), locked. Requires \(prerequisiteNames)")
    }

    /// Defensive: prerequisite ids should always resolve against the same
    /// catalog, but fall back to the raw id if content ever drifts.
    private var prerequisiteNames: String {
        node.prerequisites
            .map { engine.content.tech($0)?.name ?? $0 }
            .joined(separator: ", ")
    }
}

// MARK: - Effect chip

/// Small accent capsule summarizing what a tech node grants.
private struct EffectChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, Theme.Spacing.xs + 2)
            .padding(.vertical, 2)
            .background(Theme.accent.opacity(0.15), in: Capsule())
            .lineLimit(1)
    }
}

// MARK: - Effect formatting

/// Human-readable summary of a tech effect, e.g. "Unlocks: Game",
/// "+5% quality", "+10% dev speed", "Unlocks: Press Release campaigns".
private func techEffectSummary(_ effect: TechNode.Effect, content: ContentCatalog) -> String {
    switch effect {
    case .unlockProductType(let id):
        "Unlocks: \(content.productType(id)?.name ?? titleCased(id))"
    case .qualityMultiplier(let bonus):
        "+\(Int((bonus * 100).rounded()))% quality"
    case .devSpeedMultiplier(let bonus):
        "+\(Int((bonus * 100).rounded()))% dev speed"
    case .unlockCampaignKind(let id):
        // Campaign kinds have no content entry yet (Milestone 5), so
        // "press_release" is displayed as "Press Release".
        "Unlocks: \(titleCased(id)) campaigns"
    }
}

/// "press_release" -> "Press Release".
private func titleCased(_ id: String) -> String {
    id.split(separator: "_")
        .map { $0.prefix(1).uppercased() + $0.dropFirst() }
        .joined(separator: " ")
}
