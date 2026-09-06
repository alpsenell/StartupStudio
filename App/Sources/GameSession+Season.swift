import Foundation
import TycoonContent
import TycoonEngine
import TycoonSave

// MARK: Iteration 8 — seasons

/// What the title screen's *This season* entry offers right now.
enum SeasonEntry: Equatable, Identifiable {
    case play(GameSeason)
    case resume(GameSeason, day: Int)
    case result(GameSeason, SeasonLedger.Entry)

    var season: GameSeason {
        switch self {
        case .play(let season), .resume(let season, _), .result(let season, _): season
        }
    }

    var id: String {
        switch self {
        case .play: "play-\(season.number)"
        case .resume: "resume-\(season.number)"
        case .result: "result-\(season.number)"
        }
    }
}

/// The season under way, and its result once there is one.
struct SeasonState: Equatable {
    let season: GameSeason
    var score: Int?
    var submitted = false
}

@MainActor
extension GameSession {
    var seasonStores: SeasonStores { SeasonStores(saveDirectory: saveDirectory) }

    var seasonLedger: SeasonLedger {
        (try? seasonStores.ledger.load())?.state ?? SeasonLedger()
    }

    func seasonEntry(for season: GameSeason) -> SeasonEntry {
        if let entry = seasonLedger.entry(for: season.number) {
            return .result(season, entry)
        }
        if let stored = storedSeasonRun(season.number) {
            return .resume(season, day: stored.day)
        }
        return .play(season)
    }

    private func storedSeasonRun(_ number: Int) -> GameState? {
        guard let stored = (try? seasonStores.run(for: number).load())?.state,
              stored.mode == .season(number: number), stored.gameOver == nil,
              stored.day < GameSeason.horizonDays
        else { return nil }
        return stored
    }

    /// Plays the season: resumes the stored attempt or founds the
    /// season's company. Never a slot; one attempt per season.
    func playSeason(_ season: GameSeason) {
        guard seasonLedger.entry(for: season.number) == nil else { return }
        let engine = storedSeasonRun(season.number)
            .map(GameEngine.resume(state:))
            ?? Self.makeSeasonEngine(season)
        season_ = SeasonState(season: season)
        installGate(SeasonGate())
        startDetachedGame(engine) { [weak self] state in
            self?.persistSeason(state)
        }
        persistSeason(self.engine.state)
    }

    private static func makeSeasonEngine(_ season: GameSeason) -> GameEngine {
        let index = Int(season.seed % 64)
        let names = (try? ContentCatalog.loadBundled())?.names
            ?? NamePools(firstNames: [], lastNames: [], clientCompanies: [])
        let founder = FounderProfile(
            name: StudioNameGenerator.founderName(index: index, names: names),
            archetype: .hacker,
            appearanceSeed: season.seed,
            usesArchetypeSkills: false
        )
        return GameEngine.newGame(
            companyName: StudioNameGenerator.companyName(index: index),
            seed: season.seed,
            difficulty: season.difficulty,
            founder: founder,
            origin: season.origin,
            rules: season.rules,
            mode: .season(number: season.number)
        )
    }

    private func persistSeason(_ state: GameState) {
        guard case .season(let number) = state.mode else { return }
        try? seasonStores.run(for: number).save(state, appVersion: Self.seasonAppVersion, summary: SaveSummary(state: state))
        seasonRunChanged(state)
    }

    /// Scores the season when its year is up or the company ended; posts
    /// the board while the season is still open.
    func seasonRunChanged(_ state: GameState, now: Date = Date()) {
        guard var running = season_, running.score == nil, case .season(let number) = state.mode,
              number == running.season.number
        else { return }
        let horizonReached = state.day >= GameSeason.horizonDays
        guard state.gameOver != nil || horizonReached else { return }

        let score = state.founderNetWorth(balance: engine.balance)
        let periodIsOpen = GameSeason.current(now: now).number == number
        if periodIsOpen {
            GameCenterHub.client.submit(score: score, to: GameCenterID.season)
        }
        running.score = score
        running.submitted = periodIsOpen
        season_ = running

        var ledger = seasonLedger
        ledger.record(SeasonLedger.Entry(
            number: number, score: score, submitted: periodIsOpen,
            ending: state.gameOver?.kind.rawValue, gameDay: state.day,
            grid: YearGrid.strip(YearGrid.squares(state: state)), finishedAt: now
        ))
        try? seasonStores.ledger.save(ledger, appVersion: Self.seasonAppVersion)

        if horizonReached, state.gameOver == nil {
            returnToFrontDoor()
        }
    }

    private static var seasonAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }
}
