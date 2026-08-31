import SwiftUI
import TycoonContent
import TycoonEngine

/// The HQ dashboard: the pixel office scene, departments, company overview,
/// burn rate, the product in development (or the start-a-product call to
/// action), activity feed, and the Settings entry point.
struct HQScreen: View {
    let engine: GameEngine
    /// Opens the new-game flow (Settings → "Start a new game…"). Owned by
    /// the session, not the engine.
    let onNewGame: () -> Void

    @State private var showingNewProduct = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    if engine.state.company.daysInDebt > 0 {
                        DebtBanner(
                            daysInDebt: engine.state.company.daysInDebt,
                            graceDays: engine.balance.bankruptcyGraceDays
                        )
                    }
                    // The office is the game's face — it leads the dashboard.
                    OfficeCard(engine: engine)
                    // Reserved slot: renders nothing until WS-F fills it in.
                    GoalsCard(engine: engine)
                    DepartmentsCard(engine: engine)
                    CompanyCard(company: engine.state.company, difficulty: engine.state.difficulty)
                    BurnRateCard(
                        weeklyBurn: engine.weeklyBurn,
                        cash: engine.state.company.cash,
                        codebases: engine.state.codebases,
                        accruingDebt: engine.state.productsInDevelopment.reduce(0.0) {
                            guard case .development(let dev) = $1.stage else { return $0 }
                            return $0 + dev.debtAccrued
                        },
                        balance: engine.balance
                    )
                    ProductStatusCard(engine: engine) { showingNewProduct = true }
                    JournalCard(engine: engine)
                    // In-content settings entry point: nav-bar toolbars are
                    // hidden on tab roots (the HUD takes that slot).
                    SettingsButton { showingSettings = true }
                }
                .padding(Theme.Spacing.lg)
            }
            // The HUD inset lives on the stack's root content (not on the
            // NavigationStack) so the root scrolls below it and any pushed
            // destination shows the navigation bar instead.
            .withTopHUD(engine: engine)
            .background(Theme.screenBackground)
            .navigationTitle("HQ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingNewProduct) {
                NewProductFlow(engine: engine)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsSheet(engine: engine, onNewGame: onNewGame)
            }
        }
    }
}

// MARK: - Settings button

/// Small gear button at the bottom of the dashboard.
private struct SettingsButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Settings", systemImage: "gearshape.fill")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
        }
        .buttonStyle(.bordered)
        .tint(.secondary)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Settings")
        .accessibilityHint("Difficulty, new game, and app version")
    }
}

// MARK: - Debt banner

private struct DebtBanner: View {
    let daysInDebt: Int
    /// The engine's own grace period, already scaled for difficulty — read
    /// rather than mirrored, so easy (+7) and hard (−4) count down right.
    let graceDays: Int

    private var daysLeft: Int {
        max(0, graceDays - daysInDebt)
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("In debt")
                    .font(.system(.headline, design: .rounded))
                Text("\(daysLeft) day\(daysLeft == 1 ? "" : "s") until bankruptcy")
                    .font(.subheadline)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.negativeCash)
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Theme.negativeCash.opacity(0.12),
            in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Company card

private struct CompanyCard: View {
    let company: Company
    let difficulty: Difficulty

    var body: some View {
        CardView("Company", systemImage: "building.2.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text(company.name)
                    .font(.system(.title2, design: .rounded).weight(.bold))

                HStack(spacing: Theme.Spacing.sm) {
                    StatPill(systemImage: officeIcon, value: company.officeTier.displayName)
                    StatPill(systemImage: difficulty.systemImage, value: difficulty.displayName, tint: .secondary)
                        .accessibilityLabel("Difficulty \(difficulty.displayName)")
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    HStack {
                        Text("Reputation")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(company.reputation.formatted(.number.precision(.fractionLength(0...1))))
                            .font(Theme.Typography.number(.caption))
                    }
                    Gauge(value: normalizedReputation) {
                        EmptyView()
                    }
                    .gaugeStyle(.accessoryLinearCapacity)
                    .tint(Theme.accent)
                }
            }
        }
    }

    private var normalizedReputation: Double {
        min(max(company.reputation / 100.0, 0), 1)
    }

    private var officeIcon: String {
        switch company.officeTier {
        case .garage: "door.garage.closed"
        case .loft: "house.fill"
        case .studio: "building.fill"
        case .campus: "building.2.fill"
        }
    }
}

// MARK: - Burn rate card

private struct BurnRateCard: View {
    let weeklyBurn: Int
    let cash: Int
    /// The studio's codebases, for the second kind of debt this card
    /// reports. Empty until something ships, and the line is hidden then.
    let codebases: [Codebase]
    /// The mess the builds currently in flight have made and not yet
    /// handed over. It lands on a codebase at ship — which is the point,
    /// and the reason it is worth watching before then.
    let accruingDebt: Double
    let balance: BalanceConfig

