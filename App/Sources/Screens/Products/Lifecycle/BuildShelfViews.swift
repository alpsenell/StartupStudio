import SwiftUI
import TycoonContent
import TycoonEngine

// MARK: T2 (the build)

/// Iteration 17 — T2. The build's two ways out that are not shipping —
/// *Shelve it* (systems O3) and *Scrap it* (player P2) — on the build's
/// page, the drawer on the Products list, and the declared v2's lines.
/// Every number is the engine's (`GameState.buildShelveQuote`,
/// `buildScrapQuote`, `buildRunBothQuote`, `buildParentDecay`).
enum BuildCopy {
    /// Everything the shelve does, on its button.
    static func shelve(_ quote: BuildShelveQuote) -> String {
        var parts = ["Frees a slot today"]
        parts.append(quote.hype >= 1 ? "hype \(Int(quote.hype.rounded())) → 0" : "no hype to lose")
        if quote.slipsDate {
            let reputation = Int(quote.slipReputation.rounded())
            parts.append(quote.voidsDate
                ? "the announced date is void (−\(reputation) reputation)"
                : "the announced date slips (−\(reputation) reputation)")
        }
        parts.append(quote.crew > 0
            ? "\(quote.crew) idle, morale \(Int(quote.crewMorale.rounded()))"
            : "nobody on it")
        let keeps = Int((quote.completion * 100).rounded())
        let decay = Int((quote.completion * quote.decayPerQuarter * 100).rounded())
        parts.append("\(keeps)% keeps, −\(decay)% a quarter")
        return parts.joined(separator: " · ")
    }

    /// Everything the scrap does, on its button.
    static func scrap(_ quote: BuildScrapQuote, typeName: String) -> String {
        var parts: [String] = []
        let banked = Int(quote.banked.rounded())
        if banked > 0 {
            parts.append(quote.codebaseName.map { "Banks \(banked) points into the \($0) codebase" }
                ?? "Founds a \(typeName.lowercased()) codebase with \(banked) points")
        } else {
            parts.append("Banks nothing: the \(quote.codebaseName ?? typeName) codebase already holds more")
        }
        if quote.crew > 0 {
            parts.append("\(quote.crew) idle, morale \(Int(quote.crewMorale.rounded()))")
        }
        parts.append("no review, no sales, gone for good")
        return parts.joined(separator: " · ")
    }

    /// J4: the plain ship's cost to a live parent.
    static func runBoth(_ quote: BuildRunBothQuote) -> String {
        quote.isSubscription
            ? "Running both: \(quote.parentName) keeps its \(quote.parentSubscribers) subscribers and its bill, and loses about \(quote.weeklyLoss) a week to its v2."
            : "Running both: \(quote.parentName) stays on the shelf with its bill, and sells about \(quote.weeklyLoss) fewer a week beside its v2."
    }

    /// J4: why a parent's line is falling, for its lifecycle card.
    static func oldVersionLine(product: Product, state: GameState, balance: BalanceConfig) -> String? {
        let decay = state.buildParentDecay(productID: product.id, balance: balance)
        guard decay.acquisition != 1 || decay.churn != 1,
              let v2 = state.products.first(where: { other in
                  guard other.parentID == product.id, let info = other.releaseInfo else { return false }
                  return !info.offMarket
              }),
              let info = product.releaseInfo
        else { return nil }
        let share = Int((decay.acquisition * 100).rounded())
        return info.isSubscription
            ? "The old version: \(v2.name) sells beside it, so it signs \(share)% of the subscribers it would and churns ×\(multiple(decay.churn))."
            : "The old version: \(v2.name) sells beside it, so it sells \(share)% of what it would."
    }

    private static func multiple(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)).locale(Theme.gameLocale))
    }
}

/// The build page's card: shelve it or scrap it, each with everything it
/// does printed under it, and a confirmation that repeats it.
struct BuildWayOutCard: View {
    let engine: GameEngine
    let product: Product

    private enum Answer: Identifiable {
        case shelve, scrap
        var id: Self { self }
    }

    @State private var confirming: Answer?
    @Environment(\.dismiss) private var dismiss
    @Environment(GameShell.self) private var injectedShell: GameShell?
    private var shell: GameShell { injectedShell ?? .shared }

    private var state: GameState { engine.state }
    private var typeName: String { engine.content.productType(product.typeID)?.name ?? product.typeID }
    private var shelveQuote: BuildShelveQuote? {
        state.buildShelveQuote(productID: product.id, balance: engine.balance, content: engine.content)
    }
    private var scrapRefusal: BuildRefusal? {
        state.buildScrapRefusal(productID: product.id, balance: engine.balance, content: engine.content)
    }
    private var scrapDetail: String {
        if let scrapRefusal { return scrapRefusal.sentence }
        return state.buildScrapQuote(productID: product.id, balance: engine.balance, content: engine.content)
            .map { BuildCopy.scrap($0, typeName: typeName) } ?? ""
    }

