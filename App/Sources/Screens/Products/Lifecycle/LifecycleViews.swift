import SwiftUI
import TycoonContent
import TycoonEngine

// MARK: K2 (product lifecycle)

/// Iteration 15 — K2 (C1). The product page's lifecycle card: build its v2,
/// or retire it, each with what it costs printed under the button. A
/// retired product says when; a successor names what it replaced.
struct LifecycleCard: View {
    let engine: GameEngine
    let product: Product
    let info: ReleaseInfo

    @State private var retiring = false
    @State private var buildingSuccessor = false

    private var state: GameState { engine.state }
    private var topicName: String { engine.content.topic(product.topicID)?.name ?? product.topicID }

    var body: some View {
        CardView("Lifecycle", systemImage: "arrow.triangle.2.circlepath.circle.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                ForEach(history, id: \.self) { line in
                    Text(line)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button { buildingSuccessor = true } label: {
                    LifecycleRowLabel(
                        title: "Build its v2", icon: "hammer.fill",
                        detail: successorDetail, tint: state.hasFreeDevSlot ? .secondary : Theme.warning
                    )
                }
                .buttonStyle(.pressableRow)
                .disabled(!state.hasFreeDevSlot)
                if !info.offMarket {
                    Button { retiring = true } label: {
                        LifecycleRowLabel(
                            title: "Retire \(product.name)", icon: "archivebox.fill",
                            detail: retireDetail, tint: .secondary
                        )
                    }
                    .buttonStyle(.pressableRow)
                }
            }
        }
        .sheet(isPresented: $buildingSuccessor) {
            NewProductFlow(engine: engine, successorOf: product.id)
        }
        .sheet(isPresented: $retiring) {
            LifecycleRetireSheet(engine: engine, productID: product.id)
        }
        .onAppear {
            #if DEBUG
            if LifecycleDebug.consume(.retire) { retiring = true }
            if LifecycleDebug.consume(.buildV2) { buildingSuccessor = true }
            #endif
        }
    }

    private var history: [String] {
        var lines: [String] = []
        if let parentID = product.parentID, let parent = state.product(id: parentID) {
            // MARK: T2 (the build) — a declared v2 shipped beside its
            // parent retired nothing.
            lines.append(LifecycleShip.replaced(parent: parent, by: product)
                ? "The v2 of \(parent.name), which it retired the day it shipped."
                : "The v2 of \(parent.name), shipped beside it.")
            // MARK: end T2
        }
        if let sunset = info.sunsetDay {
            // T2: only a successor that retired it on its launch day
            // replaced it; a v2 that ran beside it did not.
            let successor = state.products.first {
                $0.parentID == product.id && LifecycleShip.replaced(parent: product, by: $0)
            }
            lines.append(successor.map { "Replaced by \($0.name) on \(GameCalendar(day: sunset).longLabel)." }
                ?? "Discontinued on \(GameCalendar(day: sunset).longLabel).")
        }
        // MARK: T2 (the build) — J4: why the old version's line is falling.
        if let line = BuildCopy.oldVersionLine(product: product, state: state, balance: engine.balance) {
            lines.append(line)
        }
        // MARK: end T2
        return lines
    }

    private var successorDetail: String {
        guard state.hasFreeDevSlot else { return "No build slot free — a v2 takes one like any build." }
        let carry = state.lifecycleCarry(from: product.id, balance: engine.balance)
        let replace: String
        if info.offMarket {
            replace = "Nothing to carry from a product off the market"
        } else if let carry, carry.isSubscription {
            replace = "ship it as a replacement and \(carry.subscribers) of \(carry.parentSubscribers) subscribers carry"
        } else {
            replace = "ship it as a replacement and it skips the saturation this one would add"
        }
        let base = state.availableCodebases(typeID: product.typeID).isEmpty ? "" : " on its codebase"
        return "Same type, same topic\(base); \(replace)."
    }

    private var retireDetail: String {
        let hosting = state.lifecycleWeeklyHosting(productID: product.id, balance: engine.balance, content: engine.content)
        var parts = ["Saves \(hosting.money)/wk"]
        if info.isSubscription { parts.append("\(info.subscribers) subscribers leave") }
        parts.append(state.lifecycleTopicStillHeld(without: product.id)
            ? "\(topicName) is still held"
            : "\(topicName) standing fades \(standingDecay) a week")
        return parts.joined(separator: " · ")
    }

    private var standingDecay: String {
        engine.balance.market.standing.decayWeeklyLoss
            .formatted(.number.precision(.fractionLength(0...1)).locale(Theme.gameLocale))
    }
}

