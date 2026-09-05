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
        case .founder: String(localized: "Founder", comment: "Job title on a badge beside a name. Keep it short - one word if possible")
        case .frontend: String(localized: "Frontend", comment: "Job title on a badge beside a name. Keep it short - one word if possible")
        case .backend: String(localized: "Backend", comment: "Job title on a badge beside a name. Keep it short - one word if possible")
        case .designer: String(localized: "Designer", comment: "Job title on a badge beside a name. Keep it short - one word if possible")
        case .qa: String(localized: "QA", comment: "Job title on a badge beside a name. Keep it short - one word if possible")
        case .marketer: String(localized: "Marketer", comment: "Job title on a badge beside a name. Keep it short - one word if possible")
        case .lawyer: String(localized: "Lawyer", comment: "Job title on a badge beside a name. Keep it short - one word if possible")
        case .hr: String(localized: "HR", comment: "Job title on a badge beside a name. Keep it short - one word if possible")
        case .ops: String(localized: "Ops", comment: "Job title on a badge beside a name. Keep it short - one word if possible")
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
        case .founder: String(localized: "a founder", comment: "Job title with its article, dropped into a sentence such as You need a lawyer")
        case .frontend: String(localized: "a frontend dev", comment: "Job title with its article, dropped into a sentence such as You need a lawyer")
        case .backend: String(localized: "a backend dev", comment: "Job title with its article, dropped into a sentence such as You need a lawyer")
        case .designer: String(localized: "a designer", comment: "Job title with its article, dropped into a sentence such as You need a lawyer")
        case .qa: String(localized: "a QA engineer", comment: "Job title with its article, dropped into a sentence such as You need a lawyer")
        case .marketer: String(localized: "a marketer", comment: "Job title with its article, dropped into a sentence such as You need a lawyer")
        case .lawyer: String(localized: "a lawyer", comment: "Job title with its article, dropped into a sentence such as You need a lawyer")
        case .hr: String(localized: "an HR specialist", comment: "Job title with its article, dropped into a sentence such as You need a lawyer")
        case .ops: String(localized: "an ops manager", comment: "Job title with its article, dropped into a sentence such as You need a lawyer")
        }
    }
}
