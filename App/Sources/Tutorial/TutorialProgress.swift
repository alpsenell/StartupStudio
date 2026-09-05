import Foundation
import TycoonEngine

// MARK: Iteration 7 — the first hour (R1)

/// The nine beats of the tour a fresh install gets once. Paced by what
/// the player has done, not by the calendar: the stretch between the desk
/// and the ship is weeks long and silent.
enum TutorialStep: Int, CaseIterable, Codable, Hashable, Comparable {
    case welcome
    case nameAProduct
    case hire
    case runTheClock
    case readTheWeek
    case yourEvenings
    case theDesk
    case shipIt
    case launchDay

    static func < (lhs: TutorialStep, rhs: TutorialStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// The tab this beat opens, `nil` for the beats that stay where the
    /// player is.
    var opensTab: GameTab? {
        switch self {
        case .welcome: .hq
        case .nameAProduct: .products
        case .hire: .team
        case .yourEvenings: .life
        case .theDesk: .business
        case .runTheClock, .readTheWeek, .shipIt, .launchDay: nil
        }
    }

    /// A short name; R1 writes the rail lines and the card copy.
    var title: String {
        switch self {
        case .welcome: "Welcome"
        case .nameAProduct: "Name a product"
        case .hire: "Hire"
        case .runTheClock: "Run the clock"
        case .readTheWeek: "Read the week"
        case .yourEvenings: "Your evenings"
        case .theDesk: "The desk"
        case .shipIt: "Ship it"
        case .launchDay: "Launch day"
        }
    }
}

/// Where the tour is. `GameSession.tutorial` is `nil` for every player
/// who is not on it — a returning player, a second company, a daily.
struct TutorialProgress: Equatable {
    var step: TutorialStep = .welcome
    var isComplete = false
    /// The tabs rendered so far; all five once the desk beat opens.
    var openTabs: Set<GameTab> = [.hq]
}
