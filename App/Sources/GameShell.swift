import Observation
import SwiftUI
import TycoonEngine

/// The cross-cutting UI state that sits above the tabs: the toast queue,
/// the weekly-report loop, and the launch-day moment.
///
/// It exists so the acknowledgement layer has exactly one owner. The tabs
/// each attach their own HUD, but they all read this, so a toast never
/// double-fires and the weekly report is offered once per week no matter
/// which tab the player is on.
@MainActor
@Observable
final class GameShell {
    /// Toasts for actions and events.
    let toasts = ToastCenter()

    /// The week whose report is waiting to be read, if any. The HUD shows
    /// a chip for it; opening the sheet clears it.
    private(set) var pendingReportWeek: Int?
    /// Set while the weekly report sheet is up.
    var showingWeeklyReport = false {
        didSet {
            // Iteration 7 (R1): the tour's "read the week" beat ends when
            // the report closes.
            if oldValue, !showingWeeklyReport { tour?.tourSaw(.reportDismissed) }
        }
    }
    /// The report being shown.
    private(set) var report: WeeklyReport?
    /// Speed to restore when the player taps "Next week".
    private(set) var resumeSpeed: SimSpeed = .x1

    /// A product that just shipped and hasn't had its launch-day moment.
    var launchDayProductID: UUID? {
        didSet {
            // Iteration 7 (R1): the tour's last beat ends when the player
            // has read the reviews and closed launch day.
            if oldValue != nil, launchDayProductID == nil { tour?.tourSaw(.launchDayDismissed) }
        }
    }

    /// Iteration 7 (R1): the tour, while a fresh install is on it. The
    /// shell reports the day, the events and its own sheets closing; the
    /// session decides what the tour does with them.
    weak var tour: (any TutorialShellObserver)?

    /// Iteration 4 seam. The `DecisionPrompt.id` of a narrative choice the
    /// player deferred with "Let me think": while set, the root does not
    /// re-present that sheet and the clock is allowed to run; the notice
    /// rail shows the choice with its real countdown, and tapping it calls
    /// `recallDeferredChoice()` to bring the sheet back. WS-D sets it,
    /// WS-A reads it. Cleared on every engine swap.
    var deferredChoiceID: String?

    /// Brings a deferred decision sheet back.
    func recallDeferredChoice() {
        if let id = deferredChoiceID { deferredQueueIDs.remove(id) } // J6 (queue)
        deferredChoiceID = nil
    }

    // MARK: J6 (queue)

    /// Iteration 12 — J6. Every question put off, by its prompt's id — a
    /// story beat, an offer, a notice, a string, the confrontation. The
    /// root presents none of them; the rail carries each with its real
    /// deadline, and its button brings the one it names back.
    /// `deferredChoiceID` stays the most recent of them for the readers
    /// that predate the queue (the HUD's attention dot).
    var deferredQueueIDs: Set<String> = []

    /// Whether the question behind `promptID` is waiting on the rail.
    func isDeferred(_ promptID: String) -> Bool {
        deferredQueueIDs.contains(promptID) || promptID == deferredChoiceID
    }

    /// Brings one deferred question back to the root.
    func recall(promptID: String) {
        deferredQueueIDs.remove(promptID)
        if deferredChoiceID == promptID { deferredChoiceID = nil }
    }

    /// The engine let a stop through past the week's two (`QueueCap`): the
    /// questions go straight to the rail, as if "Let me think" had been
    /// said for each, and the clock keeps the speed it had.
    func holdForCap(_ prompts: [DecisionPrompt]) {
        for prompt in prompts where prompt.isDeferrable && !isDeferred(prompt.id) {
            deferredQueueIDs.insert(prompt.id)
            deferredChoiceID = prompt.id
        }
    }

    // MARK: end J6

    // MARK: Iteration 9 — L1 (phone)

