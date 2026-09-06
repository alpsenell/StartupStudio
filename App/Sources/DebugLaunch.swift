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
        // MARK: L2 (life score)
        // MARK: L3 (children)
        // MARK: L4 (friends)
        // MARK: L5 (side project)
        // MARK: L6 (sabbatical)
        // MARK: L7 (furnish)
        case "furnish": .furnish
        // MARK: end of Iteration 9
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

    // MARK: L2 (life score)

    // MARK: L3 (children)

    // MARK: L4 (friends)

    // MARK: L5 (side project)

    // MARK: L6 (sabbatical)

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
