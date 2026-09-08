import Foundation
import TycoonEngine
import TycoonSave

// MARK: Iteration 10 — M4 (leagues): Beat my company

/// A challenge this phone accepted, and what came of it.
///
/// A challenge is not a mode: it is a *custom company on somebody else's
/// seed*, played in a slot like any other, which is the whole reason it
/// can be sent to a friend who then keeps the company. So the only thing
/// stored is the challenge itself, keyed by that seed; when a run on the
/// same seed stops, the front door reads both years off it and shows the
/// comparison once.
struct LeagueAcceptedChallenge: Codable, Equatable, Sendable {
    var seed: UInt64
    var grid: String
    var score: Int
    var challenger: String
    var acceptedAt: Date
    /// Set once the comparison has been shown, so it is shown once.
    var answeredAt: Date?
    /// What the player's own run finished on, once it has.
    var yourScore: Int?
    var yourGrid: String?
}

/// Every challenge this phone accepted, in the league's own store.
struct LeagueChallengeBook: Codable, Equatable, Sendable {
    var accepted: [LeagueAcceptedChallenge] = []

    static let empty = LeagueChallengeBook()

    func challenge(forSeed seed: UInt64) -> LeagueAcceptedChallenge? {
        accepted.first { $0.seed == seed }
    }

    mutating func record(_ entry: LeagueAcceptedChallenge) {
        accepted.removeAll { $0.seed == entry.seed }
        accepted.append(entry)
        if accepted.count > 50 {
            accepted.removeFirst(accepted.count - 50)
        }
    }
}

/// The comparison card's contents: two years, two numbers, one verdict.
struct LeagueChallengeResult: Equatable, Identifiable {
    var challenger: String
    var challengerScore: Int
    var challengerGrid: String
    var yourScore: Int
    var yourGrid: String
    var companyName: String

    var id: String { "\(challenger)-\(challengerScore)-\(yourScore)" }

    var youWon: Bool { yourScore > challengerScore }

    var headline: String {
        if youWon { return "You beat \(challenger)." }
        if yourScore == challengerScore { return "A dead heat with \(challenger)." }
        return "\(challenger) still has it."
    }
}

@MainActor
extension GameSession {
    private var challengeStore: SaveStore<LeagueChallengeBook> {
        SaveStore(
            directory: leagueStores.base.appendingPathComponent("Challenges", isDirectory: true),
            currentFormatVersion: 1, slotCount: 1
        )
    }

    var challengeBook: LeagueChallengeBook {
        (try? challengeStore.load())?.state ?? .empty
    }

    private func save(_ book: LeagueChallengeBook) {
        try? challengeStore.save(book, appVersion: Self.leagueAppVersion)
    }

    /// Accepts a challenge and opens the custom flow on its seed: from
    /// here it is an ordinary company, in an ordinary slot, and the only
    /// thing the league keeps is what it has to beat.
    @discardableResult
    func acceptChallenge(_ challenge: LeagueChallenge, now: Date = Date()) -> Bool {
        var book = challengeBook
        book.record(LeagueAcceptedChallenge(
            seed: challenge.code.seed, grid: challenge.grid, score: challenge.score,
            challenger: challenge.challenger, acceptedAt: now
        ))
        save(book)
        pendingChallenge = nil
        return beginCustomGame(code: challenge.code)
    }

    /// Forgets a challenge the player declined.
    func declineChallenge(_ challenge: LeagueChallenge) {
        pendingChallenge = nil
    }

    /// The comparison the front door owes the player, if a run on an
    /// accepted challenge's seed has stopped since they were last here.
    /// Marks it answered, so it is shown once.
    func challengeResult() -> LeagueChallengeResult? {
        var book = challengeBook
        let open = book.accepted.filter { $0.answeredAt == nil }
        guard !open.isEmpty else { return nil }
        for row in open {
            guard let slot = slots.first(where: { summary in
                guard let saved = summary.summary, saved.seed == row.seed else { return false }
                return saved.ending != nil || saved.day >= LeagueWeek.horizonDays
            }) else { continue }
            guard let state = (try? store.load(slot: slot.slot))?.state else { continue }
            let balance = GameEngine.resume(state: state).balance
            let yourScore = state.founderNetWorth(balance: balance)
            let yourGrid = YearGrid.letters(YearGrid.strip(YearGrid.squares(state: state)))
            var answered = row
            answered.answeredAt = Date()
            answered.yourScore = yourScore
            answered.yourGrid = yourGrid
            book.record(answered)
            save(book)
            return LeagueChallengeResult(
                challenger: row.challenger,
                challengerScore: row.score,
                challengerGrid: row.grid,
                yourScore: yourScore,
                yourGrid: yourGrid,
                companyName: state.company.name
            )
        }
        return nil
    }

    /// The challenge this phone can send from a finished run: the seed
    /// that founds the same company, the year it had, and the score.
    func challenge(from entry: LeagueLedger.Entry, week: LeagueWeek) -> LeagueChallenge {
        LeagueChallenge(
            code: week.seedCode,
            grid: YearGrid.letters(entry.grid ?? ""),
            score: entry.score,
            challenger: GameCenterHub.displayName ?? "A founder"
        )
    }
}
