import Foundation
import TycoonContent

/// City system, running just before `FinanceSystem` so property tax and
/// address prestige settle before the weekly bill: weekly it posts the
/// property tax on an owned office and applies the district's reputation
/// drift; monthly (while owned) the property value takes a seeded step.
/// Also hosts the relocate/buy/sell action handlers used by
/// `Reducer.apply`.
///
/// All randomness draws from `state.worldRNG`. Draw order per tick: one
/// gaussian on property-drift days (`day % 28 == 14`, owned only);
/// nothing otherwise.
enum CitySystem {
    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        let config = balance.city
        let district = config.district(state.city.district)

        if state.day % GameState.daysPerWeek == 0 {
            if case .owned = state.city.ownership {
                let tax = Int((Double(state.city.propertyValue)
                    * config.weeklyPropertyTaxRate).rounded())
                if tax > 0 {
                    state.company.cash -= tax
                    state.ledger.post(LedgerEntry(
                        day: state.day, amount: -tax, category: .rent, label: "Property tax"
                    ))
                }
            }
            if district.weeklyReputationDrift != 0 {
                state.company.reputation = min(100, max(0,
                    state.company.reputation + district.weeklyReputationDrift
                ))
            }
        }

        if state.day % 28 == 14, case .owned(let purchasePrice) = state.city.ownership {
            let step = state.worldRNG.nextGaussian(sigma: config.propertyDriftSigma)
            let floor = Double(purchasePrice) * config.propertyValueMinFactor
            let ceiling = Double(purchasePrice) * config.propertyValueMaxFactor
            let value = Double(state.city.propertyValue) * (1 + step)
            state.city.propertyValue = Int(min(ceiling, max(floor, value)).rounded())
        }

        return []
    }

    // MARK: - Actions

    /// Moves the office to another district. Costs
    /// `relocationCostBase × destination price multiplier`, dents every
    /// hired employee's morale, and auto-sells an owned space at its
    /// current value first. Ignored for the current district and while
    /// unaffordable (net of the sale).
    static func relocateOffice(
        district: DistrictID,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard district != state.city.district else { return [] }
        let config = balance.city
        let cost = Int((Double(config.relocationCostBase)
            * config.district(district).priceMultiplier).rounded())
        let saleProceeds = state.city.ownership.isOwned ? state.city.propertyValue : 0
        guard state.company.cash + saleProceeds >= cost else { return [] }

        var events: [GameEvent] = []
        if state.city.ownership.isOwned {
            events.append(contentsOf: sellOffice(state: &state))
        }

        state.company.cash -= cost
        state.ledger.post(LedgerEntry(
            day: state.day,
            amount: -cost,
            category: .rent,
            label: "Moved to \(district.displayName)"
        ))
        state.city.district = district
        for index in state.employees.indices where !state.employees[index].isFounder {
            state.employees[index].morale = min(100, max(0,
                state.employees[index].morale - config.relocationMoralePenalty
            ))
        }
        events.append(.officeRelocated(district: district, day: state.day))
        return events
    }

    /// Buys the current space at the district's price. Ignored while
    /// already owned or unaffordable.
    static func buyOffice(state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        guard !state.city.ownership.isOwned else { return [] }
        let price = state.officePurchasePrice(in: state.city.district, balance: balance)
        guard state.company.cash >= price else { return [] }

        state.company.cash -= price
        state.ledger.post(LedgerEntry(
            day: state.day,
            amount: -price,
            category: .rent,
            label: "Bought the \(state.city.district.displayName) office"
        ))
        state.city.ownership = .owned(purchasePrice: price)
        state.city.propertyValue = price
        return [.officeBought(district: state.city.district, price: price, day: state.day)]
    }

    /// Sells an owned space at its current value and goes back to renting.
    /// Ignored while renting.
    static func sellOffice(state: inout GameState) -> [GameEvent] {
        guard state.city.ownership.isOwned else { return [] }
        let proceeds = state.city.propertyValue

        state.company.cash += proceeds
        state.ledger.post(LedgerEntry(
            day: state.day,
            amount: proceeds,
            category: .rent,
            label: "Sold the \(state.city.district.displayName) office"
        ))
        state.city.ownership = .renting
        state.city.propertyValue = 0
        return [.officeSold(district: state.city.district, price: proceeds, day: state.day)]
    }
}
