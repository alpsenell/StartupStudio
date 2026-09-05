import SwiftUI
import TycoonEngine

/// The end-of-week debrief: what the week cost, what it earned, how the
/// team and the founder are holding up, what happened, and what's coming —
/// with one big button that starts the next week.
///
/// This is the game's retention loop. It never blocks: the clock stays
/// paused behind it and "Next week" resumes at the speed the player was
/// already running.
///
/// For the first eight weeks it also opens itself, which is right for a
/// player learning the loop and an interruption for one who is not. The
/// bottom bar carries the off switch, so nobody has to go and find
/// Settings to stop something that is happening to them right now.
struct WeeklyReportSheet: View {
    let engine: GameEngine
    let report: WeeklyReport
    /// Speed to resume at when the player taps "Next week".
    let resumeSpeed: SimSpeed
    var onRoute: ((Route) -> Void)?

    @Environment(\.dismiss) private var dismiss

    private var copy: EventCopy {
        EventCopy(state: engine.state, content: engine.content, balance: engine.balance)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    headline
                    cashCard
                    if !report.productSales.isEmpty { salesCard }
                    if !engine.state.employees.filter({ !$0.isFounder }).isEmpty { teamCard }
                    founderCard
                    if !report.events.isEmpty { eventsCard }
                    outlookCard
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle("Week \(report.weekIndex)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                WeeklyReportBottomBar(nextWeekIndex: report.weekIndex + 1) {
                    Sounds.play(.weekEnd)
                    engine.setSpeed(resumeSpeed == .paused ? .x1 : resumeSpeed)
                    dismiss()
                }
            }
        }
    }

    // MARK: - Headline

    private var headline: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                PixelText(
                    text: "Week \(report.weekIndex)",
                    scale: 3,
                    color: Theme.pixelAccent,
                    shadow: true
                )
                Text("\(report.calendar.longLabel) · \(report.calendar.season.displayName)")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Theme.pixelInk.opacity(0.7))
                HStack(spacing: Theme.Spacing.sm) {
                    PixelText(
                        text: report.net >= 0 ? "+\(report.net.money)" : report.net.money,
                        scale: 3,
                        color: report.net >= 0 ? Theme.positiveCash : Theme.negativeCash
                    )
                    Text("this week")
                        .font(.footnote)
                        .foregroundStyle(Theme.pixelInk.opacity(0.7))
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Week \(report.weekIndex), \(report.calendar.longLabel). Net \(report.net.money)."
        )
    }

    // MARK: - Cash

    private var cashCard: some View {
        CardView(String(localized: "Cash", comment: "One word, used both for the money-sheet row showing cash on hand and for the weekly report card about money in and out"), systemImage: "dollarsign.circle.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .top, spacing: Theme.Spacing.xl) {
                    ReportStat(label: String(localized: "In", comment: "Weekly report figure: money received this week"), value: report.income.money, tint: Theme.positiveCash)
                    ReportStat(label: String(localized: "Out", comment: "Weekly report figure: money spent this week"), value: report.expenses.money, tint: Theme.negativeCash)
                    ReportStat(label: String(localized: "On hand", comment: "Weekly report figure: cash left"), value: report.cash.money)
                }

                if !report.incomeByCategory.isEmpty {
                    BreakdownRows(title: String(localized: "Income", comment: "Weekly report breakdown heading: money in, by category"), totals: report.incomeByCategory, tint: Theme.positiveCash)
                }
                if !report.expensesByCategory.isEmpty {
                    BreakdownRows(title: String(localized: "Expenses", comment: "Weekly report breakdown heading: money out, by category"), totals: report.expensesByCategory, tint: Theme.negativeCash)
                }
            }
        }
    }

    // MARK: - Sales

    private var salesCard: some View {
        CardView("Products on the market", systemImage: "shippingbox.fill") {
            VStack(spacing: Theme.Spacing.md) {
                ForEach(report.productSales) { sales in
                    Button {
                        Haptics.tap()
                        dismiss()
                        onRoute?(.product(sales.id))
                    } label: {
                        HStack(alignment: .center, spacing: Theme.Spacing.md) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sales.name)
                                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                    .foregroundStyle(.primary)
                                if sales.isSubscription {
                                    Text("\(sales.subscribers.formatted(.number.locale(Theme.gameLocale))) subscribers")
                                        .font(Theme.Typography.number(.caption, weight: .regular))
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("\(sales.units.formatted(.number.locale(Theme.gameLocale))) sold")
                                        .font(Theme.Typography.number(.caption, weight: .regular))
                                        .foregroundStyle(.secondary)
                                }
                                if sales.liveBugs > 0 {
                                    Label("\(sales.liveBugs) live bug\(sales.liveBugs == 1 ? "" : "s")",
                                          systemImage: "ladybug.fill")
                                        .font(.caption2)
                                        .foregroundStyle(Theme.warning)
                                }
                            }
                            Spacer(minLength: Theme.Spacing.sm)
                            Sparkline(values: sales.history, tint: Theme.accent)
                                .frame(width: 64, height: 24)
                            Text(sales.revenue.money)
                                .font(Theme.Typography.number(.subheadline, weight: .bold))
                                .foregroundStyle(Theme.positiveCash)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(
                        "\(sales.name), \(sales.revenue.money) this week"
                    )
                }
            }
        }
    }

    // MARK: - Team

    private var teamCard: some View {
        CardView(String(localized: "Team", comment: "Weekly report card: morale and who is unhappy"), systemImage: "person.2.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .top, spacing: Theme.Spacing.xl) {
                    ReportStat(
                        label: String(localized: "Average morale", comment: "Weekly report figure: the team average morale out of 100"),
                        value: report.averageMorale.formatted(.number.precision(.fractionLength(0)).locale(Theme.gameLocale)),
                        tint: moraleTint
                    )
                    ReportStat(
                        label: String(localized: "Change", comment: "Weekly report figure: how much average morale moved this week"),
                        value: signed(report.moraleDelta),
                        tint: report.moraleDelta >= 0 ? Theme.positiveCash : Theme.negativeCash
                    )
                }
                if report.unhappy.isEmpty {
                    Text("Nobody is close to walking out.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(report.unhappy) { person in
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "exclamationmark.bubble.fill")
                                .font(.caption)
                                .foregroundStyle(Theme.warning)
                            Text("\(person.name) is unhappy")
                                .font(.footnote)
                            Spacer(minLength: 0)
                            Text(person.morale.formatted(.number.precision(.fractionLength(0)).locale(Theme.gameLocale)))
                                .font(Theme.Typography.number(.footnote))
                                .foregroundStyle(Theme.negativeCash)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private var moraleTint: Color {
        if report.averageMorale >= 60 { Theme.positiveCash }
        else if report.averageMorale >= 40 { Theme.warning }
        else { Theme.negativeCash }
    }

    // MARK: - Founder

    private var founderCard: some View {
        CardView(String(localized: "You", comment: "Card and step heading for the founder as a person - their money, their meters, their name"), systemImage: "person.fill") {
            HStack(spacing: Theme.Spacing.lg) {
                MeterDelta(label: String(localized: "Energy", comment: "Founder meter: how rested the founder is"), value: report.founderMeters.energy, delta: report.meterDeltas.energy)
                MeterDelta(label: String(localized: "Health", comment: "Founder meter: physical health"), value: report.founderMeters.health, delta: report.meterDeltas.health)
                MeterDelta(label: String(localized: "Mood", comment: "Founder meter: how the founder feels"), value: report.founderMeters.mood, delta: report.meterDeltas.mood)
                MeterDelta(
                    label: String(localized: "People", comment: "Founder meter: how the relationships are holding up"),
                    value: report.founderMeters.relationships,
                    delta: report.meterDeltas.relationships
                )
            }
        }
    }

    // MARK: - Events

    private var eventsCard: some View {
        CardView("What happened", systemImage: "book.closed.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                ForEach(Array(report.events.prefix(8).enumerated()), id: \.offset) { _, event in
                    let line = copy.line(for: event)
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                        Image(systemName: line.icon)
                            .font(.caption)
                            .foregroundStyle(line.tint)
                        Text(line.message)
                            .font(.subheadline)
                        Spacer(minLength: 0)
                    }
                    .accessibilityElement(children: .combine)
                }
                if report.events.count > 8 {
                    Text("+\(report.events.count - 8) more in the journal")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Outlook

    private var outlookCard: some View {
        CardView("Next week", systemImage: "calendar.badge.clock") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if let next = report.nextAction {
                    // The one line a first-week player needs, as a button
                    // to the screen it happens on.
                    Button {
                        Haptics.tap()
                        onRoute?(next.route)
                        dismiss()
                    } label: {
                        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Theme.accent)
                                .frame(width: 20)
                            Text("Do this next: \(next.text)")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressableRow)
                    Divider()
                }
                OutlookRow(
                    icon: "flame.fill",
                    text: runwayText,
                    tint: (report.runwayWeeks ?? 99) <= 4 ? Theme.warning : .secondary
                )
                ForEach(report.deadlines) { deadline in
                    OutlookRow(
                        icon: "briefcase.fill",
                        text: deadline.daysLeft <= 0
                            ? "\(deadline.clientName) is overdue"
                            : "\(deadline.clientName) due in \(deadline.daysLeft) day\(deadline.daysLeft == 1 ? "" : "s")",
                        tint: deadline.daysLeft <= 3 ? Theme.warning : .secondary
                    )
                }
                if report.campaignsEnding > 0 {
                    OutlookRow(
                        icon: "megaphone.fill",
                        text: "\(report.campaignsEnding) campaign\(report.campaignsEnding == 1 ? "" : "s") ending",
                        tint: .secondary
                    )
                }
                if report.deadlines.isEmpty, report.campaignsEnding == 0 {
                    OutlookRow(icon: "checkmark.circle.fill", text: "Nothing is due. Build something.", tint: .secondary)
                }
            }
        }
    }

    private var runwayText: String {
        guard let weeks = report.runwayWeeks else {
            return report.cash < 0
                ? String(localized: "You are in the red — every week digs deeper", comment: "Weekly report runway line when cash is negative")
                : String(localized: "Burn is covered", comment: "Weekly report runway line when income covers the spend")
        }
        return "\(weeks) week\(weeks == 1 ? "" : "s") of runway at \(report.weeklyBurn.money)/wk"
    }

    private func signed(_ value: Double) -> String {
        let rounded = value.rounded()
        return (rounded >= 0 ? "+" : "") + rounded.formatted(.number.precision(.fractionLength(0)).locale(Theme.gameLocale))
    }
}

