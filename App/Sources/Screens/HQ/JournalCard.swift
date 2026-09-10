import SwiftUI
import TycoonContent
import TycoonEngine

/// One journal line: an event plus everything the UI needs to draw it.
struct JournalEntry: Identifiable {
    /// Position in the event log — stable, and unique even when two
    /// identical events land on the same day.
    let id: Int
    let event: GameEvent
    let line: EventLine
    let category: JournalCategory
    let severity: EventSeverity
    var day: Int { line.day }
    var week: Int { day / 7 + 1 }
}

/// Turns the engine's event log into journal entries, newest first.
enum JournalBuilder {
    /// - Parameters:
    ///   - state: the live state.
    ///   - copy: the shared event-to-English mapper.
    ///   - limit: how many of the newest events to take.
    static func entries(
        state: GameState,
        copy: EventCopy,
        limit: Int = 400
    ) -> [JournalEntry] {
        let log = state.eventLog
        let start = max(0, log.count - limit)
        return (start..<log.count).reversed().map { index in
            let event = log[index]
            return JournalEntry(
                id: index,
                event: event,
                line: copy.line(for: event),
                category: copy.category(of: event),
                severity: event.severity
            )
        }
    }

    /// Collapses the run of weekend/instant-activity lines in a week into
    /// one summary line, so a year of "Weekend: Rest" doesn't bury the
    /// story. Entries must be newest first.
    static func collapsingRoutine(_ entries: [JournalEntry]) -> [JournalRow] {
        var rows: [JournalRow] = []
        var routineByWeek: [Int: [JournalEntry]] = [:]
        var weekOrder: [Int] = []

        for entry in entries {
            if isRoutine(entry.event) {
                if routineByWeek[entry.week] == nil {
                    routineByWeek[entry.week] = []
                    weekOrder.append(entry.week)
                    rows.append(.routinePlaceholder(week: entry.week))
                }
                routineByWeek[entry.week]?.append(entry)
            } else {
                rows.append(.entry(entry))
            }
        }

        return rows.map { row in
            if case .routinePlaceholder(let week) = row, let bundled = routineByWeek[week] {
                return .routine(week: week, entries: bundled)
            }
            return row
        }
    }

    /// Weekends and same-day activities: real, but not news.
    private static func isRoutine(_ event: GameEvent) -> Bool {
        switch event {
        case .weekendSpent, .instantActivityDone, .itemPurchased:
            true
        // MARK: Iteration 10 — M6 (the bug hunt)
        //
        // Three squashes a day is fifteen lines a week. Every one of them
        // is real and none of them is news, which is exactly what the
        // routine fold is for: a week of hunting reads as one line in the
        // diary and opens to the lot.
        case .bugSquashed:
            true
        // MARK: Iteration 11 — N4 (fame and the feed)
        //
        // A post a day is seven diary lines a week and none of them is
        // news — until one gets away, and a viral post is not routine by
        // anybody's definition. The routine fold collapses the habit and
        // leaves the accidents standing.
        case .famePosted(_, _, let viral, _, _):
            !viral
        // MARK: end of Iteration 11 — N4
        default:
            false
        }
    }
}

/// A row in the journal: either one event, or a week's routine collapsed.
enum JournalRow: Identifiable {
    case entry(JournalEntry)
    case routine(week: Int, entries: [JournalEntry])
    /// Internal marker used while collapsing; never rendered.
    case routinePlaceholder(week: Int)

    var id: String {
        switch self {
        case .entry(let entry): "e\(entry.id)"
        case .routine(let week, _), .routinePlaceholder(let week): "r\(week)"
        }
    }

    var week: Int {
        switch self {
        case .entry(let entry): entry.week
        case .routine(let week, _), .routinePlaceholder(let week): week
        }
    }
}

/// The founder's diary on HQ: the last few weeks, newest first, grouped by
/// week, with a link to the full journal.
///
/// Replaces the old flat activity feed — the same events, but ordered the
/// way the player remembers them.
struct JournalCard: View {
    let engine: GameEngine

    /// Entries shown on the dashboard before "See all".
    private static let previewCount = 6

    private var copy: EventCopy {
        EventCopy(state: engine.state, content: engine.content, balance: engine.balance)
    }

    private var rows: [JournalRow] {
        Array(
            JournalBuilder
                .collapsingRoutine(JournalBuilder.entries(state: engine.state, copy: copy, limit: 40))
                .prefix(Self.previewCount)
        )
    }

