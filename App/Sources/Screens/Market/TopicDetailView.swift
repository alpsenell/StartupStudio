import SwiftUI
import TycoonContent
import TycoonEngine

/// One topic in depth, pushed inside the report's own stack: the 26-week
/// demand chart with boom/crash markers, a plain-language read, your
/// standing in the category and the forward read it buys, your products in
/// this market, and the topic's fit per product type.
struct TopicDetailView: View {
    let engine: GameEngine
    let topicID: String
    /// Where the actions go: the market report supplies a closure that
    /// closes the sheet first, so the flow opens on the Products tab.
    var onRoute: ((Route) -> Void)?

    @Environment(AppRouter.self) private var router

    /// The studio's product on the market here, if any: the one a campaign
    /// or a price change would be for.
    private var releasedProduct: Product? {
        engine.state.products.first { product in
            guard case .released(let info) = product.stage, !info.offMarket else { return false }
            return product.topicID == topicID
        }
    }

    private func go(_ route: Route) {
        Haptics.tap()
        if let onRoute { onRoute(route) } else { router.go(route) }
    }

    private var snapshot: TopicSnapshot? {
        engine.content.topic(topicID).map { TopicSnapshot(topic: $0, market: engine.state.market) }
    }

    private var category: CategorySnapshot? {
        engine.content.topic(topicID).map {
            CategorySnapshot(topic: $0, state: engine.state, balance: engine.balance)
        }
    }

    var body: some View {
        ScrollView {
            if let snapshot {
                VStack(spacing: Theme.Spacing.lg) {
                    DemandChartCard(engine: engine, snapshot: snapshot)
                    if let category {
                        CategoryStandingCard(
                            category: category,
                            driftSigma: engine.balance.market.driftSigma
                        )
                    }
                    ProductsInTopicCard(engine: engine, snapshot: snapshot)
                    TopicFitCard(engine: engine, snapshot: snapshot)
                }
                .padding(Theme.Spacing.lg)
            } else {
                ContentUnavailableView(
                    "Unknown market",
                    systemImage: "questionmark.circle",
                    description: Text("This topic is not in the current catalog.")
                )
                .padding(.top, Theme.Spacing.xl)
            }
        }
        .background(Theme.screenBackground)
        .navigationTitle(snapshot?.topic.name ?? "Market")
        .navigationBarTitleDisplayMode(.inline)
        // The market used to be a number the player read and could not
        // touch: the report's only button said "Done". The topic detail
        // now does something with what it says.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let topic = snapshot?.topic {
                HStack(spacing: Theme.Spacing.sm) {
                    Button {
                        go(.newProduct(topicID: topic.id))
                    } label: {
                        Label("Start a product in \(topic.name)", systemImage: "hammer.fill")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.xs)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    if let product = releasedProduct {
                        Button {
                            go(.marketing)
                        } label: {
                            Label("Campaign", systemImage: "megaphone.fill")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .padding(.vertical, Theme.Spacing.xs)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Run a campaign for \(product.name)")
                        Button {
                            go(.product(product.id))
                        } label: {
                            Label("Price", systemImage: "tag.fill")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .padding(.vertical, Theme.Spacing.xs)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Change the price of \(product.name)")
                    }
                }
                .padding(Theme.Spacing.lg)
                .background(.bar)
                .overlay(alignment: .top) { Divider() }
            }
        }
    }
}

// MARK: - Standing

/// What the studio's name is worth in this category, what it would take to
/// hold it, and the forward read it buys once it does.
private struct CategoryStandingCard: View {
    let category: CategorySnapshot
    let driftSigma: Double

