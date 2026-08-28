import Foundation

/// Player-initiated commands, applied synchronously via `Reducer.apply`.
public enum GameAction: Codable, Equatable, Sendable {
    case startProduct(typeID: String, topicID: String, name: String, focus: PhaseFocus)
    case setPhaseFocus(productID: UUID, focus: PhaseFocus)
    case ship(productID: UUID)
    case hire(candidateID: UUID)
    case fire(employeeID: UUID)
    case assign(employeeID: UUID, to: Assignment)
    case startResearch(nodeID: String)
    case cancelResearch
    case acceptContract(offerID: UUID)
    case startCampaign(kindID: String, productID: UUID)
    case upgradeOffice
    case setWorkSchedule(WorkSchedule)
    /// Weekly founder salary, clamped to 0...`balance.life.founderSalaryMax`.
    case setFounderSalary(Int)
    case planWeekend(WeekendActivity)
    case upgradeHome
    case advanceRelationship
    case haveChild
    /// One-on-one morale boost, at most once per praise cooldown.
    case praise(employeeID: UUID)
    /// Sets a new weekly salary (raises lift morale, cuts hurt it).
    case adjustSalary(employeeID: UUID, weeklySalary: Int)
    case promote(employeeID: UUID)
    case demote(employeeID: UUID)
    /// Paid training: boosts one skill and morale, per-employee cooldown.
    case train(employeeID: UUID, skill: TrainableSkill)
    case takeLoan(amount: Int)
    case repayLoan(amount: Int)
    /// Buys an office amenity (tier-gated, cash up front, weekly upkeep).
    case buildAmenity(Amenity)
    /// Matches a rival's pending poach offer: the employee's salary rises
    /// to the offered amount and their loyalty jumps.
    case matchPoachOffer
    /// Lets the poached employee leave for the rival.
    case declinePoachOffer
    /// Sells the company to the rival behind the pending buyout offer —
    /// ends the run as a successful exit.
    case acceptBuyout
    case declineBuyout
    /// Buys a rival studio outright (cash- and dominance-gated); part of
    /// its team joins.
    case acquireRival(rivalID: UUID)
    /// Moves the office to another district (an owned space is auto-sold
    /// first).
    case relocateOffice(district: DistrictID)
    /// Buys the current office space instead of renting it.
    case buyOffice
    /// Sells an owned office space and goes back to renting.
    case sellOffice
    /// Does a same-day life activity (gym, walk, cinema, restaurant) —
    /// instant meter effects, wallet cost, cooldown-gated.
    case doInstantActivity(InstantActivity)
    /// Buys a possession from the shop (wallet money, once per item).
    case buyItem(itemID: String)
    /// Coffee with one employee (small morale + loyalty, cooldown-gated).
    case grabCoffee(employeeID: UUID)
    /// A one-on-one: big loyalty, clears the low-morale streak.
    case oneOnOne(employeeID: UUID)
    /// A gift (pricier, big morale + loyalty).
    case giveGift(employeeID: UUID)
    /// Dinner for the whole team (per-head cost, global cooldown).
    case teamDinner
    /// Answers the pending staff event.
    case resolveStaffEvent(choice: StaffEventChoice)

    // Reserved regions — each workstream appends its new cases inside its
    // own region and nowhere else, so six branches never touch the same
    // line. Keep the regions in this order.

    // MARK: WS-A

    /// Repositions a released product on the price ladder. Budget trades
    /// margin for reach, premium the reverse — and a premium price on a
    /// product the press did not love drives subscribers away.
    case setPriceTier(productID: UUID, tier: PriceTier)
    /// Puts a released product back into a short patch cycle. On
    /// completion it gains quality, is re-reviewed, and gets one bumper
    /// sales week.
    case startUpdate(productID: UUID)
    /// Sets the pace the whole company works at.
    case setWorkPace(WorkPace)

    // MARK: WS-B

    // MARK: WS-F

    /// Takes the investor's money: cash in, equity out, and a board seat
    /// if the term sheet asked for one.
    case acceptInvestment
    /// Turns the term sheet down and stays independent.
    case declineInvestment
    /// Files to go public. Gated on valuation, profitable quarters and
    /// recurring revenue; ends the run as an IPO.
    case fileIPO
    /// Spends a day of founder time interviewing a candidate, revealing
    /// the trait their CV didn't mention.
    case interviewCandidate(candidateID: UUID)
    /// Clears a candidate out of the pool without hiring them.
    case passOnCandidate(candidateID: UUID)
}

/// The skill a training course targets.
public enum TrainableSkill: String, Codable, Equatable, Sendable, CaseIterable {
    case coding, design, marketing
}
