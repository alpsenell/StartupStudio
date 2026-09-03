import SwiftUI
import TycoonEngine

/// The fortnight: fourteen day columns across two rows, every dated thing
/// under the day it lands on, and each row a tap away from the screen that
/// answers it.
///
/// The grid starts at *today* rather than at a Monday. A calendar that
/// begins on a weekday the player is not on would spend its first cells on
/// days that have already gone; the question this screen answers is "what
/// is coming", so the first cell is tonight.
struct AgendaScreen: View {
    let engine: GameEngine

    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            AgendaContent(
                day: engine.state.day,
                items: Agenda.items(
                    in: engine.state, balance: engine.balance, content: engine.content
                ),
                freeEvenings: Agenda.freeEveningDays(in: engine.state, balance: engine.balance),
                eveningsLeft: engine.state.eveningsLeftThisWeek(engine.balance),
                eveningsTotal: engine.balance.life.evenings(for: engine.state.life.schedule)
            ) { route in
                Haptics.tap()
                dismiss()
                router.go(route)
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.screenBackground)
        .navigationTitle("The fortnight")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The agenda's content, free of the scroll view and the engine so the
/// snapshot tests can render it directly (an `ImageRenderer` over a
/// `ScrollView` renders a blank PNG).
struct AgendaContent: View {
    /// Today, as an absolute game day.
    let day: Int
    let items: [AgendaItem]
    /// The days that still have an evening in them.
    let freeEvenings: Set<Int>
    /// The week's evening budget, for the caption under the grid.
    var eveningsLeft: Int?
    var eveningsTotal: Int?
    let onRoute: (Route) -> Void

    /// The fourteen days, each with whatever falls on it.
    private var columns: [(day: Int, items: [AgendaItem])] {
        Agenda.days(from: day).map { day in
            (day, items.filter { $0.day == day })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            grid
            if items.isEmpty {
                CardView("Nothing dated", systemImage: "calendar") {
                    Text("Two clear weeks. Nothing is due, nobody is waiting, and the evenings are yours.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(columns.filter { !$0.items.isEmpty }, id: \.day) { column in
                    daySection(column.day, items: column.items)
                }
            }
        }
    }

    // MARK: - The grid

    private var grid: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: Theme.Spacing.xs),
                    count: 7
                ),
                spacing: Theme.Spacing.sm
            ) {
                ForEach(columns, id: \.day) { column in
                    cell(column.day, items: column.items)
                }
            }
            if let eveningsLeft, let eveningsTotal, eveningsTotal > 0 {
                Label(
                    "\(eveningsLeft) of \(eveningsTotal) evenings left this week — a dot is a night that is still yours.",
                    systemImage: "moon.stars.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel(
                    "\(eveningsLeft) of \(eveningsTotal) evenings left this week"
                )
            }
        }
        .cardStyle()
    }

    private func cell(_ cellDay: Int, items: [AgendaItem]) -> some View {
        let calendar = GameCalendar(day: cellDay)
        let isToday = cellDay == day
        return VStack(spacing: 3) {
            Text(calendar.weekdayInitial)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(calendar.isWeekend ? Theme.accent : .secondary)
            Text(calendar.dayOfMonth.formatted(.number.locale(Theme.gameLocale)))
                .font(Theme.Typography.number(.subheadline, weight: .semibold))
                .foregroundStyle(isToday ? Theme.ink(on: Theme.accent) : .primary)
                .frame(width: 24, height: 24)
                .background(isToday ? Theme.accent : .clear, in: Circle())
            // A dot per thing, up to three, in the thing's own tint.
            HStack(spacing: 2) {
                ForEach(items.prefix(3)) { item in
                    Circle()
                        .fill(item.tint)
                        .frame(width: 5, height: 5)
                }
                if items.isEmpty {
                    Circle().fill(.clear).frame(width: 5, height: 5)
                }
            }
            // The evening pip: the night is still the founder's.
            Circle()
                .strokeBorder(Theme.accent.opacity(0.55), lineWidth: 1)
                .background(
                    Circle().fill(freeEvenings.contains(cellDay) ? Theme.accent : .clear)
                )
                .frame(width: 6, height: 6)
                .opacity(freeEvenings.contains(cellDay) ? 1 : 0.25)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xs)
        .background(
            isToday ? Theme.accent.opacity(0.08) : .clear,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cellLabel(cellDay, calendar: calendar, items: items))
    }

    private func cellLabel(_ cellDay: Int, calendar: GameCalendar, items: [AgendaItem]) -> String {
        var parts = [cellDay == day ? "Today" : "\(calendar.weekdayName) \(calendar.shortMonthName) \(calendar.dayOfMonth)"]
        parts.append(items.isEmpty ? "nothing dated" : "\(items.count) thing\(items.count == 1 ? "" : "s")")
        if freeEvenings.contains(cellDay) { parts.append("evening free") }
        return parts.joined(separator: ", ")
    }

    // MARK: - The day's rows

    private func daySection(_ sectionDay: Int, items: [AgendaItem]) -> some View {
        CardView(dayTitle(sectionDay), systemImage: sectionDay == day ? "sun.max.fill" : "calendar") {
            VStack(spacing: 0) {
                ForEach(items) { item in
                    AgendaRow(item: item) { onRoute(item.route) }
                    if item.id != items.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    /// "Today", "Tomorrow", then "Thursday 14 Mar".
    private func dayTitle(_ sectionDay: Int) -> String {
        switch sectionDay - day {
        case 0: "Today"
        case 1: "Tomorrow"
        default: {
            let calendar = GameCalendar(day: sectionDay)
            return "\(calendar.weekdayName) \(calendar.dayOfMonth) \(calendar.shortMonthName)"
        }()
        }
    }
}

/// One dated thing, as a row that goes somewhere.
struct AgendaRow: View {
    let item: AgendaItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: item.systemImage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(item.tint)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    if let detail = item.detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: Theme.Spacing.xs)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, Theme.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressableRow)
        .accessibilityLabel([item.title, item.detail].compactMap { $0 }.joined(separator: ". "))
    }
}

// MARK: - Calendar words

extension GameCalendar {
    /// Weekday names, 1 = Monday, matching `dayOfWeek`.
    private static let weekdayNames = [
        "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday",
    ]

    /// "Thursday".
    var weekdayName: String { Self.weekdayNames[max(0, min(6, dayOfWeek - 1))] }

    /// The single letter over a calendar column.
    var weekdayInitial: String { String(weekdayName.prefix(1)) }
}