    var body: some View {
        CardView("Journal", systemImage: "book.closed.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                if rows.isEmpty {
                    Text("All quiet. Time to build something.")
                        .emptySectionText()
                } else {
                    ForEach(groupedByWeek(rows), id: \.week) { group in
                        WeekGroup(
                            week: group.week,
                            rows: group.rows,
                            onOpenReport: reportOpener(for: group.week)
                        )
                    }
                }
                HStack(spacing: Theme.Spacing.lg) {
                    if !rows.isEmpty {
                        NavigationLink {
                            JournalScreen(engine: engine)
                        } label: {
                            Label("See all", systemImage: "chevron.right")
                                .font(.footnote.weight(.semibold))
                        }
                        .buttonStyle(.borderless)
                    }
                    Spacer(minLength: 0)
                    // The same weeks, set as a front page (U2).
                    NavigationLink(value: StoryDestination.newspaper) {
                        Label("Front page", systemImage: "newspaper.fill")
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.borderless)
                    .accessibilityHint("Opens this week's newspaper")
                }
                .padding(.top, Theme.Spacing.xs)
            }
        }
    }

    // MARK: V3 (ux: card weights, the Now card)

    /// C10/C11: a closed week's row reopens that week's report. A journal
    /// week N (days 7N−7…7N−1) is the report the shell offered on day 7N,
    /// so it is closed once `day / 7 >= N`; the week in progress has no
    /// report yet and keeps a plain heading.
    private func reportOpener(for week: Int) -> ((Int) -> Void)? {
        // V2: only a week the shell can show draws as a button.
        guard GameShell.shared.canReopenReport(week: week, engine: engine) else { return nil }
        return reopenReport
    }

    /// The presenter is V2's (`AppRootView`'s report region). Until it
    /// lands there is nothing to call, so this is `nil` and every week
    /// heading draws as it always did; V2 replaces the one line below.
    private var reopenReport: ((Int) -> Void)? {
        // Iteration 14 merge: V2's reopen, which shows the week's report as
        // it was built, without resetting the deltas or counting an open.
        { week in _ = GameShell.shared.reopenWeeklyReport(engine: engine, week: week) }
    }

    // MARK: end V3

    private func groupedByWeek(_ rows: [JournalRow]) -> [(week: Int, rows: [JournalRow])] {
        var groups: [(week: Int, rows: [JournalRow])] = []
        for row in rows {
            if groups.last?.week == row.week {
                groups[groups.count - 1].rows.append(row)
            } else {
                groups.append((week: row.week, rows: [row]))
            }
        }
        return groups
    }
}

/// One week's worth of journal rows under a week heading.
struct WeekGroup: View {
    let week: Int
    let rows: [JournalRow]
    // MARK: V3 (ux: card weights, the Now card)
    /// Reopens this week's report. `nil` (the default, and every caller
    /// but HQ's journal card) draws the plain heading.
    var onOpenReport: ((Int) -> Void)? = nil
    // MARK: end V3

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            heading
            ForEach(rows) { row in
                JournalRowView(row: row)
            }
        }
    }

    // MARK: V3 (ux: card weights, the Now card)
    /// The one "Week N" pixel title, drawn plain or inside the report
    /// button — one literal, so the strings audit's pin holds.
    private var weekTitle: some View {
        PixelText(text: "Week \(week)", scale: 2, color: .secondary)
    }

    @ViewBuilder
    private var heading: some View {
        if let onOpenReport {
            Button {
                Haptics.tap()
                onOpenReport(week)
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    weekTitle
                    Spacer(minLength: Theme.Spacing.sm)
                    Text("Report")
                        .font(.footnote.weight(.semibold))
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(Theme.accent)
                .frame(minHeight: 34)
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressableRow)
            .accessibilityLabel("Week \(week) report")
            .accessibilityHint("Opens that week's report again")
        } else {
            weekTitle
                .accessibilityAddTraits(.isHeader)
        }
    }
    // MARK: end V3
}

/// One rendered journal row.
struct JournalRowView: View {
    let row: JournalRow

    var body: some View {
        switch row {
        case .entry(let entry):
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                Image(systemName: entry.line.icon)
                    .font(.caption)
                    .foregroundStyle(entry.line.tint)
                    .frame(width: 18)
                Text(entry.line.message)
                    .font(.subheadline)
                    .fontWeight(entry.severity == .critical ? .semibold : .regular)
                Spacer(minLength: Theme.Spacing.sm)
                Text("D\(entry.day)")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Day \(entry.day). \(entry.line.message)")

        case .routine(_, let entries):
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                Image(systemName: "moon.zzz.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(width: 18)
                Text(summary(of: entries))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)

        case .routinePlaceholder:
            EmptyView()
        }
    }

    /// "Off the clock: date night, a walk, and a new espresso machine."
    private func summary(of entries: [JournalEntry]) -> String {
        // Oldest first reads like a diary entry for the week.
        let pieces = entries.reversed().map { entry -> String in
            entry.line.message
                .replacingOccurrences(of: "Weekend: ", with: "")
                .lowercased()
        }
        let unique = pieces.reduce(into: [String]()) { result, piece in
            if !result.contains(piece) { result.append(piece) }
        }
        switch unique.count {
        case 0: return "A quiet week off the clock."
        case 1: return "Off the clock: \(unique[0])."
        case 2: return "Off the clock: \(unique[0]) and \(unique[1])."
        default:
            let head = unique.dropLast().joined(separator: ", ")
            return "Off the clock: \(head), and \(unique[unique.count - 1])."
        }
    }
}
