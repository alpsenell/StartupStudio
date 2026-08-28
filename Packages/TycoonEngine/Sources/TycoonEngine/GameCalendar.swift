import Foundation

/// The game's own calendar. The world has run on "W3 · Y1" since launch,
/// which tells the player nothing about *when* they are — no months, no
/// seasons, no sense of a quarter closing.
///
/// The year is the engine's 364 days laid out as twelve months in a
/// repeating 30 / 30 / 31 pattern, so every quarter is exactly 91 days and
/// every month starts on the same weekday it did last year. Named
/// `GameCalendar` rather than `Calendar` so it never shadows Foundation's
/// inside the engine; `GameState.calendar` is the accessor everything reads.
public struct GameCalendar: Equatable, Sendable {
    /// 1-based game year.
    public let year: Int
    /// 0-based month, 0 = January.
    public let monthIndex: Int
    /// 1-based day within the month.
    public let dayOfMonth: Int
    /// 1-based day within the week (1 = Monday … 7 = Sunday).
    public let dayOfWeek: Int
    /// 1-based week within the year, 1...52.
    public let weekOfYear: Int
    /// 1-based quarter, 1...4.
    public let quarter: Int

    /// Days in each month: 30 / 30 / 31, four times over — 364 days, 91 to
    /// the quarter.
    public static let monthLengths = [30, 30, 31, 30, 30, 31, 30, 30, 31, 30, 30, 31]

    public static let monthNames = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December",
    ]

    public static let shortMonthNames = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ]

    public var monthName: String { Self.monthNames[monthIndex] }
    public var shortMonthName: String { Self.shortMonthNames[monthIndex] }

    /// Saturday and Sunday — the two days the founder's weekend plan
    /// resolves across.
    public var isWeekend: Bool { dayOfWeek >= 6 }

    public var season: Season {
        switch monthIndex {
        case 11, 0, 1: .winter
        case 2, 3, 4: .spring
        case 5, 6, 7: .summer
        default: .autumn
        }
    }

    /// A compact label, e.g. "12 Mar · Y2".
    public var shortLabel: String { "\(dayOfMonth) \(shortMonthName) · Y\(year)" }

    /// The quarter label the finance screens use, e.g. "Q3 Y2".
    public var quarterLabel: String { "Q\(quarter) Y\(year)" }

    /// Builds the calendar for an absolute day count from founding (day 0
    /// is 1 January of year 1). Negative days clamp to the first day.
    public init(day: Int) {
        let day = max(0, day)
        let daysPerYear = Self.monthLengths.reduce(0, +)
        year = day / daysPerYear + 1
        let dayOfYear = day % daysPerYear
        var remaining = dayOfYear
        var month = 0
        while month < Self.monthLengths.count - 1, remaining >= Self.monthLengths[month] {
            remaining -= Self.monthLengths[month]
            month += 1
        }
        monthIndex = month
        dayOfMonth = remaining + 1
        dayOfWeek = day % 7 + 1
        weekOfYear = dayOfYear / 7 + 1
        quarter = month / 3 + 1
    }
}

/// The four seasons, for the scene's light and the world's mood.
public enum Season: String, Codable, Equatable, Sendable, CaseIterable {
    case winter, spring, summer, autumn

    public var displayName: String {
        switch self {
        case .winter: "Winter"
        case .spring: "Spring"
        case .summer: "Summer"
        case .autumn: "Autumn"
        }
    }
}

extension GameState {
    /// Today, on the game's calendar: month, day of the month, quarter,
    /// weekend, season. Derived from `day` — nothing is stored.
    public var calendar: GameCalendar { GameCalendar(day: day) }
}
