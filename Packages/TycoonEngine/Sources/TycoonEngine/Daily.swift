import Foundation

// MARK: Iteration 7 — the daily company (R3)

/// The company everyone founds on one calendar day.
///
/// Pure: the seed, origin and difficulty are a function of the day number
/// alone, so two phones on the same UTC day run the same deterministic
/// game. Ten dates are pinned in `DailyChallengeTests` so a change here is
/// a deliberate one.
public struct DailyChallenge: Equatable, Hashable, Sendable {
    /// Days since 2026-01-01 UTC.
    public let day: Int
    public let seed: UInt64
    public let origin: FoundingOrigin
    public let difficulty: Difficulty

    /// The horizon a daily is scored at: one game year.
    public static let horizonDays = GameState.daysPerYear

    /// The calendar the day number counts from.
    public static let epoch: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 1
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: components)!
    }()

    /// The challenge for day number `n`.
    public static func forDay(_ n: Int) -> DailyChallenge {
        var rng = SeededRNG(seed: UInt64(bitPattern: Int64(n)) ^ 0xDA11_5EED)
        _ = rng.next()
        let seed = rng.next()
        let origins = FoundingOrigin.allCases
        let difficulties = Difficulty.allCases
        return DailyChallenge(
            day: n,
            seed: seed,
            origin: origins[Int(seed % UInt64(origins.count))],
            difficulty: difficulties[Int((seed >> 8) % UInt64(difficulties.count))]
        )
    }

    /// The day number of a wall-clock instant, in UTC.
    public static func dayNumber(for date: Date) -> Int {
        Int((date.timeIntervalSince(epoch) / 86_400).rounded(.down))
    }

    /// Today's challenge.
    public static func today(now: Date = Date()) -> DailyChallenge {
        forDay(dayNumber(for: now))
    }
}
