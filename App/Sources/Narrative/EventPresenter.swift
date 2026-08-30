import SwiftUI
import TycoonContent
import TycoonEngine

/// One rendered line in the activity feed / journal.
struct EventLine {
    let icon: String
    let message: String
    let day: Int
    let tint: Color
}

/// Turns a `GameEvent` the App doesn't otherwise know about into a feed
/// line.
///
/// The activity feed's own switch handles the cases it was written for and
/// hands anything else here, so a workstream can append a `GameEvent`
/// without the App failing to build or silently dropping the line.
///
/// This describes every event WS-B adds: a story beat waiting on an answer,
/// the answer that closed it, and the industry-news drumbeat.
enum EventPresenter {
    static func describe(
        _ event: GameEvent,
        state: GameState,
        content: ContentCatalog,
        balance: BalanceConfig
    ) -> EventLine? {
        switch event {
        case let .narrativeChoice(eventID, respondByDay, day):
            let daysLeft = max(0, respondByDay - state.day)
            let headline = headline(for: eventID, state: state, content: content)
            return EventLine(
                icon: icon(for: eventID, state: state, content: content),
                message: daysLeft > 0
                    ? "\(headline) — \(daysLeft) day\(daysLeft == 1 ? "" : "s") to answer"
                    : headline,
                day: day,
                tint: Theme.warning
            )

        case let .narrativeResolved(eventID, optionID, automatic, day):
            let headline = headline(for: eventID, state: state, content: content)
            let label = optionLabel(eventID: eventID, optionID: optionID, content: content)
            let message: String = if automatic {
                label.map { "\(headline) — you never answered, so: \($0.lowercasedFirst)" }
                    ?? "\(headline) — the deadline answered for you"
            } else {
                label.map { "\(headline) — \($0.lowercasedFirst)" } ?? headline
            }
            return EventLine(
                icon: automatic ? "clock.badge.exclamationmark" : "checkmark.circle.fill",
                message: message,
                day: day,
                tint: automatic ? Theme.warning : Theme.accent
            )

        case let .industryNews(headline, day):
            return EventLine(
                icon: "newspaper.fill",
                message: headline,
                day: day,
                tint: Color.secondary
            )

        default:
            // WS-F describes its own events (goals, chapters, investors,
            // the board, rival products) next door, so this file stays
            // WS-B's.
            return ProgressionEventPresenter.describe(
                event, state: state, content: content, balance: balance
            )
        }
    }

    // MARK: - Lookups

    /// The headline of the definition behind a beat, whichever catalog it
    /// came from. Falls back to the pending choice's own snapshot, which
    /// survives even if the catalog changed under an old save.
    private static func headline(
        for eventID: String,
        state: GameState,
        content: ContentCatalog
    ) -> String {
        if let event = content.event(eventID) { return event.headline }
        if let life = content.lifeEvent(eventID) { return life.headline }
        if let pending = state.narrative.pendingChoice, pending.id == eventID {
            return pending.title
        }
        return "Something needs your answer"
    }

    private static func optionLabel(
        eventID: String,
        optionID: String,
        content: ContentCatalog
    ) -> String? {
        guard !optionID.isEmpty else { return nil }
        if let choice = content.event(eventID)?.choices.first(where: { $0.id == optionID }) {
            return choice.label
        }
        return content.lifeEvent(eventID)?.choices.first { $0.id == optionID }?.label
    }

    /// The icon for a beat's category — the same mapping the decision sheet
    /// uses, so a story reads the same in the journal and in the prompt.
    static func icon(for eventID: String, state: GameState, content: ContentCatalog) -> String {
        let raw = content.event(eventID)?.category.rawValue
            ?? content.lifeEvent(eventID)?.category.rawValue
            ?? state.narrative.pendingChoice.flatMap { $0.id == eventID ? $0.category : nil }
        return icon(forCategory: raw)
    }

    static func icon(forCategory raw: String?) -> String {
        switch raw.flatMap(EventCategory.init(rawValue:)) {
        case .press: "newspaper.fill"
        case .legal: "building.columns.fill"
        case .tech: "server.rack"
        case .team: "person.3.fill"
        case .market: "chart.line.uptrend.xyaxis"
        case .money: "banknote.fill"
        case .personal: "figure.walk"
        case .investor: "briefcase.fill"
        case .office: "building.2.fill"
        case .family: "house.fill"
        case nil: "sparkles"
        }
    }

    /// The tint for a beat's category.
    static func tint(forCategory raw: String?) -> Color {
        switch raw.flatMap(EventCategory.init(rawValue:)) {
        case .legal, .tech: Theme.warning
        case .money, .investor: Theme.positiveCash
        case .market: Theme.codePhase
        case .personal, .family: Theme.designPhase
        default: Theme.accent
        }
    }
}

private extension String {
    /// "Pay him off" -> "pay him off", for use mid-sentence. Leaves an
    /// all-caps or already-lowercase word alone.
    var lowercasedFirst: String {
        guard let first = first, first.isUppercase, !allSatisfy({ !$0.isLowercase }) else {
            return self
        }
        return first.lowercased() + dropFirst()
    }
}
