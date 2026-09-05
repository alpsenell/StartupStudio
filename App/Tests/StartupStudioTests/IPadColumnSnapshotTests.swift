import SwiftUI
import TycoonEngine
import UIKit
import XCTest

@testable import StartupStudio

/// The iPad, at 820 points (iteration 7, R8).
///
/// The other snapshot suites render at 393 — a phone — through
/// `ImageRenderer`. This one renders every tab root and the screens they
/// push at 820, the width an iPad hands the app in portrait, in both
/// appearances, behind the same `gameColumn()` the app puts them behind.
///
/// **It renders through a real `UIWindow`, not `ImageRenderer`.** That is
/// not a style choice: `ImageRenderer` cannot draw a `NavigationStack`,
/// and every tab root is one — the first draft of this file "passed"
/// against SwiftUI's yellow unsupported-view placeholder, 640 points wide,
/// with the gutters correct and the game absent. A hosting controller in a
/// window laid out at 820 × 1,180 draws the real hierarchy.
///
/// What it asserts is what "the iPad is not a redesign" means: the content
/// is a centred column no wider than `AppRootView.maxColumnWidth`, with the
/// game's own paper down both edges. A screen that went edge-to-edge — a
/// full-bleed scene, a card stretched to the window — fails the edge check
/// rather than being noticed in a review screenshot six months later.
///
/// The PNGs land next to every other preview, so the column can be looked
/// at as well as asserted:
///
///     make apptest
///     open "$(xcrun simctl get_app_container booted com.alpsenel.startupstudio data)/tmp/startupstudio-previews"
@MainActor
final class IPadColumnSnapshotTests: XCTestCase {

    /// An iPad Pro 13" is 1,024 points wide in portrait and an iPad Air
    /// 820; 820 is the acceptance bar's number and the tighter of the two
    /// against a 640-point column.
    private let iPadWidth: CGFloat = 820
    private let iPadHeight: CGFloat = 1_180

    /// The gutter each side of the column at this width.
    private var gutter: CGFloat { (iPadWidth - AppRootView.maxColumnWidth) / 2 }

    private var outputDirectory: URL {
        let path = ProcessInfo.processInfo.environment["PIXELKIT_PREVIEW_DIR"]
            ?? NSTemporaryDirectory() + "/startupstudio-previews"
        let url = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func session() -> GameSession {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("R8IPad-\(UUID().uuidString)", isDirectory: true)
        return GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
    }

    /// A company with something on every tab: the day-400 studio the
    /// screenshot pipeline uses, so what is asserted here is what the
    /// store listing is photographed from.
    private func engine() -> GameEngine {
        guard let state = ReleaseFixture.state(named: "release-studio-day400") else {
            XCTFail("the day-400 fixture is missing from the bundle")
            return GameEngine.newGame(companyName: "Fallback", seed: 4242)
        }
        return GameEngine.resume(state: state)
    }

    // MARK: - Rendering

    /// Lays `view` out in a window at iPad size and photographs it.
    private func render(_ view: some View, style: UIUserInterfaceStyle) -> UIImage? {
        let bounds = CGRect(x: 0, y: 0, width: iPadWidth, height: iPadHeight)
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: bounds)
        // The test host has a scene; a window without one never lays out.
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first {
            window.windowScene = scene
        }
        window.frame = bounds
        window.overrideUserInterfaceStyle = style
        window.rootViewController = controller
        window.isHidden = false
        window.makeKeyAndVisible()
        controller.view.frame = bounds
        controller.view.setNeedsLayout()
        window.layoutIfNeeded()
        // SwiftUI lays out and the pixel scenes compose their first frame
        // on the run loop, not synchronously.
        for _ in 0..<12 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
        window.layoutIfNeeded()
        // `layer.render(in:)` rather than `drawHierarchy`: the window is
        // 820 points wide on a phone-sized simulator screen, so it is
        // never the thing actually on the display, and the screen-update
        // path renders it blank.
        let image = UIGraphicsImageRenderer(bounds: bounds).image { context in
            window.layer.render(in: context.cgContext)
        }
        window.isHidden = true
        window.rootViewController = nil
        return image
    }

