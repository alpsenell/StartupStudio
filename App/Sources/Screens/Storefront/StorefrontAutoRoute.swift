import SwiftUI
import TycoonEngine

/// Drives `-autoRoute storefront`: a headless screenshot pass with no
/// hands lands on a real store page.
///
/// The simulator can be launched and screenshotted from the command line
/// but not *tapped*, and a generated game has no products — so the two
/// moves that would give it one (start a build, ship it when the code is
/// far enough along) are made here, through the ordinary reducer. Nothing
/// is fabricated: the engine grows the build day by day at whatever speed
/// `-autoSpeed` set, computes the quality, and draws the reviews. Until it
/// ships, the pass sits on the coming-soon variant of the same page, which
/// is also worth a screenshot.
///
/// DEBUG only, behind a flag no shipped build ever sees, and inert the
/// moment `-autoRoute storefront` is absent.
private struct StorefrontAutoRoute: ViewModifier {
    let engine: GameEngine
    let router: AppRouter

    /// Each page is asked for at most once, so the pass doesn't fight the
    /// player's own navigation afterwards. The preview goes up
    /// immediately; the released page replaces it the day it ships.
    @State private var routedPreview = false
    @State private var routedRelease = false

    private var isRequested: Bool {
        DebugLaunch.autoRouteName == "storefront"
    }

    func body(content: Content) -> some View {
        content
            .task {
                guard isRequested else { return }
                startABuildIfEmpty()
                advance()
            }
            .onChange(of: engine.state.day) { _, _ in
                guard isRequested else { return }
                advance()
            }
    }

    /// Ships as soon as the engine says it can, then routes. Before that,
    /// routes to the build's own coming-soon page so there is always
    /// something on screen.
    private func advance() {
        #if DEBUG
        if let released = engine.state.products.first(where: {
            if case .released = $0.stage { return true }
            return false
        }) {
            guard !routedRelease else { return }
            routedRelease = true
            router.go(.storefront(productID: released.id))
            return
        }
        guard let building = engine.state.products.first else { return }
        if engine.state.shipForecast(
            productID: building.id, balance: engine.balance, content: engine.content
        )?.canShip == true {
            engine.send(.ship(productID: building.id))
            return
        }
        if !routedPreview {
            routedPreview = true
            router.go(.storefront(productID: building.id))
        }
        #endif
    }

    /// A generated game starts with nothing to look at.
    private func startABuildIfEmpty() {
        #if DEBUG
        guard engine.state.products.isEmpty,
              let type = engine.content.productTypes.first(where: {
                  engine.state.isProductTypeUnlocked($0.id, content: engine.content)
              }),
              let topic = engine.content.topics.first
        else { return }
        engine.send(
            .startProduct(typeID: type.id, topicID: topic.id, name: "Overcast", focus: .balanced)
        )
        #endif
    }
}

extension View {
    /// One line in `ProductsScreen`; everything the flag does lives in
    /// U6's own folder.
    func storefrontAutoRoute(engine: GameEngine, router: AppRouter) -> some View {
        modifier(StorefrontAutoRoute(engine: engine, router: router))
    }
}
