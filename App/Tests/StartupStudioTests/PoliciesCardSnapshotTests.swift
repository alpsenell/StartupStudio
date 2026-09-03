import SwiftUI
import TycoonEngine
import XCTest

@testable import StartupStudio

/// *How we do things here*: the rules a founder's answers became, both
/// themes, and the words the reversal confirm uses.
@MainActor
final class PoliciesCardSnapshotTests: XCTestCase {
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

    private func worker(_ name: String, seed: UInt64) -> Employee {
        Employee(
            id: UUID(), name: name,
            skills: SkillSet(coding: 50, design: 30, marketing: 20),
            weeklySalary: 900, assignment: .idle, isFounder: false, hiredDay: 0,
            appearanceSeed: seed, role: .backend
        )
    }

    /// A studio in its second year with two rules: a generous leave policy
    /// that has answered for two people since, and a strict line on side
    /// projects.
    private func engineWithPolicies() -> GameEngine {
        let fresh = GameEngine.newGame(
            companyName: "Northgate Softworks",
            seed: 4242,
            difficulty: .normal,
            founder: FounderProfile(name: "Mira Okafor", archetype: .hacker, appearanceSeed: 0x5EED)
        )
        var state = fresh.state
        let priya = worker("Priya Nair", seed: 0xA11CE)
        let marco = worker("Marco Salvi", seed: 0xB0B)
        let yusuf = worker("Yusuf Demir", seed: 0xC0DE)
        state.employees.append(contentsOf: [priya, marco, yusuf])
        state.day = 400
        state.staffMemory.policies = [
            StaffPolicy(
                kind: .parentalLeave, flag: "good_leave_policy", choice: .supportive,
                setDay: 120, setBy: priya.id, setByName: priya.name,
                beneficiaries: [priya.id, marco.id]
            ),
            StaffPolicy(
                kind: .sideProject, flag: "ip_strict", choice: .strict,
                setDay: 310, setBy: yusuf.id, setByName: yusuf.name,
                beneficiaries: [yusuf.id]
            ),
        ]
        state.narrative.flags.formUnion(["good_leave_policy", "ip_strict"])
        return GameEngine.resume(state: state)
    }

    func testRendersTheRulesWithTheDayAndThePerson() {
        let engine = engineWithPolicies()
        snapshot("policies_card") { PoliciesCard(engine: engine) }
    }

    func testReversingThroughTheEngineFlipsTheFlagAndCostsTheBeneficiaries() {
        let engine = engineWithPolicies()
        let loyaltyBefore = engine.state.employees.map(\.loyalty)
        engine.send(.reverseStaffPolicy(flag: "good_leave_policy"))
        XCTAssertEqual(engine.state.staffMemory.policies.count, 1)
        XCTAssertFalse(engine.state.narrative.flags.contains("good_leave_policy"))
        XCTAssertTrue(engine.state.narrative.flags.contains("leave_statutory"))
        // Priya and Marco benefited; Yusuf did not.
        let after = engine.state.employees.map(\.loyalty)
        XCTAssertLessThan(after[1], loyaltyBefore[1])
        XCTAssertLessThan(after[2], loyaltyBefore[2])
        XCTAssertEqual(after[3], loyaltyBefore[3])
    }
}
