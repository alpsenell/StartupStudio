import Foundation
import TycoonContent

// MARK: S2 (office downgrade)

// Iteration 16 — S2. Moving one office tier down: the honest inverse of
// `FinanceSystem.upgradeOffice`.
//
// A smaller office saves its rent difference every week (and, owned, is
// sold at today's value first — moving means leaving the building), but
// the move costs money on the day, everybody's morale target sits lower
// for a quarter, and the name takes a dent. It is refused while there are
// more people than the smaller office has desks, more builds in flight
// than it has slots, and during an earn-out. Amenities the smaller office
// cannot hold go into storage — no upkeep, no effect — and come back on
// the next move up. `milestonesReached` keeps every rung ever stood on.
//
// Nothing here runs on the default path: `.downgradeOffice` is sent only
// from the app, and `GameState.officeDowngrade` is `nil` (and not encoded)
// on every run that never moved down.

/// What the last move down left behind. Lives on `GameState.officeDowngrade`.
public struct OfficeDowngradeState: Codable, Equatable, Sendable {
    /// The day of the move.
    public var day: Int
    /// Everybody's morale target is dragged until (not including) this day.
    public var moraleDragUntilDay: Int
    /// Amenities the smaller office could not hold, in `Amenity.allCases`
    /// order. Kept, not sold: no upkeep and no effect until an office that
    /// can hold them.
    public var storedAmenities: [Amenity]

    public init(day: Int, moraleDragUntilDay: Int, storedAmenities: [Amenity]) {
        self.day = day
        self.moraleDragUntilDay = moraleDragUntilDay
        self.storedAmenities = storedAmenities
    }
}

/// Everything the move down button and its sheet print, computed from the
/// same state the reducer will read.
public struct OfficeDowngradeQuote: Equatable, Sendable {
    public let from: OfficeTier
    public let to: OfficeTier
    /// This week's rent in the office today (0 when owned).
    public let rentNow: Int
    /// The weekly property tax on an owned office (0 while renting).
    public let propertyTaxNow: Int
    /// The smaller office's weekly rent, renting, in the same district.
    public let rentAfter: Int
    /// The weekly upkeep of the amenities that go into storage.
    public let upkeepStored: Int
    /// What an owned office sells for today; `nil` while renting.
    public let salePrice: Int?
    /// What the move costs on the day.
    public let moveCost: Int
    /// Points off everybody's morale target, and for how many days.
    public let moraleDrag: Double
    public let moraleDragDays: Int
    /// The morale target the office itself gives, before and after.
    public let officeMoraleNow: Double
    public let officeMoraleAfter: Double
    /// Reputation lost on the day.
    public let reputationCost: Double
    public let desksAfter: Int
    public let slotsAfter: Int
    /// Amenities the smaller office cannot hold.
    public let storedAmenities: [Amenity]
    /// Whether the smaller office is below the launch-event tier while
    /// the current one is not.
    public let losesLaunchEvents: Bool
    /// Every reason the move is refused today, first the most basic; empty
    /// when it is allowed.
    public let refusals: [String]

    /// What the space costs a week today minus what it would cost after:
    /// rent, property tax and the stored amenities' upkeep. Negative when
    /// an owned office's tax is less than the smaller office's rent.
    public var weeklySaved: Int { rentNow + propertyTaxNow + upkeepStored - rentAfter }
    /// Company cash after the sale and the move.
    public func cashAfter(from cash: Int) -> Int { cash + (salePrice ?? 0) - moveCost }
    public var refusal: String? { refusals.first }
}

extension OfficeTier {
    /// The tier one rung down the ladder: campus → studio → loft → garage,
    /// and `nil` at the bottom.
    public var previous: OfficeTier? {
        rank > 0 ? Self.allCases[rank - 1] : nil
    }
}

