import Foundation
import TycoonContent
import TycoonEngine

// Two bots for the progression acceptance bar, played through the same
// headless `SimRunner` as the balance harness. The balance bots
// deliberately do one thing each (grind contracts, ship fast, alternate);
// these two are shaped like *players*, because chapter goals ask about the
// whole game — hiring, moving office, researching, taking a weekend, going
// on a date — and a bot that never leaves the garage can't answer that.

/// The engaged player: builds and ships continuously, hires whenever the
/// office has room and the account can carry the salary, upgrades as soon
/// as the next tier is affordable, keeps research running, spends weekends
/// on something, and asks somebody out when the meters allow.
struct CrunchHireBot: BotPolicy {
    let name = "crunch-hire"
    let hireCashFloor = 12_000
    let upgradeCashBuffer = 8_000
    let productCashFloor = 4_000

    func actions(
        for state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameAction] {
        var actions: [GameAction] = []

        // Fill the office. Headroom is the engine's rule, so this never
        // sends a hire the reducer would ignore.
        let cap = balance.office(state.company.officeTier).headcountCap
        if state.headcount < cap,
           state.company.cash > hireCashFloor,
           let candidate = state.candidatePool.max(by: { $0.skills.total < $1.skills.total }) {
            actions.append(.hire(candidateID: candidate.id))
        }

        if let next = state.company.officeTier.next,
           state.company.cash >= balance.office(next).upgradeCost + upgradeCashBuffer {
            actions.append(.upgradeOffice)
        }

        // A weekend that isn't rest, and a life beyond the office.
        if state.life.plannedActivity == .rest {
            actions.append(.planWeekend(state.life.family.stage == .single ? .friends : .dateNight))
        }
        if state.life.family.stage == .single,
           state.life.meters.relationships >= balance.life.datingMinRelationships {
            actions.append(.advanceRelationship)
        }

        // Somebody is always learning something.
        if state.research.activeNodeID == nil,
           let node = content.techTree.first(where: { node in
               !state.research.unlocked.contains(node.id)
                   && node.prerequisites.allSatisfy(state.research.unlocked.contains)
                   && state.research.banked >= node.researchCost
                   && state.company.cash >= node.cashCost
           }) {
            actions.append(.startResearch(nodeID: node.id))
        }

        // Build, ship, repeat; anyone spare banks research points.
        if let product = state.productInDevelopment {
            if case .development(let dev) = product.stage,
               let type = content.productType(product.typeID),
               dev.designPts >= type.designPts,
               dev.codePts >= type.codePts,
               dev.polishPts >= type.polishPts {
                actions.append(.ship(productID: product.id))
            } else {
                for employee in state.employees
                where employee.assignment != .product(product.id) {
                    actions.append(.assign(employeeID: employee.id, to: .product(product.id)))
                }
            }
        } else if state.company.cash > productCashFloor {
            actions.append(.startProduct(
                typeID: "mobile_app",
                topicID: "fitness",
                name: "Momentum \(state.products.count + 1)",
                focus: .balanced
            ))
        } else if let offer = state.contractOffers.max(by: { $0.payout < $1.payout }),
                  state.activeContracts.isEmpty,
                  offer.penalty <= state.company.cash {
            actions.append(.acceptContract(offerID: offer.id))
        } else if let job = state.activeContracts.first {
            for employee in state.employees where employee.assignment != .contract(job.id) {
                actions.append(.assign(employeeID: employee.id, to: .contract(job.id)))
            }
        }
        return actions
    }
}

/// The other end: one person, no hires, no office moves. Builds a product
/// at a time to full completion and ships it. Everything the early chapters
/// ask for has to be reachable by playing like this.
struct SoloSlowBot: BotPolicy {
    let name = "solo-slow"

    func actions(
        for state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameAction] {
        var actions: [GameAction] = []

        if let product = state.productInDevelopment {
            if case .development(let dev) = product.stage,
               let type = content.productType(product.typeID),
               dev.designPts >= type.designPts,
               dev.codePts >= type.codePts,
               dev.polishPts >= type.polishPts {
                actions.append(.ship(productID: product.id))
            } else {
                for employee in state.employees
                where employee.assignment != .product(product.id) {
                    actions.append(.assign(employeeID: employee.id, to: .product(product.id)))
                }
            }
        } else {
            actions.append(.startProduct(
                typeID: "mobile_app",
                topicID: "productivity",
                name: "Quiet \(state.products.count + 1)",
                focus: .balanced
            ))
        }
        return actions
    }
}
