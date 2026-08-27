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
        for event in events where shouldToast(event) {
            let line = copy.line(for: event)
            push(
                Toast(
                    id: nextID,
                    icon: line.icon,
                    message: line.message,
                    tint: line.tint,
                    severity: event.severity
                )
            )
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
        announce(fresh, copy: copy)
        return fresh
    }

    /// Re-baselines after an engine swap so a resumed or brand-new game
    /// doesn't replay its history as toasts.
    func resetBaseline(to state: GameState) {
        lastAnnouncedEventCount = state.eventLog.count
    }

    /// Events that get a full sheet or a banner of their own; a toast on
    /// top of those is noise.
    private func shouldToast(_ event: GameEvent) -> Bool {
        switch event {
        case .shipped, .reviewsIn, .gameOver, .companySold,
             .poachAttempt, .buyoutOffered, .staffEventOccurred:
            false
        default:
            event.severity != .quiet
        }
    }

    private func push(_ toast: Toast) {
        nextID += 1
        withAnimation(.spring(duration: 0.32)) {
            toasts.append(toast)
            if toasts.count > Self.maxVisible {
                toasts.removeFirst(toasts.count - Self.maxVisible)
            }
        }
        Haptics.play(severity: toast.severity)
        Sounds.play(severity: toast.severity)
        let id = toast.id
        Task { [weak self] in
            try? await Task.sleep(for: Self.lifetime)
            self?.dismiss(id)
        }
    }

    private func dismiss(_ id: Int) {
        withAnimation(.easeOut(duration: 0.25)) {
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

/// The stack of toasts, laid over the top of the app under the HUD.
struct ToastStack: View {
    let center: ToastCenter

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(center.toasts) { toast in
                ToastView(toast: toast)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .center)
        .allowsHitTesting(false)
        .accessibilityElement(children: .contain)
    }
}

private struct ToastView: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: toast.icon)
                .font(.footnote.weight(.bold))
                .foregroundStyle(toast.tint)
            Text(toast.message)
                .font(.system(.footnote, design: .rounded).weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(.regularMaterial, in: Capsule())
        .overlay(
            Capsule().strokeBorder(toast.tint.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(toast.message)
    }
}

#Preview {
    let center = ToastCenter()
    return ZStack(alignment: .top) {
        Theme.screenBackground.ignoresSafeArea()
        ToastStack(center: center)
    }
    .onAppear {
        center.show("Priya joins as Backend Dev", icon: "person.badge.plus", tint: Theme.positiveCash)
        center.show("Signed Pigeon Logistics · due W12", icon: "briefcase.fill")
    }
}