    var body: some View {
        CardView("Not shipping it", systemImage: "archivebox.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("Two ways to stop. The shelf keeps the build for later; the scrap keeps what the team learned.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button { confirming = .shelve } label: {
                    LifecycleRowLabel(
                        title: "Shelve it", icon: "archivebox.fill",
                        detail: shelveQuote.map(BuildCopy.shelve) ?? "", tint: .secondary
                    )
                }
                .buttonStyle(.pressableRow)
                Button { confirming = .scrap } label: {
                    LifecycleRowLabel(
                        title: "Scrap it", icon: "trash.fill",
                        detail: scrapDetail, tint: scrapRefusal == nil ? .secondary : Theme.warning
                    )
                }
                .buttonStyle(.pressableRow)
                .disabled(scrapRefusal != nil)
                .opacity(scrapRefusal == nil ? 1 : 0.6)
            }
        }
        .confirmationDialog(
            confirming == .scrap ? "Scrap \(product.name)?" : "Shelve \(product.name)?",
            isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }),
            titleVisibility: .visible,
            presenting: confirming
        ) { answer in
            switch answer {
            case .shelve:
                Button("Shelve it") { act(.shelveBuild(productID: product.id), rejected: state.buildShelveRefusal(productID: product.id)?.sentence) }
            case .scrap:
                Button("Scrap it", role: .destructive) { act(.scrapBuild(productID: product.id), rejected: scrapRefusal?.sentence) }
            }
            Button("Keep building", role: .cancel) {}
        } message: { answer in
            switch answer {
            case .shelve: Text((shelveQuote.map(BuildCopy.shelve) ?? "") + ". Take it off the shelf into any free slot.")
            case .scrap: Text(scrapDetail + ".")
            }
        }
    }

    private func act(_ action: GameAction, rejected: String?) {
        let events = shell.toasts.send(action, to: engine, rejected: rejected ?? "Nothing changed.")
        // The build has left the page's product list: go back to where the
        // player came from rather than sit on "Product not found".
        if !events.isEmpty { dismiss() }
    }
}

/// The drawer, on the Products list: every shelved build with its two
/// ways back out. Nothing while the shelf is empty.
struct ShelfCard: View {
    let engine: GameEngine

    var body: some View {
        if !engine.state.shelf.isEmpty {
            CardView("On the shelf", systemImage: "archivebox.fill") {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    ForEach(engine.state.shelf) { product in
                        ShelfRow(engine: engine, product: product)
                    }
                }
            }
        }
    }
}

private struct ShelfRow: View {
    let engine: GameEngine
    let product: Product

    @State private var confirmingScrap = false
    @Environment(GameShell.self) private var injectedShell: GameShell?
    private var shell: GameShell { injectedShell ?? .shared }

    private var state: GameState { engine.state }
    private var type: ProductTypeDef? { engine.content.productType(product.typeID) }
    private var unshelveRefusal: BuildRefusal? { state.buildUnshelveRefusal(productID: product.id) }
    private var scrapDetail: String {
        state.buildScrapQuote(productID: product.id, balance: engine.balance, content: engine.content)
            .map { BuildCopy.scrap($0, typeName: type?.name ?? product.typeID) } ?? ""
    }

    private var summary: String {
        guard case .development(let dev) = product.stage, let type else { return "" }
        let percent = Int((dev.completion(of: type) * 100).rounded())
        let weekly = dev.completion(of: type) * engine.balance.build.shelveDecayPerQuarter / 13 * 100
        let since = dev.shelvedDay.map { state.day - $0 } ?? 0
        let when = since < 1 ? "shelved today" : since < 14 ? "shelved \(since) day\(since == 1 ? "" : "s") ago" : "shelved \(since / 7) weeks ago"
        return "\(type.name) · \(percent)% done · \(when) · losing about \(weekly.formatted(.number.precision(.fractionLength(0...1)).locale(Theme.gameLocale)))% a week"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(.system(.headline, design: .rounded))
                Text(summary)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                shell.toasts.send(
                    .unshelveBuild(productID: product.id), to: engine,
                    rejected: unshelveRefusal?.sentence ?? "It stayed on the shelf."
                )
            } label: {
                LifecycleRowLabel(
                    title: "Take it off the shelf", icon: "tray.and.arrow.up.fill",
                    detail: unshelveRefusal?.sentence ?? "Into a free slot today · everyone idle joins it",
                    tint: unshelveRefusal == nil ? .secondary : Theme.warning
                )
            }
            .buttonStyle(.pressableRow)
            .disabled(unshelveRefusal != nil)
            .opacity(unshelveRefusal == nil ? 1 : 0.6)
            Button { confirmingScrap = true } label: {
                LifecycleRowLabel(title: "Scrap it", icon: "trash.fill", detail: scrapDetail, tint: .secondary)
            }
            .buttonStyle(.pressableRow)
        }
        .confirmationDialog("Scrap \(product.name)?", isPresented: $confirmingScrap, titleVisibility: .visible) {
            Button("Scrap it", role: .destructive) {
                shell.toasts.send(.scrapBuild(productID: product.id), to: engine, rejected: "It stayed on the shelf.")
            }
            Button("Keep it on the shelf", role: .cancel) {}
        } message: {
            Text(scrapDetail + ".")
        }
    }
}

