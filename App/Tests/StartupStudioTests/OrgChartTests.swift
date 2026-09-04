import SwiftUI
import TycoonEngine
import XCTest

@testable import StartupStudio

/// The chart's one hard promise is that it is a picture of the whole
/// company: everybody on it exactly once, and nobody drawn on top of
/// anybody else. Both are properties of the layout, so both are tested
/// here rather than left to a screenshot.
@MainActor
final class OrgChartTests: XCTestCase {
    private func founder() -> Employee {
        Employee(
            id: UUID(), name: "Mira Okafor",
            skills: SkillSet(coding: 70, design: 55, marketing: 40),
            weeklySalary: 0, assignment: .idle, isFounder: true,
            hiredDay: 0, appearanceSeed: 0x5EED, role: .founder
        )
    }

    private func staff(
        _ name: String, role: EmployeeRole, level: SeniorityLevel,
        bond: Double = 40, hired: Int = 10
    ) -> Employee {
        Employee(
            id: UUID(), name: name,
            skills: SkillSet(coding: 55, design: 45, marketing: 30),
            weeklySalary: 1_200, assignment: .idle, isFounder: false,
            hiredDay: hired, appearanceSeed: UInt64(abs(name.hashValue % 10_000)),
            level: level, role: role, founderBond: bond
        )
    }

    /// A studio of fourteen: builders on the floor, and all three
    /// departments staffed, at every rung of the ladder.
    private func fullStudio() -> [Employee] {
        [
            founder(),
            staff("Dev Rao", role: .backend, level: .lead, bond: 82, hired: 20),
            staff("Ana Beltrán", role: .designer, level: .senior, bond: 60, hired: 30),
            staff("Kofi Mensah", role: .qa, level: .mid, bond: 35, hired: 40),
            staff("Ines Duarte", role: .frontend, level: .mid, bond: 28, hired: 45),
            staff("Nils Berg", role: .frontend, level: .junior, bond: 12, hired: 60),
            staff("Yara Haddad", role: .backend, level: .junior, bond: 9, hired: 70),
            staff("Sam Idowu", role: .marketer, level: .senior, bond: 51, hired: 25),
            staff("Lena Fischer", role: .ops, level: .lead, bond: 66, hired: 15),
            staff("Ravi Shah", role: .ops, level: .junior, bond: 20, hired: 80),
            staff("Tom Alvi", role: .hr, level: .mid, bond: 44, hired: 50),
            staff("Cleo Marsh", role: .hr, level: .junior, bond: 15, hired: 90),
            staff("Sara Nowak", role: .lawyer, level: .senior, bond: 33, hired: 35),
            staff("Otto Lind", role: .lawyer, level: .junior, bond: 7, hired: 95),
        ]
    }

    // MARK: - Everybody, once

    func testEveryoneIsPlacedExactlyOnce() {
        for count in [1, 6, 14] {
            let people = Array(fullStudio().prefix(count))
            let layout = OrgChart.layout(employees: people)
            XCTAssertEqual(layout.nodes.count, people.count, "\(count) people")
            XCTAssertEqual(
                Set(layout.nodes.map(\.id)), Set(people.map(\.id)),
                "the chart of \(count) is missing somebody, or drew them twice"
            )
        }
    }

    func testNoTwoNodesOverlap() {
        for count in [1, 6, 14] {
            let layout = OrgChart.layout(employees: Array(fullStudio().prefix(count)))
            for (index, node) in layout.nodes.enumerated() {
                for other in layout.nodes[(index + 1)...] {
                    XCTAssertFalse(
                        node.frame.intersects(other.frame),
                        "\(node.employee.name) is drawn on top of \(other.employee.name)"
                    )
                }
            }
        }
    }

    func testEverybodyFitsInsideTheDrawing() {
        let layout = OrgChart.layout(employees: fullStudio())
        let canvas = CGRect(origin: .zero, size: layout.size)
        for node in layout.nodes {
            XCTAssertTrue(
                canvas.contains(node.frame),
                "\(node.employee.name) hangs off the edge of the chart"
            )
        }
    }

    func testAnEmptyCompanyDrawsNothing() {
        XCTAssertTrue(OrgChart.layout(employees: []).nodes.isEmpty)
    }

    /// An ousted or bought-out founder is replaced, and the company that is
    /// left still has an org — which is exactly the save that drew a blank
    /// screen before the founder became optional.
    func testACompanyWithNoFounderStillHasAChart() {
        let staff = fullStudio().filter { !$0.isFounder }
        let layout = OrgChart.layout(employees: staff)
        XCTAssertEqual(layout.nodes.count, staff.count)
        XCTAssertGreaterThan(layout.size.height, 0)
        XCTAssertTrue(
            layout.nodes.allSatisfy { node in
                node.parentID.map { id in layout.node(id: id) != nil } ?? true
            },
            "a line runs to somebody who is not on the chart"
        )
        let top = layout.nodes.map(\.position.y).min()
        XCTAssertTrue(
            layout.nodes.filter { $0.position.y == top }.allSatisfy { $0.parentID == nil },
            "the top rank hangs from nothing when there is no founder"
        )
        for (index, node) in layout.nodes.enumerated() {
            for other in layout.nodes[(index + 1)...] {
                XCTAssertFalse(node.frame.intersects(other.frame))
            }
        }
    }

