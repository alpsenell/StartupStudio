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
            message: String(localized: "Start a product. Pick a type you can actually build, and a topic the market likes.", comment: "Coach tip shown on the rail while the matching chapter-1 goal is open"),
            systemImage: "hammer.fill",
            route: .newProduct(topicID: nil),
            routeLabel: String(localized: "Start", comment: "Button on a coach tip that opens the screen it is about")
        ),
        CoachTip(
            id: "tip.ship_it",
            goalID: "g1_ship_it",
            message: String(localized: "You can ship before the polish bar is full — it just reviews worse. Check the ship sheet\'s estimate first.", comment: "Coach tip shown on the rail while the matching chapter-1 goal is open"),
            systemImage: "shippingbox.fill"
        ),
        CoachTip(
            id: "tip.first_hire",
            goalID: "g1_first_hire",
            message: String(localized: "Candidates refresh every two weeks. A hire costs their salary every week, forever.", comment: "Coach tip shown on the rail while the matching chapter-1 goal is open"),
            systemImage: "person.badge.plus",
            route: .hiring,
            routeLabel: String(localized: "Hiring", comment: "Button on a coach tip that opens the screen it is about")
        ),
        CoachTip(
            id: "tip.first_contract",
            goalID: "g1_first_contract",
            message: String(localized: "Contracts pay cash on a deadline. They\'re the bridge between products — and they grade your work.", comment: "Coach tip shown on the rail while the matching chapter-1 goal is open"),
            systemImage: "briefcase.fill",
            route: .contracts,
            routeLabel: String(localized: "Contracts", comment: "Client jobs. Used as a ledger bucket and as the button on the coach tip that opens the contracts screen")
        ),
        CoachTip(
            id: "tip.cash_positive",
            goalID: "g1_week_in_the_black",
            message: String(localized: "Runway is cash ÷ weekly burn. Under four weeks and the burn card turns orange.", comment: "Coach tip shown on the rail while the matching chapter-1 goal is open"),
            systemImage: "flame.fill"
        ),
        CoachTip(
            id: "tip.first_review",
            goalID: "g1_review_40",
            message: String(localized: "Reviews land a week after launch. Early scores are meant to sting — the skill ceiling rises with your crew.", comment: "Coach tip shown on the rail while the matching chapter-1 goal is open"),
            systemImage: "star.fill"
        ),
    ]
}

// MARK: Iteration 12 — J1 (state-keyed coach tips, Meta B1 + Life B5)

/// Tips keyed to what is happening in the run rather than to a chapter-1
/// goal: the four open doors, and a moment for each dormant room — the
/// week a rival ships into your topic, four weeks of runway, a term
/// sheet, a hospital stay, a burnout, a partner drifting, a complaint, a
/// launch party, a wedding, a review worth repeating, a boom.
///
/// `CoachTip.all` stays the chapter-1 six (`TutorialScriptTests` pins it,
/// and the tour's exit dismisses exactly those), so these live beside it.
/// Each is a route and writes no state: opening the screen is still the
/// player's own tap, which is what keeps the rooms' identity gates where
/// they are. A tip is shown while its trigger holds and until dismissed.
extension CoachTip {
    /// One per door, while that door waits on an answer.
    static let doorTips: [CoachTip] = DoorKind.allCases.map { kind in
        CoachTip(
            id: "tip.door.\(kind.rawValue)",
            goalID: CoachTrigger.doorKey(kind),
            message: doorMessage(kind),
            systemImage: DoorCopy.icon(kind),
            route: .door(kind),
            routeLabel: String(localized: "Answer", comment: "Button on a coach tip that opens a door waiting on an answer")
        )
    }

    private static func doorMessage(_ kind: DoorKind) -> String {
        switch kind {
        case .shark: String(localized: "Denny rang about the runway. His number is on your phone, and he is waiting.", comment: "Coach tip while the loan shark's door is open")
        case .vices: String(localized: "Somebody from the launch party wants an answer. It is in your coat.", comment: "Coach tip while the vices door is open")
        case .fame: String(localized: "A journalist wants your take on the launch, on the record, by Friday.", comment: "Coach tip while the fame door is open")
        case .care: String(localized: "A parent had a fall. The home wants a number by Friday.", comment: "Coach tip while the family care door is open")
        }
    }