// MARK: - Bottom bar

/// The sheet's bottom bar: the button that starts the next week, and — on
/// the thing that just opened itself — the off switch for that.
///
/// Its own view for two reasons: `ImageRenderer` cannot draw a
/// `NavigationStack`'s safe-area inset, so this is the only way the bar
/// gets a review snapshot; and the auto-open state belongs with the
/// control that owns it.
struct WeeklyReportBottomBar: View {
    /// The week the button starts, for the accessibility label.
    let nextWeekIndex: Int
    let onNextWeek: () -> Void

    /// Mirrors `GameSettings.weeklyReportAuto` so the row redraws when it
    /// is flipped. Re-read on appear: this view's state outlives one
    /// presentation, and Settings can change the value between weeks.
    @State private var opensAutomatically = GameSettings.weeklyReportAuto

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Button {
                Haptics.commit()
                onNextWeek()
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Text("Next week")
                        .font(.system(.headline, design: .rounded))
                    Image(systemName: "play.fill")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.sm)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .accessibilityLabel("Start week \(nextWeekIndex)")

            autoOpenButton
        }
        .padding(Theme.Spacing.lg)
        .background(.bar)
        .onAppear { opensAutomatically = GameSettings.weeklyReportAuto }
    }

    /// Writes to the same `GameSettings` key the Settings sheet does, so
    /// the two always agree — and so nobody has to go and find Settings to
    /// stop something that is happening to them right now.
    private var autoOpenButton: some View {
        Button {
            Haptics.tap()
            opensAutomatically.toggle()
            GameSettings.weeklyReportAuto = opensAutomatically
        } label: {
            Label(
                opensAutomatically
                    ? "Don't open this automatically"
                    : "Open this automatically again",
                systemImage: opensAutomatically ? "bell.slash" : "bell"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.vertical, Theme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressableRow)
        .accessibilityHint(
            opensAutomatically
                ? "Stops the weekly report opening on its own. The week chip in the HUD still opens it."
                : "The weekly report will open on its own at the end of each week again."
        )
    }
}

