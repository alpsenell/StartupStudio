import Foundation
import TycoonContent
import TycoonEngine
import TycoonSave

// MARK: Iteration 10 — M4 (leagues)

/// What the title screen's *League* row offers right now.
enum LeagueEntry: Equatable, Identifiable {
    /// Nothing started: the week, the tier, the table so far, and *Play*.
    case play(LeagueWeek)
    /// An attempt is under way, and the button says *Resume*.
    case resume(LeagueWeek, day: Int)
    /// This week is done. The result stands in place of *Play*.
    case result(LeagueWeek, LeagueLedger.Entry)

    var week: LeagueWeek {
        switch self {
        case .play(let week), .resume(let week, _), .result(let week, _): week
        }
    }

    var id: String {
        switch self {
        case .play: "play-\(week.week)"
        case .resume: "resume-\(week.week)"
        case .result: "result-\(week.week)"
        }
    }
}

/// The league week under way, and its result once there is one.
struct LeagueState: Equatable {
    let week: LeagueWeek
    let tier: LeagueTier
    var score: Int?
    var submitted = false
}

/// Everything the League screen draws, gathered once so the view is a
/// function of plain values.
struct LeagueView: Equatable, Identifiable {
    var week: LeagueWeek
    var record: LeagueRecord
    var entry: LeagueEntry
    /// The tier's table this week, best first, with the player's own row
    /// folded in when they have finished.
    var standings: [LeagueStanding] = []
    /// Where the standings came from, for the one line under the table.
    var source: Source = .none
    /// Set the first time the player opens the screen after a week
    /// settled: what last week did to their tier.
    var settlement: Settlement?
    // MARK: J4 (house field)
    /// How each house founder in the table plays, by the name on the row.
    var houseLines: [String: String] = [:]
    // MARK: end J4

    var id: String { "\(week.week)-\(entry.id)" }

    enum Source: Equatable {
        /// The tier's recurring Game Center board.
        case board
        /// The week's ghosts — everyone in the tier this phone has seen.
        case ghosts
        /// Nobody else yet.
        case none
        // MARK: J4 (house field)
        /// Nobody real yet: the house's nineteen, on the same seed.
        case house
        /// The tier's board, filled to twenty with house founders.
        case boardAndHouse
        /// The players this phone has seen, filled with house founders.
        case ghostsAndHouse
        // MARK: end J4

        var line: String {
            switch self {
            case .board: "From your tier's board on Game Center."
            case .ghosts: "The players in your tier this phone has seen."
            case .none: "Nobody in your tier has finished this week yet."
            // MARK: J4 (house field)
            case .house: "Nineteen house founders played this seed, each one way. Beat four of them to go up."
            case .boardAndHouse: "From your tier's board on Game Center, filled to twenty with house founders."
            case .ghostsAndHouse: "The players this phone has seen, and house founders to make twenty."
            // MARK: end J4
            }
        }
    }

    struct Settlement: Equatable {
        var week: Int
        var rank: Int
        var fieldSize: Int
        var outcome: LeagueOutcome
        var from: LeagueTier
        var to: LeagueTier

        var line: String {
            switch outcome {
            case .promoted where from != to:
                "\(LeagueTable.placeText(rank: rank, fieldSize: fieldSize)) in \(from.displayName). Up to \(to.displayName)."
            case .promoted:
                "\(LeagueTable.placeText(rank: rank, fieldSize: fieldSize)) in \(from.displayName). There is nothing above it."
            case .relegated where from != to:
                "\(LeagueTable.placeText(rank: rank, fieldSize: fieldSize)) in \(from.displayName). Down to \(to.displayName)."
            case .relegated:
                "\(LeagueTable.placeText(rank: rank, fieldSize: fieldSize)) in \(from.displayName). You cannot fall further."
            case .held:
                "\(LeagueTable.placeText(rank: rank, fieldSize: fieldSize)) in \(from.displayName). You stay where you are."
            case .unplaced:
                "You missed last week, so nothing moved."
            }
        }
    }
}

