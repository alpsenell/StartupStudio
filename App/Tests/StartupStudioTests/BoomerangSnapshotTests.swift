import SwiftUI
import TycoonContent
import TycoonEngine
import UIKit
import XCTest

@testable import StartupStudio

/// The boomerang's two surfaces: the address-book row for somebody who
/// used to work here, and the contact sheet's header saying who they were.
/// Both appearances.
///
/// Same contract as `SnapshotTests`: review artifacts, not pixel baselines.
/// What they catch is a row that renders empty or a header that lays out
/// unreadably once there is a real alum behind it — so the alumni here are
/// made through the engine's own exits (a firing, a poach), not props.
@MainActor
final class BoomerangSnapshotTests: XCTestCase {
    private var outputDirectory: URL {
        let path = ProcessInfo.processInfo.environment["PIXELKIT_PREVIEW_DIR"]
            ?? NSTemporaryDirectory() + "/startupstudio-previews"
        let url = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// A run in September where three people left in March: Marco, let go
    /// on good terms; Priya, poached, a showman who has since founded
    /// something; and Yusuf, let go with no bond to speak of — burned.
    private func scene() -> (engine: GameEngine, marco: UUID, priya: UUID) {
        let seed = GameEngine.newGame(
            companyName: "Northgate Softworks",
            seed: 4242,
            difficulty: .normal,
            founder: FounderProfile(name: "Mira Okafor", archetype: .hacker, appearanceSeed: 0x5EED)
        )
        var state = seed.state
        state.life.wallet = 40_000
        state.company.cash = 90_000

        let showman = (0..<20_000).first {
            TraitEffects.derivedTraitIDs(appearanceSeed: UInt64($0)).contains("showman")
        } ?? 0
        let marco = employee("Marco Reyes", role: .backend, bond: 62, appearanceSeed: 0xBEEF)
        let priya = employee("Priya Shah", role: .designer, bond: 48, appearanceSeed: UInt64(showman))
        let yusuf = employee("Yusuf Demir", role: .marketer, bond: 8, appearanceSeed: 0xFACE)
        state.employees.append(contentsOf: [marco, priya, yusuf])

        // March.
        state.day = 75
        Reducer.apply(.fire(employeeID: marco.id), to: &state, balance: seed.balance, content: seed.content)
        state.rivals.pendingPoach = PoachOffer(
            rivalID: UUID(), employeeID: priya.id, offeredWeeklySalary: 1_640, respondByDay: 78
        )
        Reducer.apply(.declinePoachOffer, to: &state, balance: seed.balance, content: seed.content)
        Reducer.apply(.fire(employeeID: yusuf.id), to: &state, balance: seed.balance, content: seed.content)

        // September: half a year on, Priya has founded something.
        state.day = 262
        Reducer.tick(&state, balance: seed.balance, content: seed.content)

        return (GameEngine(state: state, balance: seed.balance, content: seed.content), marco.id, priya.id)
    }

    private func employee(_ name: String, role: EmployeeRole, bond: Double, appearanceSeed: UInt64) -> Employee {
        Employee(
            id: UUID(),
            name: name,
            skills: SkillSet(coding: 64, design: 41, marketing: 33),
            weeklySalary: 1_100,
            assignment: .idle,
            isFounder: false,
            hiredDay: 12,
            appearanceSeed: appearanceSeed,
            morale: 66,
            level: .mid,
            loyalty: 55,
            role: role,
            founderBond: bond
        )
    }

    private func snapshot(
        _ name: String,
        width: CGFloat = 393,
        @ViewBuilder _ content: () -> some View
    ) {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let suffix = style == .light ? "light" : "dark"
            let sized = content()
                .frame(width: width)
                .background(Theme.screenBackground)
                .environment(\.colorScheme, style == .light ? .light : .dark)
            let renderer = ImageRenderer(content: sized)
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

    func testTheAddressBookRowSaysWhoTheyWere() throws {
        let (engine, marcoID, priyaID) = scene()
        let marco = try XCTUnwrap(engine.state.networking.contact(marcoID))
        let priya = try XCTUnwrap(engine.state.networking.contact(priyaID))

        // The row's two halves, read off the same helpers the row uses.
        XCTAssertEqual(AlumniCopy.leftLine(marco, today: engine.state.day), "Left in March")
        XCTAssertEqual(AlumniCopy.formerRole(marco), "was your backend dev")
        XCTAssertEqual(AlumniCopy.reasonLine(priya, today: engine.state.day), "poached in March")
        XCTAssertEqual(priya.askingSalary, 1_640, "a poached alum asks for the number they left for")
        XCTAssertTrue(priya.runsACompany, "a showman founds something inside six months")
        // Three left; one of them is history.
        XCTAssertEqual(engine.state.networking.contacts.count(where: \.isAlumnus), 3)
        XCTAssertEqual(engine.state.networking.contacts.count { $0.outcome == .lost }, 1)

        snapshot("address_book_alumni") {
            AddressBookSheet(engine: engine).content
                .environment(GameShell())
        }
    }

    func testTheContactSheetHeaderSaysWhoTheyWere() throws {
        let (engine, marcoID, priyaID) = scene()
        XCTAssertEqual(engine.state.networking.contact(marcoID)?.leftReason, .fired)

        snapshot("contact_sheet_alum") {
            ContactSheet(engine: engine, contactID: marcoID).content
                .environment(GameShell())
        }
        snapshot("contact_sheet_alum_founder") {
            ContactSheet(engine: engine, contactID: priyaID).content
                .environment(GameShell())
        }
    }
}
