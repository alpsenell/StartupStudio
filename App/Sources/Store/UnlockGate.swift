import TycoonEngine

// MARK: Iteration 7 — the unlock (R6)

/// The one rule behind the paywall, as a pure function so a table can
/// pin it: the garage chapter is free, everything from chapter 2 needs
/// the purchase, and the daily (R3) is free in every chapter — the
/// owner's decision, because a shared company of one day that stops at
/// its own horizon is the advertisement, not the product.
enum UnlockRule {
    /// The first chapter the purchase buys.
    static let firstPaidChapter = 2

    static func allows(chapter: Int, entitled: Bool, mode: RunMode) -> Bool {
        entitled || chapter < firstPaidChapter || mode.isDaily || mode.isScenario || mode.isSeason || mode.isLeague
    }
}

/// The gate on the clock. `GameSession` composes it into
/// `engine.advanceGate`; the engine reads it before every tick and every
/// speed change, so a refused engine pauses and stays paused while every
/// action, screen and save still works. It reads the chapter from state —
/// not a flag in the save — so editing the file cannot open it, and it
/// only ever refuses ticks, so nothing is ever lost or hidden.
struct UnlockGate: AdvanceGate {
    static let gateID = "unlock"

    let id = UnlockGate.gateID
    /// Read live, so a purchase or a refund mid-run reaches the next tick.
    let isEntitled: @MainActor () -> Bool

    func allows(_ state: GameState) -> Bool {
        // `-unlocked` (DEBUG only): the screenshot pipeline's full game.
        if DebugLaunch.isUnlocked { return true }
        return UnlockRule.allows(
            chapter: state.progression.chapter, entitled: isEntitled(), mode: state.mode
        )
    }
}

/// When the paywall opens by itself, as a pure function so the order can
/// be pinned: only once StoreKit has answered (a cached "no" on the first
/// frame is not a reason to sell anything), only over a running game the
/// gate is actually refusing, only while the clock is stopped, and never
/// while the rail is still showing the reason the clock stopped — the
/// chapter card is the reward, and the paywall comes after it, not under
/// it. With a reason up, the way in is the lock on the speed control.
enum PaywallPresentation {
    static func autoPresents(
        gated: Bool,
        known: Bool,
        inGame: Bool,
        ended: Bool,
        paused: Bool,
        pauseReasonUp: Bool
    ) -> Bool {
        gated && known && inGame && !ended && paused && !pauseReasonUp
    }
}
