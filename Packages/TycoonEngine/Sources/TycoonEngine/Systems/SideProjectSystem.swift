import Foundation
import TycoonContent

/// The thing the founder is building that is not the company.
///
/// Three actions (start, work, abandon) and one very small daily `run`.
/// The rule the whole lane keeps: with `life.sideProject == nil` — every
/// fresh game, every old save, every pacing bot — `run` returns on its
/// first line and nothing in this file has touched the state.
///
/// The only draw anywhere here is the restaurant's last chapter, a single
/// coin flip on `socialRNG`, and it can only happen to a founder who has
/// spent twenty evenings getting to it.
enum SideProjectSystem {

    // MARK: - Daily

    /// The marathon creeps forward on the days the founder is training
    /// anyway. Every other track needs an evening.
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        guard var project = state.life.sideProject, let track = project.track,
              let def = balance.sideProject.track(track),
              project.chapter < def.chapters.count,
              SideProjectTrack(rawValue: track) == .marathon,
              trainingLately(state, balance)
        else { return [] }

        project.progress += balance.sideProject.gymProgressPerDay
        state.life.sideProject = project
        return settle(state: &state, balance: balance)
    }

    /// Whether the founder's legs have seen anything this week: a gym
    /// session inside the window, or the gym as the standing weekend plan.
    /// Reads the gym; never writes it.
    private static func trainingLately(_ state: GameState, _ balance: BalanceConfig) -> Bool {
        if state.life.plannedActivity == .gym { return true }
        guard let last = state.life.instantCooldowns[InstantActivity.gymSession.rawValue]
        else { return false }
        return state.day - last <= balance.sideProject.gymWindowDays
    }

    // MARK: - Starting

    /// Picks up a track. Free — the cost of a side project is every
    /// evening after this one.
    static func start(
        track: String,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard startBlocker(track: track, state: state, balance: balance) == nil,
              let def = balance.sideProject.track(track)
        else { return [] }

        var project = state.life.sideProject
            ?? SideProjectState(track: nil, startedDay: state.day)
        project.track = track
        project.startedDay = state.day
        project.chapter = 0
        project.progress = 0
        project.lastSessionDay = nil
        project.sessionsThisProject = 0
        state.life.sideProject = project

        let name = SideProjectTrack(rawValue: track)?.displayName ?? track
        state.life.phone.post(
            "You started something on the side: \(name.lowercased()). \(def.blurb)",
            from: .partner, day: state.day
        )
        return []
    }

    /// Why starting this track would be refused, in the player's words.
    static func startBlocker(
        track: String,
        state: GameState,
        balance: BalanceConfig
    ) -> String? {
        guard balance.sideProject.track(track) != nil else { return "Not available" }
        if state.life.isAway(day: state.day) { return "You're away" }
        if let project = state.life.sideProject {
            if let current = project.track {
                let name = SideProjectTrack(rawValue: current)?.displayName ?? current
                return "\(name) first"
            }
            if project.hasCompleted(track) { return "Already done" }
        }
        return nil
    }

    // MARK: - An evening

    /// One evening on the project: energy, a little money, a mood pop, and
    /// a slice of the chapter proportional to the founder's attributes.
    static func work(state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        guard workBlocker(state: state, balance: balance) == nil,
              var project = state.life.sideProject, let track = project.track,
              let def = balance.sideProject.track(track)
        else { return [] }

        let step = state.sideProjectSessionValue(balance)
        project.progress += step
        project.lastSessionDay = state.day
        project.sessionsThisProject += 1
        state.life.sideProject = project

        state.life.wallet -= def.sessionCost
        state.life.meters.apply(
            energy: def.sessionEnergy, health: def.sessionHealth, mood: def.sessionMood
        )
        state.spendEvening(balance)

        return settle(state: &state, balance: balance)
    }

    /// Why tonight's session would be refused. The Life tab reads this
    /// rather than writing the rules out again in SwiftUI.
    static func workBlocker(state: GameState, balance: BalanceConfig) -> String? {
        guard let project = state.life.sideProject, let track = project.track,
              let def = balance.sideProject.track(track)
        else { return "Nothing on the go" }
        if state.life.isAway(day: state.day) { return "You're away" }
        if project.workedToday(state.day) { return "That's enough for tonight" }
        if let reason = state.eveningBlocker(balance) { return reason }
        if def.sessionCost > 0, state.life.wallet < def.sessionCost {
            return "Need $\(def.sessionCost - state.life.wallet) more"
        }
        return nil
    }

    // MARK: - Abandoning

    /// Puts it down. The chapters already finished stay finished — a
    /// half-written novel does not, which is the deal the sheet states.
    static func abandon(state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        guard var project = state.life.sideProject, let track = project.track
        else { return [] }
        let name = SideProjectTrack(rawValue: track)?.displayName ?? track
        project.track = nil
        project.chapter = 0
        project.progress = 0
        project.lastSessionDay = nil
        project.sessionsThisProject = 0
        state.life.sideProject = project
        state.life.phone.post(
            "You put \(name.lowercased()) down. It was taking the evenings.",
            from: .partner, day: state.day
        )
        return []
    }

    // MARK: - Chapter completion

    /// Pays out every chapter the current progress has crossed. Shared by
    /// the evening and the marathon's daily creep, so a milestone lands
    /// identically whichever finished it.
    private static func settle(
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        var events: [GameEvent] = []
        // A chapter at a time, and never more than the four there are: the
        // loop is bounded by the catalog, not by the progress number.
        while var project = state.life.sideProject, let track = project.track,
              let def = balance.sideProject.track(track),
              project.chapter < def.chapters.count,
              project.progress >= 1 {
            let chapter = def.chapters[project.chapter]
            events.append(contentsOf: pay(chapter, track: track, state: &state, balance: balance))

            project = state.life.sideProject ?? project
            project.progress = max(0, project.progress - 1)
            project.chapter += 1

            if project.chapter >= def.chapters.count {
                // Finished. The record outlives the project.
                project.completedTracks.append(
                    CompletedSideProject(track: track, finishedDay: state.day)
                )
                project.track = nil
                project.progress = 0
                project.chapter = 0
                project.lastSessionDay = nil
                project.sessionsThisProject = 0
            }
            state.life.sideProject = project
        }
        return events
    }

    /// One chapter's payout: reputation, money, a perk, meters, the press
    /// line, and the two texts.
    private static func pay(
        _ chapter: BalanceConfig.SideProjectBalance.ChapterDef,
        track: String,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        // The one roll in the lane: the restaurant's first year. Drawn from
        // `socialRNG`, and only ever by a founder twenty evenings deep.
        var wallet = chapter.wallet
        var press = chapter.press
        if chapter.upsideChance > 0, state.socialRNG.nextUniform() < chapter.upsideChance {
            wallet = chapter.walletUpside
            press = chapter.pressUpside ?? chapter.press
        }

        if chapter.reputation != 0 {
            state.company.reputation = min(
                100, max(0, state.company.reputation + chapter.reputation)
            )
        }
        if wallet != 0 { state.life.wallet += wallet }
        if let perk = chapter.perk, ProgressionPerk(rawValue: perk) != nil {
            state.progression.perks.insert(perk)
        }
        state.life.meters.apply(
            energy: chapter.energy,
            health: chapter.health,
            mood: chapter.mood,
            relationships: chapter.relationships
        )

        state.life.phone.post(chapter.officeLine, from: .office, day: state.day)
        state.life.phone.post(chapter.partnerLine, from: .partner, day: state.day)

        // The trade press notices, and changes nothing: `.industryNews` is
        // flavour only, which is exactly the weight a milestone on a side
        // project should carry in the company's feed.
        guard let press else { return [] }
        return [.industryNews(headline: press, day: state.day)]
    }
}

// MARK: - Biography

extension SideProjectState {
    /// One line per finished track, for the last screen of the run.
    ///
    /// `FounderBiographyView` is L2's file; this is the function it calls
    /// so that L5's copy lives in L5's engine.
    public func biographyLines(balance: BalanceConfig, yearDays: Int = 365) -> [String] {
        completedTracks.compactMap { done in
            guard let def = balance.sideProject.track(done.track) else { return nil }
            let year = max(1, done.finishedDay / max(1, yearDays) + 1)
            return String(format: def.biographyLine, "\(year)")
        }
    }
}
