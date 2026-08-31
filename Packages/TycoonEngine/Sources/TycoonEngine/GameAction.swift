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

    /// Answers the pending narrative choice. `eventID` must match the
    /// choice on screen (a stale sheet can't resolve a newer beat) and
    /// `optionIndex` is the option's index in the definition, which
    /// `ChoiceOption.index` carries.
    case resolveChoice(eventID: String, optionIndex: Int)

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

    // MARK: The codebase

    /// Starts a new product on the codebase a previous product left
    /// behind: part of the pools already filled, and its technical debt
    /// inherited along with them.
    ///
    /// A separate case rather than an extra parameter on `startProduct`
    /// (Swift enum payloads take no defaults) — and separate is the better
    /// shape anyway: greenfield stays the action it always was, byte for
    /// byte, and the one screen that offers the trade is the only caller
    /// that has to know the trade exists.
    case startProductOnCodebase(
        typeID: String, topicID: String, name: String, focus: PhaseFocus, codebaseID: String
    )

    // MARK: Founder & people

    /// Spends the day getting better at one of the founder's own five
    /// attributes. Wallet money above self-study, energy always.
    case trainFounderSkill(skill: FounderSkill, method: TrainingMethod)
    /// One exchange with somebody standing in the networking room.
    case talkToContact(contactID: UUID, topic: ConversationTopic)
    /// Puts a deal to a contact on the terms they have already named.
    case makeNetworkingOffer(contactID: UUID, offer: NetworkingOffer)
    /// Calls it a night and closes the room.
    case leaveNetworkingEvent
    /// Spends the founder's own evening on their partner.
    case spendTimeWithPartner(PartnerActivity)
    /// An evening out with somebody on the team, on the founder rather
    /// than on the company.
    case hangOutWith(employeeID: UUID)
    /// The founder teaches somebody one of the three trainable skills.
    case mentorEmployee(employeeID: UUID, skill: TrainableSkill)
    /// Borrows past what the bank will lend the company on its own name,
    /// against the founder's home. Draws the unsecured headroom first.
    case takeSecuredLoan(amount: Int)
}

/// The skill a training course targets.
public enum TrainableSkill: String, Codable, Equatable, Sendable, CaseIterable {
    case coding, design, marketing
}
