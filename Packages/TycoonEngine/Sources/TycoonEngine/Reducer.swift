import TycoonContent

/// The pure simulation reducer. One call to `tick` advances the state by
/// exactly one game day — always, regardless of simulation speed. Player
/// commands go through `apply` between ticks.
public enum Reducer {
    /// A simulation system: a pure function advancing one slice of the state
    /// for the current day, returning any events it produced.
    typealias System = @Sendable (inout GameState, BalanceConfig, ContentCatalog) -> [GameEvent]

    /// Systems run in this order every day:
    /// Life → Employee → Product → Contract → Research → Marketing → Finance → Event.
    /// Life runs first so today's founder condition scales today's output.
    static let systems: [System] = [
        LifeSystem.run,
        EmployeeSystem.run,
        ProductSystem.run,
        ContractSystem.run,
        ResearchSystem.run,
        MarketingSystem.run,
        FinanceSystem.run,
        EventSystem.run,
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
            events = EmployeeSystem.fire(employeeID: employeeID, state: &state)
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
        }

        state.logEvents(events)
        return events
    }
}
