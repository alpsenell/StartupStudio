import SwiftUI
import TycoonContent
import TycoonEngine

/// Shared read-only analysis over `engine.state.market`, the product list,
/// and the content catalog. Every Market view goes through these helpers so
/// thresholds, tints, and copy agree between the Business-tab overview and
/// the full report. Nothing here mutates state.
enum MarketAnalysis {
    /// Weeks of history the engine retains, and the sparklines show.
    static let historyWeeks = 26
    /// Multiplier above which a topic reads as hot.
    static let hotThreshold = 1.15
    /// Multiplier below which a topic reads as cold.
    static let coldThreshold = 0.85
    /// A 4-week move smaller than this (in multiplier units) reads as flat.
    static let flatTrend = 0.03
    /// Days per game week, mirroring the engine's calendar.
    static let daysPerWeek = 7
    /// Days per game year (52 weeks), mirroring the engine's calendar.
    static let daysPerYear = 364
    /// The revenue comparison window used by "Your position", in weeks.
    static let positionWindowWeeks = 4

    /// One snapshot per catalog topic, in catalog order.
    static func snapshots(content: ContentCatalog, market: MarketState) -> [TopicSnapshot] {
        content.topics.map { TopicSnapshot(topic: $0, market: market) }
    }

    /// Hottest first.
    static func byDemand(content: ContentCatalog, market: MarketState) -> [TopicSnapshot] {
        snapshots(content: content, market: market).sorted { $0.multiplier > $1.multiplier }
    }

    /// One category per catalog topic — the studio's standing in it, what
    /// it has on the market there, who else is selling into it, and the
    /// forward read where the studio has earned one. Ordered the way the
    /// player thinks about it: the categories they hold first, then the
    /// hottest of the rest.
    static func categories(
        state: GameState, content: ContentCatalog, balance: BalanceConfig
    ) -> [CategorySnapshot] {
        content.topics
            .map { CategorySnapshot(topic: $0, state: state, balance: balance) }
            .sorted { left, right in
                if left.standing != right.standing { return left.standing > right.standing }
                return left.market.multiplier > right.market.multiplier
            }
    }

    /// The day a released product's sales row was posted: the first weekly
    /// tick strictly after launch, then every week. Mirrors
    /// `ProductSystem.postWeeklySales` (ticks advance the day before the
    /// systems run, so a launch on a weekly day posts a week later).
    static func postDay(launchDay: Int, weekIndex: Int) -> Int {
        (launchDay / daysPerWeek + 1) * daysPerWeek + weekIndex * daysPerWeek
    }

    /// Revenue from sales rows posted on days in `lower < day <= upper`.
    static func revenue(_ info: ReleaseInfo, postedAfter lower: Int, through upper: Int) -> Int {
        info.weeklySales.reduce(0) { total, sale in
            let day = postDay(launchDay: info.launchDay, weekIndex: sale.weekIndex)
            return day > lower && day <= upper ? total + sale.revenue : total
        }
    }

    /// Revenue over the trailing comparison windows plus the best seller.
    static func position(state: GameState) -> MarketPosition {
        let window = positionWindowWeeks * daysPerWeek
        let now = state.day
        var recent = 0
        var previous = 0
        var best: (product: Product, revenue: Int)?

        for product in state.products {
            guard case .released(let info) = product.stage else { continue }
            let thisWindow = revenue(info, postedAfter: now - window, through: now)
            recent += thisWindow
            previous += revenue(info, postedAfter: now - 2 * window, through: now - window)
            if thisWindow > 0, thisWindow > (best?.revenue ?? 0) {
                best = (product, thisWindow)
            }
        }

        // With nothing selling in the window, fall back to the lifetime leader
        // so the card still names a product once anything has shipped.
        if best == nil {
            for product in state.products {
                guard case .released(let info) = product.stage, info.totalRevenue > 0 else { continue }
                if info.totalRevenue > (best?.revenue ?? 0) {
                    best = (product, info.totalRevenue)
                }
            }
            return MarketPosition(
                recentRevenue: recent, previousRevenue: previous,
                bestSeller: best, bestSellerIsLifetime: true
            )
        }
        return MarketPosition(
            recentRevenue: recent, previousRevenue: previous,
            bestSeller: best, bestSellerIsLifetime: false
        )
    }

