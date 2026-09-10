import Foundation
import TycoonEngine

// MARK: Iteration 12 — J1 (doors)

/// The screenshot pass's flags for the doors and the coach tips.
///
/// - `-autoRoute door -autoDoor <kind>` (shark | vices | fame | care):
///   opens that door today through the engine's debug action — the same
///   `open` a real day uses — and lands on its sheet.
/// - `-autoDoorAnswer <choice>` (accept | decline | careHome |
///   careSpareRoom | careSibling): answers it once the sheet is up,
///   through `.answerDoor`, so the picture is of what a yes does.
/// - `-autoTip <id>` (`state.runway_short`, `door.shark`, …): switches
///   that coach tip's trigger on whatever the state says, so a rail line
///   can be photographed without the play-through.
///
/// Every action goes through the reducer. Release builds read none of it.
enum DoorDebug {
    @MainActor private static var tookOpen = false
    @MainActor private static var tookAnswer = false

    static var requestedKind: DoorKind? {
        DebugLaunch.value(after: "-autoDoor").flatMap { DoorKind(rawValue: $0.lowercased()) }
    }

    static var requestedAnswer: DoorChoice? {
        guard let word = DebugLaunch.value(after: "-autoDoorAnswer")?.lowercased() else { return nil }
        return DoorChoice.allCases.first { $0.rawValue.lowercased() == word }
    }

    /// The coach tip a pass forces on, by its goal key or its id.
    static var forcedTip: String? {
        DebugLaunch.value(after: "-autoTip")
    }

    @MainActor private static var tookLaunchDay = false

    /// `-autoTellPeople`: puts the launch-day sheet up for the newest
    /// release, so *Tell people* can be photographed. (`-autoRoute
    /// launchday` is the war room's moment, a different screen.)
    @MainActor
    static func showLaunchDayIfAsked(engine: GameEngine) {
        #if DEBUG
        guard !tookLaunchDay, ProcessInfo.processInfo.arguments.contains("-autoTellPeople") else { return }
        tookLaunchDay = true
        GameShell.shared.launchDayProductID = engine.state.products.last { product in
            if case .released = product.stage { return true }
            return false
        }?.id
        #endif
    }

    @MainActor
    static func openIfAsked(engine: GameEngine) {
        #if DEBUG
        guard !tookOpen, let kind = requestedKind else { return }
        tookOpen = true
        engine.send(.openDoor(kind: kind))
        #endif
    }

    /// The answer a pass asked for at this door, once. The sheet gives it
    /// to its own button action, so a yes goes where a thumb's would.
    @MainActor
    static func takeAnswer(for kind: DoorKind) -> DoorChoice? {
        #if DEBUG
        guard !tookAnswer, requestedKind == kind, let choice = requestedAnswer else { return nil }
        tookAnswer = true
        return choice
        #else
        return nil
        #endif
    }
}
