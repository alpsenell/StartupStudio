import Foundation
import TycoonContent
import TycoonEngine

// The WS-A pacing bots: four deliberately one-note strategies that
// `BalanceTargetsTests` measures the economy against. They live beside
// `SimRunner`'s original three (which predate the pacing pass and are kept
// as-is so their long-standing assertions still mean something).

/// Shared helpers for the pacing bots: everyone on one job, and the
/// "am I done?" gates the bots ship on.
enum BotHelp {
    /// Puts every employee on `assignment` (skipping those already there).
    static func assignAll(_ state: GameState, to assignment: Assignment) -> [GameAction] {
        state.employees
            .filter { $0.assignment != assignment }
            .map { .assign(employeeID: $0.id, to: assignment) }
    }

    /// Whether every point pool of an in-development product is full.
    static func isComplete(_ product: Product, _ content: ContentCatalog) -> Bool {
        guard case .development(let dev) = product.stage,
              let type = content.productType(product.typeID)
        else { return false }
        return dev.designPts >= type.designPts
            && dev.codePts >= type.codePts
            && dev.polishPts >= type.polishPts
    }

    /// Whether an in-development product clears the ship gate.
    static func clearsShipGate(
        _ product: Product,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> Bool {
        guard case .development(let dev) = product.stage,
              let type = content.productType(product.typeID)
        else { return false }
        return dev.codePts >= balance.shipCodeThreshold * type.codePts
    }

    /// The best affordable contract offer: the highest payout whose penalty
    /// could not sink the company on its own.
    static func bestOffer(_ state: GameState) -> ContractOffer? {
        state.contractOffers
            .filter { $0.penalty <= state.company.cash }
            .max { $0.payout < $1.payout }
    }
}

/// The archetype solo founder: never hires, never crunches, builds one
/// mobile app at a time on a balanced focus and ships only when all three
/// pools are full. Measures "how long is the first product, and is it any
/// good?".
struct SoloSlowBot: BotPolicy {
    let name = "solo-slow"

    func actions(
        for state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameAction] {
        if let product = state.productsInDevelopment.first {
            if BotHelp.isComplete(product, content) {
                return [.ship(productID: product.id)]
            }
            return BotHelp.assignAll(state, to: .product(product.id))
        }
        return [.startProduct(
            typeID: "mobile_app",
            topicID: "fitness",
            name: "Solo \(state.products.count + 1)",
            focus: .balanced
        )]
    }
}

/// Growth at any cost: crunches, hires the strongest affordable candidate up
/// to the office cap, upgrades the office the moment it is affordable with a
/// month of payroll to spare, and ships at the code gate — but hands out a
/// raise to anyone whose morale slips, so it measures "can you grow fast if
/// you do look after people?".
struct CrunchHireBot: BotPolicy {
    let name = "crunch-hire"
    /// Weeks of payroll kept in the bank before hiring.
    let hireRunwayWeeks = 6
    let raiseMoraleFloor = 45.0

    func actions(
        for state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameAction] {
        var actions: [GameAction] = []
        if state.life.schedule != .crunch {
            actions.append(.setWorkSchedule(.crunch))
        }
        if state.economy.workPace != .crunch {
            actions.append(.setWorkPace(.crunch))
        }

        let payroll = state.employees.reduce(0) { $0 + $1.weeklySalary }
        if state.headcount < balance.office(state.company.officeTier).headcountCap,
           let candidate = state.candidatePool.max(by: { $0.skills.total < $1.skills.total }),
           state.company.cash > (payroll + candidate.weeklySalary) * hireRunwayWeeks {
            actions.append(.hire(candidateID: candidate.id))
        }

        // Keep people: anyone drifting down gets a raise.
        for employee in state.employees
        where !employee.isFounder && employee.morale < raiseMoraleFloor {
            actions.append(.adjustSalary(
                employeeID: employee.id,
                weeklySalary: Int(Double(employee.weeklySalary) * 1.2)
            ))
        }
        // A resignation notice is answered with a raise and a promotion.
        if let pending = state.economy.pendingResignation,
           let employee = state.employee(id: pending.employeeID) {
            actions.append(.adjustSalary(
                employeeID: employee.id,
                weeklySalary: Int(Double(employee.weeklySalary) * 1.3)
            ))
        }

        if let next = state.company.officeTier.next,
           state.company.cash >= balance.office(next).upgradeCost + payroll * 4 {
            actions.append(.upgradeOffice)
        }

        if let product = state.productsInDevelopment.first {
            if BotHelp.clearsShipGate(product, balance, content) {
                actions.append(.ship(productID: product.id))
            } else {
                actions.append(contentsOf: BotHelp.assignAll(state, to: .product(product.id)))
            }
        } else {
            actions.append(.startProduct(
                typeID: "mobile_app",
                topicID: "fitness",
                name: "Sprint \(state.products.count + 1)",
                focus: PhaseFocus(design: 2, code: 6, polish: 2)
            ))
        }
        return actions
    }
}

/// Plays the recurring-revenue game: contracts pay the bills while half the
/// crew researches its way to `cloud_infrastructure`, then it builds one SaaS
/// platform to full completion and lives off the subscriptions, keeping
/// bodies on support so live bugs never eat into churn.
struct SaaSBuilderBot: BotPolicy {
    let name = "saas-builder"
    /// Below this the studio drops research and works for money.
    let cashFloor = 18_000
    /// The research path to the tech that unlocks `saas_platform`.
    static let path = [
        "code_reviews", "version_control", "automated_testing",
        "agile_sprints", "cloud_infrastructure",
    ]

