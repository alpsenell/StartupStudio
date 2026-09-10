import SwiftUI
import TycoonEngine

// MARK: - Iteration 13 — P3 (purchases: surfaces and copy)

/// The headless screenshot pass for the four shop surfaces:
///
/// - `-autoRoute shop` — the money sheet, over HQ.
/// - `-autoRoute receiver` — the bankruptcy biography, on a scratch copy of
///   the open company with the ending written in (until P2's
///   `release-bankruptcy` fixture lands; the save is not touched).
/// - `-autoTab team -autoRoute veteran` — the hire sheet (`Route.hiring`).
/// - `-autoTab life -autoRoute loftpack` — the furnish sheet
///   (`Route.furnish`); with `-autoShopOwned` the pack is owned and its six
///   items are placed in the first empty slots that fit.
///
/// Any of the four routes, or `-autoShop`, stands up `ShopSurfacePreview`
/// when no store is injected, so the surfaces draw before P2's client
/// exists. Release builds never see any of it.
extension View {
    func shopAutoRoute(engine: GameEngine) -> some View {
        #if DEBUG
        modifier(ShopAutoRoute(engine: engine))
        #else
        self
        #endif
    }
}

#if DEBUG
enum ShopSurfaceDebug {
    static let routes: Set<String> = ["shop", "receiver", "veteran", "loftpack"]

    /// The fake store for a debug pass that asked for a shop surface.
    @MainActor static let previewStore: ShopSurfacePreview? = {
        guard DebugLaunch.autoShop else { return nil }
        return ShopSurfacePreview(
            owned: DebugLaunch.autoShopOwned ? [ShopSurfaceItem.loftPack.productID] : []
        )
    }()

    @MainActor static var consumed = false

    /// A copy of the company with a bankruptcy written in: cash a month of
    /// burn under water, the ending on today. Only ever drawn.
    @MainActor
    static func bankruptCopy(of engine: GameEngine) -> GameEngine? {
        var state = engine.state
        if state.company.cash >= 0 {
            state.company.cash = -max(2_000, engine.weeklyBurn * 4)
        }
        let reason = "The account stayed overdrawn past the grace period. The bank sent the receiver."
        let json = #"{"day":\#(state.day),"reason":"\#(reason)","kind":"bankruptcy"}"#
        guard let info = try? JSONDecoder().decode(GameOverInfo.self, from: Data(json.utf8)) else { return nil }
        state.gameOver = info
        state.speed = .paused
        return GameEngine(state: state, balance: engine.balance, content: engine.content)
    }

    /// Stands the owned pack up in the room, first empty slot per item.
    @MainActor
    static func placeLoftPack(engine: GameEngine) {
        for item in HomeDecor.loftPackItems {
            let tier = engine.state.life.home
            if let slot = HomeDecor.firstEmptySlot(for: item.id, tier: tier, decor: engine.state.life.decor) {
                engine.send(.placeDecor(slot: slot, itemID: item.id))
            }
        }
    }
}

private struct ShopAutoRoute: ViewModifier {
    let engine: GameEngine

    @State private var showingMoney = false
    @State private var receiverEngine: GameEngine?

    func body(content: Content) -> some View {
        content
            .task { await start() }
            .sheet(isPresented: $showingMoney) {
                MoneySheet(engine: engine)
            }
            .fullScreenCover(isPresented: Binding(
                get: { receiverEngine != nil },
                set: { if !$0 { receiverEngine = nil } }
            )) {
                if let scratch = receiverEngine, let info = scratch.state.gameOver {
                    FounderBiographyView(engine: scratch, info: info, onNewGame: { _, _, _ in })
                        .gameColumn()
                }
            }
    }

    private func start() async {
        guard !ShopSurfaceDebug.consumed,
              let route = DebugLaunch.autoRouteName,
              ["shop", "receiver", "loftpack"].contains(route)
        else { return }
        ShopSurfaceDebug.consumed = true
        try? await Task.sleep(for: .seconds(1))
        switch route {
        case "shop":
            showingMoney = true
        case "receiver":
            receiverEngine = ShopSurfaceDebug.bankruptCopy(of: engine)
        case "loftpack":
            if DebugLaunch.autoShopOwned { ShopSurfaceDebug.placeLoftPack(engine: engine) }
        default:
            break
        }
    }
}
#endif
