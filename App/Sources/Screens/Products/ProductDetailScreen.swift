import Charts
import SwiftUI
import TycoonContent
import TycoonEngine

/// Detail for one product. Released products get the sales chart and
/// reviews; products still in development get progress bars, the focus
/// editor, and the Ship button.
///
/// Pushed onto the Products tab's stack. The tab root hides the navigation
/// bar (the HUD takes that slot), so this screen explicitly shows it
/// again: that restores the Back button and the swipe-back gesture, which
/// iOS disables while the bar is hidden. The HUD isn't shown here.
struct ProductDetailScreen: View {
    let engine: GameEngine
    let productID: UUID

    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI
    /// updates this property for presented content before the
    /// environment is installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }
    @State private var confirmingShip = false

    var body: some View {
        Group {
            if let product = engine.state.product(id: productID) {
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        switch product.stage {
                        case .development(let progress):
                            developmentContent(product: product, progress: progress)
                        case .released(let info):
                            releasedContent(product: product, info: info)
                        }
                    }
                    .padding(Theme.Spacing.lg)
                }
            } else {
                ContentUnavailableView(
                    "Product not found",
                    systemImage: "questionmark.square.dashed",
                    description: Text("This product is no longer in the save.")
                )
            }
        }
        .background(Theme.screenBackground)
        .navigationTitle(engine.state.product(id: productID)?.name ?? "Product")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private var type: ProductTypeDef? {
        engine.state.product(id: productID).flatMap { engine.content.productType($0.typeID) }
    }

    private var topic: TopicDef? {
        engine.state.product(id: productID).flatMap { engine.content.topic($0.topicID) }
    }

    // MARK: - Released

    @ViewBuilder
    private func releasedContent(product: Product, info: ReleaseInfo) -> some View {
        ReleasedHeaderCard(product: product, info: info, type: type, topic: topic)
        if info.isSubscription {
            SubscriptionCard(info: info, type: type)
        }
        SalesCard(info: info)
        LiveOpsCard(engine: engine, product: product, info: info, shell: shell)
        RivalProductsCard(engine: engine, topicID: product.topicID)
        ReviewsCard(reviews: info.reviews)
    }

    // MARK: - In development

    @ViewBuilder
    private func developmentContent(product: Product, progress: DevProgress) -> some View {
        DevelopmentHeaderCard(
            product: product,
            progress: progress,
            type: type,
            topic: topic,
            techQualityBonusPercent: techQualityBonusPercent
        )

        CardView("Progress", systemImage: "chart.bar.fill") {
            TriPhaseProgress(progress: progress, type: type)
        }

        CardView("Focus", systemImage: "slider.horizontal.3") {
            FocusEditor(focus: focusBinding(fallback: progress.focus))
        }

        shipButton(product: product, progress: progress)
    }

    /// Rounded percent bonus from researched quality techs, or nil when
    /// there's none to brag about.
    private var techQualityBonusPercent: Int? {
        let multiplier = engine.state.qualityTechMultiplier(content: engine.content)
        guard multiplier > 1 else { return nil }
        return Int(((multiplier - 1) * 100).rounded())
    }

    /// Binds the focus editor straight to the engine: reads the live focus
    /// from state and sends `.setPhaseFocus` on every change.
    private func focusBinding(fallback: PhaseFocus) -> Binding<PhaseFocus> {
        Binding(
            get: {
                if case .development(let progress)? = engine.state.product(id: productID)?.stage {
                    progress.focus
                } else {
                    fallback
                }
            },
            set: { newFocus in
                engine.send(.setPhaseFocus(productID: productID, focus: newFocus))
            }
        )
    }

    @ViewBuilder
    private func shipButton(product: Product, progress: DevProgress) -> some View {
        // The gate is the engine's, read from balance rather than mirrored
        // (it used to be a hardcoded 0.6 here).
        let threshold = engine.balance.shipCodeThreshold
        let canShip = progress.codePts >= threshold * (type?.codePts ?? 0)
        VStack(spacing: Theme.Spacing.sm) {
            Button {
                confirmingShip = true
            } label: {
                Label("Ship it", systemImage: "shippingbox.fill")
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.xs)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .disabled(!canShip)
            .accessibilityLabel("Ship \(product.name)")

            if !canShip {
                Text(
                    "Shipping unlocks once code reaches \(Int((threshold * 100).rounded()))% of its target."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .confirmationDialog(
            "Ship \(product.name)?",
            isPresented: $confirmingShip,
            titleVisibility: .visible
        ) {
            Button("Ship it") {
                shell.toasts.send(
                    .ship(productID: product.id),
                    to: engine,
                    rejected: "It is not ready to ship yet."
                )
            }
            Button("Keep working", role: .cancel) {}
        } message: {
            Text(shipPreview(progress: progress))
        }
    }

    /// What the player is about to trade away, in the engine's own terms:
    /// how complete each pool is and what is still open. Deliberately not
    /// a predicted score — the reviews are the moment.
    private func shipPreview(progress: DevProgress) -> String {
        guard let type else {
            return "Once it ships, development stops for good and the press reviews it."
        }
        let design = percent(progress.designPts, of: type.designPts)
        let code = percent(progress.codePts, of: type.codePts)
        let polish = percent(progress.polishPts, of: type.polishPts)
        var lines = "Design \(design)%, code \(code)%, polish \(polish)%."
        if progress.openBugs > 0 {
            lines += " \(progress.openBugs) bug\(progress.openBugs == 1 ? "" : "s") still open — the press will find them."
        }
        if polish < 100 {
            lines += " Unfinished polish costs review score."
        }
        return lines + " Development stops for good."
    }

    private func percent(_ points: Double, of pool: Double) -> Int {
        guard pool > 0 else { return 100 }
        return Int((min(points / pool, 1) * 100).rounded())
    }
}

// MARK: - Subscriptions

/// Recurring revenue for a subscription product: subscribers and the
/// weekly run rate they add up to.
private struct SubscriptionCard: View {
    let info: ReleaseInfo
    let type: ProductTypeDef?

    private var weeklyRevenue: Int {
        Int((Double(info.subscribers) * (type?.unitPrice ?? 0)).rounded())
    }

    var body: some View {
        CardView("Subscription", systemImage: "arrow.triangle.2.circlepath") {
            HStack(alignment: .top, spacing: Theme.Spacing.xl) {
                DetailStat(label: "Subscribers", value: info.subscribers.formatted())
                DetailStat(label: "Weekly run rate", value: weeklyRevenue.money, tint: Theme.positiveCash)
            }
        }
    }
}

// MARK: - Live ops

/// Post-launch: bugs in the wild, who is fixing them, what the thing
/// costs, and whether to put out an update.
private struct LiveOpsCard: View {
    let engine: GameEngine
    let product: Product
    let info: ReleaseInfo
    let shell: GameShell

    /// Employees currently on this product's support queue.
    private var supporters: [Employee] {
        guard let assignment = LiveOps.supportAssignment(productID: product.id) else { return [] }
        return engine.state.employees.filter { $0.assignment == assignment }
    }

    /// Everyone who could be moved onto support.
    private var assignable: [Employee] {
        engine.state.employees.filter { !$0.isFounder }
    }

    var body: some View {
        CardView("Live ops", systemImage: "wrench.and.screwdriver.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                HStack(alignment: .top, spacing: Theme.Spacing.xl) {
                    DetailStat(
                        label: "Live bugs",
                        value: "\(info.liveBugs)",
                        tint: info.liveBugs > 0 ? Theme.warning : Theme.positiveCash
                    )
                    DetailStat(label: "Price", value: info.priceTier.displayName)
                    if info.offMarket {
                        DetailStat(label: "Status", value: "Delisted", tint: .secondary)
                    }
                }

                if info.liveBugs > 0 {
                    Text(
                        "Every open bug shaves a little off this product's weekly \(info.isSubscription ? "subscribers" : "sales")."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                if LiveOps.isAvailable, !info.offMarket {
                    priceTierPicker
                    supportRow
                    updateButton
                }
            }
        }
    }

    private var priceTierPicker: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Picker("Price tier", selection: priceBinding) {
                ForEach(PriceTier.allCases, id: \.self) { tier in
                    Text(tier.displayName).tag(tier)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Price tier for \(product.name)")

            Text(LiveOps.priceCaption(for: info.priceTier, balance: engine.balance))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var priceBinding: Binding<PriceTier> {
        Binding(
            get: { info.priceTier },
            set: { tier in
                guard let action = LiveOps.setPriceTier(productID: product.id, tier: tier) else { return }
                shell.toasts.send(
                    action,
                    to: engine,
                    ack: "\(product.name) is now priced \(tier.displayName.lowercased())",
                    icon: "tag.fill"
                )
            }
        )
    }

    private var supportRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                Text("Support")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Spacer(minLength: 0)
                Menu {
                    ForEach(assignable) { employee in
                        Button(employee.name) { assign(employee) }
                    }
                } label: {
                    Label(
                        supporters.isEmpty ? "Assign someone" : supporters.map(\.name).joined(separator: ", "),
                        systemImage: "person.badge.shield.checkmark"
                    )
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                }
                .disabled(assignable.isEmpty)
            }
            Text("Someone on support closes live bugs faster than they arrive.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func assign(_ employee: Employee) {
        guard let assignment = LiveOps.supportAssignment(productID: product.id) else { return }
        shell.toasts.send(
            .assign(employeeID: employee.id, to: assignment),
            to: engine,
            ack: "\(employee.name) is on \(product.name) support",
            icon: "person.badge.shield.checkmark"
        )
    }

    private var updateButton: some View {
        let state = engine.state
        let economy = engine.balance.economy
        let patchesSoFar: Int = {
            if case .released(let info) = product.stage { return info.updateCount }
            return 0
        }()
        // The same arithmetic `LiveOpsSystem` will apply, so the button
        // quotes what *this* patch is worth rather than what the first one
        // was — the point of the decay is that the player can see it.
        let worth = economy.updateQualityBonus
            * pow(economy.updateQualityDecay, Double(patchesSoFar))
        let noSlot = !state.hasFreeDevSlot

        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Button {
                guard let action = LiveOps.startUpdate(productID: product.id) else { return }
                shell.toasts.send(
                    action,
                    to: engine,
                    rejected: "No build slot free — something else is in development."
                )
            } label: {
                Label("Ship an update", systemImage: "arrow.up.circle.fill")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.xs)
            }
            .buttonStyle(.bordered)
            .disabled(noSlot)
            .accessibilityHint("Puts the product back into a short development cycle")

            Text(noSlot
                ? "No build slot free — a patch takes one, like a new product."
                : "+\(worth.formatted(.number.precision(.fractionLength(1)))) quality · "
                    + "half the live bugs · a bumper sales week · uses a build slot")
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(noSlot ? Theme.warning : .secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// What the competition has in this topic. Reads WS-F's rival products
/// when they exist and falls back to the rivals' focus topics, so the card
/// says something useful on either branch.
private struct RivalProductsCard: View {
    let engine: GameEngine
    let topicID: String

    @Environment(AppRouter.self) private var router

    private var contenders: [Rival] {
        engine.state.rivals.rivals.filter { $0.focusTopicIDs.contains(topicID) }
    }

    var body: some View {
        if !contenders.isEmpty {
            CardView("Competition", systemImage: "flag.2.crossed.fill") {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    ForEach(contenders) { rival in
                        HStack(spacing: Theme.Spacing.md) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rival.name)
                                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                Text("Works this market too")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            StatPill(
                                systemImage: "chart.bar.fill",
                                value: "Strength \(Int(rival.strength.rounded()))",
                                tint: .secondary
                            )
                        }
                        .accessibilityElement(children: .combine)
                    }
                    Button {
                        Haptics.tap()
                        router.tab = .business
                    } label: {
                        Label("See the rivals", systemImage: "arrow.forward")
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }
}

/// Labelled figure used by the released-product cards.
private struct DetailStat: View {
    let label: String
    let value: String
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Header cards

private struct ReleasedHeaderCard: View {
    let product: Product
    let info: ReleaseInfo
    let type: ProductTypeDef?
    let topic: TopicDef?

    var body: some View {
        CardView("Product", systemImage: type?.iconSystemName ?? "shippingbox") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.name)
                            .font(.system(.title2, design: .rounded).weight(.bold))
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    ScoreBadge(score: info.averageReviewScore)
                }

                HStack(spacing: Theme.Spacing.sm) {
                    StatPill(
                        systemImage: "sparkles",
                        value: "Quality \(Int(info.quality.rounded()))"
                    )
                    StatPill(
                        systemImage: "calendar",
                        value: "Launched \(gameDateLabel(forDay: info.launchDay))"
                    )
                }

                if info.offMarket {
                    OffMarketTag()
                }
            }
        }
    }

    private var subtitle: String {
        let typeName = type?.name ?? "Product"
        if let topicName = topic?.name {
            return "\(typeName) · \(topicName)"
        }
        return typeName
    }
}

private struct DevelopmentHeaderCard: View {
    let product: Product
    let progress: DevProgress
    let type: ProductTypeDef?
    let topic: TopicDef?
    let techQualityBonusPercent: Int?

    var body: some View {
        CardView("In development", systemImage: "hammer.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text(product.name)
                    .font(.system(.title2, design: .rounded).weight(.bold))

                HStack(spacing: Theme.Spacing.sm) {
                    if let type {
                        StatPill(systemImage: type.iconSystemName, value: type.name)
                    }
                    if let topic {
                        StatPill(systemImage: topic.iconSystemName, value: topic.name)
                    }
                }

                HStack(spacing: Theme.Spacing.sm) {
                    StatPill(
                        systemImage: "ladybug.fill",
                        value: "\(progress.openBugs) bug\(progress.openBugs == 1 ? "" : "s")",
                        tint: progress.openBugs > 0 ? Theme.warning : .secondary
                    )
                    if progress.hype > 0 {
                        StatPill(
                            systemImage: "megaphone.fill",
                            value: "Hype \(Int(progress.hype.rounded()))",
                            tint: Theme.accent
                        )
                        .accessibilityLabel("Hype \(Int(progress.hype.rounded()))")
                    }
                }

                if let techQualityBonusPercent {
                    StatPill(
                        systemImage: "flask.fill",
                        value: "+\(techQualityBonusPercent)% tech quality",
                        tint: Theme.positiveCash
                    )
                    .accessibilityLabel("Research bonus: plus \(techQualityBonusPercent) percent quality")
                }
            }
        }
    }
}

// MARK: - Sales

private struct SalesCard: View {
    let info: ReleaseInfo

    private var totalUnits: Int {
        info.weeklySales.reduce(0) { $0 + $1.units }
    }

    var body: some View {
        CardView("Weekly revenue", systemImage: "chart.bar.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                if info.weeklySales.isEmpty {
                    Text("No sales recorded yet — the first week is still ticking.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, Theme.Spacing.sm)
                } else {
                    chart
                }

                HStack(alignment: .top, spacing: Theme.Spacing.xl) {
                    totalBlock(label: "Units sold", value: totalUnits.formatted())
                    totalBlock(label: "Total revenue", value: info.totalRevenue.money)
                }
            }
        }
    }

    /// Bar per week. Stays readable at both 3 weeks and 26: integer x
    /// values with automatic axis stride, no per-bar labels.
    private var chart: some View {
        Chart(info.weeklySales, id: \.weekIndex) { sale in
            BarMark(
                x: .value("Week", Double(sale.weekIndex)),
                y: .value("Revenue", sale.revenue)
            )
            .foregroundStyle(Theme.accent)
            .cornerRadius(3)
        }
        .chartXAxisLabel("Week on market", alignment: .trailing)
        .chartXScale(domain: xDomain)
        .frame(height: 180)
        .accessibilityLabel("Weekly revenue chart, \(info.weeklySales.count) weeks")
    }

    /// Half-unit padding keeps the first and last bars from clipping at
    /// the plot edges, for short and long runs alike.
    private var xDomain: ClosedRange<Double> {
        let weeks = info.weeklySales.map(\.weekIndex)
        let lower = Double(weeks.min() ?? 0) - 0.5
        let upper = Double(weeks.max() ?? 1) + 0.5
        return lower...upper
    }

    private func totalBlock(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.35), value: value)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Reviews

private struct ReviewsCard: View {
    let reviews: [Review]

    var body: some View {
        CardView("Reviews", systemImage: "star.fill") {
            if reviews.isEmpty {
                Text("The press hasn't weighed in yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, Theme.Spacing.sm)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(reviews.enumerated()), id: \.offset) { index, review in
                        HStack(alignment: .top, spacing: Theme.Spacing.md) {
                            ScoreBadge(score: review.score)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(review.outlet)
                                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                Text(review.blurb)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, Theme.Spacing.sm)
                        .accessibilityElement(children: .combine)
                        if index < reviews.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Game dates

/// Compact date label for an arbitrary day, e.g. "Mar W3 · Y1", from the
/// one calendar the whole app shares.
private func gameDateLabel(forDay day: Int) -> String {
    GameCalendar(day: day).hudLabel
}
