import Foundation
import TycoonEngine

/// Debug-only launch hooks for headless QA, alongside `GameSession`'s
/// existing `-autoSpeed`.
///
/// The simulator can be launched, screenshotted and killed from the command
/// line but not *tapped* without accessibility permissions, so every
/// workstream's screenshot pass needs a way to land on the screen it is
/// about. `-autoTab team` (hq | life | team | products | business) opens
/// the app on that tab; `-autoOrigin cofounded` (garage | cofounded |
/// spinOut | mortgaged) founds the generated game that way, since the
/// Stakes page cannot be tapped either; `-autoRoute warRoom` opens a
/// surface the tab's root would otherwise only open on a tap (the tab
/// root that owns the surface reads `launchRoute` and presents it).
///
/// Release builds ignore the argument entirely.
enum DebugLaunch {
    /// The surface a headless pass asked to land on: the lower-cased word
    /// after `-autoRoute` in debug builds, `nil` otherwise. Each tab root
    /// recognises its own names (`warroom`, `launchday` on Products).
    static var launchRoute: String? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-autoRoute"),
              arguments.indices.contains(flag + 1)
        else { return nil }
        return arguments[flag + 1].lowercased()
        #else
        return nil
        #endif
    }

    /// The origin a headless pass founds its generated game with:
    /// `-autoOrigin <name>` in debug builds, `nil` (a garage) otherwise.
    static var launchOrigin: FoundingOrigin? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-autoOrigin"),
              arguments.indices.contains(flag + 1)
        else { return nil }
        return FoundingOrigin.allCases.first {
            $0.rawValue.lowercased() == arguments[flag + 1].lowercased()
        }
        #else
        return nil
        #endif
    }

    /// The screen a headless pass opens on top of HQ: `-autoRoute
    /// newspaper|timeline` in debug builds, `nil` otherwise. U2's two
    /// screens are pushed from cards nobody can tap from the command line.
    /// (`launchRoute` above is the raw flag every tab root reads; this is
    /// HQ's typed reading of it.)
    static var launchStoryRoute: Route? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-autoRoute"),
              arguments.indices.contains(flag + 1)
        else { return nil }
        return switch arguments[flag + 1].lowercased() {
        case "newspaper": .newspaper
        case "timeline": .timeline
        default: nil
        }
        #else
        return nil
        #endif
    }

    /// The screen a headless pass wants pushed once the tab is up:
    /// `-autoRoute marketMap|rivalProfile` in debug builds (iteration 6,
    /// U3), `nil` otherwise and after it has been handed out once.
    ///
    /// The rival profile needs a rival, and a fresh game has none until
    /// the first tick founds the field, so the route is resolved against
    /// state and left pending until it can be — the strongest rival on
    /// the board, or the incumbent when there is one.
    @MainActor
    static func takeLaunchRoute(in state: GameState) -> Route? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard !launchRouteConsumed,
              let flag = arguments.firstIndex(of: "-autoRoute"),
              arguments.indices.contains(flag + 1)
        else { return nil }
        switch arguments[flag + 1].lowercased() {
        case "marketmap":
            launchRouteConsumed = true
            return .marketMap
        case "rivalprofile":
            let strongest = state.rivals.rivals.max { lhs, rhs in
                if lhs.strength != rhs.strength { return lhs.strength < rhs.strength }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            guard let rival = state.rivals.incumbent ?? strongest else { return nil }
            launchRouteConsumed = true
            return .rivalProfile(rivalID: rival.id)
        default:
            return nil
        }
        #else
        return nil
        #endif
    }

    /// `-autoAnswer`: a headless pass answers every question the game asks
    /// with its first open option, closes the launch-day sheet, and keeps
    /// the clock at the `-autoSpeed` pace — so a screen can be photographed
    /// weeks into a run that would otherwise stop, modal up, at the first
    /// story beat. Started once, from HQ's root task; the loop outlives
    /// the view. Release builds never run it.
    @MainActor
    static func startAutoAnswering(engine: GameEngine) {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-autoAnswer"), autoAnswerTask == nil else { return }
        let pace: SimSpeed = if let flag = arguments.firstIndex(of: "-autoSpeed"),
                                arguments.indices.contains(flag + 1),
                                let speed = SimSpeed(rawValue: arguments[flag + 1]), speed != .paused {
            speed
        } else {
            .x4
        }
        autoAnswerTask = Task { @MainActor in
            while !Task.isCancelled, engine.state.gameOver == nil {
                try? await Task.sleep(for: .milliseconds(200))
                // The first open option, except the one that ends the run:
                // a pass that sells the company on day 68 photographs
                // nothing.
                if let prompt = DecisionPrompt.pending(in: engine.state, content: engine.content, balance: engine.balance),
                   // MARK: Iteration 9 — L1 (phone)
                   // With `-autoDeferBeats` the pass leaves the questions
                   // the phone can answer alone, so the thread can be
                   // photographed with its reply buttons up.
                   !(arguments.contains("-autoDeferBeats") && prompt.id.hasPrefix("staff-")),
                   // MARK: end L1
                   let option = prompt.options.first(where: { option in
                       guard option.disabledReason == nil else { return false }
                       switch option.action {
                       case .acceptBuyout, .acceptBuyoutEarnOut: return false
                       default: return true
                       }
                   }) {
                    _ = engine.send(option.action)
                }
                GameShell.shared.launchDayProductID = nil
                if engine.state.speed == .paused {
                    engine.setSpeed(pace)
                }
            }
        }
        #endif
    }

    #if DEBUG
    @MainActor private static var autoAnswerTask: Task<Void, Never>?
    #endif

    #if DEBUG
    @MainActor private static var launchRouteConsumed = false
    #endif

    /// Whether this launch is a headless QA pass — `-autoSpeed`,
    /// `-autoTab`, `-autoRoute` or `-autoTour` on the command line.
    ///
    /// Those two flags exist so a screenshot pass can land on a running
    /// game without tapping anything, and the front door and the
    /// onboarding flow (neither of which can be tapped either) would
    /// otherwise sit in front of every one of them on a fresh install. A
    /// headless launch therefore skips both, straight into slot 0: its
    /// save if there is one, a generated new game otherwise. Release
    /// builds never see it.
    static var isHeadlessPass: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        // Iteration 7 (R3): `-autoDaily` is entered *from* the front door —
        // the daily is a title-screen row — so a pass carrying it keeps the
        // door even alongside a speed, and the daily starts itself there.
        guard !arguments.contains("-autoDaily"), !arguments.contains("-autoScenario"),
              !arguments.contains("-autoRoom") else { return false }
        return arguments.contains("-autoSpeed") || arguments.contains("-autoTab")
            || arguments.contains("-autoRoute") || arguments.contains("-autoTour")
        #else
        return false
        #endif
    }

    /// The screen a headless QA pass wants to land on, from
    /// `-autoRoute <name>` — `storefront` is U6's, since the "View in
    /// store" button cannot be tapped either. `nil` in a release build and
    /// whenever the flag is absent.
    ///
    /// Only the argument is parsed here. What to do about it belongs to
    /// the surface that owns the route (see `StorefrontAutoRoute`), so
    /// this file never grows a branch per lane.
    static var autoRouteName: String? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-autoRoute"),
              arguments.indices.contains(flag + 1)
        else { return nil }
        return arguments[flag + 1].lowercased()
        #else
        return nil
        #endif
    }
}

