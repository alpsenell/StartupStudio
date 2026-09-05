import Foundation
import Observation
import TycoonContent
import TycoonEngine
import TycoonSave

/// Owns the engine lifecycle: loads the current slot's save on launch,
/// wires autosave into that slot, and swaps engines when the player
/// continues, opens another slot, or starts a new company.
///
/// The app opens on the front door (`isAtFrontDoor`): the title screen
/// with Continue, New company and the three slots. Every path into the
/// game goes through it, and the biography's "Start a new company" goes
/// back to it. A headless QA pass (`-autoTab`, `-autoSpeed`) skips the
/// door straight into slot 0, as it always skipped onboarding.
///
/// Load failures never crash and are never silently eaten — the failure
/// message is kept for the UI to surface once as a dismissible notice.
@MainActor
@Observable
final class GameSession {
    /// The live engine. Replaced wholesale by every slot change and every
    /// new game. While the current slot is empty this is a placeholder —
    /// a generated company nobody asked for — with no autosave wired, so
    /// backgrounding on the title screen never writes it into the slot.
    private(set) var engine: GameEngine

    /// True while the title screen is up, in front of the game.
    private(set) var isAtFrontDoor: Bool

    /// The slot the engine plays in, and the one autosave writes to.
    private(set) var currentSlot: Int

    /// Whether the current slot holds a game (loaded or started), as
    /// opposed to the placeholder behind an empty slot.
    private(set) var hasCurrentGame: Bool

    /// The three slots as the picker lists them. Refreshed at the front
    /// door and after anything that changes a slot.
    private(set) var slots: [SlotSummary] = []

    /// True while the new-game flow is up, targeting `newGameSlot`.
    private(set) var needsOnboarding: Bool = false

    /// The slot the new-game flow will start into when it finishes.
    private(set) var newGameSlot: Int

    /// Set when a slot failed to load. The UI shows it once;
    /// `clearLoadFailure()` dismisses it.
    private(set) var loadFailureMessage: String?

    /// Last autosave failure, if any. Autosave failures must never crash;
    /// this is kept around for a subtle UI indicator.
    private(set) var lastSaveError: String?

    // MARK: Iteration 7 — one stored property per lane

    // Each has an empty default and is owned by its lane's extension file
    // (`GameSession+Tutorial.swift`, `+Cloud.swift`, …), so no lane edits
    // this file for a declaration.

    /// The tour, while a fresh install is on it (R1).
    var tutorial: TutorialProgress?
    /// What iCloud is doing (R2).
    var cloud: CloudSyncStatus = .off
    /// Every finished company, apart from the slots (R2).
    var ledger: LegacyLedger = .empty
    /// Today's company, when one is being played (R3).
    var daily: DailyState?
    /// A code that arrived by URL, for the custom page to pick up (R4).
    var pendingSeedCode: SeedCode?
    /// *Custom company* was asked for: the flow opens on the custom page (R4).
    var customGameRequested = false
    /// Whether the full game is owned (R6).
    var unlock: UnlockState = .unknown

    /// The gates composed into `engine.advanceGate`, by `installGate`.
    private(set) var gates: [any AdvanceGate] = []
    /// Fanned out from `engine.eventSink`, keyed by lane (`"tour"`,
    /// `"gameCenter"`), so two lanes can observe without clobbering.
    private(set) var eventObservers: [String: @MainActor ([GameEvent]) -> Void] = [:]

    /// `let` constants are never observation-tracked, no annotation needed.
    private let store: SaveStore<GameState>

    /// Whether slot changes are written to `GameSettings.currentSlot`.
    /// Off for tests, which would otherwise redirect the next real launch.
    private let remembersSlot: Bool

    /// Bump alongside `MigrationStep`s when the save format changes.
    private static let saveFormatVersion = 1

