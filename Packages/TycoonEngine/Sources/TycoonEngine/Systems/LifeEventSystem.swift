import Foundation
import TycoonContent

/// The founder's life-event slot, called by `LifeSystem.run` at exactly the
/// point it used to roll its own event so the `rng` draw order is
/// untouched:
///
/// 1. the hit roll (`nextUniform()`, one word) — only on interval days with
///    a non-empty catalog,
/// 2. the weighted pick (`nextInt(in:)`, one word) — only on a hit with at
///    least one eligible event,
/// 3. applying the impact draws nothing.
///
/// The roll itself lives in `NarrativeSystem`, so a life beat can carry
/// choices, requirements and follow-ups exactly like a company beat —
/// including the pending-choice sheet and its deadline.
enum LifeEventSystem {
    static func roll(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        NarrativeSystem.rollLifeEvent(&state, balance, content)
    }
}