extension Route {
    /// The destination a headless pass lands on inside its tab:
    /// `-autoRoute agenda` (Life) or `-autoRoute orgChart` (Team), `nil`
    /// otherwise.
    ///
    /// `-autoTab` gets a screenshot pass to a tab; anything one tap deeper
    /// than that used to be unreachable, because the simulator cannot be
    /// tapped without accessibility permissions. The tab roots read this
    /// once when they first appear and push it themselves, so no shared
    /// root has to know about it. Release builds never see it.
    static var launchRoute: Route? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-autoRoute"),
              arguments.indices.contains(flag + 1)
        else { return nil }
        return switch arguments[flag + 1].lowercased() {
        case "agenda": .agenda
        case "orgchart": .orgChart
        // MARK: Iteration 9 — route names, one line per lane
        // MARK: L1 (phone)
        case "phone": .phone
        // MARK: L2 (life score)
        case "lifescore": .lifeScore
        // MARK: L3 (children)
        case "children": .children
        // MARK: L4 (friends)
        case "friends", "friendsheet": .friends
        // MARK: L5 (side project)
        case "sideproject": .sideProject
        // MARK: L6 (sabbatical)
        case "sabbatical", "sabbaticalreport": .sabbatical
        // MARK: L7 (furnish)
        case "furnish": .furnish
        // MARK: end of Iteration 9
        // MARK: Iteration 10 — route names
        // MARK: M1 (feature board)
        // MARK: M2 (pitch room)
        case "pitch": .pitch
        // MARK: M3 (incident room)
        // MARK: M4 (leagues)
        // MARK: M5 (morning desk)
        // MARK: M6 (bug hunt)
        // MARK: end of Iteration 10
        default: nil
        }
        #else
        return nil
        #endif
    }
}

