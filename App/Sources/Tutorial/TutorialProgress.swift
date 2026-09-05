import Foundation
import TycoonEngine
import TycoonSave

// MARK: Iteration 7 — the first hour (R1)

/// The nine beats of the tour a fresh install gets once. Paced by what
/// the player has done, not by the calendar: the stretch between the desk
/// and the ship is weeks long and silent.
enum TutorialStep: Int, CaseIterable, Codable, Hashable, Comparable {
    case welcome
    case nameAProduct
    case hire
    case runTheClock
    case readTheWeek
    case yourEvenings
    case theDesk
    case shipIt
    case launchDay

    static func < (lhs: TutorialStep, rhs: TutorialStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// The beat after this one; `nil` after launch day, where the tour ends.
    var next: TutorialStep? {
        TutorialStep(rawValue: rawValue + 1)
    }

    /// The tab this beat opens, `nil` for the beats that stay where the
    /// player is.
    var opensTab: GameTab? {
        switch self {
        case .welcome: .hq
        case .nameAProduct: .products
        case .hire: .team
        case .yourEvenings: .life
        case .theDesk: .business
        case .runTheClock, .readTheWeek, .shipIt, .launchDay: nil
        }
    }

    /// A short name: the card's bitmap kicker.
    var title: String {
        switch self {
        case .welcome: "Welcome"
        case .nameAProduct: "Name a product"
        case .hire: "Hire"
        case .runTheClock: "Run the clock"
        case .readTheWeek: "Read the week"
        case .yourEvenings: "Your evenings"
        case .theDesk: "The desk"
        case .shipIt: "Ship it"
        case .launchDay: "Launch day"
        }
    }
}

/// Where the tour is. `GameSession.tutorial` is `nil` for every player
/// who is not on it — a returning player, a second company, a daily.
struct TutorialProgress: Equatable {
    var step: TutorialStep = .welcome
    var isComplete = false
    /// The tabs rendered so far; all five once the desk beat opens.
    var openTabs: Set<GameTab> = [.hq]
    /// True while the current beat has nothing to say: the ship beat
    /// between the desk and the day the build is ready. A dormant beat
    /// draws no card and no rail line — the tour is not allowed to nag
    /// across a three-to-twelve-week stretch.
    var isDormant = false

    /// The tabs the root renders: everything once the tour is over.
    var visibleTabs: Set<GameTab> {
        isComplete ? TutorialScript.allTabs : openTabs
    }

    /// The beat the rail and the card show, if any.
    var activeStep: TutorialStep? {
        isComplete || isDormant ? nil : step
    }
}

/// Where the tour is, per slot, so backgrounding mid-tour resumes. Keyed
/// by the run's seed and day as well as the step: a slot deleted and
/// refounded mid-tour starts the tour over rather than resuming beat 6 on
/// a day-0 company, and *Run it back* on the same seed does the same.
struct TutorialStore {
    struct Saved: Equatable {
        var step: TutorialStep
        var seed: UInt64
        var day: Int
    }

    var defaults: UserDefaults = .standard

    static func stepKey(slot: Int) -> String { "tutorial.slot\(slot).step" }
    static func seedKey(slot: Int) -> String { "tutorial.slot\(slot).seed" }
    static func dayKey(slot: Int) -> String { "tutorial.slot\(slot).day" }

    func load(slot: Int) -> Saved? {
        guard let raw = defaults.object(forKey: Self.stepKey(slot: slot)) as? Int,
              let step = TutorialStep(rawValue: raw),
              let seedText = defaults.string(forKey: Self.seedKey(slot: slot)),
              let seed = UInt64(seedText)
        else { return nil }
        return Saved(step: step, seed: seed, day: defaults.integer(forKey: Self.dayKey(slot: slot)))
    }

    func save(_ saved: Saved, slot: Int) {
        defaults.set(saved.step.rawValue, forKey: Self.stepKey(slot: slot))
        // As text: a seed above `Int64.max` does not survive a plist as a number.
        defaults.set(String(saved.seed), forKey: Self.seedKey(slot: slot))
        defaults.set(saved.day, forKey: Self.dayKey(slot: slot))
    }

    func clear(slot: Int) {
        defaults.removeObject(forKey: Self.stepKey(slot: slot))
        defaults.removeObject(forKey: Self.seedKey(slot: slot))
        defaults.removeObject(forKey: Self.dayKey(slot: slot))
    }

    /// Whether `saved` belongs to the game in `state`: the same company,
    /// not rewound.
    func matches(_ saved: Saved, state: GameState) -> Bool {
        saved.seed == state.seed && state.day >= saved.day
    }
}

/// The start condition, as a pure function so a test can hand it slots.
///
/// Only the first company on a fresh install: the tour has not been
/// completed or skipped, no other slot holds a save, no company has ever
/// finished (the ledger), the run is a standard one (never a daily or a
/// custom company), and the game is on its first day.
enum TutorialEligibility {
    static func canStart(
        tutorialCompleted: Bool,
        slots: [SlotSummary],
        currentSlot: Int,
        ledger: LegacyLedger,
        state: GameState
    ) -> Bool {
        guard !tutorialCompleted else { return false }
        guard slots.allSatisfy({ $0.slot == currentSlot || $0.isEmpty }) else { return false }
        guard ledger.runs.isEmpty else { return false }
        guard state.mode == .standard, state.heirloom == nil else { return false }
        return state.day == 0
    }
}
