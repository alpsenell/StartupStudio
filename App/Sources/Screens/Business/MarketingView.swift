import SwiftUI
import TycoonContent
import TycoonEngine

/// The Marketing segment of the Business tab: pick a product, watch its
/// hype, and run the three campaign kinds against it.
///
/// Products still in development are listed first (hype feeds their launch
/// reviews); released products follow, so a social push can be pointed at
/// something already on the market.
struct MarketingView: View {
    let engine: GameEngine

    @Environment(AppRouter.self) private var router
    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI
    /// updates this property for presented content before the
    /// environment is installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }
    @State private var selectedProductID: UUID?

    /// In-development products first, then released ones still selling.
    private var targets: [Product] {
        let developing = engine.state.productsInDevelopment
        let released = engine.state.products.filter { product in
            if case .released(let release) = product.stage { return !release.offMarket }
            return false
        }
        return developing + released
    }

    private var selected: Product? {
        targets.first { $0.id == selectedProductID } ?? targets.first
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            if targets.isEmpty {
                StartSomethingCard(router: router)
            } else {
                if targets.count > 1 {
                    ProductPicker(
                        targets: targets,
                        selection: Binding(
                            get: { selected?.id },
                            set: { selectedProductID = $0 }
                        )
                    )
                }
                if let product = selected {
                    HypeCard(product: product)
                    ForEach(CampaignKindSpec.all(balance: engine.balance)) { kind in
                        CampaignKindCard(engine: engine, kind: kind, product: product, shell: shell)
                    }
                }
            }
        }
    }
}

/// The one dead end left in Marketing: nothing to promote. It links
/// straight to the place a product gets started instead of naming a tab.
private struct StartSomethingCard: View {
    let router: AppRouter

    var body: some View {
        CardView("Nothing to promote", systemImage: "megaphone") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("Marketing needs something to hype — start a product first.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button {
                    Haptics.tap()
                    router.tab = .hq
                } label: {
                    Label("Go to HQ", systemImage: "arrow.forward")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            }
        }
    }
}

private struct ProductPicker: View {
    let targets: [Product]
    @Binding var selection: UUID?

    var body: some View {
        CardView("Campaign target", systemImage: "target") {
            Picker("Product", selection: $selection) {
                ForEach(targets) { product in
                    Text(product.name).tag(Optional(product.id))
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.accent)
            .accessibilityLabel("Campaign target product")
        }
    }
}

// MARK: - Hype gauge

private struct HypeCard: View {
    let product: Product

    /// The hype that is actually live on this product: the pre-launch
    /// figure while it is building, and the post-launch one once it is
    /// out. Released products used to read `nil` here because hype was
    /// frozen at ship — but a campaign run *since* launch is a real,
    /// decaying number now, and this card is where the player watches it.
    private var hype: Double {
        switch product.stage {
        case .development(let progress): progress.hype
        case .released(let release): release.liveHype
        }
    }

    private var launchHype: Double? {
        if case .released(let release) = product.stage { return release.hypeAtLaunch }
        return nil
    }

    private var isLive: Bool {
        if case .released = product.stage { return true }
        return false
    }

    private var hypeValue: Int { Int(hype.rounded()) }

