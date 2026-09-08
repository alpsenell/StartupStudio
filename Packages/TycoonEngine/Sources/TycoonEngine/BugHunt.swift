import Foundation

// Iteration 10 — M6 owns this file. The tactile bug hunt: bugs crawl
// across the coders' desks in the pixel office during a build and a tap
// squashes one. The engine side is one action (`.squashBug(productID:)`
// in M6's `GameAction` region) against `DevProgress.openBugs`, with a
// per-day cap so it is a treat, not a strategy; the office scene side is
// PixelKit's `OfficeFX`.
//
// Identity at the default: nothing here runs on a tick, nothing draws from
// an rng stream, and nothing is written to a save that has never had a bug
// squashed in it. The day's tally is *derived* from the event log rather
// than stored — three `.bugSquashed` entries a day cannot fall off a
// 500-entry log, and a counter on `DevProgress` would have meant a new
// coding key in the hand-written product Codable and a byte for every
// build in every fixture. See `squashesToday(in:)`.

/// The rules of the bug hunt: who can be squashed, how many a day, and why
/// a tap was refused.
public enum BugHunt {

    // MARK: - Why a tap did nothing

    /// The reason a `.squashBug` was refused, in the app's words.
    ///
    /// Rule 7 of the round: a refused action says why. The office has no
    /// button to write a consequence on, so the sentence goes in a toast.
    public enum Refusal: String, Sendable, Equatable, CaseIterable {
        /// The product id is not a build in this company any more.
        case noSuchBuild
        /// It shipped while the finger was in the air.
        case alreadyShipped
        /// Nobody has written a line of it yet, so there is nothing in it
        /// to go wrong.
        case notYetCoding
        /// The build's bug list is empty.
        case nothingToSquash
        /// Today's three are done.
        case dailyCapReached

        /// What the player is told.
        public var sentence: String {
            switch self {
            case .noSuchBuild, .alreadyShipped:
                "That build has gone out of the door — nothing left to catch."
            case .notYetCoding:
                "Nobody has written any of it yet. Bugs come with the code."
            case .nothingToSquash:
                "The build is clean. Nothing to squash."
            case .dailyCapReached:
                "That's today's lot. The team gets the rest — sleep on it."
            }
        }
    }

    // MARK: - The day's tally

    /// How many bugs the founder has squashed by hand today.
    ///
    /// Derived from the event log, which is the only record the hunt keeps.
    /// The log holds 500 entries and the cap is three a day, so the count
    /// can never be lost to a trim.
    public static func squashesToday(in state: GameState) -> Int {
        var count = 0
        // Newest first: the log is chronological, and once we are off
        // today we are off it for good.
        for event in state.eventLog.reversed() {
            guard case .bugSquashed(_, _, let day) = event else { continue }
            guard day == state.day else { break }
            count += 1
        }
        return count
    }

    /// How many are left in today's allowance, never below zero.
    public static func squashesLeft(in state: GameState, balance: BalanceConfig) -> Int {
        max(0, balance.bugHunt.perDay - squashesToday(in: state))
    }

    // MARK: - Gates

    /// Whether a build is somewhere a bug could be crawling: in
    /// development, past the first code point (bugs are made of code), and
    /// carrying at least one open one.
    ///
    /// This is the whole "code or polish phase" reading the engine can
    /// give — there is no discrete phase on a build, only a focus split and
    /// the points accrued — and it is the truthful one: a design-only
    /// build has no bugs to find because `applyDailyProgress` has not
    /// rolled for any.
    public static func isHuntable(_ product: Product) -> Bool {
        guard case .development(let dev) = product.stage else { return false }
        return dev.codePts >= 1 && dev.openBugs > 0
    }

    /// Every build with a bug on it right now, in the order they were
    /// started, so the office spawns from a stable list.
    public static func huntableBuilds(in state: GameState) -> [Product] {
        state.products.filter(isHuntable)
    }

    /// Why a squash on this product would be refused, or `nil` when it
    /// would land. The single gate both the reducer and the app read, so
    /// the sentence the player sees is the reason the engine actually used.
    public static func refusal(
        productID: UUID,
        in state: GameState,
        balance: BalanceConfig
    ) -> Refusal? {
        guard let product = state.products.first(where: { $0.id == productID }) else {
            return .noSuchBuild
        }
        guard case .development(let dev) = product.stage else { return .alreadyShipped }
        guard dev.codePts >= 1 else { return .notYetCoding }
        guard dev.openBugs > 0 else { return .nothingToSquash }
        guard squashesLeft(in: state, balance: balance) > 0 else { return .dailyCapReached }
        return nil
    }
}
