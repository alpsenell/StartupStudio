import SwiftUI
import TycoonEngine
import UIKit
import XCTest

@testable import StartupStudio

/// Renders the new chrome to PNGs so it can be reviewed by eye, in both
/// light and dark appearance, the same way PixelKit's preview tests do.
///
/// Writes into `PIXELKIT_PREVIEW_DIR` (falling back to the temporary
/// directory) and asserts only that each image came out non-empty — these
/// are review artifacts, not pixel-exact regression baselines.
@MainActor
final class SnapshotTests: XCTestCase {
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

    /// Renders `view` at `width` in both appearances and writes both PNGs.
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

    func testRendersTheHUD() {
        let engine = engine()
        engine.setSpeed(.x2)
        snapshot("hud") {
            TopHUD(engine: engine)
                .environment(GameShell())
                .environment(AppRouter())
        }
    }

    func testRendersThePauseBanner() {
        let engine = engine()
        // A paused clock with a reason: the banner reads the loudest one.
        snapshot("pause_banner", width: 393) {
            VStack(spacing: 0) {
                PauseBannerPreview(
                    icon: "star.fill",
                    message: "Reviews are in for Overcast: 58",
                    tint: Theme.warning
                )
                PauseBannerPreview(
                    icon: "exclamationmark.triangle.fill",
                    message: "Bankruptcy warning — cash has run dry",
                    tint: Theme.negativeCash
                )
            }
        }
        _ = engine
    }

    func testRendersToasts() {
        let center = ToastCenter()
        center.show("Priya joins as Backend Dev", icon: "person.badge.plus", tint: Theme.positiveCash)
        center.show("Signed Pigeon Logistics · due W12", icon: "briefcase.fill")
        center.show("Overcast left the market", icon: "archivebox.fill", tint: .secondary)
        snapshot("toasts") {
            ToastStack(center: center)
                .padding(.vertical, Theme.Spacing.lg)
        }
    }

    func testRendersTheWeeklyReport() {
        let engine = engine()
        snapshot("weekly_report_headline") {
            PixelPanel {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    PixelText(text: "Week 12", scale: 3, color: Theme.pixelAccent, shadow: true)
                    Text("Mar 24, Year 1 · Spring")
                        .font(.footnote)
                        .foregroundStyle(Theme.pixelInk.opacity(0.7))
                    HStack(spacing: Theme.Spacing.sm) {
                        PixelText(text: "-$1,840", scale: 3, color: Theme.negativeCash)
                        Text("this week")
                            .font(.footnote)
                            .foregroundStyle(Theme.pixelInk.opacity(0.7))
                    }
                }
            }
            .padding(Theme.Spacing.lg)
        }
        _ = engine
    }

    /// The report's bottom bar: "Next week" and, under it, the off switch
    /// for the auto-open that a player was otherwise sent to Settings to
    /// find. Rendered in both states.
    func testRendersTheWeeklyReportBottomBar() {
        GameSettings.weeklyReportAuto = true
        snapshot("weekly_report_bar_auto_on", width: 393) {
            WeeklyReportBottomBar(nextWeekIndex: 13) {}
        }
        GameSettings.weeklyReportAuto = false
        snapshot("weekly_report_bar_auto_off", width: 393) {
            WeeklyReportBottomBar(nextWeekIndex: 13) {}
        }
        GameSettings.weeklyReportAuto = true
    }

    func testRendersLaunchDayChrome() {
        snapshot("launch_day") {
            VStack(spacing: Theme.Spacing.lg) {
                PixelPanel {
                    VStack(spacing: Theme.Spacing.md) {
                        ProductBoxArtView(typeID: "mobile", topicID: "fitness", seed: 99, size: 120)
                        PixelText(text: "Overcast", scale: 3, color: Theme.pixelInk, shadow: true)
                        Text("Mobile App · Fitness")
                            .font(.footnote)
                            .foregroundStyle(Theme.pixelInk.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                }
                VStack(spacing: Theme.Spacing.xs) {
                    PixelText(text: "58", scale: 6, color: Theme.scoreTint(58), shadow: true)
                    PixelText(text: "Mixed", scale: 2, color: .secondary)
                }
                .padding(Theme.Spacing.lg)
                .overlay {
                    PixelPanelBorder(thickness: 3, corner: 3)
                        .fill(Theme.scoreTint(58).opacity(0.6))
                }
            }
            .padding(Theme.Spacing.lg)
        }
    }

    func testRendersTheBoxArtSheet() {
        snapshot("product_box_art", width: 360) {
            VStack(spacing: Theme.Spacing.md) {
                ForEach(["mobile", "web", "desktop"], id: \.self) { type in
                    HStack(spacing: Theme.Spacing.md) {
                        ForEach(["fitness", "finance", "education"], id: \.self) { topic in
                            ProductBoxArtView(typeID: type, topicID: topic, seed: 7, size: 72)
                        }
                    }
                }
                HStack(spacing: Theme.Spacing.md) {
                    ProductBoxArtView(typeID: "game", topicID: "games", seed: 3, size: 72)
                    ProductBoxArtView(typeID: "saas", topicID: "productivity", seed: 3, size: 72)
                    ProductBoxArtView(typeID: "enterprise", topicID: "logistics", seed: 3, size: 72)
                }
            }
            .padding(Theme.Spacing.lg)
        }
    }

    func testRendersTheBitmapFont() {
        snapshot("pixel_font", width: 360) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                PixelText(text: "ABCDEFGHIJKLM", scale: 3)
                PixelText(text: "NOPQRSTUVWXYZ", scale: 3)
                PixelText(text: "0123456789", scale: 3, color: Theme.pixelAccent)
                PixelText(text: "$12,400 · Mar W2 · Y1", scale: 2, shadow: true)
                PixelText(text: "+$1,240", scale: 3, color: Theme.positiveCash, shadow: true)
                PixelText(text: "-$900", scale: 3, color: Theme.negativeCash, shadow: true)
            }
            .padding(Theme.Spacing.lg)
        }
    }
}

/// A standalone copy of the pause banner's layout for snapshotting, so the
/// image doesn't depend on driving a live engine into a paused tick.
private struct PauseBannerPreview: View {
    let icon: String
    let message: String
    let tint: Color

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 22)
            Text(message)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
            Spacer(minLength: Theme.Spacing.sm)
            Text("Details")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.accent)
            Label("Resume", systemImage: "play.fill")
                .labelStyle(.iconOnly)
                .font(.footnote.weight(.bold))
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.xs)
                .background(Theme.accent, in: Capsule())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .background(tint.opacity(0.12))
    }
}