    // MARK: - The shape

    func testTheFounderIsAloneAtTheTop() {
        let layout = OrgChart.layout(employees: fullStudio())
        let top = layout.nodes.map(\.position.y).min()
        let atTop = layout.nodes.filter { $0.position.y == top }
        XCTAssertEqual(atTop.count, 1)
        XCTAssertTrue(atTop.first?.employee.isFounder == true)
        XCTAssertNil(atTop.first?.parentID, "the founder reports to nobody")
    }

    func testDepartmentRolesHangUnderTheirOwnBranch() {
        let layout = OrgChart.layout(employees: fullStudio())
        XCTAssertEqual(
            Set(layout.branches.map(\.department)), Set([.legal, .hr, .ops]),
            "every staffed department is a branch"
        )
        for department in Department.allCases {
            let members = layout.nodes.filter { $0.employee.role.department == department }
            let xs = Set(members.map(\.position.x))
            let others = layout.nodes.filter {
                !$0.employee.isFounder && $0.employee.role.department != department
            }
            for other in others {
                XCTAssertFalse(
                    xs.contains(other.position.x),
                    "\(other.employee.name) is standing in the \(department) branch"
                )
            }
        }
    }

    func testSeniorityIsRank() {
        let layout = OrgChart.layout(employees: fullStudio())
        for node in layout.nodes where !node.employee.isFounder {
            for other in layout.nodes where !other.employee.isFounder {
                // `rank` climbs junior → lead, so the higher rank sits
                // nearer the founder, which is a smaller y.
                if node.employee.level.rank > other.employee.level.rank {
                    XCTAssertLessThan(
                        node.position.y, other.position.y,
                        "\(node.employee.name) is more senior than \(other.employee.name) "
                            + "but sits below them"
                    )
                }
            }
        }
    }

    func testALineRunsUpToTheNearestSeniorInTheSameBranch() {
        let layout = OrgChart.layout(employees: fullStudio())
        let byID = Dictionary(uniqueKeysWithValues: layout.nodes.map { ($0.id, $0) })
        for node in layout.nodes where !node.employee.isFounder {
            let parent = byID[node.parentID ?? UUID()]
            XCTAssertNotNil(parent, "\(node.employee.name) hangs from nobody")
            guard let parent else { continue }
            XCTAssertLessThan(parent.position.y, node.position.y, "a line runs upward")
            if !parent.employee.isFounder {
                XCTAssertEqual(
                    parent.employee.role.department, node.employee.role.department,
                    "\(node.employee.name)'s line leaves their branch"
                )
                XCTAssertGreaterThan(
                    parent.employee.level.rank, node.employee.level.rank,
                    "\(node.employee.name) reports to somebody no more senior"
                )
            }
        }
    }

    func testTheSoleFounderIsTheWholeChart() {
        let layout = OrgChart.layout(employees: [founder()])
        XCTAssertEqual(layout.nodes.count, 1)
        XCTAssertTrue(layout.branches.isEmpty)
        XCTAssertGreaterThan(layout.size.width, 0)
        XCTAssertGreaterThan(layout.size.height, 0)
    }

    // MARK: - Friendships

    func testFriendshipsAreDrawnOnlyBetweenPlacedPeople() {
        let people = fullStudio()
        let pair = Friendship(a: people[1].id, b: people[3].id, strength: 71, sinceDay: 40)
        let ghost = Friendship(a: people[1].id, b: UUID(), strength: 50, sinceDay: 40)
        let layout = OrgChart.layout(employees: people, friendships: [pair, ghost])
        XCTAssertEqual(layout.friendships.count, 1, "a friendship with somebody who left is not drawn")
        let link = layout.friendships.first
        XCTAssertEqual(link?.strength, 71)
        // `Friendship` normalises the pair by uuid, so the link's ends are
        // the two people in whichever order it chose.
        XCTAssertEqual(
            Set([link?.a, link?.b].compactMap { $0 }), Set([people[1].id, people[3].id])
        )
        XCTAssertEqual(
            [link?.from, link?.to].compactMap { $0 }.sorted { $0.y < $1.y },
            [people[1].id, people[3].id]
                .compactMap { layout.node(id: $0)?.position }
                .sorted { $0.y < $1.y }
        )
    }

    func testTheLayoutIsTheSameEveryTimeItIsRead() {
        let people = fullStudio()
        XCTAssertEqual(OrgChart.layout(employees: people), OrgChart.layout(employees: people))
    }
}
