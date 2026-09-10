import Foundation
import TycoonContent

// MARK: K2 (product lifecycle)

/// Iteration 15 — K2. The product's lifecycle, read: whether a product can
/// be retired, replaced by its v2 or re-priced now, and what each would
/// cost, in the numbers the engine will use. The app prints these on the
/// buttons; the systems (`ProductSystem+Lifecycle`) gate on the same
/// functions, so the sentence the player reads is the reason the engine
/// used.
///
/// Pure reads over `GameState`; no draws.
public enum LifecycleRefusal: Equatable, Sendable {
    /// Not a released product, or already off the market.
    case notLive
    /// A patch is in flight on it; retiring it would strand the patch.
    case patchRunning
    /// The successor is not a build that could ship today.
    case notShippable
    /// Replacing takes the same product type in the same topic.
    case notTheSameKind
    /// The price is already that.
    case sameTier
    /// The last change was too recent; the next is allowed on `untilDay`.
    case cooldown(untilDay: Int)

    public var sentence: String {
        switch self {
        case .notLive: "It is not on the market."
        case .patchRunning: "A patch is still being built for it. Let it land first."
        case .notShippable: "The build is not ready to ship yet."
        case .notTheSameKind: "Only a build of the same type, in the same topic, can replace it."
        case .sameTier: "It is already at that price."
        case .cooldown(let day): "Customers are still reading the last change. The next can come on day \(day)."
        }
    }
}

/// What a replacing successor opens with.
public struct LifecycleCarry: Equatable, Sendable {
    /// Subscribers the successor opens with (0 for a one-time product).
    public var subscribers: Int
    /// Post-launch hype the successor opens with (one-time products).
    public var hype: Double
    /// The parent's own book today.
    public var parentSubscribers: Int
    public var isSubscription: Bool
}

/// What a priced price change will do, before it is made.
public struct LifecyclePriceChange: Equatable, Sendable {
    public var from: PriceTier
    public var to: PriceTier
    /// Up the ladder (budget → standard → premium).
    public var isRise: Bool
    /// Subscribers a rise churns the day it lands.
    public var subscribersLost: Int
    /// A rise on a one-time product: sales × this for `riseWeeks`.
    public var riseUnitsFactor: Double
    public var riseWeeks: Int
    /// A cut that is the quarter's sale: one week × `saleBump`, and
    /// `saleStanding` in the topic.
    public var isSale: Bool
    public var saleBump: Double
    public var saleStanding: Double
    /// A cut that is not a sale: the day the next sale is available.
    public var nextSaleDay: Int?
    /// Days until the next change is allowed after this one.
    public var cooldownDays: Int
    public var isSubscription: Bool
}

extension GameState {
    /// Why `sunsetProduct` would be refused now; `nil` when it would land.
    public func lifecycleSunsetRefusal(productID: UUID) -> LifecycleRefusal? {
        guard let product = product(id: productID),
              case .released(let info) = product.stage, !info.offMarket
        else { return .notLive }
        if economy.update(for: productID) != nil { return .patchRunning }
        return nil
    }

    /// Live products `productID` (a build in development) could replace:
    /// released, on the market, same type and topic, no patch in flight.
    /// The biggest book first, then the newest.
    public func lifecycleReplaceableParents(for productID: UUID) -> [Product] {
        guard let build = product(id: productID), case .development = build.stage else { return [] }
        return products
            .filter { other in
                guard other.id != productID,
                      other.typeID == build.typeID, other.topicID == build.topicID,
                      case .released(let info) = other.stage, !info.offMarket
                else { return false }
                return economy.update(for: other.id) == nil
            }
            .sorted { lhs, rhs in
                let l = lhs.releaseInfo, r = rhs.releaseInfo
                if (l?.subscribers ?? 0) != (r?.subscribers ?? 0) {
                    return (l?.subscribers ?? 0) > (r?.subscribers ?? 0)
                }
                return (l?.launchDay ?? 0) > (r?.launchDay ?? 0)
            }
    }

