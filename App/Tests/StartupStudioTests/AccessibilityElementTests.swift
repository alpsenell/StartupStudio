import PixelKit
import SwiftUI
import TycoonContent
import TycoonEngine
import XCTest

@testable import StartupStudio

/// R7's audit, at unit level: the list of things assistive technology can
/// reach in each of the scenes, written out as a text file beside the
/// snapshot PNGs so it can be read the way the images are.
///
/// `XCUIApplication.performAccessibilityAudit` would exercise the same
/// ground on a running app, but it needs a `bundle.ui-testing` target this
/// project does not have and a second scheme to run it. These assertions
/// are over the same element lists the overlays are built from — the ones
/// PixelKit and the screens hand to SwiftUI — so a district that stops
/// having a label fails here.
@MainActor
final class AccessibilityElementTests: XCTestCase {
    private var outputDirectory: URL {
        let path = ProcessInfo.processInfo.environment["PIXELKIT_PREVIEW_DIR"]
            ?? NSTemporaryDirectory() + "/startupstudio-previews"
        let url = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Writes one element list into the preview directory.
    private func dump(_ name: String, _ lines: [String]) {
        let text = ([name, String(repeating: "=", count: name.count)] + lines).joined(separator: "\n") + "\n"
        let url = outputDirectory.appendingPathComponent("a11y_elements_\(name).txt")
        XCTAssertNoThrow(try text.write(to: url, atomically: true, encoding: .utf8))
    }

    private func engine(days: Int = 60) -> GameEngine {
        let fresh = GameEngine.newGame(
            companyName: "Northgate Softworks",
            seed: 4242,
            difficulty: .normal,
            founder: FounderProfile(name: "Mira Okafor", archetype: .hacker, appearanceSeed: 0x5EED)
        )
        var state = fresh.state
        for _ in 0..<days { _ = Reducer.tick(&state, balance: fresh.balance, content: fresh.content) }
        return GameEngine.resume(state: state)
    }

    // MARK: - The home

    func testTheHomeReadsAsAHouseholdAndItsFurniture() {
        let occupants = HomeOccupants(
            founder: CharacterAppearance(seed: 0x5EED),
            founderName: "Mira Okafor",
            partner: CharacterAppearance(seed: 21),
            partnerName: "Sam Ross",
            partnerNote: "affection sliding",
            children: [
                HomeOccupants.Child(
                    id: UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!,
                    appearance: CharacterAppearance(seed: 31),
                    name: "Ada"
                ),
            ]
        )
        let view = HomeSceneView(
            tier: .house, occupants: occupants, activity: .dinner, mood: .low,
            signals: HomeSignals(relationshipsLow: true, healthLow: true, billsDue: true)
        )
        let regions = HomeSceneComposer.hitRegions(
            tier: .house, occupants: occupants, activity: .dinner, mood: .low,
            ambience: .evening,
            signals: HomeSignals(relationshipsLow: true, healthLow: true, billsDue: true)
        )
        let labels = regions.map { view.spokenLabel(for: $0.kind) }
        dump("home", [view.sceneSummary, "--"] + labels)

        XCTAssertTrue(labels.contains("Mira Okafor, at dinner, worn down"))
        XCTAssertTrue(labels.contains("Sam Ross, your partner, affection sliding"))
        XCTAssertTrue(labels.contains("Ada, your child"))
        XCTAssertTrue(labels.contains("The sofa"))
        XCTAssertTrue(labels.contains("The bed"))
        XCTAssertEqual(labels.count, Set(labels).count, "two things in the room read the same")
        // People first: a room whose first element is a lamp is a room
        // nobody can find their partner in.
        XCTAssertTrue(regions.prefix(3).allSatisfy { $0.kind.isPerson })
    }

    /// Every fixture the composer draws in every home has a name — the
    /// failure this guards is a new prop landing in the room with no word
    /// for it.
    func testEveryFixtureInEveryHomeIsNamed() {
        for tier in HomeTierStyle.allCases {
            for activity in HomeActivity.allCases {
                let regions = HomeSceneComposer.hitRegions(
                    tier: tier,
                    occupants: HomeOccupants(
                        founder: CharacterAppearance(seed: 1),
                        partner: CharacterAppearance(seed: 2),
                        children: [CharacterAppearance(seed: 3)]
                    ),
                    activity: activity,
                    mood: .low
                )
                for region in regions {
                    guard case .furniture(let fixture) = region.kind else { continue }
                    XCTAssertFalse(
                        fixture.accessibilityName.isEmpty,
                        "\(tier)/\(activity): \(fixture) has no name"
                    )
                }
            }
        }
    }

    // MARK: - The city map

    func testEveryCityDistrictAndTheOfficeMarkerAreReachable() {
        let engine = engine()
        let screen = CityMapScreen(engine: engine)
        var lines: [String] = []
        for district in DistrictID.allCases {
            lines.append(screen.districtLabel(district))
        }
        lines.append("Your office, \(engine.state.city.district.displayName)")
        dump("city_map", lines)

        XCTAssertEqual(lines.count, DistrictID.allCases.count + 1, "five districts and the office marker")
        for district in DistrictID.allCases {
            XCTAssertTrue(
                lines.contains { $0.hasPrefix(district.displayName) },
                "\(district.displayName) has no element"
            )
        }
        XCTAssertTrue(
            lines.contains { $0.contains("your office") },
            "the district the office is in does not say so"
        )
        // Every district's rect is somewhere a finger and a cursor can
        // find it, which is what the elements are laid out from.
        for district in DistrictID.allCases {
            guard let style = DistrictStyle(rawValue: district.rawValue) else {
                return XCTFail("\(district) has no map style")
            }
            let frame = CityMapComposer.districtFrame(style)
            XCTAssertEqual(
                CityMapComposer.hitTest(x: frame.x + frame.width / 2, y: frame.y + frame.height / 2),
                style
            )
        }
    }

    // MARK: - The market map

    func testEveryMarketDistrictCarriesAValueAndTheBiggestIsReadFirst() {
        let engine = engine()
        let snapshot = MarketMapSnapshot(
            state: engine.state, content: engine.content, balance: engine.balance
        )
        let districts = snapshot.input.districts
        XCTAssertEqual(districts.count, 12)

        var lines: [String] = []
        for district in districts.sorted(by: {
            MarketMapView<EmptyView>.sortPriority($0) > MarketMapView<EmptyView>.sortPriority($1)
        }) {
            let summary = snapshot.summaries[district.id] ?? district.name
            lines.append("\(summary)  —  \(district.accessibilityValue)")
            XCTAssertFalse(district.accessibilityValue.isEmpty, "\(district.name) has no value")
        }
        dump("market_map", lines)

        // The reading order is biggest market first, not catalog order.
        let priorities = districts
            .sorted { MarketMapView<EmptyView>.sortPriority($0) > MarketMapView<EmptyView>.sortPriority($1) }
            .map { MarketMapView<EmptyView>.sortPriority($0) }
        XCTAssertEqual(priorities, priorities.sorted(by: >))
        XCTAssertEqual(
            MarketMapView<EmptyView>.sortPriority(districts[0]), districts[0].size,
            "sort priority is the market's size"
        )
    }

    func testTheSpokenValueNamesTheRungAndTheShare() {
        let held = MarketDistrictInfo(
            id: "fitness", name: "Fitness", size: 0.8, standing: .household, share: 0.63
        )
        XCTAssertEqual(held.accessibilityValue, "household name, 63 percent share")
        let untouched = MarketDistrictInfo(id: "music", name: "Music", size: 0.2, standing: .none)
        XCTAssertEqual(untouched.accessibilityValue, "no presence", "no share to claim, so none is spoken")
    }

    // MARK: - The floor and the rival's studio

    func testTheFounderOnTheNetworkingFloorSaysWhatIsLeft() {
        let floor = { (left: Int) in
            NetworkingFloorView(venue: .coworkingMixer, people: [], founderSeed: 7, exchangesLeft: left) { _ in }
        }
        XCTAssertEqual(floor(3).founderLabel, "You, 3 exchanges left")
        XCTAssertEqual(floor(1).founderLabel, "You, one exchange left")
        XCTAssertEqual(floor(0).founderLabel, "You, no exchanges left")
        dump("networking_floor", [floor(3).founderLabel])
    }

    func testARivalStudioSaysItsStrengthAndItsReputation() {
        let studio = RivalStudioInput(band: .mid, reputation: 0.7, founderSeed: 21)
        XCTAssertEqual(
            RivalStudioScene.accessibilityLabel(for: studio),
            "Rival studio: a mid-sized studio, reputation 70 percent"
        )
        let forSale = RivalStudioInput(band: .large, reputation: 0.4, forSale: true, founderSeed: 7)
        XCTAssertEqual(
            RivalStudioScene.accessibilityLabel(for: forSale),
            "Rival studio: a large studio, reputation 40 percent, for sale"
        )
        let fortress = RivalStudioInput(band: .large, reputation: 0.9, isFortress: true, founderSeed: 3)
        XCTAssertTrue(RivalStudioScene.accessibilityLabel(for: fortress).contains("fortress"))
        dump("rival_studio", [
            RivalStudioScene.accessibilityLabel(for: studio),
            RivalStudioScene.accessibilityLabel(for: forSale),
            RivalStudioScene.accessibilityLabel(for: fortress),
        ])
    }
}
