import SwiftUI
import TycoonContent
import TycoonEngine
import UIKit
import XCTest

@testable import StartupStudio

/// Renders the founder-as-a-person screens — the attribute sheet, the
/// networking floor, a conversation, and the partner card — to PNGs for
/// review by eye, in both appearances.
///
/// Same contract as `SnapshotTests`: these are review artifacts, not
/// pixel-exact baselines, so each one asserts only that something came out.
/// What they *do* catch, and what a headless simulator launch cannot, is a
/// screen that renders empty, crashes on a nil, or lays out unreadably once
/// there is real state behind it — the networking floor in particular is
/// pure layout arithmetic over a room whose occupants are rolled.
@MainActor
final class FounderLifeSnapshotTests: XCTestCase {
    private var outputDirectory: URL {
        let path = ProcessInfo.processInfo.environment["PIXELKIT_PREVIEW_DIR"]
            ?? NSTemporaryDirectory() + "/startupstudio-previews"
        let url = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// A run far enough in to have money, a partner, and something to
    /// show on every card.
    ///
    /// Built by mutating a fresh state and handing it to `GameEngine`'s
    /// public initializer, because the engine's own `state` is
    /// `private(set)` — which is the right shape for it, and means a
    /// snapshot has to set the scene through the same door a save does.
    private func scene(_ prepare: (inout GameState, BalanceConfig, ContentCatalog) -> Void = { _, _, _ in })
        -> GameEngine {
        let seed = GameEngine.newGame(
            companyName: "Northgate Softworks",
            seed: 4242,
            difficulty: .normal,
            founder: FounderProfile(name: "Mira Okafor", archetype: .hacker, appearanceSeed: 0x5EED)
        )
        var state = seed.state
        state.day = 40
        state.life.wallet = 40_000
        state.life.skills = FounderSkillSet(
            conversation: 72, technical: 61, marketKnowledge: 38, leadership: 25, finance: 54
        )
        state.life.family.stage = .partner
        state.life.family.stageSinceDay = 0
        state.life.family.partnerName = "Sam Ortega"
        state.life.family.partnerAppearanceSeed = 0xB0B
        state.life.family.affection = 42
        state.life.family.lastPartnerDay = 0
        prepare(&state, seed.balance, seed.content)
        return GameEngine(state: state, balance: seed.balance, content: seed.content)
    }

    /// The same run, standing in a room — filled by ticking a networking
    /// weekend through the real reducer, so the snapshot is of contacts the
    /// simulation actually rolls rather than hand-built props.
    private func sceneAtAnEvent() -> GameEngine {
        scene { state, balance, content in
            state.life.plannedActivity = .networking
            // Land on the weekly boundary, which is when the weekend
            // resolves and the room opens.
            state.day = GameState.daysPerWeek * 6 - 1
            while state.networking.pendingEvent == nil, state.day < 100 {
                Reducer.tick(&state, balance: balance, content: content)
            }
        }
    }

    private func snapshot(
        _ name: String,
        width: CGFloat = 393,
        height: CGFloat? = nil,
        @ViewBuilder _ content: () -> some View
    ) {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let suffix = style == .light ? "light" : "dark"
            let sized = content()
                .frame(width: width)
                .frame(height: height)
                .background(Theme.screenBackground)
                .environment(\.colorScheme, style == .light ? .light : .dark)
            let renderer = ImageRenderer(content: sized)
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

    func testRendersTheFounderAttributes() {
        let engine = scene()
        snapshot("founder_skills") {
            FounderSkillsCard(engine: engine)
                .environment(GameShell())
                .padding(Theme.Spacing.lg)
        }
    }

    func testRendersThePartnerCard() {
        let engine = scene()
        snapshot("partner_card") {
            PartnerCard(engine: engine)
                .environment(GameShell())
                .padding(Theme.Spacing.lg)
        }
    }

    func testRendersTheNetworkingCard() {
        let engine = sceneAtAnEvent()
        XCTAssertNotNil(engine.state.networking.pendingEvent, "expected a room to have opened")
        snapshot("networking_card") {
            NetworkingCard(engine: engine)
                .environment(GameShell())
                .padding(Theme.Spacing.lg)
        }
    }

    func testRendersTheNetworkingFloor() throws {
        let engine = sceneAtAnEvent()
        let event = try XCTUnwrap(engine.state.networking.pendingEvent)
        snapshot("networking_floor", height: 620) {
            NetworkingFloorView(
                venue: event.venue,
                people: engine.state.networking.contactsInRoom,
                founderSeed: 0x5EED
            ) { _ in }
        }
    }

    /// The two work switches, with the founder on chill during a team
    /// crunch so the impact note is showing.
    func testRendersTheWorkCard() {
        let engine = scene { state, _, _ in
            state.employees.append(
                Employee(
                    id: UUID(), name: "Dara Okonkwo",
                    skills: SkillSet(coding: 60, design: 30, marketing: 20),
                    weeklySalary: 1_200, assignment: .idle, isFounder: false,
                    hiredDay: 0, appearanceSeed: 0xC0DE
                )
            )
            state.economy.workPace = .crunch
            state.life.schedule = .chill
        }
        snapshot("work_card") {
            WorkScheduleCard(engine: engine)
                .environment(GameShell())
                .padding(Theme.Spacing.lg)
        }
    }

    /// The founder's salary against the room's, over the band.
    func testRendersThePayBand() {
        let engine = scene { state, _, _ in
            for _ in 0..<3 {
                state.employees.append(
                    Employee(
                        id: UUID(), name: "Hire",
                        skills: SkillSet(coding: 50, design: 30, marketing: 20),
                        weeklySalary: 1_000, assignment: .idle, isFounder: false,
                        hiredDay: 0, appearanceSeed: 0xFACE
                    )
                )
            }
            state.life.founderSalary = 4_000
        }
        snapshot("pay_band") {
            MoneyCard(engine: engine)
                .environment(GameShell())
                .padding(Theme.Spacing.lg)
        }
    }

    func testRendersAConversation() throws {
        let engine = sceneAtAnEvent()
        let contact = try XCTUnwrap(engine.state.networking.contactsInRoom.first)
        // Warm them up so the sheet shows unlocked offers rather than a
        // wall of "talk to them more first".
        engine.send(.talkToContact(contactID: contact.id, topic: .listen))
        engine.send(.talkToContact(contactID: contact.id, topic: .smallTalk))
        engine.send(.talkToContact(contactID: contact.id, topic: .pitch))

        snapshot("networking_conversation") {
            ContactSheet(engine: engine, contactID: contact.id).content
                .environment(GameShell())
        }
    }
}