/// One lifecycle row: the verb, and what it costs under it.
struct LifecycleRowLabel: View {
    let title: String
    let icon: String
    let detail: String
    let tint: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(tint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// The retirement, on pixel paper: what stops, what leaves, what the topic
/// loses — then *Retire it* with the saving on it, or keep selling.
struct LifecycleRetireSheet: View {
    let engine: GameEngine
    let productID: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(GameShell.self) private var injectedShell: GameShell?
    private var shell: GameShell { injectedShell ?? .shared }

    private var state: GameState { engine.state }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    if let product = state.product(id: productID), let info = product.releaseInfo {
                        notice(product, info)
                        choices(product, info)
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle("Retire it")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not yet") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func notice(_ product: Product, _ info: ReleaseInfo) -> some View {
        let topic = engine.content.topic(product.topicID)?.name ?? product.topicID
        let hosting = state.lifecycleWeeklyHosting(productID: productID, balance: engine.balance, content: engine.content)
        let lastWeek = info.weeklySales.last?.revenue ?? 0
        let held = state.lifecycleTopicStillHeld(without: productID)
        let lines: [(String, String, Color)] = [
            ("server.rack", "Hosting and support stop: \(hosting.money) a week back.", Theme.positiveCash),
            ("chart.line.downtrend.xyaxis", "Sales stop: it made \(lastWeek.money) last week.", Theme.warning),
            info.isSubscription
                ? ("person.2.slash", "\(info.subscribers) subscriber\(info.subscribers == 1 ? "" : "s") get a polite email and leave.", Theme.warning)
                : ("shippingbox", "The store page stays up and says Discontinued.", Theme.pixelAccent),
            held
                ? ("flag.fill", "Something else still sells in \(topic), so its standing keeps its retainer.", Theme.pixelAccent)
                : ("flag.slash.fill", "Nothing else sells in \(topic): its standing fades \(Int(engine.balance.market.standing.decayWeeklyLoss.rounded(.up))) a week from here.", Theme.warning),
            ("arrow.triangle.2.circlepath", "A v2 shipped as its replacement would have carried \(Int((engine.balance.lifecycle.successorBookCarry * 100).rounded()))% of the book instead.", Theme.pixelAccent),
        ]
        return PixelPanel(contentPadding: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                PixelSectionTitle(title: "Discontinuation notice")
                PixelText(text: product.name, scale: 3, color: Theme.pixelInk, shadow: true)
                Divider().overlay(Theme.pixelInk.opacity(0.3))
                ForEach(lines, id: \.1) { line in
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                        Image(systemName: line.0)
                            .font(.caption)
                            .foregroundStyle(line.2)
                            .frame(width: 18)
                            .accessibilityHidden(true)
                        Text(line.1)
                            .font(.footnote)
                            .monospacedDigit()
                            .foregroundStyle(Theme.pixelInk.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func choices(_ product: Product, _ info: ReleaseInfo) -> some View {
        let hosting = state.lifecycleWeeklyHosting(productID: productID, balance: engine.balance, content: engine.content)
        if let refusal = state.lifecycleSunsetRefusal(productID: productID) {
            Text(refusal.sentence)
                .font(.callout)
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: Theme.Spacing.sm) {
                Button {
                    shell.toasts.send(
                        .sunsetProduct(productID: productID),
                        to: engine,
                        rejected: state.lifecycleSunsetRefusal(productID: productID)?.sentence
                            ?? "It is not on the market."
                    )
                    dismiss()
                } label: {
                    LifecycleRowLabel(
                        title: "Retire it · saves \(hosting.money)/wk",
                        icon: "archivebox.fill",
                        detail: info.isSubscription
                            ? "\(info.subscribers) subscribers leave today"
                            : "Off the shelf today",
                        tint: Theme.warning
                    )
                }
                .buttonStyle(.pressableRow)
                Button { dismiss() } label: {
                    LifecycleRowLabel(
                        title: "Keep selling it",
                        icon: "cart.fill",
                        detail: "It holds the topic and keeps counting for the awards, for \(hosting.money) a week.",
                        tint: .secondary
                    )
                }
                .buttonStyle(.pressableRow)
            }
        }
    }
}

/// The new-product flow's "v2 of…" entry: every released product, newest
/// first, as a chip that pre-fills type, topic, codebase and name.
struct LifecycleSequelRow: View {
    let engine: GameEngine
    let pick: (Product) -> Void

    private var released: [Product] {
        engine.state.products
            .filter { $0.releaseInfo != nil }
            .sorted { ($0.releaseInfo?.launchDay ?? 0) > ($1.releaseInfo?.launchDay ?? 0) }
            .prefix(6)
            .map { $0 }
    }

    var body: some View {
        if !released.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Or a v2 of…")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(released) { product in
                            Button { pick(product) } label: {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(product.name)
                                        .font(.footnote.weight(.semibold))
                                    Text(chipDetail(product))
                                        .font(.caption2)
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.sm)
                                .background(Theme.chipBackground, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Start the v2 of \(product.name)")
                        }
                    }
                }
            }
            .padding(.bottom, Theme.Spacing.md)
        }
    }

    private func chipDetail(_ product: Product) -> String {
        guard let info = product.releaseInfo else { return "" }
        if info.offMarket { return info.sunsetDay != nil ? "Discontinued" : "Off the market" }
        return info.isSubscription ? "\(info.subscribers) subscribers" : "Review \(info.averageReviewScore)"
    }
}

/// Launch day for a successor: what it replaced and what came across.
struct LifecycleLaunchRow: View {
    let engine: GameEngine
    let product: Product
    let parentID: UUID

