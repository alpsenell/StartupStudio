import Foundation

// Iteration 9 — L5 owns this file and may reshape it freely.

/// The five things a founder builds that are not the company.
///
/// A track is a *string* on the state (`SideProjectState.track`) so the
/// catalog in `BalanceConfig.SideProjectBalance` can be retuned — or
/// extended — from `Balance.json` without touching the engine. This enum
/// is the shipped set: it gives the app its order, its art and its icons,
/// and it names the attributes each track actually runs on.
public enum SideProjectTrack: String, Codable, Equatable, Sendable, CaseIterable {
    case novel, band, marathon, weekendApp, restaurant

    public var displayName: String {
        switch self {
        case .novel: "The Novel"
        case .band: "The Band"
        case .marathon: "The Marathon"
        case .weekendApp: "The Weekend App"
        case .restaurant: "The Restaurant"
        }
    }

    /// What one evening on this track is called, for the button.
    public var sessionVerb: String {
        switch self {
        case .novel: "Write tonight"
        case .band: "Rehearse tonight"
        case .marathon: "Go for a run"
        case .weekendApp: "Build tonight"
        case .restaurant: "Work the kitchen"
        }
    }
}

/// One driver of a side project's progress: the founder's own attributes,
/// plus the two meters that are really attributes in disguise.
///
/// Kept as a string in the balance so a track can be driven by anything
/// the founder has a number for, and resolved here rather than in five
/// places. Anything unrecognised reads as the neutral midpoint, so a
/// mistyped balance slows nothing down.
public enum SideProjectDriver: String, Codable, Equatable, Sendable, CaseIterable {
    case conversation, technical, marketKnowledge, leadership, finance
    case health, energy

    public var displayName: String {
        switch self {
        case .conversation: "Conversation"
        case .technical: "Technical"
        case .marketKnowledge: "Market Sense"
        case .leadership: "Leadership"
        case .finance: "Finance"
        case .health: "Health"
        case .energy: "Energy"
        }
    }

    /// The founder's current 0…100 value for this driver.
    public func value(in life: LifeState) -> Double {
        switch self {
        case .conversation: life.skills.conversation
        case .technical: life.skills.technical
        case .marketKnowledge: life.skills.marketKnowledge
        case .leadership: life.skills.leadership
        case .finance: life.skills.finance
        case .health: life.meters.health
        case .energy: life.meters.energy
        }
    }
}

/// A track the founder actually finished, and the day they finished it.
/// The day is what lets the biography say *when*, which is the whole
/// difference between a list and a life.
public struct CompletedSideProject: Codable, Equatable, Sendable, Identifiable {
    public var track: String
    public var finishedDay: Int

    public var id: String { track }

    public init(track: String, finishedDay: Int) {
        self.track = track
        self.finishedDay = finishedDay
    }
}

/// Something the founder builds that is not the company: a novel, a band,
/// a marathon, a weekend app, a restaurant.
///
/// `nil` on `LifeState` until the founder starts one, and non-`nil`
/// forever after — an abandoned or finished project leaves the record
/// behind with `track` set to `nil`, because "you wrote a novel once" is
/// the point of the feature and must survive the next project.
public struct SideProjectState: Codable, Equatable, Sendable {
    /// The track id currently under way, or `nil` between projects.
    /// One at a time, always.
    public var track: String?
    /// The day the *current* project began.
    public var startedDay: Int
    /// 0-based index into the track's chapters.
    public var chapter: Int
    /// 0...1 through the current chapter.
    public var progress: Double
    /// Everything finished, oldest first. Never cleared.
    public var completedTracks: [CompletedSideProject]
    /// The last day an evening went into this project — one session a day.
    public var lastSessionDay: Int?
    /// Evenings spent on the current project, for the card's line.
    public var sessionsThisProject: Int

    public init(
        track: String?,
        startedDay: Int,
        chapter: Int = 0,
        progress: Double = 0,
        completedTracks: [CompletedSideProject] = [],
        lastSessionDay: Int? = nil,
        sessionsThisProject: Int = 0
    ) {
        self.track = track
        self.startedDay = startedDay
        self.chapter = chapter
        self.progress = progress
        self.completedTracks = completedTracks
        self.lastSessionDay = lastSessionDay
        self.sessionsThisProject = sessionsThisProject
    }

    /// Whether a project is under way right now.
    public var isActive: Bool { track != nil }

    /// The shipped track behind `track`, when it is one of the five.
    public var kind: SideProjectTrack? { track.flatMap(SideProjectTrack.init(rawValue:)) }

    public func hasCompleted(_ track: String) -> Bool {
        completedTracks.contains { $0.track == track }
    }

    /// A session was done today already.
    public func workedToday(_ day: Int) -> Bool { lastSessionDay == day }

    // MARK: Codable

