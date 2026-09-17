import SwiftUI
import TycoonEngine

// MARK: Iteration 18 — the launch card

/// One launch, as a card: the box art large, the studio's name and mark,
/// the outlets' verdicts, a line from the press, the first week's numbers
/// and the code that founds the same company on somebody else's phone.
///
/// No engine change and no new state — everything here is read off the
/// product and the run, which is why a card can be minted for a launch
/// from four hundred days ago as readily as for the one that shipped this
/// morning.
///
/// **It renders disasters proudly.** A launch that landed under
/// `LaunchCard.proudBelow` does not hide: it leads with the *cruelest*
/// line any outlet wrote rather than the kindest, prints the verdict in
/// the failure ink, and — when pre-orders were sold on a forecast the
/// reviews did not keep — stamps OVERPROMISED across the top. A brag
/// button is used once; a card that is funny about a 31 is used every
/// time, which is the whole reason this exists.
struct LaunchCardView: View {
    let engine: GameEngine
    let product: Product

    private var state: GameState { engine.state }

    private var release: ReleaseInfo? {
        if case .released(let info) = product.stage { return info }
        return nil
    }

    private var seedCode: SeedCode {
        SeedCode(seed: state.seed, origin: state.origin, difficulty: state.difficulty)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                if let release {
                    header(release)
                    // T5: the pre-orders were sold on a promise the
                    // reviews did not keep. Loudly.
                    if product.preordersOverpromised {
                        overpromised
                    }
                    ShareRule()
                    scores(release)
                    // The line from the press sits in the middle of the
                    // card with air around it, so a card with one short
                    // sentence on it does not read as a card with a hole.
                    Spacer(minLength: 0)
                    quote(release)
                    Spacer(minLength: 0)
                    ShareRule(color: ShareInk.ink.opacity(0.35), height: 1)
                    firstWeek(release)
                } else {
                    unreleased
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            ShareFooter(line: footerLine, code: seedCode)
        }
        .background(ShareInk.paper)
        .overlay {
            PixelPanelBorder(thickness: 6, corner: 6)
                .fill(ShareInk.ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLine)
    }

    // MARK: - The head

    private func header(_ release: ReleaseInfo) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.lg) {
            ProductBoxArtView(
                typeID: product.typeID,
                topicID: product.topicID,
                seed: product.boxArtSeed,
                size: 132,
                markSeed: state.company.markSeed
            )
            .shadow(color: ShareInk.ink.opacity(0.25), radius: 0, x: 4, y: 4)
            VStack(alignment: .leading, spacing: 6) {
                PixelText(text: LaunchCard.kicker, scale: 2, color: ShareInk.accent)
                Text(product.name)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(ShareInk.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Theme.Spacing.sm) {
                    StudioMarkStamp(state: state, size: 20)
                    Text(state.company.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(ShareInk.ink.opacity(0.75))
                        .lineLimit(1)
                }
                Text(categoryLine)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(ShareInk.faint)
                    .lineLimit(1)
                Text("Shipped \(GameCalendar(day: release.launchDay).longLabel)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ShareInk.faint)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    /// T5: sold on a forecast the build did not reach.
    private var overpromised: some View {
        HStack(spacing: Theme.Spacing.sm) {
            PixelText(text: LaunchCard.overpromisedStamp, scale: 3, color: ShareInk.paper)
            Spacer(minLength: 0)
            Text(overpromisedLine)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(ShareInk.paper.opacity(0.9))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(ShareInk.failure)
    }

    private var overpromisedLine: String {
        guard let book = product.preorders else { return "" }
        return "\(book.outstanding.formatted(.number.locale(Theme.gameLocale))) pre-orders "
            + "were sold on a \(Int(book.forecastQuality.rounded()))."
    }

    // MARK: - The verdicts

    /// The four outlets' scores, with the average stamped beside them —
    /// or, under an exclusive's embargo, the one verdict that is out and
    /// three chips holding the rest back (T7).
    private func scores(_ release: ReleaseInfo) -> some View {
        let visible = release.visibleReviews(on: state.day)
        let held = release.embargoedOutlets(on: state.day)
        let average = release.visibleAverageScore(on: state.day)
        // Through a value rather than a literal: `StringsAuditTests` pins
        // how many bare string literals reach the bitmap face, and a
        // number has no business in a string catalog.
        let averageText = average.formatted(.number.locale(Theme.gameLocale))
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: 0) {
                    PixelText(text: verdictHeading(held: held), scale: 2, color: ShareInk.accent)
                    PixelText(text: averageText, scale: 7, color: verdictTint(average))
                }
                Spacer(minLength: 0)
                Text(LaunchVerdict.text(for: average))
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(verdictTint(average))
            }
            FlowRow(spacing: 6) {
                ForEach(Array(visible.enumerated()), id: \.offset) { _, review in
                    outletChip(
                        outlet: review.outlet,
                        detail: "\(review.score)",
                        tint: verdictTint(review.score),
                        isExclusive: review.outlet == release.exclusiveOutlet
                    )
                }
                ForEach(Array(held.enumerated()), id: \.offset) { _, outlet in
                    outletChip(
                        outlet: outlet,
                        detail: String(localized: "embargoed", comment: "Launch card chip: an outlet whose verdict is still held back under an exclusive. One word, lowercase"),
                        tint: ShareInk.faint,
                        isExclusive: false
                    )
                }
            }
        }
    }

    private func verdictHeading(held: [String]) -> String {
        held.isEmpty
            ? String(localized: "THE VERDICT", comment: "Launch card heading over the average review score (bitmap face, A-Z only)")
            : String(localized: "THE ONE VERDICT OUT", comment: "Launch card heading over an exclusive's score while the other outlets are embargoed (bitmap face, A-Z only)")
    }

    private func outletChip(outlet: String, detail: String, tint: Color, isExclusive: Bool) -> some View {
        HStack(spacing: 5) {
            Text(outlet)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(ShareInk.ink.opacity(0.8))
            Text(detail)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
            if isExclusive {
                Text("EXCLUSIVE")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(ShareInk.accent)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(ShareInk.paperShade)
        .overlay {
            Rectangle().strokeBorder(ShareInk.ink.opacity(0.35), lineWidth: 1)
        }
    }

    // MARK: - The line from the press

    /// The kindest line for a launch that went well, the cruelest for one
    /// that did not — and the cruelest is the point.
    private func quote(_ release: ReleaseInfo) -> some View {
        let picked = LaunchCard.quote(release, on: state.day)
        let average = release.visibleAverageScore(on: state.day)
        return HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Rectangle()
                .fill(verdictTint(average).opacity(0.7))
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 4) {
                Text(picked.map { "“\($0.blurb)”" } ?? "The press has not filed yet.")
                    .font(.system(size: 19, weight: .regular, design: .serif).italic())
                    .foregroundStyle(ShareInk.ink)
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
                if let picked {
                    Text("— \(picked.outlet), \(picked.score)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(ShareInk.faint)
                }
            }
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - The first week

    private func firstWeek(_ release: ReleaseInfo) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.xl) {
            figure(
                label: String(localized: "First week", comment: "Launch card figure: units sold in the launch week"),
                value: firstWeekUnits
            )
            figure(
                label: String(localized: "Took", comment: "Launch card figure: cash the launch week brought in"),
                value: firstWeekCash,
                tint: ShareInk.success
            )
            if release.isSubscription {
                figure(
                    label: String(localized: "Subscribers", comment: "Launch card figure: paying subscribers on a subscription product"),
                    value: release.subscribers.formatted(.number.locale(Theme.gameLocale))
                )
            }
            Spacer(minLength: 0)
        }
    }

    private var firstWeekUnits: String {
        guard let week = release?.weeklySales.first else { return "—" }
        return week.units.formatted(.number.locale(Theme.gameLocale))
    }

    private var firstWeekCash: String {
        guard let week = release?.weeklySales.first else { return "—" }
        return week.revenue.money
    }

    private func figure(label: String, value: String, tint: Color = ShareInk.ink) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(ShareInk.faint)
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    // MARK: - The edges

    /// A build the player asked a card for before it shipped. It cannot
    /// happen from any of the three offers, but a card is a value and a
    /// value has to be total.
    private var unreleased: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            PixelText(text: LaunchCard.kicker, scale: 2, color: ShareInk.accent)
            Text(product.name)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(ShareInk.ink)
            Text("Still being built. Come back on launch day.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(ShareInk.faint)
        }
    }

    /// The pennant, when the run is staked (iteration 8's ladder), and the
    /// launch day otherwise.
    private var footerLine: String {
        state.rules.stake > 0
            ? "Stake \(state.rules.stake)"
            : "Day \(release?.launchDay ?? state.day)"
    }

    private var categoryLine: String {
        let type = engine.content.productType(product.typeID)?.name ?? product.typeID.capitalized
        guard let topic = engine.content.topic(product.topicID)?.name else { return type }
        return "\(type) · \(topic)"
    }

    private func verdictTint(_ score: Int) -> Color {
        score >= LaunchCard.proudBelow ? ShareInk.success : ShareInk.failure
    }

    private var accessibilityLine: String {
        guard let release else { return "Launch card: \(product.name), not shipped yet." }
        let average = release.visibleAverageScore(on: state.day)
        let quote = LaunchCard.quote(release, on: state.day)
        return "Launch card: \(product.name) by \(state.company.name), shipped day \(release.launchDay), "
            + "scored \(average). "
            + (product.preordersOverpromised ? "Overpromised: the pre-orders were sold on more. " : "")
            + (quote.map { "\($0.outlet): \($0.blurb) " } ?? "")
            + "First week \(firstWeekUnits) for \(firstWeekCash). Founded again with code \(seedCode.encoded)."
    }
}

/// The card's own decisions, apart from the view so they can be read (and
/// argued with) without a renderer.
enum LaunchCard {
    /// Under this score the card stops being proud and starts being funny:
    /// the failure ink, and the cruelest line the press wrote. 60 is where
    /// `LaunchVerdict` stops saying "Solid".
    static let proudBelow = 60

    static let kicker = String(
        localized: "LAUNCH DAY",
        comment: "Launch card kicker over the product's name (bitmap face, A-Z only)"
    )

    static let overpromisedStamp = String(
        localized: "OVERPROMISED",
        comment: "Launch card stamp when pre-orders were sold on a forecast the reviews did not keep (bitmap face, A-Z only)"
    )

    /// The line the card prints: the kindest verdict for a launch that
    /// went well, the cruelest for one that did not.
    ///
    /// Only reviews that are actually out are eligible, so a card minted
    /// during an exclusive's embargo quotes the outlet that had it and
    /// nobody else.
    static func quote(_ release: ReleaseInfo, on day: Int) -> Review? {
        let visible = release.visibleReviews(on: day)
        guard !visible.isEmpty else { return nil }
        let average = release.visibleAverageScore(on: day)
        return average >= proudBelow
            ? visible.max { $0.score < $1.score }
            : visible.min { $0.score < $1.score }
    }

    /// Whether a product can be made into a card at all: it has shipped.
    static func isAvailable(_ product: Product) -> Bool {
        if case .released = product.stage { return true }
        return false
    }
}

/// The one button that offers the card, wherever a launch is on screen:
/// the end of the review reveal, the war room's aftermath, and every
/// product's storefront page forever after.
///
/// Self-contained on purpose — it owns its own sheet state — so the three
/// hosts each add one line and nothing else.
struct LaunchCardButton: View {
    let engine: GameEngine
    let product: Product
    /// The bordered look for a row inside a card; the filled one for the
    /// end of a reveal, where it is the thing to do next.
    var prominent = false

    @State private var showing = false

    var body: some View {
        if LaunchCard.isAvailable(product) {
            Button {
                Haptics.tap()
                Sounds.play(.tap)
                showing = true
            } label: {
                Label("Make the launch card", systemImage: "square.and.arrow.up")
                    .font(.system(prominent ? .headline : .subheadline, design: .rounded).weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, prominent ? 0 : Theme.Spacing.xs)
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent)
            .accessibilityHint("Draws a shareable card for this launch: the box art, the scores, a line from the press and the code that founds this company again")
            .sheet(isPresented: $showing) {
                ShareCardSheet(card: .launch(engine: engine, product: product))
            }
        }
    }
}

// MARK: - The headless check

/// `-autoRoute i18-card-best` / `i18-card-worst`: opens the card over HQ
/// for the best or the worst launch in the loaded save, so the spec's own
/// check — *render it for the best and the worst launch of the release
/// fixtures; both must be legible and either funny or proud, never blank*
/// — can be run from the command line against a real fixture rather than
/// asserted in a test.
///
/// DEBUG only, and inert without the flag.
enum LaunchCardDebug {
    /// Which end of the shelf the flag asked for, or `nil`.
    static var request: Bool? {
        #if DEBUG
        switch DebugLaunch.autoRouteName ?? "" {
        case "i18-card-best": true
        case "i18-card-worst": false
        default: nil
        }
        #else
        nil
        #endif
    }

    /// `-autoMarkSeed <number>`: dresses the loaded save with a studio
    /// mark, so a marked card and a marked shelf can be photographed
    /// without a fixture being regenerated. Sent through the ordinary
    /// reducer; nothing in the game sends it.
    static var markSeed: UInt64? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-autoMarkSeed"),
              arguments.indices.contains(flag + 1)
        else { return nil }
        return UInt64(arguments[flag + 1])
        #else
        return nil
        #endif
    }

    /// The best (or worst) launch on the shelf, by average review score.
    static func product(in state: GameState, best: Bool) -> Product? {
        let released = state.products.filter { product in
            guard case .released(let info) = product.stage else { return false }
            return !info.reviews.isEmpty
        }
        func score(_ product: Product) -> Int {
            guard case .released(let info) = product.stage else { return 0 }
            return info.averageReviewScore
        }
        return best
            ? released.max { score($0) < score($1) }
            : released.min { score($0) < score($1) }
    }
}

private struct LaunchCardAutoRoute: ViewModifier {
    let engine: GameEngine

