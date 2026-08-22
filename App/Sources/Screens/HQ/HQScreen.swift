import SwiftUI
import TycoonContent
import TycoonEngine

/// The HQ dashboard: the pixel office scene, company overview, burn rate,
/// the product in development (or the start-a-product call to action), and
/// activity feed.
struct HQScreen: View {
    let engine: GameEngine

    @State private var showingNewProduct = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                if engine.state.company.daysInDebt > 0 {
                    DebtBanner(daysInDebt: engine.state.company.daysInDebt)
                }
                // The office is the game's face — it leads the dashboard.
                OfficeCard(engine: engine)
                CompanyCard(company: engine.state.company)
                BurnRateCard(weeklyBurn: engine.weeklyBurn, cash: engine.state.company.cash)
                ProductStatusCard(engine: engine) { showingNewProduct = true }
                ActivityFeedCard(state: engine.state, content: engine.content)
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.screenBackground)
        .sheet(isPresented: $showingNewProduct) {
            NewProductFlow(engine: engine)
        }
    }
}

// MARK: - Debt banner

private struct DebtBanner: View {
    let daysInDebt: Int

    /// Grace period before `GameOverInfo` — days a company may stay in debt
    /// before bankruptcy. Mirrors the engine's rule.
    private static let bankruptcyGraceDays = 14

    private var daysLeft: Int {
        max(0, Self.bankruptcyGraceDays - daysInDebt)
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

    var body: some View {
        CardView("Company", systemImage: "building.2.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text(company.name)
                    .font(.system(.title2, design: .rounded).weight(.bold))

                StatPill(systemImage: officeIcon, value: company.officeTier.displayName)

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    HStack {
                        Text("Reputation")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(company.reputation.formatted(.number.precision(.fractionLength(0...1))))
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .monospacedDigit()
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
            }
        }
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
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.35), value: value)
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
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

// MARK: - Activity feed card

private struct ActivityFeedCard: View {
    let state: GameState
    let content: ContentCatalog

    /// Newest events first, capped for the dashboard.
    private var recent: [GameEvent] {
        Array(state.eventLog.suffix(6).reversed())
    }

    var body: some View {
        CardView("Activity", systemImage: "bolt.fill") {
            if recent.isEmpty {
                Text("All quiet. Time to build something.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, Theme.Spacing.sm)
            } else {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    ForEach(Array(recent.enumerated()), id: \.offset) { _, event in
                        ActivityRow(event: event, state: state, content: content)
                    }
                }
            }
        }
    }
}

private struct ActivityRow: View {
    let event: GameEvent
    let state: GameState
    let content: ContentCatalog

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
            Image(systemName: entry.icon)
                .font(.caption)
                .foregroundStyle(entry.tint)
            Text(entry.message)
                .font(.subheadline)
            Spacer(minLength: Theme.Spacing.sm)
            Text("Day \(entry.day)")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
    }

