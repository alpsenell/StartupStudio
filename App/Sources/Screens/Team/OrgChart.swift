import CoreGraphics
import Foundation
import TycoonEngine

/// The company as a tree: who reports to whom, drawn from the two things
/// the engine actually knows about a hire — the department their role
/// staffs, and how senior they are.
///
/// There is no reporting line in the save, and inventing one would be a
/// lie the rest of the game does not tell. So the tree is derived: a role
/// that staffs a department hangs under that department's branch, everyone
/// else hangs under the founder, and *within* a branch the ladder is the
/// hierarchy — a junior's line runs up to the mid above them, the mid's to
/// the senior, the lead's to the founder. That is exactly the structure the
/// promotion ladder already implies, and it changes the moment somebody is
/// promoted, which is the point.
enum OrgChart {
    // MARK: Metrics

    /// A node's drawn box. The portrait is 34pt with a name and two badges
    /// under it.
    static let nodeSize = CGSize(width: 86, height: 96)
    /// Centre-to-centre spacing between two nodes on the same rank.
    static let columnStride: CGFloat = 98
    /// Centre-to-centre spacing between ranks.
    static let rowStride: CGFloat = 124
    /// The gap between two branches.
    static let branchGap: CGFloat = 32
    /// Padding around the whole drawing.
    static let padding: CGFloat = 24

    /// The ladder, most senior first — the order the ranks are drawn in.
    static let ladder: [SeniorityLevel] = [.lead, .senior, .mid, .junior]

    // MARK: Model

    /// One person, placed.
    struct Node: Identifiable, Equatable {
        let employee: Employee
        /// Centre of the node's box, in chart space.
        let position: CGPoint
        /// Who this person's line runs up to; `nil` for the founder.
        let parentID: UUID?

        var id: UUID { employee.id }
        /// The connecting line's weight comes from here: how close this
        /// person is to the founder, 0...100.
        var bond: Double { employee.founderBond }

        var frame: CGRect {
            CGRect(
                x: position.x - OrgChart.nodeSize.width / 2,
                y: position.y - OrgChart.nodeSize.height / 2,
                width: OrgChart.nodeSize.width,
                height: OrgChart.nodeSize.height
            )
        }
    }

    /// A department's label, over the branch it names.
    struct BranchLabel: Identifiable, Equatable {
        let department: Department
        let position: CGPoint
        let headcount: Int

        var id: String { department.rawValue }
    }

    /// A dotted line between two people who are friends.
    struct FriendLink: Identifiable, Equatable {
        let a: UUID
        let b: UUID
        let from: CGPoint
        let to: CGPoint
        let strength: Double

        var id: String { "\(a)-\(b)" }
    }

    /// Everything the view needs to draw, and the tests need to check.
    struct Layout: Equatable {
        var nodes: [Node] = []
        var branches: [BranchLabel] = []
        var friendships: [FriendLink] = []
        var size: CGSize = .zero

        func node(id: UUID) -> Node? { nodes.first { $0.id == id } }
    }

    // MARK: Layout

