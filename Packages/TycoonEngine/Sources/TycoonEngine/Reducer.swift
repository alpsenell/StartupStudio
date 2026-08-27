import TycoonContent

/// The pure simulation reducer. One call to `tick` advances the state by
/// exactly one game day — always, regardless of simulation speed. Player
/// commands go through `apply` between ticks.
public enum Reducer {
    /// A simulation system: a pure function advancing one slice of the state
    /// for the current day, returning any events it produced.
    typealias System = @Sendable (inout GameState, BalanceConfig, ContentCatalog) -> [GameEvent]

    /// Systems run in this order every day:
    /// Life → Market → Rival → Employee → Social → Product → Contract →
    /// Research → Marketing → City → Finance → Event.
    /// Life runs first so today's founder condition scales today's output;
    /// Market shifts before sales post so a weekly shift prices the same
    /// day's sales; Rival runs after Market (a rival shipping dents the
    /// fresh multipliers) and before Employee (a poach resolving today
    /// precedes the morale/quit sweep); Social runs right after Employee
    /// so loyalty and bonds track the post-sweep roster; City settles
    /// property tax and address prestige just before Finance's weekly
    /// bill. Rival, Social, and City draw only from `worldRNG`, so their
    /// positions never disturb the original `rng` stream.
    static let systems: [System] = [
        LifeSystem.run,
        MarketSystem.run,
        RivalSystem.run,
        EmployeeSystem.run,
        SocialSystem.run,
        ProductSystem.run,
        ContractSystem.run,
        ResearchSystem.run,
        MarketingSystem.run,
        CitySystem.run,
        FinanceSystem.run,
        EventSystem.run,

        // Reserved regions — each workstream appends its new systems inside
        // its own region and nowhere else. A system's position in this
        // array fixes when it runs (and, for anything drawing from `rng`,
        // the draw order), so never insert outside your region.

        // MARK: WS-A

        // MARK: WS-B

        // MARK: WS-F
    ]

    /// Advances the state by one game day. No-op once the game is over.
    /// Returned events are also appended to `state.eventLog`.
    @discardableResult
    public static func tick(
        _ state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard state.gameOver == nil else { return [] }

        state.day += 1

        var events: [GameEvent] = []
        for system in systems {
            events.append(contentsOf: system(&state, balance, content))
        }

        state.logEvents(events)
        return events
    }

