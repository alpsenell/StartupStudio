import Foundation
import TycoonContent
import TycoonEngine
import TycoonSave

// MARK: Iteration 7 — the daily (R3)

/// What the title screen's *Today's company* entry offers right now.
enum DailyEntry: Equatable, Identifiable {
    /// Nothing started: the date, the origin, the difficulty, and *Play*.
    case play(DailyChallenge)
    /// An attempt is under way — started before midnight, finishable
    /// after — and the button says *Resume*, from day `day`.
    case resume(DailyChallenge, day: Int)
    /// Today is done. The result card stands in place of *Play*.
    case result(DailyChallenge, DailyLedger.Entry)

    var challenge: DailyChallenge {
        switch self {
        case .play(let challenge), .resume(let challenge, _), .result(let challenge, _): challenge
        }
    }

    /// Identity for `.sheet(item:)`: the day, and which of the three it
    /// is, so finishing a run re-presents the result rather than the card
    /// that started it.
    var id: String {
        switch self {
        case .play: "play-\(challenge.day)"
        case .resume: "resume-\(challenge.day)"
        case .result: "result-\(challenge.day)"
        }
    }
}

@MainActor
extension GameSession {
    /// The daily's own two stores, beside the slots and never in one.
    var dailyStores: DailyStores { DailyStores(saveDirectory: saveDirectory) }

    var dailyLedger: DailyLedger {
        (try? dailyStores.ledger.load())?.state ?? .empty
    }

    func dailyResult(forDay day: Int) -> DailyLedger.Entry? {
        dailyLedger.entry(forDay: day)
    }

    /// What the entry shows for `challenge`: a result if the day is
    /// recorded, a resume if an attempt is stored and unfinished,
    /// otherwise the challenge itself.
    func dailyEntry(for challenge: DailyChallenge) -> DailyEntry {
        if let entry = dailyResult(forDay: challenge.day) {
            return .result(challenge, entry)
        }
        if let stored = storedDailyRun(forDay: challenge.day) {
            return .resume(challenge, day: stored.day)
        }
        return .play(challenge)
    }

    /// The saved attempt for `day`, if one is stored and still running.
    private func storedDailyRun(forDay day: Int) -> GameState? {
        guard let stored = (try? dailyStores.run.load())?.state,
              stored.mode == .daily(day: day), stored.gameOver == nil,
              stored.day < DailyChallenge.horizonDays
        else { return nil }
        return stored
    }

    /// Plays today's company: resumes the stored attempt if there is one,
    /// otherwise founds the company the day's seed describes.
    ///
    /// It never touches a slot. The engine is installed detached, its
    /// autosave goes to the daily's own store, and the horizon gate is
    /// installed with it, so the clock stops itself at the end of the year
    /// exactly the way the unlock stops it at chapter 2.
    func playDaily(_ challenge: DailyChallenge) {
        guard dailyResult(forDay: challenge.day) == nil else { return }
        let engine = storedDailyRun(forDay: challenge.day)
            .map(GameEngine.resume(state:))
            ?? Self.makeDailyEngine(challenge)
        daily = DailyState(challenge: challenge)
        installGate(DailyHorizonGate())
        startDetachedGame(engine) { [weak self] state in
            self?.persistDaily(state)
        }
        // Saved at once, so the attempt survives a kill before the first
        // autosave — and a run already at its horizon when it was stored
        // is finished the moment it is back.
        persistDaily(self.engine.state)
    }

    /// The company the day's seed founds: same seed, same origin, same
    /// difficulty, same founder and same name on every phone.
    private static func makeDailyEngine(_ challenge: DailyChallenge) -> GameEngine {
        let index = Int(challenge.seed % 64)
        let names = (try? ContentCatalog.loadBundled())?.names
            ?? NamePools(firstNames: [], lastNames: [], clientCompanies: [])
        // `usesArchetypeSkills: false`, as every founder the player did not
        // build gets: the archetype spread would move the balance, and
        // nobody picked "hacker" here — it is only a name.
        let founder = FounderProfile(
            name: StudioNameGenerator.founderName(index: index, names: names),
            archetype: .hacker,
            appearanceSeed: challenge.seed,
            usesArchetypeSkills: false
        )
        return GameEngine.newGame(
            companyName: StudioNameGenerator.companyName(index: index),
            seed: challenge.seed,
            difficulty: challenge.difficulty,
            founder: founder,
            origin: challenge.origin,
            mode: .daily(day: challenge.day)
        )
    }

    /// The daily's autosave: its own file, then the check for whether the
    /// year is over.
    private func persistDaily(_ state: GameState) {
        do {
            try dailyStores.run.save(
                state, appVersion: Self.dailyAppVersion, summary: SaveSummary(state: state)
            )
        } catch {
            // A failed autosave must never crash the game — the attempt
            // carries on in memory.
            assertionFailure("daily autosave failed: \(error)")
        }
        dailyRunChanged(state)
    }

    /// Called after every autosave and every batch of events: if the run
    /// has stopped — an ending, or the horizon — it is scored once.
    func dailyRunChanged(_ state: GameState, now: Date = Date()) {
        guard var daily, daily.score == nil, case .daily(let day) = state.mode else { return }
        let horizonReached = state.day >= DailyChallenge.horizonDays
        guard state.gameOver != nil || horizonReached else { return }

        let score = state.founderNetWorth(balance: engine.balance)
        // The board is a UTC day long. An attempt started before midnight
        // can be finished after, and then there is nowhere to post it.
        let periodIsOpen = DailyChallenge.dayNumber(for: now) == day
        if periodIsOpen {
            GameCenterHub.client.submit(score: score, to: GameCenterID.daily)
        }
        daily.score = score
        daily.submitted = periodIsOpen
        self.daily = daily

        var ledger = dailyLedger
        ledger.record(DailyLedger.Entry(
            day: day,
            score: score,
            submitted: periodIsOpen,
            ending: state.gameOver?.kind.rawValue,
            gameDay: state.day,
            lines: DailyResultLines.lines(for: state, balance: engine.balance),
            finishedAt: now
        ))
        try? dailyStores.ledger.save(ledger, appVersion: Self.dailyAppVersion)

        // The year running out is not an ending, so nothing else would
        // ever tell the player it happened: the run hands itself back to
        // the front door, where the result card is waiting. An ending
        // shows the biography first and lands there when they leave.
        if horizonReached, state.gameOver == nil {
            returnToFrontDoor()
        }
    }

    private static var dailyAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }
}
