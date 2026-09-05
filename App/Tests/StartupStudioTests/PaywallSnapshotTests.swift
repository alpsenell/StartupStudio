import PixelKit
import SwiftUI
import TycoonEngine
import XCTest

@testable import StartupStudio

/// R6: the paywall on pixel paper in both themes and at an accessibility
/// size, and the HUD with the lock where the speeds were.
@MainActor
final class PaywallSnapshotTests: XCTestCase {
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
        typeSize: DynamicTypeSize = .large,
        @ViewBuilder _ content: () -> some View
    ) {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let suffix = style == .light ? "light" : "dark"
            let renderer = ImageRenderer(
                content: content()
                    .frame(width: width)
                    .background(Theme.screenBackground)
                    .environment(\.colorScheme, style == .light ? .light : .dark)
                    .environment(\.dynamicTypeSize, typeSize)
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

    /// The paywall's column without the scroll view (`ImageRenderer`
    /// draws nothing inside one), on the chapter-2 company.
    private func paywall(price: String?, message: String? = nil) -> some View {
        let state = UnlockTests.chapterTwoCompany().state
        return PaywallContent(
            scene: TitleScene.input(for: state),
            companyName: state.company.name,
            price: price,
            message: message
        )
        .column
    }

    func testRendersThePaywallLightAndDark() {
        snapshot("paywall") { paywall(price: "$4.99") }
    }

    func testRendersThePaywallWithoutAPriceAndWithAMessage() {
        snapshot("paywall_no_price") {
            paywall(price: nil, message: "The App Store couldn't be reached. Try again in a moment.")
        }
    }

    func testRendersThePaywallAtAnAccessibilitySize() {
        snapshot("paywall_ax3", typeSize: .accessibility3) {
            paywall(price: "$4.99")
        }
    }

    func testRendersTheLockedSpeedControlInTheHUD() {
        let state = UnlockTests.chapterTwoCompany().state
        let engine = GameEngine.resume(state: state)
        engine.advanceGate = { _ in false }
        XCTAssertFalse(engine.mayAdvance)
        snapshot("hud_locked") {
            TopHUD(engine: engine)
                .environment(GameShell())
                .environment(AppRouter())
        }
        engine.advanceGate = nil
        snapshot("speed_control_locked_vs_open") {
            VStack(spacing: Theme.Spacing.md) {
                SpeedControl(engine: {
                    let gated = GameEngine.resume(state: state)
                    gated.advanceGate = { _ in false }
                    return gated
                }())
                SpeedControl(engine: engine)
            }
            .padding(Theme.Spacing.lg)
        }
    }
}
