import SwiftUI
import TycoonEngine
import UIKit

/// Compact role capsule (icon + short name) shown next to names on roster
/// rows, hiring cards, and the manage-sheet header. `prominent` is the
/// hiring-card look: accent tint, a step larger — role is the headline
/// there.
struct RoleBadge: View {
    let role: EmployeeRole
    var prominent: Bool = false

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: role.systemImage)
                .font((prominent ? Font.caption : .caption2).weight(.semibold))
            Text(role.shortName)
                .font((prominent ? Font.caption : .caption2).weight(.bold))
                .kerning(0.3)
                .lineLimit(1)
        }
        .foregroundStyle(prominent ? Theme.accent : Color.secondary)
        .padding(.horizontal, Theme.Spacing.xs + 2)
        .padding(.vertical, 2)
        .background(
            prominent ? Theme.accent.opacity(0.15) : Theme.chipBackground,
            in: Capsule()
        )
        .accessibilityLabel("Role: \(role.displayName)")
    }
}

// MARK: - Role presentation

extension EmployeeRole {
    /// Badge text — short enough to sit beside a name on one line.
    var shortName: String {
        switch self {
        case .founder: "Founder"
        case .frontend: "Frontend"
        case .backend: "Backend"
        case .designer: "Designer"
        case .qa: "QA"
        case .marketer: "Marketer"
        case .lawyer: "Lawyer"
        case .hr: "HR"
        case .ops: "Ops"
        }
    }

    var systemImage: String {
        switch self {
        case .founder: "crown"
        case .frontend: "rectangle.3.group"
        case .backend: "server.rack"
        case .designer: "paintbrush.pointed"
        case .qa: "ladybug"
        case .marketer: "megaphone"
        case .lawyer: Self.lawyerSymbol
        case .hr: "person.2"
        case .ops: "wrench.and.screwdriver"
        }
    }

    /// "scale.3d" isn't in every SF Symbols release; fall back to the
    /// courthouse when the runtime doesn't have it.
    private static let lawyerSymbol: String =
        UIImage(systemName: "scale.3d") != nil ? "scale.3d" : "building.columns"

    /// Article for hint copy: "a lawyer", "an HR specialist".
    var hiringNoun: String {
        switch self {
        case .founder: "a founder"
        case .frontend: "a frontend dev"
        case .backend: "a backend dev"
        case .designer: "a designer"
        case .qa: "a QA engineer"
        case .marketer: "a marketer"
        case .lawyer: "a lawyer"
        case .hr: "an HR specialist"
        case .ops: "an ops manager"
        }
    }
}