    static let stateKeyed: [CoachTip] = [
        CoachTip(
            id: "tip.state.rival_in_topic",
            goalID: CoachTrigger.rivalInTopic,
            message: String(localized: "A rival just shipped into a topic you hold. Their page says how strong they are and what they are after.", comment: "Coach tip keyed to game state"),
            systemImage: "flag.2.crossed.fill",
            route: .rivals,
            routeLabel: String(localized: "Rivals", comment: "Button on a coach tip that opens the screen it is about")
        ),
        CoachTip(
            id: "tip.state.runway_short",
            goalID: CoachTrigger.runwayShort,
            message: String(localized: "Under four weeks of runway. Finances has the loan, the cuts — and a list of who else is watching the cash.", comment: "Coach tip keyed to game state"),
            systemImage: "hourglass.bottomhalf.filled",
            route: .finances,
            routeLabel: String(localized: "Finances", comment: "Button on a coach tip that opens the screen it is about")
        ),
        CoachTip(
            id: "tip.state.term_sheet",
            goalID: CoachTrigger.termSheet,
            message: String(localized: "A term sheet is on the table. The pitch room is where the number moves before you sign it.", comment: "Coach tip keyed to game state"),
            systemImage: "doc.text.fill",
            route: .pitch,
            routeLabel: String(localized: "Pitch room", comment: "Button on a coach tip that opens the screen it is about")
        ),
        CoachTip(
            id: "tip.state.hospital",
            goalID: CoachTrigger.hospital,
            message: String(localized: "That was a hospital stay. The doctor is under Assets, next to whatever put you there.", comment: "Coach tip keyed to game state"),
            systemImage: "cross.case.fill",
            route: .assets,
            routeLabel: String(localized: "The doctor", comment: "Button on a coach tip that opens the Assets screen, where the doctor is")
        ),
        CoachTip(
            id: "tip.state.burnout",
            goalID: CoachTrigger.burnout,
            message: String(localized: "Burnout. The doctor is under Assets. The schedule that did it is on the Life tab.", comment: "Coach tip keyed to game state"),
            systemImage: "flame.fill",
            route: .assets,
            routeLabel: String(localized: "The doctor", comment: "Button on a coach tip that opens the Assets screen, where the doctor is")
        ),
        CoachTip(
            id: "tip.state.affection",
            goalID: CoachTrigger.affection,
            message: String(localized: "Your partner is drifting. The phone is where they are still talking to you.", comment: "Coach tip keyed to game state"),
            systemImage: "heart.slash.fill",
            route: .phone,
            routeLabel: String(localized: "Phone", comment: "Button on a coach tip that opens the screen it is about")
        ),
        CoachTip(
            id: "tip.state.complaint",
            goalID: CoachTrigger.complaint,
            message: String(localized: "Somebody complained about a colleague. What else the office isn't saying is on the Team tab.", comment: "Coach tip keyed to game state"),
            systemImage: "person.fill.questionmark",
            route: .secrets,
            routeLabel: String(localized: "The office", comment: "Button on a coach tip that opens the office secrets card")
        ),
        CoachTip(
            id: "tip.state.launch_party",
            goalID: CoachTrigger.launchParty,
            message: String(localized: "Launch parties run late. What they cost — the habits, the doctor, the money — is under Assets.", comment: "Coach tip keyed to game state"),
            systemImage: "wineglass.fill",
            route: .assets,
            routeLabel: String(localized: "Assets", comment: "Button on a coach tip that opens the screen it is about")
        ),
        CoachTip(
            id: "tip.state.married",
            goalID: CoachTrigger.married,
            message: String(localized: "Married means in-laws. The family room is on the Life tab, and so are they.", comment: "Coach tip keyed to game state"),
            systemImage: "house.fill",
            route: .family,
            routeLabel: String(localized: "Family", comment: "Button on a coach tip that opens the screen it is about")
        ),
        CoachTip(
            id: "tip.state.good_review",
            goalID: CoachTrigger.goodReview,
            message: String(localized: "A review worth repeating. The feed, under Life, is where you repeat it.", comment: "Coach tip keyed to game state"),
            systemImage: "megaphone.fill",
            route: .feed,
            routeLabel: String(localized: "The feed", comment: "Button on a coach tip that opens the screen it is about")
        ),
        CoachTip(
            id: "tip.state.market_boom",
            goalID: CoachTrigger.marketBoom,
            message: String(localized: "A topic is booming. The market map shows where the money is going, and who is already there.", comment: "Coach tip keyed to game state"),
            systemImage: "chart.line.uptrend.xyaxis",
            route: .marketMap,
            routeLabel: String(localized: "Market map", comment: "Button on a coach tip that opens the screen it is about")
        ),
    ]

