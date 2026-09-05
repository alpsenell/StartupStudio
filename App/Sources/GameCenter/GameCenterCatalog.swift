import Foundation
import TycoonContent
import TycoonEngine

// MARK: Iteration 7 — Game Center (R3)

/// Every identifier the game will ever ask Game Center for, in one place.
///
/// The owner creates these in App Store Connect; `docs/release/game-center-ids.md`
/// is this table written out for pasting, and `GameCenterCatalogTests`
/// pins the strings so the doc and the app can never drift apart.
///
/// 48 achievements (42 goals at 10 points + 6 endings at 50 = 720 of the
/// 1,000 a game may award) and 8 leaderboards.
enum GameCenterCatalog {
    struct Achievement: Equatable {
        let id: String
        let title: String
        /// What the player reads under the title in the Game Center list.
        let detail: String
        let points: Int
    }

    struct Leaderboard: Equatable {
        enum Sort: String { case ascending, descending }
        enum Format: String { case integer, money }

        let id: String
        let title: String
        let sort: Sort
        let format: Format
        /// A daily board resets at midnight UTC; the rest are all-time.
        let isRecurring: Bool
    }

    /// The six endings, in the order the id table lists them. `EndingKind`
    /// is not `CaseIterable` (it lives in the engine, which R3 does not
    /// edit), so the list is spelled out and pinned by a test.
    static let endings: [EndingKind] = [
        .bankruptcy, .acquired, .ipo, .oustedByBoard, .soldUp, .independent,
    ]

    /// 10 points a goal: 42 goals from `Goals.json`, in file order.
    static func goalAchievements(content: ContentCatalog) -> [Achievement] {
        content.goals.map { goal in
            Achievement(
                id: GameCenterID.achievement(goalID: goal.id),
                title: goal.title,
                detail: goal.detail ?? goal.title,
                points: 10
            )
        }
    }

    /// 50 points an ending, one for each way a company can finish.
    static let endingAchievements: [Achievement] = endings.map { kind in
        Achievement(
            id: GameCenterID.achievement(ending: kind.rawValue),
            title: kind.headline,
            detail: detail(for: kind),
            points: 50
        )
    }

    static func achievements(content: ContentCatalog) -> [Achievement] {
        goalAchievements(content: content) + endingAchievements
    }

    /// Two per difficulty, plus the two that take every run.
    static let leaderboards: [Leaderboard] = {
        var boards: [Leaderboard] = []
        for difficulty in Difficulty.allCases {
            boards.append(Leaderboard(
                id: GameCenterID.ipoDays(difficulty.rawValue),
                title: "Days to IPO — \(difficulty.displayName)",
                sort: .ascending, format: .integer, isRecurring: false
            ))
        }
        for difficulty in Difficulty.allCases {
            boards.append(Leaderboard(
                id: GameCenterID.stillYoursNetWorth(difficulty.rawValue),
                title: "Still yours — \(difficulty.displayName)",
                sort: .descending, format: .money, isRecurring: false
            ))
        }
        boards.append(Leaderboard(
            id: GameCenterID.tenureDays,
            title: "Longest anyone stayed",
            sort: .descending, format: .integer, isRecurring: false
        ))
        boards.append(Leaderboard(
            id: GameCenterID.daily,
            title: "Today's company",
            sort: .descending, format: .money, isRecurring: true
        ))
        return boards
    }()

    private static func detail(for kind: EndingKind) -> String {
        switch kind {
        case .bankruptcy: "Run a company all the way into the ground."
        case .acquired: "Sell the company to somebody who wanted it."
        case .ipo: "Take the company public and ring the bell."
        case .oustedByBoard: "Be replaced by the board you invited in."
        case .soldUp: "Sell the name and the desks to get out."
        case .independent: "Keep every share and build something that lasts."
        }
    }
}
