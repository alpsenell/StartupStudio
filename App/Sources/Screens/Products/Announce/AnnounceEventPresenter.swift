import SwiftUI
import TycoonEngine

// MARK: J5 (announce)

/// Iteration 12 — J5. What the announce events say in the journal, the
/// toast layer and the newspaper (whose lead is `EventCopy`'s line,
/// compressed).
///
/// `EventCopy`'s switch calls into this from its J5 region, so all the
/// words live in the lane's own file.
enum AnnounceEventPresenter {
    /// Icon, line, day and tint, in `EventCopy`'s shape.
    static func entry(for event: GameEvent, state: GameState) -> (String, String, Int, Color)? {
        switch event {
        case let .announceMade(productID, forDay, day):
            let name = name(of: productID, in: state)
            return (
                "megaphone.fill",
                "\(name) will ship on \(dateLabel(forDay, today: day)). It is in print now",
                day,
                Theme.accent
            )
        case let .announceSlipped(productID, slips, newDay, day):
            let name = name(of: productID, in: state)
            if let newDay {
                return (
                    "calendar.badge.exclamationmark",
                    "\(name) slips past its date. The paper ran a correction, and a new date: \(dateLabel(newDay, today: day))",
                    day,
                    Theme.warning
                )
            }
            return (
                "calendar.badge.minus",
                "\(name) misses its second date. Nobody is printing a third",
                day,
                Theme.negativeCash
            )
        case let .announceKept(productID, _, slips, day):
            let name = name(of: productID, in: state)
            return (
                "checkmark.seal.fill",
                slips == 0
                    ? "\(name) shipped on the day it said. Nobody wrote about that, which was the point"
                    : "\(name) made its second date. The first one is still in the archive",
                day,
                Theme.positiveCash
            )
        default:
            return nil
        }
    }

    /// "March 14", with the year when it is not this one.
    static func dateLabel(_ day: Int, today: Int) -> String {
        let date = GameCalendar(day: day)
        let now = GameCalendar(day: today)
        return date.year == now.year
            ? "\(date.monthName) \(date.dayOfMonth)"
            : "\(date.monthName) \(date.dayOfMonth), Year \(date.year)"
    }

    private static func name(of productID: UUID, in state: GameState) -> String {
        state.product(id: productID)?.name ?? "The build"
    }
}

// MARK: end J5
