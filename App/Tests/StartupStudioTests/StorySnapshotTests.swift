import SwiftUI
import TycoonContent
import TycoonEngine
import XCTest

@testable import StartupStudio

/// The front page with a real issue on it, and the timeline at two zoom
/// levels, both themes. PNGs land beside the other chrome previews.
@MainActor
final class StorySnapshotTests: XCTestCase {
    private var outputDirectory: URL {
        let path = ProcessInfo.processInfo.environment["PIXELKIT_PREVIEW_DIR"]
            ?? NSTemporaryDirectory() + "/startupstudio-previews"
        let url = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Renders the content view itself, not a scroll view, at a phone
    /// width; the height is whatever the content needs.
    private func snapshot(
        _ name: String,
        width: CGFloat = 393,
        @ViewBuilder _ content: () -> some View
    ) {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let suffix = style == .light ? "light" : "dark"
            let renderer = ImageRenderer(
                content: content()
                    .frame(width: width)
                    .background(Theme.screenBackground)
                    .environment(\.colorScheme, style == .light ? .light : .dark)
                    .environment(\.dynamicTypeSize, .large)
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

    // MARK: - The front page

    func testTheFrontPageWithARealIssue() {
        let state = StoryFixtures.fourWeeks()
        let composer = NewspaperComposer(state: state, content: StoryFixtures.content, balance: StoryFixtures.balance)
        let issue = composer.issues()[3]
        XCTAssertEqual(issue.lead.headline, "Reviews are in for Overcast")
        XCTAssertEqual(issue.photo.scene.occupants.count, 4)
        snapshot("newspaper_front_page") {
            NewspaperPage(issue: issue)
        }
    }

    func testTheFrontPageOnDayZero() {
        let state = StoryFixtures.newState(day: 0)
        let composer = NewspaperComposer(state: state, content: StoryFixtures.content, balance: StoryFixtures.balance)
        snapshot("newspaper_day0") {
            NewspaperPage(issue: composer.issues()[0])
        }
    }

    // MARK: - The timeline

    func testTheTimelineAtTwoZoomLevels() {
        let state = StoryFixtures.longRun()
        let markers = TimelineBuilder.markers(state: state, content: StoryFixtures.content, balance: StoryFixtures.balance)
        XCTAssertGreaterThan(markers.count, 10)

        // The whole run across one phone width.
        snapshot("timeline_run", width: 361) {
            TimelineStrip(
                markers: markers, today: state.day, zoom: .run,
                viewportWidth: 361, selectedID: .constant("product-\(StoryFixtures.chordID.uuidString)")
            )
        }

        // A quarter across the width: the strip is as wide as the run at
        // that scale, so the PNG is the whole scrollable line.
        let quarterWidth = CGFloat(state.day + 7) * ((361 - 80) / 91) + 80
        snapshot("timeline_quarter", width: quarterWidth) {
            TimelineStrip(
                markers: markers, today: state.day, zoom: .quarter,
                viewportWidth: 361, selectedID: .constant(nil)
            )
        }
    }

    func testTheMarkerArtDrawsEveryKind() {
        let kinds: [TimelineMarker.Kind] = [
            .founding(seed: 0x5EED),
            .product(typeID: "mobile_app", topicID: "fitness", seed: 7),
            .hire(seed: 21, role: .qa),
            .chapter(3),
            .crash(topicID: "finance"),
            .round,
            .incumbent,
            .challengeHeld(topicID: "fitness"),
            .challengeLost(topicID: "music"),
            .buyout,
            .ending(.ipo),
        ]
        snapshot("timeline_marker_art") {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(Array(kinds.enumerated()), id: \.offset) { _, kind in
                    TimelineMarkerArt(kind: kind, size: 28)
                }
            }
            .padding(Theme.Spacing.lg)
        }
    }
}
