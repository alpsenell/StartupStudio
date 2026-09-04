import PixelKit
import SwiftUI
import TycoonEngine

/// The company as a picture: the founder at the top, departments as
/// branches, the ladder as rank, a portrait at every node.
///
/// Two lines carry the things a roster cannot show. The line up to
/// somebody's parent is drawn at a weight set by how close they are to the
/// founder, so a studio the founder has kept up with reads as heavy and
/// solid, and one they have neglected reads as a set of hairlines. The
/// dotted lines across the chart are friendships — the shape of the room,
/// which is not the shape of the org.
struct OrgChartView: View {
    let engine: GameEngine
    /// Tapping a node opens their manage sheet; the founder's levers live
    /// on the Life tab, so the founder is not tappable here.
    let onSelect: (Employee) -> Void

    private var layout: OrgChart.Layout {
        OrgChart.layout(
            employees: engine.state.employees,
            friendships: engine.state.friendships
        )
    }

    var body: some View {
        let layout = layout
        return ScrollView([.horizontal, .vertical]) {
            if layout.nodes.isEmpty {
                // A company can genuinely have nobody on it — the founder
                // ousted or bought out and no hires — and a blank scroll
                // view would read as a broken screen rather than an empty
                // one.
                CardView("Nobody on the chart", systemImage: "person.2.slash") {
                    Text("There is nobody on the payroll to draw.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(Theme.Spacing.lg)
            } else {
                OrgChartCanvas(layout: layout, onSelect: onSelect)
                    .padding(.bottom, Theme.Spacing.xl)
            }
        }
        .background(Theme.screenBackground)
    }
}

/// The chart itself, without the scroll view — the shape the snapshot
/// tests render (an `ImageRenderer` over a `ScrollView` produces a blank
/// PNG).
struct OrgChartCanvas: View {
    let layout: OrgChart.Layout
    let onSelect: (Employee) -> Void

    var body: some View {
        // Everything is placed by `.offset` from the top-left, and the
        // lines are one `Canvas`, because the chart lives inside a two-way
        // `ScrollView`: there the proposed size is unbounded on both axes,
        // and `.position` — which hands that proposal straight back — left
        // the whole chart collapsed to nothing on the real screen while
        // rendering perfectly in a snapshot. An offset owes the parent's
        // proposal nothing.
        ZStack(alignment: .topLeading) {
            lines
                .frame(width: layout.size.width, height: layout.size.height)
            ForEach(layout.branches) { branch in
                branchLabel(branch)
            }
            ForEach(layout.nodes) { node in
                OrgChartNodeView(node: node) { onSelect(node.employee) }
                    .frame(width: OrgChart.nodeSize.width, height: OrgChart.nodeSize.height)
                    .offset(
                        x: node.position.x - OrgChart.nodeSize.width / 2,
                        y: node.position.y - OrgChart.nodeSize.height / 2
                    )
            }
        }
        .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
        .accessibilityLabel("Org chart, \(layout.nodes.count) people")
    }

    // MARK: - Lines

    /// Both kinds of line in one pass. A person's line runs up to whoever
    /// they hang from as an elbow, so a wide rank does not become a fan of
    /// diagonals, at a weight set by their bond with the founder: 1pt at no
    /// bond, 4pt at a bond of 100. The dotted ones are friendships — who
    /// actually likes working with whom.
    private var lines: some View {
        Canvas { context, _ in
            for node in layout.nodes {
                guard let parentID = node.parentID,
                      let parent = layout.node(id: parentID) else { continue }
                let bond = min(1, node.bond / 100)
                context.stroke(
                    elbow(from: parent.position, to: node.position),
                    with: .color(Theme.accent.opacity(0.25 + 0.5 * bond)),
                    style: StrokeStyle(
                        lineWidth: 1 + 3 * bond, lineCap: .round, lineJoin: .round
                    )
                )
            }
            for link in layout.friendships {
                var path = Path()
                path.move(to: link.from)
                path.addLine(to: link.to)
                context.stroke(
                    path,
                    with: .color(Theme.romance.opacity(0.2 + 0.5 * min(1, link.strength / 100))),
                    style: StrokeStyle(lineWidth: 1.5, dash: [3, 4])
                )
            }
        }
    }

    /// A parent-to-child elbow: down out of the parent, across, down into
    /// the child.
    private func elbow(from parent: CGPoint, to child: CGPoint) -> Path {
        let top = parent.y + OrgChart.nodeSize.height / 2
        let bottom = child.y - OrgChart.nodeSize.height / 2
        let mid = (top + bottom) / 2
        return Path { path in
            path.move(to: CGPoint(x: parent.x, y: top))
            path.addLine(to: CGPoint(x: parent.x, y: mid))
            path.addLine(to: CGPoint(x: child.x, y: mid))
            path.addLine(to: CGPoint(x: child.x, y: bottom))
        }
    }

    // MARK: - Branch label

    private func branchLabel(_ branch: OrgChart.BranchLabel) -> some View {
        HStack(spacing: 4) {
            Text(branch.department.displayName.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .kerning(0.6)
            Text(branch.headcount.formatted(.number.locale(Theme.gameLocale)))
                .font(Theme.Typography.number(.caption2))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 2)
        .background(Theme.chipBackground, in: Capsule())
        .fixedSize()
        // Centred over the branch by giving the label a known width to sit
        // in the middle of, so it can be offset like everything else.
        .frame(width: OrgChart.columnStride * 2)
        .offset(
            x: branch.position.x - OrgChart.columnStride,
            y: branch.position.y - 10
        )
        .accessibilityLabel("\(branch.department.displayName), \(branch.headcount) people")
    }
}

/// One person on the chart.
struct OrgChartNodeView: View {
    let node: OrgChart.Node
    let action: () -> Void

    private var employee: Employee { node.employee }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                PixelPortrait(
                    seed: employee.appearanceSeed,
                    isFounder: employee.isFounder,
                    role: employee.isFounder
                        ? .founder
                        : (RoleLook(rawValue: employee.role.rawValue) ?? .none),
                    size: employee.isFounder ? 40 : 34
                )
                Text(employee.name)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.primary)
                Text(employee.role.shortName)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !employee.isFounder {
                    Text(employee.level.displayName.uppercased())
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .kerning(0.4)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Theme.chipBackground, in: Capsule())
                }
            }
            .padding(.vertical, Theme.Spacing.xs)
            .padding(.horizontal, 2)
            .frame(width: OrgChart.nodeSize.width)
            .background(
                Theme.cardBackground,
                in: RoundedRectangle(cornerRadius: Theme.cornerRadius - 4, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius - 4, style: .continuous)
                    .strokeBorder(
                        employee.isFounder ? Theme.accent : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressableRow)
        .disabled(employee.isFounder)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts = [employee.name, employee.role.displayName]
        if !employee.isFounder {
            parts.append(employee.level.displayName)
            parts.append("bond with you \(Int(node.bond.rounded())) of 100")
        }
        return parts.joined(separator: ", ")
    }
}
