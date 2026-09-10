import Foundation
import TycoonContent
import TycoonEngine

// The balance harness: a headless driver that plays scripted bot
// strategies through the real `Reducer` so `BalanceSimulationTests` can
// assert long-horizon survival invariants against the shipped Balance.json.
//
// Iteration 12 (J4): moved out of the test target into the shipping
// `TycoonBots` library, unchanged but for `public`, so the app can play
// the house field with the same bots the tests measure the economy with.

/// A deterministic bot: polled once per day (right after the tick) with the
/// fresh state, returning the actions to apply that day, in order. Policies
/// are pure functions of the state — all persistence lives in `GameState`,
/// so a run replays byte-identically from its seed.
public protocol BotPolicy {
    var name: String { get }
    func actions(
        for state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameAction]
}

/// Headless driver for bot runs.
public enum SimRunner {
    /// Mirrors the engine's (internal) `GameState.daysPerYear`.
    public static let daysPerYear = 364
    /// Mirrors the engine's (internal) `GameState.daysPerWeek`.
    public static let daysPerWeek = 7

    public struct Result {
        public var botName: String
        public var state: GameState
        /// Days actually simulated (a bankruptcy ends the run early).
        public var daysRun: Int
        /// How the run ended, `nil` if it was still going at the horizon.
        /// Distinguishing these matters as soon as a bot answers a term
        /// sheet: a board ousting and an IPO both set `gameOver`, and
        /// counting either as a bankruptcy would have the investor gates
        /// measuring the opposite of what they say.
        public var endingKind: EndingKind?
        /// Ran out of money. *Not* "the run ended" — see `endingKind`.
        public var wentBankrupt: Bool { endingKind == .bankruptcy }
        /// The run ended before the horizon, however it ended.
        public var runEnded: Bool { endingKind != nil }
        public var contractsCompleted: Int
        public var contractsFailed: Int
        public var productsShipped: Int
        public var officeUpgrades: Int
        public var randomEvents: Int
        public var maxLedgerCount: Int
        public var maxEventLogCount: Int
        public var minCash: Int

        // MARK: Pacing instrumentation (WS-A)

        /// The day the studio's first product shipped, `nil` if it never did.
        public var firstShipDay: Int?
        /// The average review score of that first product.
        public var firstProductScore: Int?
        /// Lifetime revenue of the first product shipped.
        public var firstProductLifetimeRevenue: Int?
        /// Total events that would have stopped the clock.
        public var pauses: Int
        /// Employees who resigned over low morale.
        public var quits: Int
        /// Employees who served a resignation notice.
        public var resignationNotices: Int
        /// Times the founder was hospitalised.
        public var hospitalizations: Int
        /// Times the founder burned out.
        public var burnouts: Int
        /// Eviction warnings served on the founder.
        public var evictionWarnings: Int
        /// Weekly samples (one per weekly tick) where the wallet was negative.
        public var weeksNegativeWallet: Int
        /// The worst wallet balance seen.
        public var minWallet: Int
        public var peakHeadcount: Int
        /// The day each office tier was first reached.
        public var daysToLoft: Int?
        public var daysToStudio: Int?
        public var daysToCampus: Int?
        /// Updates shipped for already-released products.
        public var updatesShipped: Int
        /// Live bugs discovered in the wild across every release.
        public var liveBugsDiscovered: Int

        public var finalCash: Int { state.company.cash }
        public var officeTier: OfficeTier { state.company.officeTier }

        /// Pauses per game year over the days actually simulated.
        public var pausesPerYear: Double {
            guard daysRun > 0 else { return 0 }
            return Double(pauses) * Double(SimRunner.daysPerYear) / Double(daysRun)
        }

        /// Weekly recurring revenue in the final week: subscription revenue
        /// posted by every on-market subscription product.
        public var finalWeeklySubscriptionRevenue: Int {
            state.products.reduce(0) { total, product in
                guard case .released(let info) = product.stage,
                      info.isSubscription, !info.offMarket,
                      let last = info.weeklySales.last
                else { return total }
                return total + last.revenue
            }
        }

        /// Lifetime revenue across every shipped product (products never
        /// leave `state.products`, so this sees the whole run).
        public var totalProductRevenue: Int {
            state.products.reduce(0) { total, product in
                guard case .released(let info) = product.stage else { return total }
                return total + info.totalRevenue
            }
        }

        /// One row of the per-bot baseline table.
        public var tableRow: String {
            let columns = [
                botName.padding(toLength: 17, withPad: " ", startingAt: 0),
                "cash \(finalCash)".padding(toLength: 14, withPad: " ", startingAt: 0),
                "revenue \(totalProductRevenue)".padding(toLength: 17, withPad: " ", startingAt: 0),
                "shipped \(productsShipped)".padding(toLength: 11, withPad: " ", startingAt: 0),
                "contracts \(contractsCompleted)".padding(toLength: 14, withPad: " ", startingAt: 0),
                "tier \(officeTier.rawValue)",
            ]
            return columns.joined(separator: " | ")
        }
    }