    var body: some View {
        CardView("Your standing here", systemImage: "flag.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                    Text(category.standingLabel)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(category.tint)
                        .contentTransition(.numericText())
                    Text("of \(Int(category.maxStanding)) · \(category.tier)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                StandingBar(fraction: category.standingFraction, tint: category.tint, height: 6)

                Text(category.fieldLabel)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let read = category.forwardRead(driftSigma: driftSigma) {
                    HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                        Image(systemName: "binoculars.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.positiveCash)
                        Text(read)
                            .font(.footnote)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text("Reach \(Int(category.threshold.rounded())) standing here and you can "
                        + "read this market weeks ahead. Standing comes from shipping into it, "
                        + "how the launch reviewed, patches and campaigns — and it slips every "
                        + "week you have nothing on the market here.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Chart + read

private struct DemandChartCard: View {
    let engine: GameEngine
    let snapshot: TopicSnapshot

    private var shiftInterval: Int { engine.balance.market.shiftIntervalDays }

    private var points: [TopicChartPoint] {
        snapshot.chartPoints(currentDay: engine.state.day, shiftIntervalDays: shiftInterval)
    }

    private var markers: [TopicEventMarker] {
        snapshot.eventMarkers(
            events: engine.state.market.recentEvents,
            currentDay: engine.state.day,
            shiftIntervalDays: shiftInterval
        )
    }

    var body: some View {
        CardView("Demand, last \(MarketAnalysis.historyWeeks) weeks", systemImage: "chart.xyaxis.line") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                headline

                TopicDemandChart(points: points, markers: markers, tint: snapshot.band.tint)

                if !snapshot.hasHistory {
                    TrackingStartsNote()
                }

                legend

                Text(snapshot.read)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Market read: \(snapshot.read)")
            }
        }
    }

    private var headline: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.md) {
            Image(systemName: snapshot.topic.iconSystemName)
                .font(.title3)
                .foregroundStyle(snapshot.band.tint)

            Text(snapshot.multiplierLabel)
                .font(Theme.Typography.number(.title2, weight: .bold))
                .foregroundStyle(snapshot.band.figureTint)
                .contentTransition(.numericText())

            Text(snapshot.band.label)
                .font(.caption2.weight(.bold))
                .kerning(0.4)
                .foregroundStyle(snapshot.band.tint)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, 3)
                .background(snapshot.band.tint.opacity(0.15), in: Capsule())

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: snapshot.direction.systemImage)
                        .font(.caption.weight(.bold))
                    Text(snapshot.trendLabel)
                        .font(Theme.Typography.number(.subheadline))
                }
                .foregroundStyle(snapshot.direction.tint)
                Text("4-week trend")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(snapshot.accessibilitySummary)
    }

    private var legend: some View {
        HStack(spacing: Theme.Spacing.lg) {
            legendItem(color: snapshot.band.tint, systemImage: "minus", label: "Demand")
            legendItem(color: Theme.positiveCash, systemImage: "arrow.up", label: "Boom")
            legendItem(color: Theme.negativeCash, systemImage: "arrow.down", label: "Crash")
            Spacer(minLength: 0)
        }
        .accessibilityHidden(true)
    }

    private func legendItem(color: Color, systemImage: String, label: String) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Your products here

private struct ProductsInTopicCard: View {
    let engine: GameEngine
    let snapshot: TopicSnapshot

    private struct Entry: Identifiable {
        let product: Product
        let info: ReleaseInfo?
        var id: UUID { product.id }
    }

    /// Released products first (newest launch first), then the one in
    /// development, so the live earners top the list.
    private var entries: [Entry] {
        let inTopic = engine.state.products.filter { $0.topicID == snapshot.id }
        let released = inTopic.compactMap { product -> Entry? in
            guard case .released(let info) = product.stage else { return nil }
            return Entry(product: product, info: info)
        }
        .sorted { ($0.info?.launchDay ?? 0) > ($1.info?.launchDay ?? 0) }
        let developing = inTopic.compactMap { product -> Entry? in
            guard case .development = product.stage else { return nil }
            return Entry(product: product, info: nil)
        }
        return released + developing
    }

    var body: some View {
        CardView("Your products in \(snapshot.topic.name)", systemImage: "shippingbox.fill") {
            if entries.isEmpty {
                Text("Nothing of yours targets this market yet.")
                    .emptySectionText()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        row(entry)
                        if index < entries.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func row(_ entry: Entry) -> some View {
        let type = engine.content.productType(entry.product.typeID)
        let latest = entry.info?.weeklySales.last?.revenue
        let subtitle: String
        if let info = entry.info {
            let launch = "Launched \(MarketFormat.dateLabel(forDay: info.launchDay))"
            subtitle = info.offMarket ? "\(launch) · off market" : launch
        } else {
            subtitle = "In development"
        }

        return HStack(spacing: Theme.Spacing.md) {
            Image(systemName: type?.iconSystemName ?? "shippingbox")
                .font(.subheadline)
                .foregroundStyle(Theme.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.product.name)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: Theme.Spacing.sm)

            VStack(alignment: .trailing, spacing: 2) {
                if let latest {
                    Text(latest.money)
                        .font(Theme.Typography.number(.subheadline))
                        .foregroundStyle(entry.info?.offMarket == true ? .secondary : Theme.positiveCash)
                    Text("last wk")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else if entry.info != nil {
                    Text("no sales yet")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, Theme.Spacing.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(entry.product.name), \(subtitle)"
                + (latest.map { ", \($0.money) last week" } ?? "")
        )
    }
}

// MARK: - Fit by product type

private struct TopicFitCard: View {
    let engine: GameEngine
    let snapshot: TopicSnapshot

    var body: some View {
        CardView("Fit by product type", systemImage: "puzzlepiece.extension.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                VStack(spacing: 0) {
                    ForEach(Array(engine.content.productTypes.enumerated()), id: \.element.id) { index, type in
                        fitRow(type)
                        if index < engine.content.productTypes.count - 1 {
                            Divider()
                        }
                    }
                }
                Text("Fit multiplies launch quality. Locked types need research first.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func fitRow(_ type: ProductTypeDef) -> some View {
        let fit = snapshot.topic.fitByType[type.id] ?? 1.0
        let unlocked = engine.state.isProductTypeUnlocked(type.id, content: engine.content)
        let (label, tint): (String, Color) = fit > 1.05
            ? ("GREAT", Theme.positiveCash)
            : fit < 0.95 ? ("POOR", Theme.negativeCash) : ("OK", Color.secondary)

        return HStack(spacing: Theme.Spacing.md) {
            Image(systemName: type.iconSystemName)
                .font(.subheadline)
                .foregroundStyle(unlocked ? Theme.accent : .secondary)
                .frame(width: 24)

            Text(type.name)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(unlocked ? .primary : .secondary)
                .lineLimit(1)

            if !unlocked {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: Theme.Spacing.sm)

            Text(label)
                .font(.caption2.weight(.bold))
                .kerning(0.4)
                .foregroundStyle(tint)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, 3)
                .background(tint.opacity(0.15), in: Capsule())

            Text(MarketFormat.multiplier(fit))
                .font(Theme.Typography.number(.caption, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.vertical, Theme.Spacing.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(type.name)\(unlocked ? "" : ", locked"), fit \(label.lowercased()) \(MarketFormat.multiplier(fit))"
        )
    }
}