extension GameState {
    /// The move down on offer today, with its price and its refusals;
    /// `nil` in the garage.
    public func officeDowngradeQuote(balance: BalanceConfig) -> OfficeDowngradeQuote? {
        guard let target = company.officeTier.previous else { return nil }
        let config = balance.officeDowngrade
        let current = company.officeTier
        let targetDef = balance.office(target)

        let stored = ownedAmenities.filter { balance.company.amenity($0).minTier.rank > target.rank }
        var after = self
        after.company.officeTier = target
        after.city.ownership = .renting
        after.city.propertyValue = 0
        after.amenities.subtract(stored)

        let owned = city.ownership.isOwned
        let tax = owned
            ? Int((Double(city.propertyValue) * balance.city.weeklyPropertyTaxRate).rounded())
            : 0
        let listedRent = Double(balance.office(current).weeklyRent)
            * balance.city.district(city.district).rentMultiplier
        let moveCost = max(0, config.moveCostBase)
            + max(0, config.moveCostRentWeeks) * Int(listedRent.rounded())
        let launchTier = OfficeTier(rawValue: balance.launchEventMinTier)

        var refusals: [String] = []
        if investors.earnOut != nil {
            refusals.append("Not during the earn-out: the buyer is paying for this office")
        }
        let excessPeople = headcount - targetDef.headcountCap
        if excessPeople > 0 {
            refusals.append(
                "Let \(excessPeople) \(excessPeople == 1 ? "person" : "people") go first: the \(target.displayName) has \(targetDef.headcountCap) desks"
            )
        }
        let excessBuilds = buildsInFlight - target.concurrentDevSlots
        if excessBuilds > 0 {
            refusals.append(
                "Ship \(excessBuilds) build\(excessBuilds == 1 ? "" : "s") first: the \(target.displayName) runs \(target.concurrentDevSlots) at a time"
            )
        }
        let sale = owned ? city.propertyValue : 0
        if company.cash + sale < moveCost {
            refusals.append("The move costs \(moveCost.dollars) and there is \((company.cash + sale).dollars)")
        }

        return OfficeDowngradeQuote(
            from: current,
            to: target,
            rentNow: officeWeeklyRent(balance: balance),
            propertyTaxNow: tax,
            rentAfter: after.officeWeeklyRent(balance: balance),
            upkeepStored: amenityWeeklyUpkeep(balance: balance) - after.amenityWeeklyUpkeep(balance: balance),
            salePrice: owned ? city.propertyValue : nil,
            moveCost: moveCost,
            moraleDrag: config.moraleDrag,
            moraleDragDays: config.moraleDragDays,
            officeMoraleNow: balance.staff.officeMoraleBonus[current.rawValue] ?? 0,
            officeMoraleAfter: balance.staff.officeMoraleBonus[target.rawValue] ?? 0,
            reputationCost: config.reputationCost,
            desksAfter: targetDef.headcountCap,
            slotsAfter: target.concurrentDevSlots,
            storedAmenities: stored,
            losesLaunchEvents: launchTier.map { current.rank >= $0.rank && target.rank < $0.rank } ?? false,
            refusals: refusals
        )
    }

    /// Why the move down would be refused today, or `nil`.
    public func officeDowngradeBlocker(balance: BalanceConfig) -> String? {
        guard let quote = officeDowngradeQuote(balance: balance) else {
            return "The garage is as small as it gets"
        }
        return quote.refusal
    }

    /// What the last move down still does to everybody's morale target:
    /// `moraleDrag` until the drag's day. Exactly 0 on a run that never
    /// moved down.
    public func officeDowngradeMoraleDrag(balance: BalanceConfig) -> Double {
        guard let downgrade = officeDowngrade, day < downgrade.moraleDragUntilDay else { return 0 }
        return balance.officeDowngrade.moraleDrag
    }

    /// Amenities in storage since the last move down (empty otherwise).
    public var officeStoredAmenities: [Amenity] {
        officeDowngrade?.storedAmenities ?? []
    }
}

