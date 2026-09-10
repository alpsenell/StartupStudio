import SwiftUI
import TycoonEngine

// MARK: K2 (product lifecycle)

/// Iteration 15 — K2. The headless screenshot pass's hands, for
/// `-autoTab products -autoRoute k2-<scenario>` on a fixture (the studio's
/// Round 6 is the subject). Everything goes through the ordinary reducer
/// except the successor build itself, which `.lifecycleDebug("successor")`
/// seeds so a picture does not have to wait for one.
///
/// Scenarios: `k2-replace` (the ship dialog with *Replace*), `k2-launch`
/// (launch day for a replacement), `k2-card` (the lifecycle card),
/// `k2-retire` (the retire sheet), `k2-v2` (the new-product flow as a v2),
/// `k2-price` (the priced sheet), `k2-discontinued` (the store page of a
/// retired product), `k2-paper` (the paper the week after a retirement and
/// a sale). DEBUG only; inert without the flag.
@MainActor
enum LifecycleDebug {
    enum Surface { case shipDialog, retire, buildV2, price, card }

    /// The one surface the pass wants opened on the next screen that owns
    /// it; taken once.
    private static var pending: Surface?

    static func consume(_ surface: Surface) -> Bool {
        guard pending == surface else { return false }
        pending = nil
        return true
    }

    static func peek(_ surface: Surface) -> Bool { pending == surface }

    fileprivate static func want(_ surface: Surface) { pending = surface }
}

private struct LifecycleAutoRoute: ViewModifier {
    let engine: GameEngine
    let router: AppRouter

    func body(content: Content) -> some View {
        content.task {
            #if DEBUG
            guard let scenario = DebugLaunch.lifecycleScenario else { return }
            await run(scenario)
            #endif
        }
    }

    #if DEBUG
    /// The live product with the biggest book: Round 6 on the studio.
    private var subject: Product? {
        engine.state.products
            .filter { $0.releaseInfo.map { !$0.offMarket } ?? false }
            .max { ($0.releaseInfo?.subscribers ?? 0) < ($1.releaseInfo?.subscribers ?? 0) }
    }

    private var screenIsFree: Bool {
        GameShell.shared.launchDayProductID == nil
            && !GameShell.shared.showingWeeklyReport
            && DecisionPrompt.pending(in: engine.state, content: engine.content, balance: engine.balance) == nil
    }

    private func beat(_ seconds: Double = 1) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    private func run(_ scenario: String) async {
        // The fixture lands a beat after the shell does.
        for _ in 0..<20 where subject == nil { await beat() }
        await beat(2)
        guard let parent = subject else { return }
        // Keep the studio out of the bankruptcy warning, which pauses the
        // clock and takes the screen to HQ.
        engine.send(.lifecycleDebug(scenario: "solvent"))
        switch scenario {
        case "replace", "launch":
            engine.send(.lifecycleDebug(scenario: "successor"))
            guard let build = engine.state.products.first(where: { $0.name == "\(parent.name) v2" }) else { return }
            if scenario == "launch" {
                engine.send(.shipReplacing(productID: build.id, parentID: parent.id))
                // A send from here bypasses the toast layer that raises
                // launch day for a tap; raise it the same way.
                await beat()
                if GameShell.shared.launchDayProductID == nil {
                    GameShell.shared.launchDayProductID = build.id
                }
            } else {
                LifecycleDebug.want(.shipDialog)
                router.go(.product(build.id))
            }
        case "card", "retire", "v2", "price":
            LifecycleDebug.want([
                "card": .card, "retire": .retire, "v2": .buildV2, "price": .price,
            ][scenario] ?? .card)
            router.go(.product(parent.id))
        case "discontinued":
            engine.send(.sunsetProduct(productID: parent.id))
            router.go(.storefront(productID: parent.id))
        case "paper":
            engine.send(.sunsetProduct(productID: parent.id))
            if let cut = engine.state.products.first(where: {
                guard let info = $0.releaseInfo else { return false }
                return !info.offMarket && info.priceTier != .budget && !info.isSubscription
            }) {
                engine.send(.repriceProduct(productID: cut.id, tier: .budget))
            }
            // The issue on the stands covers the last *completed* week.
            let printed = (engine.state.day / 7 + 1) * 7
            for _ in 0..<120 where engine.state.day < printed + 1 { await beat(0.5) }
            // Stop the clock, or the issue on the stands moves on.
            engine.setSpeed(.paused)
            for _ in 0..<20 where !screenIsFree { await beat() }
            router.go(.newspaper)
        default:
            break
        }
    }
    #endif
}

extension View {
    /// One line in `ProductsScreen`; everything the flag does lives here.
    func lifecycleAutoRoute(engine: GameEngine, router: AppRouter) -> some View {
        modifier(LifecycleAutoRoute(engine: engine, router: router))
    }
}

// MARK: end K2
