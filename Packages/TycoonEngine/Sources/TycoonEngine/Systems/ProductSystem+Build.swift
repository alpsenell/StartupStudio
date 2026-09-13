import Foundation
import TycoonContent

// MARK: T2 (the build)

/// Iteration 17 — T2. The build's two ways out: *Shelve it* (systems O3)
/// and *Scrap it* (player P2), with *Take it off the shelf*.
///
/// Each is sent only by a player's tap in the app (`shelveBuild`,
/// `unshelveBuild`, `scrapBuild`); no bot sends any of them, and nothing
/// here draws from `rng` or `worldRNG`. Every gate is `BuildRefusal`'s, so a
/// refusal returns no events and the app says why.
extension ProductSystem {
    /// Puts a build in development into the drawer: it leaves `products`
    /// for `GameState.shelf`, so its slot frees today. An announced date
    /// slips first, through J5's own slip (the reputation, the hype share,
    /// the new date; a second slip voids it). Then the hype goes, the crew
    /// on it lose `shelveCrewMorale` and go idle, and the points keep —
    /// decaying `shelveDecayPerQuarter` a quarter in the drawer.
    static func shelve(
        productID: UUID,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard state.buildShelveRefusal(productID: productID) == nil,
              state.product(id: productID) != nil
        else { return [] }

        var events: [GameEvent] = []
        if state.product(id: productID)?.isAnnounced == true {
            // T5's slip, reached through J5's one entry point: a shelve is
            // a missed date, priced the way a missed date is.
            events += AnnounceSystem.forceSlip(
                productID: productID, state: &state, balance: balance, content: content
            )
        }
        guard let index = state.products.firstIndex(where: { $0.id == productID }),
              case .development(var dev) = state.products[index].stage
        else { return events }

        let hypeLost = dev.hype
        dev.hype = 0
        dev.shelvedDay = state.day
        var product = state.products[index]
        product.stage = .development(dev)
        let crew = standDown(productID, morale: balance.build.shelveCrewMorale, state: &state)
        state.products.remove(at: index)
        state.shelf.append(product)
        events.append(.buildShelved(
            productID: productID, name: product.name, hypeLost: hypeLost, crew: crew, day: state.day
        ))
        return events
    }

    /// Takes a shelved build out of the drawer into a free slot. Everyone
    /// idle joins it, the way everyone idle joins a new build.
    static func unshelve(
        productID: UUID,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard state.buildUnshelveRefusal(productID: productID) == nil,
              let index = state.shelf.firstIndex(where: { $0.id == productID }),
              case .development(var dev) = state.shelf[index].stage
        else { return [] }

        dev.shelvedDay = nil
        var product = state.shelf.remove(at: index)
        product.stage = .development(dev)
        state.products.append(product)
        for employeeIndex in state.employees.indices where state.employees[employeeIndex].assignment == .idle {
            state.employees[employeeIndex].assignment = .product(productID)
        }
        return [.buildUnshelved(productID: productID, name: product.name, day: state.day)]
    }

    /// Scraps a build, in a slot or on the shelf: the product is gone, the
    /// type's codebase keeps what `buildScrapQuote` says (and the build's
    /// debt), and the crew on it lose `scrapCrewMorale` and go idle.
    /// Nobody reviews it; nothing sells.
    static func scrap(
        productID: UUID,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard state.buildScrapRefusal(productID: productID, balance: balance, content: content) == nil,
              let quote = state.buildScrapQuote(productID: productID, balance: balance, content: content),
              let product = state.product(id: productID) ?? state.shelvedBuild(id: productID)
        else { return [] }

        let codebase = balance.codebase
        if let index = state.codebases.firstIndex(where: { $0.id == product.typeID }) {
            state.codebases[index].designPts += quote.design
            state.codebases[index].codePts += quote.code
            state.codebases[index].polishPts += quote.polish
            state.codebases[index].debt = codebase.clampDebt(state.codebases[index].debt + quote.debt)
        } else if quote.banked > 0 || quote.debt > 0 {
            state.codebases.append(Codebase(
                id: product.typeID,
                name: product.name,
                designPts: quote.design,
                codePts: quote.code,
                polishPts: quote.polish,
                debt: codebase.clampDebt(quote.debt),
                lastShipDay: state.day,
                productsShipped: 0
            ))
        }

        _ = standDown(productID, morale: balance.build.scrapCrewMorale, state: &state)
        state.products.removeAll { $0.id == productID }
        state.shelf.removeAll { $0.id == productID }
        return [.productScrapped(
            productID: productID, name: product.name, typeID: product.typeID,
            banked: Int(quote.banked.rounded()), day: state.day
        )]
    }