@MainActor
extension GameSession {
    var leagueStores: LeagueStores { LeagueStores(saveDirectory: saveDirectory) }

    var leagueLedger: LeagueLedger {
        (try? leagueStores.ledger.load())?.state ?? .empty
    }

    /// The rung the player is on. A ledger from before iteration 10 — or
    /// one that has never played a week — reads as a new bronze player.
    var leagueRecord: LeagueRecord {
        ledger.league ?? .starting
    }

    func leagueEntry(for week: LeagueWeek) -> LeagueEntry {
        if let entry = leagueLedger.entry(forWeek: week.week) {
            return .result(week, entry)
        }
        if let stored = storedLeagueRun(week.week) {
            return .resume(week, day: stored.day)
        }
        return .play(week)
    }

    private func storedLeagueRun(_ week: Int) -> GameState? {
        guard let stored = (try? leagueStores.run(for: week).load())?.state,
              stored.mode == .league(week: week), stored.gameOver == nil,
              stored.day < LeagueWeek.horizonDays
        else { return nil }
        return stored
    }

    // MARK: - The screen

    /// Everything the League screen shows, with the table filled in from
    /// whatever this phone can see. Settles last week first, so opening
    /// the screen on a Monday is where promotion happens.
    func leagueView(for week: LeagueWeek, now: Date = Date()) async -> LeagueView {
        let settlement = await settleLeague(before: week, now: now)
        let record = leagueRecord
        var view = LeagueView(
            week: week, record: record, entry: leagueEntry(for: week), settlement: settlement
        )
        let (standings, source) = await leagueStandings(
            week: week, tier: record.tier, now: now
        )
        view.standings = standings
        view.source = source
        // MARK: J4 (house field)
        view.houseLines = houseFieldLines(key: LeagueGhostKey.key(week: week.week, tier: record.tier))
        // MARK: end J4
        return view
    }

    /// The tier's table for `week`: the recurring board when Game Center
    /// answers, the week's ghosts when it does not, and the player's own
    /// score folded in once they have one.
    func leagueStandings(
        week: LeagueWeek, tier: LeagueTier, now: Date = Date()
    ) async -> ([LeagueStanding], LeagueView.Source) {
        // MARK: J4 (house field)
        // The house plays the tier's week first, if this phone lacks it —
        // which is also what settles a week nobody else turned up for.
        await ensureHouseField(week: week, tier: tier)
        let key = LeagueGhostKey.key(week: week.week, tier: tier)
        // MARK: end J4
        let mine = leagueLedger.entry(forWeek: week.week)?.score
        let name = leagueDisplayName
        let weeksAgo = max(0, LeagueWeek.weekNumber(for: now) - week.week)
        let board = await LeagueBoards.source.entries(
            board: GameCenterID.league(tier), weeksAgo: weeksAgo, limit: LeagueRules.fieldSize
        )
        if !board.isEmpty {
            let others = board.filter { !$0.isLocalPlayer }.map(\.standing)
            let own = mine ?? board.first(where: \.isLocalPlayer)?.score
            // MARK: J4 (house field)
            // Real players first; house founders fill the table to twenty.
            let house = houseFieldFill(key: key, besides: others.count)
            return (
                LeagueTable.standings(you: name, score: own, others: others + house),
                house.isEmpty ? .board : .boardAndHouse
            )
            // MARK: end J4
        }
        // MARK: J4 (house field)
        // The players this phone has seen — never its own year, which the
        // ledger folds in as "you" — then the house to make twenty.
        let real = houseFieldRealPlayers(
            key: key, companyName: Self.houseFieldSetup(week: week).companyName
        )
        let house = houseFieldFill(key: key, besides: real.count)
        let standings = LeagueTable.standings(you: name, score: mine, others: real + house)
        let source: LeagueView.Source = switch (real.isEmpty, house.isEmpty) {
        case (true, true): .none
        case (false, true): .ghosts
        case (true, false): .house
        case (false, false): .ghostsAndHouse
        }
        return (standings, source)
        // MARK: end J4
    }

