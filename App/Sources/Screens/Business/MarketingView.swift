import SwiftUI
import TycoonContent
import TycoonEngine

/// The Marketing segment of the Business tab: the hype gauge for the
/// product in development plus the three campaign kinds. Campaigns only
/// target the product currently being built.
struct MarketingView: View {
    let engine: GameEngine

    var body: some View {
        if let product = engine.state.productInDevelopment,
           case .development(let progress) = product.stage {
            VStack(spacing: Theme.Spacing.lg) {
                HypeCard(productName: product.name, hype: progress.hype)
                ForEach(CampaignKindSpec.all) { kind in
                    CampaignKindCard(engine: engine, kind: kind, productID: product.id)
                }
            }
        } else {
            EmptyStateCard(message: "Marketing needs something to hype — start a product first.")
        }
    }
}

// MARK: - Hype gauge

private struct HypeCard: View {
    let productName: String
    let hype: Double

    private var hypeValue: Int { Int(hype.rounded()) }

    var body: some View {
        CardView("Hype", systemImage: "flame.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text(productName)
                        .font(.system(.headline, design: .rounded))
                    Spacer(minLength: Theme.Spacing.sm)
                    Text("\(hypeValue)")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.accent)
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.35), value: hypeValue)
                }

                Gauge(value: normalizedHype) {
                    EmptyView()
                }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(Theme.accent)

                Text("Hype boosts launch reviews and sales, and decays daily.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Hype for \(productName): \(hypeValue)")
    }

    private var normalizedHype: Double {
        min(max(hype / 100.0, 0), 1)
    }
}

// MARK: - Campaign kinds

/// Static display data for the three campaign kinds. The engine owns the
/// real rules; these mirror its balance for the card copy.
private struct CampaignKindSpec: Identifiable {
    let id: String
    let name: String
    let systemImage: String
    let costLine: String
    let hypeLine: String
    /// The cash needed to start it today (one-shot cost, or the first
    /// day's spend for daily campaigns).
    let upfrontCost: Int
    let requiresResearch: Bool
    let requiresStudioTier: Bool

    static let all: [CampaignKindSpec] = [
        CampaignKindSpec(
            id: "social_push",
            name: "Social Push",
            systemImage: "megaphone.fill",
            costLine: "$50/day · 14 days",
            hypeLine: "+2 hype/day",
            upfrontCost: 50,
            requiresResearch: false,
            requiresStudioTier: false
        ),
        CampaignKindSpec(
            id: "press_release",
            name: "Press Release",
            systemImage: "newspaper.fill",
            costLine: "$500 one-shot",
            hypeLine: "+15 hype",
            upfrontCost: 500,
            requiresResearch: true,
            requiresStudioTier: false
        ),
        CampaignKindSpec(
            id: "launch_event",
            name: "Launch Event",
            systemImage: "party.popper.fill",
            costLine: "$5,000 one-shot",
            hypeLine: "+40 hype",
            upfrontCost: 5_000,
            requiresResearch: true,
            requiresStudioTier: true
        ),
    ]
}

private struct CampaignKindCard: View {
    let engine: GameEngine
    let kind: CampaignKindSpec
    let productID: UUID

    private enum Availability {
        case running(endDay: Int)
        case researchLocked
        case tierLocked
        case unaffordable
        case ready
    }

    private var availability: Availability {
        if let running = engine.state.campaigns.first(where: {
            $0.kindID == kind.id && $0.productID == productID
        }) {
            return .running(endDay: running.endDay)
        }
        if kind.requiresResearch,
           !engine.state.isCampaignKindUnlocked(kind.id, content: engine.content) {
            return .researchLocked
        }
        if kind.requiresStudioTier, !hasStudioTier {
            return .tierLocked
        }
        if engine.state.company.cash < kind.upfrontCost {
            return .unaffordable
        }
        return .ready
    }

    /// Studio or better.
    private var hasStudioTier: Bool {
        switch engine.state.company.officeTier {
        case .studio, .campus: true
        case .garage, .loft: false
        }
    }

    /// The tech node whose effect unlocks this campaign kind, for the
    /// locked caption. Defensive fallback if content ever drifts.
    private var unlockingTechName: String? {
        engine.content.techTree.first { node in
            if case .unlockCampaignKind(let id) = node.effect {
                id == kind.id
            } else {
                false
            }
        }?.name
    }

    var body: some View {
        CardView(kind.name, systemImage: kind.systemImage) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(spacing: Theme.Spacing.sm) {
                    StatPill(systemImage: "dollarsign.circle", value: kind.costLine)
                    StatPill(systemImage: "flame.fill", value: kind.hypeLine, tint: Theme.accent)
                    Spacer(minLength: 0)
                }

                switch availability {
                case .running(let endDay):
                    Text("Running · ends day \(endDay)")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.positiveCash)
                        .accessibilityLabel("\(kind.name) is running, ends day \(endDay)")

                case .researchLocked:
                    disabledRow(
                        caption: unlockingTechName.map { "Research '\($0)' to unlock" }
                            ?? "Unlocks via research"
                    )

                case .tierLocked:
                    disabledRow(caption: "Needs a Studio office")

                case .unaffordable:
                    disabledRow(caption: "Not enough cash")

                case .ready:
                    startButton
                }
            }
        }
    }

    private var startButton: some View {
        Button {
            engine.send(.startCampaign(kindID: kind.id, productID: productID))
        } label: {
            Label("Start", systemImage: kind.systemImage)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.accent)
        .accessibilityLabel("Start \(kind.name) campaign")
    }

    private func disabledRow(caption: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Text(caption)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: Theme.Spacing.sm)
            Button("Start") {}
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .buttonStyle(.bordered)
                .disabled(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kind.name) unavailable. \(caption)")
    }
}
