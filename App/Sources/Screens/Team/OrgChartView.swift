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
        ScrollView([.horizontal, .vertical]) {
            OrgChartCanvas(layout: layout, onSelect: onSelect)
                .padding(.bottom, Theme.Spacing.xl)
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
        ZStack(alignment: .topLeading) {
            reportingLines
            friendshipLines
            ForEach(layout.branches) { branch in
                branchLabel(branch)
            }
            ForEach(layout.nodes) { node in
                OrgChartNodeView(node: node) { onSelect(node.employee) }
                    .frame(width: OrgChart.nodeSize.width, height: OrgChart.nodeSize.height)
                    .position(node.position)
            }
        }
        .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
        .accessibilityLabel("Org chart, \(layout.nodes.count) people")
    }

    // MARK: - Lines

    /// One line per person, up to whoever they hang from, drawn as an
    /// elbow so a wide rank does not become a fan of diagonals. The weight
    /// is the bond: 1pt at no bond, 4pt at a bond of 100.
    private var reportingLines: some View {
        ForEach(layout.nodes) { node in
            if let parentID = node.parentID, let parent = layout.node(id: parentID) {
                elbow(from: parent.position, to: node.position)
                    .stroke(
                        Theme.accent.opacity(0.25 + 0.5 * min(1, node.bond / 100)),
                        style: StrokeStyle(
                            lineWidth: 1 + 3 * min(1, node.bond / 100),
                            lineCap: .round, lineJoin: .round
                        )
                    )
            }
        }
    }

    /// The dotted lines: who actually likes working with whom.
    private var friendshipLines: some View {
        ForEach(layout.friendships) { link in
            Path { path in
                path.move(to: link.from)
                path.addLine(to: link.to)
            }
            .stroke(
                Theme.romance.opacity(0.2 + 0.5 * min(1, link.strength / 100)),
                style: StrokeStyle(lineWidth: 1.5, dash: [3, 4])
            )
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
        .position(branch.position)
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
