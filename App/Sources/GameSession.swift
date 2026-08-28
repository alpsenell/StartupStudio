import Foundation
import Observation
import TycoonContent
import TycoonEngine
import TycoonSave

/// Owns the engine lifecycle: loads the save on launch, wires autosave,
/// and swaps in a fresh engine on "New Game".
///
/// Load failures never crash and are never silently eaten — the failure
/// message is kept for the UI to surface once as a dismissible notice.
@MainActor
@Observable
final class GameSession {
    /// The live engine. Replaced wholesale by `startNewGame()`.
    private(set) var engine: GameEngine

    /// True when the app came up without a save to resume and the player
    /// has never been through the new-game flow — `AppRootView` shows
    /// `NewGameFlow` over everything until they have.
    private(set) var needsOnboarding: Bool

    /// Set when loading the save failed on launch (a new game was started
    /// instead). The UI shows it once; `clearLoadFailure()` dismisses it.
    private(set) var loadFailureMessage: String?

    /// Last autosave failure, if any. Autosave failures must never crash;
    /// this is kept around for a subtle UI indicator.
    private(set) var lastSaveError: String?

    /// `let` constants are never observation-tracked, no annotation needed.
    private let store: SaveStore<GameState>

    /// Bump alongside `MigrationStep`s when the save format changes.
    private static let saveFormatVersion = 1

    init() {
        let store = SaveStore<GameState>(currentFormatVersion: Self.saveFormatVersion)
        self.store = store

        var resumedEngine: GameEngine?
        var failureMessage: String?
        do {
            if let saved = try store.load() {
                resumedEngine = GameEngine.resume(state: saved.state)
            }
        } catch SaveStoreError.corruptSave {
            failureMessage = "Your save file was damaged and couldn't be read, so a new game was started."
        } catch SaveStoreError.futureFormat(let version) {
            failureMessage = "Your save was made by a newer version of the app (format \(version)), so a new game was started."
        } catch {
            failureMessage = "Your save couldn't be loaded (\(error.localizedDescription)), so a new game was started."
        }

        self.engine = resumedEngine ?? Self.makeFreshEngine()
        self.loadFailureMessage = failureMessage
        // A resumed save means this player already named themselves; a
        // fresh launch with nothing to resume goes through onboarding.
        self.needsOnboarding = resumedEngine == nil && !GameSettings.hasCompletedOnboarding

        wireAutosave()
        applyDebugLaunchArguments()
    }

    /// Deletes the save and replaces the engine with a fresh game at
    /// normal difficulty. Kept for callers that don't offer a choice.
    func startNewGame() {
        startNewGame(difficulty: .normal)
    }

    /// Deletes the save and replaces the engine with a fresh game built
    /// from the new-game flow's choices: the founder's name, archetype and
    /// look, the studio's name, and the difficulty.
    func startNewGame(profile: FounderProfile, companyName: String, difficulty: Difficulty) {
        replaceEngine {
            GameEngine.newGame(
                companyName: companyName,
                seed: UInt64.random(in: .min ... .max),
                difficulty: difficulty,
                founder: profile
            )
        }
        GameSettings.hasCompletedOnboarding = true
        needsOnboarding = false
    }

    /// Re-opens the new-game flow (Settings → "Start a new game…"). The
    /// running game keeps ticking underneath until the flow finishes.
    func requestOnboarding() {
        needsOnboarding = true
    }

    /// Abandons a new-game flow the player opened from Settings, leaving
    /// the running game untouched.
    func cancelOnboarding() {
        needsOnboarding = false
    }

    /// Deletes the save and replaces the engine with a fresh game at the
    /// given difficulty, optionally as a founder the player built on the
    /// ending screen. Used by the endings screens (which offer the founder
    /// setup sheet) and the Settings sheet's "Start a new game…" (which
    /// does not, and so gets a generated founder).
    func startNewGame(difficulty: Difficulty, founder: FounderProfile? = nil) {
        replaceEngine { Self.makeFreshEngine(difficulty: difficulty, founder: founder) }
    }

    /// Shared teardown/rebuild behind every "new game" path. Stopping the
    /// outgoing engine for good matters: without it a still-referenced old
    /// instance keeps ticking and its autosave overwrites the new game's
    /// save file (the "zombie engine" bug).
    private func replaceEngine(_ make: () -> GameEngine) {
        engine.shutdown()
        do {
            try store.deleteAll()
        } catch {
            lastSaveError = error.localizedDescription
        }
        engine = make()
        wireAutosave()
        applyDebugLaunchArguments()
    }

    /// Dismisses the one-time load-failure notice.
    func clearLoadFailure() {
        loadFailureMessage = nil
    }

    // MARK: - Persistence

    private func wireAutosave() {
        engine.autosave = { [weak self] state in
            self?.persist(state)
        }
    }

    private func persist(_ state: GameState) {
        do {
            try store.save(state, appVersion: Self.appVersion)
            lastSaveError = nil
        } catch {
            // A failed autosave must never crash the game.
            lastSaveError = error.localizedDescription
        }
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    // MARK: - Engine creation

    /// Determinism lives inside the engine; a random seed at the app layer
    /// is fine.
    private static func makeFreshEngine(
        difficulty: Difficulty = .normal,
        founder: FounderProfile? = nil
    ) -> GameEngine {
        // Nobody is ever called "Founder" at a company called "Startup
        // Studio": the new-game flow names both, and the paths that skip
        // it (a first launch waiting behind onboarding, "play again" from
        // an ending) get a generated pair instead.
        let index = Int.random(in: 0..<64)
        let names = (try? ContentCatalog.loadBundled())?.names
            ?? NamePools(firstNames: [], lastNames: [], clientCompanies: [])
        // `usesArchetypeSkills: false` on the generated founder, matching
        // `FounderProfile.default`: WS-F made the archetype spread opt-in
        // on purpose (the +10 skill points move the whole balance), and
        // nobody picked "hacker" on this path — it is only a name.
        let generated = FounderProfile(
            name: StudioNameGenerator.founderName(index: index, names: names),
            archetype: .hacker,
            usesArchetypeSkills: false
        )
        return GameEngine.newGame(
            companyName: StudioNameGenerator.companyName(index: index),
            seed: UInt64.random(in: .min ... .max),
            difficulty: difficulty,
            founder: founder ?? generated
        )
    }

    /// Test hook: launch with `-autoSpeed x4` (simctl launch argument) to
    /// start the simulation running, so headless UI checks can watch time
    /// advance without tapping the speed control.
    private func applyDebugLaunchArguments() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let flag = args.firstIndex(of: "-autoSpeed"), args.indices.contains(flag + 1),
           let speed = SimSpeed(rawValue: args[flag + 1]) {
            engine.setSpeed(speed)
        }
        #endif
    }
}
