import SwiftUI
import TycoonEngine

/// The value that pushes the board onto the Products stack. A distinct
/// type rather than a second `UUID` destination, which would be ambiguous
/// with `ProductDetailScreen`'s.
struct FeatureBoardLink: Hashable {
    let productID: UUID
}

/// A button that opens the board from a product's detail screen.
struct FeatureBoardLinkButton: View {
    let productID: UUID
    /// What the board is currently worth, for the button to say.
    let multiplier: Double
    let filled: Int
    let slots: Int

    private var percent: Int { Int(((multiplier - 1) * 100).rounded()) }

    private var caption: String {
        if filled == 0 { return "Nothing placed yet" }
        if percent == 0 { return "\(filled)/\(slots) placed · no change to quality" }
        return "\(filled)/\(slots) placed · \(percent > 0 ? "+" : "")\(percent)% on quality"
    }

    var body: some View {
        NavigationLink(value: FeatureBoardLink(productID: productID)) {
            HStack(spacing: Theme.Spacing.md) {
                PixelIconTile(systemImage: "square.grid.2x2.fill", size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Feature board")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    Text(caption)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
        .buttonStyle(.pressableRow)
        .accessibilityLabel("Feature board. \(caption)")
    }
}

/// Drives `-autoRoute featureboard|featuredetail|featurestore` (and
/// `-autoFeatureBoard`): a headless screenshot pass with no hands starts a
/// build, places the first few cards of the hand on it, and lands on the
/// board, the product detail that links to it, or — once the engine lets
/// the thing ship — the store page that lists what the board put in it.
///
/// The same two rules `StorefrontAutoRoute` keeps, for the same reasons:
/// everything happens on a one-second beat rather than from `onChange`,
/// and it never navigates while a moment owns the screen.
///
/// DEBUG only, and inert without the flag.
private struct FeatureBoardAutoRoute: ViewModifier {
    let engine: GameEngine
    let router: AppRouter

    @State private var routed = false

    func body(content: Content) -> some View {
        content
            .task {
                guard DebugLaunch.opensFeatureBoard else { return }
                startABuildIfEmpty()
                for _ in 0..<600 {
                    if routed { return }
                    try? await Task.sleep(for: .seconds(1))
                    if Task.isCancelled { return }
                    advance()
                }
            }
    }

    private func advance() {
        #if DEBUG
        let destination = DebugLaunch.featureBoardDestination
        // The store page wants a shipped product, so the pass ships the
        // build the moment the engine allows it and routes to the page.
        if destination == .storefront,
           let released = engine.state.products.first(where: {
               if case .released = $0.stage { return true }
               return false
           }) {
            guard !routed, screenIsFree else { return }
            routed = true
            router.go(.storefront(productID: released.id))
            return
        }
        guard let product = engine.state.products.first(where: {
            if case .development = $0.stage { return true }
            return false
        }) else { return }
        // Two cards, so the board is a board rather than an empty grid.
        let hand = FeatureBoard.hand(
            for: product, state: engine.state, content: engine.content, balance: engine.balance
        )
        for card in hand.prefix(3) {
            let placed = engine.state.product(id: product.id)?.features ?? []
            guard !placed.contains(card.id) else { continue }
            engine.send(
                .placeFeature(productID: product.id, cardID: card.id, slot: placed.count)
            )
        }
        if destination == .storefront {
            if engine.state.shipForecast(
                productID: product.id, balance: engine.balance, content: engine.content
            )?.canShip == true {
                engine.send(.ship(productID: product.id))
            }
            return
        }
        guard !routed, screenIsFree else { return }
        routed = true
        router.go(destination == .detail ? .product(product.id) : .featureBoard(productID: product.id))
        #endif
    }

    private var screenIsFree: Bool {
        GameShell.shared.launchDayProductID == nil
            && !GameShell.shared.showingWeeklyReport
            && DecisionPrompt.pending(
                in: engine.state, content: engine.content, balance: engine.balance
            ) == nil
    }

    /// A generated game has nothing to build a board for.
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
    /// One line in `ProductsScreen`; everything the flag does lives here.
    func featureBoardAutoRoute(engine: GameEngine, router: AppRouter) -> some View {
        modifier(FeatureBoardAutoRoute(engine: engine, router: router))
    }
}
