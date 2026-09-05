import Foundation
import TycoonContent
import TycoonEngine

// MARK: Iteration 7 — the first hour (R1)

/// What the card's one button does.
enum TutorialAction: Equatable {
    /// Moves to the next beat (the welcome, which asks nothing).
    case next
    /// Switches tab and pushes a destination through `AppRouter.go`.
    case route(Route)
    /// Starts the clock at ×1.
    case play
    /// Opens the weekly report.
    case openReport
}

/// One beat of the tour: the rail's line, the card's copy, and the button.
struct TutorialBeat: Equatable {
    let step: TutorialStep
    /// The one line on the notice rail.
    let railLine: String
    /// The card's sentence or two under the bitmap kicker.
    let body: String
    /// The button's label.
    let buttonLabel: String
    let action: TutorialAction
}

/// Something the shell saw that a beat waits for, rather than a fact in
/// the state: the week-1 report closed, the launch-day sheet closed.
enum TutorialShellEvent: Equatable {
    case reportDismissed
    case launchDayDismissed
}

/// The nine beats and their predicates — every rule about *when* the tour
/// moves lives here, as pure functions of `GameState`, so
/// `TutorialScriptTests` can run each one against a fixture.
enum TutorialScript {
    static let allTabs: Set<GameTab> = [.hq, .life, .team, .products, .business]

    /// The tabs open by the time `step` is showing: HQ at the start, the
    /// tab each earlier beat opened, all five from the desk on.
    static func tabsOpen(through step: TutorialStep) -> Set<GameTab> {
        var tabs: Set<GameTab> = [.hq]
        for beat in TutorialStep.allCases where beat <= step {
            if let tab = beat.opensTab { tabs.insert(tab) }
        }
        return tabs
    }

    // MARK: - Copy

    /// The beat's rail line, card copy and button, for the state it is
    /// shown against. The ship beat is the one that varies: a build that
    /// is ready sends the player to the war room; no build at all asks for
    /// one — the tour cannot end on a company that is not building.
    static func beat(for step: TutorialStep, state: GameState) -> TutorialBeat {
        switch step {
        case .welcome:
            TutorialBeat(
                step: step,
                railLine: "This is your garage. The desk is you; the whiteboard is what you are building.",
                body: "This is your garage. The desk is you; the whiteboard is what you are building. Tap anything in the room to see what it does.",
                buttonLabel: "Next",
                action: .next
            )
        case .nameAProduct:
            TutorialBeat(
                step: step,
                railLine: "Start something. Pick a topic the shelf is thin in.",
                body: "Start something. Pick a type you can build and a topic the shelf is thin in — the catalog says what today's crew could review as.",
                buttonLabel: "Start a product",
                action: .route(.newProduct(topicID: nil))
            )
        case .hire:
            TutorialBeat(
                step: step,
                railLine: "You cannot ship alone by winter. Hire one person.",
                body: "You cannot ship alone by winter. Hire one person — interview them first if you want to see the second trait.",
                buttonLabel: "See the candidates",
                action: .route(.hiring)
            )
        case .runTheClock:
            TutorialBeat(
                step: step,
                railLine: "Press play. A day is a second.",
                body: "Press play. A day is a second, and the game stops itself for anything that needs you.",
                buttonLabel: "Play",
                action: .play
            )
        case .readTheWeek:
            TutorialBeat(
                step: step,
                railLine: "Week one is in. Read the report.",
                body: "The week's report opens itself: cash in and out, the build, the team, and what to do next. Read it, then press Next week.",
                buttonLabel: "Open the report",
                action: .openReport
            )
        case .yourEvenings:
            TutorialBeat(
                step: step,
                railLine: "You have three evenings on normal. Spend one.",
                body: "You have three evenings a week on a normal schedule. Spend one — on yourself, on somebody, or on the team.",
                buttonLabel: "Open your week",
                action: .route(.life)
            )
        case .theDesk:
            TutorialBeat(
                step: step,
                railLine: "A client is worth cash before you have sales.",
                body: "A client is worth cash before you have sales. Take a contract from the desk — it has a deadline and a quality bar.",
                buttonLabel: "See the contracts",
                action: .route(.contracts)
            )
        case .shipIt:
            if state.productsInDevelopment.isEmpty {
                TutorialBeat(
                    step: step,
                    railLine: "Nothing is building. Start something and the tour picks up when it is ready.",
                    body: "Nothing is building. Start something — the tour picks up again the day it is ready to ship.",
                    buttonLabel: "Start a product",
                    action: .route(.newProduct(topicID: nil))
                )
            } else {
                TutorialBeat(
                    step: step,
                    railLine: "It is ready. Ship it from the war room.",
                    body: "It is ready. Ship it from the war room — the forecast says what the reviews will make of it.",
                    buttonLabel: "Open the war room",
                    action: .route(.warRoom)
                )
            }
        case .launchDay:
            TutorialBeat(
                step: step,
                railLine: "Read every review. The score has reasons.",
                body: "Read every review. The score has reasons, and the fix for each one is a tap away.",
                buttonLabel: "Read the reviews",
                action: latestRelease(in: state).map { .route(.product($0.id)) } ?? .next
            )
        }
    }

    /// The rail's line for `step`.
    static func railLine(for step: TutorialStep, state: GameState) -> String {
        beat(for: step, state: state).railLine
    }

    // MARK: - Predicates

    /// Whether `step` is done, reading the state alone. The welcome and
    /// the two sheet beats are finished by the shell (`isDone(_:after:)`)
    /// and carry only a calendar fallback here, so nobody is ever stuck.
    static func isDone(_ step: TutorialStep, state: GameState) -> Bool {
        switch step {
        case .welcome:
            false
        case .nameAProduct:
            !state.products.isEmpty
        case .hire:
            state.employees.count >= 2
        case .runTheClock:
            state.day >= 7
        case .readTheWeek:
            state.day >= 14
        case .yourEvenings:
            state.life.eveningsSpentThisWeek >= 1 || state.day >= 14
        case .theDesk:
            !state.activeContracts.isEmpty || state.day >= 28
        case .shipIt:
            latestRelease(in: state) != nil
        case .launchDay:
            latestRelease(in: state).map { state.day >= $0.launchDay + 7 } ?? false
        }
    }

    /// Whether `event` finishes `step`.
    static func isDone(_ step: TutorialStep, after event: TutorialShellEvent) -> Bool {
        switch (step, event) {
        case (.readTheWeek, .reportDismissed): true
        case (.launchDay, .launchDayDismissed): true
        default: false
        }
    }

    /// Whether `step` has nothing to say right now. Only the ship beat is
    /// ever silent: from the desk until `shipETA.isReady`, the rail shows
    /// nothing from the tour and no card is drawn.
    static func isDormant(
        _ step: TutorialStep, state: GameState, balance: BalanceConfig, content: ContentCatalog
    ) -> Bool {
        guard step == .shipIt else { return false }
        let building = state.productsInDevelopment
        guard !building.isEmpty else { return false }
        return !building.contains { product in
            state.shipETA(for: product, balance: balance, content: content)?.isReady == true
        }
    }

    /// The newest launch, with its release info.
    static func latestRelease(in state: GameState) -> (id: UUID, launchDay: Int)? {
        state.products
            .compactMap { product -> (id: UUID, launchDay: Int)? in
                guard case .released(let info) = product.stage else { return nil }
                return (product.id, info.launchDay)
            }
            .max { $0.launchDay < $1.launchDay }
    }
}
