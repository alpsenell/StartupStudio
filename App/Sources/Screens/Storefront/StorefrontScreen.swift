import PixelKit
import SwiftUI
import TycoonContent
import TycoonEngine

/// A product's page in the store, as a customer would see it: box art,
/// the developer's name, a star rating, the price as the buy button, three
/// screenshots, what's new, the reviews, and how it is selling this week.
///
/// The product detail screen is the *owner's* view — quality, forecasts,
/// bug queues, the support roster. This is the same product from the
/// outside, which is the only place in the game where the player sees
/// what they shipped the way the market does. Nothing here is new state:
/// every figure comes off `ReleaseInfo` and the content catalog.
///
/// A product still in development gets the coming-soon variant, so the
/// page exists from the day the build starts.
struct StorefrontScreen: View {
    let engine: GameEngine
    let productID: UUID

    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI updates
    /// this property for presented content before the environment is
    /// installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }

    @State private var changingPrice = false

    var body: some View {
        Group {
            if let product = engine.state.product(id: productID) {
                ScrollView {
                    StorefrontPage(engine: engine, product: product) { changingPrice = true }
                        .padding(Theme.Spacing.lg)
                }
            } else {
                ContentUnavailableView(
                    "Not in the store",
                    systemImage: "questionmark.square.dashed",
                    description: Text("This product is no longer in the save.")
                )
            }
        }
        .background(Theme.screenBackground)
        .navigationTitle("Store")
        .navigationBarTitleDisplayMode(.inline)
        // The Products tab hides its bar for the HUD; a pushed screen
        // shows it again so Back and the swipe-back gesture come back.
        .toolbar(.visible, for: .navigationBar)
        // MARK: K2 (product lifecycle) — the buy button opens the priced
        // sheet the product page opens, so the price has one sheet.
        .sheet(isPresented: $changingPrice) {
            LifecyclePriceSheet(engine: engine, productID: productID)
        }
        // MARK: end K2
    }

    private func type(for product: Product) -> ProductTypeDef? {
        engine.content.productType(product.typeID)
    }

    private func topic(for product: Product) -> TopicDef? {
        engine.content.topic(product.topicID)
    }
}

// MARK: - The page