    // Hand-written so a save from any point in this feature's life decodes:
    // `track` was non-optional in the scaffold and every field below it is
    // newer than that. An absent `sideProject` key is still `nil`, which is
    // the identity case the whole lane rests on.
    private enum CodingKeys: String, CodingKey {
        case track, startedDay, chapter, progress
        case completedTracks, lastSessionDay, sessionsThisProject
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            track: try container.decodeIfPresent(String.self, forKey: .track),
            startedDay: try container.decodeIfPresent(Int.self, forKey: .startedDay) ?? 0,
            chapter: try container.decodeIfPresent(Int.self, forKey: .chapter) ?? 0,
            progress: try container.decodeIfPresent(Double.self, forKey: .progress) ?? 0,
            completedTracks: try container.decodeIfPresent(
                [CompletedSideProject].self, forKey: .completedTracks
            ) ?? [],
            lastSessionDay: try container.decodeIfPresent(Int.self, forKey: .lastSessionDay),
            sessionsThisProject: try container.decodeIfPresent(
                Int.self, forKey: .sessionsThisProject
            ) ?? 0
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(track, forKey: .track)
        try container.encode(startedDay, forKey: .startedDay)
        try container.encode(chapter, forKey: .chapter)
        try container.encode(progress, forKey: .progress)
        // Written only once there is something to remember, so the state a
        // never-engaged run encodes is byte-identical to the one it always
        // encoded.
        if !completedTracks.isEmpty {
            try container.encode(completedTracks, forKey: .completedTracks)
        }
        try container.encodeIfPresent(lastSessionDay, forKey: .lastSessionDay)
        if sessionsThisProject > 0 {
            try container.encode(sessionsThisProject, forKey: .sessionsThisProject)
        }
    }
}

// MARK: - Queries

public extension GameState {
    /// The founder's side project, or `nil` if they never started one.
    var sideProject: SideProjectState? { life.sideProject }

    /// The chapter the founder is on, when a project is under way.
    func sideProjectChapter(
        _ balance: BalanceConfig
    ) -> BalanceConfig.SideProjectBalance.ChapterDef? {
        guard let project = life.sideProject, let track = project.track,
              let def = balance.sideProject.track(track),
              project.chapter < def.chapters.count
        else { return nil }
        return def.chapters[project.chapter]
    }

    /// What one evening is worth on the current chapter, as a fraction of
    /// it: the chapter's base rate scaled by the founder's attributes.
    ///
    /// The factor is centred on `balance.founder.skillMidpoint`, so a
    /// founder who has never trained finishes every chapter in exactly the
    /// number of evenings the catalog says.
    func sideProjectSessionValue(_ balance: BalanceConfig) -> Double {
        guard let project = life.sideProject, let track = project.track,
              let def = balance.sideProject.track(track),
              let chapter = sideProjectChapter(balance),
              chapter.sessions > 0
        else { return 0 }
        return balance.sideProject.factor(for: def, life: life, founder: balance.founder)
            / chapter.sessions
    }

    /// Why tonight's session would be refused, in the player's words, or
    /// `nil` when it would go ahead. The Life tab's disabled button reads
    /// this rather than restating the rules in SwiftUI, so the button and
    /// the reducer can never disagree.
    func sideProjectWorkBlocker(_ balance: BalanceConfig) -> String? {
        SideProjectSystem.workBlocker(state: self, balance: balance)
    }

    /// Why starting `track` would be refused, or `nil`.
    func sideProjectStartBlocker(_ track: String, balance: BalanceConfig) -> String? {
        SideProjectSystem.startBlocker(track: track, state: self, balance: balance)
    }

    /// What tonight costs, written the way every other button on the Life
    /// tab writes it: "−1 evening · −$40 → $2,110 · −6 energy".
    func sideProjectSessionConsequence(_ balance: BalanceConfig) -> String {
        guard let track = life.sideProject?.track,
              let def = balance.sideProject.track(track)
        else { return "" }
        var parts: [String] = []
        if eveningsPerWeek(balance) != nil { parts.append("−1 evening") }
        if def.sessionCost > 0 {
            parts.append("−$\(def.sessionCost) → $\(life.wallet - def.sessionCost)")
        }
        if def.sessionEnergy != 0 {
            parts.append("\(Int(def.sessionEnergy)) energy")
        }
        if def.sessionMood > 0 { parts.append("+\(Int(def.sessionMood)) mood") }
        return parts.joined(separator: " · ")
    }

    /// Evenings still to go on this chapter at today's rate, rounded up.
    func sideProjectSessionsLeft(_ balance: BalanceConfig) -> Int? {
        guard let project = life.sideProject, project.isActive else { return nil }
        let perSession = sideProjectSessionValue(balance)
        guard perSession > 0 else { return nil }
        return max(1, Int(((1 - project.progress) / perSession).rounded(.up)))
    }
}
