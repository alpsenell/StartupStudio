import SwiftUI
import TycoonEngine
import XCTest

@testable import StartupStudio

/// The notice rail in each of its states, light and dark, written as PNGs
/// beside the other chrome previews. The rail replaced the report chip,
/// the pause banner, the tip strip and the toast overlay; these are the
/// pictures the integrator looks at.
@MainActor
final class NoticeRailSnapshotTests: XCTestCase {
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
        @ViewBuilder _ content: () -> some View
    ) {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let suffix = style == .light ? "light" : "dark"
            let renderer = ImageRenderer(
                content: content()
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

    private func rail(_ queue: [RailNotice]) -> some View {
        let engine = engine()
        return NoticeRail(engine: engine, onRoute: { _ in }, fixedQueue: queue)
            .environment(GameShell())
            .environment(AppRouter())
    }

    private var sampleToast: Toast {
        Toast(
            id: 7,
            icon: "person.badge.plus",
            message: "Priya joins as Backend Dev",
            tint: Theme.positiveCash,
            severity: .info
        )
    }

    func testRendersThePauseReason() {
        snapshot("rail_pause") {
            rail([.pause(.bankruptcyWarning(day: 30), more: 1)])
        }
    }

    func testRendersADeferredChoice() {
        snapshot("rail_deferred") {
            rail([
                .deferred(
                    id: "domain_for_sale",
                    title: "The domain you actually wanted is for sale.",
                    daysLeft: 4,
                    category: "money"
                ),
            ])
        }
    }

    func testRendersTheUnreadReport() {
        snapshot("rail_report") {
            rail([.report(week: 12)])
        }
    }

    func testRendersAnEvent() {
        snapshot("rail_event") {
            rail([.event(sampleToast)])
        }
    }

    func testRendersATip() {
        snapshot("rail_tip") {
            rail([.tip(CoachTip.all[0])])
        }
    }

    func testABusyDayShowsTheLeaderAndACount() {
        // Three things at once: the pause reason leads, the counter says
        // two more are waiting.
        snapshot("rail_queue") {
            rail([
                .tip(CoachTip.all[0]),
                .report(week: 3),
                .pause(.reviewsIn(productID: UUID(), averageScore: 58, day: 40), more: 0),
            ])
        }
    }

    func testTheHUDWithEverythingOn() {
        // The full band: bar plus rail, the state a screenshot pass
        // caught stacked four high before.
        let engine = engine()
        engine.setSpeed(.x2)
        snapshot("hud_busy") {
            VStack(spacing: 0) {
                TopHUD(engine: engine)
                NoticeRail(engine: engine, onRoute: { _ in }, fixedQueue: [
                    .report(week: 2),
                    .event(sampleToast),
                    .tip(CoachTip.all[0]),
                ])
            }
            .environment(GameShell())
            .environment(AppRouter())
        }
    }

    func testTheRailIsEmptyWhenNothingIsQueued() {
        let engine = engine()
        let view = NoticeRail(engine: engine, onRoute: nil, fixedQueue: [])
            .environment(GameShell())
            .environment(AppRouter())
            .frame(width: 393)
        let renderer = ImageRenderer(content: view)
        // An empty queue renders nothing: no strip, no divider, no height.
        XCTAssertLessThanOrEqual(renderer.uiImage?.size.height ?? 0, 1)
    }
}
