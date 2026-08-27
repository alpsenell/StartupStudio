import SwiftUI
import TycoonEngine

/// The Departments card on HQ (below the office): Legal, People & HR, and
/// Operations, each either active — who staffs it and what it does — or a
/// hint about which hire forms it and the office tier that unlocks those
/// candidates.
struct DepartmentsCard: View {
    let engine: GameEngine

    var body: some View {
        CardView("Departments", systemImage: "person.3.sequence.fill") {
            VStack(spacing: 0) {
                ForEach(Array(Department.allCases.enumerated()), id: \.element) { index, department in
                    DepartmentRow(
                        department: department,
                        staff: staffNames(for: department),
                        isActive: engine.state.hasDepartment(department),
                        officeTier: engine.state.company.officeTier
                    )
                    if index < Department.allCases.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    /// Everyone whose role belongs to the department, in hire order.
    private func staffNames(for department: Department) -> [String] {
        engine.state.employees
            .filter { $0.role.department == department }
            .sorted { $0.hiredDay < $1.hiredDay }
            .map(\.name)
    }
}

private struct DepartmentRow: View {
    let department: Department
    let staff: [String]
    let isActive: Bool
    let officeTier: OfficeTier

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: department.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isActive ? Theme.accent : .secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Theme.Spacing.xs + 2) {
                    Text(department.cardTitle)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.positiveCash)
                    }
                }
                if isActive {
                    Text(staffLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(department.effectSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(inactiveHint)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Theme.Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var staffLine: String {
        staff.isEmpty ? "Staffed" : "Staffed by " + staff.joined(separator: ", ")
    }

    /// "Hire a lawyer to form Legal — unlocks at Loft" while the office is
    /// too small for those candidates; the unlock suffix drops once the
    /// tier is reached.
    private var inactiveHint: String {
        let base = "Hire \(department.formingRole.hiringNoun) to form \(department.cardTitle)"
        let minTier = department.minOfficeTier
        return officeTier.rank < minTier.rank
            ? base + " — unlocks at \(minTier.displayName)"
            : base
    }

    private var accessibilityLabel: String {
        isActive
            ? "\(department.cardTitle) department active. \(staffLine). \(department.effectSummary)"
            : "\(department.cardTitle) department inactive. \(inactiveHint)"
    }
}
