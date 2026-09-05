import Observation
import TycoonContent

/// Observable shell around the pure reducer core. Owns the real-time tick
/// loop; all simulation logic lives in `Reducer.tick` / `Reducer.apply`.
/// Wall-clock time is used only for tick scheduling — never inside the
/// simulation itself.
@MainActor
@Observable
public final class GameEngine {
    public private(set) var state: GameState
    public let balance: BalanceConfig
    public let content: ContentCatalog
    /// The events that stopped the clock on the tick that auto-paused —
    /// what the UI shows in its "why did time stop?" banner. Empty
    /// whenever the pause did not come from an event, and cleared the
    /// moment the player changes speed.
    public private(set) var lastPauseEvents: [GameEvent] = []

    /// Persistence hook. The engine calls it with the fresh state:
    /// 1. after any tick or `send` that produced at least one event,
    /// 2. on every 60th tick regardless of events,
    /// 3. at the end of `pauseForBackground()`.
    @ObservationIgnored public var autosave: (@MainActor (GameState) -> Void)?

    // MARK: Iteration 7 — the app's two hooks

    /// Whether the clock may run. Consulted by `performTick` and
    /// `setSpeed`; `nil` (every engine test) means always. The app installs
    /// the unlock gate (R6) and the daily's horizon (R3) here: a refused
    /// engine pauses and stays paused, but every action, screen and save
    /// still works — the gate only ever refuses ticks.
    @ObservationIgnored public var advanceGate: (@MainActor (GameState) -> Bool)?

    /// Called with the events of every tick and every `send` that produced
    /// any, after the state has them. The app fans it out to the tour (R1)
    /// and Game Center (R3).
    @ObservationIgnored public var eventSink: (@MainActor ([GameEvent]) -> Void)?

    /// Total weekly fixed costs: operating cost + current office rent +
    /// payroll across all employees + the founder's salary + amenity
    /// upkeep (rent and upkeep after the Operations discount).
    public var weeklyBurn: Int {
        balance.weeklyOperatingCost
            + state.officeWeeklyRent(balance: balance)
            + state.employees.reduce(0) { $0 + $1.weeklySalary }
            + state.life.founderSalary
            + state.amenityWeeklyUpkeep(balance: balance)
    }

    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var speedBeforeBackground: SimSpeed?
    @ObservationIgnored private var tickCount = 0

    public init(state: GameState, balance: BalanceConfig, content: ContentCatalog) {
        self.state = state
        self.balance = balance
        self.content = content
    }

    deinit {
        tickTask?.cancel()
    }

    /// Starts a new game using the bundled balance (rescaled once for
    /// `difficulty`, so `engine.balance` is already adjusted) and content.
    public static func newGame(
        companyName: String,
        seed: UInt64,
        difficulty: Difficulty = .normal,
        founder: FounderProfile = .default,
        origin: FoundingOrigin = .garage,
        heirloom: Heirloom? = nil,
        rules: GameRules = .standard,
        mode: RunMode = .standard
    ) -> GameEngine {
        let (bundled, content) = loadBundledConfiguration()
        // Difficulty first, then the run's rules — `.standard` is the
        // identity, so a standard run's balance is what it always was.
        let balance = bundled.adjusted(for: difficulty).applying(rules)
        let state = GameState.newGame(
            companyName: companyName, seed: seed, balance: balance,
            difficulty: difficulty, founder: founder, origin: origin, content: content,
            heirloom: heirloom, rules: rules, mode: mode
        )
        return GameEngine(state: state, balance: balance, content: content)
    }

    /// Rebuilds an engine around a saved state using the bundled balance
    /// (rescaled once for the save's difficulty) and content. The state
    /// comes back paused and no tick loop is running.
    public static func resume(state: GameState) -> GameEngine {
        let (bundled, content) = loadBundledConfiguration()
        var state = state
        state.speed = .paused
        return GameEngine(
            state: state,
            balance: bundled.adjusted(for: state.difficulty).applying(state.rules),
            content: content
        )
    }

    private static func loadBundledConfiguration() -> (BalanceConfig, ContentCatalog) {
        guard let balance = try? BalanceConfig.loadBundled() else {
            fatalError("TycoonEngine is missing its bundled Balance.json resource")
        }
        guard let content = try? ContentCatalog.loadBundled() else {
            fatalError("TycoonContent is missing one of its bundled content resources")
        }
        return (balance, content)
    }

