import SwiftUI
import TycoonContent
import TycoonEngine

/// The detailed market report, presented as a sheet from the Business tab's
/// Market segment. It carries its own `NavigationStack` (topic rows push a
/// `TopicDetailView` inside it) and a Done button, so it stays independent
/// of the app's hidden-nav-bar tab roots. Views here only read
/// `engine.state` / `engine.content`.
struct MarketReportScreen: View {
    let engine: GameEngine
    /// A topic to push straight away, when the report was opened from a
    /// deep link ("Details" on a market boom or crash).
    var initialTopicID: String?

    @Environment(\.dismiss) private var dismiss
    /// Optional for the reason `LaunchDaySheet` and `OfficeCard` are:
    /// SwiftUI updates presented content while its host is being torn
    /// down, and a non-optional `@Environment(AppRouter.self)` read traps
    /// there (the crash `StorefrontAutoRoute` documents). A nil router
    /// means the deep link has nowhere to go, which on a screen that is
    /// closing is exactly right.
    @Environment(AppRouter.self) private var router: AppRouter?
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    MarketPositionCard(engine: engine)
                    CategoryStripCard(engine: engine)
                    TopicDemandTable(engine: engine)
                    ProductTypeMarketsCard(engine: engine)
                    MarketEventsCard(engine: engine)
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle("Market Report")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: TopicRoute.self) { route in
                TopicDetailView(engine: engine, topicID: route.topicID) { route in
                    // Close the report first, then deep-link: the flow opens
                    // on the Products tab, not under this sheet.
                    dismiss()
                    router?.go(route)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                if let initialTopicID, engine.content.topic(initialTopicID) != nil {
                    path.append(TopicRoute(topicID: initialTopicID))
                }
            }
        }
    }
}

/// Navigation value for pushing a topic inside the report's own stack.
struct TopicRoute: Hashable {
    let topicID: String
}

// MARK: - Topic demand table

/// One row per topic, hottest first: icon, name, multiplier, sparkline,
/// 4-week trend, and the last weekly change. Rows push the topic detail.
private struct TopicDemandTable: View {
    let engine: GameEngine

    private var snapshots: [TopicSnapshot] {
        MarketAnalysis.byDemand(content: engine.content, market: engine.state.market)
    }

    private var anyHistory: Bool {
        snapshots.contains(where: \.hasHistory)
    }

    var body: some View {
        CardView("Topic demand", systemImage: "chart.xyaxis.line") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if !anyHistory {
                    TrackingStartsNote()
                }

                VStack(spacing: 0) {
                    ForEach(Array(snapshots.enumerated()), id: \.element.id) { index, snapshot in
                        NavigationLink(value: TopicRoute(topicID: snapshot.id)) {
                            TopicDemandRow(snapshot: snapshot)
                        }
                        .buttonStyle(.plain)
                        if index < snapshots.count - 1 {
                            Divider()
                        }
                    }
                }

                Text("Multiplier on weekly sales for products in that market. Trend compares now with four weeks ago.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct TopicDemandRow: View {
    let snapshot: TopicSnapshot

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: snapshot.topic.iconSystemName)
                .font(.subheadline)
                .foregroundStyle(snapshot.band.tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.topic.name)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                lastChangeLabel
            }

            Spacer(minLength: Theme.Spacing.sm)

            MarketSparkline(series: snapshot.series, tint: snapshot.band.tint)
                .frame(width: 64, height: 26)

