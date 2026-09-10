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
        // MARK: K4 (deals and exits)
        // The smallest studio on the board: the paper deal a big company
        // can sign today.
        case "paperdeal":
            let smallest = state.rivals.rivals.min { lhs, rhs in
                if lhs.strength != rhs.strength { return lhs.strength < rhs.strength }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            guard let rival = smallest else { return nil }
            launchRouteConsumed = true
            return .rivalProfile(rivalID: rival.id)
        // MARK: end K4
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
        // Iteration 10 (M4): `-autoLeague` is the same shape — the League
        // is a title-screen row, and the week starts itself from there.
        guard !arguments.contains("-autoDaily"), !arguments.contains("-autoScenario"),
              !arguments.contains("-autoRoom"), !arguments.contains("-autoLeague") else { return false }
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
        // Handled by `featureBoardAutoRoute`, which needs a product id no
        // command line can supply.
        case "featureboard", "features", "featuredetail", "featurestore": nil
        // MARK: M2 (pitch room)
        case "pitch": .pitch
        // MARK: M3 (incident room)
        case "incident", "incidentroom": .incidentRoom
        // MARK: M4 (leagues)
        // MARK: M5 (morning desk)
        // MARK: M6 (bug hunt)
        // MARK: end of Iteration 10
        // MARK: Iteration 11 — route names
        // MARK: N1 (crime and the courtroom)
        case "crime", "ledger": .crimeLedger
        case "courtroom", "court", "hearing": .courtroom
        case "suit", "sue": .rivalSuit
        // MARK: N2 (people menus)
        // `-autoRoute people` lands on the partner's menu (the fixture
        // `l3-family-day900` has one); `-autoRoute peopleTeam` opens the
        // same menu on the first person on the roster.
        case "people", "peoplemenu": .peopleMenu(.partner)
        case "peopleteam": .peopleTeamMenu
        // MARK: N3 (assets, vices and the doctor)
        case "assets", "garage", "doctor", "casino", "habits": .assets
        // MARK: N4 (fame and the feed)
        case "feed", "fame": .feed
        // MARK: N5 (office secrets)
        case "secrets", "office": .secrets
        // MARK: end of Iteration 11
        // MARK: Iteration 11, wave two — route names
        // MARK: W1 (dirty money)
        case "dirtymoney", "backer", "facility": .dirtyMoney
        // MARK: W2 (family drama)
        case "family": .family
        case "divorce", "settlement": .divorce
        // MARK: W3 (espionage)
        case "spy", "espionage": .spy
        // MARK: W4 (inside)
        case "inside", "prison", "released": .inside
        // MARK: J1 (doors)
        case "door", "doors": .door(DoorDebug.requestedKind ?? .shark)
        // MARK: end J1
        // MARK: J2 (record)
        // The hiring sheet (the name line, the asks, the refusal) and the
        // cap table (the review line, the key-person clause).
        case "hiring", "standing": .hiring
        case "investors", "board", "boardreview": .investors
        // MARK: end J2
        // MARK: J3 (rivals and the market)
        // MARK: end J3
        // MARK: J4 (house field)
        // MARK: end J4
        // MARK: J5 (announce)
        case "announce", "premium": .announce
        // MARK: end J5
        // MARK: J6 (queue)
        // MARK: end J6
        // MARK: P1 (purchases: engine)
        // MARK: end P1
        // MARK: P2 (purchases: StoreKit and the session)
        // MARK: end P2
        // MARK: P3 (purchases: surfaces and copy)
        // The hire sheet with the veteran's row, and the furnish sheet with
        // the loft pack. `shop` and `receiver` are sheets over the HUD,
        // started by `ShopAutoRoute` (Store/ShopSurfaceDebug.swift).
        case "veteran": .hiring
        case "loftpack": .furnish
        // MARK: end P3
        // MARK: U1 (ux: the first-hour fixes)
        // MARK: end U1
        // MARK: V1 (ux: Life folded, rooms dormant)
        // MARK: end V1
        // MARK: V2 (ux: one inbox, one home per thing)
        // MARK: end V2
        // MARK: V3 (ux: card weights, the Now card)
        // MARK: end V3
        // MARK: K1 (founder money)
        // MARK: end K1
        // MARK: K2 (product lifecycle)
        // MARK: end K2
        // MARK: K3 (the ladder)
        case "k3-lead", "k3-options", "k3-holder": .ladderManage
        case "k3-captable": .investors
        // MARK: end K3
        // MARK: K4 (deals and exits)
        // The Rivals segment, where the for-sale sign lives.
        case "forsale", "sign", "deals": .rivals
        // MARK: end K4
        // MARK: K5 (hand over the keys)
        case "k5keys", "k5after", "k5card", "k5shut": .lifeScore
        // MARK: end K5
        // MARK: K6 (home and rooms)
        // MARK: end K6
        // MARK: K7 (partner and diary)
        // MARK: end K7
        // MARK: end of Iteration 15
        // MARK: end of Iteration 14
        // MARK: end of Iteration 13
        // MARK: end of Iteration 12
        // MARK: end of Iteration 11, wave two
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

    /// `-autoRoute featureboard` (or `-autoFeatureBoard`): a headless pass
    /// starts a build if the generated game has none, places a card or two
    /// so the board has something on it, and pushes the board screen. The
    /// simulator can be launched and photographed from the command line
    /// but not tapped, and the board is three taps deep.
    static var opensFeatureBoard: Bool { featureBoardDestination != nil }

    /// Which of M1's three screens a headless pass wants: the board
    /// itself, the product detail that links to it, or the store page that
    /// lists what the board put in the product.
    enum FeatureBoardDestination: String {
        case board, detail, storefront
    }

    static var featureBoardDestination: FeatureBoardDestination? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-autoFeatureBoard") { return .board }
        return switch launchRoute ?? "" {
        case "featureboard", "features": .board
        case "featuredetail": .detail
        case "featurestore": .storefront
        default: nil
        }
        #else
        return nil
        #endif
    }

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

    /// `-autoIncident <kind>` — `badPatch`, `viralSpike` or `dataLeak`.
    /// Plays a fixture company to a live product, raises that incident and
    /// opens the room, because a headless launch has neither a shipped
    /// product nor a way to tap the Products tab. Add `-autoIncidentPlay`
    /// to staff the lanes and work three hours first.
    /// See `IncidentDebug`.
    static var incidentKindName: String? {
        #if DEBUG
        return value(after: "-autoIncident")
        #else
        return nil
        #endif
    }

    // MARK: M4 (leagues)

    /// `-autoLeague`: the front door opens the League sheet on launch.
    /// With `-autoSpeed` as well it plays the week through, the way
    /// `-autoRoom season` does, so the result card can be photographed
    /// without a tap. `-autoLeague <yyyymmdd>` picks a week other than
    /// the one running now; `-autoLeague demo` fills the tier's ghost
    /// cache with a field so the table can be seen on a phone with no
    /// Game Center account.
    static var opensLeague: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-autoLeague")
        #else
        return false
        #endif
    }

    /// The word after `-autoLeague`, when it is one of ours.
    static var leagueArgument: String? {
        #if DEBUG
        guard let value = value(after: "-autoLeague"), !value.hasPrefix("-") else { return nil }
        return value
        #else
        return nil
        #endif
    }

    /// `-autoLeague demo`: seed the tier's ghost cache so the table has
    /// somebody in it. Display data for a screenshot pass, never a
    /// release build, and never anything the engine reads.
    static var seedsLeagueDemoField: Bool {
        leagueArgument?.lowercased() == "demo"
    }

    /// `-autoLeague challenge`: open the *Beat my company* card on a
    /// made-up challenge, so the comparison flow can be photographed.
    static var opensLeagueChallenge: Bool {
        leagueArgument?.lowercased() == "challenge"
    }

    /// `-autoLeague result`: open the comparison card.
    static var opensLeagueChallengeResult: Bool {
        leagueArgument?.lowercased() == "result"
    }

    // MARK: M5 (morning desk)

    /// `-autoDesk`: open the morning desk over the front door, on
    /// whatever slot 0 holds. Not a headless pass — the door stays and
    /// the desk opens on top of it, which is how it is photographed.
    /// Pair it with `-autoFixture <name>` for a company to have a
    /// morning about.
    static var opensMorningDesk: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-autoDesk")
        #else
        return false
        #endif
    }

    /// `-autoDesk cleared`: mark today's three the moment the desk opens,
    /// so the cleared desk — the stamp, the streak, the rewards and the
    /// reminder — can be photographed without a thumb. The papers'own
    /// actions are not sent; this is the screenshot pass, not a shortcut
    /// in the game.
    static var clearsMorningDesk: Bool {
        #if DEBUG
        return opensMorningDesk && value(after: "-autoDesk") == "cleared"
        #else
        return false
        #endif
    }

    // MARK: M6 (bug hunt)

    /// `-autoBugs`: a headless pass gets a build with bugs in it.
    ///
    /// Bugs are not a thing the game hands out; they are rolled per
    /// completed code point in `applyDailyProgress`, so the only way to
    /// have one is to have written some code. This flag therefore does
    /// what a player would: starts a product if none is in flight, puts
    /// everybody idle on it, and lets the clock run — every step a real
    /// `GameAction` through the ordinary reducer, no back door into state.
    /// It stops as soon as a build has bugs on it, and never taps one; the
    /// screenshot is of a room with bugs in it, not of a squash. Requires
    /// `-autoSpeed`, since bugs are days away at 1×. DEBUG only.
    static var huntsBugs: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-autoBugs")
        #else
        return false
        #endif
    }

    /// `-autoBugs splat`: the same pass, but every bug that reaches the
    /// floor is drawn as the splat and stays there.
    ///
    /// The splat is the half second after a tap, and a simulator cannot
    /// tap. Display only: nothing is squashed, no action is sent, no bug
    /// comes off any build — the room is just told to draw the frame the
    /// player would see.
    static var showsBugSplat: Bool {
        #if DEBUG
        return huntsBugs && value(after: "-autoBugs")?.lowercased() == "splat"
        #else
        return false
        #endif
    }

    /// Starts that loop, once per launch, from the office card.
    @MainActor
    static func startAutoBugs(engine: GameEngine) {
        #if DEBUG
        guard huntsBugs, autoBugsTask == nil else { return }
        autoBugsTask = Task { @MainActor in
            while !Task.isCancelled, engine.state.gameOver == nil {
                try? await Task.sleep(for: .milliseconds(250))
                // A pass that runs for game-weeks walks into sheets a
                // simulator cannot tap away; clear them the way
                // `startAutoSabbatical` clears its own.
                GameShell.shared.pendingAwardsYear = nil
                GameShell.shared.launchDayProductID = nil
                if engine.state.speed == .paused { engine.setSpeed(.x4) }
                // The first open option that is not the end of the run: a
                // pass that sells the company on week 8 photographs an
                // empty office.
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
                // One hire, so the bugs crawl in front of the desk grid
                // where the brief puts them rather than only the founder's
                // own corner — and only one, because a garage with three
                // salaries on it is bankrupt before the code goes wrong.
                if engine.state.headcount < 2, engine.state.company.cash > 8_000,
                   let candidate = engine.state.candidatePool.first {
                    _ = engine.send(.hire(candidateID: candidate.id))
                }
                // The moment there is something to hunt in a room with a
                // team in it, stop the clock and stop steering: a pass that
                // kept answering every prompt for game-years would run the
                // company into the ground long before anybody photographed
                // it.
                let openBugs = BugHunt.huntableBuilds(in: engine.state).reduce(0) { total, product in
                    guard case .development(let dev) = product.stage else { return total }
                    return total + dev.openBugs
                }
                // A garage with three salaries on it runs out of money in
                // about a quarter, and bugs are weeks of code away; borrow
                // the way a player would rather than let the pass end in a
                // fire sale.
                if engine.state.company.cash < 15_000 {
                    _ = engine.send(.takeLoan(amount: 40_000))
                }
                // Everybody idle goes on the build, so the bugs crawl in
                // front of *their* desks — and before the pause below, or
                // the pass stops the clock with the new hire still idle.
                if let build = engine.state.productsInDevelopment.first {
                    for employee in engine.state.employees
                    where employee.assignment != .product(build.id) {
                        _ = engine.send(.assign(employeeID: employee.id, to: .product(build.id)))
                    }
                }
                let onTheBuild = engine.state.productsInDevelopment.first.map { build in
                    engine.state.employees.allSatisfy { $0.assignment == .product(build.id) }
                } ?? false
                if openBugs >= 1, engine.state.headcount >= 2, onTheBuild {
                    engine.setSpeed(.paused)
                    return
                }
                guard engine.state.productsInDevelopment.isEmpty else { continue }
                guard let type = engine.content.productTypes.first,
                      let topic = engine.content.topics.first
                else { continue }
                // Code-heavy on purpose. Bugs are rolled per completed code
                // point and fixed per completed polish point, so a balanced
                // build cleans itself faster than it breaks and the pass
                // waits for ever.
                _ = engine.send(.startProduct(
                    typeID: type.id, topicID: topic.id,
                    name: "Bug Farm",
                    focus: PhaseFocus(design: 0.15, code: 0.8, polish: 0.05)
                ))
            }
        }
        #endif
    }

    #if DEBUG
    @MainActor private static var autoBugsTask: Task<Void, Never>?
    #endif

    // MARK: end of Iteration 10

    // MARK: Iteration 11 — reserved flags

    // MARK: N1 (crime and the courtroom)
    // Parsed in `CrimeDebug`, next to the screens that read them:
    // `-autoCase <offence>`, `-autoLawyer <tier>`, `-autoDefence <line>`
    // and `-autoCourtSay <exchange,exchange>`. Nothing to add here.

    // MARK: N2 (people menus)

    /// `-autoInteract <id>`: perform one interaction, once, on whichever
    /// person the people menu opened on, so a headless pass can photograph
    /// the outcome paper — a simulator cannot tap a row.
    ///
    /// It sends the ordinary `.interact` action through the ordinary
    /// reducer: no back door into state, and a refused one does exactly
    /// what it does for a player, which is nothing. DEBUG only.
    static var autoInteraction: String? {
        #if DEBUG
        return value(after: "-autoInteract")
        #else
        return nil
        #endif
    }

    /// `-autoPeopleKind <partner|child|friend|employee|contact>`: which
    /// person `-autoRoute people` should open on. Defaults to the partner.
    static var autoPeopleKind: InteractionTargetKind? {
        #if DEBUG
        return value(after: "-autoPeopleKind").flatMap(InteractionTargetKind.init(rawValue:))
        #else
        return nil
        #endif
    }

    /// `-autoPeopleGroup <nice|mean|money|serious>`: draw only that shelf
    /// of the menu. Display only — nothing is disabled, nothing is sent —
    /// and it exists because a screenshot pass cannot scroll to the mean
    /// half of a menu with twenty rows in it.
    static var autoPeopleGroup: String? {
        #if DEBUG
        return value(after: "-autoPeopleGroup")?.lowercased()
        #else
        return nil
        #endif
    }

    #if DEBUG
    @MainActor private static var autoInteractionTaken = false
    #endif

    /// Called by `PeopleMenuContent` when it appears.
    @MainActor
    static func takeAutoInteraction(engine: GameEngine, target: InteractionTarget) {
        #if DEBUG
        guard !autoInteractionTaken, let id = autoInteraction else { return }
        autoInteractionTaken = true
        _ = engine.send(.interact(target: target, interaction: id))
        #endif
    }

    // MARK: N3 (assets, vices and the doctor)

    /// `-autoAssets`: fills the garage for a screenshot pass — a coupé, a
    /// flat to let, a dog, some of the wallet that moves on its own, a
    /// ticket and three hands of blackjack.
    ///
    /// Every one of those is a real `GameAction` through the ordinary
    /// reducer, including the salary that pays for them, so the pass has
    /// no back door into state. DEBUG only, like every flag here, and
    /// consumed in `AssetsScreen.onAppear` — the one place the flag's
    /// route lands.
    static var fillsGarage: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-autoAssets")
        #else
        return false
        #endif
    }

    /// `-autoRoute doctor` / `casino`: which of the two sheets a headless
    /// pass should also open once the screen is up.
    static var opensAssetsSheet: String? {
        #if DEBUG
        let name = autoRouteName
        return name == "doctor" || name == "casino" ? name : nil
        #else
        return nil
        #endif
    }

    /// Fills the garage, once per launch, from `AssetsScreen`.
    ///
    /// A coupé is $45,000 of the founder's *own* money and a screenshot
    /// pass cannot play the four game-years that earns it — so, exactly
    /// like `startAutoSabbatical`, this borrows the way a player would,
    /// pays the founder the way a player would, and then buys the moment
    /// the wallet can actually carry it. Every step is a real
    /// `GameAction` through the ordinary reducer: no back door into
    /// state, and nothing here can put the game in a shape a played run
    /// could not reach. Requires `-autoSpeed`, since the wallet only
    /// fills on the weekly settlement.
    @MainActor
    static func startAutoAssets(engine: GameEngine) {
        #if DEBUG
        guard fillsGarage, autoAssetsTask == nil else { return }
        autoAssetsTask = Task { @MainActor in
            // Everything is bought in one moment, once the wallet can
            // carry the lot — so the clock stops immediately afterwards
            // and a screenshot is of a still frame rather than a run that
            // is still walking into decisions it cannot answer.
            let shoppingList = ["dog", "hatchback", "estate", "coupe"]
            let needed = 62_000
            // Set once the shopping is done: the clock stays stopped from
            // then on, but the loop keeps clearing modals so a question
            // raised on the last tick does not sit over the screenshot.
            var done = false
            while !Task.isCancelled, engine.state.gameOver == nil {
                try? await Task.sleep(for: .milliseconds(250))
                // A pass that runs for game-months walks into every modal
                // in the game; clear them the way the other passes do.
                GameShell.shared.pendingAwardsYear = nil
                GameShell.shared.launchDayProductID = nil
                if !done, engine.state.speed == .paused { engine.setSpeed(.x4) }
                if let prompt = DecisionPrompt.pending(
                    in: engine.state, content: engine.content, balance: engine.balance
                ), let option = prompt.options.first(where: { option in
                    guard option.disabledReason == nil else { return false }
                    // A pass that says yes to everything sells the company
                    // out from under itself — the same guard the
                    // sabbatical pass keeps.
                    switch option.action {
                    case .acceptBuyout, .acceptBuyoutEarnOut: return false
                    default: return true
                    }
                }) {
                    engine.send(option.action)
                }
                if engine.state.life.founderSalary < engine.balance.life.founderSalaryMax {
                    engine.send(.setFounderSalary(engine.balance.life.founderSalaryMax))
                }
                guard !done, engine.state.life.wallet >= needed else { continue }

                for id in shoppingList { engine.send(.buyAsset(assetID: id)) }
                engine.send(.tradeCrypto(dollars: 2000))
                engine.send(.buyLotteryTicket)
                for _ in 0..<4 { engine.send(.playCasinoGame(gameID: "blackjack", stake: 400)) }
                engine.setSpeed(.paused)
                done = true
            }
        }
        #endif
    }

    #if DEBUG
    @MainActor private static var autoAssetsTask: Task<Void, Never>?
    #endif

    // MARK: N4 (fame and the feed)

    /// `-autoFame`: the founder posts once a day for as long as the feed
    /// is on screen, so a headless pass has a feed to photograph and a
    /// follower count that means something.
    ///
    /// Debug only, and it drives the same `.postToFeed` action a thumb
    /// does — nothing here fabricates state the game could not reach on
    /// its own, so the screenshots are of the real curve.
    static var seedsFame: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-autoFame")
        #else
        return false
        #endif
    }

    /// `-autoCompose`: opens the compose sheet as soon as the feed is on
    /// screen. A headless pass cannot tap *Say something*, and the sheet —
    /// four kinds, each with its reach and its refusal — is half of what
    /// this lane looks like.
    static var opensFeedCompose: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-autoCompose")
        #else
        return false
        #endif
    }

    // MARK: N5 (office secrets)

    /// `-autoSecret <kind>`: the thread a headless pass wants a picture of.
    /// `SecretKind`'s raw value, case-insensitively ("mole", "romance",
    /// "embezzlement", "clique", "uniondrive", "coup").
    @MainActor
    static var requestedSecret: SecretKind? {
        guard let name = value(after: "-autoSecret")?.lowercased() else { return nil }
        return SecretKind.allCases.first { $0.rawValue.lowercased() == name }
    }

    /// Consumed once per launch, so a redraw does not start a second one.
    @MainActor private static var tookSecret = false

    /// Starts the asked-for thread, once, on whatever save is loaded.
    @MainActor
    static func startAutoSecret(engine: GameEngine) {
        #if DEBUG
        guard !tookSecret, let kind = requestedSecret else { return }
        tookSecret = true
        engine.send(.seedOfficeSecret(kind: kind.rawValue, stage: 2))
        #endif
    }

    // MARK: end of Iteration 11

    // MARK: Iteration 11, wave two — reserved flags

    // MARK: W1 (dirty money)

    // `-autoDirtyMoney <backer>` and `-autoDirtyMoneyTake` are read by
    // `DirtyMoneyDebug`, in the lane's own folder, the way `CrimeDebug`
    // carries N1's — the flags are here in name only so this file still
    // lists every one.

    // MARK: W2 (family drama)

    // `-autoFamily <stage>` lives with the lane, in
    // `Screens/Life/Family/FamilyDramaDebug.swift`, because it sends a real
    // action and needs the engine.

    // MARK: W3 (espionage)

    /// `-autoSpy <operation>`: the operation a headless pass wants a
    /// picture of, by `EspionageOperation` raw value, case-insensitively
    /// ("tailfounder", "placemole", "poachwithdirt", "buyroadmap",
    /// "hackstorefront").
    @MainActor
    static var requestedEspionage: EspionageOperation? {
        guard let name = value(after: "-autoSpy")?.lowercased() else { return nil }
        return EspionageOperation.allCases.first { $0.rawValue.lowercased() == name }
    }

    /// Consumed once per launch, so a redraw does not run a second one.
    @MainActor private static var tookEspionage = false

    /// Runs the asked-for operation, once, against the studio whose page
    /// is open — the same `.runEspionageOperation` a thumb sends, through
    /// the ordinary reducer, so a screenshot is of the real thing.
    @MainActor
    static func takeAutoEspionage(engine: GameEngine, rivalID: UUID) {
        #if DEBUG
        guard !tookEspionage, let operation = requestedEspionage else { return }
        tookEspionage = true
        engine.send(.runEspionageOperation(operation: operation, rivalID: rivalID))
        #endif
    }

    /// `-autoSpyCard`: lift the espionage card onto a sheet, because it
    /// sits below the fold of a long profile and a headless pass cannot
    /// scroll. Debug only.
    static var liftsEspionageCard: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-autoSpyCard")
        #else
        return false
        #endif
    }

    // MARK: W4 (inside)
    // Parsed in `InsideDebug`, next to the screens that read them:
    // `-autoInside <weeks>`, `-autoInsideDay <choice>`,
    // `-autoInsideGang join|refuse`, `-autoParole`,
    // `-autoParoleSay <exchange,exchange>` and `-autoEscape`. Nothing to
    // add here.

    // MARK: J1 (doors)
    // Parsed in `DoorDebug`, next to the sheet: `-autoRoute door` with
    // `-autoDoor shark|vices|fame|care` (opens that door today and lands
    // on it), `-autoDoorAnswer <choice>` (answers it once the sheet is
    // up), and `-autoTip <id>` (forces a coach tip's trigger on).
    // MARK: end J1
    // MARK: J2 (record)

    /// The founder's record, dressed for a screenshot, as the scenarios
    /// `GameAction.standingDebug` understands:
    ///
    /// - `-autoStanding <name>`: notoriety, mean acts on staff and firings
    ///   with cause enough for a name of about `<name>` (pair with
    ///   `-autoRoute hiring`).
    /// - `-autoBoardReview case`: a seated board, an open case and a beef,
    ///   then the quarterly review, run today (pair with
    ///   `-autoRoute investors`). `-autoBoardReview offer`: an open case
    ///   and a term sheet today, key-person clause and all.
    /// - `-autoSpotlight <level>`: fame at a level ("known" … "star"),
    ///   for the spotlight line (pair with `-autoRoute spy -autoSpyCard`).
    static var standingScenarios: [String] {
        var scenarios: [String] = []
        if let name = value(after: "-autoStanding") { scenarios.append("name \(name)") }
        if let review = value(after: "-autoBoardReview")?.lowercased() {
            scenarios.append(review == "offer" ? "offercase" : "boardcase")
        }
        if let level = value(after: "-autoSpotlight") { scenarios.append("spotlight \(level)") }
        return scenarios
    }

    /// Whether a J2 screenshot pass is running that wants the decision
    /// sheet held back: every J2 flag except `-autoBoardReview offer`,
    /// whose subject *is* the term-sheet prompt. Always false in release.
    static var standingHoldsDecisions: Bool {
        #if DEBUG
        let scenarios = standingScenarios
        return !scenarios.isEmpty && !scenarios.contains("offercase")
        #else
        return false
        #endif
    }

    /// `-autoBoardReview case` also lifts the board card onto a sheet: it
    /// sits below the fold of the cap table and a headless pass cannot
    /// scroll (W3's `-autoSpyCard`, for the same reason).
    static var standingLiftsBoardCard: Bool {
        #if DEBUG
        return standingScenarios.contains("boardcase")
        #else
        return false
        #endif
    }

    /// Sends each scenario until the state shows it. `current` is read on
    /// every attempt, the way `InsideDebug` reads it, and the test is the
    /// state rather than the engine: installing a fixture replaces the
    /// state a scenario was applied to. At most five sends a scenario.
    @MainActor
    static func startStandingIfAsked(current: @escaping () -> GameEngine) async {
        #if DEBUG
        let scenarios = standingScenarios
        guard !scenarios.isEmpty else { return }
        var sends: [String: Int] = [:]
        // An action lands on the engine's next turn, so a scenario is
        // given three seconds to show before it is sent again.
        var lastSent: [String: Int] = [:]
        for attempt in 0..<40 {
            let engine = current()
            if engine.state.gameOver == nil {
                for scenario in scenarios
                where !standingShows(scenario, engine: engine)
                    && sends[scenario, default: 0] < 5
                    && attempt - lastSent[scenario, default: -100] >= 10 {
                    engine.send(.standingDebug(scenario: scenario))
                    sends[scenario, default: 0] += 1
                    lastSent[scenario] = attempt
                }
            }
            try? await Task.sleep(for: .milliseconds(300))
        }
        #endif
    }

    /// Whether the state already shows a scenario.
    @MainActor
    private static func standingShows(_ scenario: String, engine: GameEngine) -> Bool {
        let state = engine.state
        let words = scenario.split(separator: " ").map(String.init)
        switch words.first {
        case "name":
            let target = min(100, Double(words.dropFirst().first ?? "40") ?? 40)
            return state.standingName(balance: engine.balance).score >= target - 0.5
        case "boardcase":
            return (state.investors.reviews.last?.founderQuarter ?? 0) > 0
        case "offercase":
            return state.investors.pendingOffer?.standingKeyPersonClause == true
        case "spotlight":
            return state.standingSpotlight(balance: engine.balance) > 1
        default:
            return true
        }
    }

    // MARK: end J2
    // MARK: J3 (rivals and the market)
    // Parsed in `RivalMarketDebug` (Screens/Business/RivalFight), started
    // from the app root's task: `-autoRivalMarket boom|crash`,
    // `-autoPriceWar` and `-autoCopied`. Nothing to add here.
    // MARK: end J3
    // MARK: J4 (house field)
    /// `-autoHouseField week|day` (bare: `week`): plays the house field for
    /// this week's tier, or today's daily, files a made-up finished year
    /// for the player between the house's ninth and tenth, and opens the
    /// League sheet (or today's card) on it — so the table and the
    /// "directly above you" line need no play-through. Launch it without
    /// `-autoSpeed`, which skips the front door. DEBUG only.
    static var houseFieldArgument: String? {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-autoHouseField") else { return nil }
        guard let value = value(after: "-autoHouseField"), !value.hasPrefix("-") else { return "week" }
        return value.lowercased() == "day" ? "day" : "week"
        #else
        return nil
        #endif
    }
    // MARK: end J4
    // MARK: J5 (announce)

    /// What `-autoAnnounce` asks `AnnounceDebug.start` to do on launch.
    enum AnnounceMode: String {
        /// Announce the war room's build (or the soonest build that can
        /// take a date) at the sheet's usual slack.
        case announce
        /// …then miss it once: the correction, the new date.
        case slip
        /// …then miss that too: the announcement is void.
        case void
    }

    /// `-autoAnnounce [slip|void]`. Debug builds only.
    static var autoAnnounceMode: AnnounceMode? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-autoAnnounce") else { return nil }
        let next = arguments.indices.contains(index + 1) ? arguments[index + 1].lowercased() : ""
        return AnnounceMode(rawValue: next) ?? .announce
        #else
        return nil
        #endif
    }

    /// `-autoPremium`: price the best-reviewed release premium on launch;
    /// with `-autoRoute premium`, land on its page, where the live-ops
    /// caption states what premium earns at its score.
    static var autoPremium: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-autoPremium")
        #else
        return false
        #endif
    }
    // MARK: end J5
    // MARK: J6 (queue)
    // Parsed in `QueueDebug` (`Components/QueuePrompts.swift`), started from
    // the root: `-autoQueue [eventID]` (a story and the confrontation, both
    // put off onto the rail), `-autoChild baby|toddler|school|teen|grown`,
    // `-autoCampus`, and `-autoStakes [eventID]` (the campus, a founder at
    // $5,000 a week and a story with money in it). Nothing to add here.
    // MARK: end J6
    // MARK: P1 (purchases: engine)

    /// `-autoPurchase cash4|cash13|second|veteran`: the purchase, applied
    /// through the ordinary reducer with a fake transaction id — no
    /// StoreKit — so a screenshot pass (P3) or a hand check lands on the
    /// granted state. Started from the root's task, so it needs a headless
    /// pass (`-autoTab …`): at the front door the root is not up yet.
    static var autoPurchaseKind: PurchaseKind? {
        #if DEBUG
        switch value(after: "-autoPurchase")?.lowercased() {
        case "cash4", "month": return .cash(weeks: 4)
        case "cash13", "quarter": return .cash(weeks: 13)
        case "second", "secondchance", "receiver": return .secondChance
        case "veteran": return .veteran
        default: return nil
        }
        #else
        return nil
        #endif
    }

    /// The fake id `-autoPurchase` sends. Fixed, so relaunching on a save
    /// that already took it shows the engine refusing a repeated id.
    static let autoPurchaseTransactionID: UInt64 = 0xDEB0_0000_0000_0001

    /// Waits up to a minute for `PurchaseRule` to allow the item (the
    /// receiver's call needs a bankruptcy, the veteran a pool), then sends
    /// it once. Logs `[P1] -autoPurchase …` with the outcome.
    @MainActor
    static func startAutoPurchase(engine: GameEngine) {
        #if DEBUG
        guard let kind = autoPurchaseKind, !autoPurchaseStarted else { return }
        autoPurchaseStarted = true
        Task { @MainActor in
            for _ in 0..<120 {
                if PurchaseRule.allows(kind, state: engine.state) {
                    let events = engine.send(
                        .applyPurchase(kind: kind, transactionID: autoPurchaseTransactionID)
                    )
                    print("[P1] -autoPurchase \(kind): \(events.isEmpty ? "refused (repeated id)" : "applied")")
                    return
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
            print("[P1] -autoPurchase \(kind): \(PurchaseRule.refusal(kind, state: engine.state) ?? "refused")")
        }
        #endif
    }

    #if DEBUG
    @MainActor private static var autoPurchaseStarted = false
    #endif
    // MARK: end P1
    // MARK: P2 (purchases: StoreKit and the session)
    /// `-autoShop <productID>`: one purchase through the scheme's store —
    /// the local `.storekit` file on the simulator — once the shop has
    /// loaded (`GameSession+Shop.swift`). The full id or its suffix
    /// (`cash.month`, `secondchance`, `veteran`, `slot4`, `decor.loft`).
    /// The pre-check is skipped, so on a build whose engine refuses the
    /// grant the transaction parks and the front door counts it.
    ///
    /// Fixture: `-autoFixture release-bankruptcy` installs a company one
    /// day from the bankruptcy ending into slot 0 (App Review, and the
    /// post-mortem's screenshot): continue and let one day run.
    static var autoShopProductID: String? {
        value(after: "-autoShop")
    }

    /// `-autoSlots`: the front door opens scrolled to the save slots, so
    /// the locked fourth row can be photographed without a swipe.
    static var scrollsDoorToSlots: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-autoSlots")
        #else
        return false
        #endif
    }

    /// `-autoPurchases`: with `-autoRoute settings`, the Purchases list
    /// opens over Settings.
    static var opensPurchases: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-autoPurchases")
        #else
        return false
        #endif
    }
    // MARK: end P2
    // MARK: P3 (purchases: surfaces and copy)
    /// `-autoShop`, or any of `-autoRoute shop|receiver|veteran|loftpack`:
    /// the shop surfaces read `ShopSurfacePreview` (the spec's US prices)
    /// when no store is injected. See `ShopSurfaceDebug`.
    static var autoShop: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-autoShop")
            || autoRouteName.map(ShopSurfaceDebug.routes.contains) == true
        #else
        return false
        #endif
    }

    /// `-autoShopOwned`: the preview store owns the loft pack; with
    /// `-autoRoute loftpack` its six items are placed in the room.
    static var autoShopOwned: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-autoShopOwned")
        #else
        return false
        #endif
    }

    /// `-autoShopGrants`: with `-autoRoute receiver`, the scratch bankrupt
    /// copy carries two cash grants, and the pass lands on the biography's
    /// "Bought in" line instead of the receiver's call.
    static var autoShopGrants: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-autoShopGrants")
        #else
        return false
        #endif
    }
    // MARK: end P3
    // MARK: U1 (ux: the first-hour fixes)
    /// `-autoSheetMedium`: every decision sheet opens at its half-height
    /// detent, even one that would open full (C4), so a headless pass can
    /// photograph the question where the drag would leave it.
    static var opensSheetsAtMedium: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-autoSheetMedium")
        #else
        return false
        #endif
    }

    /// `-autoMoreWays`: the front door opens its More ways to play sheet;
    /// `-autoSaves`: the front door shows its slots. Neither can be tapped
    /// by a headless pass (C9).
    static var opensMoreWays: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-autoMoreWays")
        #else
        return false
        #endif
    }

    static var opensSaves: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-autoSaves")
        #else
        return false
        #endif
    }
    // MARK: end U1
    // MARK: V1 (ux: Life folded, rooms dormant)
    /// `-autoLifeOffset <points>`: Life's root content starts that many
    /// points further up, so a headless pass can photograph below the
    /// fold (`simctl` cannot scroll). Zero without the flag.
    static var lifeOffset: CGFloat {
        #if DEBUG
        return CGFloat(UserDefaults.standard.double(forKey: "autoLifeOffset"))
        #else
        return 0
        #endif
    }

    /// `-autoLifeFolds open|closed`: every fold on Life (sections, room
    /// rows, the other rooms) open or closed for this launch, whatever
    /// the install remembers. `nil` without the flag.
    static var lifeFolds: Bool? {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "autoLifeFolds") {
        case "open": return true
        case "closed": return false
        default: return nil
        }
        #else
        return nil
        #endif
    }
    // MARK: end V1
    // MARK: V2 (ux: one inbox, one home per thing)
    /// `-autoWaiting`: "Waiting on you" opens a few seconds in, and the
    /// inbox, the desk and the morning papers are printed side by side
    /// (the lane's measurement).
    static var opensWaiting: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-autoWaiting")
        #else
        return false
        #endif
    }

    /// `-autoReopenReport`: the latest closed week's report opens again a
    /// few seconds in, as the inbox's footer and the journal would.
    static var reopensReport: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-autoReopenReport")
        #else
        return false
        #endif
    }
    // MARK: end V2
    // MARK: V3 (ux: card weights, the Now card)
    // MARK: end V3
    // MARK: K1 (founder money)
    /// `-autoFounderMoney loan|dividend|paid|rescue`: the seed
    /// `FounderMoneyDebug` sends a beat after launch. `nil` in release.
    static var founderMoneySeed: String? {
        #if DEBUG
        return value(after: "-autoFounderMoney")
        #else
        return nil
        #endif
    }
    // MARK: end K1
    // MARK: K2 (product lifecycle)
    /// `-autoRoute k2-<scenario>` (with `-autoTab products` and a fixture):
    /// the lifecycle's surfaces, dressed by `LifecycleDebug`. The scenario
    /// word without its prefix, `nil` otherwise and in release builds.
    static var lifecycleScenario: String? {
        #if DEBUG
        guard let name = autoRouteName, name.hasPrefix("k2-") else { return nil }
        return String(name.dropFirst(3))
        #else
        return nil
        #endif
    }
    // MARK: end K2
    // MARK: K3 (the ladder)
    /// `-autoLadder`: the loaded company gets a promoted lead on every
    /// build and options for two people (`LadderDebug`), once.
    static var ladderDresses: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-autoLadder")
        #else
        return false
        #endif
    }
    // MARK: end K3
    // MARK: K4 (deals and exits)
    /// `-autoDeal list|<ask>`: the for-sale sign goes up once the Rivals
    /// segment is on screen (`DealDebug`), at 1.3× or the ask given.
    static var dealAutoAsk: String? {
        #if DEBUG
        return value(after: "-autoDeal")
        #else
        return nil
        #endif
    }
    // MARK: end K4
    // MARK: K5 (hand over the keys)

    /// `-autoRoute k5keys`: Life's score screen with the hand-over sheet
    /// open. `-autoRoute k5after` (or `-k5HandOver` with any other route):
    /// the company handed to the best successor, keeping a quarter, a
    /// moment after launch. Both prepare the `-autoFixture` first
    /// (`k5Prepared`), because no bundled fixture passes the gates as it
    /// ships: every campus save has a seated board and nobody at bond 50.
    static var opensHandOverSheet: Bool { autoRouteName == "k5keys" }

    static var handsOverOnLaunch: Bool {
        #if DEBUG
        return autoRouteName == "k5after" || ProcessInfo.processInfo.arguments.contains("-k5HandOver")
        #else
        return false
        #endif
    }

    static var preparesHandOver: Bool {
        opensHandOverSheet || handsOverOnLaunch || autoRouteName == "k5card"
    }

    /// Every K5 pass lands scrolled to the Walking-away card, where the two
    /// doors are; `k5shut` is the shipped fixture, unprepared, with the
    /// door shut by its board.
    static var k5ScrollsToWalkAway: Bool {
        ["k5keys", "k5after", "k5card", "k5shut"].contains(autoRouteName ?? "")
    }

    /// The fixture with its seated rounds bought out for nothing and its
    /// longest-serving person at bond 60 — the preparation K5's
    /// measurement used (`iteration-15-lanes/k5.md`). Screenshot passes
    /// only; the save a player has is never touched by it.
    static func k5Prepared(_ start: GameState) -> GameState {
        var state = start
        let seated = state.investors.rounds.filter(\.takesBoardSeat)
        state.investors.rounds.removeAll(where: \.takesBoardSeat)
        for var round in seated {
            round.boughtOutDay = state.day
            round.buybackPrice = 0
            state.investors.boughtOut.append(round)
            state.investors.equityRemaining = min(100, state.investors.equityRemaining + round.equity)
        }
        state.investors.boardPressure = 0
        let staff = state.employees.indices.filter { !state.employees[$0].isFounder }
        if let longest = staff.min(by: { state.employees[$0].hiredDay < state.employees[$1].hiredDay }) {
            state.employees[longest].founderBond = max(state.employees[longest].founderBond, 60)
        }
        return state
    }
    // MARK: end K5
    // MARK: K6 (home and rooms)
    /// K6's launch flags, applied once the Home card appears. Each sends the
    /// real action, so a refused one (already there, on cooldown) is a
    /// no-op and a relaunch is harmless:
    /// - `-autoK6Home <district>`: `.moveHome` there (wallet and evening paid);
    /// - `-autoK6Holiday`: `.planFamilyHoliday`;
    /// - `-autoK6Break <amenity>`: `.callBreak` in it.
    /// The routes are read as strings by the cards themselves:
    /// `-autoRoute k6-move` (the move sheet), `k6-today` (the Today sheet),
    /// `k6-break` (the amenities sheet from the office card). Debug only.
    @MainActor
    static func startK6(engine: GameEngine) {
        #if DEBUG
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: "autoK6Home"), let district = DistrictID(rawValue: raw) {
            _ = engine.send(.moveHome(district: district))
        }
        if ProcessInfo.processInfo.arguments.contains("-autoK6Holiday") {
            _ = engine.send(.planFamilyHoliday)
        }
        if let raw = defaults.string(forKey: "autoK6Break"), let amenity = Amenity(rawValue: raw) {
            _ = engine.send(.callBreak(amenity: amenity))
        }
        #endif
    }
    // MARK: end K6
    // MARK: K7 (partner and diary)
    // MARK: end K7
    // MARK: end of Iteration 15
    // MARK: end of Iteration 14
    // MARK: end of Iteration 13
    // MARK: end of Iteration 12
    // MARK: end of Iteration 11, wave two

    // MARK: S4 (city)
    /// `-autoCityDistrict <district>`: the city map opens with this
    /// district's panel up (and scrolled to it), for the panel shots.
    static var launchCityDistrict: DistrictID? {
        value(after: "-autoCityDistrict").flatMap { raw in
            DistrictID.allCases.first { $0.rawValue.lowercased() == raw.lowercased() }
        }
    }

    /// `-autoCityFocus <office|home|rival|venue|hospital|courthouse|school|former>`:
    /// the map opens with that thing's name plate up.
    static var launchCityFocus: String? { value(after: "-autoCityFocus")?.lowercased() }

    /// `-autoCity <dressing>`: dresses the `-autoFixture` save before it is
    /// installed so one screenshot shows every place the map can hold.
    /// `rich`: a hospital stay, a settled case, a relocation (so an old
    /// office stands to let) and a rooftop party open tonight. Screenshot
    /// passes only; a player's save is never touched by it.
    static var launchCityDressing: String? { value(after: "-autoCity")?.lowercased() }

    static func cityDressed(_ start: GameState, _ dressing: String) -> GameState {
        guard dressing == "rich" else { return start }
        var state = start
        let day = state.day
        if state.economy.hospitalizationDays.isEmpty {
            state.economy.hospitalizationDays.append(max(0, day - 40))
        }
        if state.crime.cases.isEmpty, let offence = CrimeOffence.allCases.first {
            state.crime.cases.append(LegalCase(
                id: "s4-city-dressing", kind: offence.rawValue,
                raisedDay: max(0, day - 70), hearingDay: max(0, day - 50),
                verdict: .acquitted, settledDay: max(0, day - 50)
            ))
        }
        if state.cityFormerOfficeDistrict == nil {
            let current = state.city.district
            let former = DistrictID.allCases.first { $0 != current && $0 != .oldTown } ?? .midtown
            state.eventLog.append(.officeRelocated(district: former, day: max(0, day - 120)))
            state.eventLog.append(.officeRelocated(district: current, day: max(0, day - 20)))
        }
        if state.networking.pendingEvent == nil {
            state.networking.pendingEvent = NetworkingEvent(
                venue: .rooftopParty, day: day, expiresOnDay: day + 2,
                contactIDs: Array(state.networking.contacts.prefix(5).map(\.id)), conversationsLeft: 3
            )
        }
        return state
    }
    // MARK: end S4

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
