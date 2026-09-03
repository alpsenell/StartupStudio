import PixelKit
import SwiftUI
import TycoonContent
import TycoonEngine
import TycoonSave
import XCTest

@testable import StartupStudio

/// U7: the title screen with a save to continue and on a fresh install,
/// both themes, drawn from the content column (`ImageRenderer` draws
/// nothing inside a `ScrollView`).
@MainActor
final class FrontDoorSnapshotTests: XCTestCase {
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
            XCTAssertGreaterThan(inkCoverage(image), 0.1, "\(name) (\(suffix)) rendered blank")
            let url = outputDirectory.appendingPathComponent("\(name)_\(suffix).png")
            XCTAssertNoThrow(try data.write(to: url), "could not write \(url.path)")
        }
    }

    /// The share of sampled pixels that differ from the top-left one (the
    /// background): 0 for a blank frame, well above a tenth for a page.
    private func inkCoverage(_ image: UIImage) -> Double {
        guard let cg = image.cgImage,
              let data = cg.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data)
        else { return 0 }
        let bytesPerPixel = max(1, cg.bitsPerPixel / 8)
        let background = (0..<bytesPerPixel).map { Int(bytes[$0]) }
        var inked = 0
        var sampled = 0
        for y in stride(from: 0, to: cg.height, by: 8) {
            for x in stride(from: 0, to: cg.width, by: 8) {
                let offset = y * cg.bytesPerRow + x * bytesPerPixel
                sampled += 1
                if (0..<bytesPerPixel).contains(where: { abs(Int(bytes[offset + $0]) - background[$0]) > 8 }) {
                    inked += 1
                }
            }
        }
        return sampled == 0 ? 0 : Double(inked) / Double(sampled)
    }

    /// A company a season in, so the room has people and the chapter has
    /// moved: deterministic on its seed.
    private func company() -> GameState {
        let fresh = GameEngine.newGame(
            companyName: "Northgate Softworks",
            seed: 4242,
            difficulty: .normal,
            founder: FounderProfile(name: "Mira Okafor", archetype: .hacker, appearanceSeed: 0x5EED)
        )
        var state = fresh.state
        for _ in 0..<90 { _ = Reducer.tick(&state, balance: fresh.balance, content: fresh.content) }
        return state
    }

    private func savedRow(_ slot: Int, _ summary: SaveSummary) -> SlotSummary {
        SlotSummary(slot: slot, contents: .saved(
            summary: summary,
            envelope: SaveEnvelope(
                formatVersion: 1,
                savedAt: Date(timeIntervalSinceNow: -3_600),
                appVersion: "0.1.0",
                summary: summary
            )
        ))
    }

    func testTheTitleScreenWithASaveOffersContinueAndTheSlots() {
        let state = company()
        let summary = SaveSummary(state: state)
        XCTAssertEqual(summary.companyName, "Northgate Softworks")
        XCTAssertEqual(summary.founderName, "Mira Okafor")
        XCTAssertEqual(summary.day, 90)
        XCTAssertNil(summary.endingKind, "the fixture company is still running")
        XCTAssertEqual(summary.founderAppearanceSeed, state.employees.first { $0.isFounder }?.appearanceSeed)

        let scene = TitleScene.input(for: state)
        XCTAssertEqual(scene.ambience.timeOfDay, .night)
        XCTAssertEqual(scene.occupants.count, state.employees.count)
        XCTAssertTrue(scene.occupants.first?.isFounder == true, "the founder sits first")

        // A second slot that ended, and an empty third: every row kind
        // the picker draws for a save, on one page. The ending is written
        // as the summary the autosave would have carried for it.
        let endedSummary = SaveSummary(
            companyName: "Rooftop", founderName: "Dev Anand", day: 400,
            ending: EndingKind.acquired.rawValue, chapter: 5, chapterTitle: "The exit",
            founderAppearanceSeed: 0x7A11
        )
        XCTAssertEqual(endedSummary.endingKind, .acquired)

        snapshot("title_screen_with_save") {
            TitleScreenContent(
                scene: scene,
                current: summary,
                currentSlot: 0,
                slots: [
                    savedRow(0, summary),
                    savedRow(1, endedSummary),
                    SlotSummary(slot: 2, contents: .empty),
                ]
            )
        }
    }

    func testTheTitleScreenOnAFreshInstallShowsAnEmptyGarageAndThreeEmptySlots() {
        XCTAssertTrue(TitleScene.emptyGarage.occupants.isEmpty)
        XCTAssertEqual(TitleScene.emptyGarage.tier, .garage)
        XCTAssertEqual(TitleScene.emptyGarage.ambience.timeOfDay, .night)

        snapshot("title_screen_fresh") {
            TitleScreenContent(
                scene: TitleScene.emptyGarage,
                current: nil,
                currentSlot: 0,
                slots: (0..<3).map { SlotSummary(slot: $0, contents: .empty) }
            )
        }
    }

    func testADamagedSlotDrawsAsDamagedBesideTheOthers() {
        let summary = SaveSummary(state: company())
        snapshot("title_screen_damaged_slot") {
            TitleScreenContent(
                scene: TitleScene.emptyGarage,
                current: nil,
                currentSlot: 1,
                slots: [
                    savedRow(0, summary),
                    SlotSummary(slot: 1, contents: .corrupt),
                    SlotSummary(slot: 2, contents: .futureFormat(9)),
                ]
            )
        }
    }
}
