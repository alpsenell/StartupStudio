import Foundation
import TycoonEngine
import TycoonSave

/// The three bundled saves the store-screenshot pipeline photographs
/// (iteration 7, R8).
///
/// `simctl` can launch the app and take its picture but cannot tap it, so
/// every screenshot the App Store listing needs would otherwise be day 0
/// in a garage. `-autoFixture release-studio-day400` installs one of these
/// into slot 0 *before* the shell appears, and `-autoTab`/`-autoRoute`
/// take it from there.
///
/// The files are `GameState` JSON, written by the engine test target's
/// `ReleaseFixtureGenerator` from real bot runs against the shipped
/// balance. They are read here and re-saved through `SaveStore`, so the
/// envelope is whatever this build writes and a fixture never needs a
/// migration of its own.
///
/// DEBUG only, twice over: the flag is `#if DEBUG` and the JSON is kept
/// out of Release by `EXCLUDED_SOURCE_FILE_NAMES` in `project.yml`.
enum ReleaseFixture {
    /// Every fixture the screenshot pipeline knows about, in the order
    /// the listing tells the story.
    static let names = [
        "release-garage-day40",
        "release-studio-day400",
        "release-campus-day900",
    ]

    // MARK: Iteration 9 — lane fixtures

    /// Bundled saves a lane generated to photograph its own surface. Kept
    /// apart from `names` because those three are the store listing's
    /// story and are pinned as such; these are only ever reached by an
    /// explicit `-autoFixture`.
    ///
    /// - `l3-family-day900`: the campus run with a married founder, a
    ///   house, a teenager and a toddler, and their memory ledgers.
    static let laneFixtures = [
        "l3-family-day900",
        // MARK: P2 (purchases: StoreKit and the session)
        // `release-bankruptcy`: a standard company one day from the
        // bankruptcy ending, for App Review's receiver's call and the
        // post-mortem's screenshot (`iteration-13-lanes/p2.md`).
        "release-bankruptcy",
        // MARK: end P2
    ]

    /// The bundled JSON for `name`, or `nil` when it is not in this build
    /// (a Release build, or a name nobody generated).
    static func data(named name: String) -> Data? {
        guard names.contains(name) || laneFixtures.contains(name),
              let url = Bundle.main.url(forResource: name, withExtension: "json")
        else { return nil }
        return try? Data(contentsOf: url)
    }

    /// The game inside a fixture. `nil` if it is missing or unreadable —
    /// a screenshot pass that asked for a company it cannot have should
    /// fall through to the ordinary launch, not crash.
    static func state(named name: String) -> GameState? {
        guard let data = data(named: name) else { return nil }
        return try? JSONDecoder().decode(GameState.self, from: data)
    }

    /// Installs the fixture `-autoFixture` named into slot 0 of `store`,
    /// replacing whatever was there. Returns the name it installed, or
    /// `nil` when the flag is absent (every release build, and every
    /// launch that did not ask).
    ///
    /// Called from `GameSession.init` before the slot is loaded, so the
    /// session resumes the fixture the same way it resumes a real save —
    /// no second code path into the game.
    @discardableResult
    static func installIfAsked(
        into store: SaveStore<GameState>, appVersion: String
    ) -> String? {
        #if DEBUG
        guard let name = DebugLaunch.launchFixtureName else { return nil }
        guard var state = state(named: name) else {
            assertionFailure("-autoFixture \(name): no such bundled fixture")
            return nil
        }
        // MARK: K5 (hand over the keys)
        if DebugLaunch.preparesHandOver { state = DebugLaunch.k5Prepared(state) }
        // MARK: end K5
        do {
            try store.save(
                state, appVersion: appVersion, summary: SaveSummary(state: state), slot: 0
            )
            return name
        } catch {
            assertionFailure("-autoFixture \(name): \(error)")
            return nil
        }
        #else
        return nil
        #endif
    }
}
