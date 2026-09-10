import Foundation
import TycoonBots
import TycoonContent
import TycoonEngine

// MARK: J4 (house field)

/// The house field, on the session's side: when to play it, where it is
/// filed, and how the table and the result cards read it back.
///
/// The field is played the first time the front door opens in a new
/// league week or daily day (`refreshLeagueGhosts` and `refreshGhosts`
/// call in here after the cloud has had its turn), and again only if the
/// cache is missing a founder. Each result is an ordinary `GhostLog` under
/// the key the league or the daily already reads, marked with the founder
/// who played it, so every existing path — the table, the four rivals a
/// run is founded against, the ghost rank — sees it without being told.
@MainActor
extension GameSession {
    /// The cache the house writes to in one go.
    private var houseFieldStore: LocalGhostStore { LocalGhostStore(saveDirectory: saveDirectory) }

    // MARK: - The company the house founds

    /// The week's company, exactly as `makeLeagueEngine` founds it.
    static func houseFieldSetup(week: LeagueWeek) -> HouseFieldSetup {
        let index = Int(week.seed % 64)
        return HouseFieldSetup(
            seed: week.seed, origin: week.origin, difficulty: week.difficulty,
            mode: .league(week: week.week),
            companyName: StudioNameGenerator.companyName(index: index),
            founderName: StudioNameGenerator.founderName(index: index, names: houseFieldNamePools),
            founderAppearanceSeed: week.seed,
            horizonDays: LeagueWeek.horizonDays
        )
    }

    /// The day's company, exactly as `makeDailyEngine` founds it.
    static func houseFieldSetup(daily challenge: DailyChallenge) -> HouseFieldSetup {
        let index = Int(challenge.seed % 64)
        return HouseFieldSetup(
            seed: challenge.seed, origin: challenge.origin, difficulty: challenge.difficulty,
            mode: .daily(day: challenge.day),
            companyName: StudioNameGenerator.companyName(index: index),
            founderName: StudioNameGenerator.founderName(index: index, names: houseFieldNamePools),
            founderAppearanceSeed: challenge.seed,
            horizonDays: DailyChallenge.horizonDays
        )
    }

    private static let houseFieldNamePools: NamePools = (try? ContentCatalog.loadBundled())?.names
        ?? NamePools(firstNames: [], lastNames: [], clientCompanies: [])

    // MARK: - Playing it

    /// Plays `week`'s field for `tier`, unless this phone already has it.
    func ensureHouseField(week: LeagueWeek, tier: LeagueTier) async {
        await ensureHouseField(
            key: LeagueGhostKey.key(week: week.week, tier: tier),
            roster: HouseFieldRoster.founders(for: tier),
            setup: Self.houseFieldSetup(week: week)
        )
    }

    /// Plays the daily's field for `challenge`, unless this phone has it.
    func ensureHouseField(daily challenge: DailyChallenge) async {
        await ensureHouseField(
            key: challenge.day,
            roster: HouseFieldRoster.daily,
            setup: Self.houseFieldSetup(daily: challenge)
        )
    }

    private func ensureHouseField(key: Int, roster: [HouseFieldFounder], setup: HouseFieldSetup) async {
        guard !hasHouseField(key: key, roster: roster) else { return }
        let results = await HouseFieldRunner.shared.play(key: key, roster: roster, setup: setup)
        // Somebody else may have filed it while this one waited.
        guard !results.isEmpty, !hasHouseField(key: key, roster: roster) else { return }
        let now = Date()
        houseFieldStore.save(all: results.map {
            Self.houseFieldLog($0, key: key, companyName: setup.companyName, now: now)
        })
    }

    private func hasHouseField(key: Int, roster: [HouseFieldFounder]) -> Bool {
        let filed = Set(houseFieldLogs(key: key).compactMap(\.houseFounderID))
        return roster.allSatisfy { filed.contains($0.id) }
    }

    /// A house run as the ghost cache files any finished year.
    static func houseFieldLog(_ result: HouseFieldResult, key: Int, companyName: String, now: Date) -> GhostLog {
        let topics = Array(Set(result.launches.map(\.topicID))).sorted()
        var log = GhostLog(
            day: key,
            player: result.founder.name,
            companyName: companyName,
            appearanceSeed: result.founder.appearanceSeed,
            // A founder who never shipped still has a topic they were
            // going to build in, so a rival founded from them has a focus.
            focusTopicIDs: topics.isEmpty ? [BotHelp.topic(forProductNumber: result.founder.topicShift)] : topics,
            launches: result.launches,
            finalNetWorth: result.finalNetWorth,
            recordedAt: now
        )
        log.houseFounderID = result.founder.id
        return log
    }

    // MARK: - Reading it

    /// The house founders filed under `key`, best first — only those the
    /// current roster knows, so a week filed under an older roster is
    /// neither shown nor mistaken for this one.
    func houseFieldLogs(key: Int) -> [GhostLog] {
        ghostStore.logs(forDay: key).filter { log in
            log.houseFounderID.flatMap(HouseFieldRoster.founder(id:)) != nil
        }
    }

