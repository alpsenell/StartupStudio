import Foundation

// MARK: Iteration 7 — Game Center (R3)

/// The four things the game asks of Game Center. `LiveGameCenter` (R3)
/// wraps GameKit; `NoopGameCenter` is what tests and a signed-out player
/// get, and it never crashes.
@MainActor
protocol GameCenterClient: AnyObject {
    var isAuthenticated: Bool { get }
    func authenticate()
    func report(achievement id: String)
    func submit(score: Int, to leaderboard: String)
}

/// Does nothing, remembers what it was asked, for tests.
@MainActor
final class NoopGameCenter: GameCenterClient {
    var isAuthenticated = false
    private(set) var reportedAchievements: [String] = []
    private(set) var submittedScores: [(score: Int, leaderboard: String)] = []

    init() {}

    func authenticate() {}

    func report(achievement id: String) {
        reportedAchievements.append(id)
    }

    func submit(score: Int, to leaderboard: String) {
        submittedScores.append((score, leaderboard))
    }
}

/// The identifiers the owner creates in App Store Connect, bundle-prefixed.
enum GameCenterID {
    static let prefix = "com.alpsenel.startupstudio"

    static func achievement(goalID: String) -> String { "\(prefix).goal.\(goalID)" }
    static func achievement(ending: String) -> String { "\(prefix).ending.\(ending)" }
    static func leaderboard(_ name: String) -> String { "\(prefix).lb.\(name)" }
}

// MARK: - The boards

extension GameCenterID {
    /// The days-to-IPO board for a difficulty (integer, ascending).
    static func ipoDays(_ difficulty: String) -> String { leaderboard("ipo_days.\(difficulty)") }

    /// The *Still yours* net-worth board for a difficulty (money, descending).
    static func stillYoursNetWorth(_ difficulty: String) -> String {
        leaderboard("still_yours_net_worth.\(difficulty)")
    }

    /// The longest anyone stayed, any ending, any mode (integer, descending).
    static let tenureDays = leaderboard("tenure_days")

    /// Today's company (recurring, daily, UTC, money, descending).
    static let daily = leaderboard("daily")
}
