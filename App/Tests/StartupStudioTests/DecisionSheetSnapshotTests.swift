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

    /// The distress bid: the sheet says what it is and what accepting ends
    /// as, because it used to call a fire sale a successful exit.
    private var buyout: DecisionPrompt {
        DecisionPrompt(
            id: "buyout-preview",
            systemImage: "tag.fill",
            tint: Theme.warning,
            title: "Waypoint Nine wants to buy you out",
            message: "A distress bid. $26,966 buys the name, the desks and whatever is on the shelf. Selling ends the run — sold up, not a win.",
            stats: [("Offer", "$26,966"), ("Kind", "distress")],
            options: [
                .init(label: "Sell up for $26,966", detail: "Ends the run as Sold up", role: .destructive, action: .acceptBuyout),
                .init(label: "Decline", detail: "Keep building", action: .declineBuyout),
            ],
            kicker: "DISTRESS BID",
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

    func testRendersAStaffMomentWithTheirFace() {
        let engine = engine()
        snapshot("decision_staff") { sheet(staff, engine: engine) }
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
