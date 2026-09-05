import Foundation

// MARK: Iteration 7 — Game Center (R3)

/// What the game asked Game Center for while nobody was signed in.
///
/// A player can finish a company on a plane. The report is kept in
/// `UserDefaults` — small, synchronous, survives a kill — and replayed the
/// next time authentication lands, so an offline IPO still reaches the
/// board it belongs on. Capped at 100: past that the oldest goes, because
/// a queue that grows without a bound is a bug, not a feature.
struct GameCenterReport: Codable, Equatable, Sendable {
    /// An achievement id, or `nil` for a score.
    var achievement: String?
    /// A leaderboard id, with `score`.
    var leaderboard: String?
    var score: Int?

    static func achievement(_ id: String) -> GameCenterReport {
        GameCenterReport(achievement: id)
    }

    static func score(_ score: Int, leaderboard: String) -> GameCenterReport {
        GameCenterReport(leaderboard: leaderboard, score: score)
    }
}

/// The `UserDefaults`-backed queue behind `QueueingGameCenter`. A plain
/// value store with a cap, so it can be tested without GameKit and
/// without touching the player's own defaults.
struct GameCenterReportQueue {
    /// The doc's cap.
    static let capacity = 100
    static let defaultsKey = "gc.queue"

    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = GameCenterReportQueue.defaultsKey) {
        self.defaults = defaults
        self.key = key
    }

    var reports: [GameCenterReport] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([GameCenterReport].self, from: data)
        else { return [] }
        return decoded
    }

    var count: Int { reports.count }

    /// Appends, dropping the oldest once the cap is reached.
    func append(_ report: GameCenterReport) {
        var queued = reports
        queued.append(report)
        if queued.count > Self.capacity {
            queued.removeFirst(queued.count - Self.capacity)
        }
        write(queued)
    }

    /// Hands back everything queued and empties the store, so a failed
    /// flush cannot replay twice.
    func drain() -> [GameCenterReport] {
        let queued = reports
        if !queued.isEmpty { defaults.removeObject(forKey: key) }
        return queued
    }

    func removeAll() {
        defaults.removeObject(forKey: key)
    }

    private func write(_ reports: [GameCenterReport]) {
        guard let data = try? JSONEncoder().encode(reports) else { return }
        defaults.set(data, forKey: key)
    }
}

/// The client the game actually talks to: everything reported while
/// unauthenticated goes into the queue, and `flushQueue()` replays it the
/// moment authentication lands.
///
/// It wraps a base client rather than being one, so the queue can be
/// tested against `NoopGameCenter` on a simulator that has no Game Center
/// account to sign into.
@MainActor
final class QueueingGameCenter: GameCenterClient {
    private let base: any GameCenterClient
    let queue: GameCenterReportQueue

    init(base: any GameCenterClient, queue: GameCenterReportQueue = GameCenterReportQueue()) {
        self.base = base
        self.queue = queue
    }

    var isAuthenticated: Bool { base.isAuthenticated }

    func authenticate() {
        base.authenticate()
    }

    func report(achievement id: String) {
        guard base.isAuthenticated else {
            queue.append(.achievement(id))
            return
        }
        base.report(achievement: id)
    }

    func submit(score: Int, to leaderboard: String) {
        guard base.isAuthenticated else {
            queue.append(.score(score, leaderboard: leaderboard))
            return
        }
        base.submit(score: score, to: leaderboard)
    }

    /// Replays everything queued. A no-op while still signed out, so a
    /// failed sign-in never empties the queue into nowhere.
    func flushQueue() {
        guard base.isAuthenticated else { return }
        for report in queue.drain() {
            if let achievement = report.achievement {
                base.report(achievement: achievement)
            } else if let leaderboard = report.leaderboard, let score = report.score {
                base.submit(score: score, to: leaderboard)
            }
        }
    }
}