    /// Renders `content` inside the column in both appearances, writes the
    /// PNG, and checks both gutters.
    private func columnSnapshot(
        _ name: String,
        checkingEdges: Bool = true,
        @ViewBuilder _ content: () -> some View
    ) {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let suffix = style == .light ? "light" : "dark"
            guard let image = render(content(), style: style), let data = image.pngData() else {
                XCTFail("failed to render \(name) (\(suffix)) at \(iPadWidth)")
                continue
            }
            XCTAssertGreaterThan(data.count, 4_096, "\(name) (\(suffix)) rendered empty")
            let url = outputDirectory.appendingPathComponent("ipad820_\(name)_\(suffix).png")
            XCTAssertNoThrow(try data.write(to: url), "could not write \(url.path)")
            if checkingEdges {
                assertNothingIsEdgeToEdge(image, name: "\(name) (\(suffix))")
            }
        }
    }

    /// Fails if the render reaches either edge.
    ///
    /// Deliberately blunt: two columns of pixels inside the gutter — one at
    /// the very edge, one just short of the column — have to be the same
    /// colour on every sampled row. Something that spilled out of the
    /// column paints one of them differently; a card's shadow does not
    /// reach 20 points in from the edge of a 90-point gutter.
    private func assertNothingIsEdgeToEdge(
        _ image: UIImage, name: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        guard let cgImage = image.cgImage else {
            return XCTFail("\(name): no bitmap", file: file, line: line)
        }
        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return XCTFail("\(name): no bitmap context", file: file, line: line)
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        func pixel(_ x: Int, _ y: Int) -> [UInt8] {
            let offset = (y * width + x) * 4
            return Array(pixels[offset..<(offset + 4)])
        }
        let scale = CGFloat(width) / iPadWidth
        let inset = Int((gutter - 20) * scale)
        XCTAssertGreaterThan(inset, 20, "\(name): the gutter is too small to sample", file: file, line: line)
        for row in stride(from: height / 20, to: height, by: max(1, height / 20)) {
            let y = min(height - 1, row)
            XCTAssertEqual(
                pixel(2, y), pixel(inset, y),
                "\(name): row \(y) is not flat across the left gutter — something is edge-to-edge",
                file: file, line: line
            )
            XCTAssertEqual(
                pixel(width - 3, y), pixel(width - 1 - inset, y),
                "\(name): row \(y) is not flat across the right gutter",
                file: file, line: line
            )
        }
    }

    /// A render that is actually of the game, not of SwiftUI's
    /// unsupported-view placeholder — the trap this suite fell into once.
    /// The placeholder is a flat yellow field with a red slashed circle and
    /// nothing else, so a render with fewer than a handful of distinct
    /// colours across the column is not a screen.
    private func assertLooksLikeAScreen(
        _ image: UIImage, name: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        guard let cgImage = image.cgImage,
              let data = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data)
        else {
            return XCTFail("\(name): no bitmap", file: file, line: line)
        }
        let count = CFDataGetLength(data)
        var colors: Set<UInt32> = []
        var index = 0
        while index + 3 < count {
            colors.insert(
                UInt32(bytes[index]) << 16 | UInt32(bytes[index + 1]) << 8 | UInt32(bytes[index + 2])
            )
            index += 4 * 37  // a prime stride, so this samples rather than reads
        }
        XCTAssertGreaterThan(
            colors.count, 24,
            "\(name): only \(colors.count) colours — this is a placeholder, not a screen",
            file: file, line: line
        )
    }

    // MARK: - The five tab roots

    func testTheFiveTabRootsHoldTheColumnAt820() {
        let engine = engine()
        let session = session()
        let router = AppRouter()
        let shell = GameShell()

        func root(_ name: String, @ViewBuilder _ content: () -> some View) {
            columnSnapshot(name) {
                content()
                    .gameColumn()
                    .environment(router)
                    .environment(shell)
                    .environment(\.gameSession, session)
            }
        }

        root("hq") { HQScreen(engine: engine) {} }
        root("life") { LifeScreen(engine: engine) }
        root("team") { TeamScreen(engine: engine) }
        root("products") { ProductsScreen(engine: engine) }
        root("business") { BusinessScreen(engine: engine) }
    }

    /// One of them, checked hard: a real screen with real colour in it, so
    /// the whole suite cannot pass against a placeholder again.
    func testATabRootRendersTheGameAndNotAPlaceholder() throws {
        let engine = engine()
        let session = session()
        let view = HQScreen(engine: engine) {}
            .gameColumn()
            .environment(AppRouter())
            .environment(GameShell())
            .environment(\.gameSession, session)
        let image = try XCTUnwrap(render(view, style: .light))
        assertLooksLikeAScreen(image, name: "hq")
    }

    // MARK: - The screens the tabs push

    /// The pixel screens that live inside a tab's navigation stack, and so
    /// inside the column with it.
    func testThePushedPixelScreensHoldTheColumnAt820() {
        let engine = engine()
        let router = AppRouter()
        let shell = GameShell()

        func screen(_ name: String, @ViewBuilder _ content: () -> some View) {
            columnSnapshot(name) {
                NavigationStack {
                    content()
                }
                .gameColumn()
                .environment(router)
                .environment(shell)
            }
        }

        screen("newspaper") { NewspaperScreen(engine: engine) }
        screen("timeline") { TimelineScreen(engine: engine) }
    }

    /// The city map is the one surface that is *not* in the column: it is
    /// a full-screen cover, so an iPad hands it the whole screen. Its scale
    /// is width-relative for exactly that reason, so this render is the
    /// check that a bigger map still fits and its panel does not stretch —
    /// no edge assertion, because the map's paper is meant to reach the
    /// edges.
    func testTheCityMapFillsAnIPadWithoutStretchingItsPanel() {
        let engine = engine()
        columnSnapshot("citymap", checkingEdges: false) {
            CityMapScreen(engine: engine)
                .environment(AppRouter())
                .environment(GameShell())
        }
    }
}