    /// The name the player's own row carries.
    var leagueDisplayName: String {
        GameCenterHub.displayName ?? "You"
    }

    // MARK: - Settling a week

    /// Reads the table of the last week the player finished, once, and
    /// moves their tier. Returns what happened the first time it settles
    /// a week, and `nil` on every call after that.
    ///
    /// This is the whole promotion machine: no server, no push, no
    /// schedule. The week rolls, the player opens the screen, and the
    /// tier's board (or the ghost field) says where they came.
    @discardableResult
    func settleLeague(before week: LeagueWeek, now: Date = Date()) async -> LeagueView.Settlement? {
        var ledgerFile = leagueLedger
        guard let last = ledgerFile.lastEntry(before: week.week) else { return nil }
        let record = leagueRecord
        guard record.settledWeek != last.week else { return nil }

        let played = LeagueWeek.forWeek(last.week)
        let (standings, source) = await leagueStandings(week: played, tier: last.tier, now: now)
        guard let rank = LeagueTable.rank(inStandings: standings), source != .none else {
            // Nothing to place against: the week is marked settled all
            // the same, so it is never asked again, and the tier holds.
            var held = record
            held.settledWeek = last.week
            held.lastOutcome = .unplaced
            held.lastRank = 0
            held.lastFieldSize = 0
            ledger.league = held
            saveLedger()
            return LeagueView.Settlement(
                week: last.week, rank: 0, fieldSize: 0, outcome: .unplaced,
                from: record.tier, to: record.tier
            )
        }

        let fieldSize = max(standings.count, rank)
        let settled = record.settling(week: last.week, rank: rank, fieldSize: fieldSize)
        ledger.league = settled
        saveLedger()

        var entry = last
        entry.rank = rank
        entry.fieldSize = fieldSize
        entry.outcome = settled.lastOutcome
        ledgerFile.record(entry)
        try? leagueStores.ledger.save(ledgerFile, appVersion: Self.leagueAppVersion)

        return LeagueView.Settlement(
            week: last.week, rank: rank, fieldSize: fieldSize, outcome: settled.lastOutcome,
            from: record.tier, to: settled.tier
        )
    }

    // MARK: - Playing

    /// Plays this week's league company: resumes the stored attempt or
    /// founds the week's company. Never a slot; one attempt a week.
    func playLeague(_ week: LeagueWeek) {
        guard leagueLedger.entry(forWeek: week.week) == nil else { return }
        let tier = leagueRecord.tier
        let engine = storedLeagueRun(week.week).map(GameEngine.resume(state:))
            ?? Self.makeLeagueEngine(week, ghosts: leagueGhostScripts(week: week.week, tier: tier))
        league = LeagueState(week: week, tier: tier)
        installGate(LeagueGate())
        startDetachedGame(engine) { [weak self] state in
            self?.persistLeague(state)
        }
        // An ending before day 364 stops the run on the tick that raises
        // it, and the autosave that follows is not guaranteed to be the
        // one that carries it — the daily learned this and hangs the same
        // check off the event fan-out. One observer, on the league's own
        // key, so nothing else is disturbed.
        observeEvents("league") { [weak self] _ in
            guard let self else { return }
            self.leagueRunChanged(self.engine.state)
        }
        persistLeague(self.engine.state)
    }

    /// The company the week's seed founds: same seed, same origin, same
    /// difficulty, same founder and same name for everybody in the tier.
    private static func makeLeagueEngine(_ week: LeagueWeek, ghosts: [GhostScript] = []) -> GameEngine {
        let index = Int(week.seed % 64)
        let names = (try? ContentCatalog.loadBundled())?.names
            ?? NamePools(firstNames: [], lastNames: [], clientCompanies: [])
        let founder = FounderProfile(
            name: StudioNameGenerator.founderName(index: index, names: names),
            archetype: .hacker,
            appearanceSeed: week.seed,
            usesArchetypeSkills: false
        )
        return GameEngine.newGame(
            companyName: StudioNameGenerator.companyName(index: index),
            seed: week.seed,
            difficulty: week.difficulty,
            founder: founder,
            origin: week.origin,
            mode: .league(week: week.week),
            ghosts: ghosts
        )
    }