    func actions(
        for state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameAction] {
        var actions: [GameAction] = []

        if state.headcount < balance.office(state.company.officeTier).headcountCap,
           state.company.cash > 30_000,
           let candidate = state.candidatePool.max(by: { $0.skills.total < $1.skills.total }) {
            actions.append(.hire(candidateID: candidate.id))
        }
        if let next = state.company.officeTier.next, next != .campus,
           state.company.cash >= balance.office(next).upgradeCost + 40_000 {
            actions.append(.upgradeOffice)
        }

        guard state.isProductTypeUnlocked("saas_platform", content: content) else {
            if state.research.activeNodeID == nil,
               let next = Self.path.first(where: { !state.research.unlocked.contains($0) }) {
                actions.append(.startResearch(nodeID: next))
            }
            var target = state.activeContracts.first?.id
            if target == nil, let offer = BotHelp.bestOffer(state) {
                actions.append(.acceptContract(offerID: offer.id))
                target = offer.id
            }
            // Half the crew researches and half earns — but a one-person
            // studio has to pay the rent before it can think.
            let needsCash = state.company.cash < cashFloor
            for (index, employee) in state.employees.enumerated() {
                let wanted: Assignment = if let target, needsCash || !index.isMultiple(of: 2) {
                    .contract(target)
                } else {
                    .research
                }
                if employee.assignment != wanted {
                    actions.append(.assign(employeeID: employee.id, to: wanted))
                }
            }
            return actions
        }

        let livePlatform = state.products.first { product in
            guard case .released(let info) = product.stage else { return false }
            return product.typeID == "saas_platform" && !info.offMarket
        }

        if let product = state.productsInDevelopment.first {
            if BotHelp.isComplete(product, content) {
                actions.append(.ship(productID: product.id))
            } else {
                actions.append(contentsOf: BotHelp.assignAll(state, to: .product(product.id)))
            }
        } else if let livePlatform {
            // The platform is live: everyone tends it.
            actions.append(contentsOf: BotHelp.assignAll(state, to: .support(livePlatform.id)))
        } else {
            actions.append(.startProduct(
                typeID: "saas_platform",
                topicID: "productivity",
                name: "Platform",
                focus: .balanced
            ))
        }
        return actions
    }
}

/// The bad boss: crunches forever, hires whoever is cheapest, and never
/// praises, raises, promotes, or takes anyone for coffee. The control group
/// for "do people actually leave?".
struct NeglectfulBot: BotPolicy {
    let name = "neglectful"

    func actions(
        for state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameAction] {
        var actions: [GameAction] = []
        if state.life.schedule != .crunch {
            actions.append(.setWorkSchedule(.crunch))
        }
        if state.economy.workPace != .crunch {
            actions.append(.setWorkPace(.crunch))
        }
        if state.headcount < balance.office(state.company.officeTier).headcountCap,
           state.company.cash > 25_000,
           let cheapest = state.candidatePool.min(by: { $0.weeklySalary < $1.weeklySalary }) {
            actions.append(.hire(candidateID: cheapest.id))
        }

        if let product = state.productsInDevelopment.first {
            if BotHelp.clearsShipGate(product, balance, content) {
                actions.append(.ship(productID: product.id))
            } else {
                actions.append(contentsOf: BotHelp.assignAll(state, to: .product(product.id)))
            }
        } else {
            actions.append(.startProduct(
                typeID: "mobile_app",
                topicID: "social",
                name: "Grind \(state.products.count + 1)",
                focus: PhaseFocus(design: 2, code: 6, polish: 2)
            ))
        }
        return actions
    }
}