// MARK: - Pieces

private struct ReportStat: View {
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

private struct BreakdownRows: View {
    let title: String
    let totals: [WeeklyReport.CategoryTotal]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(totals) { total in
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: total.category.systemImage)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 18)
                    Text(total.category.displayName)
                        .font(.footnote)
                    Spacer(minLength: 0)
                    Text(total.amount.money)
                        .font(Theme.Typography.number(.footnote))
                        .foregroundStyle(tint)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(total.category.displayName) \(total.amount.money)")
            }
        }
    }
}

private struct OutlookRow: View {
    let icon: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(tint)
                .frame(width: 18)
            Text(text)
                .font(.footnote)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A tiny filled line chart for a product's revenue history.
struct Sparkline: View {
    let values: [Int]
    var tint: Color = Theme.accent

    var body: some View {
        GeometryReader { proxy in
            let points = normalizedPoints(in: proxy.size)
            ZStack {
                if points.count >= 2 {
                    Path { path in
                        path.move(to: points[0])
                        for point in points.dropFirst() { path.addLine(to: point) }
                    }
                    .stroke(tint, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
                } else if let single = points.first {
                    Circle()
                        .fill(tint)
                        .frame(width: 3, height: 3)
                        .position(single)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard !values.isEmpty else { return [] }
        let maximum = max(values.max() ?? 1, 1)
        let step = values.count > 1 ? size.width / CGFloat(values.count - 1) : 0
        return values.enumerated().map { index, value in
            CGPoint(
                x: CGFloat(index) * step,
                y: size.height - (CGFloat(value) / CGFloat(maximum)) * size.height
            )
        }
    }
}