    /// - Parameters:
    ///   - saveDirectory: where the slots live; `nil` for the app's own.
    ///   - slot: the slot to open; `nil` for the one the player last
    ///     opened (slot 0 on a fresh install, and always for a headless pass).
    ///   - remembersSlot: whether opening a slot is remembered for next launch.
    init(saveDirectory: URL? = nil, slot: Int? = nil, remembersSlot: Bool = true) {
        let store = SaveStore<GameState>(
            directory: saveDirectory, currentFormatVersion: Self.saveFormatVersion
        )
        self.store = store
        self.remembersSlot = remembersSlot

        let headless = DebugLaunch.isHeadlessPass
        let remembered = remembersSlot ? GameSettings.currentSlot : 0
        let slot = headless ? 0 : Self.clamp(slot ?? remembered, to: store)
        self.currentSlot = slot
        self.newGameSlot = slot

        var resumedEngine: GameEngine?
        var failureMessage: String?
        do {
            if let saved = try store.load(slot: slot) {
                resumedEngine = GameEngine.resume(state: saved.state)
            }
        } catch {
            failureMessage = Self.loadFailureMessage(for: error, slot: slot)
        }

        // A headless pass with nothing to resume plays the generated game,
        // as it always did; a real launch keeps it as a placeholder until
        // the player continues or starts something.
        let placeholder = resumedEngine == nil && !headless
        self.engine = resumedEngine ?? Self.makeFreshEngine()
        self.hasCurrentGame = !placeholder
        self.loadFailureMessage = failureMessage
        self.isAtFrontDoor = !headless

        if !placeholder {
            wireAutosave(slot: slot)
        }
        wireEngineHooks()
        applyDebugLaunchArguments()
        refreshSlots()
    }

    // MARK: - Iteration 7: the engine's hooks

    /// Adds (or replaces, by id) a gate on the clock and re-composes.
    func installGate(_ gate: any AdvanceGate) {
        gates.removeAll { $0.id == gate.id }
        gates.append(gate)
        wireEngineHooks()
    }

    /// Removes a lane's gate; the clock runs again if nothing else refuses.
    func removeGate(id: String) {
        gates.removeAll { $0.id == id }
        wireEngineHooks()
    }

    /// Registers a lane's event observer, replacing one under the same key.
    func observeEvents(_ key: String, _ observer: @escaping @MainActor ([GameEvent]) -> Void) {
        eventObservers[key] = observer
        wireEngineHooks()
    }

    func stopObservingEvents(_ key: String) {
        eventObservers[key] = nil
        wireEngineHooks()
    }

    /// Wires the gates and the observers into whichever engine is live.
    /// Called on every engine swap, so a lane never has to know one
    /// happened.
    private func wireEngineHooks() {
        if gates.isEmpty {
            engine.advanceGate = nil
        } else {
            let gate: @MainActor (GameState) -> Bool = { [weak self] state in
                guard let self else { return true }
                return self.gates.allSatisfy { $0.allows(state) }
            }
            engine.advanceGate = gate
        }
        if eventObservers.isEmpty {
            engine.eventSink = nil
        } else {
            let sink: @MainActor ([GameEvent]) -> Void = { [weak self] events in
                guard let self else { return }
                for observer in self.eventObservers.values {
                    observer(events)
                }
            }
            engine.eventSink = sink
        }
    }

    // MARK: - The front door

    /// Continue the current slot's game: the door closes.
    func continueGame() {
        guard hasCurrentGame else { return }
        isAtFrontDoor = false
    }

    /// Back to the title screen. The running game pauses and saves on the
    /// way out (the same path backgrounding takes), so the slot row it
    /// leaves behind is current.
    func returnToFrontDoor() {
        if hasCurrentGame {
            engine.pauseForBackground()
        }
        needsOnboarding = false
        refreshSlots()
        isAtFrontDoor = true
    }

