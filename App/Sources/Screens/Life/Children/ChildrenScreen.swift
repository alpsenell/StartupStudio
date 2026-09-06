import SwiftUI
import TycoonEngine

// MARK: Iteration 9 — L3 (children who grow up, and remember)

/// The children, at whatever age they are today: the sprite, the stage,
/// the bond, the last two things they remember, and the two things the
/// founder can still do about it.
///
/// Pushed from the Family card and from `-autoRoute children`.
struct ChildrenScreen: View {
    let engine: GameEngine

    @State private var openChild: UUID?

    private var children: [Child] { engine.state.life.family.children }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                if children.isEmpty {
                    CardView("Nobody yet", systemImage: "figure.child") {
                        Text("Kids grow up faster than companies here — a child born in the garage is a teenager by the campus. There is nobody in the spare room yet.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text("Kids grow up faster than companies. A child born in the garage is a teenager by the campus.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(children) { child in
                        ChildCard(engine: engine, child: child) { openChild = child.id }
                    }
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.screenBackground)
        .navigationTitle("The kids")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // A headless screenshot pass cannot tap: `-autoChild` opens
            // the first child's ledger.
            if DebugLaunch.opensFirstChild, openChild == nil {
                openChild = children.first?.id
            }
        }
        .sheet(item: Binding(
            get: { openChild.map(IdentifiedID.init(id:)) },
            set: { openChild = $0?.id }
        )) { wrapper in
            ChildSheet(engine: engine, childID: wrapper.id) { openChild = nil }
        }
    }
}

/// A `UUID` that a `.sheet(item:)` will accept.
struct IdentifiedID: Identifiable, Hashable {
    let id: UUID
}

// MARK: - One child

/// The child as a card: sprite, stage, bond bar, the newest two memories,
/// and the way in to the rest.
private struct ChildCard: View {
    let engine: GameEngine
    let child: Child
    let onOpen: () -> Void

    private var stage: ChildStage {
        child.stage(on: engine.state.day, balance: engine.balance.childhood)
    }

    var body: some View {
        CardView(child.name, systemImage: "figure.child") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .bottom, spacing: Theme.Spacing.md) {
                    ChildSprite(seed: child.appearanceSeed, stage: stage, boxHeight: 60)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(child.ageLabel(on: engine.state.day, balance: engine.balance.childhood))
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .monospacedDigit()
                        Text(stage.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                BondBar(bond: child.bond, label: child.bondLabel)
                if child.isInterning(on: engine.state.day), let until = child.internUntilDay {
                    Label(
                        "At the studio for \(max(0, until - engine.state.day)) more days",
                        systemImage: "briefcase.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
                }
                if child.memories.isEmpty {
                    Text("Nothing on the ledger yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(child.latestMemories.enumerated()), id: \.offset) { _, memory in
                        MemoryRow(memory: memory, day: engine.state.day)
                    }
                }
                Button(action: onOpen) {
                    Text("Open \(child.name)'s ledger")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.xs)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
            }
        }
    }
}

// MARK: - Shared pieces

/// The bond, as a bar with a word rather than a bare number — the rest of
/// the Life tab never shows a naked integer either.
struct BondBar: View {
    let bond: Double
    let label: String

    private var fraction: Double { min(max(bond / 100, 0), 1) }

    private var tint: Color {
        switch bond {
        case ..<30: Theme.negativeCash
        case ..<60: Theme.warning
        default: Theme.romance
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Bond")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text("\(label) · \(Int(bond.rounded()))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(tint)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.18))
                    Capsule().fill(tint).frame(width: geometry.size.width * fraction)
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Bond \(Int(bond.rounded())) of 100, \(label)")
    }
}

/// One line of the ledger: the day it happened, the icon for its kind, and
/// the sentence the child would use.
struct MemoryRow: View {
    let memory: ChildMemory
    /// Today. Not drawn — the row shows the date it happened, because a
    /// childhood is remembered by when, not by how long ago — but kept so
    /// a later relative form does not have to change every call site.
    let day: Int

    private var kind: ChildMemoryKind? { ChildMemoryKind(rawValue: memory.kind) }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: kind?.symbolName ?? "circle")
                .font(.caption)
                .foregroundStyle(kind?.isSour == true ? Theme.negativeCash : Theme.accent)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(memory.note)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
                Text(GameCalendar(day: memory.day).shortLabel)
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
