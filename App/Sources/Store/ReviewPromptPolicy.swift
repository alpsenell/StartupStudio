import Foundation
import StoreKit
import SwiftUI

// MARK: Iteration 7 — the unlock (R6)

/// When to ask for a rating: once per install, on the title screen, after
/// the player has come back from the first biography of any ending —
/// never from a daily, and never in a session that showed the paywall
/// (nobody rates a game on the way out of a store).
///
/// The system decides whether the prompt is actually shown; this decides
/// whether to ask it at all. The answer is remembered as the version that
/// asked (`review.askedForVersion`), which is the once-per-install mark
/// and, later, the hook for a once-per-major policy.
enum ReviewPromptPolicy {
    static let askedKey = "review.askedForVersion"

    /// The pure rule. `doorAppearances` counts the title screen's arrivals
    /// this launch: the first is the launch itself, and only a later one
    /// with an ended current run is a return from a biography.
    static func decide(
        askedForVersion: String?,
        doorAppearances: Int,
        currentRunEnded: Bool,
        isDaily: Bool,
        paywallShownThisSession: Bool
    ) -> Bool {
        askedForVersion == nil
            && doorAppearances > 1
            && currentRunEnded
            && !isDaily
            && !paywallShownThisSession
    }

    /// Counts the title screen's arrivals this launch.
    @MainActor private static var doorAppearances = 0

    /// Called from the title screen's `.task`. Returns whether to ask,
    /// and records the ask so it never comes twice.
    @MainActor
    static func titleScreenAppeared(
        session: GameSession, defaults: UserDefaults = .standard
    ) -> Bool {
        doorAppearances += 1
        let ask = decide(
            askedForVersion: defaults.string(forKey: askedKey),
            doorAppearances: doorAppearances,
            currentRunEnded: session.currentSummary?.endingKind != nil,
            isDaily: session.engine.state.mode.isDaily,
            paywallShownThisSession: session.unlock.paywallShownThisSession
        )
        if ask {
            markAsked(defaults: defaults)
        }
        return ask
    }

    static func markAsked(defaults: UserDefaults = .standard) {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        defaults.set(version, forKey: askedKey)
    }

    /// Test hook: a fresh launch.
    @MainActor static func resetForTesting() {
        doorAppearances = 0
    }
}

/// The title screen's `.task`: asks the system for the review prompt when
/// the policy says so. Lives here so `StoreKit` stays under `Store/`.
struct ReviewPromptOnReturn: ViewModifier {
    let session: GameSession

    @Environment(\.requestReview) private var requestReview

    func body(content: Content) -> some View {
        content.task {
            if ReviewPromptPolicy.titleScreenAppeared(session: session) {
                requestReview()
            }
        }
    }
}

extension View {
    /// Iteration 7 (R6): the once-per-install review prompt.
    func reviewPromptOnReturn(session: GameSession) -> some View {
        modifier(ReviewPromptOnReturn(session: session))
    }
}
