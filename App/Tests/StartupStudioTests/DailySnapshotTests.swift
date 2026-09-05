import SwiftUI
import TycoonEngine
import UIKit
import XCTest

@testable import StartupStudio

/// R3: today's company before and after it is played, in both
/// appearances, at the default type size and at an accessibility one.
///
/// Review artifacts, like the other snapshot suites: they assert the
/// frame came out and is not blank, and write the PNG for a human.
@MainActor
final class DailySnapshotTests: XCTestCase {
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
                    .padding(Theme.Spacing.lg)
                    .frame(width: width)
                    .background(Theme.screenBackground)
                    .environment(\.dynamicTypeSize, typeSize)
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

    /// 2026-09-05: the day the release doc was written.
    private let challenge = DailyChallenge.forDay(247)

    private func result(
        submitted: Bool = true, ending: String? = nil, score: Int = 184_500
    ) -> DailyLedger.Entry {
        DailyLedger.Entry(
            day: challenge.day,
            score: score,
            submitted: submitted,
            ending: ending,
            gameDay: ending == nil ? 364 : 212,
            lines: [
                "Shipped 4 products, best reviewed 81.",
                "9 people on payroll, the longest 300 days in.",
                "Company worth $1,240,000; you still owned 74%.",
            ],
            finishedAt: Date(timeIntervalSince1970: 1_788_000_000)
        )
    }

    func testTodaysCompanyBeforeItIsPlayed() {
        snapshot("daily_card") {
            DailyCard(challenge: challenge)
        }
    }

    func testAnAttemptUnderWayOffersResume() {
        snapshot("daily_card_resume") {
            DailyCard(challenge: challenge, resumingFromDay: 118)
        }
    }

    func testTheResultCardWhenTheYearRanOut() {
        snapshot("daily_result") {
            DailyResultCard(challenge: challenge, entry: result())
        }
    }

    func testTheResultCardWhenTheBoardHadAlreadyClosed() {
        snapshot("daily_result_closed") {
            DailyResultCard(
                challenge: challenge,
                entry: result(submitted: false, ending: EndingKind.bankruptcy.rawValue, score: -4_200)
            )
        }
    }

    /// The accessibility sizes stack the two facts instead of squeezing
    /// them into two columns.
    func testTheCardsHoldAtAnAccessibilitySize() {
        snapshot("daily_card_a11y", typeSize: .accessibility3) {
            DailyCard(challenge: challenge)
        }
        snapshot("daily_result_a11y", typeSize: .accessibility3) {
            DailyResultCard(challenge: challenge, entry: result())
        }
    }
}