    var body: some View {
        // MARK: T2 (the build) — a declared v2 shipped beside its parent
        // replaced nothing; its launch day says what running both costs.
        if let parent = engine.state.product(id: parentID), !LifecycleShip.replaced(parent: parent, by: product) {
            BesideParentLaunchRow(engine: engine, product: product, parent: parent)
        } else {
            replacesCard
        }
        // MARK: end T2
    }

    private var replacesCard: some View {
        let parentName = engine.state.product(id: parentID)?.name ?? "the old one"
        let carried = product.releaseInfo?.subscribers ?? 0
        return CardView("Replaces \(parentName)", systemImage: "arrow.triangle.2.circlepath.circle.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(product.releaseInfo?.isSubscription == true
                     ? "\(carried) subscriber\(carried == 1 ? "" : "s") came across on day one."
                     : "It opens with the old one's buzz, and the old one is off the shelf.")
                    .font(.subheadline)
                    .monospacedDigit()
                Text("\(parentName) is discontinued, and this launch skipped the saturation it would have added.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// The ship confirmation's third answer: one button per product the build
/// can replace, with what carries printed on it.
enum LifecycleShip {
    static func replaceLabel(parent: Product, state: GameState, balance: BalanceConfig) -> String {
        guard let carry = state.lifecycleCarry(from: parent.id, balance: balance) else {
            return "Replace \(parent.name)"
        }
        return carry.isSubscription
            ? "Replace \(parent.name) · \(carry.subscribers) subscribers carry"
            : "Replace \(parent.name) · it retires today"
    }

    // MARK: T2 (the build)
    /// Whether `child` replaced `parent` (`shipReplacing` retires the
    /// parent on the successor's launch day) rather than being a v2
    /// declared on it and shipped beside it.
    static func replaced(parent: Product, by child: Product) -> Bool {
        guard let sunset = parent.releaseInfo?.sunsetDay, let launch = child.releaseInfo?.launchDay else {
            return false
        }
        return sunset == launch
    }
    // MARK: end T2

    /// The sentence the dialog's message gains when a replacement is on
    /// offer.
    static func replaceMessage(for productID: UUID, state: GameState) -> String? {
        guard let parent = state.lifecycleReplaceableParents(for: productID).first else { return nil }
        return " Or ship it as the v2 of \(parent.name): the old one retires today, its book carries over and this launch skips its saturation. Running both keeps both books and both bills."
    }
}

/// The price-change line in the journal, the toasts and the paper.
enum LifecycleEventLine {
    static func priceMoved(
        name: String, from: PriceTier, to: PriceTier, subscribersLost: Int, sale: Bool, day: Int
    ) -> (icon: String, message: String, day: Int, tint: Color) {
        let ladder = PriceTier.allCases
        let rise = (ladder.firstIndex(of: to) ?? 0) > (ladder.firstIndex(of: from) ?? 0)
        if rise {
            return (
                "arrow.up.right.circle.fill",
                subscribersLost > 0
                    ? "\(name) went up to \(to.displayName). \(subscribersLost) subscriber\(subscribersLost == 1 ? "" : "s") left over it"
                    : "\(name) went up to \(to.displayName). Buyers are waiting for the sale",
                day,
                Theme.warning
            )
        }
        if sale {
            return ("tag.fill", "\(name) is on sale at \(to.displayName) this week. The trade noticed", day, Theme.positiveCash)
        }
        return ("tag.fill", "\(name) dropped to \(to.displayName) pricing", day, Theme.accent)
    }
}

// MARK: end K2
