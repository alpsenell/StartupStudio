import SwiftUI
import TycoonEngine

// Presentation helpers for the HQ tab's departments and amenities: display
// names, icons, effect copy, and the mirrored engine rules the UI uses for
// button states and hint text. The engine enforces every rule; these only
// explain and predict.

// MARK: - Office tiers

extension OfficeTier {
    /// Position on the garage → campus ladder, for "at least a loft" style
    /// comparisons (amenity and department unlock tiers).
    var rank: Int {
        OfficeTier.allCases.firstIndex(of: self) ?? 0
    }
}

// MARK: - Departments

extension Department {
    /// Row title on the Departments card.
    var cardTitle: String {
        switch self {
        case .legal: "Legal"
        case .hr: "People & HR"
        case .ops: "Operations"
        }
    }

    var systemImage: String {
        switch self {
        case .legal: EmployeeRole.lawyer.systemImage
        case .hr: EmployeeRole.hr.systemImage
        case .ops: EmployeeRole.ops.systemImage
        }
    }

    /// What the department does for the company while staffed — the
    /// engine owns the numbers.
    var effectSummary: String {
        switch self {
        case .legal:
            "Contract penalties halved, +10% payouts, one extra offer a week."
        case .hr:
            "+5 morale target, candidates refresh 4 days sooner, staff tolerate low morale 7 days longer, training 30% cheaper."
        case .ops:
            "Amenity upkeep −30%, office rent −10%."
        }
    }

    /// The role whose hire forms this department (derived from the
    /// engine's role → department mapping).
    var formingRole: EmployeeRole {
        EmployeeRole.allCases.first { $0.department == self } ?? .lawyer
    }

    /// The office tier from which candidates of the forming role start
    /// showing up: lawyers and HR at the loft, ops managers at the studio.
    /// Mirrors the engine's candidate generation.
    var minOfficeTier: OfficeTier {
        switch self {
        case .legal, .hr: .loft
        case .ops: .studio
        }
    }
}

// MARK: - Amenities

extension Amenity {
    var systemImage: String {
        switch self {
        case .gameRoom: "gamecontroller.fill"
        case .cafeteria: "fork.knife"
        case .shuttle: "bus.fill"
        case .gym: "dumbbell.fill"
        }
    }

    /// Qualitative effect summary — the engine owns the numbers.
    var effectSummary: String {
        switch self {
        case .gameRoom: "Somewhere to blow off steam between sprints."
        case .cafeteria: "Free lunch keeps the team fed and at their desks."
        case .shuttle: "Door-to-door commute, no parking fights."
        case .gym: "On-site workouts for the team — and the founder."
        }
    }
}

/// The Ops department's amenity upkeep discount, mirrored for the upkeep
/// readout on the amenities sheet (the engine applies the real one).
let opsAmenityUpkeepDiscount = 0.30

/// Weekly upkeep as the player will actually pay it: the amenity's base
/// `weeklyCost`, discounted while the Ops department is staffed.
func amenityWeeklyUpkeep(_ weeklyCost: Int, opsActive: Bool) -> Int {
    guard opsActive else { return weeklyCost }
    return Int((Double(weeklyCost) * (1 - opsAmenityUpkeepDiscount)).rounded())
}
