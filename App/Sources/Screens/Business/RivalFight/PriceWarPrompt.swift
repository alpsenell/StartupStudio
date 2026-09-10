import SwiftUI
import TycoonContent
import TycoonEngine

/// Iteration 12 — J3. The price war as a question in the game's hand.
///
/// A war used to stop the clock and ask nothing. Now it asks three things,
/// each with its consequence on the button:
///
/// - **Match them** — the product goes budget for the war, the share
///   penalty lifts, the studio bleeds and remembers. Twice against the same
///   studio passes the grudge at which it starts working against you.
/// - **Out-ship them** — a patch that lands inside the war ends it, and
///   the category remembers that too.
/// - **Outlast them** — what every war was before, and what an unanswered
///   one still is once the answer window closes.
///
/// Read off the rival's `priceWarUntilDay` on the app side; the engine
/// holds no pending question, so a run that never sees this sheet saves
/// exactly what it always did. The refusals under the buttons are the
/// reducer's own, from a dry run (`RivalMarket.refusal(answering:…)`).
enum PriceWarPrompt {
    static func pending(
        in state: GameState,
        content: ContentCatalog,
        balance: BalanceConfig
    ) -> DecisionPrompt? {
        guard let rival = RivalMarket.pendingPriceWar(state: state, balance: balance),
              let topicID = rival.priceWarTopicID,
              let until = rival.priceWarUntilDay
        else { return nil }
        return prompt(rival: rival, topicID: topicID, until: until, state: state, content: content, balance: balance)
    }

    static func prompt(
        rival: Rival,
        topicID: String,
        until: Int,
        state: GameState,
        content: ContentCatalog,
        balance: BalanceConfig
    ) -> DecisionPrompt {
        let config = balance.rivalMarket
        let topic = content.topic(topicID)?.name ?? topicID
        let product = RivalMarket.warProduct(in: topicID, state: state)
        let productName = product?.name ?? String(localized: "your product", comment: "Stand-in for the product a price war is fought over, when it cannot be named")
        let penalty = Int((RivalDepthTuning.priceWarSharePenalty * 100).rounded())
        let share = Int((state.rivals.share(for: topicID) * 100).rounded())
        let weeks = RivalDepthTuning.priceWarWeeks
        let deadline = RivalMarket.answerDeadline(rival, balance: balance) ?? state.day
        let daysLeft = max(0, deadline - state.day)
        let grudgeNow = Int(rival.grudge.rounded())
        let grudgeAfter = Int(min(100, rival.grudge + config.matchGrudge).rounded())
        let actsAt = Int(balance.espionage.rivalGrudgeToAct.rounded())
        let bleed = config.matchStrengthPerWeek.formatted(.number.precision(.fractionLength(0...1)).locale(Theme.gameLocale))
        let standing = Int(config.outshipStanding.rounded())

        func refusal(_ answer: RivalMarketPriceWarAnswer) -> String? {
            RivalMarket.refusal(
                answering: answer, rivalID: rival.id, state: state, balance: balance, content: content
            )?.reason
        }

        let alreadyBudget: Bool = if case .released(let info)? = product?.stage {
            info.priceTier == .budget
        } else {
            false
        }
        // MARK: U1 (ux: the first-hour fixes)
        // C4: the player's words, not the engine's — no "lifts", no
        // "strength", no "grudge". The numbers stay.
        var matchDetail = alreadyBudget
            ? "\(productName) is budget already: you win back the \(penalty)% of share"
            : "\(productName) goes budget for \(weeks) weeks: you win back the \(penalty)% of share, but earn less per sale"
        matchDetail += " · \(rival.name) gets weaker every week (−\(bleed)) · bad blood \(grudgeNow) → \(grudgeAfter) of 100"
        if grudgeAfter >= actsAt {
            matchDetail += " · past \(actsAt) they start working against you"
        }
        // MARK: end U1

        let patching = product.map { state.economy.update(for: $0.id) != nil } ?? false
        let outshipDetail = patching
            ? "The patch on \(productName) is already underway · if it lands by day \(until) the war ends, standing +\(standing)"
            : "Patch \(productName) now, a build slot for a few weeks · lands by day \(until) and the war ends, standing +\(standing)"

        let options: [DecisionPrompt.Option] = [
            DecisionPrompt.Option(
                label: String(localized: "Match them", comment: "Answer to a price war: go budget too"),
                detail: matchDetail,
                disabledReason: refusal(.match),
                action: .answerPriceWar(rivalID: rival.id, answer: .match)
            ),
            DecisionPrompt.Option(
                label: String(localized: "Out-ship them", comment: "Answer to a price war: patch the product so the war ends"),
                detail: outshipDetail,
                disabledReason: refusal(.outship),
                action: .answerPriceWar(rivalID: rival.id, answer: .outship)
            ),
            DecisionPrompt.Option(
                label: String(localized: "Outlast them", comment: "Answer to a price war: take the hit until it is over"),
                detail: "−\(penalty)% of your \(topic) share until day \(until) · nothing else moves",
                role: .destructive,
                disabledReason: refusal(.outlast),
                action: .answerPriceWar(rivalID: rival.id, answer: .outlast)
            ),
        ]

        return DecisionPrompt(
            id: "pricewar-\(rival.id.uuidString)-\(until)",
            systemImage: "arrow.down.right.circle.fill",
            tint: Theme.negativeCash,
            title: "\(rival.name) cut its prices in \(topic)",
            message: "You out-sold them \(RivalDepthTuning.priceWarTrigger) weeks running, so now they are selling at a loss. "
                + "Until day \(until) they take \(penalty)% of your share there. "
                + "Answer inside the week, or you outlast it by default.",
            stats: [
                (String(localized: "Your share", comment: "Price war sheet stat: your share of the topic now"), "\(share)%"),
                (String(localized: "Ends", comment: "Price war sheet stat: the day the war ends on its own"), "day \(until)"),
                (String(localized: "Answer by", comment: "Price war sheet stat: days left to answer"), daysLeft == 0 ? "today" : "\(daysLeft)d"),
            ],
            options: options,
            kicker: String(localized: "PRICE WAR", comment: "Bitmap kicker: a rival has started a price war. Uppercase A-Z only"),
            portraitSeed: rival.appearanceSeed
        )
    }
}

/// The journal's words for J3's four events, beside the sheet that makes
/// two of them.
enum RivalMarketEventLine {
    static func answered(_ answer: RivalMarketPriceWarAnswer, rival: String, topic: String) -> String {
        switch answer {
        case .match: "You matched \(rival)'s prices in \(topic). Somebody is losing money on every sale; both of you are"
        case .outship: "You answered \(rival)'s price war in \(topic) with a patch"
        case .outlast: "You let \(rival)'s price war in \(topic) run its course"
        }
    }

    static func icon(_ answer: RivalMarketPriceWarAnswer) -> String {
        switch answer {
        case .match: "tag.fill"
        case .outship: "hammer.fill"
        case .outlast: "hourglass"
        }
    }
}