    /// One-sentence read of the whole market plus the studio's momentum.
    static func marketRead(snapshots: [TopicSnapshot], position: MarketPosition) -> String {
        guard !snapshots.isEmpty else { return "No markets to read yet." }
        let average = snapshots.reduce(0.0) { $0 + $1.multiplier } / Double(snapshots.count)
        let hot = snapshots.filter { $0.band == .hot }.count
        let cold = snapshots.filter { $0.band == .cold }.count
        let rising = snapshots.filter { $0.direction == .rising }.count
        let falling = snapshots.filter { $0.direction == .falling }.count

        let tone: String
        if average >= 1.08 {
            tone = "Demand is running above baseline overall"
        } else if average <= 0.92 {
            tone = "Demand is running below baseline overall"
        } else {
            tone = "Demand is close to baseline overall"
        }
        let mix = "(\(MarketFormat.multiplier(average)) average, \(hot) hot, \(cold) cold)"

        let drift: String
        if rising > falling + 2 {
            drift = "with most markets climbing"
        } else if falling > rising + 2 {
            drift = "with most markets slipping"
        } else {
            drift = "with no strong drift either way"
        }

        let you: String
        if let change = position.changePercent {
            let pct = Int(abs(change).rounded())
            you = change >= 0
                ? "Your revenue is up \(pct)% on the previous four weeks."
                : "Your revenue is down \(pct)% on the previous four weeks."
        } else if position.recentRevenue > 0 {
            you = "Your first sales are landing now; the comparison starts next month."
        } else {
            you = "Nothing is selling yet; ship into a hot market to start the meter."
        }
        return "\(tone) \(mix), \(drift). \(you)"
    }
}

// MARK: - Topic snapshot

/// Everything a view needs to know about one topic, computed once per render.
struct TopicSnapshot: Identifiable {
    let topic: TopicDef
    let multiplier: Double
    let lastChange: Double
    /// `MarketState.trend(for:)`: last minus four weeks ago.
    let trend: Double
    /// Weekly multipliers, oldest first. Empty until the first shift lands.
    let history: [Double]

    var id: String { topic.id }

    init(topic: TopicDef, market: MarketState) {
        self.topic = topic
        multiplier = market.multiplier(for: topic.id)
        lastChange = market.lastChange(for: topic.id)
        trend = market.trend(for: topic.id)
        history = market.history[topic.id] ?? []
    }

    /// Chart series: the recorded history, or the live value as one point.
    var series: [Double] { history.isEmpty ? [multiplier] : history }

    /// Whether there is enough history to draw a line.
    var hasHistory: Bool { history.count >= 2 }

    /// Whether `trend` is meaningful: the engine reports 0 until five
    /// weekly samples exist.
    var hasTrend: Bool { history.count >= 5 }

    var band: DemandBand {
        if multiplier > MarketAnalysis.hotThreshold { return .hot }
        if multiplier < MarketAnalysis.coldThreshold { return .cold }
        return .steady
    }

    /// Direction of the 4-week trend; flat until there is enough history.
    var direction: TrendDirection {
        guard hasTrend else { return .flat }
        if trend > MarketAnalysis.flatTrend { return .rising }
        if trend < -MarketAnalysis.flatTrend { return .falling }
        return .flat
    }

    /// The 4-week trend as a percentage of the value four weeks ago.
    var trendPercent: Double? {
        guard hasTrend else { return nil }
        let base = multiplier - trend
        guard base > 0.0001 else { return nil }
        return trend / base * 100
    }

    var multiplierLabel: String { MarketFormat.multiplier(multiplier) }

    var trendLabel: String {
        trendPercent.map(MarketFormat.signedPercent) ?? "—"
    }

