import SwiftUI
import TycoonContent
import TycoonEngine

/// The HQ dashboard: the pixel office scene, departments, company overview,
/// burn rate, the product in development (or the start-a-product call to
/// action), activity feed, and the Settings entry point.
struct HQScreen: View {
    let engine: GameEngine
    /// Starts a new game at the chosen difficulty (Settings → "Start a new
    /// game…"). Owned by the session, not the engine.
    let onNewGame: (Difficulty) -> Void

    @State private var showingNewProduct = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    if engine.state.company.daysInDebt > 0 {
                        DebtBanner(daysInDebt: engine.state.company.daysInDebt)
                    }
                    // The office is the game's face — it leads the dashboard.
                    OfficeCard(engine: engine)
                    DepartmentsCard(engine: engine)
                    CompanyCard(company: engine.state.company, difficulty: engine.state.difficulty)
                    BurnRateCard(weeklyBurn: engine.weeklyBurn, cash: engine.state.company.cash)
                    ProductStatusCard(engine: engine) { showingNewProduct = true }
                    ActivityFeedCard(state: engine.state, content: engine.content, balance: engine.balance)
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
    let balance: BalanceConfig

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
                        ActivityRow(event: event, state: state, content: content, balance: balance)
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
    let balance: BalanceConfig

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
        case .amenityBuilt(let amenity, let day):
            (amenity.systemImage, "Opened the \(amenity.displayName)!", day, Theme.positiveCash)
        case .departmentFormed(let department, let day):
            (department.systemImage, "\(department.displayName) department formed", day, Theme.positiveCash)
        case .departmentDissolved(let department, let day):
            (department.systemImage, "\(department.displayName) department has no staff", day, Theme.warning)
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
        case .marketBoom(let topicID, let day):
            ("chart.line.uptrend.xyaxis", "\(topicName(topicID)) market is booming!", day, Theme.positiveCash)
        case .marketCrash(let topicID, let day):
            ("chart.line.downtrend.xyaxis", "\(topicName(topicID)) market crashed", day, Theme.negativeCash)
        case .employeeQuit(_, let name, let day):
            ("figure.walk.departure", "\(name) quit — morale hit rock bottom", day, Theme.negativeCash)
        case .employeePromoted(let employeeID, let level, let day):
            ("arrow.up.circle.fill", "\(employeeName(employeeID)) promoted to \(level.displayName)", day, Theme.positiveCash)
        case .employeeDemoted(let employeeID, let level, let day):
            ("arrow.down.circle.fill", "\(employeeName(employeeID)) demoted to \(level.displayName)", day, Theme.warning)
        case .salaryChanged(let employeeID, let weeklySalary, let day):
            ("dollarsign.arrow.circlepath", "\(employeeName(employeeID)) now earns \(weeklySalary.money)/wk", day, Theme.accent)
        case .employeeTrained(let employeeID, let day):
            ("book.fill", "\(employeeName(employeeID)) finished a training course", day, Theme.accent)
        case .contractDelivered(let contractID, let quality, let payout, let day):
            (
                "briefcase.fill",
                quality >= 80
                    ? "Delivered for \(clientName(contractID)): +\(payout.money) — client delighted"
                    : quality >= 60
                        ? "Delivered for \(clientName(contractID)): +\(payout.money) — client had notes"
                        : "Client rejected the quality: only +\(payout.money) paid",
                day,
                Theme.scoreTint(quality)
            )
        case .loanTaken(let amount, let day):
            ("banknote.fill", "Took a \(amount.money) loan", day, Theme.warning)
        case .loanRepaid(let amount, let day):
            ("banknote", "Repaid \(amount.money) of the loan", day, Theme.positiveCash)
        case .rivalFounded(_, let name, let day):
            ("flag.fill", "\(name) entered the scene", day, Theme.accent)
        case .rivalShipped(let rivalID, let topicID, let day):
            ("shippingbox", "\(rivalName(rivalID)) shipped a \(topicName(topicID)) product", day, Theme.warning)
        case .rivalFolded(_, let name, let day):
            ("flag.slash.fill", "\(name) shut down", day, Color.secondary)
        case .poachAttempt(let rivalID, let employeeID, let offered, _, let day):
            (
                "person.fill.questionmark",
                "\(rivalName(rivalID)) wants \(employeeName(employeeID)) — offering \(offered.money)/wk",
                day,
                Theme.warning
            )
        case .poachDefeated(let employeeID, let day):
            ("person.fill.checkmark", "\(employeeName(employeeID)) is staying with you", day, Theme.positiveCash)
        case .employeePoached(_, let name, let rivalID, let day):
            ("person.fill.xmark", "\(name) left for \(rivalName(rivalID))", day, Theme.negativeCash)
        case .buyoutOffered(let rivalID, let amount, _, let day):
            ("envelope.badge.fill", "\(rivalName(rivalID)) offered \(amount.money) for the company", day, Theme.warning)
        case .buyoutWithdrawn(let rivalID, let day):
            ("envelope", "\(rivalName(rivalID)) withdrew its buyout offer", day, Color.secondary)
        case .companySold(let rivalID, let amount, let day):
            ("crown.fill", "Sold the company to \(rivalName(rivalID)) for \(amount.money)!", day, Theme.positiveCash)
        case .rivalAcquired(_, let name, let hires, let day):
            (
                "building.2.crop.circle.fill",
                hires > 0 ? "Acquired \(name) — \(hires) joined the team" : "Acquired \(name)",
                day,
                Theme.positiveCash
            )
        case .officeRelocated(let district, let day):
            ("map.fill", "Moved the office to \(district.displayName)", day, Theme.accent)
        case .officeBought(let district, let price, let day):
            ("signature", "Bought the \(district.displayName) office for \(price.money)", day, Theme.positiveCash)
        case .officeSold(let district, let price, let day):
            ("signature", "Sold the \(district.displayName) office for \(price.money)", day, Theme.accent)
        case .instantActivityDone(let activity, let day):
            (activity.systemImage, activity.displayName, day, Color.secondary.opacity(0.6))
        case .itemPurchased(let itemID, let day):
            ("bag.fill", "Bought a \(itemName(itemID).lowercased())", day, Theme.accent)
        case .socialActivity(let kind, let employeeID, let day):
            (
                kind.systemImage,
                socialMessage(kind, employeeID: employeeID),
                day,
                Theme.accent
            )
        case .friendshipFormed(let a, let b, let day):
            (
                "person.2.fill",
                "\(employeeName(a)) and \(employeeName(b)) became friends",
                day,
                Theme.positiveCash
            )
        case .friendLostMorale(let employeeID, let day):
            ("heart.slash", "\(employeeName(employeeID)) misses their friend", day, Theme.warning)
        case .staffBirthday(let employeeID, let day):
            ("birthday.cake.fill", "It's \(employeeName(employeeID))'s birthday!", day, Theme.positiveCash)
        case .staffEventOccurred(let employeeID, let kind, _, let day):
            (
                "person.crop.circle.badge.questionmark",
                kind == .familyEmergency
                    ? "\(employeeName(employeeID)) has a family emergency"
                    : "\(employeeName(employeeID)) is being courted by a rival",
                day,
                Theme.warning
            )
        case .staffEventResolved(let employeeID, let choice, let day):
            (
                choice == .supportive ? "hand.raised.fill" : "briefcase.fill",
                choice == .supportive
                    ? "You backed \(employeeName(employeeID)) — they'll remember"
                    : "Business came first for \(employeeName(employeeID))",
                day,
                choice == .supportive ? Theme.positiveCash : Color.secondary
            )
        }
    }

    private func socialMessage(_ kind: SocialActivityKind, employeeID: UUID?) -> String {
        let name = employeeID.map { employeeName($0) } ?? "the team"
        return switch kind {
        case .coffee: "Coffee with \(name)"
        case .oneOnOne: "1-on-1 with \(name)"
        case .gift: "A gift for \(name)"
        case .teamDinner: "The whole team went to dinner"
        }
    }

    /// Defensive name lookup — saves can reference item ids the balance no
    /// longer knows.
    private func itemName(_ id: String) -> String {
        balance.instantLife.items[id]?.name ?? "little something"
    }

    /// Defensive name lookup — folded and acquired rivals are gone from
    /// state, so their events fall back.
    private func rivalName(_ id: UUID) -> String {
        state.rivals.rival(id: id)?.name ?? "a rival"
    }

    /// Defensive name lookup — saves can reference topic ids the catalog no
    /// longer knows.
    private func topicName(_ id: String) -> String {
        content.topic(id)?.name ?? "A niche"
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
