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
public enum BotHelp {
    /// Topics rotated through so a bot's tenth product isn't its ninth
    /// again — launch saturation punishes that, and a player would notice.
    public static let topics = ["fitness", "finance", "productivity", "travel", "music", "health"]

    public static func topic(forProductNumber number: Int) -> String {
        topics[number % topics.count]
    }

    /// Puts every employee on `assignment` (skipping those already there).
    public static func assignAll(_ state: GameState, to assignment: Assignment) -> [GameAction] {
        state.employees
            .filter { $0.assignment != assignment }
            .map { .assign(employeeID: $0.id, to: assignment) }
    }

    /// Whether every point pool of an in-development product is full.
    public static func isComplete(_ product: Product, _ content: ContentCatalog) -> Bool {
        looksShippable(product, nil, content, polish: 1.0)
    }

    /// Whether an in-development product clears the ship gate *and* looks
    /// finished enough that a founder would put their name on it: the code
    /// gate, plus `polish` of every pool.
    public static func looksShippable(
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
    public static func focusForRemainingWork(
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
    public static func bestValueCandidate(_ state: GameState) -> Candidate? {
        state.candidatePool.max {
            $0.skills.total / Double(max(1, $0.weeklySalary))
                < $1.skills.total / Double(max(1, $1.weeklySalary))
        }
    }

    /// The best affordable contract offer: the highest payout whose penalty
    /// could not sink the company on its own.
    public static func bestOffer(_ state: GameState) -> ContractOffer? {
        state.contractOffers
            .filter { $0.penalty <= state.company.cash }
            .max { $0.payout < $1.payout }
    }

    /// One weekend a month out of the office. Not self-care — a founder
    /// who crunches eleven months of the year and takes one Saturday in
    /// four, which is the least any engaged player does and more than any
    /// bot did before the balance pass.
    ///
    /// Deliberately blind to the health meter. Measured, *any* reactive
    /// gym rule zeroes hospitalisations outright — a gym weekend is +12
    /// health against crunch's −3.5 a week, so the first time the bot
    /// reacts it never stops reacting — and a harness whose founder never
    /// falls over cannot measure whether falling over hurts. This bot is
    /// the control for "what does never looking up cost?", and the engine
    /// is calibrated so that even *that* founder is hospitalised three or
    /// four times in two years rather than seven to twelve. Also not
    /// called by `SoloSlowBot` or `NeglectfulBot`.
    ///
    /// It matters beyond flavour: `rest` is the do-nothing default and
    /// `ProgressionSystem` only counts a weekend the founder actually
    /// planned, so a bot that never plans one can never complete chapter
    /// 2's `g2_take_a_weekend` — and, four goals being the gate, can never
    /// see chapter 3 at all.
    public static func weekendPlan(_ state: GameState) -> [GameAction] {
        guard !state.life.isAway(day: state.day) else { return [] }
        let monthly = state.weekOfYear.isMultiple(of: 4)
        let wanted: WeekendActivity = monthly
            ? (state.life.family.stage == .single ? .friends : .dateNight)
            : .rest
        return state.life.plannedActivity == wanted ? [] : [.planWeekend(wanted)]
    }
}

/// The archetype solo founder: never hires, never crunches, builds one
/// mobile app at a time and ships once the code gate clears and the rest is
/// 70% there — a founder who cares, but who cannot afford to gold-plate.
/// Measures "how long is the first product, and is it any good?".
public struct SoloSlowBot: BotPolicy {
    public let name = "solo-slow"

    public init() {}

    public func actions(
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
/// to spare, and ships at 85% — but pays over the market rate, answers
/// resignation notices, and takes one weekend a month, so it measures "can
/// you grow fast if you *do* look after people?".
public struct CrunchHireBot: BotPolicy {
    /// How the bot answers an unhappy employee.
    public enum RaisePolicy: Sendable {
        /// What a founder counting the runway does: pay a generous
        /// multiple of what the market says the person is worth.
        case marketAnchored
        /// What the bot did before the balance pass, and what a panicking
        /// founder does: add a fifth to whatever they happen to be paying,
        /// every day the person is unhappy, with nothing to anchor it.
        case compounding
    }

    public var name = "crunch-hire"
    public var raises: RaisePolicy = .marketAnchored
    /// Weeks of payroll kept in the bank before hiring. Unchanged by the
    /// balance pass: at 40 seeds the strategy's failure rate is flat
    /// between 10 and 16 weeks (42–57%) and chaotic within it, so there is
    /// no honest reason to move it.
    public var hireRunwayWeeks = 12
    /// Headcount at which the studio graduates from mobile apps to the
    /// bigger, better-paying web builds. Two: the day it is not just the
    /// founder any more. A web app is 1.5× the points of a mobile app for
    /// 2.2× the lifetime revenue, so the moment there is a second pair of
    /// hands it is the better build — and a bot that waits for four hands
    /// waits forever, because mobile apps alone never pay for the third.
    public var bigProductHeadcount = 2
    /// Whether a bigger office is bought when the current one runs out of
    /// desks — what it is *for* — rather than the day the sticker price
    /// becomes affordable. False: "growth at any cost" means the letterhead
    /// too, and measured, waiting for a full loft means the studio is
    /// reached on 4 seeds in 40 rather than 25.
    public var upgradeWhenFull = false
    let raiseMoraleFloor = 45.0
    /// What "a good employer" pays: this much of the candidate-market rate
    /// for the person's skills. Above `staff.wellPaidThreshold` (1.15), so
    /// it buys the morale bonus and keeps poachers honest, and *anchored*
    /// — a founder counting the runway pays over the odds, not over the
    /// last number they happened to write down.
    let payPremium = 1.3

    public init(
        name: String = "crunch-hire",
        raises: RaisePolicy = .marketAnchored,
        hireRunwayWeeks: Int = 12,
        bigProductHeadcount: Int = 2,
        upgradeWhenFull: Bool = false
    ) {
        self.name = name
        self.raises = raises
        self.hireRunwayWeeks = hireRunwayWeeks
        self.bigProductHeadcount = bigProductHeadcount
        self.upgradeWhenFull = upgradeWhenFull
    }

    public func actions(
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
        // Crunches the week and still spends the weekend somewhere — which
        // is what "engaged" means, and the only thing standing between
        // this bot and chapter 2.
        actions.append(contentsOf: BotHelp.weekendPlan(state))

        let payroll = state.employees.reduce(0) { $0 + $1.weeklySalary }
        if state.headcount < balance.office(state.company.officeTier).headcountCap,
           let candidate = BotHelp.bestValueCandidate(state),
           state.company.cash > (payroll + candidate.weeklySalary) * hireRunwayWeeks {
            actions.append(.hire(candidateID: candidate.id))
        }

        // Keep people: anyone drifting down gets a raise, and a
        // resignation notice is answered on the spot.
        for employee in state.employees
        where !employee.isFounder && employee.morale < raiseMoraleFloor {
            switch raises {
            case .marketAnchored:
                let target = Int((balance.fairWeeklyPay(for: employee) * payPremium).rounded())
                guard employee.weeklySalary < target else { continue }
                actions.append(.adjustSalary(employeeID: employee.id, weeklySalary: target))
            case .compounding:
                actions.append(.adjustSalary(
                    employeeID: employee.id,
                    weeklySalary: Int(Double(employee.weeklySalary) * 1.2)
                ))
            }
        }
        if let pending = state.economy.pendingResignation {
            // Whatever the policy, a notice is met with a real counter —
            // `counterOfferRaiseFactor` is 1.12, so 1.15 always clears it.
            let floor = Int(Double(pending.salaryAtNotice) * 1.15)
            let fair = state.employees
                .first { $0.id == pending.employeeID }
                .map { Int((balance.fairWeeklyPay(for: $0) * payPremium).rounded()) } ?? 0
            actions.append(.adjustSalary(
                employeeID: pending.employeeID,
                weeklySalary: raises == .marketAnchored ? max(floor, fair) : floor
            ))
        }

        let atCap = state.headcount >= balance.office(state.company.officeTier).headcountCap
        if let next = state.company.officeTier.next,
           state.company.cash >= balance.office(next).upgradeCost + payroll * 4,
           !upgradeWhenFull || atCap {
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
                typeID: state.headcount >= bigProductHeadcount ? "web_app" : "mobile_app",
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
public struct SaaSBuilderBot: BotPolicy {
    public let name = "saas-builder"

    public init() {}
    /// The research path to the tech that unlocks `saas_platform`.
    public static let path = [
        "code_reviews", "version_control", "automated_testing",
        "agile_sprints", "cloud_infrastructure",
    ]
    /// Weeks of payroll kept in the bank before hiring.
    let hireRunwayWeeks = 10
    /// The founder only stays in the lab while the rent is safe.
    let researchCashFloor = 15_000
    /// The crew stays small until the platform is earning.
    let crewCapBeforeLaunch = 5
    /// People kept on the support desk once the platform is live.
    let supportDeskSize = 2

    public func actions(
        for state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameAction] {
        var actions: [GameAction] = []
        actions.append(contentsOf: BotHelp.weekendPlan(state))
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
        var startedSomething = false
        if state.hasFreeDevSlot,
           livePlatform != nil || state.productsInDevelopment.isEmpty {
            startedSomething = true
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
            } else {
                startedSomething = false
            }
        }
        // `startProduct` puts everyone idle onto the new build; re-deciding
        // assignments from this (pre-action) state would immediately undo
        // that, so the crew settles on the next poll.
        if startedSomething { return actions }

        // Who does what: the founder takes the lab whenever the rent is
        // safe (a garage studio cannot afford a full-time researcher), a
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
public struct NeglectfulBot: BotPolicy {
    public let name = "neglectful"

    public init() {}

    public func actions(
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

extension CrunchHireBot {
    /// The same strategy, with the raise rule the bot used before the
    /// balance pass: a fifth on top of the current salary, every day the
    /// person is unhappy, anchored to nothing. Crunch holds morale near
    /// the floor, so the rule fires again and again and payroll compounds
    /// clean off the end of the revenue curve.
    ///
    /// Kept as a control: growth plus crunch is survivable, mismanaging
    /// payroll on top of it is not, and the only difference between this
    /// bot and `crunch-hire` is those four lines.
    public static var runawayRaise: CrunchHireBot {
        CrunchHireBot(name: "runaway-raise", raises: .compounding)
    }
}
