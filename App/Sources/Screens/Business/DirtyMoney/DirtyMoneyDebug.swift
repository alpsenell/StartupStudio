import SwiftUI
import TycoonEngine

/// Iteration 11, wave two — W1's debug-launch flags, in the lane's own
/// file so `DebugLaunch` needs one region rather than four.
///
/// Everything here is DEBUG-only. The *offer* is seeded, because an offer
/// is a thing the world does and a headless pass cannot wait a quarter for
/// a company to go broke; everything after it — banking the cheque,
/// answering the strings — is a real `GameAction` through the ordinary
/// reducer, exactly as a player sends it. There is no back door into
/// `state.dirtyMoney` beyond that one seed.
enum DirtyMoneyDebug {

    /// `-autoDirtyMoney <backer>`: put an offer on the table.
    ///
    /// Names are the `DirtyMoneyBacker` raw values, case-insensitively —
    /// `familyOffice`, `theFront`, `theShark`. `-autoDirtyMoney` with no
    /// name takes the front, which has the invoice and photographs best.
    static var backerArgument: String? {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-autoDirtyMoney") else { return nil }
        return DebugLaunch.value(after: "-autoDirtyMoney") ?? ""
        #else
        return nil
        #endif
    }

    static var seedsOffer: Bool { backerArgument != nil }

    /// `-autoDirtyMoney <backer> take`: bank the cheque as well, and let
    /// the clock run to the first string.
    static var takesCheque: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-autoDirtyMoneyTake")
        #else
        return false
        #endif
    }

    /// `-autoDirtyMoneyDemand <kind>`: pull one of the strings the
    /// moment the cheque is banked, rather than waiting a quarter for the
    /// calendar to pull it. `DirtyMoneyDemandKind`'s raw value.
    static var demandArgument: String? {
        #if DEBUG
        return DebugLaunch.value(after: "-autoDirtyMoneyDemand")
        #else
        return nil
        #endif
    }

    /// `-autoDirtyMoneyOut`: open the three ways out over the facility,
    /// once there is a facility to get out of.
    static var opensWayOut: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-autoDirtyMoneyOut")
        #else
        return false
        #endif
    }

    /// Runs the pass. Idempotent: the task is kept so a redraw of the card
    /// that started it does not start a second one.
    @MainActor
    static func startIfAsked(engine: GameEngine) {
        #if DEBUG
        guard let named = backerArgument, task == nil else { return }
        DebugLaunch.startAutoAnswering(engine: engine)
        task = Task { @MainActor in
            let backer = named.isEmpty ? DirtyMoneyBacker.theFront.rawValue : named
            engine.send(.seedDirtyMoneyOffer(backer: backer))
            guard takesCheque || demandArgument != nil || opensWayOut else {
                // An offer stands for a week, and a week at x4 is gone
                // before a headless pass has taken its picture. Stop the
                // clock: this is the screenshot pass, not a shortcut in
                // the game.
                engine.setSpeed(.paused)
                return
            }
            // Give the sheet a beat to be photographed, then do what a
            // player would do with it.
            try? await Task.sleep(for: .milliseconds(600))
            engine.send(.takeDirtyMoney)
            if opensWayOut {
                engine.setSpeed(.paused)
                return
            }
            if let demand = demandArgument {
                engine.send(.seedDirtyMoneyDemand(kind: demand))
                engine.setSpeed(.paused)
                return
            }
            // Wait for the first string the way a founder waits for it.
            for _ in 0..<900 {
                if engine.state.dirtyMoney.openDemand != nil { return }
                if engine.state.speed == .paused { engine.setSpeed(.x4) }
                try? await Task.sleep(for: .milliseconds(120))
            }
        }
        #endif
    }

    /// Opens the offer sheet the moment there is one, for
    /// `-autoRoute dirtymoney`.
    @MainActor
    static func openWhenOffered(engine: GameEngine, open: @escaping () -> Void) async {
        #if DEBUG
        guard Route.launchRoute == .dirtyMoney || seedsOffer else { return }
        guard !takesCheque, demandArgument == nil, !opensWayOut else { return }
        for _ in 0..<600 {
            if engine.state.dirtyMoney.hasOffer(on: engine.state.day) {
                open()
                return
            }
            try? await Task.sleep(for: .milliseconds(120))
        }
        #endif
    }

    /// Opens the three ways out the moment there is a facility, for
    /// `-autoDirtyMoneyOut`.
    @MainActor
    static func openWayOutWhenBacked(engine: GameEngine, open: @escaping () -> Void) async {
        #if DEBUG
        guard opensWayOut else { return }
        for _ in 0..<600 {
            if engine.state.dirtyMoney.isBacked {
                open()
                return
            }
            try? await Task.sleep(for: .milliseconds(120))
        }
        #endif
    }

    #if DEBUG
    @MainActor private static var task: Task<Void, Never>?
    #endif
}
