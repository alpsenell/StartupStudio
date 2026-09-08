import SwiftUI
import TycoonEngine

/// Iteration 11, wave two — W1. One line on the Investors page pointing at
/// the other money, and only while there is other money to point at.
///
/// A founder who has just turned a term sheet down is on this page, not on
/// the finances page, so the approach has to be visible from here — but as
/// a note with a link rather than a second copy of the card, because there
/// is exactly one of these and it belongs beside the ledger.
struct DirtyMoneyApproachNote: View {
    let engine: GameEngine

    @Environment(AppRouter.self) private var router

    private var money: DirtyMoneyState { engine.state.dirtyMoney }

    var body: some View {
        if money.hasOffer(on: engine.state.day), let backer = money.offeredKind {
            note(
                title: "Somebody else has called",
                line: "\(backer.displayName) will put \(money.offeredCheque.money) in the account this week, against no equity. It is in Finances.",
                tint: Theme.warning,
                symbol: backer.symbol
            )
        } else if let backer = money.backerKind {
            note(
                title: "Off the cap table",
                line: "\(money.cheque.money) of \(backer.displayName)'s money is in the company and none of it is on this page.",
                tint: Theme.negativeCash,
                symbol: backer.symbol
            )
        }
    }

    private func note(title: String, line: String, tint: Color, symbol: String) -> some View {
        Button {
            Haptics.tap()
            router.go(.dirtyMoney)
        } label: {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    Text(line)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Theme.Spacing.sm)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(Theme.Spacing.md)
            .background(Theme.chipBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressableRow)
        .accessibilityLabel("\(title). \(line)")
    }
}
