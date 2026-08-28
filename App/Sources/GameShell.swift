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
    var showingWeeklyReport = false
    /// The report being shown.
    private(set) var report: WeeklyReport?
    /// Speed to restore when the player taps "Next week".
    private(set) var resumeSpeed: SimSpeed = .x1

    /// A product that just shipped and hasn't had its launch-day moment.
    var launchDayProductID: UUID?

    /// Last report's figures, for this report's deltas.
    @ObservationIgnored private var previousMorale: Double?
    @ObservationIgnored private var previousMeters: WeeklyReport.MeterSnapshot?
    /// The most recent week already offered, so the chip appears once.
    @ObservationIgnored private var lastOfferedWeek = 0
    /// The run's day the shell last saw, to detect week boundaries.
    @ObservationIgnored private var lastSeenDay = -1

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
    func dayAdvanced(engine: GameEngine) {
        let day = engine.state.day
        defer { lastSeenDay = day }
        guard day > lastSeenDay, lastSeenDay >= 0 else { return }
        guard day % 7 == 0, day > 0 else { return }

        let week = day / 7
        guard week > lastOfferedWeek else { return }
        lastOfferedWeek = week
        pendingReportWeek = week
        Sounds.play(.weekEnd)

        // Auto-open only in the early game, only at a speed where the
        // player is watching, and never on top of another pause reason.
        let autoOpen = GameSettings.weeklyReportAuto
            && week <= Self.autoOpenWeeks
            && engine.state.speed != .paused
            && engine.lastPauseEvents.isEmpty
        if autoOpen {
            openWeeklyReport(engine: engine)
        }
    }

    /// Builds and presents the weekly report, pausing the clock behind it.
    func openWeeklyReport(engine: GameEngine) {
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
        previousMorale = nil
        previousMeters = nil
    }
}
