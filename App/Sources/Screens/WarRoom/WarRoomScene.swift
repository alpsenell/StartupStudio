import PixelKit
import SwiftUI
import TycoonContent
import TycoonEngine

/// The office as the war room sees it: the whole crew at their desks, with
/// the people on the build doing the build's work, the pressure *this*
/// build is under, the evening light of a launch week, and the cheer when
/// it ships.
///
/// HQ's office card composes the same room for the company as a whole —
/// the worst build's bugs, the day's celebration read out of the event
/// log. This reading is narrower on purpose: the bug load is this build's,
/// and the celebration is the reveal the room is playing, keyed by the
/// room's own token so it fires exactly once.
@MainActor
enum WarRoomScene {
    /// Everything the scene is a function of, for `OfficeSceneView`.
    static func input(
        for product: Product,
        engine: GameEngine,
        celebrationToken: Int?
    ) -> OfficeSceneInput {
        let state = engine.state
        var input = OfficeSceneInput(
            tier: OfficeTierStyle(rawValue: state.company.officeTier.rawValue) ?? .garage,
            occupants: occupants(for: product, state: state, content: engine.content),
            amenities: Set(state.amenities.compactMap { AmenityStyle(rawValue: $0.rawValue) }),
            ambience: ambience(state: state),
            celebration: celebration(for: product, token: celebrationToken)
        )
        input.pressure = pressure(for: product, engine: engine)
        return input
    }

    /// What this build is under: the pace, the runway, its own bugs, and
    /// anyone about to walk out mid-launch.
    static func pressure(for product: Product, engine: GameEngine) -> OfficePressure {
        let state = engine.state
        let cash = state.company.cash
        let burn = engine.weeklyBurn
        let runway: Int? = burn > 0 && cash >= 0 ? cash / burn : nil

        let bugs: Int = if case .development(let dev) = product.stage { dev.openBugs } else { 0 }
        let bugLoad = bugs >= 12 ? 3 : bugs >= 6 ? 2 : bugs >= 2 ? 1 : 0

        var departing: Set<UUID> = []
        if let notice = state.economy.pendingResignation { departing.insert(notice.employeeID) }
        if let poach = state.rivals.pendingPoach { departing.insert(poach.employeeID) }

        return OfficePressure(
            crunch: state.economy.workPace == .crunch,
            runwayWeeks: runway,
            inDebt: cash < 0,
            bugLoad: bugLoad,
            departing: departing,
            pendingOffer: state.rivals.pendingBuyout != nil
        )
    }

    /// Launch week is worked into the evening: the room opens at dusk and
    /// rolls on from there. The weather is the season's.
    static func ambience(state: GameState) -> OfficeAmbience {
        let calendar = state.calendar
        let weather: Weather = switch calendar.season {
        case .winter: .snow
        case .autumn: .rain
        case .spring, .summer: .clear
        }
        let staff = state.employees.filter { !$0.isFounder }
        let morale = staff.isEmpty ? 60 : staff.reduce(0) { $0 + $1.morale } / Double(staff.count)
        return OfficeAmbience(
            timeOfDay: .dusk,
            weather: weather,
            isWeekend: calendar.isWeekend,
            teamMood: mood(morale)
        )
    }

    /// The shipped cheer, once the reveal has a score and a token.
    static func celebration(for product: Product, token: Int?) -> OfficeSceneInput.Celebration? {
        guard let token, case .released(let info) = product.stage, !info.reviews.isEmpty else { return nil }
        // T7: the cheer is for the verdicts that are out on launch day.
        return OfficeSceneInput.Celebration(kind: .shipped(score: info.visibleAverageScore(on: info.launchDay)), token: token)
    }

    /// Founder first, then by hire day — the same desk order HQ uses, so
    /// nobody changes seats between the office card and the room.
    static func occupants(for product: Product, state: GameState, content: ContentCatalog) -> [Occupant] {
        let founderAway = state.life.isAway(day: state.day)
        return state.employees
            .sorted { lhs, rhs in
                if lhs.isFounder != rhs.isFounder { return lhs.isFounder }
                return lhs.hiredDay < rhs.hiredDay
            }
            .map { employee in
                Occupant(
                    id: employee.id,
                    appearance: CharacterAppearance(seed: employee.appearanceSeed),
                    status: status(of: employee, on: product),
                    isFounder: employee.isFounder,
                    mood: mood(employee.morale),
                    friendIDs: state.friendships
                        .filter { $0.involves(employee.id) && $0.strength >= 40 }
                        .sorted { $0.strength > $1.strength }
                        .compactMap { $0.other(than: employee.id) },
                    role: employee.isFounder ? .founder : (RoleLook(rawValue: employee.role.rawValue) ?? .none),
                    name: employee.name,
                    isAway: employee.isFounder && founderAway
                )
            }
    }

    /// Who is on the build, by id.
    static func crew(of product: Product, state: GameState) -> [Employee] {
        state.employees.filter {
            if case .product(let id) = $0.assignment { return id == product.id }
            return false
        }
    }

    /// The desk status: builders on this product show the build's work by
    /// role; department staff work their department; everyone else reads
    /// as whatever they are doing, or idle.
    private static func status(of employee: Employee, on product: Product) -> WorkStatus {
        switch employee.role {
        case .lawyer: return .legal
        case .hr: return .peopleOps
        case .ops: return .operations
        default: break
        }
        switch employee.assignment {
        case .idle: return .idle
        case .research: return .researching
        default: break
        }
        return switch employee.role {
        case .qa: .testing
        case .designer: .designing
        case .marketer: .marketing
        case .frontend, .backend: .coding
        case .founder: employee.skills.coding >= employee.skills.design ? .coding : .designing
        case .lawyer, .hr, .ops: .idle
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
