import TycoonEngine
import UIKit

/// Every haptic the game plays, in one place, so "did that action do
/// anything?" always has a physical answer and the Settings toggle has a
/// single switch to flip.
@MainActor
enum Haptics {
    /// Mirrors the Settings toggle, persisted in `UserDefaults`.
    static var isEnabled: Bool {
        get { GameSettings.hapticsEnabled }
        set { GameSettings.hapticsEnabled = newValue }
    }

    /// A button press or a page turn.
    static func tap() {
        impact(.light)
    }

    /// A committed choice: hire, ship, accept, buy.
    static func commit() {
        impact(.medium)
    }

    /// Something landed well.
    static func success() {
        notify(.success)
    }

    /// Something needs attention but isn't fatal.
    static func warning() {
        notify(.warning)
    }

    /// Something went wrong.
    static func failure() {
        notify(.error)
    }

    // MARK: Iteration 10 — M6 (the bug hunt)

    /// A bug going under a thumb. `.rigid` is the sharpest impact iOS has —
    /// a short, hard knock rather than the soft thud of a committed choice,
    /// which is the difference between squashing something and pressing a
    /// button.
    static func squash() {
        impact(.rigid)
    }

    // MARK: end Iteration 10 — M6

    /// The haptic that matches an event's severity, used by the toast and
    /// pause layers so the strength of the buzz tracks the news.
    static func play(severity: EventSeverity) {
        switch severity {
        case .quiet: break
        case .info: tap()
        case .notable: commit()
        case .critical: warning()
        }
    }

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    private static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

/// The handful of player preferences that live outside the simulation:
/// sound, haptics, the weekly-report auto-open, and whether onboarding has
/// been seen. Everything here is cosmetic — nothing in `GameState`
/// depends on it, so a save moved between devices behaves identically.
enum GameSettings {
    private static let soundKey = "settings.soundEnabled"
    private static let hapticsKey = "settings.hapticsEnabled"
    private static let weeklyReportKey = "settings.weeklyReportAuto"
    private static let onboardedKey = "settings.hasCompletedOnboarding"
    private static let dismissedTipsKey = "settings.dismissedTips"

    /// Chiptune SFX. On by default — the game respects the silent switch.
    static var soundEnabled: Bool {
        get { bool(forKey: soundKey, default: true) }
        set { UserDefaults.standard.set(newValue, forKey: soundKey) }
    }

    /// Haptic feedback. On by default.
    static var hapticsEnabled: Bool {
        get { bool(forKey: hapticsKey, default: true) }
        set { UserDefaults.standard.set(newValue, forKey: hapticsKey) }
    }

    /// Whether the weekly report opens itself at the end of a week.
    /// Default on; `WeeklyReportChip` stops auto-opening after the first
    /// eight weeks unless the player keeps this on deliberately.
    static var weeklyReportAuto: Bool {
        get { bool(forKey: weeklyReportKey, default: true) }
        set { UserDefaults.standard.set(newValue, forKey: weeklyReportKey) }
    }

    /// How many times the player has opened the weekly report from the
    /// rail themselves. After two, the report stops opening itself: they
    /// have learned the loop.
    static var weeklyReportManualOpens: Int {
        get { UserDefaults.standard.integer(forKey: "settings.weeklyReportManualOpens") }
        set { UserDefaults.standard.set(newValue, forKey: "settings.weeklyReportManualOpens") }
    }

    /// Set once the player has been through `NewGameFlow`, so a fresh
    /// install opens onboarding and a resumed save does not.
    static var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: onboardedKey) }
        set { UserDefaults.standard.set(newValue, forKey: onboardedKey) }
    }

    /// Coach tips the player has dismissed, by tip id.
    static var dismissedTips: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: dismissedTipsKey) ?? []) }
        set { UserDefaults.standard.set(newValue.sorted(), forKey: dismissedTipsKey) }
    }

    /// Restores the defaults that new installs get. Used by the tests and
    /// by "Reset tips" in Settings.
    static func resetTips() {
        UserDefaults.standard.removeObject(forKey: dismissedTipsKey)
    }

    // MARK: Iteration 7 — the first hour (R1)

    private static let tutorialCompletedKey = "settings.tutorialCompleted"

    /// Set once the tour has been finished or skipped. A fresh install
    /// sees the tour once; nobody with this set sees it again, whatever
    /// company they found next.
    static var tutorialCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: tutorialCompletedKey) }
        set { UserDefaults.standard.set(newValue, forKey: tutorialCompletedKey) }
    }

    // MARK: V1 (ux: Life folded, rooms dormant)

    /// Iteration 14 — V1. Whether one of Life's folds is open: a section
    /// ("people"), a room's row ("room.crime"), or the dormant rooms'
    /// group. Per install, like tip dismissal — nothing the player folded
    /// pops back open on the next launch. `fallback` is the fold's own
    /// default, used until the player first touches it.
    static func lifeFoldIsOpen(_ id: String, default fallback: Bool) -> Bool {
        bool(forKey: "settings.lifeFold." + id, default: fallback)
    }

    static func setLifeFold(_ id: String, isOpen: Bool) {
        UserDefaults.standard.set(isOpen, forKey: "settings.lifeFold." + id)
    }

    // MARK: end V1

    private static func bool(forKey key: String, default fallback: Bool) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? fallback
    }
}
