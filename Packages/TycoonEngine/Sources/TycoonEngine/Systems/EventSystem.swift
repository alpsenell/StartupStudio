import TycoonContent

/// Daily random-event system, running last in the fixed system order: every
/// `eventCheckIntervalDays` days it rolls once against `eventChance`, and on
/// a hit it picks one `EventDef` from the content catalog (weighted by
/// `weight`) and applies its impact.
///
/// The RNG draw order is fixed for determinism:
/// 1. the hit roll (`nextUniform()`, one word) — only on interval days,
/// 2. the weighted pick (`nextInt(in:)`, one word) — only on a hit,
/// 3. applying the impact draws nothing.
/// Off-interval days — and interval days with an empty event catalog, which
/// is static content and so identical across replays — draw nothing at all.
enum EventSystem {
    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        guard state.day % balance.eventCheckIntervalDays == 0,
              !content.events.isEmpty
        else { return [] }

        // 1. The hit roll.
        guard state.rng.nextUniform() < balance.eventChance else { return [] }

        // 2. The weighted pick over cumulative weights in catalog order.
        // Weights are >= 1 by the content contract; max(1, _) keeps a
        // malformed catalog from trapping the pure reducer.
        let totalWeight = content.events.reduce(0) { $0 + max(1, $1.weight) }
        var remaining = state.rng.nextInt(in: 0...(totalWeight - 1))
        var picked = content.events[content.events.count - 1]
        for event in content.events {
            remaining -= max(1, event.weight)
            if remaining < 0 {
                picked = event
                break
            }
        }

        // 3. Apply the impact.
        apply(picked, to: &state)
        return [.randomEvent(eventID: picked.id, day: state.day)]
    }

    /// Applies one event's impact. Cash deltas post to the ledger under
    /// `.other`, labeled with the headline; reputation clamps to 0...100;
    /// hype deltas land on the in-development product (clamped at 0) and are
    /// a silent no-op when nothing is in development — the `.randomEvent`
    /// still emits either way.
    private static func apply(_ event: EventDef, to state: inout GameState) {
        switch event.impact {
        case .cashDelta(let amount):
            state.company.cash += amount
            state.ledger.post(LedgerEntry(
                day: state.day, amount: amount, category: .other, label: event.headline
            ))
        case .reputationDelta(let amount):
            state.company.reputation = min(100, max(0, state.company.reputation + amount))
        case .hypeDeltaOnActiveProduct(let amount):
            guard let index = state.products.firstIndex(where: { product in
                if case .development = product.stage { return true }
                return false
            }), case .development(var dev) = state.products[index].stage else { return }
            dev.hype = max(0, dev.hype + amount)
            state.products[index].stage = .development(dev)
        }
    }
}
