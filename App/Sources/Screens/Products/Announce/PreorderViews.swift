import SwiftUI
import TycoonContent
import TycoonEngine

// MARK: T5 (expo and pre-orders)

/// Iteration 17 — T5 (G6/P4). The row under an announced date on the build's
/// *Ship date* card: *Open pre-orders* with the cash it takes now, or what
/// was sold and what the slips gave back — or, where they cannot open, why.
struct PreorderRow: View {
    let engine: GameEngine
    let product: Product

    @State private var showingSheet = false

    private var state: GameState { engine.state }
    private var refusal: PreorderRefusal? {
        state.preorderRefusal(productID: product.id, balance: engine.balance, content: engine.content)
    }

    var body: some View {
        content
            .sheet(isPresented: $showingSheet) {
                PreorderSheet(engine: engine, productID: product.id)
            }
            .onChange(of: product.announcedDay, initial: true) { _, _ in
                if refusal == nil, PreorderRoute.takeSheetRequest(for: product.id) { showingSheet = true }
            }
    }

    @ViewBuilder
    private var content: some View {
        if let book = product.preorders {
            VStack(alignment: .leading, spacing: 2) {
                Label(
                    "\(book.units) pre-ordered · \(book.cash.money) taken \(AnnounceEventPresenter.dateLabel(book.openedDay, today: state.day))",
                    systemImage: "cart.fill"
                )
                .font(.footnote.weight(.semibold))
                if book.refundedUnits > 0 {
                    Text("\(book.refundedUnits) refunded when the date slipped (\(book.refundedCash.money)).")
                        .font(.caption)
                        .foregroundStyle(Theme.warning)
                }
                if book.outstanding > 0 {
                    let voiding = product.slips + 1 >= Announce.voidAfterSlips
                    let units = book.refundUnits(voiding: voiding, balance: engine.balance)
                    Text(voiding
                        ? "The next miss refunds the other \(units) (\(book.refundCash(units: units).money)) and costs reputation −\(ExpoCopy.number(engine.balance.expo.preorders.voidReputation)) more."
                        : "A miss refunds \(units) of them (\(book.refundCash(units: units).money)) the same day.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } else if let refusal {
            if refusal == .subscription || refusal == .tooClose || refusal == .nothingToSell {
                Text(refusal.sentence)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else if let quote = state.preorderQuote(productID: product.id, balance: engine.balance, content: engine.content) {
            Button {
                showingSheet = true
            } label: {
                Label("Open pre-orders · +\(quote.cash.money) now", systemImage: "cart.fill")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.xs)
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent)
            .accessibilityHint("Opens the pre-order sheet, with what a slip gives back")
            Text("\(quote.units) of the \(quote.windowUnits) its first \(quote.windowWeeks) week\(quote.windowWeeks == 1 ? "" : "s") would sell, at \(ExpoCopy.price(quote.unitPrice)) · a slip refunds \(quote.firstRefundCash.money)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The pre-order sheet: the launch week the forecast sees, what selling a
/// slice of it now takes, and what a slip gives back. Two answers.
struct PreorderSheet: View {
    let engine: GameEngine
    let productID: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(GameShell.self) private var injectedShell: GameShell?
    private var shell: GameShell { injectedShell ?? .shared }

    private var state: GameState { engine.state }
    private var product: Product? { state.product(id: productID) }
    private var config: BalanceConfig.PreorderBalance { engine.balance.expo.preorders }
    private var quote: PreorderQuote? {
        state.preorderQuote(productID: productID, balance: engine.balance, content: engine.content)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    if let product, let quote {
                        release(product, quote)
                        choices(product, quote)
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle("Pre-orders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not yet") { dismiss() }
                }
            }
        }
    }

    private func release(_ product: Product, _ quote: PreorderQuote) -> some View {
        PixelPanel(contentPadding: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                PixelSectionTitle(title: "Pre-orders open")
                PixelText(text: product.name, scale: 3, color: Theme.pixelInk, shadow: true)
                if let date = product.announcedDay {
                    Text("Announced for \(AnnounceEventPresenter.dateLabel(date, today: state.day)), \(date - state.day) days out.")
                        .font(.callout)
                        .foregroundStyle(Theme.pixelInk)
                }
                Divider().overlay(Theme.pixelInk.opacity(0.3))
                ForEach(lines(quote), id: \.1) { icon, text, tint in
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                        Image(systemName: icon)
                            .font(.caption)
                            .foregroundStyle(tint)
                            .frame(width: 18)
                            .accessibilityHidden(true)
                        Text(text)
                            .font(.footnote)
                            .foregroundStyle(Theme.pixelInk.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func lines(_ quote: PreorderQuote) -> [(String, String, Color)] {
        let book = PreorderBook(
            units: quote.units, unitPrice: quote.unitPrice, cash: quote.cash,
            openedDay: state.day, forecastQuality: quote.forecastQuality
        )
        let rest = book.refundUnits(voiding: true, balance: engine.balance) - quote.firstRefundUnits
        return [
            (
                "cart.fill",
                "The forecast's launch: \(quote.windowUnits) units at \(ExpoCopy.price(quote.standardPrice)) over the \(quote.windowWeeks) week\(quote.windowWeeks == 1 ? "" : "s") it takes to reach its peak. Sell \(pct(config.fraction))% of them now: \(quote.units) at \(ExpoCopy.price(quote.unitPrice)), \(pct(config.price))% of the price.",
                Theme.pixelAccent
            ),
            (
                "shippingbox.fill",
                "The launch weeks deliver them, already paid for: those weeks earn only on the buyers after them.",
                Theme.pixelAccent
            ),
            (
                "calendar.badge.exclamationmark",
                "Miss the date: \(quote.firstRefundUnits) refunded (\(quote.firstRefundCash.money)) the same day. Miss the new one: the other \(rest) (\(book.refundCash(units: rest).money)), and reputation −\(ExpoCopy.number(config.voidReputation)) on top of the slip's own.",
                Theme.warning
            ),
            (
                "star.leadinghalf.filled",
                "They are buying a \(Int(quote.forecastQuality.rounded())). If the reviews land under it, the forum calls it overpromised.",
                Theme.warning
            ),
        ]
    }

    @ViewBuilder
    private func choices(_ product: Product, _ quote: PreorderQuote) -> some View {
        if let refusal = state.preorderRefusal(productID: productID, balance: engine.balance, content: engine.content) {
            Text(refusal.sentence)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(spacing: Theme.Spacing.sm) {
                Button { open(product, quote) } label: {
                    row(
                        title: "Open pre-orders · +\(quote.cash.money) now",
                        detail: "Cash today at \(pct(config.price))% of the price. The date has a dollar figure on it now: \(quote.firstRefundCash.money) goes back on a slip.",
                        emphasised: true
                    )
                }
                .buttonStyle(.pressableRow)
                Button { dismiss() } label: {
                    row(
                        title: "Sell it all at launch",
                        detail: "Full price in the launch week, and a slip only costs face.",
                        emphasised: false
                    )
                }
                .buttonStyle(.pressableRow)
            }
        }
    }

    private func row(title: String, detail: String, emphasised: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(emphasised ? Theme.accent : .primary)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func open(_ product: Product, _ quote: PreorderQuote) {
        let refusal = state.preorderRefusal(productID: productID, balance: engine.balance, content: engine.content)
        shell.toasts.send(
            .openPreorders(productID: productID),
            to: engine,
            ack: "\(product.name): \(quote.units) pre-ordered, \(quote.cash.money) in",
            rejected: refusal?.sentence ?? "Nobody would pre-order that.",
            icon: "cart.fill"
        )
        Haptics.commit()
        dismiss()
    }

    private func pct(_ value: Double) -> Int { Int((value * 100).rounded()) }
}

/// Launch day: the pre-orders the build ships with, and whether the
/// reviews kept the forecast they were sold on. Nothing for a launch that
/// never pre-sold.
struct PreorderLaunchRow: View {
    let engine: GameEngine
    let product: Product

    var body: some View {
        if let book = product.preorders, book.units > 0, case .released(let info) = product.stage {
            CardView("Pre-orders", systemImage: "shippingbox.fill") {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    let when = AnnounceEventPresenter.dateLabel(book.openedDay, today: engine.state.day)
                    if book.outstanding > 0 {
                        Text(book.isDelivered
                            ? "\(book.deliveredUnits) pre-orders went out with the launch, paid for on \(when)."
                            : book.deliveredUnits > 0
                                ? "\(book.deliveredUnits) of \(book.outstanding) pre-orders delivered, paid for on \(when). Until the rest are out, the weeks earn only on the buyers after them."
                                : "\(book.outstanding) pre-orders ship with it, paid for on \(when). The launch weeks earn only on the buyers after them.")
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if book.refundedUnits > 0 {
                        Text("\(book.refundedUnits) were refunded when the date slipped (\(book.refundedCash.money)).")
                            .font(.footnote)
                            .foregroundStyle(Theme.warning)
                    }
                    if product.preordersOverpromised {
                        Label(
                            "Overpromised: they were sold a \(Int(book.forecastQuality.rounded())). The press gave it \(info.averageReviewScore).",
                            systemImage: "star.slash.fill"
                        )
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.negativeCash)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// `-autoRoute t5-preorders`: the pre-order sheet the next `PreorderRow`
/// for this product should open.
@MainActor
enum PreorderRoute {
    static var sheetRequest: UUID?

    static func takeSheetRequest(for productID: UUID) -> Bool {
        guard sheetRequest == productID else { return false }
        sheetRequest = nil
        return true
    }
}

// MARK: end T5