    /// Ticks `days` game days, polling the bot after every tick and applying
    /// its actions in order. Ends early on game over.
    ///
    /// `origin` defaults to the garage — every pacing and investor gate runs
    /// there — and is only set by the origin table (`OriginBotTests`).
    public static func run(
        days: Int,
        seed: UInt64,
        bot: any BotPolicy,
        balance: BalanceConfig,
        content: ContentCatalog,
        origin: FoundingOrigin = .garage
    ) -> Result {
        let state = GameState.newGame(
            companyName: bot.name, seed: seed, balance: balance, origin: origin, content: content
        )
        return run(from: state, days: days, bot: bot, balance: balance, content: content)
    }

    // MARK: J4 (house field)
    /// The same loop from a state the caller founded — the house field
    /// founds a league week's or a daily's company exactly the way the
    /// player's is founded (its difficulty, origin, founder and mode) and
    /// hands it here. `run(days:seed:…)` is this with a garage start.
    public static func run(
        from start: GameState,
        days: Int,
        bot: any BotPolicy,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> Result {
        var state = start
        // MARK: end J4
        var result = Result(
            botName: bot.name,
            state: state,
            daysRun: 0,
            endingKind: nil,
            contractsCompleted: 0,
            contractsFailed: 0,
            productsShipped: 0,
            officeUpgrades: 0,
            randomEvents: 0,
            maxLedgerCount: 0,
            maxEventLogCount: 0,
            minCash: state.company.cash,
            firstShipDay: nil,
            firstProductScore: nil,
            firstProductLifetimeRevenue: nil,
            pauses: 0,
            quits: 0,
            resignationNotices: 0,
            hospitalizations: 0,
            burnouts: 0,
            evictionWarnings: 0,
            weeksNegativeWallet: 0,
            minWallet: state.life.wallet,
            peakHeadcount: state.headcount,
            daysToLoft: nil,
            daysToStudio: nil,
            daysToCampus: nil,
            updatesShipped: 0,
            liveBugsDiscovered: 0
        )
        var firstProductID: UUID?

        for _ in 0..<days {
            tally(
                Reducer.tick(&state, balance: balance, content: content),
                day: state.day, into: &result, firstProductID: &firstProductID
            )
            observe(state, into: &result)
            // What the player would actually have seen: `PausePolicy` has
            // already applied the owned-topic rule and the pause budget.
            result.pauses += state.economy.pauseEvents.count
            if state.day % daysPerWeek == 0, state.life.wallet < 0 {
                result.weeksNegativeWallet += 1
            }
            if state.gameOver != nil { break }

            for action in bot.actions(for: state, balance: balance, content: content) {
                tally(
                    Reducer.apply(action, to: &state, balance: balance, content: content),
                    day: state.day, into: &result, firstProductID: &firstProductID
                )
            }
            observe(state, into: &result)
        }

        if let firstProductID,
           case .released(let info)? = state.product(id: firstProductID)?.stage {
            result.firstProductScore = info.averageReviewScore
            result.firstProductLifetimeRevenue = info.totalRevenue
        }

        result.state = state
        result.daysRun = state.day
        result.endingKind = state.gameOver?.kind
        return result
    }

    private static func tally(
        _ events: [GameEvent],
        day: Int,
        into result: inout Result,
        firstProductID: inout UUID?
    ) {
        for event in events {
            switch event {
            case .contractDelivered: result.contractsCompleted += 1
            case .contractFailed: result.contractsFailed += 1
            case let .shipped(productID, shipDay):
                result.productsShipped += 1
                if firstProductID == nil {
                    firstProductID = productID
                    result.firstShipDay = shipDay
                }
            case let .officeUpgraded(tier, upgradeDay):
                result.officeUpgrades += 1
                switch tier {
                case .garage: break
                case .loft: result.daysToLoft = result.daysToLoft ?? upgradeDay
                case .studio: result.daysToStudio = result.daysToStudio ?? upgradeDay
                case .campus: result.daysToCampus = result.daysToCampus ?? upgradeDay
                }
            case .randomEvent: result.randomEvents += 1
            case .employeeQuit: result.quits += 1
            case .resignationNotice: result.resignationNotices += 1
            case .evictionWarning: result.evictionWarnings += 1
            case .updateShipped: result.updatesShipped += 1
            case let .founderAway(reason, _, _):
                if reason == "Hospital" { result.hospitalizations += 1 }
                if reason == "Burnout" { result.burnouts += 1 }
            default: break
            }
        }
        _ = day
    }

    private static func observe(_ state: GameState, into result: inout Result) {
        result.maxLedgerCount = max(result.maxLedgerCount, state.ledger.entries.count)
        result.maxEventLogCount = max(result.maxEventLogCount, state.eventLog.count)
        result.minCash = min(result.minCash, state.company.cash)
        result.minWallet = min(result.minWallet, state.life.wallet)
        result.peakHeadcount = max(result.peakHeadcount, state.headcount)
        result.liveBugsDiscovered = max(result.liveBugsDiscovered, state.products.reduce(0) { total, product in
            guard case .released(let info) = product.stage else { return total }
            return total + info.liveBugs
        })
    }
}

// MARK: - Bots

/// Lives entirely off contracts: whenever no contract is active it accepts
/// the best-value affordable offer ("best value" = highest payout;
/// "affordable" = the penalty for a missed deadline couldn't exceed current
/// cash), keeps everyone assigned to the active contract, and never builds
/// products.
public struct ContractGrinderBot: BotPolicy {
    public let name = "contract-grinder"

