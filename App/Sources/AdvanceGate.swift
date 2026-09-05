import TycoonEngine

// MARK: Iteration 7

/// Something that can refuse to let the clock run.
///
/// `GameSession` composes every installed gate into `engine.advanceGate`;
/// the engine reads it before each tick and each speed change. A refused
/// engine pauses and stays paused — every action, screen and save still
/// works, because a gate only ever refuses ticks. R6 installs the unlock
/// gate (chapter 2 and beyond, unless entitled), R3 the daily's horizon.
@MainActor
protocol AdvanceGate {
    /// Stable, so a lane can remove its own gate: `"unlock"`, `"daily"`.
    var id: String { get }
    func allows(_ state: GameState) -> Bool
}
