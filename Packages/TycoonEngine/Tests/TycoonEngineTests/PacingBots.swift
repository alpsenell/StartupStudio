import Foundation
import TycoonContent
import TycoonEngine

// The WS-A pacing bots: four one-note but *plausible* strategies that
// `BalanceTargetsTests` measures the economy against. They live beside
// `SimRunner`'s original three (which predate the pacing pass and are kept
// as-is so their long-standing assertions still mean something).
//
// Each bot plays like someone who has understood one idea and nothing else
// — so a gate that fails says something about the balance, not about a bot
// doing something no human would do.

/// Shared helpers: crew assignment, the "would I put my name on this?"
/// gates, focus that follows the work, and value hiring.
enum BotHelp {
    /// Topics rotated through so a bot's tenth product isn't its ninth
    /// again — launch saturation punishes that, and a player would notice.
    static let topics = ["fitness", "finance", "productivity", "travel", "music", "health"]

    static func topic(forProductNumber number: Int) -> String {
        topics[number % topics.count]
    }

    /// Puts every employee on `assignment` (skipping those already there).
    static func assignAll(_ state: GameState, to assignment: Assignment) -> [GameAction] {
        state.employees
            .filter { $0.assignment != assignment }
            .map { .assign(employeeID: $0.id, to: assignment) }
    }

    /// Whether every point pool of an in-development product is full.
    static func isComplete(_ product: Product, _ content: ContentCatalog) -> Bool {
        looksShippable(product, nil, content, polish: 1.0)
    }

    /// Whether an in-development product clears the ship gate *and* looks
    /// finished enough that a founder would put their name on it: the code
    /// gate, plus `polish` of every pool.
    static func looksShippable(
        _ product: Product,
        _ balance: BalanceConfig?,
        _ content: ContentCatalog,
        polish: Double
    ) -> Bool {
        guard case .development(let dev) = product.stage,
              let type = content.productType(product.typeID)
        else { return false }
        let codeGate = max(balance?.shipCodeThreshold ?? 0, polish)
        return dev.codePts >= codeGate * type.codePts
            && dev.designPts >= polish * type.designPts
            && dev.polishPts >= polish * type.polishPts
    }

    /// A focus split matching what a product still needs, so a bot never
    /// pours a third of its days into a pool that is already full — the
    /// thing any player learns in their first hour.
    static func focusForRemainingWork(
        _ product: Product,
        _ content: ContentCatalog
    ) -> PhaseFocus {
        guard case .development(let dev) = product.stage,
              let type = content.productType(product.typeID)
        else { return .balanced }
        return PhaseFocus(
            design: max(0, type.designPts - dev.designPts),
            code: max(0, type.codePts - dev.codePts),
            polish: max(0, type.polishPts - dev.polishPts)
        )
    }

