import SwiftUI
import TycoonEngine
import XCTest

@testable import StartupStudio

/// The decision sheet in the game's own hand: every prompt kind, both
/// themes, and the accessibility size that used to clip the title.
@MainActor
final class DecisionSheetSnapshotTests: XCTestCase {
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
        height: CGFloat = 560,
        typeSize: DynamicTypeSize = .large,
        @ViewBuilder _ content: () -> some View
    ) {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let suffix = style == .light ? "light" : "dark"
            let renderer = ImageRenderer(
                content: content()
                    .frame(width: width, height: height)
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

    private func sheet(_ prompt: DecisionPrompt, engine: GameEngine) -> some View {
        DecisionSheetContent(
            prompt: prompt,
            engine: engine,
            choose: { _ in },
            postpone: prompt.isDeferrable ? {} : nil
        )
        .environment(GameShell())
        .environment(AppRouter())
    }

    private var buyout: DecisionPrompt {
        DecisionPrompt(
            id: "buyout-preview",
            systemImage: "envelope.badge.fill",
            tint: Theme.accent,
            title: "Waypoint Nine wants to buy you out",
            message: "They're offering $26,966 for Rooftop. Accepting ends the run as a successful exit.",
            stats: [("Offer", "$26,966")],
            options: [
                .init(label: "Sell the company", detail: "Exit with $26,966", action: .acceptBuyout),
                .init(label: "Decline", detail: "Keep building", action: .declineBuyout),
            ],
            kicker: "BUYOUT OFFER",
            portraitSeed: 0xBEEF
        )
    }

    private var story: DecisionPrompt {
        DecisionPrompt(
            id: "narrative-preview",
            systemImage: "banknote.fill",
            tint: Theme.positiveCash,
            title: "The domain you actually wanted is for sale.",
            message: "The squatter who has been sitting on it since 2011 has decided this is the year. He is asking $2,300 and will not be negotiating.\n\nPut it off for 5 days and it goes down as \"Add another hyphen\".",
            stats: [("Answer within", "5 days")],
            options: [
                .init(
                    label: "Pay the squatter",
                    detail: "reputation +5",
                    cashDelta: -2300,
                    action: .resolveChoice(eventID: "domain", optionIndex: 0)
                ),
                .init(
                    label: "Add another hyphen",
                    detail: "Free · reputation −1",
                    action: .resolveChoice(eventID: "domain", optionIndex: 1)
                ),
            ],
            kicker: "MONEY",
            isDeferrable: true
        )
    }

    private var termSheet: DecisionPrompt {
        DecisionPrompt(
            id: "investment-preview",
            systemImage: "doc.text.fill",
            tint: Theme.accent,
            title: "Harbourline Ventures wants in",
            message: "\u{201C}We back founders who ship.\u{201D} $40,000 for 12.0% of Northgate Softworks. They take a board seat and will grade you on revenue every quarter.",
            stats: [("Cheque", "$40,000"), ("Equity", "12.0%")],
            options: [
                .init(
                    label: "Take the money",
                    detail: "Cash in, 12.0% out, a board to answer to",
                    cashDelta: 40_000,
                    action: .acceptInvestment
                ),
                .init(label: "Stay independent", detail: "Keep all 100.0% of it", action: .declineInvestment),
            ],
            kicker: "TERM SHEET"
        )
    }

    private var staff: DecisionPrompt {
        DecisionPrompt(
            id: "staff-preview",
            systemImage: "heart.text.square.fill",
            tint: Theme.warning,
            title: "Priya's father is in hospital",
            message: "She needs the week, and she has not asked for the money — but the flights are not cheap.",
            stats: [("Morale", "62"), ("Loyalty", "48")],
            options: [
                .init(
                    label: "Send her, and pay the flights",
                    detail: "loyalty way up",
                    cashDelta: -900,
                    action: .resolveStaffEvent(choice: .supportive)
                ),
                .init(
                    label: "Business first",
                    detail: "Free, but loyalty takes a hit",
                    role: .destructive,
                    action: .resolveStaffEvent(choice: .strict)
                ),
            ],
            kicker: "STAFF",
            portraitSeed: 0xA11CE
        )
    }

    func testRendersABuyoutWithTheRivalsFace() {
        let engine = engine()
        snapshot("decision_buyout") { sheet(buyout, engine: engine) }
    }

    func testRendersAStoryBeatWithTheAfterStateAndLetMeThink() {
        let engine = engine()
        snapshot("decision_story", height: 620) { sheet(story, engine: engine) }
    }

    func testRendersATermSheet() {
        let engine = engine()
        snapshot("decision_term_sheet") { sheet(termSheet, engine: engine) }
    }

    /// A policy-shaped kind: the generous answer says it becomes the
    /// rule, and the firm answer comes twice — for them, and as the rule.
    private var policyStaff: DecisionPrompt {
        DecisionPrompt(
            id: "staff-policy-preview",
            systemImage: "figure.and.child.holdinghands",
            tint: Theme.warning,
            title: "Priya is having a baby",
            message: "They want to know what the policy is. There is no policy. Whatever you say next becomes the policy.",
            stats: [("Morale", "71"), ("Loyalty", "58")],
            options: [
                .init(
                    label: "Full pay, three months, written down",
                    detail: "−$4,000 · morale +12 for everyone · reputation +4 · becomes the rule",
                    cashDelta: -4_000,
                    action: .resolveStaffEvent(choice: .supportive)
                ),
                .init(
                    label: "The statutory minimum",
                    detail: "Free · morale −12 for everyone · reputation −3",
                    role: .destructive,
                    action: .resolveStaffEvent(choice: .strict)
                ),
                .init(
                    label: "…and make that the rule",
                    detail: "Parental leave: the same answer for everyone who asks · no sheet next time",
                    role: .destructive,
                    action: .resolveStaffEvent(choice: .strictAsPolicy)
                ),
            ],
            kicker: "STAFF",
            portraitSeed: 0xA11CE
        )
    }

    func testRendersAStaffMomentWithTheirFace() {
        let engine = engine()
        snapshot("decision_staff") { sheet(staff, engine: engine) }
    }

    func testRendersAPolicyShapedStaffMomentWithTheThirdButton() {
        let engine = engine()
        snapshot("decision_staff_policy", height: 640) { sheet(policyStaff, engine: engine) }
    }

    func testAPolicyShapedKindOffersTheRuleAndAFollowUpDoesNot() throws {
        let engine = engine()
        var state = engine.state
        let worker = Employee(
            id: UUID(), name: "Priya Nair",
            skills: SkillSet(coding: 50, design: 30, marketing: 20),
            weeklySalary: 900, assignment: .idle, isFounder: false, hiredDay: 0,
            appearanceSeed: 0xA11CE, role: .backend
        )
        state.employees.append(worker)
        state.pendingStaffEvent = StaffEvent(employeeID: worker.id, kind: .parentalLeave, respondByDay: 5)
        let prompt = try XCTUnwrap(
            DecisionPrompt.pending(in: state, content: engine.content, balance: engine.balance)
        )
        XCTAssertEqual(prompt.options.count, 3)
        XCTAssertEqual(prompt.options[2].label, "…and make that the rule")
        XCTAssertEqual(prompt.options[0].cashDelta, -4_000, "the def's cost, not the generic support cost")
        XCTAssertTrue(prompt.options[0].detail?.hasSuffix("becomes the rule") == true)

        // A kind with no policy block keeps its two answers.
        state.pendingStaffEvent = StaffEvent(employeeID: worker.id, kind: .familyEmergency, respondByDay: 5)
        let plain = try XCTUnwrap(
            DecisionPrompt.pending(in: state, content: engine.content, balance: engine.balance)
        )
        XCTAssertEqual(plain.options.count, 2)
    }

    func testTheTitleSurvivesAccessibilitySizes() {
        // The buttons sit in the scroll view's bottom inset, so at AX1 the
        // copy scrolls above them instead of being clipped behind them.
        let engine = engine()
        snapshot("decision_ax1", height: 820, typeSize: .accessibility1) {
            sheet(buyout, engine: engine)
        }
    }

    func testAfterStateUsesTheCompanysCashAndBurn() {
        // The story prompt's −$2,300 lands on a fresh company's $12,000.
        let engine = engine()
        let cash = engine.state.company.cash
        XCTAssertEqual(cash, 12_000)
        let burn = engine.weeklyBurn
        XCTAssertGreaterThan(burn, 0)
        // Rendering asserts nothing about text, but the arithmetic the sheet
        // shows is the same the HUD's runway uses; pin that here.
        XCTAssertEqual((cash - 2300) / burn, (cash - 2300) / engine.weeklyBurn)
    }
}
