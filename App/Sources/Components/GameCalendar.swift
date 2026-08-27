import Foundation
import TycoonEngine

/// The world's clock, derived from `GameState.day`.
///
/// The engine counts in days and weeks (364-day years, 7-day weeks); this
/// turns that into the months, quarters, weekends and seasons the HUD and
/// the weekly report speak in. Twelve months over 364 days on a 30/30/31
/// pattern, so every quarter is exactly 91 days and week and month
/// boundaries never drift apart across a year.
///
/// It is a pure function of `day` — no `Date`, no locale — so a save shows
/// the same date on every device.
struct GameCalendar: Equatable {
    /// 0-based month of the year.
    let monthIndex: Int
    /// 1-based day within the month.
    let dayOfMonth: Int
    /// 1-based quarter of the year.
    let quarter: Int
    /// 1-based week of the year, matching `GameState.weekOfYear`.
    let weekOfYear: Int
    /// 1-based year, matching `GameState.year`.
    let year: Int
    /// 1 = the first working day of the week, 7 = the last.
    let dayOfWeek: Int

    /// Days in each month, repeating 30/30/31 per quarter.
    static let monthLengths = [30, 30, 31, 30, 30, 31, 30, 30, 31, 30, 30, 31]

    static let monthNames = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ]

    /// Short month name, "Jan"…"Dec".
    var monthName: String { Self.monthNames[monthIndex] }

    /// Saturday and Sunday of the game's week.
    var isWeekend: Bool { dayOfWeek >= 6 }

    /// The season the month falls in (northern hemisphere), used for the
    /// scene ambience and the report's flavor line.
    var season: Season {
        switch monthIndex {
        case 11, 0, 1: .winter
        case 2, 3, 4: .spring
        case 5, 6, 7: .summer
        default: .autumn
        }
    }

    enum Season: String, CaseIterable, Sendable {
        case winter, spring, summer, autumn

        var displayName: String { rawValue.capitalized }

        var systemImage: String {
            switch self {
            case .winter: "snowflake"
            case .spring: "leaf.fill"
            case .summer: "sun.max.fill"
            case .autumn: "wind"
            }
        }
    }

    /// The HUD label: "Mar W2 · Y1".
    var hudLabel: String { "\(monthName) W\(weekOfYear) · Y\(year)" }

    /// The long form used in sheets: "Mar 12, Year 1".
    var longLabel: String { "\(monthName) \(dayOfMonth), Year \(year)" }

    /// Builds the calendar for an absolute game day (day 0 = Jan 1, Y1).
    init(day: Int) {
        let clamped = max(0, day)
        let dayOfYear = clamped % 364
        year = clamped / 364 + 1
        weekOfYear = dayOfYear / 7 + 1
        dayOfWeek = clamped % 7 + 1

        var remaining = dayOfYear
        var month = 0
        while month < Self.monthLengths.count - 1, remaining >= Self.monthLengths[month] {
            remaining -= Self.monthLengths[month]
            month += 1
        }
        monthIndex = month
        dayOfMonth = remaining + 1
        quarter = month / 3 + 1
    }
}

extension GameState {
    /// This state's calendar. Reads `day` only, so it is safe on any save.
    var gameCalendar: GameCalendar { GameCalendar(day: day) }
}
