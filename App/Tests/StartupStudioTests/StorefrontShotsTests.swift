import SwiftUI
import TycoonContent
import TycoonEngine
import XCTest

@testable import StartupStudio

/// The generated screenshot strip: same product, same pixels, forever —
/// and every type and topic in the catalog draws something.
@MainActor
final class StorefrontShotsTests: XCTestCase {
    private var outputDirectory: URL {
        let path = ProcessInfo.processInfo.environment["PIXELKIT_PREVIEW_DIR"]
            ?? NSTemporaryDirectory() + "/startupstudio-previews"
        let url = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testTheSameProductAlwaysDrawsTheSameShots() {
        for shot in 0..<StorefrontShots.shotCount {
            let first = StorefrontShots.grid(
                typeID: "mobile_app", topicID: "fitness", seed: 0xBEEF_1234, shot: shot
            )
            let second = StorefrontShots.grid(
                typeID: "mobile_app", topicID: "fitness", seed: 0xBEEF_1234, shot: shot
            )
            XCTAssertEqual(first, second, "shot \(shot) is not deterministic")
        }
    }

    func testTheThreeShotsDifferFromEachOther() {
        let grids = (0..<StorefrontShots.shotCount).map {
            StorefrontShots.grid(typeID: "web_app", topicID: "finance", seed: 99, shot: $0)
        }
        XCTAssertNotEqual(grids[0], grids[1])
        XCTAssertNotEqual(grids[1], grids[2])
        XCTAssertNotEqual(grids[0], grids[2])
    }

    func testTwoProductsOfTheSameTypeAndTopicStillDiffer() {
        let a = StorefrontShots.grid(typeID: "mobile_app", topicID: "social", seed: 1, shot: 0)
        let b = StorefrontShots.grid(typeID: "mobile_app", topicID: "social", seed: 2, shot: 0)
        XCTAssertNotEqual(a, b, "the seed should vary the contents of a shot")
    }

    func testTypeChoosesTheChromeAndTopicTheMotif() {
        XCTAssertEqual(StorefrontShots.chrome(for: "mobile_app"), .phone)
        XCTAssertEqual(StorefrontShots.chrome(for: "web_app"), .browser)
        XCTAssertEqual(StorefrontShots.chrome(for: "desktop_tool"), .monitor)
        XCTAssertEqual(StorefrontShots.chrome(for: "game"), .widescreen)
        XCTAssertEqual(StorefrontShots.chrome(for: "saas_platform"), .console)
        XCTAssertEqual(StorefrontShots.chrome(for: "enterprise_tool"), .console)
        XCTAssertEqual(StorefrontShots.motif(for: "social"), .feed)
        XCTAssertEqual(StorefrontShots.motif(for: "finance"), .chart)
        XCTAssertEqual(StorefrontShots.motif(for: "logistics"), .map)
        XCTAssertEqual(StorefrontShots.motif(for: "music"), .player)
    }

    /// Every shipped type and topic draws a well-formed, non-empty grid —
    /// a motif that painted nothing, or painted outside the frame, would
    /// show up as a uniform grid or a wrong row width.
    func testEveryCatalogTypeAndTopicDrawsAFullGrid() throws {
        let content = try ContentCatalog.loadBundled()
        for type in content.productTypes {
            for topic in content.topics {
                for shot in 0..<StorefrontShots.shotCount {
                    let grid = StorefrontShots.grid(
                        typeID: type.id, topicID: topic.id, seed: 0xA11CE, shot: shot
                    )
                    XCTAssertEqual(grid.count, StorefrontShots.height, "\(type.id)/\(topic.id)")
                    for row in grid {
                        XCTAssertEqual(row.count, StorefrontShots.width, "\(type.id)/\(topic.id)")
                    }
                    let distinct = Set(grid.joined())
                    XCTAssertGreaterThan(
                        distinct.count, 2,
                        "\(type.id)/\(topic.id) shot \(shot) drew almost nothing"
                    )
                }
            }
        }
    }

    /// A contact sheet of one strip per type and a strip per motif, so the
    /// art is reviewable as a PNG rather than as rows of characters.
    func testTheContactSheetRenders() throws {
        let content = try ContentCatalog.loadBundled()
        let sheet = VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            ForEach(content.productTypes, id: \.id) { type in
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("\(type.id) · social").font(.caption)
                    StorefrontShotStrip(typeID: type.id, topicID: "social", seed: 7, pixelScales: [2])
                }
            }
            ForEach(content.topics, id: \.id) { topic in
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("mobile_app · \(topic.id)").font(.caption)
                    StorefrontShotStrip(typeID: "mobile_app", topicID: topic.id, seed: 7, pixelScales: [2])
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(width: 420)
        .background(Theme.screenBackground)
        let renderer = ImageRenderer(content: sheet)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.uiImage)
        let data = try XCTUnwrap(image.pngData())
        XCTAssertGreaterThan(data.count, 512)
        try data.write(to: outputDirectory.appendingPathComponent("storefront_shots_sheet.png"))
    }
}
