import SwiftUI
import TycoonContent
import TycoonEngine

/// The Market segment of the Business tab: a compact pulse of every topic's
/// demand — the latest boom or crash, the hottest and coldest markets, a
/// sparkline grid — and the way into the full report, presented as a sheet
/// with its own navigation so it stays clear of the hidden-nav-bar tab root.
struct MarketView: View {
    let engine: GameEngine

    @State private var showingReport = false
    /// Topic the report should open on, when a deep link named one.
    @State private var reportTopicID: String?

    @Environment(AppRouter.self) private var router

    /// Hottest first.
    private var snapshots: [TopicSnapshot] {
        MarketAnalysis.byDemand(content: engine.content, market: engine.state.market)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            BusinessSectionHeader(title: "Market pulse", systemImage: "chart.xyaxis.line")

            if let latest = engine.state.market.recentEvents.last {
                MarketEventBanner(
                    event: latest,
                    topicName: engine.content.topic(latest.topicID)?.name ?? latest.topicID,
                    isCurrentWeek: latest.day / MarketAnalysis.daysPerWeek
                        == engine.state.day / MarketAnalysis.daysPerWeek
                )
            }

            HotColdCard(snapshots: snapshots)
            SparklineGridCard(snapshots: engine.content.topics.map {
                TopicSnapshot(topic: $0, market: engine.state.market)
            })

            Button {
                Haptics.tap()
                reportTopicID = nil
                showingReport = true
            } label: {
                Label("Open Market Report", systemImage: "doc.text.magnifyingglass")
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.xs)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .accessibilityHint("Opens the detailed market report")

            Text("Demand multiplies weekly sales for products in that market. Conditions shift every week; booms and crashes make the news.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Spacing.xs)
        }
        .sheet(isPresented: $showingReport) {
            MarketReportScreen(engine: engine, initialTopicID: reportTopicID)
        }
        // "Details" on a market boom/crash pause opens the report already
        // scrolled to the topic that moved.
        .onChange(of: router.pendingPush, initial: true) { _, _ in
            if case .marketReport(let topicID)? = router.take(where: {
                if case .marketReport = $0 { return true } else { return false }
            }) {
                reportTopicID = topicID
                showingReport = true
            }
        }
    }
}

// MARK: - Latest event banner

private struct MarketEventBanner: View {
    let event: MarketEvent
    let topicName: String
    let isCurrentWeek: Bool

    private var headline: String {
        switch event.kind {
        case .boom: "\(topicName) is booming"
        case .crash: "\(topicName) crashed"
        }
    }

    private var detail: String {
        let when = isCurrentWeek ? "This week" : MarketFormat.dateLabel(forDay: event.day)
        switch event.kind {
        case .boom: return "\(when) · demand jumped; products in this market sell more."
        case .crash: return "\(when) · demand fell; products in this market sell less."
        }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: event.kind.systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(event.kind.tint, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(headline)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                Text(detail)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.md)
        .background(
            event.kind.tint.opacity(0.12),
            in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .strokeBorder(event.kind.tint.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(headline). \(detail)")
    }
}

// MARK: - Hot and cold

/// The three best and three worst multipliers side by side, each with its
/// 4-week trend arrow.
private struct HotColdCard: View {
    let snapshots: [TopicSnapshot]

    private static let count = 3

    private var hot: [TopicSnapshot] { Array(snapshots.prefix(Self.count)) }
    private var cold: [TopicSnapshot] { Array(snapshots.suffix(Self.count).reversed()) }

    var body: some View {
        CardView("Hot & cold", systemImage: "thermometer.medium") {
            HStack(alignment: .top, spacing: Theme.Spacing.lg) {
                column(title: "Hottest", systemImage: "flame.fill", tint: Theme.positiveCash, items: hot)
                Divider()
                column(title: "Coldest", systemImage: "snowflake", tint: Theme.negativeCash, items: cold)
            }
        }
    }

    private func column(
        title: String, systemImage: String, tint: Color, items: [TopicSnapshot]
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.bold))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(tint)
            .accessibilityAddTraits(.isHeader)

            ForEach(items) { snapshot in
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: snapshot.topic.iconSystemName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                    Text(snapshot.topic.name)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 2)
                    if snapshot.hasTrend {
                        Image(systemName: snapshot.direction.systemImage)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(snapshot.direction.tint)
                    }
                    Text(snapshot.multiplierLabel)
                        .font(Theme.Typography.number(.caption))
                        .foregroundStyle(snapshot.band.figureTint)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(snapshot.accessibilitySummary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Sparkline grid

/// Every topic as a small tile: name, current multiplier, and the weekly
/// sparkline. Tiles stay in catalog order so a topic keeps its place as the
/// numbers move.
private struct SparklineGridCard: View {
    let snapshots: [TopicSnapshot]

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: Theme.Spacing.sm), count: 3
    )

    private var anyHistory: Bool {
        snapshots.contains(where: \.hasHistory)
    }

    var body: some View {
        CardView("All markets", systemImage: "square.grid.3x3.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if !anyHistory {
                    TrackingStartsNote()
                }
                LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                    ForEach(snapshots) { snapshot in
                        SparklineTile(snapshot: snapshot)
                    }
                }
            }
        }
    }
}

private struct SparklineTile: View {
    let snapshot: TopicSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: snapshot.topic.iconSystemName)
                    .font(.caption2)
                    .foregroundStyle(snapshot.band.tint)
                Text(snapshot.topic.name)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
            }
            MarketSparkline(series: snapshot.series, tint: snapshot.band.tint)
                .frame(height: 28)
            HStack(spacing: 2) {
                Text(snapshot.multiplierLabel)
                    .font(Theme.Typography.number(.caption2))
                    .foregroundStyle(snapshot.band.figureTint)
                    .contentTransition(.numericText())
                if snapshot.hasTrend {
                    Image(systemName: snapshot.direction.systemImage)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(snapshot.direction.tint)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(Theme.Spacing.sm)
        .background(
            Theme.chipBackground,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(snapshot.accessibilitySummary)
    }
}