            VStack(alignment: .trailing, spacing: 2) {
                Text(snapshot.multiplierLabel)
                    .font(Theme.Typography.number(.subheadline))
                    .foregroundStyle(snapshot.band.figureTint)
                    .contentTransition(.numericText())
                trendLabel
            }
            .frame(width: 62, alignment: .trailing)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, Theme.Spacing.sm)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(snapshot.accessibilitySummary)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder private var lastChangeLabel: some View {
        if let shift = snapshot.lastShiftDirection {
            HStack(spacing: 2) {
                Image(systemName: shift.systemImage)
                    .font(.caption2.weight(.bold))
                Text("\(MarketFormat.signedDelta(snapshot.lastChange)) last wk")
                    .font(Theme.Typography.number(.caption2, weight: .regular))
            }
            .foregroundStyle(shift.tint)
        } else {
            Text("no change last wk")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder private var trendLabel: some View {
        if snapshot.hasTrend {
            HStack(spacing: 2) {
                Image(systemName: snapshot.direction.systemImage)
                    .font(.caption2.weight(.bold))
                Text(snapshot.trendLabel)
                    .font(Theme.Typography.number(.caption2, weight: .regular))
            }
            .foregroundStyle(snapshot.direction.tint)
        } else {
            Text("4wk —")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Shared sparse-state note

/// Shown wherever the weekly history is still empty.
struct TrackingStartsNote: View {
    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "waveform.path.ecg")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.accent)
            Text("Tracking starts now — sparklines fill in weekly.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Your position

/// Revenue over the last four weeks against the four before, the best
/// seller, and a one-line market read.
private struct MarketPositionCard: View {
    let engine: GameEngine

    private var position: MarketPosition {
        MarketAnalysis.position(state: engine.state)
    }

    private var snapshots: [TopicSnapshot] {
        MarketAnalysis.snapshots(content: engine.content, market: engine.state.market)
    }

    var body: some View {
        let position = self.position
        CardView("Your position", systemImage: "scope") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .top) {
                    revenueBlock(label: "Last 4 wks", value: position.recentRevenue)
                    Spacer()
                    revenueBlock(label: "Previous 4 wks", value: position.previousRevenue)
                    Spacer()
                    changeBadge(position.changePercent)
                }

                if let best = position.bestSeller {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "trophy.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.warning)
                        Text(best.product.name)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .lineLimit(1)
                        Spacer(minLength: Theme.Spacing.sm)
                        Text(best.revenue.money)
                            .font(Theme.Typography.number(.subheadline, weight: .regular))
                            .foregroundStyle(.secondary)
                        Text(position.bestSellerIsLifetime ? "lifetime" : "4 wks")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        "Best seller \(best.product.name), \(best.revenue.money) \(position.bestSellerIsLifetime ? "lifetime" : "over four weeks")"
                    )
                } else {
                    Text("No sales yet — ship a product to start tracking.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(MarketAnalysis.marketRead(snapshots: snapshots, position: position))
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func revenueBlock(label: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value.money)
                .font(Theme.Typography.number(.headline))
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func changeBadge(_ change: Double?) -> some View {
        if let change {
            let direction: TrendDirection = change > 0.5 ? .rising : change < -0.5 ? .falling : .flat
            HStack(spacing: 3) {
                Image(systemName: direction.systemImage)
                    .font(.caption2.weight(.bold))
                Text(MarketFormat.signedPercent(change))
                    .font(Theme.Typography.number(.subheadline, weight: .bold))
            }
            .foregroundStyle(direction.tint)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .background(direction.tint.opacity(0.14), in: Capsule())
            .accessibilityLabel("Revenue \(direction.accessibilityLabel) \(MarketFormat.signedPercent(change))")
        } else {
            Text("n/a")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.vertical, Theme.Spacing.xs)
                .accessibilityLabel("No previous period to compare")
        }
    }
}

// MARK: - Events timeline

/// Recent booms and crashes, newest first.
private struct MarketEventsCard: View {
    let engine: GameEngine

    private var events: [MarketEvent] {
        engine.state.market.recentEvents.reversed()
    }

    var body: some View {
        CardView("Market events", systemImage: "bolt.fill") {
            if events.isEmpty {
                Text("No booms or crashes yet. Most weeks drift quietly; the big moves make the news here.")
                    .emptySectionText()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.offset) { index, event in
                        MarketEventRow(
                            event: event,
                            topicName: engine.content.topic(event.topicID)?.name ?? event.topicID,
                            isLast: index == events.count - 1
                        )
                    }
                }
            }
        }
    }
}

private struct MarketEventRow: View {
    let event: MarketEvent
    let topicName: String
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            VStack(spacing: 0) {
                Image(systemName: event.kind.systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(event.kind.tint, in: Circle())
                if !isLast {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.25))
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(topicName) \(event.kind.title.lowercased())")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text(MarketFormat.dateLabel(forDay: event.day))
                    .font(Theme.Typography.number(.caption, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, isLast ? 0 : Theme.Spacing.md)

            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(topicName) \(event.kind.title.lowercased()), \(MarketFormat.dateLabel(forDay: event.day))")
    }
}