    /// Direction of the most recent weekly shift; nil while flat.
    var lastShiftDirection: TrendDirection? {
        guard abs(lastChange) >= 0.005 else { return nil }
        return lastChange > 0 ? .rising : .falling
    }

    /// Plain-language read, e.g. "Demand is 23% above baseline and rising —
    /// a good moment to launch."
    var read: String {
        let pct = Int(((multiplier - 1) * 100).rounded())
        let level: String
        if pct == 0 {
            level = "Demand is at baseline"
        } else if pct > 0 {
            level = "Demand is \(pct)% above baseline"
        } else {
            level = "Demand is \(-pct)% below baseline"
        }

        let motion: String
        switch direction {
        case .rising: motion = " and rising"
        case .falling: motion = " and falling"
        case .flat: motion = hasTrend ? " and holding" : ""
        }

        let advice: String
        switch (band, direction) {
        case (.hot, .rising): advice = "a good moment to launch"
        case (.hot, .falling): advice = "the peak may be passing; ship soon or wait it out"
        case (.hot, .flat): advice = "still a strong market to ship into"
        case (.cold, .rising): advice = "recovering, but not there yet"
        case (.cold, .falling): advice = "hold launches here until it turns"
        case (.cold, .flat): advice = "a weak market for now"
        case (.steady, .rising): advice = "worth lining up a launch"
        case (.steady, .falling): advice = "cooling off; no rush to ship here"
        case (.steady, .flat): advice = "no edge either way"
        }
        return "\(level)\(motion) — \(advice)."
    }

    /// Spoken summary for the row.
    var accessibilitySummary: String {
        var parts = ["\(topic.name) market \(band.label.lowercased()), demand \(multiplierLabel)"]
        if hasTrend {
            parts.append("four week trend \(direction.accessibilityLabel) \(trendLabel)")
        }
        if lastShiftDirection != nil {
            parts.append("last change \(MarketFormat.signedDelta(lastChange))")
        }
        return parts.joined(separator: ", ")
    }

    // MARK: Chart series

    /// Chart points keyed by absolute game week (1-based, like the Finances
    /// chart). The newest history entry is the latest shift, on the most
    /// recent day divisible by `shiftIntervalDays`.
    func chartPoints(currentDay: Int, shiftIntervalDays: Int) -> [TopicChartPoint] {
        let latestWeek = Self.latestShiftDay(currentDay: currentDay, interval: shiftIntervalDays)
            / MarketAnalysis.daysPerWeek
        let values = series
        return values.enumerated().map { index, value in
            TopicChartPoint(week: latestWeek - (values.count - 1 - index) + 1, value: value)
        }
    }

    /// Booms and crashes for this topic that fall inside the charted window,
    /// pinned to the history value recorded at that shift.
    func eventMarkers(
        events: [MarketEvent], currentDay: Int, shiftIntervalDays: Int
    ) -> [TopicEventMarker] {
        let interval = max(1, shiftIntervalDays)
        let latestShift = Self.latestShiftDay(currentDay: currentDay, interval: interval)
        let latestWeek = latestShift / MarketAnalysis.daysPerWeek
        let values = series
        var markers: [TopicEventMarker] = []
        for event in events where event.topicID == topic.id {
            let shiftsAgo = (latestShift - event.day) / interval
            let index = values.count - 1 - shiftsAgo
            guard values.indices.contains(index) else { continue }
            markers.append(TopicEventMarker(
                week: latestWeek - shiftsAgo + 1,
                value: values[index],
                kind: event.kind
            ))
        }
        return markers
    }

    private static func latestShiftDay(currentDay: Int, interval: Int) -> Int {
        let interval = max(1, interval)
        return currentDay - currentDay % interval
    }
}

struct TopicChartPoint: Identifiable {
    /// Absolute game week, 1-based.
    let week: Int
    let value: Double
    var id: Int { week }
}

struct TopicEventMarker: Identifiable {
    let week: Int
    let value: Double
    let kind: MarketEvent.Kind
    var id: String { "\(week)-\(kind.rawValue)" }
}

