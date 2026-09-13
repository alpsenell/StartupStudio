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
                // MARK: K2 (product lifecycle) — a reader, so `-autoRoute
                // k2-card` can scroll to the lifecycle card.
                ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        switch product.stage {
                        case .development(let progress):
                            developmentContent(product: product, progress: progress)
                        case .released(let info):
                            releasedContent(product: product, info: info)
                        }
                        // U6: the same product from the outside.
                        StorefrontLinkButton(productID: productID)
                    }
                    .padding(Theme.Spacing.lg)
                }
                .task {
                    #if DEBUG
                    if LifecycleDebug.consume(.card) {
                        try? await Task.sleep(for: .seconds(1))
                        withAnimation { proxy.scrollTo("k2-lifecycle", anchor: .top) }
                    }
                    // The ship confirmation anchors to the button: bring
                    // it on screen before `shipButton` opens the dialog.
                    if LifecycleDebug.peek(.shipDialog) {
                        try? await Task.sleep(for: .milliseconds(300))
                        proxy.scrollTo("k2-ship", anchor: .bottom)
                    }
                    #endif
                }
                }
                // MARK: end K2
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
        // MARK: K2 (product lifecycle) — build its v2, or retire it.
        LifecycleCard(engine: engine, product: product, info: info)
            .id("k2-lifecycle")
        // MARK: end K2
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
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                TriPhaseProgress(progress: progress, type: type)
                if engine.state.employees.contains(where: { !$0.isFounder }) {
                    Divider()
                    // The pace, where "we need to ship sooner" is decided.
                    WorkPaceControl(engine: engine, compact: true)
                }
            }
        }

        // M1: what the product *is*, before what the pools are. A build
        // with an empty board says so and costs nothing.
        if let board = featureBoard(for: product) {
            FeatureBoardLinkButton(
                productID: productID,
                multiplier: board.qualityMultiplier,
                filled: board.filled,
                slots: board.slots
            )
        }

        CardView("Focus", systemImage: "slider.horizontal.3") {
            FocusEditor(
                focus: focusBinding(fallback: progress.focus),
                matching: type.map { PhaseFocus.matching(progress: progress, type: $0) }
            )
        }

        if let forecast = engine.state.shipForecast(
            productID: productID, balance: engine.balance, content: engine.content
        ) {
            ShipForecastCard(forecast: forecast)
        }

        // MARK: J5 (announce) — the ship date, told or not.
        AnnounceCard(engine: engine, product: product)
        // MARK: end J5

        shipButton(product: product, progress: progress)
            // MARK: K2 (product lifecycle) — a scroll target for `k2-replace`.
            .id("k2-ship")
            // MARK: end K2
    }

    /// M1: the product's board, read. `nil` for anything not in
    /// development — a shipped board is history.
    private func featureBoard(for product: Product) -> FeatureBoardReading? {
        guard case .development = product.stage else { return nil }
        return FeatureBoard.reading(
            for: product, state: engine.state, content: engine.content, balance: engine.balance
        )
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
                .monospacedDigit()
                .foregroundStyle(.secondary)
            }
            // MARK: T7 (press and stakes) — who gets the review copy first.
            if canShip { ExclusiveRow(engine: engine, productID: product.id) }
            // MARK: end T7
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
                // MARK: T7 (press and stakes) — the exclusive, if one was picked.
                ExclusivePick.shared.grantAfterShip(productID: product.id, engine: engine)
                // MARK: end T7
            }
            // MARK: K2 (product lifecycle) — the third answer: ship it as
            // the v2 of a live product of the same kind, with what carries
            // printed on the button.
            ForEach(engine.state.lifecycleReplaceableParents(for: product.id)) { parent in
                Button(LifecycleShip.replaceLabel(parent: parent, state: engine.state, balance: engine.balance)) {
                    shell.toasts.send(
                        .shipReplacing(productID: product.id, parentID: parent.id),
                        to: engine,
                        rejected: engine.state.lifecycleReplaceRefusal(
                            productID: product.id, parentID: parent.id,
                            balance: engine.balance, content: engine.content
                        )?.sentence ?? "It is not ready to ship yet."
                    )
                }
            }
            // MARK: end K2
            Button("Keep working", role: .cancel) {}
        } message: {
            // MARK: K2 (product lifecycle)
            Text(shipPreview(progress: progress)
                + (LifecycleShip.replaceMessage(for: product.id, state: engine.state) ?? ""))
            // MARK: end K2
        }
        // MARK: K2 (product lifecycle) — `-autoRoute k2-replace`.
        .task {
            #if DEBUG
            if LifecycleDebug.consume(.shipDialog) {
                try? await Task.sleep(for: .seconds(1))
                confirmingShip = true
            }
            #endif
        }
        // MARK: end K2
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
        // M1: the board is part of what ships, so it is part of the last
        // sentence before it does.
        if let product = engine.state.product(id: productID),
           let board = featureBoard(for: product), board.filled > 0 {
            let percent = Int(((board.qualityMultiplier - 1) * 100).rounded())
            if percent != 0 {
                lines += " The board is worth \(percent > 0 ? "+" : "")\(percent)% on quality."
            }
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
                DetailStat(label: "Subscribers", value: info.subscribers.formatted(.number.locale(Theme.gameLocale)))
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

    // MARK: K2 (product lifecycle) — the priced sheet, in place of the
    // free picker.
    @State private var changingPrice = false
    // MARK: end K2

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
        // MARK: K2 (product lifecycle)
        .sheet(isPresented: $changingPrice) {
            LifecyclePriceSheet(engine: engine, productID: product.id)
        }
        .task {
            #if DEBUG
            if LifecycleDebug.consume(.price) {
                try? await Task.sleep(for: .seconds(1))
                changingPrice = true
            }
            #endif
        }
        // MARK: end K2
    }

    private var priceTierPicker: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            // MARK: K2 (product lifecycle) — C6: the picker became a
            // priced confirmation. The button opens it, and says when the
            // next change is allowed.
            Button { changingPrice = true } label: {
                LifecycleRowLabel(
                    title: "Change the price · \(info.priceTier.displayName)",
                    icon: "tag.fill",
                    detail: priceButtonDetail,
                    tint: .secondary
                )
            }
            .buttonStyle(.pressableRow)
            .accessibilityLabel("Change the price of \(product.name)")
            // MARK: end K2

            // MARK: J5 (announce) — I1: the caption at this product's score.
            Text(LiveOps.priceCaption(
                for: info.priceTier, balance: engine.balance, reviewScore: info.averageReviewScore
            ))
            // MARK: end J5
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    // MARK: K2 (product lifecycle)
    /// Under the price button: when the next change is allowed, or what
    /// the two directions cost.
    private var priceButtonDetail: String {
        let other = PriceTier.allCases.first { $0 != info.priceTier } ?? .standard
        if case .cooldown(let until)? = engine.state.lifecycleRepriceRefusal(
            productID: product.id, tier: other, balance: engine.balance
        ) {
            return "The next change can come on day \(until)."
        }
        return info.isSubscription
            ? "A rise costs subscribers; a cut is a sale once a quarter."
            : "A rise dents sales for a month; a cut is a sale once a quarter."
    }
    // MARK: end K2

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
                : "+\(worth.formatted(.number.precision(.fractionLength(1)).locale(Theme.gameLocale))) quality · "
                    + "half the live bugs · a bumper sales week · uses a build slot")
                .font(.caption2)
                .monospacedDigit()
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
                .font(Theme.Typography.number(.title3))
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

                if let reason = info.launchForecast?.limitingFactor {
                    // Why the score was what it was, kept where the score is.
                    Label(reason, systemImage: "lightbulb.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
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
                        .emptySectionText()
                } else {
                    chart
                }

                HStack(alignment: .top, spacing: Theme.Spacing.xl) {
                    totalBlock(label: "Units sold", value: totalUnits.formatted(.number.locale(Theme.gameLocale)))
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
                .font(Theme.Typography.number(.title3))
                .contentTransition(.numericText())
                .animation(Theme.Motion.valueChange, value: value)
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
                    .emptySectionText()
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


// MARK: - The ship decision

/// What shipping today would get you, and what is holding the number down.
///
/// The screen used to show three completion bars and nothing else, so "100%
/// on all three" could mean a quality of 58 with no way to tell — the two
/// terms that put it there (the crew's ceiling and topic fit) were computed
/// at launch and never shown — and a third, the inherited codebase's debt,
/// arrived with a fourth page on the new-product sheet. Ship-or-keep-working is the real decision on
/// this screen; this is the information it needs.
private struct ShipForecastCard: View {
    let forecast: ShipForecast

    var body: some View {
        CardView("If you shipped today", systemImage: "shippingbox") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                    Text("\(Int(forecast.quality.rounded()))")
                        .font(Theme.Typography.number(.largeTitle, weight: .bold))
                        .foregroundStyle(Theme.scoreTint(Int(forecast.quality.rounded())))
                        .contentTransition(.numericText())
                        .animation(Theme.Motion.valueChange, value: forecast.quality)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("projected quality")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        // Whose ceiling it is. Saying "your crew" when the
                        // foundations are the problem sends the player to
                        // the hiring desk to fix something hiring cannot.
                        Text(
                            forecast.codebaseCeiling < forecast.skillCeiling
                                ? "the codebase tops this out at \(Int((forecast.crewCeiling * 100).rounded()))"
                                : "your crew tops out at \(Int((forecast.crewCeiling * 100).rounded()))"
                        )
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 0)
                }

                if let limiting = forecast.limitingFactor {
                    Text(limiting)
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(
                            forecast.quality >= forecast.crewCeiling * 100 - 1
                                ? Theme.warning : .secondary
                        )
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let name = forecast.codebaseName, forecast.codebaseDebt >= 1 {
                    // The debt is on the sheet whether or not it is the
                    // binding constraint yet, because by the time it binds
                    // the only fix left is weeks of refactoring.
                    Label(
                        "Built on \(name), carrying \(Int(forecast.codebaseDebt.rounded())) debt — a ×\(forecast.codebaseCeiling.formatted(.number.precision(.fractionLength(2)).locale(Theme.gameLocale))) ceiling you cannot polish past.",
                        systemImage: "shippingbox.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(Theme.warning)
                    .fixedSize(horizontal: false, vertical: true)
                }

                // M1: the board's contribution, in the same card as the
                // other terms that decide the number. Absent on an empty
                // board, which is what every pre-iteration-10 build has.
                if let summary = forecast.featureSummary {
                    let percent = Int(((forecast.featureMultiplier - 1) * 100).rounded())
                    Label(
                        percent == 0
                            ? "Feature board: \(summary) It is not moving the score either way."
                            : "Feature board: \(summary) Worth \(percent > 0 ? "+" : "")\(percent)% on quality.",
                        systemImage: "square.grid.2x2.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(percent < 0 ? Theme.warning : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                if forecast.marketScale < 0.99 {
                    // Own-saturation: two launches of the same type inside
                    // a quarter cut the peak to about 0.61, and this number
                    // appeared nowhere in the game.
                    Label(
                        "Your own recent launches have taken \(Int(((1 - forecast.marketScale) * 100).rounded()))% of this launch's audience.",
                        systemImage: "chart.line.downtrend.xyaxis"
                    )
                    .font(.caption)
                    .foregroundStyle(Theme.warning)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