/// Launch day for a declared v2 shipped beside its parent (K2's row says
/// "Replaces" only when it did).
struct BesideParentLaunchRow: View {
    let engine: GameEngine
    let product: Product
    let parent: Product

    var body: some View {
        let decay = engine.state.buildParentDecay(productID: parent.id, balance: engine.balance)
        CardView("Beside \(parent.name)", systemImage: "arrow.triangle.branch") {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(parent.releaseInfo?.isSubscription == true
                     ? "\(parent.name) is the old version now: while this one sells it signs \(Int((decay.acquisition * 100).rounded()))% of the subscribers it would, and its book churns faster."
                     : "\(parent.name) is the old version now: while this one sells it sells \(Int((decay.acquisition * 100).rounded()))% of what it would.")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Both books, both bills. Retire \(parent.name) from its page once its customers have walked over.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Debug

/// The headless screenshot pass's hands, for `-autoTab products -autoRoute
/// t2-<scenario>` on the studio fixture. The save is dressed through
/// `.buildDebugSeed` and the ordinary actions.
///
/// Scenarios: `t2-ship` (the ship sheet on a build past the gate),
/// `t2-card` (the build page's shelve/scrap card), `t2-shelf` (a build on
/// the shelf, the Products list), `t2-v2` (the ship sheet of a declared v2
/// of Round 6: the run-both line), `t2-parent` (Round 6's lifecycle card
/// after its v2 shipped beside it), `t2-launch` (that launch day). DEBUG
/// only; inert without the flag.
@MainActor
enum BuildDebug {
    enum Surface { case shipSheet, card, parentCard }

    private static var pending: Surface?

    static func consume(_ surface: Surface) -> Bool {
        guard pending == surface else { return false }
        pending = nil
        return true
    }

    static func peek(_ surface: Surface) -> Bool { pending == surface }

    fileprivate static func want(_ surface: Surface) { pending = surface }
}

private struct BuildAutoRoute: ViewModifier {
    let engine: GameEngine
    let router: AppRouter

    func body(content: Content) -> some View {
        content.task {
            #if DEBUG
            guard let scenario = DebugLaunch.buildScenario else { return }
            await run(scenario)
            #endif
        }
    }

    #if DEBUG
    private func beat(_ seconds: Double = 1) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    private func run(_ scenario: String) async {
        for _ in 0..<20 where engine.state.products.isEmpty { await beat() }
        await beat(2)
        // Keep the studio out of the bankruptcy warning, which pauses the
        // clock and takes the screen to HQ (K2's seed).
        engine.send(.lifecycleDebug(scenario: "solvent"))
        switch scenario {
        case "ship", "card":
            engine.send(.buildDebugSeed(scenario: "ready"))
            guard let build = engine.state.productsInDevelopment.first else { return }
            BuildDebug.want(scenario == "ship" ? .shipSheet : .card)
            router.go(.product(build.id))
        case "shelf":
            engine.send(.buildDebugSeed(scenario: "shelve"))
        case "v2":
            engine.send(.buildDebugSeed(scenario: "v2"))
            guard let build = engine.state.products.last, build.parentID != nil else { return }
            BuildDebug.want(.shipSheet)
            router.go(.product(build.id))
        case "parent", "launch":
            engine.send(.buildDebugSeed(scenario: "v2shipped"))
            guard let build = engine.state.products.last, let parentID = build.parentID else { return }
            if scenario == "launch" {
                await beat()
                GameShell.shared.launchDayProductID = build.id
            } else {
                BuildDebug.want(.parentCard)
                router.go(.product(parentID))
            }
        default:
            break
        }
    }
    #endif
}

extension View {
    /// One line in `ProductsScreen`; everything the flag does lives here.
    func buildAutoRoute(engine: GameEngine, router: AppRouter) -> some View {
        modifier(BuildAutoRoute(engine: engine, router: router))
    }
}

// MARK: end T2