// MARK: - Category snapshot

/// One topic read as a *category* rather than as a demand number: what the
/// studio's name is worth there, what it has on the market, who it is up
/// against, and — only where the studio holds the category — where the
/// multiplier is likely to be a few weeks out.
struct CategorySnapshot: Identifiable {
    let topic: TopicDef
    /// The demand read every other market view already uses.
    let market: TopicSnapshot
    /// 0...`standing.maxStanding`.
    let standing: Double
    let maxStanding: Double
    /// The threshold that buys the forward read.
    let threshold: Double
    /// nil below the threshold: the read is the thing standing buys.
    let forecast: MarketForecast?
    /// The studio's products still selling here.
    let liveProducts: [Product]
    /// Rival studios with something on the market here, best first.
    let competitors: [(name: String, quality: Double)]

    var id: String { topic.id }

    init(topic: TopicDef, state: GameState, balance: BalanceConfig) {
        self.topic = topic
        market = TopicSnapshot(topic: topic, market: state.market)
        standing = state.market.standing(for: topic.id)
        maxStanding = balance.market.standing.maxStanding
        threshold = balance.market.standing.forecastThreshold
        forecast = state.market.forecast(for: topic.id, market: balance.market)
        liveProducts = state.products.filter { product in
            guard case .released(let info) = product.stage else { return false }
            return product.topicID == topic.id && !info.offMarket
        }
        competitors = state.rivals.competitors(in: topic.id, on: state.day)
            .map { (name: $0.rival.name, quality: $0.product.quality) }
            .sorted { $0.quality > $1.quality }
    }

    /// Whether the studio holds this category well enough to read it.
    var holdsCategory: Bool { standing >= threshold }

    /// Standing as a 0...1 bar fill.
    var standingFraction: Double {
        guard maxStanding > 0 else { return 0 }
        return min(1, max(0, standing / maxStanding))
    }

    var standingLabel: String { "\(Int(standing.rounded()))" }

    /// The rung the studio is on, named against the balance's threshold so
    /// the copy moves if the tuning does.
    var tier: String {
        if standing <= 0 { return "No presence" }
        if standing < threshold / 2 { return "Newcomer" }
        if standing < threshold { return "Known" }
        if standing < (threshold + maxStanding) / 2 { return "Established" }
        return "Household name"
    }

    var tint: Color {
        if standing <= 0 { return .secondary }
        if standing < threshold { return Theme.accent }
        return Theme.positiveCash
    }

    /// "You and 2 rivals" — who is actually in this category.
    var fieldLabel: String {
        let mine = liveProducts.count
        let theirs = competitors.count
        switch (mine, theirs) {
        case (0, 0): return "Nobody is selling here"
        case (0, _): return theirs == 1
            ? "\(competitors[0].name) has this to itself"
            : "\(theirs) rivals, none of them you"
        case (_, 0): return mine == 1 ? "Yours alone" : "\(mine) of yours, no rivals"
        default:
            let yours = mine == 1 ? "1 of yours" : "\(mine) of yours"
            return theirs == 1
                ? "\(yours) against \(competitors[0].name)"
                : "\(yours) against \(theirs) rivals"
        }
    }

    /// The one line the forward read is for. Nil where the studio has not
    /// earned it — the absence is the mechanic, so the view says so
    /// instead of hiding the row.
    func forwardRead(driftSigma: Double) -> String? {
        guard let forecast else { return nil }
        let weeks = forecast.weeksAhead
        let band = "\(MarketFormat.multiplier(forecast.low))–\(MarketFormat.multiplier(forecast.high))"
        let lean = switch forecast.lean(threshold: driftSigma / 2) {
        case .warming: "with room to climb"
        case .cooling: "with more room to fall than to climb"
        case .steady: "either way"
        }
        let jump = Int((forecast.jumpChance * 100).rounded())
        return "\(weeks) weeks out: \(band) \(lean). "
            + "\(jump)% chance a boom or crash lands in that window."
    }

