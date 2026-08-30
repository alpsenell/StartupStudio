import TycoonContent

/// The company-event slot in the fixed system order, running last of the
/// original twelve.
///
/// The roll itself lives in `NarrativeSystem` — company events, life events
/// and their follow-ups all go through one machine — but the *call site*
/// stays here so the system's position, and therefore its `rng` draw order,
/// is exactly where it has always been:
///
/// 1. the hit roll (`nextUniform()`, one word) — only on interval days with
///    a non-empty catalog,
/// 2. the weighted pick (`nextInt(in:)`, one word) — only on a hit with at
///    least one eligible def,
/// 3. applying the effects draws nothing unless a def asks for a random
///    employee.
///
/// Cadence comes from `balance.narrative` when that block sets it, and from
/// the legacy top-level `eventCheckIntervalDays` / `eventChance` when it
/// doesn't — so a balance written before the narrative engine rolls
/// identically.
enum EventSystem {
    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        NarrativeSystem.rollCompanyEvent(&state, balance, content)
    }
}
