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
            if rows.isEmpty {
                Text("All quiet. Time to build something.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, Theme.Spacing.sm)
            } else {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    ForEach(groupedByWeek(rows), id: \.week) { group in
                        WeekGroup(week: group.week, rows: group.rows)
                    }
                    NavigationLink {
                        JournalScreen(engine: engine)
                    } label: {
                        Label("See all", systemImage: "chevron.right")
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.borderless)
                    .padding(.top, Theme.Spacing.xs)
                }
            }
        }
    }

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

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            PixelText(text: "Week \(week)", scale: 2, color: .secondary)
                .accessibilityAddTraits(.isHeader)
            ForEach(rows) { row in
                JournalRowView(row: row)
            }
        }
    }
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
