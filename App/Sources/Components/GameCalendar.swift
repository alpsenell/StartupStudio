import Foundation
import TycoonEngine

/// App-side vocabulary for the engine's own calendar.
///
/// WS-E shipped a `GameCalendar` struct here as a stand-in until WS-A's
/// landed. They compute the same thing — twelve months over 364 days on a
/// 30/30/31 pattern, so every quarter is exactly 91 days — so at merge the
/// duplicate was deleted and `TycoonEngine.GameCalendar` is now the one
/// clock in the app. What is left here is the two label forms the UI
/// speaks in, which are presentation, not simulation.
extension GameCalendar {
    /// The HUD label: "Mar W2 · Y1".
    var hudLabel: String { String(localized: "\(shortMonthName) W\(weekOfYear) · Y\(year)", comment: "HUD date: month, week of year, game year. Bitmap face - keep to A-Z, digits and the middot") }
    /// The HUD's fallback when the bar is too tight for the month:
    /// "W14 · Y1". The week and the year are what the player steers by.
    var compactHUDLabel: String { String(localized: "W\(weekOfYear) · Y\(year)", comment: "HUD date, narrow form: week of year and game year. Bitmap face") }

    /// The long form used in sheets: "Mar 12, Year 1".
    var longLabel: String { String(localized: "\(shortMonthName) \(dayOfMonth), Year \(year)", comment: "Long game date used in sheets and spoken labels") }
}

extension Season {
    var systemImage: String {
        switch self {
        case .winter: "snowflake"
        case .spring: "leaf.fill"
        case .summer: "sun.max.fill"
        case .autumn: "wind"
        }
    }
}

extension GameState {
    /// This state's calendar. WS-E's call sites used `gameCalendar` while
    /// the App carried its own struct; it now forwards to the engine's
    /// `calendar` so both names mean exactly one thing.
    var gameCalendar: GameCalendar { calendar }
}
