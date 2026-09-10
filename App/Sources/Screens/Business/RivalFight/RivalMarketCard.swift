import SwiftUI
import TycoonContent
import TycoonEngine

/// Iteration 12 — J3. A studio's page, read against the market: the
/// topics it is in and why it is there, the ones it walked out of, and the
/// price war it is running, with the answer you gave it.
///
/// Drawn only once there is something to say — the market board has been
/// opened, or a war is on — so a profile in a run that has done neither is
/// the profile it always was.
struct RivalMarketCard: View {
    let engine: GameEngine
    let rival: Rival

    static func hasSomething(_ rival: Rival, state: GameState) -> Bool {
        state.rivalMarket.noticed || rival.isInPriceWar(on: state.day)
    }

    private var state: GameState { engine.state }

    var body: some View {
        CardView("Where they are going", systemImage: "arrow.triangle.branch") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if let war = warLine {
                    row(icon: "arrow.down.right.circle.fill", tint: Theme.negativeCash, text: war)
                }
                if state.rivalMarket.noticed {
                    ForEach(rival.focusTopicIDs, id: \.self) { topicID in
                        row(icon: engine.content.topic(topicID)?.iconSystemName ?? "circle",
                            tint: Theme.accent,
                            text: focusLine(topicID))
                    }
                    ForEach(Array(exits.enumerated()), id: \.offset) { _, move in
                        row(icon: "arrow.left.circle", tint: .secondary, text: exitLine(move))
                    }
                    Text("Studios launch where demand is: a market at ×1.4 draws about twice the launches of one at ×1.0.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func row(icon: String, tint: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 20)
            Text(text)
                .font(.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func topicName(_ id: String) -> String {
        engine.content.topic(id)?.name ?? id
    }

    private func multiplier(_ id: String) -> String {
        "×" + state.market.multiplier(for: id).formatted(.number.precision(.fractionLength(2)).locale(Theme.gameLocale))
    }

    private func focusLine(_ topicID: String) -> String {
        let name = topicName(topicID)
        let selling = rival.bestProduct(in: topicID, on: state.day) != nil
        let move = state.rivalMarket.latestMove(rivalID: rival.id, topicID: topicID)
        var line = "\(name), \(multiplier(topicID))"
        if move?.kind == .boomEntry, let day = move?.day {
            line += ": moved in on the boom, \(MarketFormat.dateLabel(forDay: day))"
        } else if rival.focusTopicIDs.first == topicID {
            line += ": where they started"
        } else if rival.personality == .copycat {
            line += ": followed you here"
        } else {
            line += ": took it in a fight"
        }
        line += selling ? " · selling" : " · nothing out yet"
        return line
    }

    private var exits: [RivalMarketMove] {
        state.rivalMarket.moves
            .filter { $0.rivalID == rival.id && $0.kind == .crashExit }
            .suffix(2)
    }

    private func exitLine(_ move: RivalMarketMove) -> String {
        "Left \(topicName(move.topicID)) \(MarketFormat.dateLabel(forDay: move.day)), a month under ×0.70"
    }

    private var warLine: String? {
        guard rival.isInPriceWar(on: state.day),
              let topicID = rival.priceWarTopicID,
              let until = rival.priceWarUntilDay
        else { return nil }
        let base = "Price war in \(topicName(topicID)) until day \(until)"
        switch state.rivalMarket.answer(to: rival)?.answer {
        case .match: return base + ". You matched it: no share lost, and they are bleeding."
        case .outship: return base + ". You are out-shipping it: the patch ends it when it lands."
        case .outlast: return base + ". You are outlasting it."
        case nil:
            if let deadline = RivalMarket.answerDeadline(rival, balance: engine.balance), state.day <= deadline {
                return base + ". Not answered yet."
            }
            return base + ". You are outlasting it."
        }
    }
}
