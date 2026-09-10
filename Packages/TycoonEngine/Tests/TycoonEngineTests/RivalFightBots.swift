import Foundation
import TycoonContent
@testable import TycoonEngine
import TycoonBots

// The WS-A verification bots for the category fight and the incumbent.
// Each is an existing bot plus one idea, so a measured difference is the
// idea's and nothing else's.

/// SoloSlow plus: on a challenge, go budget tier and patch the product that
/// holds the category — and hold the one build slot for that patch, which
/// is the cost the design names ("a build slot for weeks"). Everything
/// else is SoloSlow.
struct DefenderBot: BotPolicy {
    let name = "defender"
    private let base = SoloSlowBot()

    /// Whether the fight's product has been patched since it opened, or
    /// is being patched now.
    private func patched(_ fight: CategoryChallenge, _ state: GameState) -> Bool {
        guard let best = RivalSystem.playerBestProduct(in: fight.topicID, state) else { return true }
        if state.economy.update(for: best.id) != nil { return true }
        guard let product = state.product(id: best.id),
              case .released(let info) = product.stage
        else { return true }
        return (info.lastUpdateDay ?? -1) >= fight.startedDay
    }

    func actions(
        for state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameAction] {
        var actions: [GameAction] = []
        let fights = state.rivals.challenges
        for fight in fights {
            actions.append(.defendCategory(topicID: fight.topicID, defense: .budgetPrice))
            if state.hasFreeDevSlot, !patched(fight, state) {
                actions.append(.defendCategory(topicID: fight.topicID, defense: .patch))
            }
        }
        // The slot is for the patch: no new product while a fight is on
        // and the patch has not run. SoloSlow would start the next build
        // the day the last one shipped.
        let holdingTheSlot = fights.contains { !patched($0, state) }
            && state.productsInDevelopment.isEmpty
        if holdingTheSlot { return actions }
        return actions + base.actions(for: state, balance: balance, content: content)
    }
}

/// The funded founder (`InvestorBot`, growing, buying the trophies) plus
/// one idea: own the category it holds best. In its highest-standing live
/// topic it prices the best product budget and patches it between builds,
/// keeping the founder on the patch — `InvestorBot` deals the crew across
/// the builds in development every day, and a patch nobody works blocks
/// the slot forever — and it defends every challenge the same way.
struct DominatorBot: BotPolicy {
    let name = "dominator"
    private let base = InvestorBot()

    func actions(
        for state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameAction] {
        var actions: [GameAction] = []
        for fight in state.rivals.challenges where fight.isPending {
            actions.append(.defendCategory(topicID: fight.topicID, defense: .budgetPrice))
            if state.hasFreeDevSlot, state.productsInDevelopment.isEmpty {
                actions.append(.defendCategory(topicID: fight.topicID, defense: .patch))
            }
        }
        let live = StandingSystem.liveTopicIDs(state)
        if let topicID = live.max(by: { lhs, rhs in
            let left = state.market.standing(for: lhs)
            let right = state.market.standing(for: rhs)
            if left != right { return left < right }
            return lhs > rhs
        }), let best = RivalSystem.playerBestProduct(in: topicID, state),
           let product = state.product(id: best.id),
           case .released(let info) = product.stage {
            if info.priceTier != .budget {
                actions.append(.setPriceTier(productID: best.id, tier: .budget))
            }
            // A patch between builds, not on top of a fresh one.
            if state.hasFreeDevSlot, state.productsInDevelopment.isEmpty,
               state.economy.update(for: best.id) == nil,
               state.day - (info.lastUpdateDay ?? -1_000) >= 8 * GameState.daysPerWeek {
                actions.append(.startUpdate(productID: best.id))
            }
        }
        actions.append(contentsOf: base.actions(for: state, balance: balance, content: content))
        // After the base has dealt the crew: the founder works whatever
        // patch is in flight.
        if let patch = state.economy.updates.first,
           let founder = state.employees.first(where: \.isFounder) {
            actions.append(.assign(employeeID: founder.id, to: .product(patch.productID)))
        }
        return actions
    }
}
