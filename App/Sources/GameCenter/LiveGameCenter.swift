import Foundation
import GameKit
import UIKit

// MARK: Iteration 7 — Game Center (R3)

/// GameKit, behind the four things the game asks of it.
///
/// The only file in the app that imports GameKit: everything above it
/// talks to `GameCenterClient`, so the mapping (`GameSession+GameCenter`)
/// and the daily are testable on a simulator with no Game Center account.
///
/// Policy, from the release doc:
/// - `GKLocalPlayer.local.authenticateHandler` is set once, at launch.
/// - The sign-in view controller it hands back is presented **once**. A
///   player who dismisses it is never asked again in this launch; the game
///   plays exactly the same signed out, and everything it would have
///   reported queues.
/// - `GKAccessPoint` stays off — the floating badge fights the pixel
///   chrome. Game Center is reachable from the Settings row instead.
@MainActor
final class LiveGameCenter: GameCenterClient {
    private(set) var isAuthenticated = false

    /// Called when authentication lands, so the queue can flush.
    var onAuthenticated: (@MainActor () -> Void)?

    /// The handler is installed once per launch; a second `authenticate()`
    /// is a no-op rather than a second sign-in prompt.
    private var didInstallHandler = false
    /// The sign-in sheet is shown once and never nagged.
    private var didPresentSignIn = false

    init() {}

    func authenticate() {
        guard !didInstallHandler else { return }
        didInstallHandler = true
        GKAccessPoint.shared.isActive = false
        GKLocalPlayer.local.authenticateHandler = { viewController, _ in
            // GameKit documents this handler as main-thread; the app is
            // main-actor throughout, and nothing here is Sendable.
            MainActor.assumeIsolated {
                GameCenterHub.liveDidAuthenticate(viewController: viewController)
            }
        }
    }

    func report(achievement id: String) {
        guard isAuthenticated else { return }
        let achievement = GKAchievement(identifier: id)
        achievement.percentComplete = 100
        achievement.showsCompletionBanner = true
        GKAchievement.report([achievement]) { _ in }
    }

    func submit(score: Int, to leaderboard: String) {
        guard isAuthenticated else { return }
        GKLeaderboard.submitScore(
            score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [leaderboard]
        ) { _ in }
    }

    // MARK: - The authenticate handler

    /// GameKit calls back three ways: a view controller to present (nobody
    /// is signed in yet), no controller and `isAuthenticated` true (signed
    /// in), or an error (signed out for good this launch).
    fileprivate func handleAuthentication(viewController: UIViewController?) {
        if let viewController {
            guard !didPresentSignIn else { return }
            didPresentSignIn = true
            Self.topViewController()?.present(viewController, animated: true)
            return
        }
        let authenticated = GKLocalPlayer.local.isAuthenticated
        let changed = authenticated != isAuthenticated
        isAuthenticated = authenticated
        if authenticated, changed {
            onAuthenticated?()
        }
    }

    /// The frontmost view controller, for the sign-in sheet and the
    /// dashboard. `nil` while no scene is up (a unit-test host).
    static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController
            ?? scene?.windows.first?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

extension GameCenterHub {
    /// The authenticate handler's landing point. Free of GameKit types
    /// above this line: the hub owns the live client, and only it knows
    /// whether there is one.
    fileprivate static func liveDidAuthenticate(viewController: UIViewController?) {
        live?.handleAuthentication(viewController: viewController)
    }
}
