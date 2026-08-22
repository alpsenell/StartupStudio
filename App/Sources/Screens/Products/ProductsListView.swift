import SwiftUI
import TycoonContent
import TycoonEngine

/// The Products segment of the Products tab: the product currently in
/// development (with live progress and the Ship button) plus every released
/// product. Rows push `ProductDetailScreen` via the `UUID` destination
/// registered on `ProductsScreen`'s stack.
struct ProductsListView: View {
    let engine: GameEngine

    @State private var showingNewProduct = false

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            if let product = engine.state.productInDevelopment,
               case .development(let progress) = product.stage {
                InDevelopmentCard(engine: engine, product: product, progress: progress)
            }

            if !releasedProducts.isEmpty {
                ReleasedProductsCard(engine: engine, entries: releasedProducts)
            }

            if engine.state.products.isEmpty {
                EmptyProductsCard { showingNewProduct = true }
            } else if engine.state.productInDevelopment == nil {
                // In-content CTA: nav-bar toolbars sit underneath the
                // opaque top HUD in this design, so actions live in
                // the scroll content instead.
                Button {
                    showingNewProduct = true
                } label: {
                    Label("Start a new product", systemImage: "plus.circle.fill")
                        .font(.system(.headline, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.sm)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .accessibilityLabel("New product")
            }
        }
        .sheet(isPresented: $showingNewProduct) {
            NewProductFlow(engine: engine)
        }
    }

    /// Released products, newest launch first.
    private var releasedProducts: [(product: Product, info: ReleaseInfo)] {
        engine.state.products
            .compactMap { product in
                if case .released(let info) = product.stage {
                    (product, info)
                } else {
                    nil
                }
            }
            .sorted { $0.info.launchDay > $1.info.launchDay }
    }
}

// MARK: - In development

private struct InDevelopmentCard: View {
    let engine: GameEngine
    let product: Product
    let progress: DevProgress

    private var type: ProductTypeDef? {
        engine.content.productType(product.typeID)
    }

    /// Shippable once code reaches 60% of the type's code requirement.
    private var canShip: Bool {
        progress.codePts >= 0.6 * (type?.codePts ?? 0)
    }

    var body: some View {
        CardView("In development", systemImage: "hammer.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                NavigationLink(value: product.id) {
                    HStack(spacing: Theme.Spacing.sm) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.name)
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .foregroundStyle(.primary)
                            if let type {
                                Label(type.name, systemImage: type.iconSystemName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        StatPill(
                            systemImage: "ladybug.fill",
                            value: "\(progress.openBugs) bug\(progress.openBugs == 1 ? "" : "s")",
                            tint: progress.openBugs > 0 ? Theme.warning : .secondary
                        )
                        if progress.hype > 0 {
                            StatPill(
                                systemImage: "megaphone.fill",
                                value: "Hype \(Int(progress.hype.rounded()))",
                                tint: Theme.accent
                            )
                            .accessibilityLabel("Hype \(Int(progress.hype.rounded()))")
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens details and the focus editor")

                TriPhaseProgress(progress: progress, type: type)

                Button {
                    engine.send(.ship(productID: product.id))
                } label: {
                    Label("Ship it", systemImage: "shippingbox.fill")
                        .font(.system(.headline, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.xs)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(!canShip)
                .accessibilityLabel("Ship \(product.name)")

                if !canShip {
                    Text("Shipping unlocks once code reaches 60% of its target.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Released

private struct ReleasedProductsCard: View {
    let engine: GameEngine
    let entries: [(product: Product, info: ReleaseInfo)]

    var body: some View {
        CardView("Released", systemImage: "shippingbox.fill") {
            VStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.product.id) { index, entry in
                    NavigationLink(value: entry.product.id) {
                        ReleasedProductRow(
                            product: entry.product,
                            info: entry.info,
                            type: engine.content.productType(entry.product.typeID)
                        )
                    }
                    .buttonStyle(.plain)
                    if index < entries.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }
}

private struct ReleasedProductRow: View {
    let product: Product
    let info: ReleaseInfo
    let type: ProductTypeDef?

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: type?.iconSystemName ?? "shippingbox")
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 34, height: 34)
                .background(
                    Theme.chipBackground,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.primary)
                HStack(spacing: Theme.Spacing.sm) {
                    Text(info.totalRevenue.money)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.35), value: info.totalRevenue)
                    if info.offMarket {
                        OffMarketTag()
                    }
                }
            }

            Spacer(minLength: Theme.Spacing.sm)

            ScoreBadge(score: info.averageReviewScore)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, Theme.Spacing.sm + 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Small "Off market" capsule tag for products no longer selling.
struct OffMarketTag: View {
    var body: some View {
        Text("Off market")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, Theme.Spacing.xs + 2)
            .padding(.vertical, 2)
            .background(Theme.chipBackground, in: Capsule())
    }
}

// MARK: - Empty state

private struct EmptyProductsCard: View {
    let startNewProduct: () -> Void

    var body: some View {
        Button(action: startNewProduct) {
            VStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Theme.accent)
                Text("Start your first product")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.primary)
                Text("Pick a type, pick a topic, and get building.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.sm)
            .cardStyle()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start your first product")
    }
}
