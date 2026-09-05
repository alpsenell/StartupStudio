import Foundation
import TycoonEngine

// MARK: Iteration 7 — the daily (R3)

/// Every daily this device has finished: one attempt a day, and what came
/// of it.
///
/// It lives in the daily's own store, beside the run, so nothing about it
/// can leak into a save slot. Reinstalling clears it; that is accepted in
/// the release doc, because the board itself is the record that matters.
struct DailyLedger: Codable, Equatable, Sendable {
    /// One finished attempt.
    struct Entry: Codable, Equatable, Sendable {
        /// The challenge's day number (days since 2026-01-01 UTC).
        var day: Int
        /// Founder net worth when the run stopped.
        var score: Int
        /// Whether the score was sent to `lb.daily` — posted, or queued
        /// for the next sign-in, which is the same thing to the player.
        /// False only when the board's UTC day had already closed, and
        /// there was nowhere to send it.
        var submitted: Bool
        /// `EndingKind.rawValue` when the company ended before the
        /// horizon; `nil` when the year simply ran out.
        var ending: String?
        /// The in-game day the run stopped on: 364 at the horizon.
        var gameDay: Int
        /// The three lines the result card reads, composed at the stop so
        /// the card never needs the state back.
        var lines: [String]
        var finishedAt: Date

        var endingKind: EndingKind? {
            ending.flatMap(EndingKind.init(rawValue:))
        }
    }

    var entries: [Entry] = []

    static let empty = DailyLedger()

    func entry(forDay day: Int) -> Entry? {
        entries.first { $0.day == day }
    }

    /// Records a finished attempt, replacing an earlier one for that day
    /// (which only happens if a stored run outlived its ledger entry).
    mutating func record(_ entry: Entry) {
        entries.removeAll { $0.day == entry.day }
        entries.append(entry)
        entries.sort { $0.day < $1.day }
        // A year of dailies is plenty of history for a card that only
        // ever shows one of them.
        if entries.count > 400 {
            entries.removeFirst(entries.count - 400)
        }
    }
}

extension DailyLedger.Entry {
    /// "The year is up" or the ending's own headline.
    var headline: String {
        endingKind?.headline ?? "The year is up"
    }
}

// MARK: - The three lines

enum DailyResultLines {
    /// Three facts about the company that just stopped, in the
    /// biography's order: what it shipped, who was there, what it was
    /// worth.
    static func lines(for state: GameState, balance: BalanceConfig) -> [String] {
        [shipped(state), people(state), money(state, balance: balance)]
    }

    private static func shipped(_ state: GameState) -> String {
        let count = state.products.reduce(into: 0) { total, product in
            if case .released = product.stage { total += 1 }
        }
        guard count > 0 else { return "Shipped nothing all year." }
        let plural = count == 1 ? "product" : "products"
        let best = state.progression.stats.bestReviewScore
        guard best > 0 else { return "Shipped \(count) \(plural)." }
        return "Shipped \(count) \(plural), best reviewed \(best)."
    }

    private static func people(_ state: GameState) -> String {
        let hires = state.employees.filter { !$0.isFounder }
        guard !hires.isEmpty else { return "Never hired anyone." }
        let plural = hires.count == 1 ? "person" : "people"
        guard let tenure = GameCenterMapping.longestTenure(in: state) else {
            return "\(hires.count) \(plural) on payroll."
        }
        return "\(hires.count) \(plural) on payroll, the longest \(tenure) days in."
    }

    private static func money(_ state: GameState, balance: BalanceConfig) -> String {
        let valuation = state.companyValuation(balance: balance)
        let equity = Int(state.investors.equityRemaining.rounded())
        return "Company worth \(valuation.money); you still owned \(equity)%."
    }
}
