import SwiftUI
import TycoonEngine
import TycoonSave
import XCTest

@testable import StartupStudio

/// What the store asks for (iteration 7, R8): the privacy manifest, the
/// listing keys in the generated `Info.plist`, the iPad keys, and the
/// three bundled fixtures the screenshot pipeline photographs.
///
/// Everything here reads the *built* bundle rather than `project.yml`, so
/// it fails if a key stops reaching the app however it was lost — a typo
/// in the yml, a hand-edited plist, a build setting that overrode it.
@MainActor
final class ReleasePlumbingTests: XCTestCase {

    /// The bundle's `Info.plist` **as written**, not as the running
    /// device resolved it.
    ///
    /// `Bundle.main.infoDictionary` folds the device-suffixed keys away:
    /// on an iPhone simulator `UISupportedInterfaceOrientations~ipad` has
    /// already been consumed and is simply not there, so the test that
    /// matters most for this lane would pass by being absent. Reading the
    /// file gives the plist xcodegen generated from `project.yml`.
    private func infoPlist() throws -> [String: Any] {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: "Info", withExtension: "plist"),
            "the app bundle has no Info.plist"
        )
        return try XCTUnwrap(
            PropertyListSerialization.propertyList(
                from: try Data(contentsOf: url), format: nil
            ) as? [String: Any]
        )
    }

    // MARK: - The privacy manifest

    /// The scaffold's test asserts tracking and the collected-data list;
    /// this one pins the rest of the answer, because "no data collected"
    /// is a promise the whole app has to keep and the manifest is where it
    /// is written down.
    func testPrivacyManifestDeclaresNoTrackingDomainsAndOneAccessedAPIReason() throws {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"),
            "PrivacyInfo.xcprivacy is not in the bundle"
        )
        let manifest = try XCTUnwrap(
            PropertyListSerialization.propertyList(
                from: try Data(contentsOf: url), format: nil
            ) as? [String: Any]
        )
        XCTAssertEqual(manifest["NSPrivacyTracking"] as? Bool, false)
        XCTAssertEqual((manifest["NSPrivacyTrackingDomains"] as? [Any])?.count, 0)
        XCTAssertEqual((manifest["NSPrivacyCollectedDataTypes"] as? [Any])?.count, 0)

        let accessed = try XCTUnwrap(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        XCTAssertEqual(accessed.count, 1, "only UserDefaults is reached for a declared reason")
        XCTAssertEqual(
            accessed[0]["NSPrivacyAccessedAPIType"] as? String,
            "NSPrivacyAccessedAPICategoryUserDefaults"
        )
        XCTAssertEqual(accessed[0]["NSPrivacyAccessedAPITypeReasons"] as? [String], ["CA92.1"])
    }

    // MARK: - The listing's keys

    func testTheBundleCarriesTheStoreListingKeys() throws {
        let info = try infoPlist()
        XCTAssertEqual(info["CFBundleShortVersionString"] as? String, "1.0.0")
        XCTAssertEqual(
            info["LSApplicationCategoryType"] as? String, "public.app-category.simulation-games"
        )
        XCTAssertEqual(info["ITSAppUsesNonExemptEncryption"] as? Bool, false)
        let copyright = try XCTUnwrap(info["NSHumanReadableCopyright"] as? String)
        XCTAssertTrue(copyright.contains("©"), "the copyright line is a copyright line")

        // The build number comes from App/Config/Version.xcconfig, which
        // `make gen` writes from the commit count. Whatever it is, it has
        // to be a number App Store Connect can sort.
        let build = try XCTUnwrap(info["CFBundleVersion"] as? String)
        let number = try XCTUnwrap(Int(build), "CFBundleVersion \"\(build)\" is not a number")
        XCTAssertGreaterThan(number, 0)
    }

    func testTheBundleIsIPadReadyAndPortraitOnlyOnBothFamilies() throws {
        let info = try infoPlist()
        XCTAssertEqual(info["UIRequiresFullScreen"] as? Bool, true, "no multitasking sizes")
        XCTAssertEqual(
            info["UISupportedInterfaceOrientations"] as? [String],
            ["UIInterfaceOrientationPortrait"]
        )
        let iPad = try XCTUnwrap(info["UISupportedInterfaceOrientations~ipad"] as? [String])
        XCTAssertEqual(
            Set(iPad),
            ["UIInterfaceOrientationPortrait", "UIInterfaceOrientationPortraitUpsideDown"],
            "the iPad is the phone layout in a column, so it stays portrait"
        )
        XCTAssertFalse(
            iPad.contains { $0.contains("Landscape") },
            "iPad landscape is a redesign of the HUD and the rail — wave 2"
        )
    }

    // MARK: - The column

    func testTheColumnIsWiderThanEveryIPhoneAndNarrowerThanEveryIPad() {
        // 440 points is the widest iPhone (6.9"); 744 the narrowest iPad
        // in portrait (the mini). So the cap is invisible on one and
        // always doing something on the other.
        XCTAssertGreaterThan(AppRootView.maxColumnWidth, 440)
        XCTAssertLessThan(AppRootView.maxColumnWidth, 744)
    }

    /// The city map is a full-screen cover, so on an iPad it gets the
    /// whole screen rather than the game's column — and a scale pinned at
    /// 3 left the city floating in the middle of it.
    func testTheCityMapScaleIsWidthRelativeAndUnchangedOnEveryPhone() {
        for phoneWidth in [320.0, 375.0, 393.0, 402.0, 430.0, 440.0] {
            XCTAssertEqual(
                CityMapScreen.mapScale(forWidth: phoneWidth), 3,
                "\(phoneWidth): the phone's map must not move"
            )
        }
        XCTAssertEqual(CityMapScreen.mapScale(forWidth: 744), 3, "iPad mini")
        XCTAssertEqual(CityMapScreen.mapScale(forWidth: 1024), 4, "iPad Pro 13\"")
        XCTAssertEqual(CityMapScreen.mapScale(forWidth: 4000), 5, "and never past 5")
        XCTAssertEqual(CityMapScreen.mapScale(forWidth: 0), 3, "a size nobody proposed yet")

        // The panel clearance is the phone's 280 points expressed in scene
        // rows, so it grows with the map rather than with the screen.
        XCTAssertEqual(CityMapScreen.panelClearance(scale: 3), 280)
        XCTAssertEqual(CityMapScreen.panelClearance(scale: 4), 373)
    }

    // MARK: - The screenshot fixtures

    func testTheThreeScreenshotFixturesAreBundledAndDecode() throws {
        XCTAssertEqual(ReleaseFixture.names.count, 3)
        let expected: [String: (day: Int, tier: OfficeTier)] = [
            "release-garage-day40": (40, .garage),
            "release-studio-day400": (400, .studio),
            "release-campus-day900": (905, .campus),
        ]
        for name in ReleaseFixture.names {
            let state = try XCTUnwrap(
                ReleaseFixture.state(named: name), "\(name) is not in the bundle"
            )
            let want = try XCTUnwrap(expected[name])
            XCTAssertEqual(state.day, want.day, "\(name)")
            XCTAssertEqual(state.company.officeTier, want.tier, "\(name)")
            XCTAssertNil(state.gameOver, "\(name): a fixture is a company still running")
        }
        XCTAssertNil(ReleaseFixture.state(named: "no-such-fixture"))
    }

    /// A fixture goes in the way a real save does — through `SaveStore` —
    /// so a screenshot pass resumes it down the ordinary path and nothing
    /// about it can drift from what the game writes.
    func testAFixtureInstallsIntoSlotZeroAndReadsBackAsASave() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("R8Fixture-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SaveStore<GameState>(directory: directory, currentFormatVersion: 1)

        let state = try XCTUnwrap(ReleaseFixture.state(named: "release-studio-day400"))
        try store.save(state, appVersion: "1.0.0", summary: SaveSummary(state: state), slot: 0)

        let loaded = try XCTUnwrap(try store.load(slot: 0))
        XCTAssertEqual(loaded.state.day, 400)
        XCTAssertEqual(loaded.state, state, "the save round-trips the fixture exactly")
        XCTAssertEqual(loaded.envelope.summary?.day, 400)
    }
}
