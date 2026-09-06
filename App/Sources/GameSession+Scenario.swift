import Foundation
import TycoonEngine
import TycoonSave

// MARK: Iteration 8 — scenarios

/// A scenario under way: which one, the day it started, the state it
/// started from (the objective is measured against it), and the outcome
/// once there is one.
struct ScenarioState {
    let id: String
    let startDay: Int
    let start: GameState
    var outcome: ScenarioOutcome?
    var score = 0
}

/// A finished scenario waiting for its result card on the front door.
struct ScenarioResult: Equatable, Identifiable {
    let scenarioID: String
    let outcome: ScenarioOutcome
    let score: Int
    let daysUsed: Int
    let cash: Int
    let featured: Bool

    var id: String { "\(scenarioID)-\(score)-\(daysUsed)" }
}

/// One row of the Scenarios room.
struct ScenarioEntry: Identifiable {
    let scenario: Scenario
    let ledger: ScenarioLedger.Entry?
    let isFeatured: Bool
    let hasRunUnderWay: Bool

    var id: String { scenario.id }
}

extension GameSession {
    var scenarioStores: ScenarioStores { ScenarioStores(saveDirectory: saveDirectory) }

    var scenarioLedger: ScenarioLedger {
        (try? scenarioStores.ledger.load(slot: 0))?.state ?? ScenarioLedger()
    }

    /// The room's rows: this week's featured one first, the rest in the
    /// catalog's order.
    func scenarioEntries(now: Date = Date()) -> [ScenarioEntry] {
        let ledger = scenarioLedger
        let featured = ScenarioCatalog.featured(now: now)
        let entries = ScenarioCatalog.all.map { scenario in
            ScenarioEntry(
                scenario: scenario,
                ledger: ledger.entry(for: scenario.id),
                isFeatured: scenario.id == featured.id,
                hasRunUnderWay: storedScenarioRun(scenario.id) != nil
            )
        }
        return entries.sorted { lhs, rhs in
            if lhs.isFeatured != rhs.isFeatured { return lhs.isFeatured }
            return false
        }
    }

    /// Starts `scenario` from its fixture with day one's changes, or
    /// resumes the run under way. Never a slot.
    func playScenario(_ scenario: Scenario) {
        let stores = scenarioStores
        let startStore = SaveStore<GameState>(
            directory: stores.base.appendingPathComponent(scenario.id, isDirectory: true)
                .appendingPathComponent("Start", isDirectory: true),
            currentFormatVersion: 1, slotCount: 1
        )

        let engine: GameEngine
        let start: GameState
        let startDay: Int
        if let stored = storedScenarioRun(scenario.id),
           case .scenario(_, let day) = stored.mode,
           let storedStart = (try? startStore.load(slot: 0))?.state {
            engine = GameEngine.resume(state: stored)
            start = storedStart
            startDay = day
        } else {
            guard var state = ReleaseFixture.state(named: scenario.fixture) else {
                assertionFailure("scenario \(scenario.id): fixture \(scenario.fixture) is missing")
                return
            }
            scenario.prepare(&state)
            state.gameOver = nil
            state.epilogue = nil
            state.speed = .paused
            state.mode = .scenario(id: scenario.id, startDay: state.day)
            start = state
            startDay = state.day
            engine = GameEngine.resume(state: state)
            try? startStore.save(state, appVersion: Self.scenarioAppVersion, slot: 0)
        }

        scenario_ = ScenarioState(id: scenario.id, startDay: startDay, start: start)
        scenarioResult = nil
        installGate(ScenarioGate { [weak self] state in
            self?.scenarioOutcome(for: state) != nil
        })
        startDetachedGame(engine) { [weak self] state in
            self?.persistScenario(state)
        }
        persistScenario(self.engine.state)
    }

    /// The outcome on `state` for the scenario under way, `nil` while open.
    func scenarioOutcome(for state: GameState) -> ScenarioOutcome? {
        guard let running = scenario_, case .scenario(let id, _) = state.mode, id == running.id,
              let scenario = ScenarioCatalog.scenario(id)
        else { return nil }
        return ScenarioProgress.outcome(of: scenario, state: state, start: running.start, startDay: running.startDay)
    }

    private func storedScenarioRun(_ id: String) -> GameState? {
        guard let state = (try? scenarioStores.run(for: id).load(slot: 0))?.state,
              case .scenario(let storedID, _) = state.mode, storedID == id
        else { return nil }
        return state
    }

    private func persistScenario(_ state: GameState) {
        guard case .scenario(let id, _) = state.mode else { return }
        try? scenarioStores.run(for: id).save(state, appVersion: Self.scenarioAppVersion, summary: SaveSummary(state: state))
        scenarioRunChanged(state)
    }

    /// Records the result the first time the scenario is decided, posts
    /// the featured board, and hands the run back to the front door.
    func scenarioRunChanged(_ state: GameState, now: Date = Date()) {
        guard var running = scenario_, running.outcome == nil,
              let scenario = ScenarioCatalog.scenario(running.id),
              let outcome = scenarioOutcome(for: state)
        else { return }
        let score = ScenarioProgress.score(outcome, scenario: scenario, state: state, startDay: running.startDay)
        running.outcome = outcome
        running.score = score
        scenario_ = running

        var ledger = scenarioLedger
        ledger.record(id: scenario.id, outcome: outcome, score: score, at: now)
        try? scenarioStores.ledger.save(ledger, appVersion: Self.scenarioAppVersion, slot: 0)

        let featured = ScenarioCatalog.featured(now: now).id == scenario.id
        if featured, case .won = outcome {
            GameCenterHub.client.submit(score: score, to: GameCenterID.scenario)
        }
        // The run is over either way: the next Play starts it fresh.
        try? scenarioStores.run(for: scenario.id).delete(slot: 0)

        scenarioResult = ScenarioResult(
            scenarioID: scenario.id, outcome: outcome, score: score,
            daysUsed: state.day - running.startDay, cash: state.company.cash, featured: featured
        )
        if state.gameOver == nil {
            returnToFrontDoor()
        }
    }

    private static var scenarioAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }
}