    private var entry: (icon: String, message: String, day: Int, tint: Color) {
        switch event {
        case .bankruptcyWarning(let day):
            ("exclamationmark.triangle.fill", "Bankruptcy warning — cash has run dry", day, Theme.warning)
        case .gameOver(let day):
            ("xmark.octagon.fill", "The company went bankrupt", day, Theme.negativeCash)
        case .productStarted(let productID, let day):
            ("hammer.fill", "Started building \(productName(productID))", day, Theme.accent)
        case .shipped(let productID, let day):
            ("shippingbox.fill", "Shipped \(productName(productID))!", day, Theme.positiveCash)
        case .reviewsIn(let productID, let averageScore, let day):
            (
                "star.fill",
                "Reviews are in for \(productName(productID)): \(averageScore)",
                day,
                Theme.scoreTint(averageScore)
            )
        case .productOffMarket(let productID, let day):
            ("archivebox.fill", "\(productName(productID)) left the market", day, Color.secondary)
        case .hired(let employeeID, let day):
            ("person.badge.plus", "Hired \(employeeName(employeeID))", day, Theme.positiveCash)
        case .fired(let employeeID, let day):
            ("person.badge.minus", "\(employeeName(employeeID, fallback: "Someone")) left the company", day, Color.secondary)
        case .candidatesRefreshed(let day):
            ("person.2.wave.2", "New candidates are looking for work", day, Theme.accent)
        case .researchStarted(let nodeID, let day):
            ("flask", "Research started: \(techName(nodeID))", day, Theme.accent)
        case .researchCompleted(let nodeID, let day):
            ("flask.fill", "Research complete: \(techName(nodeID))!", day, Theme.positiveCash)
        case .contractAccepted(let contractID, let day):
            ("briefcase", "Signed a contract with \(clientName(contractID))", day, Theme.accent)
        case .contractCompleted(let contractID, let payout, let day):
            ("briefcase.fill", "Delivered for \(clientName(contractID)): +\(payout.money)", day, Theme.positiveCash)
        case .contractFailed(let contractID, let penalty, let day):
            ("exclamationmark.triangle.fill", "Blew the \(clientName(contractID)) deadline: −\(penalty.money)", day, Theme.warning)
        case .campaignStarted(_, let day):
            ("megaphone.fill", "Marketing campaign launched", day, Theme.accent)
        case .contractOffersRefreshed(let day):
            ("phone.fill", "New clients are asking around", day, Theme.accent)
        case .officeUpgraded(let tier, let day):
            ("building.2.fill", "Moved into the \(tier.displayName)!", day, Theme.positiveCash)
        case .randomEvent(let eventID, let day):
            ("sparkles", eventHeadline(eventID), day, Theme.accent)
        case .lifeEvent(let eventID, let day):
            ("heart.text.square.fill", lifeEventHeadline(eventID), day, Theme.accent)
        case .founderAway(let reason, let untilDay, let day):
            (
                "person.crop.circle.badge.exclamationmark",
                "Founder out: \(reason) until day \(untilDay)",
                day,
                Theme.warning
            )
        case .founderBack(let day):
            ("person.crop.circle.badge.checkmark", "Founder is back at the office", day, Theme.positiveCash)
        case .relationshipChanged(let stage, let day):
            ("heart.fill", relationshipMessage(stage), day, Theme.positiveCash)
        case .breakup(let day):
            ("heart.slash.fill", "It's over — you're single again", day, Theme.negativeCash)
        case .childBorn(let name, let day):
            ("sparkles", "Welcome, \(name)!", day, Theme.positiveCash)
        case .homeUpgraded(let tier, let day):
            ("house.fill", "Moved into the \(tier.displayName.lowercased())!", day, Theme.positiveCash)
        case .weekendSpent(let activity, let day):
            (activity.systemImage, "Weekend: \(activity.displayName)", day, Color.secondary.opacity(0.6))
        }
    }

    /// Defensive headline lookup — saves can reference life event ids the
    /// catalog no longer knows.
    private func lifeEventHeadline(_ id: String) -> String {
        content.lifeEvent(id)?.headline ?? "Something happened at home"
    }

    /// The partner's name is read from live state: by the time a breakup
    /// logs, it's gone (that event has its own copy).
    private func relationshipMessage(_ stage: RelationshipStage) -> String {
        let partner = state.life.family.partnerName ?? "someone"
        return switch stage {
        case .single: "Single again"
        case .dating: "Now dating \(partner)"
        case .partner: "Moved in with \(partner)"
        case .married: "Married \(partner)!"
        }
    }

    /// Defensive headline lookup — saves can reference event ids the catalog
    /// no longer knows.
    private func eventHeadline(_ id: String) -> String {
        content.events.first(where: { $0.id == id })?.headline ?? "Something happened"
    }

    /// Defensive name lookup — completed and failed jobs are removed from
    /// state, so their events fall back to a generic client.
    private func clientName(_ id: UUID) -> String {
        state.activeContract(id: id)?.clientName ?? "a client"
    }

    /// Defensive name lookup — events can outlive their products.
    private func productName(_ id: UUID) -> String {
        state.product(id: id)?.name ?? "a product"
    }

    /// Defensive name lookup — fired employees are gone from state, so
    /// their events fall back.
    private func employeeName(_ id: UUID, fallback: String = "someone") -> String {
        state.employee(id: id)?.name ?? fallback
    }

    /// Defensive name lookup — saves can reference tech ids the catalog no
    /// longer knows.
    private func techName(_ id: String) -> String {
        content.tech(id)?.name ?? "a technology"
    }
}
