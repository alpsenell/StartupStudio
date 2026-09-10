import SwiftUI
import TycoonEngine

/// The Departments card on HQ (below the office): Legal, People & HR, and
/// Operations, each either active — who staffs it and what it does — or a
/// hint about which hire forms it and the office tier that unlocks those
/// candidates.
struct DepartmentsCard: View {
    let engine: GameEngine

    // MARK: U1 (ux: the first-hour fixes)
    /// C8: a department is drawn in full once it exists or once the office
    /// is big enough for the hire that forms it. The rest are one line.
    private var formable: [Department] {
        let tier = engine.state.company.officeTier
        return Department.allCases.filter {
            engine.state.hasDepartment($0) || tier.rank >= $0.minOfficeTier.rank
        }
    }

    private var later: [Department] {
        Department.allCases.filter { !formable.contains($0) }
    }

    /// "Departments open at the Loft" for a garage founder, who can form
    /// none; "Operations opens at the Studio" once the Loft has formed the
    /// first two.
    private var laterLine: String {
        let tier = later.map(\.minOfficeTier).min { $0.rank < $1.rank } ?? .loft
        if formable.isEmpty {
            return String(localized: "Departments open at the \(tier.displayName)", comment: "Team tab, one line while no department can be formed yet: the office tier that allows the first ones")
        }
        let names = later.map(\.cardTitle).joined(separator: " and ")
        return later.count == 1
            ? String(localized: "\(names) opens at the \(tier.displayName)", comment: "Team tab, under the departments: the one department the office is still too small for, and the office tier that allows it")
            : String(localized: "\(names) open at the \(tier.displayName)", comment: "Team tab, under the departments: the departments the office is still too small for, and the office tier that allows them")
    }
    // MARK: end U1

    var body: some View {
        // MARK: U1 (ux: the first-hour fixes)
        // C8: a solo garage founder sees one line, not three locked rows.
        if formable.isEmpty {
            DepartmentsLaterLine(text: laterLine)
        } else {
            CardView("Departments", systemImage: "person.3.sequence.fill") {
                VStack(spacing: 0) {
                    ForEach(Array(formable.enumerated()), id: \.element) { index, department in
                        DepartmentRow(
                            department: department,
                            staff: staffNames(for: department),
                            isActive: engine.state.hasDepartment(department),
                            officeTier: engine.state.company.officeTier
                        )
                        if index < formable.count - 1 || !later.isEmpty {
                            Divider()
                        }
                    }
                    if !later.isEmpty {
                        DepartmentsLaterLine(text: laterLine)
                            .padding(.vertical, Theme.Spacing.sm)
                    }
                }
            }
        }
        // MARK: end U1
    }

    /// Everyone whose role belongs to the department, in hire order.
    private func staffNames(for department: Department) -> [String] {
        engine.state.employees
            .filter { $0.role.department == department }
            .sorted { $0.hiredDay < $1.hiredDay }
            .map(\.name)
    }
}

// MARK: U1 (ux: the first-hour fixes)
/// C8: the departments the office cannot hold yet, as one quiet line.
private struct DepartmentsLaterLine: View {
    let text: String

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "person.3.sequence.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
// MARK: end U1

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