extension GameTab {
    /// The tab the app opens on: `-autoTab <name>` in debug builds, HQ
    /// otherwise.
    static var launchTab: GameTab {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-autoTab"),
              arguments.indices.contains(flag + 1)
        else { return .hq }
        return switch arguments[flag + 1].lowercased() {
        case "life": .life
        case "team": .team
        case "products": .products
        case "business": .business
        default: .hq
        }
        #else
        return .hq
        #endif
    }
}

// MARK: - Iteration 7: reserved flags

// Parsed here so no lane edits this file for a flag; each lane reads its
// own. All DEBUG-only, like the rest.
extension DebugLaunch {
    /// `-unlocked`: the full game, for the screenshot pipeline (R6, R8).
    ///
    /// The flag sticks: one launch with `-unlocked` is remembered on the
    /// device, so an icon launch afterwards keeps the game open — a
    /// personal-team device build cannot make even a sandbox purchase. A
    /// launch with `-locked` forgets it. Debug builds only; release never
    /// reads the key.
    static var isUnlocked: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let defaults = UserDefaults.standard
        if arguments.contains("-locked") {
            defaults.removeObject(forKey: persistentUnlockKey)
            return false
        }
        if arguments.contains("-unlocked") {
            defaults.set(true, forKey: persistentUnlockKey)
            return true
        }
        // A remembered unlock must never reach the test host: the gate
        // tests run against the same defaults the simulator's launches
        // wrote into.
        guard NSClassFromString("XCTestCase") == nil else { return false }
        return defaults.bool(forKey: persistentUnlockKey)
        #else
        return false
        #endif
    }

    private static let persistentUnlockKey = "debug.unlocked"

    /// `-autoTour <beat>`: land on a tour beat headlessly (R1). The beat
    /// is `TutorialStep.rawValue`, 0–8.
    static var launchTourBeat: TutorialStep? {
        value(after: "-autoTour").flatMap(Int.init).flatMap(TutorialStep.init(rawValue:))
    }

    /// `-autoScenario <id>`: play that scenario from the front door
    /// (iteration 8); with `-autoSpeed` it plays through.
    static var launchScenarioID: String? {
        value(after: "-autoScenario")
    }

    /// `-autoDaily <yyyymmdd>`: play that day's company (R3).
    static var launchDailyDay: String? {
        value(after: "-autoDaily")
    }

    /// `-autoFixture <name>`: install a bundled fixture save into slot 0
    /// before the shell appears (R8).
    static var launchFixtureName: String? {
        value(after: "-autoFixture")
    }

    // MARK: Iteration 9 — reserved flags

    // Each lane adds its own `-auto…` flag between its markers (a fixture
    // or a route that lands a headless pass on its surface, for
    // screenshots). Route names go in `launchRoute` inside the same lane's
    // markers there if the surface is pushed rather than sheeted.

    // MARK: L1 (phone)

    /// `-autoThread`: with `-autoRoute phone`, open the newest thread as
    /// well. A headless pass cannot tap a row, and the thread is the
    /// surface this lane exists to draw.
    static var opensNewestPhoneThread: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-autoThread")
        #else
        return false
        #endif
    }

    /// `-autoThread <n>`: which thread in the recency list to open, when
    /// the newest is not the interesting one. Defaults to the newest.
    static var phoneThreadIndex: Int {
        value(after: "-autoThread").flatMap(Int.init) ?? 0
    }

    /// `-autoShareThread`: open the share card over the thread, so the
    /// 1080x1350 picture can be photographed headlessly.
    static var opensPhoneThreadShareCard: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-autoShareThread")
        #else
        return false
        #endif
    }

    /// `-autoThreadAsking`: open whichever thread is waiting on an answer,
    /// so a headless pass can photograph the reply buttons.
    static var opensAskingPhoneThread: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-autoThreadAsking")
        #else
        return false
        #endif
    }

    // MARK: L2 (life score)

    // MARK: L3 (children)

    /// `-autoChild`: open the first child's ledger sheet as soon as the
    /// kids screen appears (L3). `simctl` cannot tap, and the ledger and
    /// the evening / summer buttons are one tap past the list.
    static var opensFirstChild: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-autoChild")
        #else
        return false
        #endif
    }

    // MARK: L4 (friends)

    /// `-autoFriends warm` gives the friends room one call each and one
    /// evening on the way in, so a screenshot pass can see a friendship
    /// that has been worked on — and the offers that opens — without
    /// tapping. Debug only, and it does exactly what the taps would do.
    static var warmsFriends: Bool {
        #if DEBUG
        return value(after: "-autoFriends") == "warm"
        #else
        return false
        #endif
    }

    /// `-autoRoute friendsheet` lands on the friends room *and* opens the
    /// first friend's sheet, because a screenshot pass cannot tap a row.
    static var opensFirstFriendSheet: Bool {
        #if DEBUG
        return autoRouteName == "friendsheet"
        #else
        return false
        #endif
    }

    // MARK: L5 (side project)

    /// `-autoSideProject <track>`: the track a headless pass starts and
    /// then feeds its evenings to. See `SideProjectDebug`.
    static var launchSideProjectTrack: String? {
        value(after: "-autoSideProject")?.lowercased()
    }

    // MARK: L6 (sabbatical)

    /// `-autoSabbatical [weeks]`: a headless pass gets the founder out of
    /// the building.
    ///
    /// The gates on a caretaker are a tenure *and a bond*, and a bond is
    /// something a player builds by hand over months — which is exactly
    /// what a simulator pass cannot do, because it cannot tap. So this
    /// flag spends the founder's evenings on the longest-serving person on
    /// the roster (hang-outs, mentoring, coffees — every one of them a real
    /// `GameAction` through the ordinary reducer, no back door into state)
    /// until the engine says they qualify, then hands them the keys.
    /// Requires `-autoSpeed`, since every one of those actions is on a
    /// cooldown measured in game days. DEBUG only, like every flag here.
    static var autoSabbaticalWeeks: Int? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-autoSabbatical") else { return nil }
        return value(after: "-autoSabbatical").flatMap(Int.init) ?? 6
        #else
        return nil
        #endif
    }

    /// Starts that loop, once per launch. Called from the sabbatical card
    /// and screen (both live on the Life tab, which is where the flag's
    /// pass lands); the task outlives either view.
    @MainActor
    static func startAutoSabbatical(engine: GameEngine) {
        #if DEBUG
        guard let weeks = autoSabbaticalWeeks, autoSabbaticalTask == nil else { return }
        autoSabbaticalTask = Task { @MainActor in
            while !Task.isCancelled, engine.state.gameOver == nil {
                try? await Task.sleep(for: .milliseconds(250))
                // A pass that runs for game-months walks into the awards
                // night and the launch-day sheet, neither of which a
                // simulator can tap away; clear them the way
                // `startAutoAnswering` clears its own.
                GameShell.shared.pendingAwardsYear = nil
                GameShell.shared.launchDayProductID = nil
                // Anything that pauses the timeline stops the pass dead.
                if engine.state.speed == .paused { engine.setSpeed(.x4) }
                // `startAutoAnswering` runs from HQ's root, which a pass
                // that lands on Life never shows: answer the questions
                // here too, or the first poach offer stops the clock.
                if let prompt = DecisionPrompt.pending(
                    in: engine.state, content: engine.content, balance: engine.balance
                ), let option = prompt.options.first(where: { option in
                    guard option.disabledReason == nil else { return false }
                    switch option.action {
                    case .acceptBuyout, .acceptBuyoutEarnOut: return false
                    default: return true
                    }
                }) {
                    _ = engine.send(option.action)
                }
                let state = engine.state
                // Once the founder has been away once, the loop stops
                // acting and just keeps the modals off the screen — except
                // under `-autoRoute sabbaticalreport`, which wants the
                // return sheet and so flies home after a fortnight.
                if let sabbatical = state.life.sabbatical {
                    if sabbatical.isActive, autoRouteName == "sabbaticalreport",
                       state.day - sabbatical.sinceDay >= 14 {
                        _ = engine.send(.endSabbaticalEarly)
                    }
                    continue
                }
                guard let target = state.employees
                    .filter({ !$0.isFounder })
                    .min(by: { $0.hiredDay < $1.hiredDay })
                else { continue }
                // A company nobody is playing runs out of money in about a
                // quarter, which is shorter than the months of coffees a
                // caretaker needs. Borrow, the way a player would.
                if state.company.cash < 60_000 {
                    _ = engine.send(.takeLoan(amount: 60_000))
                }
                // The trip is the founder's own money, so keep the wallet
                // fed the way a player would — with a salary, not a cheat.
                if state.life.founderSalary < 2000 {
                    _ = engine.send(.setFounderSalary(min(2000, engine.balance.life.founderSalaryMax)))
                }
                if state.caretakerBlocker(target, balance: engine.balance) != nil {
                    _ = engine.send(.oneOnOne(employeeID: target.id))
                    _ = engine.send(.mentorEmployee(employeeID: target.id, skill: .coding))
                    _ = engine.send(.grabCoffee(employeeID: target.id))
                    continue
                }
                _ = engine.send(.startSabbatical(caretakerID: target.id, weeks: weeks))
            }
        }
        #endif
    }

    #if DEBUG
    @MainActor private static var autoSabbaticalTask: Task<Void, Never>?
    #endif

    // MARK: L7 (furnish)

    /// `-autoDecor`: draws one of everything in the home, so a headless
    /// pass photographs a furnished room at every tier without owning a
    /// thing. Display only — nothing is written to the save.
    static var fillsDecor: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-autoDecor")
        #else
        return false
        #endif
    }

    /// `-autoHome penthouse`: draws the home card and the furnish sheet
    /// at that tier whatever the save says, so one pass can photograph
    /// all four rooms. Display only — the founder has not moved.
    static var decorTier: HomeTier? {
        #if DEBUG
        return value(after: "-autoHome").flatMap { name in
            HomeTier.allCases.first { $0.rawValue.lowercased() == name.lowercased() }
        }
        #else
        return nil
        #endif
    }

    // MARK: end of Iteration 9

    // MARK: Iteration 10 — reserved flags

    // MARK: M1 (feature board)

    // MARK: M2 (pitch room)

    /// `-autoPitch <investor|client|journalist|board>`: the chair a
    /// headless pass sits down in. A simulator cannot tap a button, and
    /// the room is the surface this lane exists to draw, so the matching
    /// *Talk first* button opens its own sheet once when it appears.
    /// Everything after that is the ordinary reducer.
    static var launchPitchCounterpart: String? {
        #if DEBUG
        return value(after: "-autoPitch")?.lowercased()
        #else
        return nil
        #endif
    }

    /// `-autoPitchSay <topic,topic,…>`: the exchanges a headless pass
    /// makes once the room is open, so a screenshot can be of a
    /// conversation in progress rather than an opener. Topic names are
    /// `ConversationTopic` raw values.
    static var launchPitchScript: [String] {
        #if DEBUG
        return value(after: "-autoPitchSay")?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? []
        #else
        return []
        #endif
    }

    // MARK: M3 (incident room)

    // MARK: M4 (leagues)

    // MARK: M5 (morning desk)

    // MARK: M6 (bug hunt)

    // MARK: end of Iteration 10

    /// The word after `flag` on the command line, in debug builds.
    static func value(after flag: String) -> String? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1)
        else { return nil }
        return arguments[index + 1]
        #else
        return nil
        #endif
    }
}
