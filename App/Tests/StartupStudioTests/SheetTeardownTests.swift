import SwiftUI
import TycoonContent
import TycoonEngine
import UIKit
import XCTest

@testable import StartupStudio

/// Iteration 7 (R5, fix 2) — the trap `StorefrontAutoRoute` documents.
///
/// A sheet's content is updated by SwiftUI *while its host is being torn
/// down*, and a non-optional `@Environment(AppRouter.self)` read traps
/// there. `LaunchDaySheet` and `MoneySheetContent` were the two sheets
/// still reading it that way; both now read it optionally, the way
/// `OfficeCard` has since iteration 6.
///
/// The test does the teardown for real — a hosted window, a presented
/// sheet, and `launchDayProductID` cleared out from under it — and draws
/// both sheets with no router in the environment at all, which is what
/// the inside of a torn-down host looks like.
@MainActor
final class SheetTeardownTests: XCTestCase {
    private func engineWithALaunch() -> (GameEngine, Product) {
        let engine = GameEngine.newGame(
            companyName: "Rooftop", seed: 4242, difficulty: .normal,
            founder: FounderProfile(name: "Mira Okafor", archetype: .hacker, appearanceSeed: 0x5EED)
        )
        var state = engine.state
        let product = Product(
            id: UUID(), name: "Overcast", typeID: "mobile_app", topicID: "fitness",
            stage: .released(ReleaseInfo(
                launchDay: state.day, quality: 71,
                reviews: ["TechDaily", "AppVerdict"].map {
                    Review(outlet: $0, score: 71, blurb: "Polished where it counts.")
                },
                weeklySales: [], offMarket: false
            ))
        )
        state.products.append(product)
        return (GameEngine.resume(state: state), product)
    }

    /// The host presents the sheet, then the id it was presented for is
    /// cleared from outside the view tree — the exact sequence a headless
    /// pass (and `GameShell` on the next tick) performs.
    private struct Host: View {
        let engine: GameEngine
        let shell: GameShell

        var body: some View {
            Color.clear
                .sheet(isPresented: Binding(
                    get: { shell.launchDayProductID != nil },
                    set: { presented in if !presented { shell.launchDayProductID = nil } }
                )) {
                    if let productID = shell.launchDayProductID,
                       let product = engine.state.product(id: productID) {
                        LaunchDaySheet(engine: engine, product: product)
                    }
                }
                .environment(shell)
        }
    }

    func testTheLaunchDaySheetSurvivesItsProductBeingClearedUnderIt() {
        let (engine, product) = engineWithALaunch()
        let shell = GameShell()
        shell.launchDayProductID = product.id

        let host = UIHostingController(rootView: Host(engine: engine, shell: shell))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        // Let the presentation commit.
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        XCTAssertNotNil(host.presentedViewController, "the sheet never went up")

        // Torn down from outside, the way the run does it.
        shell.launchDayProductID = nil
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        XCTAssertNil(shell.launchDayProductID)
        window.isHidden = true
    }

    /// Both sheets draw with no router installed. A non-optional
    /// `@Environment(AppRouter.self)` is a promise the environment always
    /// has one, and a closing sheet is where that promise breaks.
    func testBothSheetsDrawWithoutARouter() {
        let (engine, product) = engineWithALaunch()

        let launchDay = ImageRenderer(
            content: LaunchDaySheet(engine: engine, product: product)
                .environment(GameShell())
                .frame(width: 393, height: 852)
        )
        XCTAssertNotNil(launchDay.uiImage, "launch day needs a router to draw")

        let money = ImageRenderer(
            content: MoneySheetContent(engine: engine)
                .environment(GameShell())
                .frame(width: 393)
        )
        XCTAssertNotNil(money.uiImage, "the money sheet needs a router to draw")
    }
}
