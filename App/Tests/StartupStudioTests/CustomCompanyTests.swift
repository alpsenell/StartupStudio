import SwiftUI
import TycoonContent
import TycoonEngine
import XCTest

@testable import StartupStudio

/// Iteration 7 (R4): the custom page and the locks as pictures, and the
/// custom company's plumbing through the session — a typed code and the
/// ending's *Run it back* found the same first month, a custom page left
/// alone founds a standard company, and a URL parks its code.
@MainActor
final class CustomCompanyTests: XCTestCase {
    private var outputDirectory: URL {
        let path = ProcessInfo.processInfo.environment["PIXELKIT_PREVIEW_DIR"]
            ?? NSTemporaryDirectory() + "/startupstudio-previews"
        let url = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func snapshot(
        _ name: String,
        width: CGFloat = 393,
        typeSize: DynamicTypeSize = .large,
        @ViewBuilder _ content: () -> some View
    ) {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let suffix = style == .light ? "light" : "dark"
            let renderer = ImageRenderer(
                content: content()
                    .padding(Theme.Spacing.lg)
                    .frame(width: width)
                    .background(Theme.screenBackground)
                    .environment(\.colorScheme, style == .light ? .light : .dark)
                    .environment(\.dynamicTypeSize, typeSize)
            )
            renderer.scale = 2
            guard let image = renderer.uiImage, let data = image.pngData() else {
                XCTFail("failed to render \(name) (\(suffix))")
                continue
            }
            XCTAssertGreaterThan(data.count, 512, "\(name) (\(suffix)) rendered empty")
            let url = outputDirectory.appendingPathComponent("\(name)_\(suffix).png")
            XCTAssertNoThrow(try data.write(to: url), "could not write \(url.path)")
        }
    }

