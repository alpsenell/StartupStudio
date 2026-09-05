import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

/// Writes the three store-screenshot saves in `App/Resources/Fixtures/`
/// (iteration 7, R8).
///
/// The App Store wants pictures of a company worth looking at, and a
/// launched-from-the-command-line app starts on day 0 in a garage. So the
/// screenshot pipeline installs one of these into slot 0 before the shell
/// appears (`-autoFixture <name>`, `GameSession.installFixtureIfAsked`) and
/// photographs the tab it was asked for.
///
/// Each fixture is a real bot run against the shipped `Balance.json` with
/// rivals on, encoded exactly the way `FixtureGenerator` encodes the legacy
/// save — a `GameState` with sorted keys, no envelope. The app wraps it in
/// a save envelope on the way in, so the envelope's format version is
/// whatever the app writes today and these files never need a migration.
///
/// Disabled by default, like the legacy fixture generator. Regenerate
/// deliberately — the files are committed, and a new set means new
/// screenshots:
///
///     REGENERATE_RELEASE_FIXTURES=1 swift test --filter regenerateReleaseFixtures
///
/// Determinism is the engine's, not this file's: the seeds below were
/// picked by the search in `pick(...)` and pinned once they produced a run
/// that matched its brief. The same seed replays the same company.
@Suite("Release fixture generator")
struct ReleaseFixtureGenerator {

    /// What each fixture has to be true of before it is written. If a seed
    /// stops satisfying its brief the generator says so rather than
    /// quietly writing a garage where a campus should be.
    struct Brief {
        var name: String
        var companyName: String
        var founder: FounderProfile
        var bot: any BotPolicy
        var days: Int
        /// Extra days to keep playing looking for `holds`, after `days`.
        var grace: Int
        /// What the run must look like when it stops.
        var holds: @Sendable (GameState, BalanceConfig, ContentCatalog) -> Bool
        var describes: String
    }

    static let fixturesDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // TycoonEngineTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // TycoonEngine
        .deletingLastPathComponent()  // Packages
        .deletingLastPathComponent()  // repo root
        .appendingPathComponent("App/Resources/Fixtures", isDirectory: true)

    /// Nothing is waiting for an answer.
    ///
    /// A screenshot has to be of a screen, not of a modal over one: the
    /// app puts a `DecisionSheet` over every tab whenever any of these is
    /// set (see `DecisionPrompt.pending`), and the campus fixture's first
    /// draft opened on a question about a feature nobody could read the
    /// market behind. So a fixture stops on a quiet day.
    static func isQuiet(_ state: GameState) -> Bool {
        state.rivals.pendingPoach == nil
            && state.rivals.pendingBuyout == nil
            && state.rivals.pendingChallenge == nil
            && state.pendingStaffEvent == nil
            && state.economy.pendingResignation == nil
            && state.investors.pendingOffer == nil
            && state.narrative.pendingChoice == nil
    }

    /// A build is "in launch week" when its ETA is inside seven days.
    static func hasBuildInLaunchWeek(
        _ state: GameState, _ balance: BalanceConfig, _ content: ContentCatalog
    ) -> Bool {
        state.shipETAs(balance: balance, content: content)
            .contains { $0.daysAway <= 7 }
    }

    /// A function, not a stored constant: `Brief` carries a bot, and
    /// `BotPolicy` is not `Sendable`.
    static func briefs() -> [Brief] { [
        Brief(
            name: "release-garage-day40",
            companyName: "Northgate",
            founder: FounderProfile(
                name: "Mira Okafor", archetype: .hacker, appearanceSeed: 0x5EED
            ),
            bot: GoalSoloBot(),
            days: 40,
            grace: 0,
            holds: { state, _, _ in
                state.gameOver == nil && isQuiet(state)
                    && state.company.officeTier == .garage
            },
            describes: "a solo founder still in the garage, six weeks in"
        ),
        Brief(
            name: "release-studio-day400",
            companyName: "Meridian Labs",
            founder: FounderProfile(
                name: "Dara Whitfield", archetype: .designer, appearanceSeed: 0xC0FFEE
            ),
            bot: InvestorBot(),
            days: 400,
            grace: 120,
            holds: { state, balance, content in
                state.gameOver == nil && isQuiet(state)
                    && state.company.officeTier == .studio
                    && hasBuildInLaunchWeek(state, balance, content)
            },
            describes: "a studio with a build in launch week"
        ),
        Brief(
            name: "release-campus-day900",
            companyName: "Halcyon Systems",
            founder: FounderProfile(
                name: "Ines Ferreira", archetype: .hustler, appearanceSeed: 0xBEEF_1234
            ),
            bot: InvestorBot(),
            days: 900,
            grace: 200,
            holds: { state, _, _ in
                state.gameOver == nil && isQuiet(state)
                    && state.company.officeTier == .campus
                    && state.investors.hasBoard
            },
            describes: "a funded campus with a board watching"
        ),
    ] }

    // MARK: - The driver

