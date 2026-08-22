import SwiftUI
import TycoonEngine

/// The Products tab: the product pipeline and the R&D tech tree, switched
/// with a segmented picker pinned above the scroll content (the same
/// pattern as `BusinessScreen` — nav-bar toolbars sit underneath the opaque
/// top HUD in this design, and content inside the ScrollView would scroll
/// under the HUD).
struct ProductsScreen: View {
    let engine: GameEngine

    private enum ProductsSection: String, CaseIterable, Identifiable {
        case products = "Products"
        case research = "R&D"

        var id: String { rawValue }
    }

    @State private var section: ProductsSection = .products

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Pinned below the top HUD inset, outside the ScrollView, so
                // it can never scroll under the opaque HUD.
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
            .background(Theme.screenBackground)
            .navigationTitle("Products")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            // Registered on the always-present stack root (not inside the
            // segment switch) so product links resolve from either segment.
            .navigationDestination(for: UUID.self) { productID in
                ProductDetailScreen(engine: engine, productID: productID)
            }
        }
    }
}