    /// Opens a slot from the picker. The current game continues; another
    /// slot's game is loaded and takes over; an empty slot starts the
    /// new-game flow into it; a slot that will not read stays where it is
    /// and says why.
    func openSlot(_ slot: Int) {
        guard slot != currentSlot || !hasCurrentGame else {
            continueGame()
            return
        }
        let loaded: (state: GameState, envelope: SaveEnvelope)?
        do {
            loaded = try store.load(slot: slot)
        } catch {
            loadFailureMessage = Self.loadFailureMessage(for: error, slot: slot)
            return
        }
        guard let loaded else {
            beginNewGame(inSlot: slot)
            return
        }
        install(GameEngine.resume(state: loaded.state), inSlot: slot)
        isAtFrontDoor = false
    }

    /// Deletes a slot's save and backup — that slot's and nothing else.
    /// Deleting the slot the engine is playing in leaves a placeholder
    /// behind it, so Continue goes away with the save.
    func deleteSlot(_ slot: Int) {
        do {
            try store.delete(slot: slot)
        } catch {
            lastSaveError = error.localizedDescription
        }
        if slot == currentSlot, hasCurrentGame {
            engine.shutdown()
            engine = Self.makeFreshEngine()
            hasCurrentGame = false
            wireEngineHooks()
        }
        refreshSlots()
    }

    /// Opens the new-game flow, to start into `slot` when it finishes.
    /// Nothing is deleted until then: cancelling leaves every slot as it was.
    func beginNewGame(inSlot slot: Int) {
        newGameSlot = Self.clamp(slot, to: store)
        needsOnboarding = true
    }

    /// Settings → "Start a new game…": back to the front door, where the
    /// slot picker is.
    func requestOnboarding() {
        returnToFrontDoor()
    }

    /// Abandons a new-game flow, leaving every slot untouched.
    func cancelOnboarding() {
        needsOnboarding = false
    }

    // MARK: - New games

    /// Replaces the engine with a fresh game at normal difficulty in the
    /// current slot. Kept for callers that don't offer a choice.
    func startNewGame() {
        startNewGame(difficulty: .normal)
    }

    /// Starts the company the new-game flow built — the founder's name,
    /// archetype and look, the studio's name, the difficulty, and how the
    /// company starts — into `newGameSlot`, replacing whatever was there.
    ///
    /// Iteration 7: `seed` (a typed code, R4), `rules` (the custom page,
    /// R4), `heirloom` (R2) and `mode` (R3/R4) all default to what the
    /// flow always did, so today's callers are untouched.
    func startNewGame(
        profile: FounderProfile,
        companyName: String,
        difficulty: Difficulty,
        origin: FoundingOrigin = .garage,
        seed: UInt64? = nil,
        rules: GameRules = .standard,
        heirloom: Heirloom? = nil,
        mode: RunMode = .standard
    ) {
        replaceEngine(inSlot: newGameSlot) {
            GameEngine.newGame(
                companyName: companyName,
                seed: seed ?? UInt64.random(in: .min ... .max),
                difficulty: difficulty,
                founder: profile,
                origin: origin,
                heirloom: heirloom,
                rules: rules,
                mode: mode
            )
        }
        GameSettings.hasCompletedOnboarding = true
        needsOnboarding = false
        isAtFrontDoor = false
    }

    /// The same year again: a fresh engine on the run's own seed, founder,
    /// company, difficulty and origin, so the same events and candidates
    /// come round. The engine is deterministic — same seed, same game —
    /// and the player is the only thing that changes. Plays in the slot
    /// the ended run was in.
    func replayCurrentGame() {
        let ended = engine.state
        replaceEngine(inSlot: currentSlot) {
            GameEngine.newGame(
                companyName: ended.company.name,
                seed: ended.seed,
                difficulty: ended.difficulty,
                founder: ended.progression.founder,
                origin: ended.origin
            )
        }
        GameSettings.hasCompletedOnboarding = true
        needsOnboarding = false
        isAtFrontDoor = false
    }

    /// Replaces the current slot with a fresh game at the given
    /// difficulty, optionally as a founder the player built. Used by the
    /// endings' founder setup sheet when the front door is not around
    /// (a snapshot, a preview) — the biography itself goes to the door.
    func startNewGame(
        difficulty: Difficulty,
        founder: FounderProfile? = nil,
        origin: FoundingOrigin = .garage
    ) {
        replaceEngine(inSlot: currentSlot) {
            Self.makeFreshEngine(difficulty: difficulty, founder: founder, origin: origin)
        }
        isAtFrontDoor = false
    }

