import SwiftUI
import TycoonEngine

/// When the war room is offered, and for which build.
///
/// The room is never forced: the build card and the Now card *offer* it
/// once a build is inside the last week before its ETA, and again on
/// launch day, and the player can open it for any build they want to
/// watch. This is the one place that window is defined.
@MainActor
enum WarRoomOffer {
    /// How many days before the ETA the room starts being offered.
    static let windowDays = 7

    /// Days until `product` is done, at today's crew and focus. `nil` when
    /// it is not in development or nothing is moving on it.
    static func daysOut(for product: Product, engine: GameEngine) -> Int? {
        engine.state.buildETA(productID: product.id, balance: engine.balance, content: engine.content)?
            .daysToComplete
    }

    /// Whether `product` shipped today — the room's launch-day mode.
    static func isLaunchDay(for product: Product, state: GameState) -> Bool {
        if case .released(let info) = product.stage { return info.launchDay == state.day }
        return false
    }

    /// Whether the room is offered for `product` right now: inside the
    /// window before its ETA, or on its launch day.
    static func isOffered(for product: Product, engine: GameEngine) -> Bool {
        if isLaunchDay(for: product, state: engine.state) { return true }
        guard let days = daysOut(for: product, engine: engine) else { return false }
        return days <= windowDays
    }

    /// The build the `.warRoom` route opens when it names none: whatever
    /// shipped today, else the build closest to its ETA, else the first
    /// build in development — any build the player chooses to watch.
    static func candidate(in engine: GameEngine) -> Product? {
        let state = engine.state
        if let launched = state.products.first(where: { isLaunchDay(for: $0, state: state) }) {
            return launched
        }
        let building = state.productsInDevelopment
        let dated = building.compactMap { product -> (Product, Int)? in
            daysOut(for: product, engine: engine).map { (product, $0) }
        }
        return dated.min { $0.1 < $1.1 }?.0 ?? building.first
    }
}

/// What the Products tab presents the room for: the engine the room runs
/// on and the build it watches. Identified by the product so a second
/// request for the same build does not re-present.
@MainActor
struct WarRoomRequest: Identifiable {
    let engine: GameEngine
    let productID: UUID

    nonisolated var id: UUID { productID }

    /// The room for the build the route implies, if there is one.
    static func offered(by engine: GameEngine) -> WarRoomRequest? {
        WarRoomOffer.candidate(in: engine).map { WarRoomRequest(engine: engine, productID: $0.id) }
    }
}

// MARK: - Entry points

/// "Go to the war room", on the build card once the build is inside the
/// window. Owns its own presentation so the card's diff is one line.
struct WarRoomEntryButton: View {
    let engine: GameEngine
    let product: Product

    @State private var request: WarRoomRequest?

    var body: some View {
        if WarRoomOffer.isOffered(for: product, engine: engine) {
            Button {
                Haptics.tap()
                Sounds.play(.tap)
                request = WarRoomRequest(engine: engine, productID: product.id)
            } label: {
                Label(label, systemImage: "flag.checkered")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.xs)
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent)
            .accessibilityLabel("Go to the war room for \(product.name)")
            .accessibilityHint(hint)
            .fullScreenCover(item: $request) { request in
                WarRoomScreen(engine: request.engine, productID: request.productID)
            }
        }
    }

    private var label: String {
        if WarRoomOffer.isLaunchDay(for: product, state: engine.state) { return "Launch day — go to the war room" }
        return "Go to the war room"
    }

    private var hint: String {
        guard let days = WarRoomOffer.daysOut(for: product, engine: engine) else {
            return "Opens the launch week room"
        }
        return days == 0 ? "The build is done" : "\(days) day\(days == 1 ? "" : "s") to the build's ETA"
    }
}

/// The Now card's row: the launch week, one tap from HQ. Renders nothing
/// until a build is inside the window, so the card reads as it always did
/// for the other fifty weeks of the year.
struct WarRoomOfferRow: View {
    let engine: GameEngine

    @Environment(AppRouter.self) private var router

    var body: some View {
        if let product = WarRoomOffer.candidate(in: engine),
           WarRoomOffer.isOffered(for: product, engine: engine) {
            Button {
                Haptics.tap()
                Sounds.play(.tap)
                router.go(.warRoom)
            } label: {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "flag.checkered")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title(for: product))
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Go to the war room")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: Theme.Spacing.sm)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressableRow)
            .accessibilityLabel("\(title(for: product)). Go to the war room")
            .accessibilityHint("Opens the launch week room on the Products tab")
        }
    }

    private func title(for product: Product) -> String {
        if WarRoomOffer.isLaunchDay(for: product, state: engine.state) {
            return "\(product.name) ships today"
        }
        switch WarRoomOffer.daysOut(for: product, engine: engine) {
        case .some(0): return "\(product.name) is done"
        case .some(1): return "\(product.name) is a day out"
        case .some(let days): return "\(product.name) is \(days) days out"
        case nil: return "\(product.name) is in launch week"
        }
    }
}
