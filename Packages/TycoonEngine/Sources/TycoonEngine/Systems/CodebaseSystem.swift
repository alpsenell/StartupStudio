import Foundation
import TycoonContent

/// The codebase layer: where technical debt comes from, who pays it down,
/// and what a shipped product leaves behind.
///
/// ## The one rule everything here is arranged around
///
/// Debt a build *creates* never touches that build. It accumulates in
/// `DevProgress.debtAccrued` and is handed to the codebase at ship; the
/// debt that shapes a product's ceiling and bug rate is the *live* debt of
/// the codebase it was started on, which is exactly 0 when there isn't one.
///
/// Two things fall out of that, and both were the point:
///
/// - **A greenfield build is bit-identical to the shipped balance.** The
///   pacing bots crunch constantly and never build on a codebase, so
///   `crunchDebtPerDay` can be set to anything at all without moving a
///   single number in `BalanceTargetsTests`. The gates are protected by
///   construction rather than by a carefully chosen constant.
/// - **Refactoring pays off immediately.** Because the inherited debt is
///   read live, people moved onto `.refactor` raise the ship forecast of
///   the product that is running *right now*. Freezing the debt at start
///   would have made the assignment a bet on the product after next, which
///   nobody would ever take.
///
/// It also happens to be the honest reading of technical debt: the
/// shortcuts you take this quarter are not what makes this quarter hard.
enum CodebaseSystem {
    // MARK: - Accrual

    /// Charges a build for a day of crunch. Called once per in-development
    /// product per day from `EmployeeSystem`, after the day's output — once
    /// per *build*, not once per person, because a shortcut is taken by
    /// the schedule and not by the headcount.
    static func accrueDailyDebt(
        productIndex: Int,
        state: inout GameState,
        balance: BalanceConfig
    ) {
        guard state.economy.workPace == .crunch,
              case .development(var dev) = state.products[productIndex].stage
        else { return }
        dev.debtAccrued += balance.codebase.crunchDebtPerDay
        state.products[productIndex].stage = .development(dev)
    }

    /// Adds a completed patch cycle's debt to the patched product's
    /// codebase, if it has one. A patch is mostly bug fixes, so the number
    /// is small — but a product walked to the review ceiling on a dozen
    /// patches leaves a codebase nobody wants to start from.
    static func accruePatchDebt(
        productID: UUID,
        state: inout GameState,
        balance: BalanceConfig
    ) {
        guard let product = state.product(id: productID),
              let index = state.codebases.firstIndex(where: { $0.id == product.codebaseID })
        else { return }
        let codebase = balance.codebase
        state.codebases[index].debt = codebase.clampDebt(
            state.codebases[index].debt + codebase.patchDebt
        )
    }

    // MARK: - Refactoring

    /// One day of everyone on a `.refactor` desk.
    ///
    /// The shape mirrors `EmployeeSystem.produceResearchPoints`, the other
    /// assignment that produces nothing anybody can see: a base rate plus a
    /// skill term, scaled by the person's performance (the founder's own
    /// output multiplier, and nothing at all while they are away). Debt
    /// cannot go below zero — a clean codebase is as clean as it gets.
    ///
    /// Refactorers do not learn anything they would not have learnt
    /// building the same code, so their coding skill grows at the standard
    /// rate; design does not, because nobody is designing.
    static func runRefactoring(_ state: inout GameState, _ balance: BalanceConfig) {
        guard state.employees.contains(where: {
            if case .refactor = $0.assignment { return true }
            return false
        }) else { return }

        let config = balance.codebase
        let founderAway = state.life.isAway(day: state.day)
        let founderFactor = state.founderOutputMultiplier(balance: balance)
        var cutByCodebase: [String: Double] = [:]
        var refactorers: [Int] = []

        for index in state.employees.indices {
            guard case .refactor(let codebaseID) = state.employees[index].assignment else { continue }
            let isFounder = state.employees[index].isFounder
            if isFounder, founderAway { continue }
            let factor = isFounder
                ? founderFactor
                : state.employees[index].performanceMultiplier(balance: balance)
            let skills = state.employees[index].skills
            cutByCodebase[codebaseID, default: 0] += factor * (config.refactorBasePoints
                + skills.coding / config.refactorCodingDivisor)
            refactorers.append(index)
        }

        for index in state.codebases.indices {
            guard let cut = cutByCodebase[state.codebases[index].id] else { continue }
            state.codebases[index].debt = config.clampDebt(state.codebases[index].debt - cut)
        }
        for index in refactorers {
            let skill = state.employees[index].skills.coding
            state.employees[index].skills.coding = min(
                100, skill + balance.skillGrowthRate * (1 - skill / 100)
            )
        }
    }

    // MARK: - Ship

    /// Records what a product just shipped leaves behind: the carried
    /// share of its filled pools, and the debt of the build plus whatever
    /// bugs went out the door with it.
    ///
    /// The codebase always reflects the *most recent* product built in it,
    /// so a lineage does not silently ratchet its head start upward — the
    /// pools it hands out are the ones the last team actually filled.
    /// Debt, by contrast, accumulates: that is the whole shape of the
    /// feature.
    static func recordShip(
        product: Product,
        dev: DevProgress,
        type: ProductTypeDef,
        state: inout GameState,
        balance: BalanceConfig
    ) {
        let config = balance.codebase
        let carry = config.carryFraction
        let addedDebt = dev.debtAccrued + Double(dev.openBugs) * config.shipBugDebt

        if let index = state.codebases.firstIndex(where: { $0.id == product.typeID }) {
            state.codebases[index].designPts = min(type.designPts, dev.designPts) * carry
            state.codebases[index].codePts = min(type.codePts, dev.codePts) * carry
            state.codebases[index].polishPts = min(type.polishPts, dev.polishPts) * carry
            state.codebases[index].debt = config.clampDebt(
                state.codebases[index].debt + addedDebt
            )
            state.codebases[index].lastShipDay = state.day
            state.codebases[index].productsShipped += 1
        } else {
            state.codebases.append(Codebase(
                id: product.typeID,
                // The lineage is named after the product that founded it —
                // the new-product sheet offers to "build on Habit Loop",
                // which is a thing the player remembers shipping.
                name: product.name,
                designPts: min(type.designPts, dev.designPts) * carry,
                codePts: min(type.codePts, dev.codePts) * carry,
                polishPts: min(type.polishPts, dev.polishPts) * carry,
                debt: config.clampDebt(addedDebt),
                lastShipDay: state.day,
                productsShipped: 1
            ))
        }
    }
}
