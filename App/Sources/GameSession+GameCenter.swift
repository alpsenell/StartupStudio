import Foundation
import TycoonContent
import TycoonEngine

// MARK: Iteration 7 — Game Center (R3)

/// What a run's events are worth to Game Center.
///
/// A pure function of the events and the state they left behind, so the
/// whole table — six endings × three difficulties, ranked and unranked —
/// is testable without GameKit, an engine, or a signed-in player.
enum GameCenterMapping {
    /// The reports `events` earn, in the order they should be sent.
    ///
    /// - `.goalCompleted` → the goal's achievement, in every mode: a
    ///   custom company and the daily both earn them.
    /// - `.gameOver` → the ending's achievement, again in every mode,
    ///   plus the boards below.
    ///
    /// Boards:
    /// - `ipo_days.<difficulty>` and `still_yours_net_worth.<difficulty>`
    ///   are ranked: they need `state.isRanked` (standard or daily mode,
    ///   no heirloom — a custom company never posts).
    /// - `tenure_days` takes any ending in any mode, per the release doc,
    ///   because it measures a person staying rather than a company
    ///   winning. It needs at least one hire who is not the founder.
    /// - `lb.daily` is not here: the daily posts its own score when its
    ///   year stops, which is not always an ending (`GameSession+Daily`).
    static func reports(
        for events: [GameEvent], state: GameState, balance: BalanceConfig,
        content: ContentCatalog? = nil
    ) -> [GameCenterReport] {
        var reports: [GameCenterReport] = []
        for event in events {
            switch event {
            case .goalCompleted(let goalID, _):
                // The epilogue chapter has no achievements in the id
                // table (`GameCenterCatalog.goalAchievements`), so its
                // completions are not reported. Defaulted so every old
                // caller — the tests — reads exactly as it did.
                if let content, let goal = content.goal(goalID),
                   goal.chapter > ProgressionState.chapterCount {
                    continue
                }
                reports.append(.achievement(GameCenterID.achievement(goalID: goalID)))
            case .gameOver:
                guard let ending = state.gameOver else { continue }
                reports.append(.achievement(GameCenterID.achievement(ending: ending.kind.rawValue)))
                reports.append(contentsOf: boardReports(for: ending.kind, state: state, balance: balance))
            default:
                continue
            }
        }
        return reports
    }

    private static func boardReports(
        for kind: EndingKind, state: GameState, balance: BalanceConfig
    ) -> [GameCenterReport] {
        var reports: [GameCenterReport] = []
        let difficulty = state.difficulty.rawValue
        if state.isRanked {
            switch kind {
            case .ipo:
                reports.append(.score(state.day, leaderboard: GameCenterID.ipoDays(difficulty)))
            case .independent:
                reports.append(.score(
                    state.founderNetWorth(balance: balance),
                    leaderboard: GameCenterID.stillYoursNetWorth(difficulty)
                ))
            default:
                break
            }
            // Iteration 8: a successful ending at a stake posts the stake.
            if kind.isSuccess, state.rules.stake > 0 {
                reports.append(.score(state.rules.stake, leaderboard: GameCenterID.stakes))
            }

            // MARK: Iteration 9 — L2 (life score)

            // The founder's own board takes *every* ranked ending, not
            // just the good ones: a bankruptcy with a marriage and two
            // kids intact is exactly the run this board exists to rank.
            reports.append(.score(
                LifeScore.score(state, balance: balance),
                leaderboard: GameCenterID.lifeScore(difficulty)
            ))

            // MARK: end of Iteration 9
        }
        if let tenure = longestTenure(in: state) {
            reports.append(.score(tenure, leaderboard: GameCenterID.tenureDays))
        }
        return reports
    }

    /// Days the longest-serving hire has been there, founder excluded.
    /// `nil` when nobody was ever hired — a founder alone has no tenure to
    /// post, and a zero on the board would read as one.
    static func longestTenure(in state: GameState) -> Int? {
        guard let earliest = state.employees.filter({ !$0.isFounder }).map(\.hiredDay).min()
        else { return nil }
        return max(0, state.day - earliest)
    }
}

@MainActor
extension GameSession {
    /// Starts Game Center for this launch and begins mapping events onto
    /// it. Idempotent — the title screen calls it every time it appears.
    func startGameCenter() {
        GameCenterHub.start()
        observeGameCenterEvents()
    }

    /// Registers the event observer only. Tests call this after putting a
    /// `NoopGameCenter` in the hub.
    func observeGameCenterEvents() {
        observeEvents("gameCenter") { [weak self] events in
            guard let self else { return }
            self.sendToGameCenter(events)
            // The daily's own horizon and ending land here too: an ending
            // before day 364 stops the run and scores it.
            self.dailyRunChanged(self.engine.state)
        }
    }

    /// Reports what `events` earned, through whatever client the hub has.
    func sendToGameCenter(_ events: [GameEvent]) {
        let client = GameCenterHub.client
        for report in GameCenterMapping.reports(
            for: events, state: engine.state, balance: engine.balance, content: engine.content
        ) {
            if let achievement = report.achievement {
                client.report(achievement: achievement)
            } else if let leaderboard = report.leaderboard, let score = report.score {
                client.submit(score: score, to: leaderboard)
            }
        }
    }
}
