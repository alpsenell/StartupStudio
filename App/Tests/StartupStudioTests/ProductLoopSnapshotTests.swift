import SwiftUI
import TycoonEngine
import XCTest

@testable import StartupStudio

/// The product loop's new chrome: the pace control, the focus editor with
/// "Match the work", and the launch-day reason row, both themes.
@MainActor
final class ProductLoopSnapshotTests: XCTestCase {
    private var outputDirectory: URL {
        let path = ProcessInfo.processInfo.environment["PIXELKIT_PREVIEW_DIR"]
            ?? NSTemporaryDirectory() + "/startupstudio-previews"
        let url = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func engine() -> GameEngine {
        GameEngine.newGame(
            companyName: "Northgate Softworks",
            seed: 4242,
            difficulty: .normal,
            founder: FounderProfile(name: "Mira Okafor", archetype: .hacker, appearanceSeed: 0x5EED)
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

    func testThePaceControlAndPill() {
        let engine = engine()
        engine.send(.setWorkPace(.crunch))
        snapshot("product_pace_control") {
            CardView("Progress", systemImage: "chart.bar.fill") {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    WorkPacePill(pace: engine.state.economy.workPace)
                    WorkPaceControl(engine: engine, compact: true)
                }
            }
            .environment(GameShell())
            .environment(AppRouter())
        }
    }

    func testTheFocusEditorOffersToMatchTheWork() throws {
        let engine = engine()
        let type = try XCTUnwrap(engine.content.productTypes.first)
        struct Host: View {
            @State var focus: PhaseFocus = .balanced
            let matching: PhaseFocus
            var body: some View {
                CardView("Focus", systemImage: "slider.horizontal.3") {
                    FocusEditor(focus: $focus, matching: matching)
                }
            }
        }
        let progress = DevProgress(designPts: type.designPts, codePts: 10, polishPts: 0, openBugs: 0, focus: .balanced, hype: 0)
        let matching = PhaseFocus.matching(progress: progress, type: type)
        XCTAssertEqual(matching.design, 0, "a full pool gets no weight")
        snapshot("product_focus_match") {
            Host(matching: matching)
        }
    }

    func testTheLaunchReasonRowNamesTheFix() {
        let crew = LaunchForecast(
            crewCeiling: 0.61, skillCeiling: 0.61, codebaseCeiling: 1, topicFit: 1, bugFactor: 1, marketScale: 1,
            limitingFactor: "Your crew caps this at 61. Better people, not more time."
        )
        XCTAssertEqual(crew.fix, .hiring)
        let bugs = LaunchForecast(
            crewCeiling: 0.98, skillCeiling: 0.98, codebaseCeiling: 1, topicFit: 1, bugFactor: 0.88, marketScale: 1,
            limitingFactor: "Open bugs are costing 12% of the score."
        )
        XCTAssertEqual(bugs.fix, .bugs)
        snapshot("launch_reason") {
            VStack(spacing: Theme.Spacing.md) {
                LaunchReasonRow(reason: crew.limitingFactor!, fix: crew.fix, productID: nil) { _ in }
                LaunchReasonRow(reason: bugs.limitingFactor!, fix: bugs.fix, productID: UUID()) { _ in }
            }
        }
    }

    func testThePreStartForecastExistsForEveryUnlockedType() {
        let engine = engine()
        for type in engine.content.productTypes
        where engine.state.isProductTypeUnlocked(type.id, content: engine.content) {
            let forecast = ShipForecast.preStart(
                typeID: type.id, topicID: nil, codebaseID: nil,
                state: engine.state, balance: engine.balance, content: engine.content
            )
            XCTAssertNotNil(forecast, "no pre-start forecast for \(type.name)")
            XCTAssertGreaterThan(forecast?.quality ?? 0, 0)
        }
    }
}
