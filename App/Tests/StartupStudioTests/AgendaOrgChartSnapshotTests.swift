import SwiftUI
import TycoonEngine
import XCTest

@testable import StartupStudio

/// The fortnight and the org chart, rendered light and dark: the agenda on
/// the full fixture (one of everything it can draw) and the chart at one,
/// six and fourteen people, which is the range between "the founder alone
/// in a garage" and "a studio with three departments".
@MainActor
final class AgendaOrgChartSnapshotTests: XCTestCase {
    private var outputDirectory: URL {
        let path = ProcessInfo.processInfo.environment["PIXELKIT_PREVIEW_DIR"]
            ?? NSTemporaryDirectory() + "/startupstudio-previews"
        let url = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Renders the *content* view rather than a `ScrollView` — a renderer
    /// over a scroll view writes a blank PNG.
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

    // MARK: - The agenda

    func testTheFortnightWithOneOfEverythingOnIt() {
        let engine = AgendaTests.fixture()
        let items = Agenda.items(
            in: engine.state, balance: engine.balance, content: engine.content
        )
        XCTAssertGreaterThanOrEqual(items.count, 7, "the fixture should fill the fortnight")
        snapshot("agenda_fortnight") {
            AgendaContent(
                day: engine.state.day,
                items: items,
                freeEvenings: Agenda.freeEveningDays(in: engine.state, balance: engine.balance),
                eveningsLeft: engine.state.eveningsLeftThisWeek(engine.balance),
                eveningsTotal: engine.balance.life.evenings(for: engine.state.life.schedule),
                onRoute: { _ in }
            )
        }
    }

    func testAClearFortnightStillReadsAsACalendar() {
        let engine = GameEngine.newGame(companyName: "Quiet Co", seed: 7, difficulty: .normal)
        snapshot("agenda_quiet") {
            AgendaContent(
                day: engine.state.day,
                items: [],
                freeEvenings: Agenda.freeEveningDays(in: engine.state, balance: engine.balance),
                eveningsLeft: engine.state.eveningsLeftThisWeek(engine.balance),
                eveningsTotal: engine.balance.life.evenings(for: engine.state.life.schedule),
                onRoute: { _ in }
            )
        }
    }

    func testTheFortnightCardLeadsLife() {
        let engine = AgendaTests.fixture()
        snapshot("agenda_card") {
            AgendaCard(engine: engine, onOpen: {}, onRoute: { _ in })
        }
    }

    // MARK: - The org chart

    func testTheChartAtOneSixAndFourteenPeople() {
        for count in [1, 6, 14] {
            let people = Array(Self.studio().prefix(count))
            let layout = OrgChart.layout(
                employees: people, friendships: Self.friendships(among: people)
            )
            XCTAssertEqual(layout.nodes.count, count)
            snapshot("orgchart_\(count)", width: max(393, layout.size.width + 2 * Theme.Spacing.lg)) {
                OrgChartCanvas(layout: layout) { _ in }
            }
        }
    }

    /// A fourteen-person studio: the founder, six on the floor, and all
    /// three departments staffed at more than one rung.
    static func studio() -> [Employee] {
        var people = [
            Employee(
                id: UUID(), name: "Mira Okafor",
                skills: SkillSet(coding: 70, design: 55, marketing: 40),
                weeklySalary: 0, assignment: .idle, isFounder: true,
                hiredDay: 0, appearanceSeed: 0x5EED, role: .founder
            )
        ]
        let roster: [(String, EmployeeRole, SeniorityLevel, Double)] = [
            ("Dev Rao", .backend, .lead, 84),
            ("Ana Beltrán", .designer, .senior, 62),
            ("Sam Idowu", .marketer, .senior, 48),
            ("Kofi Mensah", .qa, .mid, 33),
            ("Ines Duarte", .frontend, .mid, 27),
            ("Nils Berg", .frontend, .junior, 11),
            ("Lena Fischer", .ops, .lead, 66),
            ("Ravi Shah", .ops, .junior, 19),
            ("Tom Alvi", .hr, .mid, 45),
            ("Cleo Marsh", .hr, .junior, 14),
            ("Sara Nowak", .lawyer, .senior, 31),
            ("Otto Lind", .lawyer, .junior, 6),
            ("Yara Haddad", .backend, .junior, 8),
        ]
        for (index, entry) in roster.enumerated() {
            people.append(
                Employee(
                    id: UUID(), name: entry.0,
                    skills: SkillSet(coding: 55, design: 45, marketing: 35),
                    weeklySalary: 1_200, assignment: .idle, isFounder: false,
                    hiredDay: 10 + index * 7, appearanceSeed: UInt64(4_000 + index * 37),
                    level: entry.2, role: entry.1, founderBond: entry.3
                )
            )
        }
        return people
    }

    /// Two friendships that cross branches, so the dotted lines have
    /// something to say.
    static func friendships(among people: [Employee]) -> [Friendship] {
        let staff = people.filter { !$0.isFounder }
        guard staff.count >= 4 else { return [] }
        return [
            Friendship(a: staff[0].id, b: staff[3].id, strength: 78, sinceDay: 60),
            Friendship(a: staff[1].id, b: staff[2].id, strength: 41, sinceDay: 90),
        ]
    }
}