    /// House founders to stand beside `realPlayers` real ones, up to a
    /// full table, spread evenly down the house's own table so a thinner
    /// fill keeps the field's shape.
    func houseFieldFill(key: Int, besides realPlayers: Int) -> [LeagueStanding] {
        let wanted = max(0, HouseFieldRoster.fieldSize - realPlayers)
        return Self.houseFieldSpread(houseFieldLogs(key: key), count: wanted)
            .map { LeagueStanding(name: $0.player, score: $0.finalNetWorth) }
    }

    /// `count` items from `items`, evenly spaced, first and last kept.
    static func houseFieldSpread<T>(_ items: [T], count: Int) -> [T] {
        guard count < items.count else { return items }
        guard count > 1 else { return count == 1 ? [items[items.count / 2]] : [] }
        return (0..<count).map { step in
            items[Int((Double(step) * Double(items.count - 1) / Double(count - 1)).rounded())]
        }
    }

    /// "Grinder — contracts only, never hired", by the name on the row,
    /// for every house founder filed under `key`.
    func houseFieldLines(key: Int) -> [String: String] {
        let pairs = houseFieldLogs(key: key).compactMap { log -> (String, String)? in
            guard let founder = log.houseFounderID.flatMap(HouseFieldRoster.founder(id:)) else { return nil }
            return (log.player, founder.line)
        }
        return Dictionary(pairs, uniquingKeysWith: { first, _ in first })
    }

    /// Whether a real log is this phone's own year: filed under the Game
    /// Center name, or — signed out — the company's, which is the name
    /// `recordGhost` gives it. The player's row is folded in from the
    /// ledger, so their ghost must not stand beside it as somebody else.
    func houseFieldIsOwnGhost(_ log: GhostLog, companyName: String) -> Bool {
        guard log.houseFounderID == nil else { return false }
        return log.player == companyName || log.player == leagueDisplayName
            || log.player == GameCenterHub.displayName
    }

    /// The real players filed under `key` — not the house, not this phone.
    func houseFieldRealPlayers(key: Int, companyName: String) -> [LeagueStanding] {
        ghostStore.logs(forDay: key)
            .filter { $0.houseFounderID == nil && !houseFieldIsOwnGhost($0, companyName: companyName) }
            .prefix(HouseFieldRoster.fieldSize)
            .map { LeagueStanding(name: $0.player, score: $0.finalNetWorth) }
    }

    /// The daily result card's line: who finished directly above the
    /// player on the day's seed, and how they play. `nil` before the
    /// house has played the day, and for anything but a result.
    func houseFieldAbove(forDaily entry: DailyEntry) -> HouseFieldAbove? {
        guard case .result(let challenge, let result) = entry else { return nil }
        let key = challenge.day
        guard !houseFieldLogs(key: key).isEmpty else { return nil }
        let company = Self.houseFieldSetup(daily: challenge).companyName
        let real = houseFieldRealPlayers(key: key, companyName: company)
        let others = real + houseFieldFill(key: key, besides: real.count)
        let standings = LeagueTable.standings(you: leagueDisplayName, score: result.score, others: others)
        return HouseFieldAbove.make(standings: standings, lines: houseFieldLines(key: key))
    }

    // MARK: - Debug

    #if DEBUG
    /// `-autoHouseField week|day`: plays this week's field for the
    /// player's tier (or today's), then files a made-up finished year for
    /// the player between the house's ninth and tenth, so the table and
    /// the "directly above you" line can be photographed without playing
    /// a year. An attempt already recorded is left alone.
    func debugFileHouseFieldRun(_ mode: String, now: Date = Date()) async {
        let lines = [
            "Filed by -autoHouseField: a made-up year,",
            "placed in the middle of the house field.",
        ]
        if mode == "day" {
            let challenge = DailyChallenge.today(now: now)
            await ensureHouseField(daily: challenge)
            guard dailyResult(forDay: challenge.day) == nil else { return }
            let scores = houseFieldLogs(key: challenge.day).map(\.finalNetWorth)
            guard scores.count >= 10 else { return }
            var ledger = dailyLedger
            ledger.record(DailyLedger.Entry(
                day: challenge.day, score: (scores[8] + scores[9]) / 2, submitted: false,
                ending: nil, gameDay: DailyChallenge.horizonDays, lines: lines, finishedAt: now, grid: nil
            ))
            try? dailyStores.ledger.save(ledger, appVersion: Self.leagueAppVersion)
        } else {
            let week = LeagueWeek.current(now: now)
            let tier = leagueRecord.tier
            await ensureHouseField(week: week, tier: tier)
            guard leagueLedger.entry(forWeek: week.week) == nil else { return }
            let scores = houseFieldLogs(key: LeagueGhostKey.key(week: week.week, tier: tier)).map(\.finalNetWorth)
            guard scores.count >= 10 else { return }
            var ledgerFile = leagueLedger
            ledgerFile.record(LeagueLedger.Entry(
                week: week.week, tier: tier, score: (scores[8] + scores[9]) / 2, submitted: false,
                ending: nil, gameDay: LeagueWeek.horizonDays, lines: lines, grid: nil, finishedAt: now
            ))
            try? leagueStores.ledger.save(ledgerFile, appVersion: Self.leagueAppVersion)
        }
    }
    #endif
}

// MARK: end J4
