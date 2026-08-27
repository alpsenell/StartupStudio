import SwiftUI
import TycoonEngine

/// The Rivals segment of the Business tab: one card per competitor studio,
/// strongest first, each with an acquisition move once the player can
/// afford (and dominate) it.
struct RivalsView: View {
    let engine: GameEngine

    /// Strongest first; ties break on the id so the order is stable.
    private var rivals: [Rival] {
        engine.state.rivals.rivals.sorted { lhs, rhs in
            if lhs.strength != rhs.strength { return lhs.strength > rhs.strength }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    var body: some View {
        BusinessSectionHeader(title: "Rival studios", systemImage: "flag.2.crossed.fill")

        if rivals.isEmpty {
            EmptyStateCard(
                message: "The scene is quiet. Competitors will show up soon."
            )
        } else {
            ForEach(rivals) { rival in
                RivalCard(engine: engine, rival: rival)
            }
        }
    }
}

// MARK: - Rival card

private struct RivalCard: View {
    let engine: GameEngine
    let rival: Rival

    @State private var confirmingAcquisition = false

    var body: some View {
        CardView(rival.name, systemImage: "flag.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(spacing: Theme.Spacing.sm) {
                    PixelPortrait(seed: rival.appearanceSeed)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("~\(rival.headcount) people")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .monospacedDigit()
                        Text("Valued around \(rival.valuation(balance: engine.balance).money)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    if let shipped = rival.lastShippedDay {
                        Text("Shipped D\(shipped)")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.tertiary)
                    }
                }

                meter("Strength", value: rival.strength, tint: Theme.warning)
                meter("Reputation", value: rival.reputation, tint: Theme.accent)

                if !rival.focusTopicIDs.isEmpty {
                    Text("Focus: \(focusNames)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                acquireRow
            }
        }
        .confirmationDialog(
            "Acquire \(rival.name) for \(acquisitionCost.money)?",
            isPresented: $confirmingAcquisition,
            titleVisibility: .visible
        ) {
            Button("Acquire for \(acquisitionCost.money)", role: .destructive) {
                engine.send(.acquireRival(rivalID: rival.id))
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Part of their team joins you; \(rival.name) leaves the market for good.")
        }
    }

    private var focusNames: String {
        rival.focusTopicIDs
            .map { engine.content.topic($0)?.name ?? $0 }
            .joined(separator: ", ")
    }

    private func meter(_ label: String, value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(value.rounded()))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: value, total: 100)
                .tint(tint)
        }
    }

    // MARK: Acquisition

    private var acquisitionCost: Int {
        Int((Double(rival.valuation(balance: engine.balance))
            * engine.balance.rivals.acquirePremium).rounded())
    }

    /// Why the acquisition button is disabled, mirroring the engine's
    /// `acquireRival` gates (the engine stays the enforcer).
    private var acquisitionBlocker: String? {
        let balance = engine.balance
        let state = engine.state
        let dominanceBar = Double(rival.valuation(balance: balance))
            * balance.rivals.acquireDominanceFactor
        if Double(state.companyValuation(balance: balance)) < dominanceBar {
            return "You're not big enough yet — grow your valuation first"
        }
        if state.company.cash < acquisitionCost {
            return "Need \((acquisitionCost - state.company.cash).money) more cash"
        }
        return nil
    }

    private var acquireRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Button {
                confirmingAcquisition = true
            } label: {
                Label("Acquire for \(acquisitionCost.money)", systemImage: "building.2.crop.circle.fill")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .disabled(acquisitionBlocker != nil)

            if let blocker = acquisitionBlocker {
                Text(blocker)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