    /// The door and state tip the rail should show now, or `nil`: the
    /// first whose trigger holds and that was not dismissed. Doors first.
    static func stateTip(in state: GameState, dismissed: Set<String>) -> CoachTip? {
        let keys = Set(CoachTrigger.active(in: state))
        guard !keys.isEmpty else { return nil }
        return (doorTips + stateKeyed).first { keys.contains($0.goalID) && !dismissed.contains($0.id) }
    }
}

/// The state reads behind the tips. Pure, and cheap enough for a render:
/// a few passes over the 500-entry event log at most.
enum CoachTrigger {
    static let rivalInTopic = "state.rival_in_topic"
    static let runwayShort = "state.runway_short"
    static let termSheet = "state.term_sheet"
    static let hospital = "state.hospital"
    static let burnout = "state.burnout"
    static let affection = "state.affection"
    static let complaint = "state.complaint"
    static let launchParty = "state.launch_party"
    static let married = "state.married"
    static let goodReview = "state.good_review"
    static let marketBoom = "state.market_boom"

    static func doorKey(_ kind: DoorKind) -> String { "door.\(kind.rawValue)" }

    /// How long a moment keeps its tip up.
    static let window = 28

    /// Every trigger that holds today, as goal keys.
    static func active(in state: GameState) -> [String] {
        var keys = state.doors.open(on: state.day).map { doorKey($0.kind) }
        let live = Set(state.products.compactMap { product -> String? in
            guard case .released(let info) = product.stage, !info.offMarket else { return nil }
            return product.topicID
        })
        if happened(state, { event in
            if case let .rivalShipped(_, topicID, day) = event, live.contains(topicID) { return day }
            return nil
        }) { keys.append(rivalInTopic) }
        if runwayIsShort(state) { keys.append(runwayShort) }
        if happened(state, { event in
            if case let .investmentOffered(_, _, _, _, day) = event { return day }
            return nil
        }) { keys.append(termSheet) }
        if happened(state, { event in
            if case let .founderAway(reason, _, day) = event, reason == "Hospital" { return day }
            return nil
        }) { keys.append(hospital) }
        if happened(state, { event in
            if case let .founderAway(reason, _, day) = event, reason == "Burnout" { return day }
            return nil
        }) { keys.append(burnout) }
        if happened(state, { event in
            if case let .partnerDrifting(_, day) = event { return day }
            return nil
        }) { keys.append(affection) }
        if happened(state, { event in
            if case let .staffEventOccurred(_, kind, _, day) = event, kind == .harassmentComplaint { return day }
            return nil
        }) { keys.append(complaint) }
        if !state.assets.isEngaged, happened(state, within: GameState.daysPerWeek, { event in
            if case let .shipped(_, day) = event { return day }
            return nil
        }) { keys.append(launchParty) }
        if state.life.family.stage == .married, state.familyDrama.openedDay == nil {
            keys.append(married)
        }
        if state.fame == .empty, DoorRules.bestReview(state) >= 70 { keys.append(goodReview) }
        if happened(state, { event in
            if case let .marketBoom(_, day) = event { return day }
            return nil
        }) { keys.append(marketBoom) }

        if let forced = DoorDebug.forcedTip {
            let all = CoachTip.doorTips + CoachTip.stateKeyed
            if let tip = all.first(where: { $0.id == forced || $0.goalID == forced }) { keys.append(tip.goalID) }
        }
        return keys
    }

    /// Whether `match` finds an event in the last `within` days.
    private static func happened(
        _ state: GameState, within days: Int = window, _ match: (GameEvent) -> Int?
    ) -> Bool {
        state.eventLog.contains { event in
            guard let day = match(event) else { return false }
            return state.day - day < days
        }
    }

    /// Four weeks of runway, read off what actually left the account in the
    /// last seven days — the tip has the state, not the balance, and the
    /// ledger is the burn the player sees.
    private static func runwayIsShort(_ state: GameState) -> Bool {
        guard state.day >= 14 else { return false }
        let cash = state.company.cash
        if cash < 0 { return true }
        let spent = state.ledger.entries.reduce(0) { total, entry in
            entry.amount < 0 && state.day - entry.day < GameState.daysPerWeek ? total - entry.amount : total
        }
        return spent > 0 && cash < spent * DoorRules.sharkRunwayWeeks
    }
}

// MARK: end J1

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