    /// The candidate offering the most skill per dollar — what a founder
    /// counting the runway actually hires.
    static func bestValueCandidate(_ state: GameState) -> Candidate? {
        state.candidatePool.max {
            $0.skills.total / Double(max(1, $0.weeklySalary))
                < $1.skills.total / Double(max(1, $1.weeklySalary))
        }
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
/// mobile app at a time and ships once the code gate clears and the rest is
/// 70% there — a founder who cares, but who cannot afford to gold-plate.
/// Measures "how long is the first product, and is it any good?".
struct SoloSlowBot: BotPolicy {
    let name = "solo-slow"

    func actions(
        for state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameAction] {
        guard let product = state.productsInDevelopment.first else {
            return [.startProduct(
                typeID: "mobile_app",
                topicID: BotHelp.topic(forProductNumber: state.products.count),
                name: "Solo \(state.products.count + 1)",
                focus: .balanced
            )]
        }
        if BotHelp.looksShippable(product, balance, content, polish: 0.7) {
            return [.ship(productID: product.id)]
        }
        return BotHelp.assignAll(state, to: .product(product.id)) + [
            .setPhaseFocus(
                productID: product.id,
                focus: BotHelp.focusForRemainingWork(product, content)
            )
        ]
    }
}

/// Growth at any cost: crunches the whole company, hires the best-value
/// candidate up to the office cap whenever there is a quarter's runway,
/// upgrades the office as soon as it is affordable with a month of payroll
/// to spare, and ships at 85% — but hands out raises and answers
/// resignation notices, so it measures "can you grow fast if you *do* look
/// after people?".
struct CrunchHireBot: BotPolicy {
    let name = "crunch-hire"
    /// Weeks of payroll kept in the bank before hiring.
    let hireRunwayWeeks = 12
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
           let candidate = BotHelp.bestValueCandidate(state),
           state.company.cash > (payroll + candidate.weeklySalary) * hireRunwayWeeks {
            actions.append(.hire(candidateID: candidate.id))
        }

        // Keep people: anyone drifting down gets a raise, and a resignation
        // notice is answered on the spot.
        for employee in state.employees
        where !employee.isFounder && employee.morale < raiseMoraleFloor {
            actions.append(.adjustSalary(
                employeeID: employee.id,
                weeklySalary: Int(Double(employee.weeklySalary) * 1.2)
            ))
        }
        if let pending = state.economy.pendingResignation {
            actions.append(.adjustSalary(
                employeeID: pending.employeeID,
                weeklySalary: Int(Double(pending.salaryAtNotice) * 1.3)
            ))
        }

        if let next = state.company.officeTier.next,
           state.company.cash >= balance.office(next).upgradeCost + payroll * 4 {
            actions.append(.upgradeOffice)
        }

        if let product = state.productsInDevelopment.first {
            if BotHelp.looksShippable(product, balance, content, polish: 0.85) {
                actions.append(.ship(productID: product.id))
            } else {
                actions.append(contentsOf: BotHelp.assignAll(state, to: .product(product.id)))
                actions.append(.setPhaseFocus(
                    productID: product.id,
                    focus: BotHelp.focusForRemainingWork(product, content)
                ))
            }
        } else {
            actions.append(.startProduct(
                typeID: state.headcount >= 4 ? "web_app" : "mobile_app",
                topicID: BotHelp.topic(forProductNumber: state.products.count),
                name: "Sprint \(state.products.count + 1)",
                focus: .balanced
            ))
        }
        return actions
    }
}

/// Plays the recurring-revenue game the way a player would: ship mobile
/// apps to pay the bills while the founder sits in the lab all the way to
/// `cloud_infrastructure`, then put the whole studio on one SaaS platform,
/// finish it properly, and live off the subscriptions with a couple of
/// people on the support desk holding churn down.
struct SaaSBuilderBot: BotPolicy {
    let name = "saas-builder"
    /// The research path to the tech that unlocks `saas_platform`.
    static let path = [
        "code_reviews", "version_control", "automated_testing",
        "agile_sprints", "cloud_infrastructure",
    ]
    /// Weeks of payroll kept in the bank before hiring.
    let hireRunwayWeeks = 10
    /// The crew stays small until the platform is earning.
    let crewCapBeforeLaunch = 5
    /// People kept on the support desk once the platform is live.
    let supportDeskSize = 2
    /// The founder only stays in the lab while the rent is safe.
    let researchCashFloor = 15_000