    /// Shared teardown/rebuild behind every "new game" path. Stopping the
    /// outgoing engine for good matters: without it a still-referenced old
    /// instance keeps ticking and its autosave overwrites the new game's
    /// save file (the "zombie engine" bug). Only `slot` is cleared; the
    /// new game is saved at once so its row is on the picker before the
    /// first tick.
    private func replaceEngine(inSlot slot: Int, _ make: () -> GameEngine) {
        engine.shutdown()
        do {
            try store.delete(slot: slot)
        } catch {
            lastSaveError = error.localizedDescription
        }
        install(make(), inSlot: slot)
        persist(engine.state, slot: slot)
        refreshSlots()
    }

    /// Makes `newEngine` the live game in `slot`: the old engine is shut
    /// down, autosave is wired to the slot, and the slot is remembered
    /// for the next launch.
    private func install(_ newEngine: GameEngine, inSlot slot: Int) {
        engine.shutdown()
        engine = newEngine
        currentSlot = slot
        newGameSlot = slot
        hasCurrentGame = true
        if remembersSlot {
            GameSettings.currentSlot = slot
        }
        wireAutosave(slot: slot)
        wireEngineHooks()
        applyDebugLaunchArguments()
    }

    /// Dismisses the one-time load-failure notice.
    func clearLoadFailure() {
        loadFailureMessage = nil
    }

    // MARK: - Persistence

    /// The picker's rows, from the envelopes; a save from before summaries
    /// existed is summarized from its state.
    func refreshSlots() {
        slots = store.slots(summarize: SaveSummary.init(state:))
    }

    /// The Continue card's facts about the current game, off the live
    /// state rather than the file, so a run just left is up to date.
    var currentSummary: SaveSummary? {
        hasCurrentGame ? SaveSummary(state: engine.state) : nil
    }

    /// The slot is captured, not read back, so an engine on its way out
    /// can never write its state into the slot that replaced it.
    private func wireAutosave(slot: Int) {
        engine.autosave = { [weak self] state in
            self?.persist(state, slot: slot)
        }
    }

    private func persist(_ state: GameState, slot: Int) {
        do {
            try store.save(
                state, appVersion: Self.appVersion, summary: SaveSummary(state: state), slot: slot
            )
            lastSaveError = nil
        } catch {
            // A failed autosave must never crash the game.
            lastSaveError = error.localizedDescription
        }
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    private static func clamp(_ slot: Int, to store: SaveStore<GameState>) -> Int {
        min(max(0, slot), store.slotCount - 1)
    }

    private static func loadFailureMessage(for error: any Error, slot: Int) -> String {
        let name = "slot \(slot + 1)"
        return switch error {
        case SaveStoreError.corruptSave:
            "The save in \(name) was damaged and couldn't be read."
        case SaveStoreError.futureFormat(let version):
            "The save in \(name) was made by a newer version of the app (format \(version)) and can't be opened here."
        default:
            "The save in \(name) couldn't be loaded (\(error.localizedDescription))."
        }
    }

    // MARK: - Engine creation

    /// Determinism lives inside the engine; a random seed at the app layer
    /// is fine.
    private static func makeFreshEngine(
        difficulty: Difficulty = .normal,
        founder: FounderProfile? = nil,
        origin: FoundingOrigin = .garage
    ) -> GameEngine {
        // Nobody is ever called "Founder" at a company called "Startup
        // Studio": the new-game flow names both, and the paths that skip
        // it (the placeholder behind an empty slot, a headless pass, "play
        // again" from an ending) get a generated pair instead.
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
            founder: founder ?? generated,
            // A headless screenshot pass can ask for a non-garage start;
            // every other caller gets what it asked for.
            origin: DebugLaunch.launchOrigin ?? origin
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
