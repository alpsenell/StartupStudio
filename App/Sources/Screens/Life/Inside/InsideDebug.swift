import SwiftUI
import TycoonEngine

/// Iteration 11, wave two — W4's debug-launch flags, in the lane's own
/// file so `DebugLaunch` needs one region rather than four.
///
/// Everything here is DEBUG-only and every step is a real `GameAction`
/// through the ordinary reducer: the screenshot pass is sentenced, picks
/// its days and walks into the board exactly as a player would. There is
/// no back door into `state.prison`.
enum InsideDebug {

    /// `-autoInside <weeks>`: serve a sentence of that many weeks on a
    /// headless pass. A verdict is the only other way in, and a headless
    /// pass cannot commit an offence, wait four weeks for a hearing and
    /// lose it inside a screenshot run.
    static var weeks: Int? {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-autoInside") else { return nil }
        return DebugLaunch.value(after: "-autoInside").flatMap(Int.init) ?? 8
        #else
        return nil
        #endif
    }

    /// `-autoInsideDay yard`: the day the pass picks, so the room can be
    /// photographed with a choice made.
    static var day: PrisonDayChoice? {
        #if DEBUG
        return DebugLaunch.value(after: "-autoInsideDay").flatMap(PrisonDayChoice.init(rawValue:))
        #else
        return nil
        #endif
    }

    /// `-autoInsideGang join` / `refuse`: answer the wing when it asks.
    static var gang: Bool? {
        #if DEBUG
        return switch DebugLaunch.value(after: "-autoInsideGang") {
        case "join", "yes": true
        case "refuse", "no": false
        default: nil
        }
        #else
        return nil
        #endif
    }

    /// `-autoParole`: wait for the halfway mark, open the board and say
    /// the things `-autoParoleSay remorse,theCourse` names.
    static var opensParole: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-autoParole")
        #else
        return false
        #endif
    }

    static var paroleScript: [String] {
        #if DEBUG
        guard let raw = DebugLaunch.value(after: "-autoParoleSay") else { return [] }
        return raw.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        #else
        return []
        #endif
    }

    /// `-autoInsideScroll wing|out`: scroll the room to a panel below the
    /// fold once it has settled, so it can be photographed.
    static var scrollAnchor: String? {
        #if DEBUG
        return switch DebugLaunch.value(after: "-autoInsideScroll") {
        case "wing": InsideScreen.wingAnchor
        case "out", "waysout", "parole": InsideScreen.waysOutAnchor
        default: nil
        }
        #else
        return nil
        #endif
    }

    /// `-autoEscape`: go over the wall as soon as the room opens.
    static var escapes: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-autoEscape")
        #else
        return false
        #endif
    }

    /// Sends the sentence once the shell has a company to send it to.
    ///
    /// `current` is read on every attempt rather than captured: installing
    /// a fixture swaps the session's engine, and a sentence sent to the
    /// engine that was there a moment ago goes down with it. The pass
    /// keeps asking for a couple of seconds and stops the moment the
    /// founder is actually inside.
    @MainActor
    static func startIfAsked(current: @escaping () -> GameEngine) async {
        #if DEBUG
        guard let weeks else { return }
        for _ in 0..<60 {
            let engine = current()
            if engine.state.prison?.isInside == true { return }
            if engine.state.gameOver == nil {
                engine.send(.serveSentence(weeks: weeks))
            }
            try? await Task.sleep(for: .milliseconds(200))
        }
        #endif
    }

    /// Dresses the room once it is on screen: the day's choice, the answer
    /// to the wing, the wall, and the board. Idempotent.
    @MainActor
    static func play(engine: GameEngine, openParole: @escaping () -> Void) async {
        #if DEBUG
        guard weeks != nil, !played else { return }
        played = true
        if escapes {
            engine.send(.attemptEscape)
            return
        }
        guard gang != nil || opensParole || day != nil else { return }
        // The wing asks on day four, and the board sits at the halfway
        // mark: a headless pass waits for both the way a founder does. At
        // x4 that is a handful of seconds.
        for _ in 0..<900 {
            guard let prison = engine.state.prison, prison.isInside else { return }
            // The day the gate closes is a critical event and it stops the
            // clock, the way every critical event does. A player presses
            // the play button in the room's own top bar; a headless pass
            // has no thumb, so it presses it here.
            if engine.state.speed == .paused, prison.parole == nil { engine.setSpeed(.x4) }
            // The day resets at midnight; a headless pass picks the same
            // thing every morning, the way a player on autopilot would.
            if let day, prison.todayChoice != day {
                engine.send(.chooseInsideDay(choice: day))
            }
            if let joining = gang, prison.gang == .offered {
                engine.send(.answerPrisonGang(joining: joining))
            }
            if opensParole,
               prison.isParoleEligible(on: engine.state.day, balance: engine.balance.prison) {
                openParole()
                return
            }
            if gang != nil, day == nil, !opensParole,
               prison.gang != .offered, prison.gang != .unasked {
                return
            }
            try? await Task.sleep(for: .milliseconds(120))
        }
        #endif
    }

    /// The exchanges the pass says to the board, once the room is open.
    @MainActor
    static func playParoleScript(engine: GameEngine) {
        #if DEBUG
        for name in paroleScript {
            guard let exchange = PrisonParoleExchange(rawValue: name),
                  engine.state.prison?.parole != nil
            else { continue }
            engine.send(.sayAtParole(exchange: exchange))
        }
        #endif
    }

    #if DEBUG
    @MainActor private static var played = false
    #endif
}
