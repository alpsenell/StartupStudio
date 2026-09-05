import Foundation

// MARK: Iteration 7 — Game Center (R3)

/// The one Game Center client the app reports through.
///
/// It is a stored global rather than a `GameSession` property on purpose:
/// achievements outlive an engine swap, a slot change and the daily, and
/// no other lane should have to know the client exists. Tests replace it
/// with a `NoopGameCenter` and read back what it was asked for.
@MainActor
enum GameCenterHub {
    /// The GameKit client, when this launch made one. `nil` in tests and
    /// wherever `install(_:)` put something else in front.
    private(set) static var live: LiveGameCenter?

    /// What the game reports through — a no-op until `start()` runs, so
    /// nothing ever crashes for want of Game Center.
    private(set) static var client: any GameCenterClient = NoopGameCenter()

    /// Whether `start()` has run this launch.
    private(set) static var isStarted = false

    /// Builds the live client, queues behind it, and asks GameKit to
    /// authenticate. Idempotent: the second call is a no-op, so it can be
    /// hung off a view's `onAppear`.
    static func start() {
        guard !isStarted else { return }
        isStarted = true
        let live = LiveGameCenter()
        let queueing = QueueingGameCenter(base: live)
        live.onAuthenticated = { [weak queueing] in queueing?.flushQueue() }
        self.live = live
        client = queueing
        client.authenticate()
    }

    /// Test seam: report through `client` instead, and forget the live one.
    static func install(_ client: any GameCenterClient) {
        live = nil
        self.client = client
        isStarted = true
    }

    /// Test seam: back to a fresh no-op client.
    static func reset() {
        live = nil
        client = NoopGameCenter()
        isStarted = false
    }
}