    private func persistLeague(_ state: GameState) {
        guard case .league(let week) = state.mode else { return }
        try? leagueStores.run(for: week).save(
            state, appVersion: Self.leagueAppVersion, summary: SaveSummary(state: state)
        )
        leagueRunChanged(state)
    }

    /// Scores the week when its year is up or the company ended; posts to
    /// the tier's board while the week is still open, and leaves a ghost
    /// for the rest of the tier.
    func leagueRunChanged(_ state: GameState, now: Date = Date()) {
        guard var running = league, running.score == nil, case .league(let week) = state.mode,
              week == running.week.week
        else { return }
        let horizonReached = state.day >= LeagueWeek.horizonDays
        guard state.gameOver != nil || horizonReached else { return }

        let score = state.founderNetWorth(balance: engine.balance)
        let periodIsOpen = LeagueWeek.weekNumber(for: now) == week
        if periodIsOpen {
            GameCenterHub.client.submit(score: score, to: GameCenterID.league(running.tier))
        }
        running.score = score
        running.submitted = periodIsOpen
        league = running

        var lines = DailyResultLines.lines(for: state, balance: engine.balance)
        if let rank = Self.ghostRank(score: score, ghosts: state.ghosts) {
            lines.append("Finished \(rank) against \(state.ghosts.map(\.name).joined(separator: ", ")).")
        }
        recordLeagueGhost(from: state, week: week, tier: running.tier, score: score, now: now)

        var ledgerFile = leagueLedger
        ledgerFile.record(LeagueLedger.Entry(
            week: week, tier: running.tier, score: score, submitted: periodIsOpen,
            ending: state.gameOver?.kind.rawValue, gameDay: state.day, lines: lines,
            grid: YearGrid.strip(YearGrid.squares(state: state)), finishedAt: now
        ))
        try? leagueStores.ledger.save(ledgerFile, appVersion: Self.leagueAppVersion)

        ledger.league = leagueRecord.played()
        saveLedger()

        stopObservingEvents("league")

        if horizonReached, state.gameOver == nil {
            returnToFrontDoor()
        }
    }

    // MARK: - The tier's ghosts

    /// The logs of everyone in `tier` this phone has seen for `week`.
    func leagueGhosts(week: Int, tier: LeagueTier) -> [GhostLog] {
        ghostStore.logs(forDay: LeagueGhostKey.key(week: week, tier: tier))
    }

    /// The rivals a league run is founded against: your tier this week,
    /// and last week's tier when this week has nobody in it yet.
    func leagueGhostScripts(week: Int, tier: LeagueTier) -> [GhostScript] {
        var logs = leagueGhosts(week: week, tier: tier)
        if logs.isEmpty {
            logs = leagueGhosts(week: week - 1, tier: tier)
        }
        return Array(logs.prefix(Self.ghostFieldSize)).map(\.script)
    }

    /// Records a finished league week as a ghost for the rest of the tier.
    func recordLeagueGhost(
        from state: GameState, week: Int, tier: LeagueTier, score: Int, now: Date = Date()
    ) {
        recordGhost(from: state, day: LeagueGhostKey.key(week: week, tier: tier), score: score, now: now)
    }

    /// Pulls this week's tier from the cloud into the cache, when the
    /// cloud exists. Called from the front door beside the daily's.
    func refreshLeagueGhosts(week: Int, tier: LeagueTier) async {
        await CloudGhostStore.refresh(day: LeagueGhostKey.key(week: week, tier: tier), into: ghostStore)
        // MARK: J4 (house field)
        // The first front-door open of a new week plays the tier's field.
        await ensureHouseField(week: LeagueWeek.forWeek(week), tier: tier)
        // MARK: end J4
    }

    static var leagueAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }
}
