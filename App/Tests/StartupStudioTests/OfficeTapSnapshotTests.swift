import PixelKit
import SwiftUI
import TycoonContent
import TycoonEngine
import XCTest

@testable import StartupStudio

/// The office as the interface: the card with a pressed person and a
/// pressed prop, the first-time hint, the coffee machine's menu, and the
/// map from what was tapped to what opens.
@MainActor
final class OfficeTapSnapshotTests: XCTestCase {
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

    /// Far enough in for the candidate pool to have refreshed (every
    /// fortnight), and one hire made, so there is somebody besides the
    /// founder to press and to take out for a coffee.
    private func engineWithAHire() -> GameEngine {
        let fresh = engine()
        var state = fresh.state
        var days = 0
        while state.candidatePool.isEmpty && days < 30 {
            _ = Reducer.tick(&state, balance: fresh.balance, content: fresh.content)
            days += 1
        }
        let resumed = GameEngine.resume(state: state)
        if let candidate = resumed.state.candidatePool.first {
            resumed.send(.hire(candidateID: candidate.id))
        }
        return resumed
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

    // MARK: - Snapshots

    func testAPressedPersonIsOutlined() {
        let engine = engineWithAHire()
        let hire = engine.state.employees.first { !$0.isFounder }
        XCTAssertNotNil(hire, "the fixture hires somebody")
        let pressed = OfficeHitRegion.Kind.person((hire ?? engine.state.employees[0]).id)
        snapshot("office_card_pressed_person") {
            OfficeCard(engine: engine, pressedForPreview: pressed)
                .environment(AppRouter())
                .environment(GameShell())
        }
    }

    func testAPressedPropIsOutlined() {
        let engine = engine()
        snapshot("office_card_pressed_whiteboard") {
            OfficeCard(engine: engine, pressedForPreview: .whiteboard)
                .environment(AppRouter())
                .environment(GameShell())
        }
        snapshot("office_card_pressed_coffee") {
            OfficeCard(engine: engine, pressedForPreview: .coffeeMachine)
                .environment(AppRouter())
                .environment(GameShell())
        }
    }

    func testTheHintShowsTheFirstTime() {
        snapshot("office_card_tap_hint") {
            OfficeCard(engine: engine(), showsTapHintForPreview: true)
                .environment(AppRouter())
                .environment(GameShell())
        }
    }

    func testTheCoffeeMachineMenuListsDinnerAndEveryoneHired() {
        let engine = engineWithAHire()
        snapshot("office_coffee_menu") {
            CoffeeMachineMenu(engine: engine)
                .environment(GameShell())
        }
    }

    // MARK: - The map

    func testTapsGoWhereTheDocSays() {
        let engine = engineWithAHire()
        let state = engine.state
        func destination(_ kind: OfficeHitRegion.Kind) -> OfficeTapDestination? {
            OfficeTapDestination.destination(for: kind, state: state)
        }

        let founder = try! XCTUnwrap(state.employees.first { $0.isFounder })
        XCTAssertEqual(destination(.person(founder.id)), .work, "the founder's levers are the work schedule")
        if let hire = state.employees.first(where: { !$0.isFounder }) {
            XCTAssertEqual(destination(.person(hire.id)), .person(hire.id), "anyone else opens their page")
        }
        XCTAssertNil(destination(.person(UUID())), "somebody who has left opens nothing")
        XCTAssertEqual(destination(.coffeeMachine), .coffee)
        XCTAssertEqual(destination(.door), .hiring)
        XCTAssertEqual(destination(.founderDesk), .work)
        XCTAssertEqual(destination(.whiteboard), .newProduct, "nothing in development yet")

        // With a build in flight, the whiteboard opens it.
        let type = try! XCTUnwrap(engine.content.productTypes.first {
            engine.state.isProductTypeUnlocked($0.id, content: engine.content)
        })
        let topic = try! XCTUnwrap(engine.content.topics.first)
        engine.send(.startProduct(typeID: type.id, topicID: topic.id, name: "Overcast", focus: .balanced))
        let product = try! XCTUnwrap(engine.state.productInDevelopment)
        XCTAssertEqual(
            OfficeTapDestination.destination(for: .whiteboard, state: engine.state),
            .product(product.id)
        )
        XCTAssertEqual(
            OfficeTapDestination.accessibilityHint(for: .whiteboard, state: engine.state),
            "Opens Overcast"
        )
    }

    func testEveryRegionKindHasAHintForVoiceOver() {
        let state = engineWithAHire().state
        for kind in [OfficeHitRegion.Kind.coffeeMachine, .whiteboard, .door, .founderDesk] {
            XCTAssertNotNil(OfficeTapDestination.accessibilityHint(for: kind, state: state), "\(kind)")
        }
        let founder = try! XCTUnwrap(state.employees.first { $0.isFounder })
        XCTAssertEqual(
            OfficeTapDestination.accessibilityHint(for: .person(founder.id), state: state),
            "Opens the work schedule"
        )
    }
}
