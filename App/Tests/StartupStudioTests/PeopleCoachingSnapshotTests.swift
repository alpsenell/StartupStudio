import SwiftUI
import TycoonEngine
import XCTest

@testable import StartupStudio

/// People at a glance and coaching that ends in a sentence: the status
/// rules, the ghost marks on the skill bars, the report's next action, the
/// post-mortem and the ending screen, both themes.
@MainActor
final class PeopleCoachingSnapshotTests: XCTestCase {
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

    /// A fresh company ticked with no product until it goes under.
    private func bankruptEngine() -> GameEngine {
        let fresh = engine()
        var state = fresh.state
        var days = 0
        while state.gameOver == nil, days < 600 {
            _ = Reducer.tick(&state, balance: fresh.balance, content: fresh.content)
            days += 1
        }
        return GameEngine.resume(state: state)
    }

    func testAFreshRosterHasNothingToSay() {
        let engine = engine()
        XCTAssertTrue(EmployeeStatus.roster(in: engine.state, balance: engine.balance, content: engine.content).isEmpty)
        XCTAssertEqual(EmployeeStatus.attentionCount(in: engine.state, balance: engine.balance, content: engine.content), 0)
    }

    func testSkillBarsCarryTheRostersBestAsATick() {
        snapshot("skill_bars_reference") {
            VStack(spacing: Theme.Spacing.md) {
                SkillBars(skills: SkillSet(coding: 62, design: 35, marketing: 20),
                          reference: SkillSet(coding: 40, design: 30, marketing: 20))
                SkillBars(skills: SkillSet(coding: 20, design: 71, marketing: 55),
                          reference: SkillSet(coding: 40, design: 30, marketing: 20))
            }
        }
    }

    func testTheReportsNextActionFollowsTheFirstGoal() {
        let fresh = engine()
        var state = fresh.state
        _ = Reducer.tick(&state, balance: fresh.balance, content: fresh.content)
        let next = WeeklyReport.nextAction(for: state, balance: fresh.balance)
        XCTAssertNotNil(next)
        XCTAssertEqual(next?.route, .newProduct(topicID: nil))
        XCTAssertTrue(next?.text.contains("no income") ?? false, next?.text ?? "")
    }

    func testThePostMortemNamesWhatWentWrong() {
        let engine = bankruptEngine()
        XCTAssertNotNil(engine.state.gameOver, "a company with no product goes under within the horizon")
        let lines = PostMortem.lines(for: engine.state, balance: engine.balance, weeklyBurn: engine.weeklyBurn)
        XCTAssertFalse(lines.isEmpty)
        XCTAssertEqual(lines.first?.id, "never-shipped")
        XCTAssertLessThanOrEqual(lines.count, 3)
        XCTAssertNotEqual(engine.state.seed, 0, "the seed is kept for the replay")
        // The biography's scroll view does not render in ImageRenderer; the
        // card does.
        snapshot("ending_post_mortem") {
            PostMortemCard(lines: lines)
        }
    }
}