    @State private var product: Product?

    func body(content: Content) -> some View {
        content
            .task {
                #if DEBUG
                if let seed = LaunchCardDebug.markSeed, engine.state.company.markSeed == nil {
                    engine.send(.chooseStudioMark(seed: seed))
                }
                #endif
                guard let best = LaunchCardDebug.request else { return }
                // A beat, so the shell is up before a sheet goes over it —
                // the same rule the storefront pass follows.
                try? await Task.sleep(for: .seconds(1))
                product = LaunchCardDebug.product(in: engine.state, best: best)
            }
            .sheet(item: $product) { product in
                ShareCardSheet(card: .launch(engine: engine, product: product))
            }
    }
}

extension View {
    /// One line in `HQScreen`; everything the flag does lives here.
    func launchCardAutoRoute(engine: GameEngine) -> some View {
        modifier(LaunchCardAutoRoute(engine: engine))
    }
}

/// A row that wraps: the outlet chips, four across on a card this wide and
/// two rows on the accessibility sizes, without a fixed grid.
struct FlowRow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = arrange(subviews: subviews, width: width)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews: subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let next = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            if next > width, !row.indices.isEmpty {
                rows.append(row)
                row = Row()
                row.indices = [index]
                row.width = size.width
                row.height = size.height
            } else {
                row.indices.append(index)
                row.width = next
                row.height = max(row.height, size.height)
            }
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}

// MARK: end of Iteration 18