    var body: some View {
        CardView("Hype", systemImage: "flame.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text(product.name)
                        .font(.system(.headline, design: .rounded))
                    Spacer(minLength: Theme.Spacing.sm)
                    Text("\(hypeValue)")
                            .font(Theme.Typography.number(.title2, weight: .bold))
                            .foregroundStyle(Theme.accent)
                        .contentTransition(.numericText())
                        .animation(Theme.Motion.valueChange, value: hypeValue)
                }

                Gauge(value: normalizedHype) {
                    EmptyView()
                }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(Theme.accent)

                Text(isLive
                    ? "Attention on a product that's already out: it lifts sales while it lasts, and decays daily. The reviews are already written."
                    : "Hype before launch buys reviews and sales, permanently — it is baked in at ship. It decays daily until then.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if isLive {
                    Text(
                        "Launched on \(Int((launchHype ?? 0).rounded())) hype, which still carries. This is what you've spent since."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var normalizedHype: Double {
        min(max(hype / 100, 0), 1)
    }
}

// MARK: - Campaign kinds

/// Display data for the three campaign kinds, read straight off the
/// balance so the card copy can never drift from the rule.
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
    /// The office tier the kind needs, if any.
    let minTier: OfficeTier?

    /// What a hype figure is actually worth, in the two currencies it
    /// buys — the exchange rate the tab never printed.
    ///
    /// A player was asked to choose between three prices for a scalar with
    /// no stated effect, which is why the gated, expensive launch event
    /// (~$125 per point) reads the same as the social push (~$25) unless
    /// you go and do the arithmetic.
    static func worth(_ hype: Double, balance: BalanceConfig, live: Bool) -> String {
        if live {
            let sales = hype * balance.economy.liveHypeSalesFactor / balance.salesHypeDivisor * 100
            return "≈ +\(format(sales))% sales while it lasts"
        }
        let reviewPoints = hype / balance.reviewHypeDivisor
        let sales = hype * balance.hypeLaunchCarryFraction / balance.salesHypeDivisor * 100
        return "≈ +\(format(reviewPoints)) review pts, +\(format(sales))% sales"
    }

    static func all(balance: BalanceConfig) -> [CampaignKindSpec] {
        [
            CampaignKindSpec(
                id: "social_push",
                name: "Social Push",
                systemImage: "megaphone.fill",
                costLine: "\(balance.socialPushDailyCost.money)/day · \(balance.socialPushDurationDays) days",
                hypeLine: "+\(format(balance.socialPushDailyHype)) hype/day",
                upfrontCost: balance.socialPushDailyCost,
                requiresResearch: false,
                minTier: nil
            ),
            CampaignKindSpec(
                id: "press_release",
                name: "Press Release",
                systemImage: "newspaper.fill",
                costLine: "\(balance.pressReleaseCost.money) one-shot",
                hypeLine: "+\(format(balance.pressReleaseHype)) hype",
                upfrontCost: balance.pressReleaseCost,
                requiresResearch: true,
                minTier: nil
            ),
            CampaignKindSpec(
                id: "launch_event",
                name: "Launch Event",
                systemImage: "party.popper.fill",
                costLine: "\(balance.launchEventCost.money) one-shot",
                hypeLine: "+\(format(balance.launchEventHype)) hype",
                upfrontCost: balance.launchEventCost,
                requiresResearch: true,
                minTier: OfficeTier(rawValue: balance.launchEventMinTier)
            ),
        ]
    }

    private static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}

private struct CampaignKindCard: View {
    let engine: GameEngine
    let kind: CampaignKindSpec
    let product: Product
    let shell: GameShell

    private enum Availability {
        case running(endDay: Int)
        case researchLocked
        case tierLocked(OfficeTier)
        case unaffordable
        case ready
    }

    private var availability: Availability {
        if let running = engine.state.campaigns.first(where: {
            $0.kindID == kind.id && $0.productID == product.id && $0.endDay >= engine.state.day
        }) {
            return .running(endDay: running.endDay)
        }
        if kind.requiresResearch,
           !engine.state.isCampaignKindUnlocked(kind.id, content: engine.content) {
            return .researchLocked
        }
        if let minTier = kind.minTier, engine.state.company.officeTier.rank < minTier.rank {
            return .tierLocked(minTier)
        }
        if engine.state.company.cash < kind.upfrontCost {
            return .unaffordable
        }
        return .ready
    }

    /// What this kind's hype is worth against the selected product —
    /// reviews and permanent sales before launch, temporary sales after.
    private var exchangeRate: String {
        let balance = engine.balance
        let hype: Double = switch kind.id {
        case "social_push": balance.socialPushDailyHype * Double(balance.socialPushDurationDays)
        case "press_release": balance.pressReleaseHype
        default: balance.launchEventHype
        }
        let live: Bool = if case .released = product.stage { true } else { false }
        return CampaignKindSpec.worth(hype, balance: balance, live: live)
    }

    /// The tech node whose effect unlocks this campaign kind, for the
    /// locked caption. Defensive fallback if content ever drifts.
    private var unlockingTech: TechNode? {
        engine.content.techTree.first { node in
            if case .unlockCampaignKind(let id) = node.effect {
                id == kind.id
            } else {
                false
            }
        }
    }

    var body: some View {
        CardView(kind.name, systemImage: kind.systemImage) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(spacing: Theme.Spacing.sm) {
                    StatPill(systemImage: "dollarsign.circle", value: kind.costLine)
                    StatPill(systemImage: "flame.fill", value: kind.hypeLine, tint: Theme.accent)
                    Spacer(minLength: 0)
                }

                Text(exchangeRate)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                switch availability {
                case .running(let endDay):
                    Text("Running · ends day \(endDay)")
                        .font(Theme.Typography.number(.footnote))
                        .foregroundStyle(Theme.positiveCash)
                        .accessibilityLabel("\(kind.name) is running, ends day \(endDay)")

                case .researchLocked:
                    ResearchLockedRow(kindName: kind.name, tech: unlockingTech)

                case .tierLocked(let tier):
                    disabledRow(caption: "Needs \(tier.displayName == "Studio" ? "a" : "the") \(tier.displayName)")

                case .unaffordable:
                    disabledRow(caption: "Not enough cash — you have \(engine.state.company.cash.money)")

                case .ready:
                    startButton
                }
            }
        }
    }

    private var startButton: some View {
        Button {
            shell.toasts.send(
                .startCampaign(kindID: kind.id, productID: product.id),
                to: engine,
                rejected: "\(kind.name) couldn't start for \(product.name)"
            )
        } label: {
            Label("Start", systemImage: kind.systemImage)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.accent)
        .accessibilityLabel("Start \(kind.name) campaign for \(product.name)")
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

/// A locked campaign that links straight to the tech that unlocks it,
/// instead of naming a tab and leaving the player to find it.
private struct ResearchLockedRow: View {
    let kindName: String
    let tech: TechNode?

    @Environment(AppRouter.self) private var router

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Text(tech.map { "Research “\($0.name)” to unlock" } ?? "Unlocks via research")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: Theme.Spacing.sm)
            Button {
                Haptics.tap()
                router.go(.research)
            } label: {
                Label("R&D", systemImage: "flask.fill")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
            }
            .buttonStyle(.bordered)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(kindName) unavailable until researched")
    }
}