    /// Everyone on the build loses `morale` and goes idle. Returns how
    /// many there were.
    private static func standDown(_ productID: UUID, morale delta: Double, state: inout GameState) -> Int {
        var count = 0
        for index in state.employees.indices where state.employees[index].assignment == .product(productID) {
            state.employees[index].assignment = .idle
            state.employees[index].morale = min(100, max(0, state.employees[index].morale + delta))
            count += 1
        }
        return count
    }
}

/// O3: the drawer's weekly pass. A shelved build loses a thirteenth of
/// `shelveDecayPerQuarter` of its points each week. Returns on its first
/// line while the shelf is empty, which is every run nobody shelved in;
/// draws nothing.
enum ShelfSystem {
    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        guard !state.shelf.isEmpty, state.day % GameState.daysPerWeek == 0 else { return [] }
        let keep = max(0, 1 - balance.build.shelveDecayPerQuarter / 13)
        for index in state.shelf.indices {
            guard case .development(var dev) = state.shelf[index].stage else { continue }
            dev.designPts *= keep
            dev.codePts *= keep
            dev.polishPts *= keep
            state.shelf[index].stage = .development(dev)
        }
        return []
    }
}

#if DEBUG
/// `-autoRoute t2-…`: dresses the loaded save for a screenshot, through
/// the engine's own actions where there is one. Debug builds only;
/// nothing in the game sends it.
///
/// - `ready`: the first build in development is past the ship gate and
///   holds some hype (so the ship sheet opens and the shelve row has a
///   hype number to print).
/// - `shelve`: `ready`, then that build shelved.
/// - `v2`: a declared v2 of the live product with the biggest book,
///   ship-ready — the newest build shelved first when no slot is free.
/// - `v2shipped`: `v2`, then shipped beside its parent.
enum BuildDebugSeed {
    static func apply(
        scenario: String,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        var events: [GameEvent] = []
        switch scenario {
        case "ready", "shelve":
            guard let product = state.productsInDevelopment.first,
                  let index = state.products.firstIndex(where: { $0.id == product.id }),
                  case .development(var dev) = product.stage,
                  let type = content.productType(product.typeID)
            else { break }
            dev.codePts = max(dev.codePts, balance.shipCodeThreshold * type.codePts)
            dev.hype = max(dev.hype, 24)
            state.products[index].stage = .development(dev)
            if scenario == "shelve" {
                events += ProductSystem.shelve(productID: product.id, state: &state, balance: balance, content: content)
            }
        case "v2", "v2shipped":
            let live = state.products.filter { $0.releaseInfo.map { !$0.offMarket } ?? false }
            guard let parent = live.max(by: {
                ($0.releaseInfo?.subscribers ?? 0) < ($1.releaseInfo?.subscribers ?? 0)
            }) else { break }
            if !state.hasFreeDevSlot, let newest = state.productsInDevelopment.last {
                events += ProductSystem.shelve(productID: newest.id, state: &state, balance: balance, content: content)
            }
            events += ProductSystem.startProduct(
                typeID: parent.typeID, topicID: parent.topicID, name: "\(parent.name) Next",
                focus: .balanced, codebaseID: parent.typeID, parentID: parent.id,
                state: &state, balance: balance, content: content
            )
            guard let build = state.products.last, build.parentID == parent.id,
                  case .development(var dev) = build.stage,
                  let type = content.productType(build.typeID)
            else { break }
            dev.designPts = max(dev.designPts, type.designPts * 0.9)
            dev.codePts = max(dev.codePts, type.codePts * 0.9)
            dev.polishPts = max(dev.polishPts, type.polishPts * 0.9)
            state.products[state.products.count - 1].stage = .development(dev)
            if scenario == "v2shipped" {
                events += ProductSystem.ship(productID: build.id, state: &state, balance: balance, content: content)
            }
        default:
            break
        }
        return events
    }
}
#endif

// MARK: end T2
