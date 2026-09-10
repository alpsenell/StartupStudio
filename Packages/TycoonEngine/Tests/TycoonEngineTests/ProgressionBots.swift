import Foundation
import TycoonContent
import TycoonEngine
import TycoonBots

// Two bots for the progression acceptance bar, played through the same
// headless `SimRunner` as the balance harness. (Named `Goal…` at merge:
// WS-A's balance harness independently grew a `CrunchHireBot` and a
// `SoloSlowBot` in PacingBots.swift with different policies, and both sets
// are wanted — these two answer "can a player reach the chapter goals?",
// A's answer "does the economy pace correctly?".) The balance bots
// deliberately do one thing each (grind contracts, ship fast, alternate);
// these two are shaped like *players*, because chapter goals ask about the
// whole game — hiring, moving office, researching, taking a weekend, going
// on a date — and a bot that never leaves the garage can't answer that.

/// The engaged player: builds and ships continuously, hires whenever the
/// office has room and the account can carry the salary, upgrades as soon
/// as the next tier is affordable, keeps research running, spends weekends
/// on something, and asks somebody out when the meters allow.
struct GoalCrunchBot: BotPolicy {
    let name = "goal-crunch"
    let hireCashFloor = 12_000
    let upgradeCashBuffer = 8_000
    let productCashFloor = 4_000

    func actions(
        for state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameAction] {
        var actions: [GameAction] = []
        var researcherID: UUID?

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

        // Somebody is always learning something — which needs somebody
        // *on* research. Before the balance pass this block only ever
        // looked at `research.banked`, and nothing in the bot ever put a
        // person on the bench, so `banked` stayed at zero for two game
        // years and `g2_research_two_techs` was unreachable by
        // construction. One pair of hands out of three, once there are
        // three.
        if state.headcount >= 3,
           !state.employees.contains(where: { $0.assignment == .research }),
           let spare = state.employees.last(where: { !$0.isFounder }) {
            actions.append(.assign(employeeID: spare.id, to: .research))
            researcherID = spare.id
        } else {
            researcherID = state.employees.first { $0.assignment == .research }?.id
        }
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
                where employee.assignment != .product(product.id)
                    && employee.id != researcherID {
                    actions.append(.assign(employeeID: employee.id, to: .product(product.id)))
                }
            }
        } else if state.company.cash > productCashFloor {
            // Rotates topics, and moves up to web apps once there is a
            // team. Before the balance pass this shipped a fitness mobile
            // app every time: `saturationPerRelease` is 0.75 over a
            // 182-day window and `genreFatigueFactor` 0.78 over 84, so by
            // the fourth one it was launching into a market it had itself
            // flooded, and the studio never earned the loft.
            actions.append(.startProduct(
                typeID: state.headcount >= 2 ? "web_app" : "mobile_app",
                topicID: BotHelp.topic(forProductNumber: state.products.count),
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

/// The independent player (WS-G, iteration 5): the recurring-revenue
/// studio, played by somebody who has a life and says no to money.
///
/// `SaaSBuilderBot`'s company, unchanged — the platform, the support
/// desk, the fair pay — plus the three things the independent ladder asks
/// for that no pacing bot does: every weekend spent on something (a date
/// once there is somebody to take), a relationship pushed forward whenever
/// the meters allow, and every term sheet turned down. It buys the office
/// once the deeds cost less than a quarter of the bank, and it declares
/// *Still yours* the day it can.
///
/// The tell for the whole feature: it has to reach the ending on some of
/// the seeds inside four years and fail on the rest. Zero means the ladder
/// is the funded one with the numbers filed off; ten means it is free.
struct GoalIndependentBot: BotPolicy {
    let name = "goal-independent"
    private let studio = SaaSBuilderBot()

    func actions(
        for state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameAction] {
        // The ending, the day it opens.
        if state.canStayIndependent(balance: balance) {
            return [.declareIndependence]
        }
        // The studio first: its monthly weekend plan is overridden below,
        // because a later action on the same day wins.
        var actions = studio.actions(for: state, balance: balance, content: content)
        if state.investors.pendingOffer != nil {
            actions.append(.declineInvestment)
        }

        // A life: somebody to go home to, and a weekend that is not rest.
        // `SaaSBuilderBot` plans one weekend a month; this founder plans
        // every one, which is what the ladder's "move in", "marry" and
        // "three children" cost in evenings.
        if !state.life.isAway(day: state.day) {
            let wanted: WeekendActivity = state.life.family.stage == .single ? .friends : .dateNight
            if state.life.plannedActivity != wanted {
                actions.append(.planWeekend(wanted))
            }
        }
        if state.life.family.stage != .married {
            // Ignored by the engine until every gate (meters, days at the
            // stage, the wedding money) is met, so asking daily is harmless.
            actions.append(.advanceRelationship)
        } else {
            actions.append(.haveChild)
        }

        // The deeds, once they are cheap against the bank.
        if !state.city.ownership.isOwned {
            let price = state.officePurchasePrice(in: state.city.district, balance: balance)
            if state.company.cash >= price * 4 {
                actions.append(.buyOffice)
            }
        }
        return actions
    }
}

/// The other end: one person, no hires, no office moves. Builds a product
/// at a time to full completion and ships it. Everything the early chapters
/// ask for has to be reachable by playing like this.
struct GoalSoloBot: BotPolicy {
    let name = "goal-solo"

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
