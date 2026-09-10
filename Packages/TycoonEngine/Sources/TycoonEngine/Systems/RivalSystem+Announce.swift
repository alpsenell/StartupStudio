import Foundation

// MARK: J5 (announce)

/// Iteration 12 — J5. The copycat reads the newspaper too.
///
/// `copycatCheck` treats a product as ripe once it launched
/// `RivalDepthTuning.copycatDelayWeeks` (8) weeks ago. A product whose date
/// was announced — kept, slipped or void — told every studio in the
/// industry what it was and when, so it is ripe at
/// `announce.copycatDelayWeeks` (4). Read from one marked line in
/// `RivalSystem.copycatCheck`; J3 owns the rest of that file.
extension RivalSystem {
    /// The latest launch day at which `product` is old enough to copy,
    /// given the ordinary `ripeDay`. Returns `ripeDay` untouched for a
    /// product nobody announced.
    static func announceRipeDay(_ ripeDay: Int, for product: Product, _ balance: BalanceConfig) -> Int {
        guard product.wasAnnounced else { return ripeDay }
        let headStartWeeks = max(0, RivalDepthTuning.copycatDelayWeeks - balance.announce.copycatDelayWeeks)
        return ripeDay + headStartWeeks * GameState.daysPerWeek
    }
}

// MARK: end J5