    public init() {}

    public func actions(
        for state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameAction] {
        var actions: [GameAction] = []

        var targetID = state.activeContracts.first?.id
        if targetID == nil {
            let best = state.contractOffers
                .filter { $0.penalty <= state.company.cash }
                .max { $0.payout < $1.payout }
            if let best {
                actions.append(.acceptContract(offerID: best.id))
                targetID = best.id
            }
        }

        if let targetID {
            for employee in state.employees where employee.assignment != .contract(targetID) {
                actions.append(.assign(employeeID: employee.id, to: .contract(targetID)))
            }
        }
        return actions
    }
}

/// Churns out mobile apps as fast as the ship gate allows: starts one
/// immediately with a code-heavy focus, ships the moment the 60% code gate
/// clears, and starts the next on the following day's poll (the daily sweep
/// has returned everyone to idle by then, so `startProduct` auto-assigns
/// them). Hires the first coder-leaning candidate whenever cash exceeds its
/// chosen buffer.
public struct ShipFastBot: BotPolicy {
    public let name = "ship-fast"

    public init() {}
    /// The bot's own choice of hiring war chest.
    let hireCashBuffer = 15_000

    public func actions(
        for state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameAction] {
        var actions: [GameAction] = []

        if let product = state.productInDevelopment {
            if case .development(let dev) = product.stage,
               let type = content.productType(product.typeID),
               dev.codePts >= balance.shipCodeThreshold * type.codePts {
                actions.append(.ship(productID: product.id))
            } else {
                // Keep late joiners (post-gap hires) on the build.
                for employee in state.employees
                where employee.assignment != .product(product.id) {
                    actions.append(.assign(employeeID: employee.id, to: .product(product.id)))
                }
            }
        } else {
            actions.append(.startProduct(
                typeID: "mobile_app",
                topicID: "fitness",
                name: "Speedrun \(state.products.count + 1)",
                focus: PhaseFocus(design: 1, code: 8, polish: 1)
            ))
        }

        if state.company.cash > hireCashBuffer,
           let coder = state.candidatePool.first(where: { candidate in
               candidate.skills.coding >= candidate.skills.design
                   && candidate.skills.coding >= candidate.skills.marketing
           }) {
            actions.append(.hire(candidateID: coder.id))
        }
        return actions
    }
}

/// Grinds contracts until the war chest clears $20k, then runs one product
/// cycle at a time — shipping only at full completion of all three point
/// pools — hires once at cash > $25k, upgrades the office whenever the next
/// tier is affordable with a safety buffer left over, and parks everyone on
/// research when there is neither a product nor a contract to work.
public struct BalancedBot: BotPolicy {
    public let name = "balanced"

    public init() {}
    let productCashFloor = 20_000
    let hireCashFloor = 25_000
    let upgradeCashBuffer = 10_000

    public func actions(
        for state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameAction] {
        var actions: [GameAction] = []

        // One hire, once cash comfortably covers a salary.
        if state.headcount < 2,
           state.company.cash > hireCashFloor,
           let candidate = state.candidatePool.first {
            actions.append(.hire(candidateID: candidate.id))
        }

        // Upgrade whenever the next tier is affordable with buffer to spare.
        if let next = state.company.officeTier.next,
           state.company.cash >= balance.office(next).upgradeCost + upgradeCashBuffer {
            actions.append(.upgradeOffice)
        }

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
                name: "Steady \(state.products.count + 1)",
                focus: .balanced
            ))
        } else {
            var targetID = state.activeContracts.first?.id
            if targetID == nil {
                let best = state.contractOffers
                    .filter { $0.penalty <= state.company.cash }
                    .max { $0.payout < $1.payout }
                if let best {
                    actions.append(.acceptContract(offerID: best.id))
                    targetID = best.id
                }
            }
            if let targetID {
                for employee in state.employees
                where employee.assignment != .contract(targetID) {
                    actions.append(.assign(employeeID: employee.id, to: .contract(targetID)))
                }
            } else {
                // No product, no contract: spare bodies do research.
                for employee in state.employees where employee.assignment != .research {
                    actions.append(.assign(employeeID: employee.id, to: .research))
                }
            }
        }
        return actions
    }
}