    /// Places everybody. Pure: the same roster always lays out the same
    /// way, which is what makes "nobody overlaps" a testable claim.
    static func layout(employees: [Employee], friendships: [Friendship] = []) -> Layout {
        // The founder is optional, and that is not a defensive `if let`: a
        // founder who is ousted or bought out is replaced, and the company
        // that is left still has an org. Without a founder the branches
        // simply start at the top row and their leads hang from nothing.
        let founder = employees.first(where: \.isFounder)
        let staff = employees.filter { !$0.isFounder }
        guard founder != nil || !staff.isEmpty else { return Layout() }

        // 1. Branches: the departments that exist, then the floor — the
        //    people whose role staffs nothing, under the founder directly.
        let departments = Department.allCases.filter { department in
            staff.contains { $0.role.department == department }
        }
        let groups: [(department: Department?, members: [Employee])] =
            [(nil, staff.filter { $0.role.department == nil })]
                + departments.map { department in
                    (department, staff.filter { $0.role.department == department })
                }

        // 2. Ranks: the ladder rungs anybody actually stands on, so a
        //    company of four juniors is one row deep rather than four.
        let occupied = ladder.filter { level in staff.contains { $0.level == level } }
        let firstStaffRow = founder == nil ? 0 : 1
        let rowIndex = Dictionary(
            uniqueKeysWithValues: occupied.enumerated().map { ($1, $0 + firstStaffRow) }
        )

        // 3. Bands: each branch is as wide as its widest rank.
        var cursor = padding
        var bands: [(group: Int, centre: CGFloat, members: [SeniorityLevel: [Employee]])] = []
        for (index, group) in groups.enumerated() where !group.members.isEmpty {
            var byLevel: [SeniorityLevel: [Employee]] = [:]
            for level in occupied {
                let members = group.members
                    .filter { $0.level == level }
                    .sorted { ($0.hiredDay, $0.name) < ($1.hiredDay, $1.name) }
                if !members.isEmpty { byLevel[level] = members }
            }
            let widest = byLevel.values.map(\.count).max() ?? 1
            let width = CGFloat(widest) * columnStride
            bands.append((index, cursor + width / 2, byLevel))
            cursor += width + branchGap
        }

        let contentWidth = max(cursor - branchGap + padding, nodeSize.width + 2 * padding)
        let depth = occupied.count + firstStaffRow
        let contentHeight = CGFloat(max(0, depth - 1)) * rowStride + nodeSize.height + 2 * padding

        var layout = Layout()
        layout.size = CGSize(width: contentWidth, height: contentHeight)

        // 4. The founder, centred over the whole company.
        if let founder {
            layout.nodes.append(
                Node(
                    employee: founder,
                    position: CGPoint(x: contentWidth / 2, y: rowY(0)),
                    parentID: nil
                )
            )
        }

        // 5. Everybody else, rank by rank, centred inside their band.
        for band in bands {
            for (levelIndex, level) in occupied.enumerated() {
                guard let members = band.members[level], !members.isEmpty else { continue }
                let row = rowIndex[level] ?? levelIndex + firstStaffRow
                // The line runs up to the nearest more senior person in the
                // same branch, and to the founder when there is nobody.
                let parent = occupied[..<levelIndex].reversed()
                    .compactMap { band.members[$0]?.first }
                    .first
                for (offset, member) in members.enumerated() {
                    let shift = CGFloat(offset) - CGFloat(members.count - 1) / 2
                    layout.nodes.append(
                        Node(
                            employee: member,
                            position: CGPoint(x: band.centre + shift * columnStride, y: rowY(row)),
                            parentID: parent?.id ?? founder?.id
                        )
                    )
                }
            }
            // 6. The branch's name, above its topmost rank.
            if let department = groups[band.group].department,
               let top = occupied.first(where: { band.members[$0] != nil }),
               let row = rowIndex[top] {
                layout.branches.append(
                    BranchLabel(
                        department: department,
                        position: CGPoint(
                            x: band.centre,
                            y: rowY(row) - nodeSize.height / 2 - 14
                        ),
                        headcount: groups[band.group].members.count
                    )
                )
            }
        }

        // 7. The friendships, as they fall between placed people.
        let placed = Dictionary(uniqueKeysWithValues: layout.nodes.map { ($0.id, $0.position) })
        layout.friendships = friendships.compactMap { friendship in
            guard let from = placed[friendship.a], let to = placed[friendship.b] else { return nil }
            return FriendLink(
                a: friendship.a, b: friendship.b,
                from: from, to: to, strength: friendship.strength
            )
        }
        .sorted { $0.id < $1.id }

        return layout
    }

    private static func rowY(_ row: Int) -> CGFloat {
        padding + CGFloat(row) * rowStride + nodeSize.height / 2
    }
}