    /// Plays `brief` on `seed` and returns the state it stopped on, or
    /// `nil` if the run ended or never met the brief.
    static func play(
        _ brief: Brief, seed: UInt64, balance: BalanceConfig, content: ContentCatalog
    ) -> GameState? {
        var state = GameState.newGame(
            companyName: brief.companyName, seed: seed, balance: balance,
            founder: brief.founder, content: content
        )
        for day in 0..<(brief.days + brief.grace) {
            _ = Reducer.tick(&state, balance: balance, content: content)
            if state.gameOver != nil { return nil }
            for action in brief.bot.actions(for: state, balance: balance, content: content) {
                _ = Reducer.apply(action, to: &state, balance: balance, content: content)
            }
            if state.gameOver != nil { return nil }
            // Past the nominal horizon, stop on the first day the brief
            // holds — that is what "day 400 with a build in launch week"
            // means when the build's timing is the engine's to decide.
            if day + 1 >= brief.days, brief.holds(state, balance, content) {
                return state
            }
        }
        return nil
    }

    /// The seeds each brief is pinned to. Found by `searchForSeeds` below.
    static let pinnedSeeds: [String: UInt64] = [
        "release-garage-day40": 3_115,
        "release-studio-day400": 3_461,
        "release-campus-day900": 2_769,
    ]

    static func encoded(_ state: GameState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(state)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["REGENERATE_RELEASE_FIXTURES"] != nil))
    func regenerateReleaseFixtures() throws {
        let balance = try BalanceConfig.loadBundled()
        let content = TestContent.bundled
        try FileManager.default.createDirectory(
            at: Self.fixturesDirectory, withIntermediateDirectories: true
        )
        for brief in Self.briefs() {
            let seed = try #require(Self.pinnedSeeds[brief.name])
            let state = try #require(
                Self.play(brief, seed: seed, balance: balance, content: content),
                "\(brief.name): seed \(seed) no longer produces \(brief.describes)"
            )
            let data = try Self.encoded(state)
            let url = Self.fixturesDirectory.appendingPathComponent("\(brief.name).json")
            try data.write(to: url)
            print(
                """
                \(brief.name): day \(state.day), \(state.company.officeTier.rawValue), \
                \(state.headcount) people, cash \(state.company.cash), \
                \(state.products.count) products, board \(state.investors.hasBoard), \
                \(data.count) bytes
                """
            )
        }
    }

    /// The committed files still are what the briefs say, and still
    /// decode on this branch.
    ///
    /// Not disabled, because this is the test that matters: the fixtures
    /// are a save format's worth of engine state sitting in the app
    /// bundle, and a field added without a default would break the
    /// screenshot pipeline silently — three black PNGs, noticed at
    /// submission. Regenerating is one command (above); knowing you have
    /// to is this.
    @Test func theCommittedFixturesStillDecodeAndStillMatchTheirBriefs() throws {
        let balance = try BalanceConfig.loadBundled()
        let content = TestContent.bundled
        for brief in Self.briefs() {
            let url = Self.fixturesDirectory.appendingPathComponent("\(brief.name).json")
            let data = try #require(
                try? Data(contentsOf: url), "\(brief.name).json is missing"
            )
            let state = try JSONDecoder().decode(GameState.self, from: data)
            #expect(
                brief.holds(state, balance, content),
                "\(brief.name) is no longer \(brief.describes) — regenerate it"
            )
            // And the bytes are exactly what the pinned seed replays, so
            // the file and the generator can never drift apart.
            let seed = try #require(Self.pinnedSeeds[brief.name])
            let replayed = try #require(
                Self.play(brief, seed: seed, balance: balance, content: content),
                "\(brief.name): seed \(seed) no longer produces \(brief.describes)"
            )
            #expect(
                try Self.encoded(replayed) == data,
                "\(brief.name): the committed file is not what seed \(seed) plays"
            )
        }
    }

    /// The search that found the pinned seeds. Prints every seed in the
    /// range that satisfies each brief; run it again if a brief changes.
    ///
    ///     SEARCH_RELEASE_FIXTURE_SEEDS=1 swift test --filter searchForSeeds
    @Test(.enabled(if: ProcessInfo.processInfo.environment["SEARCH_RELEASE_FIXTURE_SEEDS"] != nil))
    func searchForSeeds() throws {
        let balance = try BalanceConfig.loadBundled()
        let content = TestContent.bundled
        for brief in Self.briefs() {
            var found: [UInt64] = []
            for seed in stride(from: UInt64(1), through: 6_000, by: 173) {
                if let state = Self.play(brief, seed: seed, balance: balance, content: content) {
                    found.append(seed)
                    print(
                        "\(brief.name) seed \(seed): day \(state.day) "
                            + "\(state.company.officeTier.rawValue) "
                            + "\(state.headcount)p cash \(state.company.cash) "
                            + "board \(state.investors.hasBoard)"
                    )
                }
            }
            print("\(brief.name): \(found.count) seeds — \(found)")
        }
    }
}

