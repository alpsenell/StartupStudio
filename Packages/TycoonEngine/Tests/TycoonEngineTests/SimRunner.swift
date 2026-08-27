import Foundation
import TycoonContent
import TycoonEngine

// Test-target-only balance harness: a headless driver that plays scripted
// bot strategies through the real `Reducer` so `BalanceSimulationTests` can
// assert long-horizon survival invariants against the shipped Balance.json.

/// A deterministic bot: polled once per day (right after the tick) with the
/// fresh state, returning the actions to apply that day, in order. Policies
/// are pure functions of the state — all persistence lives in `GameState`,
/// so a run replays byte-identically from its seed.
protocol BotPolicy {
    var name: String { get }
    func actions(
        for state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameAction]
}

/// Headless driver for bot runs.
enum SimRunner {
    struct Result {
        var botName: String
        var state: GameState
        /// Days actually simulated (a bankruptcy ends the run early).
        var daysRun: Int
        var wentBankrupt: Bool
        var contractsCompleted: Int
        var contractsFailed: Int
        var productsShipped: Int
        var officeUpgrades: Int
        var randomEvents: Int
        var maxLedgerCount: Int
        var maxEventLogCount: Int
        var minCash: Int

        var finalCash: Int { state.company.cash }
        var officeTier: OfficeTier { state.company.officeTier }

        /// Lifetime revenue across every shipped product (products never
        /// leave `state.products`, so this sees the whole run).
        var totalProductRevenue: Int {
            state.products.reduce(0) { total, product in
                guard case .released(let info) = product.stage else { return total }
                return total + info.totalRevenue
            }
        }

        /// One row of the per-bot baseline table.
        var tableRow: String {
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
    static func run(
        days: Int,
        seed: UInt64,
        bot: any BotPolicy,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> Result {
        var state = GameState.newGame(companyName: bot.name, seed: seed, balance: balance)
        var result = Result(
            botName: bot.name,
            state: state,
            daysRun: 0,
            wentBankrupt: false,
            contractsCompleted: 0,
            contractsFailed: 0,
            productsShipped: 0,
            officeUpgrades: 0,
            randomEvents: 0,
            maxLedgerCount: 0,
            maxEventLogCount: 0,
            minCash: state.company.cash
        )

        for _ in 0..<days {
            tally(Reducer.tick(&state, balance: balance, content: content), into: &result)
            observe(state, into: &result)
            if state.gameOver != nil { break }

            for action in bot.actions(for: state, balance: balance, content: content) {
                tally(
                    Reducer.apply(action, to: &state, balance: balance, content: content),
                    into: &result
                )
            }
            observe(state, into: &result)
        }

        result.state = state
        result.daysRun = state.day
        result.wentBankrupt = state.gameOver != nil
        return result
    }

    private static func tally(_ events: [GameEvent], into result: inout Result) {
        for event in events {
            switch event {
            case .contractDelivered: result.contractsCompleted += 1
            case .contractFailed: result.contractsFailed += 1
            case .shipped: result.productsShipped += 1
            case .officeUpgraded: result.officeUpgrades += 1
            case .randomEvent: result.randomEvents += 1
            default: break
            }
        }
    }

    private static func observe(_ state: GameState, into result: inout Result) {
        result.maxLedgerCount = max(result.maxLedgerCount, state.ledger.entries.count)
        result.maxEventLogCount = max(result.maxEventLogCount, state.eventLog.count)
        result.minCash = min(result.minCash, state.company.cash)
    }
}

// MARK: - Bots

/// Lives entirely off contracts: whenever no contract is active it accepts
/// the best-value affordable offer ("best value" = highest payout;
/// "affordable" = the penalty for a missed deadline couldn't exceed current
/// cash), keeps everyone assigned to the active contract, and never builds
/// products.
struct ContractGrinderBot: BotPolicy {
    let name = "contract-grinder"

    func actions(
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
struct ShipFastBot: BotPolicy {
    let name = "ship-fast"
    /// The bot's own choice of hiring war chest.
    let hireCashBuffer = 15_000

    func actions(
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
struct BalancedBot: BotPolicy {
    let name = "balanced"
    let productCashFloor = 20_000
    let hireCashFloor = 25_000
    let upgradeCashBuffer = 10_000

    func actions(
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