enum OfficeDowngradeSystem {
    /// Moves the company one office tier down. Ignored in the garage and
    /// for every reason `officeDowngradeQuote` refuses.
    static func downgrade(state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        guard let quote = state.officeDowngradeQuote(balance: balance), quote.refusals.isEmpty else {
            return []
        }
        var events: [GameEvent] = []
        if state.city.ownership.isOwned {
            events.append(contentsOf: CitySystem.sellOffice(state: &state))
        }
        if quote.moveCost > 0 {
            state.company.cash -= quote.moveCost
            state.ledger.post(LedgerEntry(
                day: state.day,
                amount: -quote.moveCost,
                category: .other,
                label: "Moved down: \(quote.to.displayName)"
            ))
        }
        state.company.officeTier = quote.to
        state.company.reputation = max(0, state.company.reputation - quote.reputationCost)

        // Storage keeps what the last move already put there.
        let alreadyStored = state.officeStoredAmenities
        state.amenities.subtract(quote.storedAmenities)
        let stored = Amenity.allCases.filter {
            alreadyStored.contains($0) || quote.storedAmenities.contains($0)
        }
        state.officeDowngrade = OfficeDowngradeState(
            day: state.day,
            moraleDragUntilDay: state.day + max(0, quote.moraleDragDays),
            storedAmenities: stored
        )
        events.append(.officeDowngraded(tier: quote.to, day: state.day))
        return events
    }

    /// Called from the move up: the stored amenities the new office can
    /// hold come out of storage, free. Nothing to do on a run that never
    /// moved down.
    static func unpackStorage(state: inout GameState, balance: BalanceConfig) {
        guard var downgrade = state.officeDowngrade, !downgrade.storedAmenities.isEmpty else { return }
        let tier = state.company.officeTier
        let fits = downgrade.storedAmenities.filter { balance.company.amenity($0).minTier.rank <= tier.rank }
        guard !fits.isEmpty else { return }
        state.amenities.formUnion(fits)
        downgrade.storedAmenities.removeAll { fits.contains($0) }
        state.officeDowngrade = downgrade
    }
}

#if DEBUG
/// `-autoRoute s2-downgrade|s2-owned|s2-refused`: dresses the loaded save
/// through the engine for a screenshot. Debug builds only; nothing in the
/// game sends `.officeDowngradeDebugSeed`.
///
/// - `legal`: the newest hires let go down to the smaller office's desks,
///   the newest builds shipped down to its slots — the move is allowed.
/// - `owned`: the same, with the office bought at today's price first.
/// - `refused`: nothing: the studio fixture as it ships is over both caps.
enum OfficeDowngradeDebugSeed {
    static func apply(
        scenario: String,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard scenario == "legal" || scenario == "owned",
              let target = state.company.officeTier.previous
        else { return [] }
        var events: [GameEvent] = []
        let cap = balance.office(target).headcountCap
        while state.headcount > cap,
              let newest = state.employees
                  .filter({ !$0.isFounder && !$0.isCofounder })
                  .max(by: { $0.hiredDay < $1.hiredDay }) {
            events += EmployeeSystem.fire(employeeID: newest.id, state: &state, balance: balance)
        }
        while state.buildsInFlight > target.concurrentDevSlots,
              let index = state.products.lastIndex(where: {
                  if case .development = $0.stage { true } else { false }
              }),
              case .development(var dev) = state.products[index].stage,
              let type = content.productType(state.products[index].typeID) {
            dev.codePts = max(dev.codePts, balance.shipCodeThreshold * type.codePts)
            state.products[index].stage = .development(dev)
            let shipped = ProductSystem.ship(
                productID: state.products[index].id, state: &state, balance: balance, content: content
            )
            guard !shipped.isEmpty else { break }
            events += shipped
        }
        if scenario == "owned", !state.city.ownership.isOwned {
            let price = state.officePurchasePrice(in: state.city.district, balance: balance)
            state.city.ownership = .owned(purchasePrice: price)
            state.city.propertyValue = price
        }
        return events
    }
}
#endif

// MARK: end S2