    func actions(
        for state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameAction] {
        var actions: [GameAction] = []
        let payroll = state.employees.reduce(0) { $0 + $1.weeklySalary }

        let livePlatform = state.products.first { product in
            guard case .released(let info) = product.stage else { return false }
            return product.typeID == "saas_platform" && !info.offMarket
        }
        let crewCap = livePlatform == nil
            ? crewCapBeforeLaunch
            : balance.office(state.company.officeTier).headcountCap
        if state.headcount < min(crewCap, balance.office(state.company.officeTier).headcountCap),
           state.company.officeTier != .campus,
           let candidate = BotHelp.bestValueCandidate(state),
           state.company.cash > (payroll + candidate.weeklySalary) * hireRunwayWeeks {
            actions.append(.hire(candidateID: candidate.id))
        }
        if let next = state.company.officeTier.next, next != .campus,
           livePlatform != nil || next == .loft,
           state.company.cash >= balance.office(next).upgradeCost + payroll * 8 {
            actions.append(.upgradeOffice)
        }

        // Pay the market rate: a value hire who stays underpaid resigns,
        // and this bot's whole strategy is a crew that sticks around.
        for employee in state.employees where !employee.isFounder {
            let fair = Int(balance.fairWeeklyPay(for: employee).rounded())
            if employee.weeklySalary < fair {
                actions.append(.adjustSalary(employeeID: employee.id, weeklySalary: fair))
            }
        }
        if let pending = state.economy.pendingResignation {
            actions.append(.adjustSalary(
                employeeID: pending.employeeID,
                weeklySalary: Int(Double(pending.salaryAtNotice) * 1.25)
            ))
        }

        let unlocked = state.isProductTypeUnlocked("saas_platform", content: content)
        if !unlocked, state.research.activeNodeID == nil,
           let next = Self.path.first(where: { !state.research.unlocked.contains($0) }) {
            actions.append(.startResearch(nodeID: next))
        }

        // What to build. Every free development slot gets filled: the
        // platform first once it is unlocked, and mobile apps alongside it
        // to keep the lights on while it is being built — which is exactly
        // what the loft's second slot is for.
        for product in state.productsInDevelopment {
            let polish = product.typeID == "saas_platform" ? 1.0 : 0.8
            if BotHelp.looksShippable(product, balance, content, polish: polish) {
                actions.append(.ship(productID: product.id))
            } else {
                actions.append(.setPhaseFocus(
                    productID: product.id,
                    focus: BotHelp.focusForRemainingWork(product, content)
                ))
            }
        }
        let buildingPlatform = state.productsInDevelopment
            .contains { $0.typeID == "saas_platform" }
        // Before the platform earns anything the studio can only afford
        // one build at a time; once it is live the spare slots go to
        // cash-flow apps.
        if state.hasFreeDevSlot,
           livePlatform != nil || state.productsInDevelopment.isEmpty {
            if unlocked, livePlatform == nil, !buildingPlatform {
                actions.append(.startProduct(
                    typeID: "saas_platform",
                    topicID: "productivity",
                    name: "Platform",
                    focus: .balanced
                ))
            } else if !buildingPlatform {
                // While the platform is being built it gets the whole
                // studio; the spare slots are for cash-flow apps.
                actions.append(.startProduct(
                    typeID: "mobile_app",
                    topicID: BotHelp.topic(forProductNumber: state.products.count),
                    name: "Filler \(state.products.count + 1)",
                    focus: .balanced
                ))
            }
        }

        // Who does what: the founder researches until the gate is open, a
        // couple of hands hold the support desk once the platform is live,
        // and everyone else is dealt round-robin across the open builds so
        // both slots actually move.
        // While the platform is on the bench everybody is on it.
        let builds = buildingPlatform
            ? state.productsInDevelopment.filter { $0.typeID == "saas_platform" }.map(\.id)
            : state.productsInDevelopment.map(\.id)
        var supportPlaced = 0
        var dealt = 0
        for employee in state.employees {
            let wanted: Assignment
            if employee.isFounder, !unlocked, state.company.cash > researchCashFloor {
                wanted = .research
            } else if let livePlatform, supportPlaced < supportDeskSize,
                      state.headcount > supportDeskSize {
                wanted = .support(livePlatform.id)
                supportPlaced += 1
            } else if !builds.isEmpty {
                wanted = .product(builds[dealt % builds.count])
                dealt += 1
            } else if let livePlatform {
                wanted = .support(livePlatform.id)
            } else {
                wanted = .research
            }
            if employee.assignment != wanted {
                actions.append(.assign(employeeID: employee.id, to: wanted))
            }
        }
        return actions
    }
}

/// The bad boss: crunches forever, hires whoever is cheapest, ships at half
/// done, and never praises, raises, promotes, or takes anyone for coffee.
/// The control group for "do people actually leave?".
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
            if BotHelp.looksShippable(product, balance, content, polish: 0.5) {
                actions.append(.ship(productID: product.id))
            } else {
                actions.append(contentsOf: BotHelp.assignAll(state, to: .product(product.id)))
                actions.append(.setPhaseFocus(
                    productID: product.id,
                    focus: BotHelp.focusForRemainingWork(product, content)
                ))
            }
        } else {
            actions.append(.startProduct(
                typeID: "mobile_app",
                topicID: BotHelp.topic(forProductNumber: state.products.count),
                name: "Grind \(state.products.count + 1)",
                focus: .balanced
            ))
        }
        return actions
    }
}
