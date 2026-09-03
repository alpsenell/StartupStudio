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

    /// How many products the current office can build at once, and how
    /// many are in flight. Both come from the engine.
    private var slots: (used: Int, total: Int) {
        (engine.state.productsInDevelopment.count, engine.state.devSlots)
    }

    private var hasFreeSlot: Bool { slots.used < slots.total }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            if slots.total > 1 || slots.used > 0 {
                DevSlotsRow(used: slots.used, total: slots.total)
            }

            ForEach(engine.state.productsInDevelopment) { product in
                if case .development(let progress) = product.stage {
                    InDevelopmentCard(engine: engine, product: product, progress: progress)
                }
            }

            if !releasedProducts.isEmpty {
                ReleasedProductsCard(engine: engine, entries: releasedProducts)
            }

            if engine.state.products.isEmpty {
                EmptyProductsCard { showingNewProduct = true }
                // Day 0 used to be one card and a blank screen. The
                // catalog shows what a product is before the player
                // starts one.
                TypeCatalogPreview(engine: engine) { typeID in
                    ShipForecast.preStart(
                        typeID: typeID, topicID: nil, codebaseID: nil,
                        state: engine.state, balance: engine.balance, content: engine.content
                    ).map { Int($0.quality.rounded()) }
                }
            } else if hasFreeSlot {
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
            } else {
                Text("Every development slot is busy. Ship something, or move to a bigger office for more.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Spacing.xs)
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

    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI
    /// updates this property for presented content before the
    /// environment is installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }
    @State private var confirmingShip = false

    private var type: ProductTypeDef? {
        engine.content.productType(product.typeID)
    }

    /// The engine's own ship gate, read from balance rather than mirrored.
    private var canShip: Bool {
        progress.codePts >= engine.balance.shipCodeThreshold * (type?.codePts ?? 0)
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
                .buttonStyle(.pressableRow)
                .accessibilityHint("Opens details and the focus editor")

                TriPhaseProgress(progress: progress, type: type)
                if engine.state.economy.workPace != .normal || engine.state.employees.contains(where: { !$0.isFounder }) {
                    HStack(spacing: Theme.Spacing.sm) {
                        WorkPacePill(pace: engine.state.economy.workPace)
                        Spacer(minLength: 0)
                    }
                    WorkPaceControl(engine: engine, compact: true)
                }

                Button {
                    confirmingShip = true
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
                    Text(
                        "Shipping unlocks once code reaches \(Int((engine.balance.shipCodeThreshold * 100).rounded()))% of its target."
                    )
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                }

                // Launch week (U1): offered from seven days out, never forced.
                WarRoomEntryButton(engine: engine, product: product)
            }
        }
        .confirmationDialog(
            "Ship \(product.name)?",
            isPresented: $confirmingShip,
            titleVisibility: .visible
        ) {
            Button("Ship it") {
                shell.toasts.send(
                    .ship(productID: product.id),
                    to: engine,
                    rejected: "It is not ready to ship yet."
                )
            }
            Button("Keep working", role: .cancel) {}
        } message: {
            Text("Development stops for good and the press reviews whatever is finished.")
        }
    }
}

/// "2 of 3 in development" — the office's concurrent build slots.
private struct DevSlotsRow: View {
    let used: Int
    let total: Int

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.accent)
            Text("\(used) of \(total) in development")
                .font(Theme.Typography.number(.footnote))
            Spacer(minLength: Theme.Spacing.sm)
            HStack(spacing: 3) {
                ForEach(0..<max(total, 1), id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(index < used ? Theme.accent : Theme.chipBackground)
                        .frame(width: 14, height: 6)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(used) of \(total) development slots in use")
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
                        .font(Theme.Typography.number(.caption, weight: .regular))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .animation(Theme.Motion.valueChange, value: info.totalRevenue)
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
        .buttonStyle(.pressableRow)
        .accessibilityLabel("Start your first product")
    }
}

// MARK: - Day-0 catalog

/// The product types, read-only, under the empty state: name, blurb,
/// effort, price and market, with the locked ones dimmed and a line about
/// what R&D unlocks. Iteration 4 seam: `ceiling` is WS-F's slot for the
/// crew-ceiling badge ("~58 with this crew") once the pre-start forecast
/// exists; until then the cards carry no number.
struct TypeCatalogPreview: View {
    let engine: GameEngine
    /// The crew ceiling per type id, when a forecast is available.
    var ceiling: (String) -> Int? = { _ in nil }

    private var types: [ProductTypeDef] { engine.content.productTypes }

    private var lockedCount: Int {
        types.count { !engine.state.isProductTypeUnlocked($0.id, content: engine.content) }
    }

    var body: some View {
        CardView("What you could build", systemImage: "square.grid.2x2.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                // The crew ceiling is the same whatever the type — it is
                // the people, not the product — so it is said once.
                if let first = types.first, let crewCeiling = ceiling(first.id) {
                    CrewCeilingNote(ceiling: crewCeiling)
                }
                ForEach(types) { type in
                    let unlocked = engine.state.isProductTypeUnlocked(type.id, content: engine.content)
                    TypePreviewRow(type: type, isUnlocked: unlocked, ceiling: nil)
                    if type.id != types.last?.id {
                        Divider()
                    }
                }
                if lockedCount > 0 {
                    Label(
                        "Research unlocks \(lockedCount) more type\(lockedCount == 1 ? "" : "s").",
                        systemImage: "flask.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct TypePreviewRow: View {
    let type: ProductTypeDef
    let isUnlocked: Bool
    let ceiling: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                Image(systemName: isUnlocked ? type.iconSystemName : "lock.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(isUnlocked ? Theme.accent : Color.secondary)
                    .frame(width: 18)
                Text(type.name)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Spacer(minLength: Theme.Spacing.xs)
                if let ceiling {
                    Text("~\(ceiling) with this crew")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.scoreTint(ceiling))
                } else if !isUnlocked {
                    Text("Research to unlock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(type.blurb)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Theme.Spacing.md) {
                EffortDots(label: "Design", points: type.designPts, tint: Theme.designPhase)
                EffortDots(label: "Code", points: type.codePts, tint: Theme.codePhase)
                EffortDots(label: "Polish", points: type.polishPts, tint: Theme.polishPhase)
            }
            if isUnlocked {
                HStack(spacing: Theme.Spacing.md) {
                    Label(String(format: "$%.2f/unit", type.unitPrice), systemImage: "tag")
                    Label(
                        "\(Int(type.marketSize).formatted(.number.notation(.compactName).locale(Theme.gameLocale))) market",
                        systemImage: "person.3.fill"
                    )
                }
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            }
        }
        .opacity(isUnlocked ? 1 : 0.55)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            isUnlocked ? "\(type.name). \(type.blurb)" : "\(type.name), locked. Research to unlock."
        )
    }
}

/// "With today's crew, the best any of these reviews is ~58." Once, above
/// a list of types, because the number belongs to the people.
struct CrewCeilingNote: View {
    let ceiling: Int

    var body: some View {
        Label {
            Text("With today's crew, the best any of these reviews is about ")
                + Text("\(ceiling)").foregroundStyle(Theme.scoreTint(ceiling)).bold()
                + Text(". Better people raise it; the topic moves it.")
        } icon: {
            Image(systemName: "person.3.fill")
                .foregroundStyle(Theme.scoreTint(ceiling))
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityLabel("With today's crew the best any product reviews is about \(ceiling) out of 100")
    }
}