    /// Applies a player action synchronously. Invalid actions are ignored and
    /// return no events; the game being over ignores everything. Returned
    /// events are also appended to `state.eventLog`.
    @discardableResult
    public static func apply(
        _ action: GameAction,
        to state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard state.gameOver == nil else { return [] }

        let events: [GameEvent]
        switch action {
        case let .startProduct(typeID, topicID, name, focus):
            events = ProductSystem.startProduct(
                typeID: typeID, topicID: topicID, name: name, focus: focus,
                state: &state, content: content
            )
        case let .setPhaseFocus(productID, focus):
            events = ProductSystem.setPhaseFocus(productID: productID, focus: focus, state: &state)
        case let .ship(productID):
            events = ProductSystem.ship(
                productID: productID, state: &state, balance: balance, content: content
            )
        case let .hire(candidateID):
            events = EmployeeSystem.hire(candidateID: candidateID, state: &state, balance: balance)
        case let .fire(employeeID):
            events = EmployeeSystem.fire(employeeID: employeeID, state: &state, balance: balance)
        case let .assign(employeeID, assignment):
            events = EmployeeSystem.assign(employeeID: employeeID, to: assignment, state: &state)
        case let .startResearch(nodeID):
            events = ResearchSystem.startResearch(nodeID: nodeID, state: &state, content: content)
        case .cancelResearch:
            events = ResearchSystem.cancelResearch(state: &state)
        case let .acceptContract(offerID):
            events = ContractSystem.acceptContract(offerID: offerID, state: &state)
        case let .startCampaign(kindID, productID):
            events = MarketingSystem.startCampaign(
                kindID: kindID, productID: productID,
                state: &state, balance: balance, content: content
            )
        case .upgradeOffice:
            events = FinanceSystem.upgradeOffice(state: &state, balance: balance)
        case let .setWorkSchedule(schedule):
            events = LifeSystem.setWorkSchedule(schedule, state: &state)
        case let .setFounderSalary(amount):
            events = LifeSystem.setFounderSalary(amount, state: &state, balance: balance)
        case let .planWeekend(activity):
            events = LifeSystem.planWeekend(activity, state: &state)
        case .upgradeHome:
            events = LifeSystem.upgradeHome(state: &state, balance: balance)
        case .advanceRelationship:
            events = LifeSystem.advanceRelationship(state: &state, balance: balance, content: content)
        case .haveChild:
            events = LifeSystem.haveChild(state: &state, balance: balance, content: content)
        case let .praise(employeeID):
            events = EmployeeSystem.praise(employeeID: employeeID, state: &state, balance: balance)
        case let .adjustSalary(employeeID, weeklySalary):
            events = EmployeeSystem.adjustSalary(
                employeeID: employeeID, weeklySalary: weeklySalary, state: &state, balance: balance
            )
        case let .promote(employeeID):
            events = EmployeeSystem.promote(employeeID: employeeID, state: &state, balance: balance)
        case let .demote(employeeID):
            events = EmployeeSystem.demote(employeeID: employeeID, state: &state, balance: balance)
        case let .train(employeeID, skill):
            events = EmployeeSystem.train(
                employeeID: employeeID, skill: skill, state: &state, balance: balance
            )
        case let .takeLoan(amount):
            events = FinanceSystem.takeLoan(amount: amount, state: &state, balance: balance)
        case let .repayLoan(amount):
            events = FinanceSystem.repayLoan(amount: amount, state: &state)
        case let .buildAmenity(amenity):
            events = FinanceSystem.buildAmenity(amenity, state: &state, balance: balance)
        case .matchPoachOffer:
            events = RivalSystem.matchPoachOffer(state: &state, balance: balance)
        case .declinePoachOffer:
            events = RivalSystem.declinePoachOffer(state: &state, balance: balance)
        case .acceptBuyout:
            events = RivalSystem.acceptBuyout(state: &state)
        case .declineBuyout:
            events = RivalSystem.declineBuyout(state: &state)
        case let .acquireRival(rivalID):
            events = RivalSystem.acquireRival(
                rivalID: rivalID, state: &state, balance: balance, content: content
            )
        case let .relocateOffice(district):
            events = CitySystem.relocateOffice(district: district, state: &state, balance: balance)
        case .buyOffice:
            events = CitySystem.buyOffice(state: &state, balance: balance)
        case .sellOffice:
            events = CitySystem.sellOffice(state: &state)
        case let .doInstantActivity(activity):
            events = LifeSystem.doInstantActivity(activity, state: &state, balance: balance)
        case let .buyItem(itemID):
            events = LifeSystem.buyItem(itemID: itemID, state: &state, balance: balance)
        case let .grabCoffee(employeeID):
            events = SocialSystem.grabCoffee(employeeID: employeeID, state: &state, balance: balance)
        case let .oneOnOne(employeeID):
            events = SocialSystem.oneOnOne(employeeID: employeeID, state: &state, balance: balance)
        case let .giveGift(employeeID):
            events = SocialSystem.giveGift(employeeID: employeeID, state: &state, balance: balance)
        case .teamDinner:
            events = SocialSystem.teamDinner(state: &state, balance: balance)
        case let .resolveStaffEvent(choice):
            events = SocialSystem.resolveStaffEvent(choice: choice, state: &state, balance: balance)

        // Reserved regions — each workstream adds the handlers for the
        // cases it appended to `GameAction` inside its own region and
        // nowhere else. The switch stays exhaustive: no `default`.

        // MARK: WS-A

        // MARK: WS-B

        // MARK: WS-F
        }

        state.logEvents(events)
        return events
    }
}