/// Everything on the store page, without the scroll view around it.
///
/// Split out from `StorefrontScreen` because that is how this app is
/// snapshotted: `ImageRenderer` renders a `ScrollView` as a blank PNG, so
/// the tests render the content and the screen supplies the scrolling.
struct StorefrontPage: View {
    let engine: GameEngine
    let product: Product
    /// Tapping the buy button. The screen presents the price sheet; a
    /// snapshot passes an empty closure.
    var changePrice: () -> Void = {}

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            switch product.stage {
            case .released(let info):
                StorefrontHero(
                    product: product,
                    developer: engine.state.company.name,
                    type: type,
                    topic: topic,
                    rating: .released(info),
                    // MARK: T7 (press and stakes) — an exclusive's embargo.
                    today: engine.state.day,
                    // MARK: end T7
                    // MARK: Iteration 18 — the studio mark
                    markSeed: engine.state.company.markSeed
                    // MARK: end of Iteration 18
                )
                priceButton(info: info)
                StorefrontShotsCard(product: product)
                // M1: what the thing actually does, listed the way a store
                // page lists it. Absent when nobody placed a card.
                StorefrontFeaturesCard(product: product, content: engine.content)
                StorefrontWeekCard(info: info, type: type)
                WhatsNewCard(product: product, info: info)
                // MARK: T7 (press and stakes) — only the verdicts that are out.
                StorefrontReviewsCard(info: info, today: engine.state.day)
                // MARK: end T7
                // MARK: Iteration 18 — the launch card, retroactively:
                // every product that ever shipped can still be minted.
                LaunchCardButton(engine: engine, product: product)
                // MARK: end of Iteration 18
            case .development(let progress):
                StorefrontHero(
                    product: product,
                    developer: engine.state.company.name,
                    type: type,
                    topic: topic,
                    rating: .comingSoon,
                    // MARK: Iteration 18 — the studio mark
                    markSeed: engine.state.company.markSeed
                    // MARK: end of Iteration 18
                )
                ComingSoonCard(progress: progress, type: type)
                StorefrontFeaturesCard(product: product, content: engine.content)
                StorefrontShotsCard(product: product)
            }
        }
    }

    /// The store's buy button. It shows what a customer pays — the type's
    /// unit price scaled by the tier the player set — and opens the price
    /// change that already exists, rather than restating it here.
    @ViewBuilder
    private func priceButton(info: ReleaseInfo) -> some View {
        let priceable = LiveOps.isAvailable && !info.offMarket
        Button(action: changePrice) {
            HStack(spacing: Theme.Spacing.sm) {
                Text(priceLabel(info: info))
                    .font(Theme.Typography.number(.headline))
                if priceable {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.footnote.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.xs)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .disabled(!priceable)
        .accessibilityLabel(
            priceable ? "\(priceLabel(info: info)). Change the price." : "Off the market"
        )
        // MARK: K2 (product lifecycle) — a retired product says so and
        // when; a sale and a rise are printed where the customer sees them.
        if let sunset = info.sunsetDay {
            Text("Discontinued on \(GameCalendar(day: sunset).longLabel). Nobody can buy this any more.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if info.offMarket {
            Text("Nobody can buy this any more.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if let sale = info.lastSaleDay,
                  engine.state.day - sale <= engine.balance.economy.updateBumpDays {
            Text("On sale this week only.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.positiveCash)
        } else if let rise = info.priceRiseUntilDay, engine.state.day <= rise,
                  let changed = info.lastPriceChangeDay {
            Text("The price went up on \(GameCalendar(day: changed).longLabel). Buyers are waiting for a sale.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        // MARK: end K2
    }

    /// "$14 · Premium", or "$9 / mo · Standard" for a subscription. The
    /// price is the type's list price times the tier's factor, which is
    /// the same arithmetic the economy charges.
    private func priceLabel(info: ReleaseInfo) -> String {
        // MARK: K2 (product lifecycle)
        if info.sunsetDay != nil { return "Discontinued" }
        // MARK: end K2
        guard let type else { return info.priceTier.displayName }
        let factor = engine.balance.economy.priceTier(info.priceTier).priceFactor
        let price = Int((type.unitPrice * factor).rounded())
        let money = info.isSubscription ? "\(price.money) / mo" : price.money
        return "\(money) · \(info.priceTier.displayName)"
    }

    private var type: ProductTypeDef? { engine.content.productType(product.typeID) }
    private var topic: TopicDef? { engine.content.topic(product.topicID) }
}

// MARK: - What it does

/// M1: the product's feature board, read as a store listing — the cards
/// the studio actually chose, with the line each one was written with.
/// Nothing is drawn for a product with an empty board, which is every
/// product from before the board existed.
private struct StorefrontFeaturesCard: View {
    let product: Product
    let content: ContentCatalog

    private var cards: [FeatureCardDef] {
        product.features.compactMap { content.featureCard($0) }
    }

    var body: some View {
        if !cards.isEmpty {
            CardView("What it does", systemImage: "checklist") {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    ForEach(cards) { card in
                        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.footnote)
                                .foregroundStyle(Theme.accent)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(card.name)
                                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                if !card.blurb.isEmpty {
                                    Text(card.blurb)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }
}

// MARK: - Getting here

/// The navigation value that pushes a storefront.
///
/// A type of its own rather than a second `UUID` destination on the
/// Products stack, which already pushes the *owner's* detail screen for a
/// bare product id — two destinations for the same value type would be
/// ambiguous.
struct StorefrontLink: Hashable {
    let productID: UUID
}

/// "View in store": the one link from the owner's view of a product to the
/// customer's.
struct StorefrontLinkButton: View {
    let productID: UUID

    var body: some View {
        NavigationLink(value: StorefrontLink(productID: productID)) {
            Label("View in store", systemImage: "storefront")
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.xs)
        }
        .buttonStyle(.bordered)
        .accessibilityHint("Shows this product's store page, as a customer sees it")
    }
}

// MARK: - Hero

/// Box art, name, developer and rating, on pixel paper: the top of a store
/// listing, in the game's own chrome rather than the system's.
private struct StorefrontHero: View {
    enum Rating {
        case released(ReleaseInfo)
        case comingSoon
    }

    let product: Product
    let developer: String
    let type: ProductTypeDef?
    let topic: TopicDef?
    let rating: Rating
    // MARK: T7 (press and stakes)
    /// Today, for an exclusive's embargo; `nil` rates on every review.
    var today: Int? = nil
    // MARK: end T7
    // MARK: Iteration 18 — the studio mark
    /// The developer's glyph, on the cover and beside their name. `nil`
    /// draws the page exactly as it was.
    var markSeed: UInt64? = nil
    // MARK: end of Iteration 18

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        PixelPanel(contentPadding: Theme.Spacing.md) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.md))
                : AnyLayout(HStackLayout(alignment: .top, spacing: Theme.Spacing.md))
            layout {
                ProductBoxArtView(
                    typeID: product.typeID,
                    topicID: product.topicID,
                    seed: product.id.artSeed,
                    size: 84,
                    // MARK: Iteration 18 — the studio mark on the cover.
                    markSeed: markSeed
                    // MARK: end of Iteration 18
                )
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(product.name)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.pixelInk)
                        .fixedSize(horizontal: false, vertical: true)
                    // MARK: Iteration 18 — the developer's mark beside the
                    // developer's name, the way a store badges a publisher.
                    HStack(spacing: Theme.Spacing.xs) {
                        if let markSeed {
                            StudioMarkView(seed: markSeed, size: 14)
                        }
                        Text(developer)
                            .font(.subheadline)
                            .foregroundStyle(Theme.pixelInk.opacity(0.7))
                    }
                    // MARK: end of Iteration 18
                    Text(category)
                        .font(.footnote)
                        .foregroundStyle(Theme.pixelInk.opacity(0.7))
                    switch rating {
                    case .released(let info):
                        // T7: the stars rate the verdicts that are out.
                        StoreStars(score: info.visibleAverageScore(on: today), count: info.visibleReviews(on: today).count)
                            .padding(.top, Theme.Spacing.xs)
                    case .comingSoon:
                        PixelText(text: "Coming soon", scale: 2, color: Theme.pixelInk)
                            .padding(.top, Theme.Spacing.xs)
                            .accessibilityLabel("Coming soon")
                    }
                }
                // Not a `Spacer`: in the stacked accessibility layout a
                // spacer takes the vertical axis and leaves half a panel
                // of empty paper under the rating.
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var category: String {
        let typeName = type?.name ?? "Product"
        guard let topicName = topic?.name else { return typeName }
        return "\(typeName) · \(topicName)"
    }
}

/// Five stars from a 0–100 review score, to the nearest half star, with
/// the score and how many reviews it came from.
///
/// The owner's screens show the raw 0–100 in a `ScoreBadge`, because that
/// is the number the engine balances on. A customer sees stars, so this is
/// the one place the same number is drawn the other way — with the 0–100
/// still spelled out beside it so the two screens can be compared.
struct StoreStars: View {
    let score: Int
    let count: Int

    /// Score out of five, to the nearest half.
    private var starsOutOfFive: Double {
        (Double(score) / 20 * 2).rounded() / 2
    }

    /// Five stars and the score beside them where the width allows, and
    /// stacked under them where it does not. At the accessibility sizes
    /// the star glyphs alone are most of a phone wide, and the row used to
    /// squeeze "No reviews yet" into a one-letter column.
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Spacing.xs) { stars; caption }
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) { stars; caption }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            count == 0
                ? "Not reviewed yet"
                : "\(starsText) out of 5 stars, from \(count) review\(count == 1 ? "" : "s"), scoring \(score) out of 100"
        )
    }

    private var stars: some View {
        HStack(spacing: 1) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: symbol(index: index))
                    .foregroundStyle(count == 0 ? Theme.pixelInk.opacity(0.3) : Theme.warning)
            }
        }
        .font(.footnote)
        .fixedSize()
    }

    @ViewBuilder
    private var caption: some View {
        if count > 0 {
            Text(starsText)
                .font(Theme.Typography.number(.footnote))
                .foregroundStyle(Theme.pixelInk)
            Text("(\(count.formatted(.number.locale(Theme.gameLocale))))")
                .font(.caption)
                .foregroundStyle(Theme.pixelInk.opacity(0.7))
        } else {
            Text("No reviews yet")
                .font(.caption)
                .foregroundStyle(Theme.pixelInk.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var starsText: String {
        starsOutOfFive.formatted(.number.precision(.fractionLength(1)).locale(Theme.gameLocale))
    }

    private func symbol(index: Int) -> String {
        let filled = starsOutOfFive - Double(index)
        if filled >= 1 { return "star.fill" }
        if filled >= 0.5 { return "star.leadinghalf.filled" }
        return "star"
    }
}

// MARK: - Screenshots

private struct StorefrontShotsCard: View {
    let product: Product

    var body: some View {
        CardView("Screenshots", systemImage: "photo.on.rectangle") {
            StorefrontShotStrip(
                typeID: product.typeID,
                topicID: product.topicID,
                seed: product.id.artSeed
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - This week

/// What the store is doing right now: the most recent recorded week, as
/// units or as subscribers depending on how the product makes money.
private struct StorefrontWeekCard: View {
    let info: ReleaseInfo
    let type: ProductTypeDef?

    private var latest: WeeklySale? {
        info.weeklySales.max { $0.weekIndex < $1.weekIndex }
    }

    var body: some View {
        CardView("This week", systemImage: "chart.line.uptrend.xyaxis") {
            if info.weeklySales.isEmpty, info.subscribers == 0 {
                Text("The first week is still ticking — nothing to report yet.")
                    .emptySectionText()
            } else {
                StatRowLayout {
                    if info.isSubscription {
                        StorefrontStat(
                            label: "Subscribers",
                            value: info.subscribers.formatted(.number.locale(Theme.gameLocale))
                        )
                    } else {
                        StorefrontStat(
                            label: "Units",
                            value: (latest?.units ?? 0).formatted(.number.locale(Theme.gameLocale))
                        )
                    }
                    StorefrontStat(label: "Revenue", value: (latest?.revenue ?? 0).money)
                }
            }
        }
    }
}

/// Two figures side by side — stacked instead at accessibility text
/// sizes, where a money figure otherwise wraps in the middle of its own
/// digits.
private struct StatRowLayout<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ViewBuilder var content: Content

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.md))
            : AnyLayout(HStackLayout(alignment: .top, spacing: Theme.Spacing.xl))
        layout { content }
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StorefrontStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(Theme.Typography.number(.title3))
                .contentTransition(.numericText())
                .animation(Theme.Motion.valueChange, value: value)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - What's new

/// The update history, told the way a store tells it: a version number
/// that counts the patches, the day the last one landed, and a note.
///
/// The engine records how many updates shipped and the day of the most
/// recent one, and nothing about what was in them — so the note is
/// generated from the product's own id and its version, deterministically,
/// exactly as the box art is. Only the version whose date is known gets a
/// dated entry; the ones before it are counted, not invented.
private struct WhatsNewCard: View {
    let product: Product
    let info: ReleaseInfo

    var body: some View {
        CardView("What's new", systemImage: "arrow.triangle.2.circlepath") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                // "Version 1.2" is a figure, not a sentence: it never
                // hyphenates. The date moves under it instead.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Theme.Spacing.sm) { versionLine; dateStamp }
                    VStack(alignment: .leading, spacing: 2) { versionLine; dateStamp }
                }
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if info.updateCount > 1 {
                    Text(
                        "\(info.updateCount.formatted(.number.locale(Theme.gameLocale))) updates since launch."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var versionLine: some View {
        Text(version)
            .font(Theme.Typography.number(.subheadline, weight: .bold))
            .lineLimit(1)
            .fixedSize()
    }

    private var dateStamp: some View {
        Text(dateLine)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var version: String { "Version 1.\(info.updateCount)" }

    private var dateLine: String {
        GameCalendar(day: info.lastUpdateDay ?? info.launchDay).hudLabel
    }

    private var note: String {
        guard info.updateCount > 0 else {
            return "The version that shipped on launch day."
        }
        let notes = [
            "Bug fixes and stability. You asked; we listened.",
            "Faster launch, fewer crashes on older devices.",
            "A rebuilt settings screen and small polish everywhere.",
            "Performance work under the hood, and a lighter install.",
            "Fixes for the issues you reported most.",
            "Refreshed icons, and the thing that kept logging you out.",
        ]
        // Deterministic per product and version, so re-opening the page
        // never changes the note under the player.
        let index = Int((product.id.artSeed &+ UInt64(info.updateCount)) % UInt64(notes.count))
        return notes[index]
    }
}

// MARK: - Reviews

/// The press, as a store shows it: one card per outlet, with the score and
/// the quote. The same reviews the detail screen lists as rows.
private struct StorefrontReviewsCard: View {
    let info: ReleaseInfo
    // MARK: T7 (press and stakes)
    /// Today, for an exclusive's embargo; `nil` lists every review.
    var today: Int? = nil
    // MARK: end T7

    var body: some View {
        CardView("Reviews", systemImage: "quote.bubble") {
            if info.reviews.isEmpty {
                Text("The press hasn't weighed in yet.")
                    .emptySectionText()
            } else {
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(Array(info.visibleReviews(on: today).enumerated()), id: \.offset) { _, review in // T7
                        ReviewQuoteCard(review: review)
                    }
                }
            }
        }
    }
}

private struct ReviewQuoteCard: View {
    let review: Review

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                ScoreBadge(score: review.score)
                Text(review.outlet)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                // The badge already carries the number; at accessibility
                // sizes the stars would squeeze the outlet's name down to
                // two letters and an ellipsis, so they go.
                if !dynamicTypeSize.isAccessibilitySize {
                    StoreStarsCompact(score: review.score)
                }
            }
            Text("“\(review.blurb)”")
                .font(.footnote)
                .italic()
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.chipBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// The star row without the numbers, for a single review.
private struct StoreStarsCompact: View {
    let score: Int

    private var stars: Double { (Double(score) / 20 * 2).rounded() / 2 }

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<5, id: \.self) { index in
                let filled = stars - Double(index)
                Image(
                    systemName: filled >= 1
                        ? "star.fill" : (filled >= 0.5 ? "star.leadinghalf.filled" : "star")
                )
            }
        }
        .font(.caption2)
        .foregroundStyle(Theme.warning)
        .accessibilityHidden(true)
    }
}

// MARK: - Coming soon

/// The pre-release page: how far the build has got, and whatever buzz the
/// campaigns have bought it.
private struct ComingSoonCard: View {
    let progress: DevProgress
    let type: ProductTypeDef?

    private var completion: Double {
        guard let type else { return 0 }
        let required = type.designPts + type.codePts + type.polishPts
        guard required > 0 else { return 0 }
        let done = min(progress.designPts, type.designPts)
            + min(progress.codePts, type.codePts)
            + min(progress.polishPts, type.polishPts)
        return min(1, done / required)
    }

    var body: some View {
        CardView("Not on sale yet", systemImage: "hourglass") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("This one is still being built. The store page goes live the day it ships.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                StatRowLayout {
                    StorefrontStat(
                        label: "Built",
                        value: (completion * 100)
                            .formatted(.number.precision(.fractionLength(0)).locale(Theme.gameLocale))
                            + "%"
                    )
                    StorefrontStat(
                        label: "Buzz",
                        value: progress.hype
                            .formatted(.number.precision(.fractionLength(0)).locale(Theme.gameLocale))
                    )
                }
                TriPhaseProgress(progress: progress, type: type, compact: true)
            }
        }
    }
}

// MARK: K2 (product lifecycle) — the buy button's old sheet, a free
// picker, is `LifecyclePriceSheet` now (Screens/Products/Lifecycle).
// MARK: end K2

// MARK: - Art seed

extension UUID {
    /// The seed a product's generated art is drawn from — box art and now
    /// the screenshots. Deliberately the same expression `LaunchDaySheet`
    /// already uses, so the box on launch day and the box in the store are
    /// the same box.
    var artSeed: UInt64 {
        uuidString.utf8.reduce(UInt64(0)) { $0 &* 31 &+ UInt64($1) }
    }
}
