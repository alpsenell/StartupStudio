import SwiftUI
import TycoonEngine

/// Iteration 11, wave two — W2. The Life tab's door into the half of the
/// family the Family card does not show: the people you did not choose,
/// the paperwork, and whatever is currently going wrong.
///
/// Four states, because the lane has four: nothing has happened yet (the
/// pitch and the door), somebody knows about the affair (the loudest
/// thing on the tab), a divorce has been through (what it left), and the
/// ordinary middle — a sibling waiting for an answer, a care bill, a will
/// with nobody's name on it.
struct FamilyDramaCard: View {
    let engine: GameEngine
    var onOpen: () -> Void

    var body: some View {
        let state = engine.state
        let drama = state.familyDrama
        CardView("The rest of the family", systemImage: "person.2.badge.gearshape.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                if drama.isConfrontationOpen {
                    headline(
                        "They know.",
                        detail: "It has been sitting on the kitchen table since this morning.",
                        icon: "exclamationmark.bubble.fill",
                        tint: Theme.negativeCash
                    )
                } else if drama.isFuneralOpen {
                    headline(
                        "The funeral is Thursday.",
                        detail: "Everybody is coming, including the ones who are a problem.",
                        icon: "leaf.fill",
                        tint: Theme.warning
                    )
                } else if let ask = drama.pendingAsk, let kind = FamilyAsk(rawValue: ask.askStage) {
                    headline(
                        kind.title,
                        detail: "\(siblingName) is waiting on an answer.",
                        icon: "hand.raised.fill",
                        tint: Theme.warning
                    )
                } else if let settlement = drama.settlement {
                    divorceSummary(settlement)
                } else if drama.openedDay == nil {
                    Text("Two parents, a sibling, and — while there is a partner — their parents as well. None of them work for you and all of them have opinions.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    middle(state)
                }

                Button(buttonTitle(drama), systemImage: "chevron.right.circle.fill") { onOpen() }
                    .buttonStyle(.pressable)
                    .font(.footnote.weight(.semibold))
            }
        }
        .task { FamilyDramaDebug.setUpIfAsked(engine: engine) }
    }

    private var siblingName: String {
        engine.state.familyRelativeName(.sibling, content: engine.content)
    }

    private func buttonTitle(_ drama: FamilyDramaState) -> String {
        if drama.isConfrontationOpen { return "Go home" }
        if drama.isFuneralOpen { return "Go to the funeral" }
        if drama.pendingAsk != nil { return "Answer them" }
        return drama.openedDay == nil ? "Look at the family" : "The family"
    }

    // MARK: - The states

    private func headline(
        _ title: String, detail: String, icon: String, tint: Color
    ) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func divorceSummary(_ settlement: FamilySettlement) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Divorced from \(settlement.exName).")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
            Text(settlementLine(settlement))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let custody = engine.state.familyDrama.custody {
                Text(custody.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(custody.keepsTheHouse ? Theme.positiveCash : Theme.warning)
            }
        }
    }

    private func settlementLine(_ settlement: FamilySettlement) -> String {
        var parts: [String] = []
        parts.append(settlement.keptHome ? "You kept the house" : "They kept the house")
        if settlement.cashTransfer != 0 {
            parts.append(settlement.cashTransfer > 0
                ? "\(settlement.cashTransfer.money) came your way"
                : "\((-settlement.cashTransfer).money) went theirs")
        }
        if settlement.equityGiven > 0 {
            parts.append("\(Int(settlement.equityGiven.rounded()))% of the company is theirs")
        }
        if !settlement.petName.isEmpty {
            parts.append(settlement.petKept
                ? "\(settlement.petName) stayed"
                : "\(settlement.petName) went with them")
        }
        return parts.joined(separator: " · ") + "."
    }

    @ViewBuilder
    private func middle(_ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if state.familyDrama.careWeeklyBill > 0 {
                Text("\(state.familyDrama.careWeeklyBill.money) a week to the home.")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Theme.warning)
            }
            if let heir = state.familyDrama.heirName {
                Text("The will names \(heir).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Nobody is named in a will. The board would enjoy that.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if state.interactions.affairIsSecret {
                Text("Nobody knows yet.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
