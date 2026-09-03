import SwiftUI
import TycoonEngine
import XCTest

@testable import StartupStudio

/// One money, one face: the sheet off the cash pill, and the locale every
/// in-game figure is formatted with.
@MainActor
final class MoneySnapshotTests: XCTestCase {
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

    func testTheGameLocaleUsesADotWhateverTheDeviceSays() {
        // The founder output multiplier and the money on the same screen
        // must agree on what a comma means.
        XCTAssertEqual(0.93.formatted(.number.precision(.fractionLength(2)).locale(Theme.gameLocale)), "0.93")
        XCTAssertEqual(1_800.formatted(.number.notation(.compactName).locale(Theme.gameLocale)), "1.8K")
        XCTAssertEqual(12_400.money, "$12,400")
        XCTAssertEqual((-1_200).money, "-$1,200")
    }

    func testNoFormattingSiteObeysTheDeviceLocale() throws {
        // A source-level guard: every `.formatted(` in the app passes the
        // game locale, except list formatting, which is prose.
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources")
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        var offenders: [String] = []
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift", let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for (index, line) in text.components(separatedBy: "\n").enumerated()
            where line.contains(".formatted(") && !line.contains("gameLocale") && !line.contains(".list(") && !line.contains("///") {
                offenders.append("\(url.lastPathComponent):\(index + 1)")
            }
        }
        XCTAssertTrue(offenders.isEmpty, "locale-dependent formatting at \(offenders.joined(separator: ", "))")
    }

    func testTheMoneySheetShowsCompanyBankAndYou() {
        let engine = engine()
        snapshot("money_sheet") {
            MoneySheetContent(engine: engine)
                .environment(AppRouter())
                .environment(GameShell())
        }
    }
}
