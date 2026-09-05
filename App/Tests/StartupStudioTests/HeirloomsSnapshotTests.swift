import SwiftUI
import TycoonEngine
import TycoonSave
import XCTest

@testable import StartupStudio

/// The Heirlooms page and the title screen's iCloud line (iteration 7,
/// R2), both themes, as review PNGs.
@MainActor
final class HeirloomsSnapshotTests: XCTestCase {
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

    func testTheHeirloomsPageOffersPeoplePerksAndTheDeed() {
        let content = GameEngine.newGame(companyName: "X", seed: 1).content
        let ledger = LegacyLedger.sample
        XCTAssertEqual(ledger.offers.count, 6, "three people, two perks, one deed")
        snapshot("heirlooms_page") {
            HeirloomsStep(ledger: ledger, content: content, selection: .constant(.perk(id: "pressContacts")))
        }
        snapshot("heirlooms_page_nothing") {
            HeirloomsStep(ledger: ledger, content: content, selection: .constant(nil))
        }
    }

    func testTheTitleScreenCarriesTheCloudNotice() {
        let engine = GameEngine.newGame(
            companyName: "Northgate Softworks", seed: 4242,
            founder: FounderProfile(name: "Mira Okafor", archetype: .hacker, appearanceSeed: 0x5EED)
        )
        let summary = SaveSummary(state: engine.state)
        snapshot("title_cloud_notice") {
            TitleScreenContent(
                scene: TitleScene.input(for: engine.state),
                current: summary,
                currentSlot: 1,
                slots: [
                    SlotSummary(slot: 0, contents: .empty),
                    SlotSummary(slot: 1, contents: .saved(
                        summary: summary,
                        envelope: SaveEnvelope(formatVersion: 1, savedAt: Date(), appVersion: "0.1.0", summary: summary)
                    )),
                    SlotSummary(slot: 2, contents: .empty),
                ],
                notice: "Slot 2 · updated from iCloud, day 340"
            )
        }
    }
}
