import Foundation
import TycoonContent

// Iteration 17 — T7 (press and stakes): `-autoRoute t7-…` dresses the
// loaded save for a screenshot. Debug builds only; nothing in the game
// sends `.pressStakeDebugSeed`.

#if DEBUG
enum PressStakeDebugSeed {
    /// - `standing`: the four outlets at warm, friendly, cool and cold.
    /// - `launch`: `standing`, then the most finished shippable build ships.
    /// - `exclusive`: `launch`, with the first outlet given the exclusive.
    /// - `paper`: `exclusive`, then a week ticks so the issue prints it.
    /// - `stake`: 25% of the strongest rival, cash topped up to afford it.
    static func apply(
        scenario: String,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        var events: [GameEvent] = []
        let outlets = balance.reviewOutlets
        if ["standing", "launch", "exclusive", "paper"].contains(scenario) {
            for (outlet, standing) in zip(outlets, [12.0, 4, -4, -11]) {
                state.company.pressStanding[outlet] = standing
            }
        }
        if ["launch", "exclusive", "paper"].contains(scenario) {
            let shippable = state.products.compactMap { product -> (UUID, Double)? in
                guard case .development(let dev) = product.stage,
                      let type = content.productType(product.typeID),
                      dev.codePts >= balance.shipCodeThreshold * type.codePts
                else { return nil }
                return (product.id, dev.codePts / max(1, type.codePts))
            }
            if let pick = shippable.max(by: { $0.1 < $1.1 }) {
                events += ProductSystem.ship(productID: pick.0, state: &state, balance: balance, content: content)
                if scenario != "launch", let first = outlets.first {
                    events += PressSystem.grantExclusive(
                        productID: pick.0, outlet: first, state: &state, balance: balance
                    )
                }
            }
        }
        if scenario == "paper" {
            for _ in 0..<7 { events += Reducer.tick(&state, balance: balance, content: content) }
        }
        if scenario == "stake" {
            let strongest = state.rivals.rivals.max { lhs, rhs in
                if lhs.strength != rhs.strength { return lhs.strength < rhs.strength }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            if let rival = strongest, state.rivalStake(in: rival.id) == nil,
               let quote = state.rivalStakeQuote(rivalID: rival.id, percent: 0.25, balance: balance) {
                if state.company.cash < quote.price { state.company.cash = quote.price + 50_000 }
                events += RivalSystem.buyRivalStake(
                    rivalID: rival.id, percent: 0.25, state: &state, balance: balance
                )
            }
        }
        return events
    }
}
#endif
