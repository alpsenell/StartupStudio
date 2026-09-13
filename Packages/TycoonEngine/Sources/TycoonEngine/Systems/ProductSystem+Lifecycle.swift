import Foundation
import TycoonContent

// MARK: K2 (product lifecycle)

/// Iteration 15 — K2. Retire a product, replace it with its v2, move its
/// price with the cost printed.
///
/// Three actions, each sent only by a player's tap in the app
/// (`sunsetProduct`, `shipReplacing`, `repriceProduct`); no bot sends any of
/// them and nothing here draws from `rng` or `worldRNG` beyond what `ship`
/// already draws when a successor ships. Every gate is `LifecycleRefusal`'s,
/// so a refusal returns no events and the app says why.
extension ProductSystem {
    /// Retires a live product: off the market, the book gone, the day
    /// written. Whoever was on its support desk goes back to the bench.
    static func sunset(
        productID: UUID,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard state.lifecycleSunsetRefusal(productID: productID) == nil,
              let index = state.products.firstIndex(where: { $0.id == productID }),
              case .released(var info) = state.products[index].stage
        else { return [] }

        let book = info.isSubscription ? info.subscribers : 0
        retire(&info, day: state.day)
        state.products[index].stage = .released(info)
        for employeeIndex in state.employees.indices
        where state.employees[employeeIndex].assignment == .support(productID) {
            state.employees[employeeIndex].assignment = .idle
        }
        return [.lifecycleSunset(productID: productID, subscribers: book, day: state.day)]
    }

    /// Ships `productID` as `ship` does, with `parentID` left out of its
    /// launch saturation and genre fatigue, then retires the parent the
    /// same day and opens the successor's book with the carried share of
    /// the parent's (one-time products carry the parent's hype). The
    /// parent's support desk moves to the successor with its customers.
    static func shipReplacing(
        productID: UUID,
        parentID: UUID,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog,
        // MARK: T2 (the build) — P1: the price named on the ship sheet.
        tier: PriceTier = .standard
        // MARK: end T2
    ) -> [GameEvent] {
        guard state.lifecycleReplaceRefusal(
                  productID: productID, parentID: parentID, balance: balance, content: content
              ) == nil,
              let carry = state.lifecycleCarry(from: parentID, balance: balance)
        else { return [] }

        let shipped = ship(
            productID: productID, state: &state, balance: balance, content: content,
            excludingFromSaturation: parentID,
            // MARK: T2 (the build)
            tier: tier
            // MARK: end T2
        )
        guard !shipped.isEmpty,
              let index = state.products.firstIndex(where: { $0.id == productID }),
              case .released(var info) = state.products[index].stage,
              let parentIndex = state.products.firstIndex(where: { $0.id == parentID }),
              case .released(var parent) = state.products[parentIndex].stage
        else { return shipped }

        retire(&parent, day: state.day)
        state.products[parentIndex].stage = .released(parent)

        if info.isSubscription {
            info.subscribers = carry.subscribers
        } else {
            info.liveHype += carry.hype
        }
        // The forecast frozen for launch day was read this morning, with
        // the parent still counted; launch day says what actually applied.
        info.launchForecast?.marketScale = info.launchMarketScale
        state.products[index].stage = .released(info)
        state.products[index].parentID = parentID

        for employeeIndex in state.employees.indices
        where state.employees[employeeIndex].assignment == .support(parentID) {
            state.employees[employeeIndex].assignment = .support(productID)
        }
        return shipped + [.lifecycleReplaced(
            productID: productID, parentID: parentID, carried: carry.subscribers, day: state.day
        )]
    }

    /// The priced price change. A rise churns the book the day it lands (a
    /// one-time product sells ×`riseUnitsFactor` for `riseWeeks` instead);
    /// a cut is the quarter's sale when one is due — one bumper week read
    /// in `postWeeklySales` and a little standing in the topic. Either way
    /// the next change waits `changeCooldownDays`.
    static func reprice(
        productID: UUID,
        tier: PriceTier,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard state.lifecycleRepriceRefusal(productID: productID, tier: tier, balance: balance) == nil,
              let change = state.lifecyclePriceChange(productID: productID, to: tier, balance: balance),
              let index = state.products.firstIndex(where: { $0.id == productID }),
              case .released(var info) = state.products[index].stage
        else { return [] }

        info.priceTier = tier
        info.lastPriceChangeDay = state.day
        if change.isRise {
            if info.isSubscription {
                info.subscribers = max(0, info.subscribers - change.subscribersLost)
            } else {
                info.priceRiseUntilDay = state.day + change.riseWeeks * GameState.daysPerWeek
            }
        }
        if change.isSale {
            info.lastSaleDay = state.day
        }
        state.products[index].stage = .released(info)
        if change.isSale {
            StandingSystem.adjust(
                change.saleStanding, in: state.products[index].topicID, &state, balance
            )
        }
        return [.lifecyclePriceMoved(
            productID: productID, from: change.from, to: tier,
            subscribersLost: change.isRise ? change.subscribersLost : 0,
            sale: change.isSale, day: state.day
        )]
    }

    /// Off the market by the player's hand: no book, and the day it went.
    private static func retire(_ info: inout ReleaseInfo, day: Int) {
        info.offMarket = true
        info.subscribers = 0
        info.sunsetDay = day
    }
}

// MARK: end K2
