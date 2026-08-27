import Foundation
import TycoonContent

/// The founder's life-event roll, lifted out of `LifeSystem` unchanged so
/// WS-B can grow it into choice-driven storylines without touching WS-A's
/// file. `LifeSystem.run` calls `LifeEventSystem.roll` at exactly the point
/// it used to call its own `rollLifeEvent`, so the RNG draw order is
/// untouched:
/// 1. the hit roll (`nextUniform()`, one word) — only on interval days with
///    a non-empty catalog,
/// 2. the weighted pick (`nextInt(in:)`, one word) — only on a hit with at
///    least one eligible event,
/// 3. applying the impact draws nothing.
enum LifeEventSystem {
    static func roll(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        let config = balance.life
        guard state.day % config.lifeEventIntervalDays == 0,
              !content.lifeEvents.isEmpty
        else { return [] }

        // 1. The hit roll.
        guard state.rng.nextUniform() < config.lifeEventChance else { return [] }

        // 2. The weighted pick over the eligible events, cumulative weights
        // in catalog order. Weights are >= 1 by the content contract;
        // max(1, _) keeps a malformed catalog from trapping the reducer.
        let eligible = content.lifeEvents.filter { isEligible($0, state: state) }
        guard !eligible.isEmpty else { return [] }
        let totalWeight = eligible.reduce(0) { $0 + max(1, $1.weight) }
        var remaining = state.rng.nextInt(in: 0...(totalWeight - 1))
        var picked = eligible[eligible.count - 1]
        for event in eligible {
            remaining -= max(1, event.weight)
            if remaining < 0 {
                picked = event
                break
            }
        }

        // 3. Apply the impact.
        return apply(picked, to: &state)
    }

    private static func isEligible(_ event: LifeEventDef, state: GameState) -> Bool {
        if let minStage = event.minStage {
            guard let stage = RelationshipStage(rawValue: minStage),
                  state.life.family.stage.rank >= stage.rank
            else { return false }
        }
        if event.requiresChildren, state.life.family.children.isEmpty {
            return false
        }
        if let cap = event.maxRelationships, state.life.meters.relationships >= cap {
            return false
        }
        return true
    }

    /// Applies one event's impact: meter deltas (clamped), the wallet
    /// delta, a cold window, and — unless the founder is already away — an
    /// away window (reason: the impact's `awayReason`, or the headline).
    private static func apply(_ event: LifeEventDef, to state: inout GameState) -> [GameEvent] {
        let impact = event.impact
        let day = state.day
        state.life.meters.apply(
            energy: impact.energy, health: impact.health,
            mood: impact.mood, relationships: impact.relationships
        )
        state.life.wallet += impact.wallet
        if impact.coldDays > 0 {
            state.life.coldUntilDay = day + impact.coldDays
        }

        var events: [GameEvent] = [.lifeEvent(eventID: event.id, day: day)]
        if impact.awayDays > 0, !state.life.isAway(day: day) {
            let until = day + impact.awayDays
            let reason = impact.awayReason ?? event.headline
            state.life.awayUntilDay = until
            state.life.awayReason = reason
            events.append(.founderAway(reason: reason, untilDay: until, day: day))
        }
        return events
    }
}
