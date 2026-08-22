import Charts
import SwiftUI
import TycoonContent
import TycoonEngine

/// Detail for one product. Released products get the sales chart and
/// reviews; products still in development get progress bars, the focus
/// editor, and the Ship button.
struct ProductDetailScreen: View {
    let engine: GameEngine
    let productID: UUID

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
        SalesCard(info: info)
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
        let canShip = progress.codePts >= 0.6 * (type?.codePts ?? 0)
        VStack(spacing: Theme.Spacing.sm) {
            Button {
                engine.send(.ship(productID: product.id))
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
                Text("Shipping unlocks once code reaches 60% of its target.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
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

/// Compact date label for an arbitrary day, e.g. "W3 · Y1".
/// Mirrors the engine's calendar: 364-day years of 52 seven-day weeks.
private func gameDateLabel(forDay day: Int) -> String {
    let year = day / 364 + 1
    let week = (day % 364) / 7 + 1
    return "W\(week) · Y\(year)"
}
