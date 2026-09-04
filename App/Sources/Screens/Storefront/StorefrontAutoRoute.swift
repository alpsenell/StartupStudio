import SwiftUI
import TycoonEngine

/// Drives `-autoRoute storefront`: a headless screenshot pass with no
/// hands lands on a real store page.
///
/// The simulator can be launched and screenshotted from the command line
/// but not *tapped*, and a generated game has no products — so the two
/// moves that would give it one (start a build; ship it once the engine
/// says it can) are made here, through the ordinary reducer. Nothing is
/// fabricated: the engine grows the build day by day at whatever speed
/// `-autoSpeed` set, computes the quality and draws the reviews. Until it
/// ships, the pass sits on the coming-soon variant of the same page, which
/// is also worth a screenshot.
///
/// Two rules keep it from breaking the app it is photographing:
///
/// 1. **Everything happens on a one-second beat, never from `onChange`.**
///    Sending an action or asking the router to push from inside a view
///    update — which is exactly when a ship happens, with a sheet already
///    mid-presentation — re-enters SwiftUI's update and traps.
/// 2. **It never navigates while a moment is on screen.** Launch day and
///    the story questions own the screen when they are up; the pass waits
///    them out rather than pushing underneath them, and it never answers
///    them: a decision is not a screen, and a pass with no hands has no
///    business taking one.
///
/// The price of the second rule: a story question pauses the clock until
/// somebody answers it, so a run that meets one early sits on the
/// coming-soon page and never reaches a ship. Run it again — the question
/// is drawn from the run's own seed, and a run that gets a clear fortnight
/// ships and lands on the released page. Answering them automatically was
/// tried and abandoned: dismissing a presented sheet from outside the view
/// tree traps inside SwiftUI, in a sheet whose content reads a
/// non-optional `@Environment(AppRouter.self)` while its host is being
/// torn down (`LaunchDaySheet` is one). That is a real latent bug, but it
/// belongs to the screens that own those reads, not to a debug flag.
///
/// DEBUG only, behind a flag no shipped build ever sees, and inert the
/// moment `-autoRoute storefront` is absent.
private struct StorefrontAutoRoute: ViewModifier {
    let engine: GameEngine
    let router: AppRouter

    /// Each page is asked for at most once, so the pass doesn't fight the
    /// player's own navigation afterwards. The preview goes up as soon as
    /// there is a build; the released page replaces it once it ships.
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
                // Ten minutes of beats, or until the released page is up.
                for _ in 0..<600 {
                    if routedRelease { return }
                    try? await Task.sleep(for: .seconds(1))
                    if Task.isCancelled { return }
                    advance()
                }
            }
    }

    /// Ships as soon as the engine allows, and routes when the screen is
    /// free.
    private func advance() {
        #if DEBUG
        if let released = engine.state.products.first(where: {
            if case .released = $0.stage { return true }
            return false
        }) {
            guard !routedRelease, screenIsFree else { return }
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
        if !routedPreview, screenIsFree {
            routedPreview = true
            router.go(.storefront(productID: building.id))
        }
        #endif
    }

    /// Whether anything modal is up. Pushing a destination underneath a
    /// sheet that is still presenting is the one thing this pass must not
    /// do.
    private var screenIsFree: Bool {
        GameShell.shared.launchDayProductID == nil
            && !GameShell.shared.showingWeeklyReport
            && DecisionPrompt.pending(
                in: engine.state, content: engine.content, balance: engine.balance
            ) == nil
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