    /// `-autoDeferBeats`: a headless pass defers every deferrable story
    /// beat instead of showing its sheet, so the question can be
    /// photographed where the phone answers it. Debug only; no release
    /// build has the flag.
    /// `-autoDeferBeats` also keeps the modal off a screenshot pass
    /// entirely, so the thread's own reply buttons are what gets
    /// photographed. Debug only.
    static var headlessPassAnswersOnThePhone: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-autoDeferBeats")
        #else
        return false
        #endif
    }

    func deferBeatIfHeadless(_ prompt: DecisionPrompt, engine: GameEngine) {
        #if DEBUG
        guard prompt.isDeferrable, !isDeferred(prompt.id), // J6 (queue)
              ProcessInfo.processInfo.arguments.contains("-autoDeferBeats")
        else { return }
        postpone(prompt, engine: engine)
        #endif
    }

    // MARK: end L1

    /// The speed the clock was last running at, so a deferred question
    /// resumes the game at the pace the player had set — the engine
    /// forgets it when an event pauses the tick.
    private(set) var lastRunningSpeed: SimSpeed = .x1

    /// "Let me think": closes a deferrable prompt, puts it on the notice
    /// rail with its real countdown, and starts the clock again.
    func postpone(_ prompt: DecisionPrompt, engine: GameEngine) {
        guard prompt.isDeferrable else { return }
        deferredQueueIDs.insert(prompt.id) // J6 (queue)
        deferredChoiceID = prompt.id
        engine.setSpeed(lastRunningSpeed == .paused ? .x1 : lastRunningSpeed)
        Haptics.tap()
    }

    /// Last report's figures, for this report's deltas.
    @ObservationIgnored private var previousMorale: Double?
    @ObservationIgnored private var previousMeters: WeeklyReport.MeterSnapshot? {
        didSet { weekStartMeters = previousMeters }
    }
    /// The founder's meters as they stood when the current week began —
    /// the last report's snapshot — so the Life tab can show each meter's
    /// change this week beside it. Observed, unlike the private copy.
    private(set) var weekStartMeters: WeeklyReport.MeterSnapshot?
    /// The most recent week already offered, so the chip appears once.
    @ObservationIgnored private var lastOfferedWeek = 0
    /// The run's day the shell last saw, to detect week boundaries.
    @ObservationIgnored private var lastSeenDay = -1

    /// The app's one shell.
    ///
    /// `AppRootView` owns it and puts it in the environment, which is how
    /// every screen should reach it. The shared instance exists because
    /// SwiftUI updates a modally-presented view's `@Environment` dynamic
    /// properties *before* the presentation's environment is installed,
    /// and a non-optional `@Environment(GameShell.self)` traps at that
    /// moment rather than waiting for `body`. Reading it optionally with
    /// this as the fallback is correct rather than defensive: there is
    /// exactly one shell for an app run either way.
    @MainActor static let shared = GameShell()

    init() {
        // Every fresh batch of events flows through the toast center;
        // this is where the shell picks the ones that deserve a sheet.
        toasts.onFreshEvents = { [weak self] events in
            self?.noteMoments(in: events)
        }
    }

    /// Weeks for which the report opens itself (when the setting is on).
    /// After this the chip is still offered, but the game stops
    /// interrupting a player who has learned the loop.
    static let autoOpenWeeks = 8

    /// Called on every observed change of the engine's day. Detects the
    /// week boundary and offers the report.
    /// Iteration 8: the year whose ceremony is waiting to be shown.
    var pendingAwardsYear: Int?

    func dayAdvanced(engine: GameEngine) {
        let day = engine.state.day
        defer { lastSeenDay = day }
        // Iteration 8: mid-December, the year's awards. Only on a day the
        // clock actually crossed, never on a resumed save's first frame.
        if lastSeenDay >= 0, day > lastSeenDay {
            let year = AwardsJudge.year(of: day)
            let ceremony = AwardsJudge.ceremonyDay(year: year)
            if lastSeenDay < ceremony, day >= ceremony, pendingAwardsYear == nil {
                pendingAwardsYear = year
            }
        }
        if engine.state.speed != .paused {
            lastRunningSpeed = engine.state.speed
        }
        // Iteration 7 (R1): the tour reads the day before the report
        // decision below, so "run the clock" is over by the time week 1
        // asks whether the tour wants its report opened.
        tour?.tourDayAdvanced(engine: engine)
        guard day > lastSeenDay, lastSeenDay >= 0 else { return }
        guard day % 7 == 0, day > 0 else { return }

        let week = day / 7
        guard week > lastOfferedWeek else { return }
        lastOfferedWeek = week
        pendingReportWeek = week
        Sounds.play(.weekEnd)

        // Auto-open only in the early game, only at a speed where the
        // player is watching, and never on top of another pause reason.
        // A headless QA pass has nobody to press "Next week", and the
        // report holds the clock until somebody does — three minutes of
        // wall time got nine game days before this. Players are unaffected.
        // ...and only until the player has opened the report from the rail
        // twice on their own, which is the point at which they have
        // learned the loop and the interruption stops earning its place.
        let autoOpen = GameSettings.weeklyReportAuto && !DebugLaunch.isHeadlessPass
            && week <= Self.autoOpenWeeks
            && GameSettings.weeklyReportManualOpens < 2
            && engine.state.speed != .paused
            && engine.lastPauseEvents.isEmpty
        // Iteration 7 (R1): the tour's "read the week" beat opens week
        // 1's report whatever the manual-opens counter says — the
        // counter itself is untouched.
        let tourOpen = !DebugLaunch.isHeadlessPass
            && tour?.tourWantsReportOpened(week: week) == true
            && engine.state.speed != .paused
            && engine.lastPauseEvents.isEmpty
        if autoOpen || tourOpen {
            openWeeklyReport(engine: engine, byHand: false)
        }
    }

    /// Builds and presents the weekly report, pausing the clock behind it.
    /// `byHand` is the rail's tap; the auto-open passes `false`.
    func openWeeklyReport(engine: GameEngine, byHand: Bool = true) {
        if byHand { GameSettings.weeklyReportManualOpens += 1 }
        let built = WeeklyReport(
            state: engine.state,
            balance: engine.balance,
            weeklyBurn: engine.weeklyBurn,
            previousMorale: previousMorale,
            previousMeters: previousMeters
        )
        previousMorale = built.averageMorale
        previousMeters = built.founderMeters
        report = built
        resumeSpeed = engine.state.speed == .paused ? .x1 : engine.state.speed
        engine.setSpeed(.paused)
        pendingReportWeek = nil
        showingWeeklyReport = true
        Haptics.commit()
    }

    /// Announces whatever a tick appended to the event log, and picks up
    /// the moments that get a sheet of their own.
    func eventsChanged(engine: GameEngine) {
        toasts.announceNewEvents(
            in: engine.state,
            copy: EventCopy(state: engine.state, content: engine.content, balance: engine.balance)
        )
        // Iteration 7 (R1): a hire, a product, a contract — the tour's
        // beats end on what the log just gained.
        tour?.tourEventsChanged(engine: engine)
    }

    /// Picks the events that get a sheet rather than a toast.
    private func noteMoments(in events: [GameEvent]) {
        for event in events {
            // Both halves of launch day open the same sheet: the ship
            // itself, and the reviews a week later (which is why
            // `.reviewsIn` needs no pause banner of its own).
            switch event {
            case .shipped(let productID, _), .reviewsIn(let productID, _, _):
                launchDayProductID = productID
            default:
                break
            }
        }
    }

    /// Re-baselines everything after an engine swap (new game, resumed
    /// save), so history never replays as toasts or reports.
    func rebase(to engine: GameEngine) {
        toasts.resetBaseline(to: engine.state)
        lastSeenDay = engine.state.day
        lastOfferedWeek = engine.state.day / 7
        pendingReportWeek = nil
        launchDayProductID = nil
        deferredChoiceID = nil
        deferredQueueIDs = [] // J6 (queue)
        previousMorale = nil
        previousMeters = nil
    }
}
