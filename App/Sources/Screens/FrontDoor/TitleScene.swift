import PixelKit
import SwiftUI
import TycoonEngine

/// The office at night behind the title: the current slot's room with
/// its people at their desks, or an empty garage when there is nothing
/// to continue. Cosmetic only — nothing here reads back into the game.
enum TitleScene {
    /// The garage before anyone has founded anything, lights off.
    static let emptyGarage = OfficeSceneInput(
        tier: .garage,
        occupants: [],
        ambience: OfficeAmbience(timeOfDay: .night)
    )

    /// The company as it stands, after hours: the tier, the amenities,
    /// the whole team at their desks, and the season's weather past the
    /// windows. The room's own clock rolls on from night while the
    /// player looks at it.
    static func input(for state: GameState) -> OfficeSceneInput {
        let tier = OfficeTierStyle(rawValue: state.company.officeTier.rawValue) ?? .garage
        let occupants = state.employees
            .sorted { lhs, rhs in
                if lhs.isFounder != rhs.isFounder { return lhs.isFounder }
                return lhs.hiredDay < rhs.hiredDay
            }
            .map { employee in
                Occupant(
                    id: employee.id,
                    appearance: CharacterAppearance(seed: employee.appearanceSeed),
                    status: status(for: employee),
                    isFounder: employee.isFounder,
                    mood: mood(employee.morale),
                    role: employee.isFounder
                        ? .founder
                        : (RoleLook(rawValue: employee.role.rawValue) ?? .none),
                    name: employee.name
                )
            }
        let staff = state.employees.filter { !$0.isFounder }
        let morale = staff.isEmpty
            ? 60
            : staff.reduce(0) { $0 + $1.morale } / Double(staff.count)
        let weather: Weather = switch state.calendar.season {
        case .winter: .snow
        case .autumn: .rain
        case .spring, .summer: .clear
        }
        return OfficeSceneInput(
            tier: tier,
            occupants: occupants,
            amenities: Set(state.amenities.compactMap { AmenityStyle(rawValue: $0.rawValue) }),
            ambience: OfficeAmbience(timeOfDay: .night, weather: weather, teamMood: mood(morale))
        )
    }

    /// The desk each role sits at. The title screen has no assignment to
    /// read into a bubble, so everyone is at their own work.
    private static func status(for employee: Employee) -> WorkStatus {
        switch employee.role {
        case .lawyer: .legal
        case .hr: .peopleOps
        case .ops: .operations
        case .qa: .testing
        case .designer: .designing
        case .marketer: .marketing
        case .frontend, .backend: .coding
        case .founder: employee.skills.coding >= employee.skills.design ? .coding : .designing
        }
    }

    private static func mood(_ morale: Double) -> MoodLevel {
        switch morale {
        case ..<38: .low
        case ..<70: .okay
        default: .great
        }
    }
}
