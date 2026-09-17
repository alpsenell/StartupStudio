import SwiftUI
import TycoonEngine

// MARK: A3 (IPO day)

/// Pricing the offering: the three books, side by side, each with the
/// money it pays, what the street is expected to do with it on the day,
/// and — the house rule for anything with a cash effect — what the
/// founder's wallet reads afterwards.
///
/// The engine owns every number (`GameState.ipoQuotes`); this sheet prints
/// them and sends `.fileIPO(price:)`. T1's exit split keeps its place
/// under the rows: the loan comes back first, the vested are paid out of
/// the price, and the unvested lapse home to the founder's slice before it
/// is sold.
struct IPOPricingSheet: View {
    let engine: GameEngine

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let state = engine.state
        let balance = engine.balance
        let quotes = state.ipoQuotes(balance: balance)
        let blocker = state.ipoBlocker(balance: balance)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    header(state, quotes: quotes)
                    ForEach(quotes, id: \.price) { quote in
                        row(quote, blocker: blocker, state: state)
                    }
                    // MARK: T1 (exits and joins) — the split keeps its place.
                    if let split = ExitOptionsRow.make(
                        price: quotes.first(where: { $0.price == .fair })?.offerValuation ?? 0,
                        state: state,
                        balance: balance,
                        offersEarnOut: false
                    ) {
                        exitSplitRow(split)
                    }
                    // MARK: end T1
                    Text(
                        "The pop is not a coin toss: it reads the reviews on what you still have on sale, "
                            + "the hype behind it and the market under it. Price into a weak book and the "
                            + "stock closes under its own offer — a broken open, and everyone remembers it."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle("Price the offering")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not yet") { dismiss() }
                }
            }
        }
    }

    // MARK: - The header

    private func header(_ state: GameState, quotes: [IPOQuote]) -> some View {
        let ticker = quotes.first?.ticker ?? ""
        return PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(alignment: .center, spacing: Theme.Spacing.md) {
                    PixelIconTile(systemImage: "building.columns.fill", tint: Theme.accent, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        PixelText(text: ticker, scale: 3, color: Theme.pixelInk)
                        Text("\(state.company.name) · \(state.investors.equityRemaining.oneDecimal)% yours")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.pixelInk.opacity(0.7))
                    }
                }
                Text(
                    "The bankers have a range. Pick the number on the cover: "
                        + "leave money on the table, take the fair price, or price for every dollar the book will bear."
                )
                .font(.callout)
                .foregroundStyle(Theme.pixelInk)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Pricing \(state.company.name), ticker \(ticker.map(String.init).joined(separator: " ")). "
                + "You hold \(state.investors.equityRemaining.oneDecimal) percent."
        )
    }

    // MARK: - A price

    private func row(_ quote: IPOQuote, blocker: String?, state: GameState) -> some View {
        let after = state.life.wallet + quote.proceeds
        // The fair row is filled with the accent, so `.secondary` — a dim
        // grey meant for paper — lands almost unreadable on it. Photographed
        // on the 6.9" phone before this line existed.
        let filled = quote.price == .fair
        let quiet: Color = filled ? Theme.pixelPaper.opacity(0.85) : .secondary
        return Button { file(quote) } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    Text(quote.price.displayName)
                        .font(.system(.headline, design: .rounded))
                    Spacer(minLength: Theme.Spacing.sm)
                    Text(quote.proceeds.money)
                        .font(Theme.Typography.number(.headline))
                }
                Text(caption(quote))
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
                Text(quote.oddsLine)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(
                        quote.brokeOpen ? AnyShapeStyle(Theme.negativeCash) : AnyShapeStyle(Theme.positiveCash)
                    )
                // House rule: every option with a cash effect prints the
                // company — here the wallet — afterwards.
                Text(
                    blocker
                        ?? "Your wallet after the bell: \(after.money) · \(quote.ticker) opens at \(quote.offerValuation.money)"
                )
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(blocker == nil ? quiet : Theme.warning)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(PixelButtonStyle(fill: quote.price == .fair ? Theme.pixelAccent : Theme.pixelPaper))
        .disabled(blocker != nil)
        .opacity(blocker == nil ? 1 : 0.6)
        .accessibilityLabel(accessibilityLabel(quote, after: after, blocker: blocker))
    }

    private func caption(_ quote: IPOQuote) -> String {
        switch quote.price {
        case .conservative:
            "Under the range. The book is covered many times over, the first day is a party, "
                + "and every outlet gets to write that you left money on the table."
        case .fair:
            "The bankers' number. What the company is worth, sold at what the company is worth."
        case .aggressive:
            "Over the range. A quarter more in your pocket on the morning — and if the book is "
                + "thinner than you think, the stock closes under its own price and your name wears it."
        }
    }

    private func accessibilityLabel(_ quote: IPOQuote, after: Int, blocker: String?) -> String {
        var label = "\(quote.price.displayName). \(quote.proceeds.money) to you. \(quote.oddsLine)."
        if let blocker {
            label += " Not available: \(blocker)"
        } else {
            label += " Your wallet afterwards: \(after.money)."
        }
        return label
    }

    // MARK: - T1's split

    private func exitSplitRow(_ row: ExitOptionsRow) -> some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: 6) {
                PixelText(
                    text: String(
                        localized: "OPTIONS",
                        comment: "Pixel header over the IPO pricing sheet's options row. Uppercase A-Z only — the bitmap font has no lowercase and no accents."
                    ),
                    scale: 2, color: Theme.pixelAccent
                )
                Text(row.headline)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.pixelInk)
                ForEach(row.lines, id: \.self) { line in
                    Text(line)
                        .font(.caption)
                        .foregroundStyle(Theme.pixelInk.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if row.split.hasUnvested {
                    // There is no acceleration at a listing: there is no
                    // company left to keep anyone in, so the unvested lapse
                    // and come home to the slice being sold.
                    Text(
                        "Nothing is left to vest into: what has not vested lapses back to your slice "
                            + "before it is sold."
                    )
                    .font(.caption)
                    .foregroundStyle(Theme.pixelInk.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - The tap

    private func file(_ quote: IPOQuote) {
        Haptics.commit()
        engine.send(.fileIPO(price: quote.price))
        dismiss()
    }
}
