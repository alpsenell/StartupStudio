import SwiftUI
import TycoonContent
import TycoonEngine

/// Feed lines for the events WS-F adds: goals, chapters, term sheets, the
/// board, the endings, and rivals shipping named products.
///
/// The activity feed's own switch predates these cases and hands anything
/// it doesn't know to `EventPresenter`, which delegates here. Every WS-F
/// event yields a line, so nothing the player did ever shows up as
/// "Something happened".
enum ProgressionEventPresenter {
    static func describe(
        _ event: GameEvent,
        state: GameState,
        content: ContentCatalog,
        balance: BalanceConfig
    ) -> EventLine? {
        switch event {
        case let .goalCompleted(goalID, day):
            let title = content.goal(goalID)?.title ?? "a milestone"
            return EventLine(
                icon: "checkmark.seal.fill",
                message: "Goal complete — \(title)",
                day: day,
                tint: Theme.positiveCash
            )

        case let .chapterReached(chapter, day):
            return EventLine(
                icon: "flag.checkered",
                message: "Chapter \(chapter): \(ChapterDef.title(for: chapter))",
                day: day,
                tint: Theme.accent
            )

        case let .investmentOffered(investorID, amount, equity, _, day):
            return EventLine(
                icon: "doc.text.fill",
                message: "\(investorName(investorID, content)) offered \(amount.money) "
                    + "for \(equity.oneDecimal)%",
                day: day,
                tint: Theme.accent
            )

        case let .investmentAccepted(investorID, amount, equity, day):
            return EventLine(
                icon: "signature",
                message: "Closed \(amount.money) from \(investorName(investorID, content)) "
                    + "for \(equity.oneDecimal)%",
                day: day,
                tint: Theme.positiveCash
            )

        case let .investmentDeclined(investorID, day):
            return EventLine(
                icon: "hand.raised.fill",
                message: "Turned down \(investorName(investorID, content))",
                day: day,
                tint: .secondary
            )

        case let .investmentWithdrawn(investorID, day):
            return EventLine(
                icon: "clock.badge.xmark",
                message: "\(investorName(investorID, content)) withdrew their term sheet",
                day: day,
                tint: Theme.warning
            )

        case let .boardReviewed(met, pressure, day):
            return EventLine(
                icon: met ? "checkmark.circle.fill" : "xmark.circle.fill",
                message: met
                    ? "Board review passed — pressure down to \(Int(pressure.rounded()))"
                    : "Board review missed — pressure up to \(Int(pressure.rounded()))",
                day: day,
                tint: met ? Theme.positiveCash : Theme.warning
            )

        case let .boardDemandedPlan(pressure, day):
            return EventLine(
                icon: "exclamationmark.triangle.fill",
                message: "The board wants a plan (pressure \(Int(pressure.rounded())))",
                day: day,
                tint: Theme.negativeCash
            )

        case let .founderOusted(day):
            return EventLine(
                icon: "person.crop.circle.badge.xmark",
                message: "The board replaced \(state.progression.founder.displayName)",
                day: day,
                tint: Theme.negativeCash
            )

        case let .wentPublic(proceeds, day):
            return EventLine(
                icon: "bell.fill",
                message: "\(state.company.name) went public — \(proceeds.money) for your stake",
                day: day,
                tint: Theme.positiveCash
            )

        case let .rivalProductLaunched(rivalID, productName, topicID, quality, day):
            return EventLine(
                icon: "shippingbox.fill",
                message: "\(rivalName(rivalID, state)) shipped \(productName) "
                    + "(\(quality)) into \(topicName(topicID, content))",
                day: day,
                tint: Theme.warning
            )

        case let .priceWarStarted(rivalID, topicID, untilDay, day):
            return EventLine(
                icon: "arrow.down.right.circle.fill",
                message: "\(rivalName(rivalID, state)) started a price war in "
                    + "\(topicName(topicID, content)) — until day \(untilDay)",
                day: day,
                tint: Theme.negativeCash
            )

        case let .rivalCopycat(rivalID, topicID, day):
            return EventLine(
                icon: "doc.on.doc.fill",
                message: "\(rivalName(rivalID, state)) cloned your \(topicName(topicID, content)) play",
                day: day,
                tint: Theme.warning
            )

        case let .candidateInterviewed(_, day):
            return EventLine(
                icon: "person.fill.questionmark",
                message: "Spent the day interviewing",
                day: day,
                tint: .secondary
            )

        default:
            return nil
        }
    }

    // MARK: - Defensive name lookups

    /// A persona the catalog no longer knows still reads as a person.
    private static func investorName(_ id: String, _ content: ContentCatalog) -> String {
        content.investors.first { $0.id == id }?.name ?? "An investor"
    }

    /// Folded and acquired rivals are gone from state, so their events
    /// fall back.
    private static func rivalName(_ id: UUID, _ state: GameState) -> String {
        state.rivals.rival(id: id)?.name ?? "A rival"
    }

    private static func topicName(_ id: String, _ content: ContentCatalog) -> String {
        content.topic(id)?.name ?? id
    }
}
