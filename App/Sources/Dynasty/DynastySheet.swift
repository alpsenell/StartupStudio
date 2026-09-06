import SwiftUI
import TycoonEngine

// MARK: Iteration 8 — the dynasty

/// Every company the ledger remembers, as a tree: a company founded by
/// somebody from an earlier one sits under it, indented.
struct DynastySheet: View {
    let ledger: LegacyLedger
    var onClose: () -> Void = {}

    private struct Node: Identifiable {
        let run: LegacyRun
        let depth: Int
        var id: UUID { run.id }
    }

    private var nodes: [Node] {
        let runs = ledger.runs
        let byID = Dictionary(uniqueKeysWithValues: runs.map { ($0.id, $0) })
        let children = Dictionary(grouping: runs.filter { run in
            run.lineage.map { byID[$0.predecessorRunID] != nil } ?? false
        }, by: { $0.lineage!.predecessorRunID })
        var out: [Node] = []
        func walk(_ run: LegacyRun, depth: Int) {
            out.append(Node(run: run, depth: depth))
            for child in children[run.id] ?? [] { walk(child, depth: depth + 1) }
        }
        for run in runs where run.lineage.flatMap({ byID[$0.predecessorRunID] }) == nil {
            walk(run, depth: 0)
        }
        return out
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    if ledger.runs.isEmpty {
                        PixelPanel {
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                PixelText(text: "NOBODY YET", scale: 3, color: Theme.pixelInk.opacity(0.5))
                                Text("Every company you finish goes in here. When the next one is founded by a child, an old employee, or you again, it hangs under the last.")
                                    .font(.footnote)
                                    .foregroundStyle(Theme.pixelInk.opacity(0.8))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    } else {
                        Text("\(ledger.runs.count) compan\(ledger.runs.count == 1 ? "y" : "ies"), \(generations) generation\(generations == 1 ? "" : "s").")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        ForEach(nodes) { node in
                            DynastyRow(run: node.run)
                                .padding(.leading, CGFloat(node.depth) * Theme.Spacing.lg)
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Theme.screenBackground.ignoresSafeArea())
            .navigationTitle("Dynasty")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                }
            }
        }
    }

    private var generations: Int {
        (nodes.map(\.depth).max() ?? 0) + 1
    }
}

private struct DynastyRow: View {
    let run: LegacyRun

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            if let seed = run.founderAppearanceSeed {
                PixelPortrait(seed: seed, isFounder: true, size: 48)
            } else {
                Image(systemName: "person.crop.square")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                    .frame(width: 48, height: 48)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(run.founderName)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                // Iteration 9 — L2: the second number, when the ledger has
                // it. A run recorded before life had a score shows the
                // line it always did.
                Text(
                    "\(run.companyName) · \(run.ending.headline) · day \(String(run.day))"
                        + (run.lifeScore.map { " · Life \(String($0))" } ?? "")
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                if let lineage = run.lineage {
                    Text(Successors.line(for: lineage))
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let children = run.children, !children.isEmpty {
                    Text("Children: \(children.map(\.name).joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            if let stake = run.stake {
                Label("\(stake)", systemImage: "flag.checkered")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .accessibilityLabel("Stake \(stake)")
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
