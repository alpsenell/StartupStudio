import SwiftUI
import TycoonEngine

// MARK: Iteration 9 — L3 (children who grow up, and remember)

/// The Life tab's way in to `ChildrenScreen`, and nothing else.
///
/// A zero-height view rather than a card: the children themselves draw on
/// the Family card, which is where the founder already looks for them. All
/// this does is own the push — it consumes `Route.children` (sent by the
/// Family card's button and by anything else that deep-links to the kids)
/// and the `-autoRoute children` landing a headless screenshot pass needs.
/// Keeping it here means the Life tab's own `consumeRoute`, which belongs
/// to no lane, does not have to grow an arm per lane.
struct ChildrenLink: View {
    let onOpen: () -> Void

    @Environment(AppRouter.self) private var router
    @State private var tookLaunchRoute = false

    var body: some View {
        Color.clear
            .frame(height: 0)
            .accessibilityHidden(true)
            .onAppear {
                guard !tookLaunchRoute else { return }
                tookLaunchRoute = true
                if Route.launchRoute == .children { onOpen() }
            }
            .onChange(of: router.pendingPush, initial: true) { _, _ in
                if router.take(.children) { onOpen() }
            }
    }
}