    var body: some View {
        CardView("Burn rate", systemImage: "flame.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .top, spacing: Theme.Spacing.xl) {
                    StatBlock(
                        label: "Weekly burn",
                        value: "\(weeklyBurn.money)/wk",
                        tint: weeklyBurn > 0 ? Theme.warning : .primary
                    )
                    StatBlock(label: "Runway", value: runwayValue, tint: runwayTint)
                }
                if cash < 0 {
                    Text("Out of cash — expenses are digging the hole deeper.")
                        .font(.footnote)
                        .foregroundStyle(Theme.negativeCash)
                }
                // The other debt. It is on the burn card and not on a
                // screen of its own because it is the same kind of number
                // as the runway: something that is quietly getting worse
                // while you are looking at the products.
                let worst = codebases.max(by: { $0.debt < $1.debt })
                if (worst?.debt ?? 0) >= 1 || accruingDebt >= 1 {
                    Divider()
                    codebaseDebtLine(worst)
                }
            }
        }
    }

    @ViewBuilder
    private func codebaseDebtLine(_ codebase: Codebase?) -> some View {
        let debt = codebase?.debt ?? 0
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(debtTint(debt))
                Text("Technical debt")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if accruingDebt >= 1 {
                    // What this crunch is costing, before it costs it.
                    Text("+\(Int(accruingDebt.rounded()))")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(Theme.warning)
                }
                Text("\(Int(debt.rounded()))")
                    .font(.system(.headline, design: .rounded).monospacedDigit())
                    .foregroundStyle(debtTint(debt))
            }
            Text(explanation(codebase))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Technical debt \(Int(debt.rounded()))"
                + (accruingDebt >= 1 ? ", \(Int(accruingDebt.rounded())) more in the build" : "")
        )
    }

    private func explanation(_ codebase: Codebase?) -> String {
        guard let codebase, codebase.debt >= 1 else {
            return "The build in flight is cutting corners. It lands on the "
                + "codebase you leave behind, not on this product."
        }
        let ceiling = balance.codebase.debtCeiling(codebase.debt)
        let base = "\(codebase.name) caps anything built on it at "
            + "\(Int((ceiling * 100).rounded()))%. Refactoring is the only way down."
        return accruingDebt >= 1
            ? base + " The build in flight will add \(Int(accruingDebt.rounded())) more at launch."
            : base
    }

    /// Debt reads neutral, then warning, then the colour cash uses when
    /// the company is underwater — because by then it is the same problem.
    private func debtTint(_ debt: Double) -> Color {
        let ceiling = balance.codebase.debtCeiling(debt)
        if ceiling <= 0.80 { return Theme.negativeCash }
        if ceiling <= 0.92 { return Theme.warning }
        return .secondary
    }

    private var runwayValue: String {
        if cash < 0 { return "—" }
        guard weeklyBurn > 0 else { return "∞" }
        return "\(cash / weeklyBurn) wk"
    }

    private var runwayTint: Color {
        if cash < 0 { return Theme.negativeCash }
        guard weeklyBurn > 0 else { return Theme.positiveCash }
        return cash / weeklyBurn <= 4 ? Theme.warning : .primary
    }
}

private struct StatBlock: View {
    let label: String
    let value: String
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(Theme.Typography.number(.title3))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .animation(Theme.Motion.valueChange, value: value)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Product status

/// Live product card: the product in development with compact progress,
/// or the call-to-action that opens the new-product flow.
private struct ProductStatusCard: View {
    let engine: GameEngine
    let startNewProduct: () -> Void

    var body: some View {
        if let product = engine.state.productInDevelopment,
           case .development(let progress) = product.stage {
            let type = engine.content.productType(product.typeID)
            CardView("In development", systemImage: "hammer.fill") {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    HStack(spacing: Theme.Spacing.sm) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.name)
                                .font(.system(.headline, design: .rounded))
                            if let type {
                                Label(type.name, systemImage: type.iconSystemName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        StatPill(
                            systemImage: "ladybug.fill",
                            value: "\(progress.openBugs) bug\(progress.openBugs == 1 ? "" : "s")",
                            tint: progress.openBugs > 0 ? Theme.warning : .secondary
                        )
                    }
                    TriPhaseProgress(progress: progress, type: type, compact: true)
                }
            }
        } else {
            StartProductCTACard(
                isFirstProduct: engine.state.products.isEmpty,
                action: startNewProduct
            )
        }
    }
}

private struct StartProductCTACard: View {
    let isFirstProduct: Bool
    let action: () -> Void

    private var title: String {
        isFirstProduct ? "Start your first product" : "Start a new product"
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Theme.accent)
                Text(title)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.primary)
                Text("Pick a type, pick a topic, and get building.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.sm)
            .cardStyle()
        }
        .buttonStyle(.pressableRow)
        .accessibilityLabel(title)
    }
}
