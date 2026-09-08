import SwiftUI
import TycoonEngine

/// Iteration 11, wave two — W4. What the lane's events say in the journal
/// and the toast layer.
///
/// `EventCopy`'s switch calls into this from its W4 region, so all the
/// words live in the lane's own file.
enum InsideEventPresenter {

    /// Icon, line, day and tint, in `EventCopy`'s shape.
    static func entry(
        for event: GameEvent
    ) -> (String, String, Int, Color)? {
        switch event {
        case let .insideArrived(weeks, cellmate, day):
            (
                "building.columns.fill",
                "\(weeks) week\(weeks == 1 ? "" : "s") inside. \(cellmate) has the top bunk",
                day,
                Theme.negativeCash
            )
        case let .insideDayChosen(choice, day):
            (
                PrisonDayChoice(rawValue: choice)?.symbol ?? "circle",
                PrisonDayChoice(rawValue: choice)?.displayName ?? "A day inside",
                day,
                Color.secondary
            )
        case let .insideTrouble(kind, infractions, day):
            (
                "exclamationmark.triangle.fill",
                kind == "theDeal"
                    ? "They found what you were carrying — \(infractions) on your file"
                    : "Something started in the yard — \(infractions) on your file",
                day,
                Theme.warning
            )
        case let .insideGangAnswered(joined, day):
            (
                joined ? "hand.raised.fill" : "hand.raised.slash.fill",
                joined ? "You went in with the wing" : "You said no to the wing",
                day,
                joined ? Theme.warning : Theme.accent
            )
        case let .insideParoleListed(day):
            ("calendar.badge.clock", "Your parole hearing is listed", day, Theme.accent)
        case let .insideParoleOpened(day):
            ("person.crop.square.filled.and.at.rectangle", "The board is sitting", day, Theme.accent)
        case let .insideParoleSaid(exchange, landed, day):
            (
                PrisonParoleExchange(rawValue: exchange)?.symbol ?? "text.bubble",
                landed
                    ? "\(PrisonParoleExchange(rawValue: exchange)?.displayName ?? "You spoke") — it landed"
                    : "\(PrisonParoleExchange(rawValue: exchange)?.displayName ?? "You spoke") — it did not",
                day,
                landed ? Theme.positiveCash : Theme.negativeCash
            )
        case let .insideParoleDecided(granted, day):
            (
                granted ? "door.left.hand.open" : "lock.fill",
                granted ? "Parole granted" : "Parole refused — the date has not moved",
                day,
                granted ? Theme.positiveCash : Theme.negativeCash
            )
        case let .insideEscape(succeeded, day):
            (
                "figure.run",
                succeeded
                    ? "You went over the wall, and you are not off any list"
                    : "They found you at the second gate — the sentence doubled",
                day,
                Theme.warning
            )
        case let .insideReleased(weeksServed, paroled, day):
            (
                "door.left.hand.open",
                paroled
                    ? "Out after \(weeksServed) week\(weeksServed == 1 ? "" : "s"), on paper"
                    : "Out. \(weeksServed) week\(weeksServed == 1 ? "" : "s") served, all of it",
                day,
                Theme.positiveCash
            )
        default:
            nil
        }
    }
}
