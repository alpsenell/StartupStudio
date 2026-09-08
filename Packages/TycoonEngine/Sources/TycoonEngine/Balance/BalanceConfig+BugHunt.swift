import Foundation

// Iteration 10 — M6. The bug hunt: how many bugs a thumb may take off a
// build in a day, and how many crawl at once.
//
// Both knobs are read only when the player taps a bug, which no bot and no
// tick ever does, so a run that never hunts is bit-for-bit the run it was
// before this file existed whatever the numbers say. `perDay` is the whole
// balance argument: three is a treat you look for, thirty would be a way
// to ship clean products without polish.

extension BalanceConfig {

    // MARK: - Bug hunt

    public struct BugHuntBalance: Codable, Equatable, Sendable {
        /// Bugs a founder may squash by hand in one game day, across every
        /// build. Three: enough to feel like a habit, nowhere near enough
        /// to replace a polish phase (a mid-size build carries dozens).
        public var perDay: Int
        /// How many bugs crawl in the room at once. More than three and
        /// the office reads as an infestation rather than a nuisance.
        public var maxOnScreen: Int

        public init(perDay: Int = 3, maxOnScreen: Int = 3) {
            self.perDay = perDay
            self.maxOnScreen = maxOnScreen
        }

        /// The shipped hunt. Like `sabbatical`, the default is not
        /// "switched off" — there is nothing to switch off until the player
        /// puts a thumb on a bug — so a balance file with no `"bugHunt"`
        /// object still gets the game that ships.
        public static let `default` = BugHuntBalance()
    }
}

// Lets `BalanceConfig`'s synthesized decoder read a balance file with no
// `"bugHunt"` object.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.BugHuntBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.BugHuntBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}
