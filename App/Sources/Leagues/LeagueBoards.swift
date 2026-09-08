import Foundation
import GameKit
import TycoonEngine

// MARK: Iteration 10 — M4 (leagues)

extension GameCenterID {
    /// The tier's own recurring board.
    static func league(_ tier: LeagueTier) -> String { league(tier.rawValue) }
}

/// One row read back off a leaderboard: who, and what they scored.
///
/// A read-only seam beside `GameCenterClient`, which only ever writes.
/// The league needs to *read* a board to work out who came top, and
/// giving the write client a read method would make every other client
/// in the app (the queue, the no-op) answer a question it has no
/// business answering.
struct LeagueBoardEntry: Equatable, Sendable {
    var name: String
    var score: Int
    var isLocalPlayer: Bool

    init(name: String, score: Int, isLocalPlayer: Bool = false) {
        self.name = name
        self.score = score
        self.isLocalPlayer = isLocalPlayer
    }

    var standing: LeagueStanding {
        LeagueStanding(name: name, score: score, isYou: isLocalPlayer)
    }
}

/// Where a tier's week comes from.
@MainActor
protocol LeagueBoardSource {
    /// The top `limit` rows of `board` for the week ending `weeksAgo`
    /// weeks back (0 is the week running now), best first. Empty on any
    /// failure — signed out, offline, or a board the owner has not
    /// created yet.
    func entries(board: String, weeksAgo: Int, limit: Int) async -> [LeagueBoardEntry]
}

/// Answers nothing. What a signed-out player and every test get; the
/// league then reads the week's ghost field instead, so the table is
/// never empty for want of an account.
@MainActor
struct NoLeagueBoards: LeagueBoardSource {
    func entries(board: String, weeksAgo: Int, limit: Int) async -> [LeagueBoardEntry] { [] }
}

/// GameKit. The second file in the app that imports it (`LiveGameCenter`
/// is the other): reading a board is a different question from reporting
/// to one, and the league is the only thing that asks it.
///
/// A recurring board hands back its current occurrence; the week that
/// just closed is one `loadPreviousOccurrence()` behind it, and a week
/// further back is that again. Anything missing — signed out, offline, a
/// board the owner has not created — is an empty table, never an error
/// the player sees.
@MainActor
struct LiveLeagueBoards: LeagueBoardSource {
    func entries(board: String, weeksAgo: Int, limit: Int) async -> [LeagueBoardEntry] {
        guard GKLocalPlayer.local.isAuthenticated else { return [] }
        guard let boards = try? await GKLeaderboard.loadLeaderboards(IDs: [board]),
              var leaderboard = boards.first
        else { return [] }
        for _ in 0..<max(0, weeksAgo) {
            guard let previous = try? await leaderboard.loadPreviousOccurrence() else { return [] }
            leaderboard = previous
        }
        let range = NSRange(location: 1, length: max(1, min(limit, 100)))
        guard let result = try? await leaderboard.loadEntries(for: .global, timeScope: .allTime, range: range)
        else { return [] }
        let local = GKLocalPlayer.local.gamePlayerID
        return result.1.map { entry in
            LeagueBoardEntry(
                name: entry.player.displayName,
                score: entry.score,
                isLocalPlayer: entry.player.gamePlayerID == local
            )
        }
    }
}

/// The source the app uses: GameKit when the player is signed in, and
/// nothing when they are not.
@MainActor
enum LeagueBoards {
    static var source: any LeagueBoardSource {
        GameCenterHub.client.isAuthenticated ? LiveLeagueBoards() : NoLeagueBoards()
    }
}
