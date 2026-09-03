import SwiftUI
import TycoonEngine

/// One line of coaching, keyed to a progression goal.
///
/// Tips are content-free hints about the *interface* ("candidates refresh
/// every two weeks"), never about strategy — they exist so the first hour
/// has no dead ends. Each is shown while its goal is active and disappears
/// for good once dismissed or once the goal completes.
struct CoachTip: Identifiable, Equatable {
    /// Stable id, also the `UserDefaults` dismissal key.
    let id: String
    /// The goal id from WS-F's `Goals.json` this tip accompanies.
    let goalID: String
    let message: String
    let systemImage: String
    /// Where the tip's button takes you, if anywhere.
    var route: Route?
    /// Label for that button.
    var routeLabel: String?

    /// The full tip catalog, keyed to Chapter 1's goal ids in
    /// `Goals.json` (WS-F). `ProgressionContentTests` pins those ids, so a
    /// rename there is caught before it silently mutes a tip.
    static let all: [CoachTip] = [
        CoachTip(
            id: "tip.first_product",
            goalID: "g1_name_a_product",
            message: "Start a product. Pick a type you can actually build, and a topic the market likes.",
            systemImage: "hammer.fill",
            route: .newProduct(topicID: nil),
            routeLabel: "Start"
        ),
        CoachTip(
            id: "tip.ship_it",
            goalID: "g1_ship_it",
            message: "You can ship before the polish bar is full — it just reviews worse. Check the ship sheet's estimate first.",
            systemImage: "shippingbox.fill"
        ),
        CoachTip(
            id: "tip.first_hire",
            goalID: "g1_first_hire",
            message: "Candidates refresh every two weeks. A hire costs their salary every week, forever.",
            systemImage: "person.badge.plus",
            route: .hiring,
            routeLabel: "Hiring"
        ),
        CoachTip(
            id: "tip.first_contract",
            goalID: "g1_first_contract",
            message: "Contracts pay cash on a deadline. They're the bridge between products — and they grade your work.",
            systemImage: "briefcase.fill",
            route: .contracts,
            routeLabel: "Contracts"
        ),
        CoachTip(
            id: "tip.cash_positive",
            goalID: "g1_week_in_the_black",
            message: "Runway is cash ÷ weekly burn. Under four weeks and the burn card turns orange.",
            systemImage: "flame.fill"
        ),
        CoachTip(
            id: "tip.first_review",
            goalID: "g1_review_40",
            message: "Reviews land a week after launch. Early scores are meant to sting — the skill ceiling rises with your crew.",
            systemImage: "star.fill"
        ),
    ]
}

/// Reads WS-F's progression state.
///
/// Keeping the read in one place means the tip strip, the journal and
/// anything else that wants goals has a single place to look.
enum ProgressionReader {
    /// Goal ids the player is currently working on, newest chapter first.
    /// Empty whenever progression has no goals yet.
    static func activeGoalIDs(in state: GameState) -> [String] {
        state.progression.activeGoals.map(\.id)
    }
}
