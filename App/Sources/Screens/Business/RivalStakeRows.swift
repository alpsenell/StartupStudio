import SwiftUI
import TycoonContent
import TycoonEngine

// Iteration 17 — T7 (press and stakes): a stake in a rival, on screen.
//
// `RivalStakeRows` sits beside *Acquire* on the rival's profile (the one
// home of the verb); `RivalHoldingsCard` lists what you hold on the Rivals
// segment; `RivalStakeAssetCard` is the asset line on Finances. The engine
// is the enforcer: every gate here reads `rivalStakeQuote`.

/// Buy 5, 10 or 25% of them, or sell what you hold.
struct RivalStakeRows: View {
    let engine: GameEngine
    let rival: Rival

    @State private var confirmingPercent: Double?
    @State private var confirmingSale = false

    private var state: GameState { engine.state }
    private var balance: BalanceConfig { engine.balance }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Divider()
            if let stake = state.rivalStake(in: rival.id) {
                holding(stake)
            } else {
                offer
            }
        }
        .confirmationDialog(
            confirmTitle,
            isPresented: Binding(get: { confirmingPercent != nil }, set: { if !$0 { confirmingPercent = nil } }),
            titleVisibility: .visible
        ) {
            if let percent = confirmingPercent,
               let quote = state.rivalStakeQuote(rivalID: rival.id, percent: percent, balance: balance) {
                Button("Buy \(label(percent)) for \(quote.price.money)") {
                    _ = engine.send(.buyRivalStake(rivalID: rival.id, percent: percent))
                }
            }
            Button("Keep the cash", role: .cancel) {}
        } message: {
            Text(confirmMessage)
        }
        .confirmationDialog(
            saleTitle,
            isPresented: $confirmingSale,
            titleVisibility: .visible
        ) {
            Button("Sell", role: .destructive) {
                _ = engine.send(.sellRivalStake(rivalID: rival.id))
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("The dividend stops, and so does the look at their plans. The strength your money bought them stays.")
        }
    }

    // MARK: Buying

    private var offer: some View {
        let quotes = balance.stakes.percents.compactMap {
            state.rivalStakeQuote(rivalID: rival.id, percent: $0, balance: balance)
        }
        let largest = quotes.last
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Or buy a stake")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(quotes, id: \.percent) { quote in
                    Button {
                        Haptics.tap()
                        confirmingPercent = quote.percent
                    } label: {
                        VStack(spacing: 2) {
                            Text(label(quote.percent))
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            Text(quote.price.money)
                                .font(Theme.Typography.number(.caption2))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(quote.blocker != nil)
                    .accessibilityLabel("Buy \(label(quote.percent)) of \(rival.name) for \(quote.price.money)")
                }
            }
            if let blocker = quotes.first(where: { $0.blocker != nil })?.blocker, quotes.allSatisfy({ $0.blocker != nil }) {
                Text(blocker)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Theme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let largest {
                Text(offerTerms(largest))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// What the biggest stake does, now and later.
    private func offerTerms(_ quote: RivalStakeQuote) -> String {
        let dividend = state.rivalStakeWeeklyDividend(
            RivalStake(rivalID: rival.id, percent: quote.percent, paid: quote.price, sinceDay: state.day),
            balance: balance, content: engine.content
        )
        let gain = String(format: "%.1f", quote.strengthGain)
        let roadmap = Int((balance.stakes.roadmapFrom * 100).rounded())
        let sellBack = String(format: "%.1f", balance.stakes.sellBack)
        return String(
            localized: "At \(label(quote.percent)): a quarter of the price becomes their strength (+\(gain)), and it pays \(dividend.money) a week today from what they sell. From \(roadmap)% you see their next topic; their recruiters call half as often; no price war from them. It sells back at \(sellBack)× their valuation, and goes if they fold.",
            comment: "Rival profile: what a stake costs now and what it does later"
        )
    }

    private var confirmTitle: String {
        guard let percent = confirmingPercent,
              let quote = state.rivalStakeQuote(rivalID: rival.id, percent: percent, balance: balance)
        else { return "" }
        return String(localized: "Buy \(label(percent)) of \(rival.name) for \(quote.price.money)?", comment: "Rival profile: the stake's confirmation title")
    }

    private var confirmMessage: String {
        guard let percent = confirmingPercent,
              let quote = state.rivalStakeQuote(rivalID: rival.id, percent: percent, balance: balance)
        else { return "" }
        return offerTerms(quote)
    }

    // MARK: Holding

    private func holding(_ stake: RivalStake) -> some View {
        let sale = state.rivalStakeSaleValue(stake, balance: balance)
        let mark = state.rivalStakeMarkValue(stake, balance: balance)
        let weekly = state.rivalStakeWeeklyDividend(stake, balance: balance, content: engine.content)
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "chart.pie.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Text("You own \(stake.percentLabel) of \(rival.name)")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
            }
            Text("Paid \(stake.paid.money) · worth \(mark.money) today · \(weekly.money) this week, \(stake.dividends.money) so far")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let topicID = state.rivalStakeRoadmapTopic(rivalID: rival.id, balance: balance) {
                Text("Their next launch: \(engine.content.topic(topicID)?.name ?? topicID.capitalized)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
            Text("Their recruiters call half as often, and they will not start a price war with you. Acquiring them costs \(Int(((1 - stake.percent) * 100).rounded()))% of the price.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Haptics.tap()
                confirmingSale = true
            } label: {
                Text("Sell \(stake.percentLabel) for \(sale.money)")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(sale + stake.dividends >= stake.paid ? Theme.positiveCash : Theme.warning)
            .disabled(state.gameOver != nil)
        }
    }

    private var saleTitle: String {
        guard let stake = state.rivalStake(in: rival.id) else { return "" }
        let sale = state.rivalStakeSaleValue(stake, balance: balance)
        return String(localized: "Sell \(stake.percentLabel) of \(rival.name) for \(sale.money)? It cost \(stake.paid.money).", comment: "Rival profile: the stake sale's confirmation title")
    }

    private func label(_ percent: Double) -> String {
        "\(Int((percent * 100).rounded()))%"
    }
}

/// The Rivals segment's holdings: one line per stake.
struct RivalHoldingsCard: View {
    let engine: GameEngine

    var body: some View {
        CardView("Your stakes", systemImage: "chart.pie.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                ForEach(engine.state.rivals.stakes, id: \.rivalID) { stake in
                    let name = engine.state.rivals.rival(id: stake.rivalID)?.name ?? "—"
                    let mark = engine.state.rivalStakeMarkValue(stake, balance: engine.balance)
                    let weekly = engine.state.rivalStakeWeeklyDividend(stake, balance: engine.balance, content: engine.content)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(stake.percentLabel) of \(name)")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        Text("Worth \(mark.money) · paid \(stake.paid.money) · \(weekly.money) a week")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(mark >= stake.paid ? Theme.positiveCash : .secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

/// Finances: what the company owns of other companies.
struct RivalStakeAssetCard: View {
    let engine: GameEngine

    var body: some View {
        let state = engine.state
        let stakes = state.rivals.stakes
        let paid = stakes.reduce(0) { $0 + $1.paid }
        let mark = stakes.reduce(0) { $0 + state.rivalStakeMarkValue($1, balance: engine.balance) }
        let sale = stakes.reduce(0) { $0 + state.rivalStakeSaleValue($1, balance: engine.balance) }
        let dividends = stakes.reduce(0) { $0 + $1.dividends }
        CardView("Stakes in rivals", systemImage: "chart.pie.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(alignment: .top, spacing: Theme.Spacing.xl) {
                    LaunchStat(label: String(localized: "Worth today", comment: "Finances: the stakes marked to market"), value: mark.money, tint: mark >= paid ? Theme.positiveCash : .primary)
                    LaunchStat(label: String(localized: "Paid", comment: "Finances: what the stakes cost"), value: paid.money)
                    LaunchStat(label: String(localized: "Dividends", comment: "Finances: dividends received from stakes"), value: dividends.money, tint: Theme.positiveCash)
                }
                Text("Sells back for \(sale.money) today. Not counted in the company's valuation or the runway.")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
