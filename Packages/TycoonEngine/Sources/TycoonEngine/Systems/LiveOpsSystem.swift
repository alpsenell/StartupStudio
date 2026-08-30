import Foundation
import TycoonContent

/// Daily live-ops system, running last so it sees the day the rest of the
/// simulation just produced. Shipping is no longer the end of a product's
/// story:
///
/// 1. **Support desks** clear bugs. Weekly (the day after sales post), each
///    supporter's polish output over the week × `supportBugFixMultiplier`
///    comes off that product's live-bug count.
/// 2. **The wild finds new ones.** Weekly, every on-market release rolls
///    `units sold / liveBugUnitsPerDiscovery` new live bugs — the whole
///    part plus one Bernoulli draw for the fraction, so exactly one word of
///    `worldRNG` per product per week. Crossing `liveBugAlarmThreshold`
///    raises `.liveBugsSpiking` once per run of trouble.
/// 3. **Patches land.** A finished `ProductUpdate` lifts the product's
///    quality, halves its live bugs, re-reviews it at
///    `updateReviewWeight` against the launch reviews, and buys one bumper
///    sales week.
///
/// Every live bug shaves `liveBugSalesPenalty` off weekly sales and
/// subscriber acquisition alike (capped at `liveBugPenaltyCap`), which is
/// where the pressure to staff a support desk comes from.
///
/// Draw order is fixed: products are visited in `state.products` order, and
/// only the discovery roll draws (from `worldRNG`, so the long-established
/// `rng` stream that the older systems' tests document word by word is
/// untouched).
enum LiveOpsSystem {
    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        var events: [GameEvent] = []
        if state.day % GameState.daysPerWeek == 0 {
            clearBugsFromSupport(&state, balance)
            events.append(contentsOf: discoverLiveBugs(&state, balance))
        }
        events.append(contentsOf: completeUpdates(&state, balance, content))
        return events
    }

    // MARK: - Support

    /// A week of support work: everyone on a product's support desk turns
    /// their polish output into fixes. No RNG.
    private static func clearBugsFromSupport(_ state: inout GameState, _ balance: BalanceConfig) {
        var fixesByProduct: [UUID: Double] = [:]
        for employee in state.employees {
            guard case .support(let productID) = employee.assignment else { continue }
            // An away founder's multiplier is already 0; everyone else works.
            let factor = employee.isFounder
                ? state.founderOutputMultiplier(balance: balance)
                : employee.performanceMultiplier(balance: balance)
            let yield = balance.company.roleYield(employee.role)
            let skills = employee.skills
            let daily = factor * yield.polish
                * (balance.employeeBasePoints
                    + (skills.coding + skills.design) / 2 / balance.skillYieldDivisor)
            fixesByProduct[productID, default: 0] +=
                daily * Double(GameState.daysPerWeek) * balance.economy.supportBugFixMultiplier
        }
        guard !fixesByProduct.isEmpty else { return }

        for index in state.products.indices {
            guard case .released(var info) = state.products[index].stage,
                  let fixes = fixesByProduct[state.products[index].id],
                  info.liveBugs > 0
            else { continue }
            info.liveBugs = max(0, info.liveBugs - Int(fixes))
            state.products[index].stage = .released(info)
        }
    }

    // MARK: - Discovery

    /// One week of the wild finding bugs, proportional to how many people
    /// actually used the thing.
    private static func discoverLiveBugs(
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) -> [GameEvent] {
        let economy = balance.economy
        guard economy.liveBugUnitsPerDiscovery.isFinite,
              economy.liveBugUnitsPerDiscovery > 0
        else { return [] }

        var events: [GameEvent] = []
        for index in state.products.indices {
            guard case .released(var info) = state.products[index].stage,
                  !info.offMarket,
                  let week = info.weeklySales.last
            else { continue }

            let expected = Double(week.units) / economy.liveBugUnitsPerDiscovery
            let whole = Int(expected)
            // One draw, always, so the stream walks the same path whatever
            // the week sold.
            let extra = state.worldRNG.nextUniform() < expected - Double(whole) ? 1 : 0
            let found = whole + extra
            guard found > 0 else { continue }

            let wasBelowAlarm = info.liveBugs < economy.liveBugAlarmThreshold
            info.liveBugs += found
            state.products[index].stage = .released(info)
            if wasBelowAlarm, info.liveBugs >= economy.liveBugAlarmThreshold {
                events.append(.liveBugsSpiking(
                    productID: state.products[index].id,
                    liveBugs: info.liveBugs,
                    day: state.day
                ))
            }
        }
        return events
    }

    // MARK: - Patches

    /// Lands every patch that finished today.
    private static func completeUpdates(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        guard state.economy.updates.contains(where: \.isComplete) else { return [] }

        var events: [GameEvent] = []
        let finished = state.economy.updates.filter(\.isComplete)
        state.economy.updates.removeAll(where: \.isComplete)

        for update in finished {
            guard let index = state.products.firstIndex(where: { $0.id == update.productID }),
                  case .released(var info) = state.products[index].stage
            else { continue }

            let economy = balance.economy
            // Diminishing returns on the count that was already being
            // incremented here and read by nothing. A flat bonus meant a
            // twelfth patch was worth as much as the first, so any product
            // could be walked to `reviewCeiling` regardless of how it
            // shipped; now the third is worth about three points and a
            // late patch is a marketing beat (the sales bump below) rather
            // than a quality fix.
            let bonus = economy.updateQualityBonus
                * pow(economy.updateQualityDecay, Double(info.updateCount))
            info.quality = min(100, info.quality + bonus)
            // A patch is mostly bug fixes: half the wild's backlog goes.
            info.liveBugs /= 2
            info.updateCount += 1
            info.lastUpdateDay = state.day

            // The press takes another look, at reduced weight against the
            // launch verdict.
            let weight = economy.updateReviewWeight
            info.reviews = info.reviews.map { review in
                let revisited = min(
                    balance.reviewCeiling,
                    max(balance.reviewFloor, Int(info.quality.rounded()))
                )
                let blended = (Double(review.score) + weight * Double(revisited)) / (1 + weight)
                let score = min(balance.reviewCeiling, max(balance.reviewFloor, Int(blended.rounded())))
                return Review(
                    outlet: review.outlet,
                    score: score,
                    blurb: ReviewBlurbs.pick(for: score, rng: &state.rng)
                )
            }
            let newScore = info.averageReviewScore
            let stillSelling = !info.offMarket
            state.products[index].stage = .released(info)
            if stillSelling {
                for employeeIndex in state.employees.indices
                where state.employees[employeeIndex].assignment == .product(update.productID) {
                    state.employees[employeeIndex].assignment = .support(update.productID)
                }
            }
            // A well-received patch nudges the studio's reputation the way a
            // launch does, at the same reduced weight.
            state.company.reputation = min(100, max(0,
                state.company.reputation
                    + (Double(newScore) - state.company.reputation)
                        * balance.reputationReviewNudge * weight
            ))
            events.append(.updateShipped(
                productID: update.productID, newScore: newScore, day: state.day
            ))
            // The patch crew rolls onto the product's support desk rather
            // than the bench.
            //
            // Benching them undid the player's staffing decision: they put
            // these people on *this product*, and a finished patch moved
            // them off it. Simply not moving them was no better — the
            // daily sweep idles a `.product` assignment on something that
            // is no longer in development, so the crew ended up on the
            // bench a tick later anyway. A support desk is the assignment
            // that stays valid, and it is where the people who just spent
            // a fortnight in this product's bug list are worth the most.
        }
        return events
    }
}
