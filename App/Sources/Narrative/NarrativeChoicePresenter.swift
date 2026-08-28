import SwiftUI
import TycoonContent
import TycoonEngine

/// Maps a pending narrative choice onto the app's `DecisionPrompt`, so
/// story beats use the same pause-and-choose sheet as poaches, buyouts and
/// staff moments.
///
/// Everything is read from `state.narrative.pendingChoice` — the title,
/// body and options were snapshotted into state when the beat fired — so
/// the sheet survives a relaunch, and a save whose catalog has since
/// changed still renders the choice the player was actually offered.
enum NarrativeChoicePresenter {
    static func prompt(
        for state: GameState,
        content: ContentCatalog,
        balance: BalanceConfig
    ) -> DecisionPrompt? {
        guard let pending = state.narrative.pendingChoice, !pending.options.isEmpty else {
            return nil
        }
        let daysLeft = max(0, pending.respondByDay - state.day)
        let autoLabel = pending.options.first { $0.index == pending.autoOptionIndex }?.label
            ?? pending.options.last?.label

        var stats: [(label: String, value: String)] = [
            ("Answer by", "Day \(pending.respondByDay)")
        ]
        if daysLeft <= 1 {
            stats.append(("Deadline", daysLeft == 0 ? "Today" : "Tomorrow"))
        }

        return DecisionPrompt(
            id: "narrative-\(pending.id)-\(pending.raisedDay)",
            systemImage: EventPresenter.icon(forCategory: pending.category),
            tint: EventPresenter.tint(forCategory: pending.category),
            title: pending.title,
            message: message(for: pending, daysLeft: daysLeft, autoLabel: autoLabel),
            stats: stats,
            options: pending.options.map { option in
                DecisionPrompt.Option(
                    label: option.label,
                    detail: option.detail,
                    action: .resolveChoice(eventID: pending.id, optionIndex: option.index)
                )
            }
        )
    }

    /// The body, plus a line about what silence will cost — the deadline
    /// answers for a founder who never got back to it, and the player
    /// should know which answer that is.
    ///
    /// The body is dropped when it is the headline again. An event
    /// definition with no `body` is snapshotted with the headline in both
    /// fields (`NarrativeSystem`), and a sheet that repeats its own title
    /// underneath itself in grey reads as a bug. Every shipped
    /// choice-bearing event now has a real body, but a save written before
    /// they did still carries the duplicate, so the guard lives here and
    /// not only in the content.
    private static func message(
        for pending: PendingChoice,
        daysLeft: Int,
        autoLabel: String?
    ) -> String {
        var parts: [String] = []
        if !isEcho(of: pending.title, pending.body) {
            parts.append(pending.body)
        }
        if let autoLabel {
            let when = switch daysLeft {
            case 0: "If you don't answer today"
            case 1: "If you don't answer by tomorrow"
            default: "If you don't answer within \(daysLeft) days"
            }
            parts.append("\(when), it goes down as \"\(autoLabel)\".")
        }
        return parts.joined(separator: "\n\n")
    }

    /// Whether the body says nothing the title has not already said.
    static func isEcho(of title: String, _ body: String) -> Bool {
        func normalized(_ text: String) -> String {
            text.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\u{2019}", with: "'")
                .lowercased()
        }
        let stripped = normalized(body)
        return stripped.isEmpty || stripped == normalized(title)
    }
}
