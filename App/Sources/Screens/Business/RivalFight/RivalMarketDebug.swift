import SwiftUI
import TycoonEngine

/// Iteration 12 — J3's debug-launch flags, in the lane's own file so
/// `DebugLaunch` needs one comment rather than four regions.
///
/// - `-autoRivalMarket boom` — the newest product's topic booms, its
///   forecast is readable, and the strongest studio moves in.
/// - `-autoRivalMarket crash` — a studio's home market sits under ×0.70
///   for a month and it walks out.
/// - `-autoPriceWar` — a studio starts a price war in a topic you sell in,
///   and the sheet comes up.
/// - `-autoCopied` — a clone lifts the best card in the newest build's
///   hand, so the chip shows before it is placed (with `-autoRoute
///   featureboard`).
///
/// Every flag sends `.noticeMarketOpened` first, then one DEBUG-only
/// `.seedRivalMarket`: the world doing the thing a headless pass cannot
/// wait a quarter for. The sheet, the answers, the chip and the map are
/// the ordinary game. Release builds never read any of it.
enum RivalMarketDebug {
    static var scenarios: [String] {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        var list: [String] = []
        if arguments.contains("-autoRivalMarket") {
            list.append(DebugLaunch.value(after: "-autoRivalMarket")?.lowercased() ?? "boom")
        }
        if arguments.contains("-autoPriceWar") { list.append("pricewar") }
        if arguments.contains("-autoCopied") { list.append("copied") }
        return list
        #else
        return []
        #endif
    }

    /// `-autoMarketReport`: open the market report sheet (where the
    /// categories card carries the circling line) as the market appears.
    /// No `-autoRoute` name reaches the sheet, and a headless pass cannot
    /// tap. Debug only.
    static var opensReport: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-autoMarketReport")
        #else
        return false
        #endif
    }

    /// `-autoRivalMarketCard`: lift the profile's "Where they are going"
    /// card onto a sheet — it sits below the fold of a long profile and a
    /// headless pass cannot scroll (W3's `-autoSpyCard`, for the same
    /// reason). Debug only; nothing in the game presents it.
    static var liftsCard: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-autoRivalMarketCard")
        #else
        return false
        #endif
    }

    /// Runs the pass once, from the app root's task.
    @MainActor
    static func startIfAsked(engine: GameEngine) {
        #if DEBUG
        let scenarios = self.scenarios
        guard !scenarios.isEmpty, task == nil else { return }
        task = Task { @MainActor in
            // The field is founded on the first tick.
            for _ in 0..<300 where engine.state.rivals.rivals.isEmpty {
                if engine.state.speed == .paused { engine.setSpeed(.x4) }
                try? await Task.sleep(for: .milliseconds(100))
            }
            engine.send(.noticeMarketOpened)
            for scenario in scenarios {
                if scenario == "copied" {
                    // The chip is on a build's hand: wait for a build.
                    for _ in 0..<300 where !engine.state.products.contains(where: {
                        if case .development = $0.stage { return true }
                        return false
                    }) {
                        try? await Task.sleep(for: .milliseconds(100))
                    }
                }
                engine.send(.seedRivalMarket(scenario: scenario))
            }
            engine.setSpeed(.paused)
        }
        #endif
    }

    #if DEBUG
    @MainActor private static var task: Task<Void, Never>?
    #endif
}
