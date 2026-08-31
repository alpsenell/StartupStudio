import Foundation

/// What a shipped product leaves behind.
///
/// Three of the game's better mechanics used to end at ship and were never
/// heard from again: `DevProgress.openBugs` was thrown away, a crunch week
/// cost morale and bugs *that week* and nothing after, and the crew quality
/// ceiling was recomputed per product from scratch — so the fourth product
/// a studio built was mechanically the first one with better people. A
/// codebase is the thread between them: start the next product on it and
/// part of the pools are already full, but you inherit the mess.
///
/// One per product *type*: a mobile app is built on the mobile app
/// codebase, and `id` is the type id, which is also why nothing here needs
/// a draw from the RNG. (Minting a UUID at ship would have shifted the
/// stream under every pacing bot for a value nobody looks at.)
public struct Codebase: Codable, Equatable, Sendable, Identifiable {
    /// The `ProductTypeDef.id` this codebase belongs to — also its identity.
    public let id: String
    /// The name of the product that founded the lineage. What the new
    /// product sheet offers to build on.
    public var name: String
    /// Points already in the bank on day one of the next build, per pool.
    /// Capped at the type's pool sizes when a build starts, so a shrinking
    /// content table can never hand out a finished product.
    public var designPts: Double
    public var codePts: Double
    public var polishPts: Double
    /// Technical debt, 0...`CodebaseBalance.debtCap`. Costs a slice of the
    /// quality ceiling and raises the bug rate for anything built on it.
    public var debt: Double
    /// The day the most recent product shipped out of this codebase.
    public var lastShipDay: Int
    /// How many products have shipped out of it.
    public var productsShipped: Int

    public init(
        id: String,
        name: String,
        designPts: Double = 0,
        codePts: Double = 0,
        polishPts: Double = 0,
        debt: Double = 0,
        lastShipDay: Int = 0,
        productsShipped: Int = 0
    ) {
        self.id = id
        self.name = name
        self.designPts = designPts
        self.codePts = codePts
        self.polishPts = polishPts
        self.debt = debt
        self.lastShipDay = lastShipDay
        self.productsShipped = productsShipped
    }
}

extension GameState {
    /// The codebase with this id, `nil` for an unknown one (and for `nil`
    /// itself, so a greenfield product's `codebaseID` reads through).
    public func codebase(id: String?) -> Codebase? {
        guard let id else { return nil }
        return codebases.first { $0.id == id }
    }

    /// The debt a product in development is building *on top of*: the live
    /// debt of its codebase, or exactly 0 for a greenfield build.
    ///
    /// Live, not frozen at start, and that is the whole point of the
    /// `.refactor` assignment — people taken off production work cut this
    /// number while the build is still running, and the ceiling on the
    /// ship sheet rises the same week.
    public func inheritedDebt(for product: Product) -> Double {
        codebase(id: product.codebaseID)?.debt ?? 0
    }

    /// The codebases a new product of `typeID` could be built on. Empty
    /// until something of that type has shipped.
    public func availableCodebases(typeID: String) -> [Codebase] {
        codebases.filter { $0.id == typeID }
    }
}
