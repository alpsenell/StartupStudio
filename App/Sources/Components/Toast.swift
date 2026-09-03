import Observation
import SwiftUI
import TycoonEngine

/// One transient acknowledgement: an icon, a sentence, and a tint.
struct Toast: Identifiable, Equatable {
    let id: Int
    let icon: String
    let message: String
    let tint: Color
    let severity: EventSeverity

    static func == (lhs: Toast, rhs: Toast) -> Bool { lhs.id == rhs.id }
}

/// The app's acknowledgement layer.
///
/// Everything the player does, and everything the world does back, passes
/// through here: an action they sent, an event a tick produced. Toasts
/// stack up to three, live 2.5 seconds, and carry the haptic and the blip
/// that match their severity — so no action in the game is ever silent.
@MainActor
@Observable
final class ToastCenter {
    /// Visible toasts, oldest first.
    private(set) var toasts: [Toast] = []

    /// How long a toast stays on screen.
    static let lifetime: Duration = .milliseconds(2500)
    /// The most toasts shown at once; older ones are dropped.
    static let maxVisible = 3

    /// Called with every batch of fresh events, whoever noticed them —
    /// a tick or a player action. `GameShell` uses it to catch the moments
    /// that open a sheet, so a manually shipped product still gets its
    /// launch day even though `send(_:to:)` consumed the events first.
    @ObservationIgnored var onFreshEvents: (([GameEvent]) -> Void)?

    @ObservationIgnored private var nextID = 0
    /// Events already turned into a toast, so a redraw never re-announces
    /// the same tick.
    @ObservationIgnored private var lastAnnouncedEventCount = 0

    /// Shows a toast the player's own action produced. `severity` picks
    /// the haptic and the sound.
    func show(
        _ message: String,
        icon: String = "checkmark.circle.fill",
        tint: Color = Theme.accent,
        severity: EventSeverity = .info
    ) {
        push(Toast(id: nextID, icon: icon, message: message, tint: tint, severity: severity))
    }

    /// Announces the events a tick or an action produced, skipping
    /// anything the player will see in a sheet instead.
    ///
    /// - Parameters:
    ///   - events: the newest events, oldest first.
    ///   - copy: the shared event-to-English mapper.
    func announce(_ events: [GameEvent], copy: EventCopy) {
        let announced = events.filter { shouldToast($0) }
        for event in announced {
            let line = copy.line(for: event)
            push(
                Toast(
                    id: nextID,
                    icon: line.icon,
                    message: line.message,
                    tint: line.tint,
                    severity: event.severity
                ),
                silent: true
            )
        }
        // One buzz and one blip per batch, at the loudest severity in it:
        // a busy tick should not fire five haptics in a row.
        guard let loudest = announced.map(\.severity).max(by: { rank($0) < rank($1) }) else {
            return
        }
        Haptics.play(severity: loudest)
        Sounds.play(severity: loudest)
    }

    private func rank(_ severity: EventSeverity) -> Int {
        switch severity {
        case .quiet: 0
        case .info: 1
        case .notable: 2
        case .critical: 3
        }
    }

    /// Announces only the events appended to `state.eventLog` since the
    /// last call, and returns them.
    ///
    /// This is the single place the app decides "what is new" — the root
    /// view's per-tick observation and `send(_:to:)` both go through it,
    /// so an event is never announced twice or missed.
    @discardableResult
    func announceNewEvents(in state: GameState, copy: EventCopy) -> [GameEvent] {
        let log = state.eventLog
        // The baseline is re-set on every engine swap (`resetBaseline`),
        // so a resumed save never dumps its whole backlog on screen.
        guard log.count > lastAnnouncedEventCount else {
            lastAnnouncedEventCount = log.count
            return []
        }
        let fresh = Array(log.suffix(log.count - lastAnnouncedEventCount))
        lastAnnouncedEventCount = log.count
        onFreshEvents?(fresh)
        // An event that stopped the clock is the notice rail's pause
        // reason already; announcing it again would say the same thing
        // twice in the same 60pt.
        let pausing = state.economy.pauseEvents
        announce(fresh.filter { !pausing.contains($0) }, copy: copy)
        return fresh
    }

    /// Re-baselines after an engine swap so a resumed or brand-new game
    /// doesn't replay its history as toasts.
    func resetBaseline(to state: GameState) {
        lastAnnouncedEventCount = state.eventLog.count
    }

    /// Events that get a full sheet or a banner of their own; a toast on
    /// top of those is noise. `.rivalShipped` is the topic-level twin of
    /// `.rivalProductLaunched`, which names the product and its score —
    /// one launch, one line.
    private func shouldToast(_ event: GameEvent) -> Bool {
        switch event {
        case .shipped, .reviewsIn, .gameOver, .companySold,
             .poachAttempt, .buyoutOffered, .staffEventOccurred,
             .rivalShipped:
            false
        default:
            event.severity != .quiet
        }
    }

    private func push(_ toast: Toast, silent: Bool = false) {
        nextID += 1
        withAnimation(Theme.Motion.weighted) {
            toasts.append(toast)
            if toasts.count > Self.maxVisible {
                toasts.removeFirst(toasts.count - Self.maxVisible)
            }
        }
        if !silent {
            Haptics.play(severity: toast.severity)
            Sounds.play(severity: toast.severity)
        }
        let id = toast.id
        Task { [weak self] in
            try? await Task.sleep(for: Self.lifetime)
            self?.dismiss(id)
        }
    }

    private func dismiss(_ id: Int) {
        withAnimation(Theme.Motion.exit) {
            toasts.removeAll { $0.id == id }
        }
    }
}

// MARK: - Sending actions

extension ToastCenter {
    /// Sends a player action and acknowledges it.
    ///
    /// This is the only way the UI should reach the engine: it diffs the
    /// event log around `engine.send`, announces whatever the action
    /// produced, and — when the reducer produced nothing visible (a focus
    /// change, an assignment) — falls back to `ack`, so no button in the
    /// game is ever a no-op to the player. Actions the reducer *rejects*
    /// produce no events and no `ack` line unless the caller passes one.
    ///
    /// - Parameters:
    ///   - action: what to send.
    ///   - engine: the live engine.
    ///   - ack: the sentence to show when the action produced no event.
    ///     Pass this for actions the reducer applies silently (a focus
    ///     change, an assignment).
    ///   - rejected: the sentence to show when the action produced no
    ///     event. Pass this instead for actions that always emit one when
    ///     accepted, so a gate the player didn't see still gets a reason.
    ///   - icon: SF Symbol for the `ack` line.
    ///   - tint: tint for the `ack` line.
    /// - Returns: the events the action produced, for callers that need to
    ///   know whether the engine actually accepted it.
    @discardableResult
    func send(
        _ action: GameAction,
        to engine: GameEngine,
        ack: String? = nil,
        rejected: String? = nil,
        icon: String = "checkmark.circle.fill",
        tint: Color = Theme.accent
    ) -> [GameEvent] {
        engine.send(action)
        let produced = announceNewEvents(
            in: engine.state,
            copy: EventCopy(state: engine.state, content: engine.content, balance: engine.balance)
        )
        guard produced.isEmpty else { return produced }
        if let rejected {
            show(rejected, icon: "exclamationmark.triangle.fill", tint: Theme.warning, severity: .notable)
        } else if let ack {
            Haptics.commit()
            show(ack, icon: icon, tint: tint)
        }
        return produced
    }
}
