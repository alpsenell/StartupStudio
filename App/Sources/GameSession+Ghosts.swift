import Foundation
import TycoonEngine

// MARK: Iteration 8 — rival ghosts

extension GameSession {
    /// The store the daily reads its field from and writes its ghost to.
    var ghostStore: any GhostStore { LocalGhostStore(saveDirectory: saveDirectory) }

    /// Pulls yesterday's ghosts from the cloud into the cache, when the
    /// cloud exists. Called from the front door, ahead of Play.
    func refreshGhosts(forDailyDay day: Int) async {
        await CloudGhostStore.refresh(day: day - 1, into: ghostStore)
        // MARK: J4 (house field)
        // Real players first; then the house plays yesterday's seed (the
        // four rivals today's company is founded against) and today's
        // (the result card's field), each only if this phone lacks it.
        await ensureHouseField(daily: DailyChallenge.forDay(day - 1))
        await ensureHouseField(daily: DailyChallenge.forDay(day))
        // MARK: end J4
    }

    /// How many ghosts stand in for rivals: the whole field.
    static let ghostFieldSize = 4

    /// The scripts today's company is founded against: yesterday's best.
    /// Empty on the first day anyone plays, and the field rolls as it
    /// always did.
    func ghostScripts(forDailyDay day: Int) -> [GhostScript] {
        Array(ghostStore.logs(forDay: day - 1).prefix(Self.ghostFieldSize)).map(\.script)
    }

    /// The name a ghost of this player carries: the Game Center display
    /// name when there is one, the company's otherwise.
    func ghostName(for state: GameState) -> String {
        GameCenterHub.client.isAuthenticated ? GameCenterHub.displayName ?? state.company.name : state.company.name
    }

    /// Records a finished daily as a ghost for tomorrow's players.
    func recordGhost(from state: GameState, day: Int, score: Int, now: Date = Date()) {
        let launches = state.products.compactMap { product -> GhostLaunch? in
            guard case .released(let release) = product.stage else { return nil }
            return GhostLaunch(
                day: release.launchDay, topicID: product.topicID, typeID: product.typeID,
                name: product.name, quality: Double(AwardsJudge.reviewScore(release))
            )
        }
        let founder = state.employees.first { $0.isFounder }
        let topics = Array(Set(launches.map(\.topicID))).sorted()
        let log = GhostLog(
            day: day,
            player: ghostName(for: state),
            companyName: state.company.name,
            appearanceSeed: founder?.appearanceSeed ?? state.seed,
            focusTopicIDs: topics.isEmpty ? [state.products.first?.topicID].compactMap { $0 } : topics,
            launches: launches,
            finalNetWorth: score,
            recordedAt: now
        )
        ghostStore.save(log)
        Task { await CloudGhostStore.push(log) }
    }

    /// Where the player finished against the ghosts in the field: "2nd of
    /// 5", or `nil` when the field was rolled.
    static func ghostRank(score: Int, ghosts: [GhostScript]) -> String? {
        guard !ghosts.isEmpty else { return nil }
        let ahead = ghosts.filter { $0.finalNetWorth > score }.count
        let place = ahead + 1
        let suffix: String = switch place {
        case 1: "st"
        case 2: "nd"
        case 3: "rd"
        default: "th"
        }
        return "\(place)\(suffix) of \(ghosts.count + 1)"
    }
}
