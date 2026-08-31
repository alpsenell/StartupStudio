import TycoonContent

/// Weekly market system, running after `LifeSystem` and before
/// `EmployeeSystem`: every `market.shiftIntervalDays` days each topic's
/// demand multiplier takes a seeded random-walk step, with a small chance
/// of a boom or crash jump. Booms and crashes emit events (which pause the
/// timeline) and are logged to `MarketState.recentEvents`; ordinary drift
/// is silent. Every shift also appends the post-shift multiplier to
/// `MarketState.history` (both logs are capped by the balance).
///
/// The same weekly beat keeps the standing ledger — a topic the studio has
/// something on the market in earns a little, a topic it has walked away
/// from loses a little. That runs after the walk and draws nothing; see
/// `StandingSystem`.
///
/// The RNG draw order is fixed for determinism: topics are visited in
/// catalog order, and each topic draws exactly three words — the drift
/// gaussian, the boom roll, and the crash roll. Off-interval days draw
/// nothing.
enum MarketSystem {
    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        let config = balance.market
        guard state.day % config.shiftIntervalDays == 0, !content.topics.isEmpty else { return [] }

        var events: [GameEvent] = []
        for topic in content.topics {
            let before = state.market.multiplier(for: topic.id)

            var delta = state.rng.nextGaussian(sigma: config.driftSigma)
            let boomRoll = state.rng.nextUniform()
            let crashRoll = state.rng.nextUniform()
            let boomed = boomRoll < config.boomChance
            let crashed = !boomed && crashRoll < config.crashChance
            if boomed { delta += config.boomJump }
            if crashed { delta -= config.crashJump }

            let after = min(config.multiplierMax, max(config.multiplierMin, before + delta))
            state.market.topics[topic.id] = TopicMarket(
                multiplier: after,
                lastChange: after - before
            )
            state.market.history[topic.id, default: []].append(after)
            trim(&state.market.history[topic.id, default: []], to: balance.marketHistoryWeeks)

            if boomed {
                events.append(.marketBoom(topicID: topic.id, day: state.day))
                state.market.recentEvents.append(MarketEvent(day: state.day, topicID: topic.id, kind: .boom))
            } else if crashed {
                events.append(.marketCrash(topicID: topic.id, day: state.day))
                state.market.recentEvents.append(MarketEvent(day: state.day, topicID: topic.id, kind: .crash))
            }
        }
        trim(&state.market.recentEvents, to: balance.marketEventLogCap)
        StandingSystem.applyWeeklyDrift(&state, balance, content)
        return events
    }

    /// Drops the oldest entries beyond `cap` (a non-positive cap keeps
    /// nothing).
    private static func trim<Element>(_ log: inout [Element], to cap: Int) {
        let overflow = log.count - max(0, cap)
        if overflow > 0 {
            log.removeFirst(overflow)
        }
    }
}
