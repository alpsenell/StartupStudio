import Foundation
import TycoonContent

/// When a build in development reaches the ship gate at today's pace.
///
/// The forecast in `ShipForecast` answers *how good* a build will be; it
/// never answered *when*. The agenda (and any screen that wants to put a
/// build on a calendar) needs a day, so this is the missing half: a pure
/// read of the crew that is on the product right now, projected forward at
/// a constant rate. It draws no random numbers, writes nothing back, and
/// changes no balance — it is arithmetic on the same daily output the
/// reducer computes, so a day it predicts is the day the reducer reaches
/// if nothing about the crew changes.
public struct ShipETA: Equatable, Sendable, Identifiable {
    public let productID: UUID
    public let productName: String
    /// The absolute game day the ship gate opens. Equal to today when the
    /// build can already ship.
    public let day: Int
    /// Days from today, 0 when the build is ready now.
    public let daysAway: Int
    /// Whether the gate is already open.
    public let isReady: Bool

    public var id: UUID { productID }

    public init(productID: UUID, productName: String, day: Int, daysAway: Int, isReady: Bool) {
        self.productID = productID
        self.productName = productName
        self.day = day
        self.daysAway = daysAway
        self.isReady = isReady
    }
}

extension GameState {
    /// The day `product` reaches the ship gate at the rate its current crew
    /// is working today.
    ///
    /// `nil` when the product is not in development, when its type is
    /// missing from content, or when nobody is on it — a build with no
    /// hands on it has no ETA, which is the honest answer and the one the
    /// agenda wants (it shows nothing rather than "in 4,000 days").
    public func shipETA(
        for product: Product,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> ShipETA? {
        // Iteration 7: one ETA. `BuildETA` projects every pool from the
        // same crew arithmetic; the ship gate is its `daysToShippable`,
        // so the war room's countdown and the agenda's row can never
        // disagree by a day.
        guard case .development = product.stage,
              let eta = buildETA(productID: product.id, balance: balance, content: content),
              let days = eta.daysToShippable
        else { return nil }
        return ShipETA(
            productID: product.id, productName: product.name,
            day: day + days, daysAway: days, isReady: days == 0
        )
    }

    /// Every in-development build's ETA, soonest first. Builds nobody is
    /// working on are left out.
    public func shipETAs(balance: BalanceConfig, content: ContentCatalog) -> [ShipETA] {
        productsInDevelopment
            .compactMap { shipETA(for: $0, balance: balance, content: content) }
            .sorted { ($0.day, $0.productName) < ($1.day, $1.productName) }
    }
}
