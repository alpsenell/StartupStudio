import TycoonContent

/// Daily research system, running after `EmployeeSystem` has generated the
/// day's RP: completes the active node once its invested RP reaches the
/// research cost. Also hosts the startResearch/cancelResearch action
/// handlers used by `Reducer.apply`.
enum ResearchSystem {
    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        guard let nodeID = state.research.activeNodeID,
              let node = content.tech(nodeID),
              state.research.activeProgress >= node.researchCost
        else { return [] }

        return [complete(node, state: &state)]
    }

    /// Moves the node into `unlocked`, refunds any overshoot to `banked`,
    /// and clears the active slot. The caller must have verified that the
    /// invested progress covers the research cost.
    private static func complete(_ node: TechNode, state: inout GameState) -> GameEvent {
        state.research.unlocked.insert(node.id)
        state.research.banked += state.research.activeProgress - node.researchCost
        state.research.activeNodeID = nil
        state.research.activeProgress = 0
        return .researchCompleted(nodeID: node.id, day: state.day)
    }

    // MARK: - Actions

    /// Starts researching a node. Ignored for unknown ids, already-unlocked
    /// or already-active nodes, missing prerequisites, and insufficient
    /// cash. Switching away from another active node refunds its progress
    /// to `banked` (never its cash cost). Banked RP pours into the new node
    /// immediately — capped at the research cost so any overshoot stays
    /// banked — and a pour that covers the whole cost completes the node in
    /// the same apply.
    static func startResearch(
        nodeID: String,
        state: inout GameState,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard let node = content.tech(nodeID),
              !state.research.unlocked.contains(nodeID),
              state.research.activeNodeID != nodeID,
              node.prerequisites.allSatisfy({ state.research.unlocked.contains($0) }),
              state.company.cash >= node.cashCost
        else { return [] }

        if state.research.activeNodeID != nil {
            state.research.banked += state.research.activeProgress
            state.research.activeProgress = 0
            state.research.activeNodeID = nil
        }

        if node.cashCost > 0 {
            state.company.cash -= node.cashCost
            state.ledger.post(LedgerEntry(
                day: state.day,
                amount: -node.cashCost,
                category: .research,
                label: node.name
            ))
        }

        state.research.activeNodeID = node.id
        let poured = min(state.research.banked, node.researchCost)
        state.research.activeProgress = poured
        state.research.banked -= poured

        var events: [GameEvent] = [.researchStarted(nodeID: node.id, day: state.day)]
        if state.research.activeProgress >= node.researchCost {
            events.append(complete(node, state: &state))
        }
        return events
    }

    /// Cancels the active node: its progress is refunded to `banked` and
    /// the active slot cleared. No event; no-op when nothing is active.
    static func cancelResearch(state: inout GameState) -> [GameEvent] {
        guard state.research.activeNodeID != nil else { return [] }
        state.research.banked += state.research.activeProgress
        state.research.activeProgress = 0
        state.research.activeNodeID = nil
        return []
    }
}
