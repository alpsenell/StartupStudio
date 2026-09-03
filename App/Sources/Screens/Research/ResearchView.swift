import SwiftUI
import TycoonContent
import TycoonEngine

/// The R&D segment of the Products tab: banked research points, the active
/// project, and the tech tree grouped by tier. Research points come only
/// from employees assigned to Research on the Team tab.
///
/// Every tech node row is tappable and opens `TechNodeInfoSheet` (name,
/// tier, blurb, effect, cost, prerequisites, status); the Research/Switch/
/// Cancel buttons stay on the rows.
struct ResearchView: View {
    let engine: GameEngine

    /// The node whose info sheet is open, if any.
    @State private var selectedNode: TechNode?

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            LabSummaryCard(engine: engine)
            ForEach(tiers, id: \.tier) { group in
                TierCard(engine: engine, tier: group.tier, nodes: group.nodes) { node in
                    selectedNode = node
                }
            }
        }
        .sheet(item: $selectedNode) { node in
            TechNodeInfoSheet(engine: engine, node: node)
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

    @Environment(AppRouter.self) private var router

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
                    HStack(spacing: Theme.Spacing.md) {
                        Text("Nobody is researching — the lab banks no points.")
                            .font(.footnote)
                            .foregroundStyle(Theme.warning)
                        Spacer(minLength: Theme.Spacing.sm)
                        IdleAssignMenu(engine: engine, assignment: .research)
                    }
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
                    .font(Theme.Typography.number(.caption, weight: .regular))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(Theme.Motion.valueChange, value: progress)
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
    let onSelect: (TechNode) -> Void

    var body: some View {
        CardView("Tier \(tier)", systemImage: "square.stack.3d.up.fill") {
            VStack(spacing: 0) {
                ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                    TechNodeRow(engine: engine, node: node, onSelect: onSelect)
                        .padding(.vertical, Theme.Spacing.sm)
                    if index < nodes.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }
}

// MARK: - Node status

/// Where a tech node stands for the current save.
private enum TechNodeStatus {
    case owned, active, available, locked
}

private func techNodeStatus(_ node: TechNode, research: ResearchState) -> TechNodeStatus {
    if research.unlocked.contains(node.id) { return .owned }
    if research.activeNodeID == node.id { return .active }
    let prerequisitesMet = node.prerequisites.allSatisfy { research.unlocked.contains($0) }
    return prerequisitesMet ? .available : .locked
}

// MARK: - Tech node row

/// One node in a tier card. The whole row is tappable (opens the info
/// sheet via `onSelect`); the Research/Switch/Cancel buttons inside take
/// precedence over the row tap.
private struct TechNodeRow: View {
    let engine: GameEngine
    let node: TechNode
    let onSelect: (TechNode) -> Void

    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI
    /// updates this property for presented content before the
    /// environment is installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }
    /// Drives the one-shot flip when this node's research lands.
    @State private var flip: Double = 0

    private var research: ResearchState { engine.state.research }

    /// True on the tick this node's `.researchCompleted` arrives, so the
    /// card can turn over once and settle as "owned".
    private var justCompleted: Bool {
        guard case .researchCompleted(let nodeID, let day) = engine.state.eventLog.last else {
            return false
        }
        return nodeID == node.id && day == engine.state.day
    }

    private var status: TechNodeStatus {
        techNodeStatus(node, research: research)
    }

    private var effectSummary: String {
        techEffectSummary(node.effect, content: engine.content)
    }

    var body: some View {
        Group {
            switch status {
            case .owned: ownedRow
            case .active: activeRow
            case .available: availableRow
            case .locked: lockedRow
            }
        }
        .contentShape(Rectangle())
        .rotation3DEffect(.degrees(flip), axis: (x: 1, y: 0, z: 0))
        .onTapGesture { onSelect(node) }
        .accessibilityAction(named: "Show details") { onSelect(node) }
        // A finished tech turns over once: the one moment in the tree
        // that is worth watching.
        .onChange(of: justCompleted) { _, completed in
            guard completed else { return }
            Sounds.play(.goal)
            Haptics.success()
            withAnimation(Theme.Motion.emphatic) { flip = 360 }
            Task {
                try? await Task.sleep(for: .milliseconds(700))
                flip = 0
            }
        }
    }

    /// Trailing "there's more" affordance on every row.
    private var infoIcon: some View {
        Image(systemName: "info.circle")
            .font(.subheadline)
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
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
                .monospacedDigit()
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            infoIcon
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
                infoIcon
            }

            Gauge(value: fraction) {
                EmptyView()
            }
            .gaugeStyle(.accessoryLinearCapacity)
            .tint(Theme.accent)

            HStack {
                Text("\(progress) / \(cost) RP")
                    .font(Theme.Typography.number(.caption, weight: .regular))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(Theme.Motion.valueChange, value: progress)
                Spacer()
                // No confirmation needed: cancelling refunds progress to
                // the banked pool.
                Button("Cancel") {
                    shell.toasts.send(
                        .cancelResearch,
                        to: engine,
                        ack: "Shelved \(node.name) — the points go back in the bank",
                        icon: "flask"
                    )
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
            HStack(spacing: Theme.Spacing.sm) {
                Text(node.name)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Spacer(minLength: Theme.Spacing.sm)
                infoIcon
            }
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
                    shell.toasts.send(
                        .startResearch(nodeID: node.id),
                        to: engine,
                        rejected: "\(node.name) can't be started yet."
                    )
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(node.name), available. \(effectSummary)")
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
            infoIcon
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

// MARK: - Node info sheet

/// Read-only detail for one tech node: name, tier, blurb, effect, cost,
/// prerequisites (with owned checkmarks), and status. Actions stay on the
/// tree rows.
private struct TechNodeInfoSheet: View {
    let engine: GameEngine
    let node: TechNode

    @Environment(\.dismiss) private var dismiss

    private var research: ResearchState { engine.state.research }

    private var status: TechNodeStatus {
        techNodeStatus(node, research: research)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        HStack(spacing: Theme.Spacing.sm) {
                            StatPill(systemImage: "square.stack.3d.up.fill", value: "Tier \(node.tier)")
                            statusPill
                        }
                        Text(node.blurb)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                }

                Section("Effect") {
                    Label(
                        techEffectSummary(node.effect, content: engine.content),
                        systemImage: effectIcon
                    )
                }

                Section("Cost") {
                    LabeledContent("Research") {
                        Text("\(Int(node.researchCost.rounded())) RP")
                            .font(Theme.Typography.number(.body, weight: .regular))
                    }
                    if node.cashCost > 0 {
                        LabeledContent("Cash") {
                            Text(node.cashCost.money)
                                .font(Theme.Typography.number(.body, weight: .regular))
                                .foregroundStyle(
                                    engine.state.company.cash >= node.cashCost
                                        ? Color.secondary
                                        : Theme.negativeCash
                                )
                        }
                    }
                }

                Section("Prerequisites") {
                    if node.prerequisites.isEmpty {
                        Text("None")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(node.prerequisites, id: \.self) { id in
                            prerequisiteRow(id)
                        }
                    }
                }

                Section("Status") {
                    statusDetail
                }
            }
            .navigationTitle(node.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var statusPill: StatPill {
        switch status {
        case .owned:
            StatPill(systemImage: "checkmark.circle.fill", value: "Researched", tint: Theme.positiveCash)
        case .active:
            StatPill(systemImage: "flask.fill", value: "In progress", tint: Theme.accent)
        case .available:
            StatPill(systemImage: "circle.dashed", value: "Available")
        case .locked:
            StatPill(systemImage: "lock.fill", value: "Locked", tint: .secondary)
        }
    }

    @ViewBuilder
    private var statusDetail: some View {
        switch status {
        case .owned:
            Text("Researched — its effect is active.")
                .foregroundStyle(.secondary)
        case .active:
            let progress = Int(research.activeProgress.rounded())
            let cost = Int(node.researchCost.rounded())
            let fraction = node.researchCost > 0
                ? min(max(research.activeProgress / node.researchCost, 0), 1)
                : 0
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("\(progress) / \(cost) RP")
                    .font(Theme.Typography.number(.body, weight: .regular))
                    .foregroundStyle(.secondary)
                Gauge(value: fraction) {
                    EmptyView()
                }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(Theme.accent)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("In progress, \(progress) of \(cost) research points")
        case .available:
            if research.activeNodeID != nil {
                Text("Ready to research. Switching from the current project refunds its progress to the banked pool.")
                    .foregroundStyle(.secondary)
            } else {
                Text("Ready to research.")
                    .foregroundStyle(.secondary)
            }
            if node.cashCost > 0, engine.state.company.cash < node.cashCost {
                Text("Needs \(node.cashCost.money) cash to start.")
                    .monospacedDigit()
                    .foregroundStyle(Theme.negativeCash)
            }
        case .locked:
            Text("Research the prerequisites above first.")
                .foregroundStyle(.secondary)
        }
    }

    private func prerequisiteRow(_ id: String) -> some View {
        // Defensive: prerequisite ids should always resolve against the
        // same catalog, but fall back to the raw id if content ever drifts.
        let owned = research.unlocked.contains(id)
        let name = engine.content.tech(id)?.name ?? id
        return HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: owned ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(owned ? Theme.positiveCash : Color.secondary)
            Text(name)
                .foregroundStyle(owned ? Color.primary : Color.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(owned ? "researched" : "not yet researched")")
    }

    private var effectIcon: String {
        switch node.effect {
        case .unlockProductType: "shippingbox.fill"
        case .qualityMultiplier: "sparkles"
        case .devSpeedMultiplier: "hare.fill"
        case .unlockCampaignKind: "megaphone.fill"
        }
    }
}

// MARK: - Effect chip

/// Small accent capsule summarizing what a tech node grants.
private struct EffectChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .monospacedDigit()
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
