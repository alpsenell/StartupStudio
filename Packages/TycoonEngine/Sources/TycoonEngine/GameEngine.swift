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

    /// Persistence hook. The engine calls it with the fresh state:
    /// 1. after any tick or `send` that produced at least one event,
    /// 2. on every 60th tick regardless of events,
    /// 3. at the end of `pauseForBackground()`.
    @ObservationIgnored public var autosave: (@MainActor (GameState) -> Void)?

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
        difficulty: Difficulty = .normal
    ) -> GameEngine {
        let (bundled, content) = loadBundledConfiguration()
        let balance = bundled.adjusted(for: difficulty)
        let state = GameState.newGame(
            companyName: companyName, seed: seed, balance: balance, difficulty: difficulty
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
            state: state, balance: bundled.adjusted(for: state.difficulty), content: content
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
    /// appending the returned events to the event log).
    public func send(_ action: GameAction) {
        let events = Reducer.apply(action, to: &state, balance: balance, content: content)
        if !events.isEmpty {
            autosave?(state)
        }
    }

    public func setSpeed(_ speed: SimSpeed) {
        guard state.gameOver == nil else { return }
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
        let events = Reducer.tick(&state, balance: balance, content: content)
        tickCount += 1
        if state.gameOver != nil {
            cancelTickLoop()
        } else if events.contains(where: \.pausesTimeline), state.speed != .paused {
            // Notable events stop the clock so the player can react; the
            // speed control resumes it.
            state.speed = .paused
            cancelTickLoop()
        }
        if !events.isEmpty || tickCount.isMultiple(of: 60) {
            autosave?(state)
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