    /// Applies a player action synchronously via `Reducer.apply` (which owns
    /// appending the returned events to the event log), and hands back what
    /// it produced.
    ///
    /// The events are returned so a caller that needs to know *what
    /// happened* — did that conversation land, did the activity actually
    /// go ahead — can read it from the reducer rather than re-deriving it
    /// from the state or fishing the tail of the capped event log. An
    /// empty array means the action was refused.
    @discardableResult
    public func send(_ action: GameAction) -> [GameEvent] {
        let events = Reducer.apply(action, to: &state, balance: balance, content: content)
        if !events.isEmpty {
            // Iteration 7 (R5): the tick that ended the run cancelled the
            // loop for good and left `speed` where the player had it. If
            // this action cleared the game over — "Keep running it" is the
            // only one that can — the clock is allowed to run again, so
            // the loop comes back here rather than waiting for a speed
            // change to a value the control is already showing.
            if state.gameOver == nil, state.speed != .paused, !isTickLoopRunning, mayAdvance {
                restartTickLoop()
            }
            autosave?(state)
            eventSink?(events)
        }
        return events
    }

    /// Whether the app's gate lets the clock run right now.
    public var mayAdvance: Bool {
        advanceGate?(state) ?? true
    }

    public func setSpeed(_ speed: SimSpeed) {
        guard state.gameOver == nil else { return }
        // Iteration 7: a gated engine will not run; the speed control
        // opens whatever the gate is about (the paywall, the daily's
        // result). Pausing is always allowed.
        guard speed == .paused || mayAdvance else { return }
        // The player answered the pause; the banner's reason goes with it.
        lastPauseEvents = []
        state.economy.pauseEvents = []
        state.speed = speed
        restartTickLoop()
    }

    /// Permanently stops this engine: cancels the tick loop and detaches the
    /// autosave hook. Call before discarding an engine (e.g. "New game"), so
    /// a replaced instance can never keep ticking or overwrite the live
    /// game's save file.
    public func shutdown() {
        cancelTickLoop()
        autosave = nil
    }

    /// Remembers the current speed, pauses, cancels the tick loop, and
    /// autosaves. Call when the app moves to the background.
    public func pauseForBackground() {
        speedBeforeBackground = state.speed
        state.speed = .paused
        cancelTickLoop()
        autosave?(state)
    }

    /// Restores the speed remembered by `pauseForBackground` (no-op if the
    /// game was already paused). No catch-up ticks are ever performed.
    public func resumeAfterForeground() {
        guard let previous = speedBeforeBackground else { return }
        speedBeforeBackground = nil
        if previous != .paused {
            setSpeed(previous)
        }
    }

    // MARK: - Tick loop

    /// One simulation tick plus the autosave policy. Internal so tests can
    /// drive the tick path synchronously without the real-time loop.
    /// A game-over engine never ticks or autosaves again; the tick that
    /// produces game over fires one final event-driven autosave and then the
    /// loop is cancelled for good.
    func performTick() {
        guard state.gameOver == nil else {
            cancelTickLoop()
            return
        }
        // Iteration 7: the gate is read before every tick, so a purchase
        // revoked or a horizon reached mid-run stops the clock on the
        // next day rather than at the next launch. Nothing is lost: the
        // state is exactly as the last tick left it, and it autosaves.
        guard mayAdvance else {
            state.speed = .paused
            cancelTickLoop()
            autosave?(state)
            return
        }
        let events = Reducer.tick(&state, balance: balance, content: content)
        tickCount += 1
        if state.gameOver != nil {
            cancelTickLoop()
        } else if !state.economy.pauseEvents.isEmpty, state.speed != .paused {
            // `PausePolicy` already graded the day and spent the pause
            // budget; the speed control resumes. The reasons are kept so
            // the UI can say why.
            lastPauseEvents = state.economy.pauseEvents
            state.speed = .paused
            cancelTickLoop()
        }
        if !events.isEmpty || tickCount.isMultiple(of: 60) {
            autosave?(state)
        }
        if !events.isEmpty {
            eventSink?(events)
        }
    }

    /// Whether the real-time loop is currently scheduled. Internal for tests.
    var isTickLoopRunning: Bool { tickTask != nil }

    private func cancelTickLoop() {
        tickTask?.cancel()
        tickTask = nil
    }

    /// Runs ticks on absolute deadlines: `deadline += interval` each cycle so
    /// cadence never drifts. After a hitch longer than one second past the
    /// deadline, the schedule resets to `now + interval` instead of
    /// burst-ticking to catch up.
    private func restartTickLoop() {
        cancelTickLoop()
        guard let ticksPerSecond = state.speed.ticksPerSecond else { return }
        let interval = Duration.seconds(1.0 / ticksPerSecond)

        tickTask = Task { [weak self] in
            let clock = ContinuousClock()
            var deadline = clock.now.advanced(by: interval)
            while !Task.isCancelled {
                do {
                    try await clock.sleep(until: deadline)
                } catch {
                    return // cancelled while sleeping
                }
                guard let self else { return }

                self.performTick()

                deadline = deadline.advanced(by: interval)
                let now = clock.now
                if now > deadline.advanced(by: .seconds(1)) {
                    deadline = now.advanced(by: interval)
                }
            }
        }
    }
}
