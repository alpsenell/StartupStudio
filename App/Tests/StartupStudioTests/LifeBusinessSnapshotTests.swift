import SwiftUI
import TycoonEngine
import XCTest

@testable import StartupStudio

/// Life's first card, the Business desk and the six-pill grid, both themes.
@MainActor
final class LifeBusinessSnapshotTests: XCTestCase {
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

    private enum Pill: String, CaseIterable, Identifiable {
        case contracts = "Contracts", market = "Market", marketing = "Marketing"
        case finances = "Finances", rivals = "Rivals", investors = "Investors"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .contracts: "briefcase.fill"
            case .market: "chart.xyaxis.line"
            case .marketing: "megaphone.fill"
            case .finances: "banknote.fill"
            case .rivals: "flag.2.crossed.fill"
            case .investors: "chart.pie.fill"
            }
        }
    }

    func testThisWeekLeadsLife() {
        let engine = engine()
        snapshot("life_this_week") {
            ThisWeekCard(engine: engine)
                .environment(GameShell())
                .environment(AppRouter())
        }
    }

    func testTheDeskReadsAFreshGameAsEmpty() {
        let engine = engine()
        let items = Desk.items(in: engine.state, balance: engine.balance, content: engine.content)
        XCTAssertTrue(items.isEmpty, "a fresh company has nothing on the desk")
        snapshot("business_desk_empty") {
            DeskCard(items: items) { _ in }
        }
    }

    func testTheDeskSortsDatedRowsFirstAndMostUrgentOnTop() {
        let items = [
            DeskItem(id: "loan", systemImage: "banknote.fill", text: "$4,000 on loan · interest posts weekly", daysLeft: nil, tint: .secondary, route: .finances, section: .finances),
            DeskItem(id: "c2", systemImage: "briefcase.fill", text: "Pigeon Logistics · on track", daysLeft: 9, tint: Theme.positiveCash, route: .contracts, section: .contracts),
            DeskItem(id: "c1", systemImage: "briefcase.fill", text: "Harbour Dental · nobody on it", daysLeft: 2, tint: Theme.negativeCash, route: .contracts, section: .contracts),
            DeskItem(id: "offer", systemImage: "doc.text.fill", text: "Harbourline Ventures offered $40,000 for 12.0%", daysLeft: 5, tint: Theme.accent, route: .investors, section: .investors),
        ]
        // The same comparison Desk.items uses.
        let sorted = items.sorted { lhs, rhs in
            switch (lhs.daysLeft, rhs.daysLeft) {
            case let (l?, r?): l < r
            case (.some, .none): true
            case (.none, .some): false
            case (.none, .none): lhs.id < rhs.id
            }
        }
        XCTAssertEqual(sorted.map(\.id), ["c1", "offer", "c2", "loan"])
        snapshot("business_desk_busy") {
            DeskCard(items: sorted) { _ in }
        }
    }

    func testSixPillsLayOutAsAGridWithBadges() {
        struct Host: View {
            @State private var selection: Pill = .contracts
            let badges: [String: Int]
            var body: some View {
                SegmentPillBar(
                    segments: Pill.allCases,
                    title: \.rawValue,
                    systemImage: \.icon,
                    accessibilityLabel: "Business section",
                    selection: $selection,
                    badges: badges
                )
            }
        }
        snapshot("business_pills_grid") {
            Host(badges: ["Contracts": 2, "Investors": 1])
        }
    }
}
