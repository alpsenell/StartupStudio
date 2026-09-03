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
/// changed still renders the choice the player was actually offered. The
/// catalog is consulted only for the numbers: an option's effect on cash,
/// so the sheet can say what the company looks like afterwards.
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

        let choices = content.event(pending.id)?.choices
            ?? content.lifeEvent(pending.id)?.choices
            ?? []

        return DecisionPrompt(
            id: "narrative-\(pending.id)-\(pending.raisedDay)",
            systemImage: EventPresenter.icon(forCategory: pending.category),
            tint: EventPresenter.tint(forCategory: pending.category),
            title: pending.title,
            message: message(for: pending, daysLeft: daysLeft, autoLabel: autoLabel),
            stats: [
                ("Answer within", daysLeft == 0 ? "today" : "\(daysLeft) day\(daysLeft == 1 ? "" : "s")")
            ],
            options: pending.options.map { option in
                DecisionPrompt.Option(
                    label: option.label,
                    detail: option.detail,
                    cashDelta: cashDelta(for: option, in: choices),
                    action: .resolveChoice(eventID: pending.id, optionIndex: option.index)
                )
            },
            kicker: kicker(for: pending.category),
            isDeferrable: true
        )
    }

    /// The lump sum an option moves in or out of the company, or `nil`
    /// when it moves none — the after-state line is only worth its space
    /// when there is a number in it.
    private static func cashDelta(for option: ChoiceOption, in choices: [EventChoice]) -> Int? {
        guard let choice = choices.first(where: { $0.id == option.id }) else { return nil }
        let total = choice.effects.reduce(0) { sum, effect in
            if case .cash(let amount) = effect { return sum + amount }
            return sum
        }
        return total == 0 ? nil : total
    }

    /// The bitmap word over the title, from the beat's category.
    static func kicker(for category: String) -> String {
        switch EventCategory(rawValue: category) {
        case .press: "PRESS"
        case .legal: "LEGAL"
        case .tech: "TECH"
        case .team: "TEAM"
        case .market: "MARKET"
        case .money: "MONEY"
        case .personal: "PERSONAL"
        case .investor: "INVESTOR"
        case .office: "OFFICE"
        case .family: "FAMILY"
        case nil: "STORY"
        }
    }

    /// The body, plus a line about what silence will cost. The clock is
    /// stopped while the sheet is up, so the deadline only bites if the
    /// player puts the question off — and the line now says exactly that.
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
            case 0: "Put it off past today"
            case 1: "Put it off past tomorrow"
            default: "Put it off for \(daysLeft) days"
            }
            parts.append("\(when) and it goes down as \"\(autoLabel)\".")
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