    /// Why `shipReplacing` would be refused now; `nil` when it would land.
    public func lifecycleReplaceRefusal(
        productID: UUID,
        parentID: UUID,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> LifecycleRefusal? {
        guard let build = product(id: productID),
              case .development(let dev) = build.stage,
              let type = content.productType(build.typeID),
              dev.codePts >= balance.shipCodeThreshold * type.codePts
        else { return .notShippable }
        if let refusal = lifecycleSunsetRefusal(productID: parentID) { return refusal }
        guard let parent = product(id: parentID), parentID != productID,
              parent.typeID == build.typeID, parent.topicID == build.topicID
        else { return .notTheSameKind }
        return nil
    }

    /// What a successor would open with if it replaced `parentID` today.
    public func lifecycleCarry(from parentID: UUID, balance: BalanceConfig) -> LifecycleCarry? {
        guard let info = product(id: parentID)?.releaseInfo else { return nil }
        let config = balance.lifecycle
        return LifecycleCarry(
            subscribers: info.isSubscription
                ? Int((Double(info.subscribers) * config.successorBookCarry).rounded())
                : 0,
            hype: info.isSubscription ? 0 : info.liveHype * config.successorHypeCarry,
            parentSubscribers: info.subscribers,
            isSubscription: info.isSubscription
        )
    }

    /// Why `repriceProduct` would be refused now; `nil` when it would land.
    public func lifecycleRepriceRefusal(
        productID: UUID,
        tier: PriceTier,
        balance: BalanceConfig
    ) -> LifecycleRefusal? {
        guard let info = product(id: productID)?.releaseInfo, !info.offMarket else { return .notLive }
        if info.priceTier == tier { return .sameTier }
        if let last = info.lastPriceChangeDay {
            let until = last + balance.lifecycle.changeCooldownDays
            if day < until { return .cooldown(untilDay: until) }
        }
        return nil
    }

    /// What moving `productID` to `tier` would do today. `nil` for
    /// anything not released.
    public func lifecyclePriceChange(
        productID: UUID,
        to tier: PriceTier,
        balance: BalanceConfig
    ) -> LifecyclePriceChange? {
        guard let info = product(id: productID)?.releaseInfo else { return nil }
        let config = balance.lifecycle
        let ladder = PriceTier.allCases
        let from = ladder.firstIndex(of: info.priceTier) ?? 1
        let to = ladder.firstIndex(of: tier) ?? 1
        let isRise = to > from
        let isCut = to < from
        let saleOpen = info.lastSaleDay.map { day - $0 >= config.saleIntervalDays } ?? true
        return LifecyclePriceChange(
            from: info.priceTier,
            to: tier,
            isRise: isRise,
            subscribersLost: isRise && info.isSubscription
                ? Int((Double(info.subscribers) * config.riseChurn).rounded())
                : 0,
            riseUnitsFactor: config.riseUnitsFactor,
            riseWeeks: config.riseWeeks,
            isSale: isCut && saleOpen,
            saleBump: config.saleBump,
            saleStanding: config.saleStanding,
            nextSaleDay: isCut && !saleOpen
                ? info.lastSaleDay.map { $0 + config.saleIntervalDays }
                : nil,
            cooldownDays: config.changeCooldownDays,
            isSubscription: info.isSubscription
        )
    }

    /// What a live product costs to keep running for a week, the number a
    /// retirement saves. 0 for anything off the market.
    public func lifecycleWeeklyHosting(
        productID: UUID,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> Int {
        guard let product = product(id: productID),
              let info = product.releaseInfo, !info.offMarket,
              let type = content.productType(product.typeID)
        else { return 0 }
        return ProductSystem.weeklyHostingCost(for: info, type: type, balance: balance)
    }

    /// Whether something else of the studio's still sells in the topic once
    /// `productID` leaves it, so the topic's standing keeps its retainer.
    public func lifecycleTopicStillHeld(without productID: UUID) -> Bool {
        guard let topicID = product(id: productID)?.topicID else { return false }
        return products.contains { other in
            guard other.id != productID, other.topicID == topicID,
                  case .released(let info) = other.stage
            else { return false }
            return !info.offMarket
        }
    }
}

extension Product {
    /// The release, if this product has shipped.
    public var releaseInfo: ReleaseInfo? {
        if case .released(let info) = stage { return info }
        return nil
    }
}

// MARK: end K2
