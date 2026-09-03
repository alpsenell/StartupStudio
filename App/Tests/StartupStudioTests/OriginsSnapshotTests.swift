import SwiftUI
import TycoonContent
import TycoonEngine
import XCTest

@testable import StartupStudio

/// The Stakes page with its four origins above the difficulty rows, the
/// biography's first line naming the origin, and the day-0 Now card for
/// each start — both themes.
@MainActor
final class OriginsSnapshotTests: XCTestCase {
    private var outputDirectory: URL {
        let path = ProcessInfo.processInfo.environment["PIXELKIT_PREVIEW_DIR"]
            ?? NSTemporaryDirectory() + "/startupstudio-previews"
        let url = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func engine(_ origin: FoundingOrigin) -> GameEngine {
        GameEngine.newGame(
            companyName: "Northgate Softworks",
            seed: 4242,
            difficulty: .normal,
            founder: FounderProfile(name: "Mira Okafor", archetype: .hacker, appearanceSeed: 0x5EED),
            origin: origin
        )
    }

    private func snapshot(
        _ name: String,
        width: CGFloat = 393,
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

    // MARK: - The Stakes page

    func testTheStakesPageOffersFourOriginsAboveTheDifficultyRows() {
        XCTAssertEqual(FoundingOrigin.allCases.count, 4)
        snapshot("stakes_page_origins") {
            StakesStepContent(origin: .constant(.cofounded), difficulty: .constant(.normal))
        }
    }

    func testTheFounderSetupSheetCarriesTheSamePicker() {
        snapshot("origin_picker_in_card") {
            CardView("How it starts", systemImage: "flag.fill") {
                OriginPicker(origin: .constant(.spinOut), rowsAreCards: false)
            }
        }
    }

    // MARK: - The biography's first line

    func testTheBiographyNamesTheOrigin() throws {
        let engine = engine(.cofounded)
        XCTAssertNotNil(engine.state.cofounder)
        // `GameOverInfo`'s initializer is the engine's own; a decoded one
        // is the same value the reducer would have written.
        let info = try JSONDecoder().decode(
            GameOverInfo.self,
            from: Data(#"{"day":120,"reason":"The bank stopped answering the phone.","kind":"bankruptcy"}"#.utf8)
        )
        XCTAssertEqual(engine.state.origin.biographyLine, "Started with a co-founder who owned a third of it.")
        // The banner alone: `ImageRenderer` cannot lay out the screen's
        // scroll view, and the origin line lives in the banner.
        snapshot("biography_origin_line") {
            FounderBiographyView(engine: engine, info: info, onNewGame: { _, _, _ in }).banner
        }
    }

    // MARK: - Day 0 on HQ

    func testTheNowCardSaysWhatTheOriginPutOnTheDesk() {
        for origin in FoundingOrigin.allCases {
            snapshot("now_card_day0_\(origin.rawValue)") {
                NowCard(engine: engine(origin), startNewProduct: {})
                    .environment(AppRouter())
                    .environment(GameShell())
            }
        }
    }

    // MARK: - The origin reaches the session and survives a replay

    func testReplayKeepsTheOrigin() {
        let ended = engine(.mortgaged)
        let again = GameEngine.newGame(
            companyName: ended.state.company.name,
            seed: ended.state.seed,
            difficulty: ended.state.difficulty,
            founder: ended.state.progression.founder,
            origin: ended.state.origin
        )
        XCTAssertEqual(again.state.origin, .mortgaged)
        XCTAssertEqual(again.state, ended.state)
        XCTAssertEqual(again.state.loanBalance, 25_000)
        XCTAssertEqual(again.state.life.home, .apartment)
    }
}