    var accessibilitySummary: String {
        var parts = ["\(topic.name), standing \(standingLabel) of \(Int(maxStanding)), \(tier.lowercased())"]
        parts.append("demand \(market.multiplierLabel)")
        parts.append(fieldLabel.lowercased())
        return parts.joined(separator: ", ")
    }
}

// MARK: - Bands and directions

enum DemandBand {
    case hot, steady, cold

    var label: String {
        switch self {
        case .hot: "HOT"
        case .steady: "STEADY"
        case .cold: "COLD"
        }
    }

    /// Tint for the multiplier text and sparkline.
    var tint: Color {
        switch self {
        case .hot: Theme.positiveCash
        case .steady: Theme.accent
        case .cold: Theme.negativeCash
        }
    }

    /// Tint for the multiplier figure in rows; steady stays primary so the
    /// column reads calmly.
    var figureTint: Color {
        switch self {
        case .hot: Theme.positiveCash
        case .steady: .primary
        case .cold: Theme.negativeCash
        }
    }

    var systemImage: String {
        switch self {
        case .hot: "flame.fill"
        case .steady: "equal.circle"
        case .cold: "snowflake"
        }
    }
}

enum TrendDirection {
    case rising, falling, flat

    var systemImage: String {
        switch self {
        case .rising: "arrow.up.right"
        case .falling: "arrow.down.right"
        case .flat: "arrow.right"
        }
    }

    var tint: Color {
        switch self {
        case .rising: Theme.positiveCash
        case .falling: Theme.negativeCash
        case .flat: .secondary
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .rising: "rising"
        case .falling: "falling"
        case .flat: "flat"
        }
    }
}

// MARK: - Position

struct MarketPosition {
    /// Revenue posted in the last `positionWindowWeeks` weeks.
    let recentRevenue: Int
    /// Revenue posted in the window before that.
    let previousRevenue: Int
    /// The top earner, by window revenue (or lifetime when the window is empty).
    let bestSeller: (product: Product, revenue: Int)?
    let bestSellerIsLifetime: Bool

    /// Percent change vs the previous window; nil when there is no base.
    var changePercent: Double? {
        guard previousRevenue > 0 else { return nil }
        return Double(recentRevenue - previousRevenue) / Double(previousRevenue) * 100
    }
}

// MARK: - Formatting

enum MarketFormat {
    /// "×1.23"
    static func multiplier(_ value: Double) -> String {
        String(format: "×%.2f", value)
    }

    /// "+12%" / "-4%" / "0%"
    static func signedPercent(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        return rounded > 0 ? "+\(rounded)%" : "\(rounded)%"
    }

    /// "+0.04" / "-0.12"
    static func signedDelta(_ value: Double) -> String {
        String(format: "%+.2f", value)
    }

    /// "$1.99"
    static func price(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }

    /// "12,000" — whole units with thousands grouping (reuses the money
    /// formatter's grouping so every figure in the app groups the same way).
    static func units(_ value: Double) -> String {
        Int(max(0, value).rounded()).money.replacingOccurrences(of: "$", with: "")
    }

    /// Compact date label for any day, e.g. "W12 · Y2". Mirrors the
    /// engine's calendar: 364-day years of 52 seven-day weeks.
    static func dateLabel(forDay day: Int) -> String {
        let year = day / MarketAnalysis.daysPerYear + 1
        let week = (day % MarketAnalysis.daysPerYear) / MarketAnalysis.daysPerWeek + 1
        return "W\(week) · Y\(year)"
    }
}

extension MarketEvent.Kind {
    var title: String {
        switch self {
        case .boom: "Boom"
        case .crash: "Crash"
        }
    }

    var systemImage: String {
        switch self {
        case .boom: "arrow.up"
        case .crash: "arrow.down"
        }
    }

    var tint: Color {
        switch self {
        case .boom: Theme.positiveCash
        case .crash: Theme.negativeCash
        }
    }
}
