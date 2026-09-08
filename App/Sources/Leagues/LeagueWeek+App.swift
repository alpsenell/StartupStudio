import SwiftUI
import TycoonEngine

// MARK: Iteration 10 — M4 (leagues)

extension LeagueWeek {
    /// "5 – 11 January 2026", the week everybody in your tier is playing.
    var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.locale = Theme.gameLocale
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "d MMM"
        let closing = DateFormatter()
        closing.locale = Theme.gameLocale
        closing.timeZone = TimeZone(identifier: "UTC")
        closing.dateFormat = "d MMM yyyy"
        return "\(formatter.string(from: firstDay)) – \(closing.string(from: lastDay))"
    }

    /// "Closes Monday" / "2 days left".
    func closingText(now: Date = Date()) -> String {
        let left = daysLeft(now: now)
        return switch left {
        case ...0: "The week has closed."
        case 1: "Last day."
        default: "\(left) days left."
        }
    }

    /// The week a `-autoLeague 20260907` argument names, or `nil` when it
    /// is not eight digits of a real UTC date.
    static func fromLaunchArgument(_ argument: String) -> LeagueWeek? {
        DailyChallenge.dayNumber(fromLaunchArgument: argument)
            .map { forWeek(weekNumber(forDay: $0)) }
    }
}

extension LeagueTier {
    /// The SF symbol a row and a card wear. The rungs read as one set.
    var systemImageName: String {
        switch self {
        case .bronze: "3.circle"
        case .silver: "2.circle"
        case .gold: "1.circle"
        case .founders: "crown"
        }
    }

    /// The tier's colour, from the palette the rest of the game uses.
    var tint: Color {
        switch self {
        case .bronze: Theme.pixelInk.opacity(0.65)
        case .silver: Theme.accent.opacity(0.75)
        case .gold: Theme.pixelAccent
        case .founders: Theme.positiveCash
        }
    }
}

extension LeagueOutcome {
    var systemImageName: String {
        switch self {
        case .promoted: "arrow.up.circle.fill"
        case .held: "equal.circle.fill"
        case .relegated: "arrow.down.circle.fill"
        case .unplaced: "questionmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .promoted: Theme.positiveCash
        case .held: Theme.accent
        case .relegated: Theme.negativeCash
        case .unplaced: Theme.pixelInk.opacity(0.6)
        }
    }
}