    private func makeTempDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("R4Custom-\(UUID().uuidString)", isDirectory: true)
    }

    // MARK: - Pictures

    func testTheCustomPageRenders() {
        var choices = CustomChoices()
        choices.difficulty = .hard
        choices.incumbentEnabled = false
        snapshot("custom_page") {
            CustomStepContent(choices: .constant(choices), defaultCash: DifficultyCash.startingCash(for:))
        }
        var prefilled = CustomChoices()
        _ = prefilled.prefill(with: SeedCode(seed: 0xDEAD_BEEF, origin: .spinOut, difficulty: .hard))
        prefilled.startingCash = 120_000
        snapshot("custom_page_from_code") {
            CustomStepContent(choices: .constant(prefilled), defaultCash: DifficultyCash.startingCash(for:))
        }
        // The accessibility sizes: the page holds at AX3 whole, and at AX5
        // the two cards with the pixel labels (a whole page at AX5 is
        // taller than the PNG encoder takes).
        snapshot("custom_page_ax3", typeSize: .accessibility3) {
            CustomStepContent(choices: .constant(prefilled), defaultCash: DifficultyCash.startingCash(for:))
        }
        snapshot("seed_field_ax5", typeSize: .accessibility5) {
            CardView("Seed", systemImage: "number") {
                SeedCodeField(text: .constant(SeedCode(seed: 0xDEAD_BEEF, origin: .spinOut, difficulty: .hard).encoded))
            }
        }
    }

    func testTheMortgagedOriginIsPadlockedUntilAnEnding() {
        XCTAssertEqual(Unlocks.lockedOrigins(endingsReached: []), [.mortgaged])
        XCTAssertEqual(Unlocks.lockedOrigins(endingsReached: [.bankruptcy]), [])
        snapshot("stakes_page_padlock") {
            StakesStepContent(
                origin: .constant(.garage), difficulty: .constant(.normal),
                showsDifficulty: false, lockedOrigins: [.mortgaged]
            )
        }
        snapshot("origin_row_padlock") {
            OriginRow(origin: .mortgaged, isSelected: false, isLocked: true) {}
                .cardStyle()
        }
    }

    func testTheEarnedLooksAreSixDistinctFacesWithRibbons() {
        XCTAssertEqual(Unlocks.earnedLooks.count, 6)
        let seeds = Set(Unlocks.earnedLooks.map(\.seed))
        XCTAssertEqual(seeds.count, 6, "every ending's look is its own seed")
        XCTAssertTrue(seeds.isDisjoint(with: NewGameFlow.appearanceSeeds), "an earned look is not one of the 24")
        XCTAssertEqual(Unlocks.earnedLookSeeds(endingsReached: []).count, 0)
        XCTAssertEqual(Unlocks.earnedLookSeeds(endingsReached: [.ipo, .bankruptcy]).map(\.ending), [.bankruptcy, .ipo])
        snapshot("earned_looks") {
            VStack(spacing: Theme.Spacing.md) {
                ForEach(Unlocks.earnedLooks, id: \.seed) { look in
                    HStack(spacing: Theme.Spacing.md) {
                        PixelPortrait(seed: look.seed, isFounder: true, size: 72)
                        EarnedLookRibbon(ending: look.ending)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    func testTheSeedFieldAndTheCodeSheetRender() {
        let code = SeedCode(seed: 0xDEAD_BEEF, origin: .spinOut, difficulty: .hard)
        snapshot("seed_field_states") {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                SeedCodeField(text: .constant(""))
                SeedCodeField(text: .constant(code.encoded))
                SeedCodeField(text: .constant("4242"))
                SeedCodeField(text: .constant("not a code"))
            }
        }
    }

    // MARK: - Choices

    func testChoicesLeftAloneAreAStandardCompany() {
        let choices = CustomChoices()
        let cash = DifficultyCash.startingCash(for: .normal)
        XCTAssertEqual(choices.rules(defaultCash: cash), .standard)
        XCTAssertEqual(choices.mode(defaultCash: cash), .standard)
        XCTAssertNil(choices.entry.seed)

        var typed = choices
        typed.seedText = "4242"
        XCTAssertEqual(typed.mode(defaultCash: cash), .custom)
        XCTAssertEqual(typed.rules(defaultCash: cash), .standard)

        var cashMoved = choices
        cashMoved.startingCash = cash
        XCTAssertEqual(cashMoved.mode(defaultCash: cash), .standard, "the difficulty's own cash is not an override")
        cashMoved.startingCash = cash + 10_000
        XCTAssertEqual(cashMoved.mode(defaultCash: cash), .custom)
        XCTAssertEqual(cashMoved.rules(defaultCash: cash).startingCash, cash + 10_000)

        var noRivals = choices
        noRivals.rivalsEnabled = false
        XCTAssertEqual(noRivals.mode(defaultCash: cash), .custom)
    }

    func testTheDifficultysOwnCashIsTheEnginesCash() {
        for difficulty in Difficulty.allCases {
            let engine = GameEngine.newGame(companyName: "Cash", seed: 1, difficulty: difficulty)
            XCTAssertEqual(DifficultyCash.startingCash(for: difficulty), engine.state.company.cash, "\(difficulty)")
        }
    }

    // MARK: - The session

    func testATypedCodeAndRunItBackFoundTheSameFirstMonth() {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        let profile = FounderProfile(name: "Mira Okafor", archetype: .hacker, appearanceSeed: 0x5EED)

        // The friend's run, ended; its card would carry this code.
        session.beginNewGame(inSlot: 0)
        session.startNewGame(profile: profile, companyName: "Twice", difficulty: .hard, origin: .spinOut)
        let ended = session.engine.state
        let code = SeedCode(seed: ended.seed, origin: ended.origin, difficulty: ended.difficulty)

        // Run it back on the friend's phone.
        session.replayCurrentGame()
        var replayed = session.engine.state
        let balance = session.engine.balance
        let content = session.engine.content
        for _ in 0..<28 { _ = Reducer.tick(&replayed, balance: balance, content: content) }

        // The code typed into another install.
        let other = GameSession(saveDirectory: makeTempDirectory(), slot: 0, remembersSlot: false)
        let decoded = SeedCode.decode(code.encoded)!
        other.beginCustomGame(code: decoded)
        XCTAssertTrue(other.needsOnboarding)
        XCTAssertTrue(other.newGameOptions.showsCustomStep)
        XCTAssertEqual(other.newGameOptions.seedCode, decoded)
        var choices = CustomChoices()
        let origin = choices.prefill(with: decoded)
        let cash = DifficultyCash.startingCash(for: choices.difficulty)
        other.startNewGame(
            profile: profile, companyName: "Twice", difficulty: choices.difficulty, origin: origin,
            setup: RunSetup(seed: choices.entry.seed, rules: choices.rules(defaultCash: cash), mode: choices.mode(defaultCash: cash))
        )
        XCTAssertFalse(other.customGameRequested)
        XCTAssertNil(other.pendingSeedCode)
        var typed = other.engine.state
        XCTAssertEqual(typed.mode, .custom, "a typed code is a custom company")
        XCTAssertEqual(typed.seed, ended.seed)
        XCTAssertEqual(typed.origin, .spinOut)
        XCTAssertEqual(typed.difficulty, .hard)
        for _ in 0..<28 { _ = Reducer.tick(&typed, balance: other.engine.balance, content: other.engine.content) }

        XCTAssertEqual(typed.eventLog, replayed.eventLog)
        XCTAssertEqual(typed.candidatePool.map(\.name), replayed.candidatePool.map(\.name))
        XCTAssertEqual(typed.company.cash, replayed.company.cash)
        XCTAssertEqual(typed.rivals.rivals.map(\.name), replayed.rivals.rivals.map(\.name))
    }

    func testACustomPageLeftAloneFoundsARankedCompany() {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        session.beginCustomGame()
        XCTAssertTrue(session.newGameOptions.showsCustomStep)
        session.startNewGame(
            profile: FounderProfile(name: "Ada", archetype: .hacker), companyName: "Plain",
            difficulty: .normal, origin: .garage, setup: .standard
        )
        XCTAssertEqual(session.engine.state.mode, .standard)
        XCTAssertTrue(session.engine.state.isRanked)
        XCTAssertFalse(session.newGameOptions.showsCustomStep, "the request is spent")
    }

    func testRulesReachTheEngineAndTheSave() {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        session.beginCustomGame()
        let setup = RunSetup(seed: 7, rules: GameRules(rivalsEnabled: false, incumbentEnabled: false, startingCash: 300_000), mode: .custom)
        session.startNewGame(
            profile: FounderProfile(name: "Ada", archetype: .hacker), companyName: "Alone",
            difficulty: .hard, origin: .garage, setup: setup
        )
        XCTAssertEqual(session.engine.state.company.cash, 300_000)
        XCTAssertEqual(session.engine.balance.rivals.rivalCount, 0)
        XCTAssertFalse(session.engine.balance.rivals.depth.incumbentEnabled)
        XCTAssertEqual(session.engine.state.rules, setup.rules)
        XCTAssertFalse(session.engine.state.isRanked)

        // The rules come back with the save.
        let reopened = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        XCTAssertEqual(reopened.engine.state.rules, setup.rules)
        XCTAssertEqual(reopened.engine.balance.rivals.rivalCount, 0)
    }

    func testAURLParksItsCodeAndTheFlowPicksItUp() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        let code = SeedCode(seed: 55, origin: .cofounded, difficulty: .easy)
        XCTAssertTrue(session.handleOpenURL(try XCTUnwrap(GameSession.seedURL(for: code))))
        XCTAssertEqual(session.pendingSeedCode, code)
        XCTAssertFalse(session.needsOnboarding, "a URL parks the code; the row opens the page")
        XCTAssertTrue(session.newGameOptions.showsCustomStep)
        XCTAssertFalse(session.handleOpenURL(URL(string: "startupstudio://seed/garbage")!))
        XCTAssertEqual(session.pendingSeedCode, code, "a bad URL leaves the parked code alone")

        // The plain path forgets it.
        session.clearCustomGameRequest()
        XCTAssertNil(session.pendingSeedCode)
        XCTAssertFalse(session.newGameOptions.showsCustomStep)
    }

    func testTheTitleMenuOffersCustomAndFromCode() {
        let menu = TitleMenu.make(onDaily: {}, onCustom: {}, onFromCode: {})
        XCTAssertEqual(Set(menu.enabledRows.map(\.id)).intersection([.custom, .fromCode]), [.custom, .fromCode])
    }

    func testTheEndingsReachTheFlowsOptions() {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        XCTAssertEqual(session.newGameOptions.lockedOrigins, [.mortgaged])
        session.ledger.endingsReached = [.soldUp]
        XCTAssertEqual(session.newGameOptions.lockedOrigins, [])
        XCTAssertEqual(session.newGameOptions.endingsReached, [.soldUp])
    }
}
