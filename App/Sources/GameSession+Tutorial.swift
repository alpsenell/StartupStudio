import Foundation
import TycoonEngine

// MARK: Iteration 7 — the first hour (R1)

/// What the shell tells the tour. `GameShell` sees the day change, the
/// events land, and its own sheets close; the tour is the only listener.
@MainActor
protocol TutorialShellObserver: AnyObject {
    /// Whether the tour wants week `week`'s report to open itself, whatever
    /// the manual-opens rule says.
    func tourWantsReportOpened(week: Int) -> Bool
    func tourDayAdvanced(engine: GameEngine)
    func tourEventsChanged(engine: GameEngine)
    func tourSaw(_ event: TutorialShellEvent)
}

/// The tour's owner. `tutorial` is the scaffold's stored property; this
/// file is where it starts, moves, persists and ends.
///
/// The tour starts only for the first company on a fresh install
/// (`TutorialEligibility`), resumes from `UserDefaults` for the slot it
/// was on, and is never shown to a headless pass unless `-autoTour`
/// asked for a beat. Skipping counts as completing: the flag is written,
/// the six coach tips are dismissed, and no later company sees it.
extension GameSession: TutorialShellObserver {
    /// The store the tour persists in. Tests swap it for a suite instance
    /// through `GameSession.tutorialStore`.
    private var tourStore: TutorialStore { Self.tutorialStore }

    /// Whether the tour could start for the engine's current game.
    var canStartTour: Bool {
        TutorialEligibility.canStart(
            tutorialCompleted: GameSettings.tutorialCompleted,
            slots: slots,
            currentSlot: currentSlot,
            ledger: ledger,
            state: engine.state
        )
    }

    /// Called by the root whenever the live engine changes — a company
    /// founded, a save continued — with the shell that will report to
    /// the tour. Decides between resuming, starting, landing on a debug
    /// beat, and staying out of the way.
    func tourEngineChanged(shell: GameShell) {
        shell.tour = self
        let state = engine.state

        if let beat = DebugLaunch.launchTourBeat {
            // A screenshot pass lands on the beat it asked for, without
            // touching what a real install would persist.
            tutorial = TutorialProgress(step: beat, openTabs: TutorialScript.tabsOpen(through: beat))
        } else if DebugLaunch.isHeadlessPass || GameSettings.tutorialCompleted {
            tutorial = nil
        } else if let saved = tourStore.load(slot: currentSlot), tourStore.matches(saved, state: state) {
            tutorial = TutorialProgress(step: saved.step, openTabs: TutorialScript.tabsOpen(through: saved.step))
        } else if canStartTour {
            tutorial = TutorialProgress()
            persistTour()
        } else {
            tutorial = nil
        }

        if tutorial != nil {
            observeEvents("tour") { [weak self] _ in self?.evaluateTour() }
            evaluateTour()
        } else {
            stopObservingEvents("tour")
        }
    }

    /// The card's *Next*, and the welcome's four seconds: moves on from
    /// `step` if the tour is still on it.
    func advanceTour(from step: TutorialStep) {
        guard var progress = tutorial, !progress.isComplete, progress.step == step else { return }
        guard let next = step.next else {
            completeTour()
            return
        }
        progress.step = next
        tutorial = progress
        evaluateTour()
    }

    /// *Skip the tour*: ends it and opens everything.
    func skipTour() {
        completeTour()
    }

    /// A tab the player reached by a route before the tour introduced it
    /// is open from then on; the bar can never show a selection it does
    /// not draw.
    func tourReached(_ tab: GameTab) {
        guard var progress = tutorial, !progress.isComplete, !progress.openTabs.contains(tab) else { return }
        progress.openTabs.insert(tab)
        tutorial = progress
    }

    /// Re-reads the state against the current beat: every beat whose
    /// predicate is already met is passed (a player who hired before the
    /// tour asked is not sent back to do it), the tabs are opened through
    /// the beat reached, and the ship beat's silence is decided.
    func evaluateTour() {
        guard var progress = tutorial, !progress.isComplete else { return }
        let state = engine.state
        var step = progress.step
        while TutorialScript.isDone(step, state: state) {
            guard let next = step.next else {
                completeTour()
                return
            }
            step = next
        }
        progress.step = step
        progress.openTabs.formUnion(TutorialScript.tabsOpen(through: step))
        progress.isDormant = DebugLaunch.launchTourBeat == nil
            && TutorialScript.isDormant(step, state: state, balance: engine.balance, content: engine.content)
        if progress != tutorial {
            tutorial = progress
            persistTour()
        }
    }

    /// Completion and skip are the same exit: the flag, the tips the
    /// beats already said, the slot's bookmark gone, every tab open.
    private func completeTour() {
        guard var progress = tutorial, !progress.isComplete else { return }
        progress.isComplete = true
        progress.isDormant = false
        progress.openTabs = TutorialScript.allTabs
        tutorial = progress
        GameSettings.tutorialCompleted = true
        GameSettings.dismissedTips = GameSettings.dismissedTips.union(CoachTip.all.map(\.id))
        if DebugLaunch.launchTourBeat == nil {
            tourStore.clear(slot: currentSlot)
        }
        stopObservingEvents("tour")
    }

    private func persistTour() {
        guard let progress = tutorial, !progress.isComplete, DebugLaunch.launchTourBeat == nil else { return }
        tourStore.save(
            TutorialStore.Saved(step: progress.step, seed: engine.state.seed, day: engine.state.day),
            slot: currentSlot
        )
    }

    // MARK: - TutorialShellObserver

    func tourWantsReportOpened(week: Int) -> Bool {
        guard let progress = tutorial, !progress.isComplete else { return false }
        return progress.step == .readTheWeek && week == 1
    }

    func tourDayAdvanced(engine: GameEngine) {
        guard engine === self.engine else { return }
        evaluateTour()
    }

    func tourEventsChanged(engine: GameEngine) {
        guard engine === self.engine else { return }
        evaluateTour()
    }

    func tourSaw(_ event: TutorialShellEvent) {
        guard let progress = tutorial, !progress.isComplete,
              TutorialScript.isDone(progress.step, after: event)
        else { return }
        advanceTour(from: progress.step)
    }
}

extension GameSession {
    /// Where the tour's per-slot bookmark lives. `UserDefaults.standard`
    /// for the app; a test suite points it at its own domain.
    static var tutorialStore = TutorialStore()
}
