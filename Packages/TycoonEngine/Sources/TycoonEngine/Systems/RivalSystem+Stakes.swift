import Foundation
import TycoonContent

// Iteration 17 — T7 (press and stakes): the stake's verbs and its week.
// Read by `RivalSystem` at five marked points (the weekly pass, the fold,
// an acquisition, the poach odds, the price war) and by the reducer for
// `.buyRivalStake` / `.sellRivalStake`. Nothing here draws; with no stakes
// every function returns on its first line.

extension RivalSystem {
    /// Buys a `percent` stake in `rivalID` for company cash. A quarter of
    /// the price becomes their strength. Ignored when the quote refuses.
    static func buyRivalStake(
        rivalID: UUID,
        percent: Double,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard let quote = state.rivalStakeQuote(rivalID: rivalID, percent: percent, balance: balance),
              quote.blocker == nil,
              let index = state.rivals.rivals.firstIndex(where: { $0.id == rivalID })
        else { return [] }
        let name = state.rivals.rivals[index].name
        state.company.cash -= quote.price
        state.ledger.post(LedgerEntry(
            day: state.day,
            amount: -quote.price,
            category: .other,
            label: "Bought \(Int((percent * 100).rounded()))% of \(name)"
        ))
        state.rivals.rivals[index].strength = min(100, state.rivals.rivals[index].strength + quote.strengthGain)
        state.rivals.stakes.append(RivalStake(
            rivalID: rivalID, percent: quote.percent, paid: quote.price, sinceDay: state.day
        ))
        return [.rivalStakeBought(rivalID: rivalID, name: name, percent: quote.percent, price: quote.price, day: state.day)]
    }

    /// Sells the stake back at `valuation × sellBack × percent`. Ignored
    /// with no stake, or once the company has had its ending.
    static func sellRivalStake(
        rivalID: UUID,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard state.gameOver == nil,
              let stake = state.rivalStake(in: rivalID),
              let rival = state.rivals.rival(id: rivalID)
        else { return [] }
        let value = state.rivalStakeSaleValue(stake, balance: balance)
        state.company.cash += value
        state.ledger.post(LedgerEntry(
            day: state.day,
            amount: value,
            category: .other,
            label: "Sold \(stake.percentLabel) of \(rival.name)"
        ))
        state.rivals.stakes.removeAll { $0.rivalID == rivalID }
        return [.rivalStakeSold(
            rivalID: rivalID, name: rival.name, percent: stake.percent,
            price: value, paid: stake.paid, day: state.day
        )]
    }

    /// The weekly dividend, one ledger line per stake that earned
    /// something. On the rivals' weekly pass, after the folds, so a studio
    /// that folded this week pays nothing. Returns at once with no stakes.
    static func stakeWeek(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) {
        guard !state.rivals.stakes.isEmpty,
              state.day % max(1, balance.rivals.evolveIntervalDays) == 0
        else { return }
        for index in state.rivals.stakes.indices {
            let stake = state.rivals.stakes[index]
            let dividend = state.rivalStakeWeeklyDividend(stake, balance: balance, content: content)
            guard dividend > 0, let rival = state.rivals.rival(id: stake.rivalID) else { continue }
            state.company.cash += dividend
            state.ledger.post(LedgerEntry(
                day: state.day,
                amount: dividend,
                category: .other,
                label: "Dividend: \(stake.percentLabel) of \(rival.name)"
            ))
            state.rivals.stakes[index].dividends += dividend
        }
    }

    /// A folded studio takes the stake with it.
    static func stakeFolded(_ rival: Rival, _ state: inout GameState) -> [GameEvent] {
        guard let stake = state.rivalStake(in: rival.id) else { return [] }
        state.rivals.stakes.removeAll { $0.rivalID == rival.id }
        return [.rivalStakeLost(
            rivalID: rival.id, name: rival.name, percent: stake.percent, paid: stake.paid, day: state.day
        )]
    }

    /// An acquired studio's stake is part of what was bought: it closes
    /// with no money changing hands (the cash price already counted it).
    static func stakeAbsorbed(_ rivalID: UUID, _ state: inout GameState) {
        guard !state.rivals.stakes.isEmpty else { return }
        state.rivals.stakes.removeAll { $0.rivalID == rivalID }
    }
}
