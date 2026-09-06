import Foundation
import TycoonEngine

// MARK: Iteration 8 — seasons

/// Four weeks of the same world for everyone: a seed, an origin, a
/// difficulty and one twist, derived from the date the way the daily is,
/// so no server decides it and nothing is collected.
struct GameSeason: Equatable, Hashable, Identifiable {
    /// Seasons since the epoch, 1-based.
    let number: Int
    let seed: UInt64
    let origin: FoundingOrigin
    let difficulty: Difficulty
    let twist: SeasonTwist

    var id: Int { number }

    static let daysPerSeason = 28
    /// The horizon a season is scored at: one game year, like the daily.
    static let horizonDays = DailyChallenge.horizonDays

    /// The season a wall-clock instant falls in.
    static func current(now: Date = Date()) -> GameSeason {
        season(number: DailyChallenge.dayNumber(for: now) / daysPerSeason + 1)
    }

    static func season(number: Int) -> GameSeason {
        var rng = SeededRNG(seed: UInt64(bitPattern: Int64(number)) ^ 0x5EA5_0000_0000_0001)
        _ = rng.next()
        let seed = rng.next()
        let origins = FoundingOrigin.allCases
        let difficulties = Difficulty.allCases
        let twists = SeasonTwist.allCases
        return GameSeason(
            number: number,
            seed: seed,
            origin: origins[Int(seed % UInt64(origins.count))],
            difficulty: difficulties[Int((seed >> 8) % UInt64(difficulties.count))],
            twist: twists[(number - 1) % twists.count]
        )
    }

    var firstDay: Date {
        DailyChallenge.epoch.addingTimeInterval(TimeInterval((number - 1) * Self.daysPerSeason * 86_400))
    }

    var lastDay: Date {
        firstDay.addingTimeInterval(TimeInterval(Self.daysPerSeason * 86_400 - 1))
    }

    var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "d MMM"
        return "\(formatter.string(from: firstDay)) – \(formatter.string(from: lastDay))"
    }

    var rules: GameRules { GameRules(twist: twist) }

    /// A face for the season, for the look it earns.
    var lookSeed: UInt64 { seed ^ 0x100C_5EA5_0000_0000 }
}

extension SeasonTwist {
    var title: String {
        switch self {
        case .platformLaunch: "The platform launch"
        case .fundingWinter: "The funding winter"
        case .crashSeason: "The crash season"
        case .poachingSeason: "The poaching season"
        case .pressYear: "The press year"
        }
    }

    var detail: String {
        switch self {
        case .platformLaunch: "Booms come twice as often and land harder. Ship into them."
        case .fundingWinter: "No premium on a round and cheap talent. Build lean."
        case .crashSeason: "Crashes twice as often and deeper. Spread your bets."
        case .poachingSeason: "Rivals come for your people twice as often. Keep them."
        case .pressYear: "The press is kinder and the market bigger. Everything sells, so ship."
        }
    }
}
