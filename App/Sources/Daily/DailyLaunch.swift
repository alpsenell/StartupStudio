import Foundation
import TycoonEngine

// MARK: Iteration 7 — the daily (R3)

extension DailyChallenge {
    /// The day number a `-autoDaily 20260905` argument names, or `nil` if
    /// it is not eight digits of a real UTC date.
    ///
    /// Pure, so the flag's parsing is tested without launching anything.
    static func dayNumber(fromLaunchArgument argument: String) -> Int? {
        let digits = argument.trimmingCharacters(in: .whitespaces)
        guard digits.count == 8, digits.allSatisfy(\.isNumber),
              let value = Int(digits)
        else { return nil }
        var components = DateComponents()
        components.year = value / 10_000
        components.month = (value / 100) % 100
        components.day = value % 100
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        guard let date = calendar.date(from: components),
              calendar.dateComponents([.year, .month, .day], from: date) == components
        else { return nil }
        return dayNumber(for: date)
    }

    /// The challenge a `-autoDaily` argument names.
    static func fromLaunchArgument(_ argument: String) -> DailyChallenge? {
        dayNumber(fromLaunchArgument: argument).map(forDay)
    }

    /// The UTC calendar day this challenge is for.
    var date: Date {
        Self.epoch.addingTimeInterval(TimeInterval(day) * 86_400)
    }

    /// "Saturday, 5 September 2026" — the date the world is playing.
    var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Theme.gameLocale
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "EEEE, d MMMM yyyy"
        return formatter.string(from: date)
    }
}

extension DebugLaunch {
    /// `-autoDaily <yyyymmdd>`: the challenge a headless pass wants the
    /// title screen to open on (R3). `nil` in a release build, without the
    /// flag, or when the date does not parse.
    static var launchDailyChallenge: DailyChallenge? {
        launchDailyDay.flatMap(DailyChallenge.fromLaunchArgument)
    }

    /// `-autoDaily <day> -autoSpeed x4`: play the day through rather than
    /// stopping on its card, so a screenshot pass can reach the result.
    static var playsDailyAutomatically: Bool {
        #if DEBUG
        return launchDailyChallenge != nil
            && ProcessInfo.processInfo.arguments.contains("-autoSpeed")
        #else
        return false
        #endif
    }
}
