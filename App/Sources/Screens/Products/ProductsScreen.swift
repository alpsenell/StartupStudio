import SwiftUI
import TycoonEngine

/// The Products tab: the product pipeline and the R&D tech tree, switched
/// with a segmented picker pinned above the scroll content (the same
/// pattern as `BusinessScreen`).
///
/// Layout contract: the `VStack` (picker + scroll view) is the stack's root
/// content and carries the HUD inset via `withTopHUD`, so the picker sits
/// directly under the HUD. Nothing in the root may live outside that
/// inset-carrying `VStack`.
struct ProductsScreen: View {
    let engine: GameEngine

    private enum ProductsSection: String, CaseIterable, Identifiable {
        case products = "Products"
        case research = "R&D"

        var id: String { rawValue }
    }

    @State private var section: ProductsSection = .products
    @State private var path = NavigationPath()
    /// Set by the `.newProduct` deep link; presents the flow with the
    /// requested topic (if any) already selected.
    @State private var newProductRequest: NewProductRequest?
    /// Set by the `.warRoom` deep link (U1); presents the launch week room
    /// for the build the route implies.
    @State private var warRoom: WarRoomRequest?

    @Environment(AppRouter.self) private var router

    /// Identity for the deep-linked new-product sheet, so a second link
    /// with a different topic re-presents it.
    private struct NewProductRequest: Identifiable {
        let id = UUID()
        let topicID: String?
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                // Pinned directly below the HUD inset (applied to this
                // VStack), outside the ScrollView, so it can never scroll
                // under the opaque HUD.
                Picker("Section", selection: $section) {
                    ForEach(ProductsSection.allCases) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Products section")
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.sm)
                .background(Theme.screenBackground)

                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        switch section {
                        case .products:
                            ProductsListView(engine: engine)
                        case .research:
                            ResearchView(engine: engine)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.sm)
                    .padding(.bottom, Theme.Spacing.lg)
                }
            }
            // The HUD inset lives on the stack's root content (this VStack),
            // not on the NavigationStack: the picker lands below it, and
            // pushed product details show the navigation bar instead.
            .withTopHUD(engine: engine)
            .background(Theme.screenBackground)
            .navigationTitle("Products")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            // Registered on the always-present stack root (not inside the
            // segment switch) so product links resolve from either segment.
            .navigationDestination(for: UUID.self) { productID in
                ProductDetailScreen(engine: engine, productID: productID)
            }
            .onChange(of: router.pendingPush, initial: true) { _, _ in
                consumeRoute()
            }
            .sheet(item: $newProductRequest) { request in
                NewProductFlow(engine: engine, initialTopicID: request.topicID)
            }
            .fullScreenCover(item: $warRoom) { request in
                WarRoomScreen(engine: request.engine, productID: request.productID)
            }
        }
    }

    /// Deep links into this tab: R&D picks the segment, a product id
    /// pushes its detail screen, and `.newProduct` opens the flow.
    private func consumeRoute() {
        #if DEBUG
        // `-autoRoute warRoom`: a headless pass lands in the room.
        if warRoom == nil, let request = WarRoomRequest.debugLaunch() {
            warRoom = request
        }
        #endif
        switch router.pendingPush {
        case .research:
            section = .research
            router.take(.research)
        case .product(let productID):
            section = .products
            router.take(.product(productID))
            guard engine.state.product(id: productID) != nil else { return }
            path.append(productID)
        case .newProduct(let topicID):
            section = .products
            router.take(.newProduct(topicID: topicID))
            newProductRequest = NewProductRequest(topicID: topicID)
        case .warRoom:
            section = .products
            router.take(.warRoom)
            warRoom = WarRoomRequest.offered(by: engine)
        default:
            break
        }
    }
}
