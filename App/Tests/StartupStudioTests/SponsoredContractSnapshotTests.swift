import SwiftUI
import TycoonEngine
import XCTest

@testable import StartupStudio

/// "Build It For Them" on the sheet: the sponsored offer card says what it
/// is, the active card says what they will ship, the desk row carries the
/// clock and the promise, and the journal line names the rival. Both
/// themes.
@MainActor
final class SponsoredContractSnapshotTests: XCTestCase {
    private var outputDirectory: URL {
        let path = ProcessInfo.processInfo.environment["PIXELKIT_PREVIEW_DIR"]
            ?? NSTemporaryDirectory() + "/startupstudio-previews"
        let url = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static let rivalID = UUID()

    /// A studio nine weeks in, holding Fitness at 62, with Northwind
    /// Software on the sheet asking for a Fitness white-label next to an
    /// ordinary offer — and, when asked, the same job accepted and half
    /// built.
    private func engine(active: Bool = false) -> GameEngine {
        let base = GameEngine.newGame(
            companyName: "Northgate Softworks",
            seed: 4242,
            difficulty: .normal,
            founder: FounderProfile(name: "Mira Okafor", archetype: .hacker, appearanceSeed: 0x5EED)
        )
        var state = base.state
        let rival = Rival(
            id: Self.rivalID, name: "Northwind Software", strength: 52, reputation: 45,
            focusTopicIDs: ["fitness"], foundedDay: 7, appearanceSeed: 0xA11CE, personality: .copycat
        )
        state.rivals.rivals = [rival]
        state.market.standing["fitness"] = 62
        state.day = 63

        let sponsored = ContractOffer(
            id: UUID(), clientName: rival.name,
            requiredCodePts: 96, requiredDesignPts: 44,
            payout: 11_880, penalty: 3_564, deadlineDays: 62, expiresDay: 70,
            requiredSkill: 61.6, topicID: "fitness", sponsorRivalID: rival.id
        )
        let plain = ContractOffer(
            id: UUID(), clientName: "Herring & Hound Legal",
            requiredCodePts: 49, requiredDesignPts: 13,
            payout: 3_305, penalty: 992, deadlineDays: 25, expiresDay: 70, requiredSkill: 53
        )
        if active {
            state.contractOffers = [plain]
            state.activeContracts = [ContractJob(
                id: sponsored.id, clientName: sponsored.clientName,
                requiredCodePts: 96, requiredDesignPts: 44,
                progressCode: 51, progressDesign: 20,
                deadlineDay: 63 + 62 - 18, payout: 11_880, penalty: 3_564, acceptedDay: 45,
                requiredSkill: 61.6, skillDaySum: 18 * 58, skillDays: 18,
                topicID: "fitness", sponsorRivalID: rival.id
            )]
            state.employees[0].assignment = .contract(sponsored.id)
        } else {
            state.contractOffers = [sponsored, plain]
        }
        return GameEngine(state: state, balance: base.balance, content: base.content)
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

    func testTheSponsoredOfferSaysWhatItIs() {
        let engine = engine()
        let offer = engine.state.contractOffers[0]
        XCTAssertTrue(offer.isSponsored)
        XCTAssertEqual(
            ContractOutlook.sponsorLine(
                client: offer.clientName, topic: "Fitness",
                standing: engine.state.market.standing(for: "fitness"), sponsorPresent: true
            ),
            "On delivery Northwind Software ships a Fitness product at the quality you build. You hold Fitness at 62."
        )
        XCTAssertEqual(
            ContractOutlook.sponsorLine(client: "Northwind Software", topic: "Travel", standing: 0, sponsorPresent: true),
            "On delivery Northwind Software ships a Travel product at the quality you build. You hold nothing in Travel yet."
        )
        XCTAssertEqual(
            ContractOutlook.sponsorLine(client: "Northwind Software", topic: "Fitness", standing: 62, sponsorPresent: false),
            "Northwind Software has since shut down — this is just a job now."
        )
        snapshot("contracts_sponsored_offer") {
            ContractsView(engine: engine)
                .environment(GameShell())
                .environment(AppRouter())
        }
    }

    func testTheActiveJobAndTheDeskCarryThePromise() {
        let engine = engine(active: true)
        let job = engine.state.activeContracts[0]
        // Crew 58 against 61.6: 58/61.6 × 80 = 75, "client will have notes";
        // 75 × 0.9 = 68 is what Northwind would ship.
        XCTAssertEqual(job.projectedQuality, 75)
        XCTAssertEqual(ContractOutlook.promisedQuality(projectedQuality: 75, balance: engine.balance), 68)

        let items = Desk.items(in: engine.state, balance: engine.balance, content: engine.content)
        let row = items.first { $0.id == "contract-\(job.id)" }
        XCTAssertEqual(row?.text, "Northwind Software · they ship Fitness at ~68")
        XCTAssertEqual(row?.daysLeft, 44)
        XCTAssertEqual(row?.tint, Theme.warning, "the row keeps the grade's colour")

        // An ordinary job's row is untouched by the topic-aware grade.
        let plain = ContractOutlook.grade(hasWork: true, projectedQuality: 75, balance: engine.balance)
        XCTAssertEqual(plain.label, "client will have notes")
        XCTAssertNil(plain.promise)
        let sponsored = ContractOutlook.grade(
            hasWork: true, projectedQuality: 75, balance: engine.balance, sponsoredTopic: "Fitness"
        )
        XCTAssertEqual(sponsored.label, "client will have notes")
        XCTAssertEqual(sponsored.promise, "they ship Fitness at ~68")
        let idle = ContractOutlook.grade(
            hasWork: false, projectedQuality: 0, balance: engine.balance, sponsoredTopic: "Fitness"
        )
        XCTAssertEqual(idle.label, "nobody on it")
        XCTAssertNil(idle.promise)

        snapshot("contracts_sponsored_active") {
            VStack(spacing: Theme.Spacing.lg) {
                DeskCard(items: items) { _ in }
                ContractsView(engine: engine)
            }
            .environment(GameShell())
            .environment(AppRouter())
        }
    }
}
