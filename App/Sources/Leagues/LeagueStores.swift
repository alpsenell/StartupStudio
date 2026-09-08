import Foundation
import TycoonEngine
import TycoonSave

// MARK: Iteration 10 — M4 (leagues)

/// Where a league week's run lives — one directory per week, never a
/// slot — and the ledger of finished weeks one level down, the way the
/// season already splits them (`SaveStore` names its files `slot0.json`,
/// so two stores may not share a directory).
struct LeagueStores: Sendable {
    let base: URL

    init(saveDirectory: URL?) {
        let root = saveDirectory ?? Self.defaultSavesDirectory()
        base = root.appendingPathComponent("Leagues", isDirectory: true)
    }

    func run(for week: Int) -> SaveStore<GameState> {
        SaveStore(
            directory: base.appendingPathComponent("\(week)", isDirectory: true),
            currentFormatVersion: 1, slotCount: 1
        )
    }

    var ledger: SaveStore<LeagueLedger> {
        SaveStore(
            directory: base.appendingPathComponent("Ledger", isDirectory: true),
            currentFormatVersion: 1, slotCount: 1
        )
    }

    private static func defaultSavesDirectory() -> URL {
        let fileManager = FileManager.default
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent("Saves", isDirectory: true)
    }
}

/// Every league week this device has finished: one attempt a week, what
/// it was worth, the tier it was played in, the year as squares, and —
/// once the week rolls and the table is read — where it came.
struct LeagueLedger: Codable, Equatable, Sendable {
    struct Entry: Codable, Equatable, Sendable {
        var week: Int
        var tier: LeagueTier
        var score: Int
        /// Whether the score reached the tier's board — posted, or queued
        /// for the next sign-in. False only when the week had already
        /// closed and there was nowhere to send it.
        var submitted: Bool
        /// `EndingKind.rawValue` when the company ended before the
        /// horizon; `nil` when the year simply ran out.
        var ending: String?
        /// The in-game day the run stopped on: 364 at the horizon.
        var gameDay: Int
        /// The three lines the result card reads, composed at the stop.
        var lines: [String]
        /// The year as squares (`YearGrid.strip`).
        var grid: String?
        var finishedAt: Date
        /// Where the player came once the week's table was read; 0 while
        /// the week is still running.
        var rank: Int = 0
        var fieldSize: Int = 0
        var outcome: LeagueOutcome = .unplaced

        var endingKind: EndingKind? { ending.flatMap(EndingKind.init(rawValue:)) }

        /// "The year is up" or the ending's own headline.
        var headline: String { endingKind?.headline ?? "The year is up" }

        /// Whether the week's table has been read and applied.
        var isSettled: Bool { rank > 0 }

        private enum CodingKeys: String, CodingKey {
            case week, tier, score, submitted, ending, gameDay, lines, grid, finishedAt
            case rank, fieldSize, outcome
        }

        init(
            week: Int, tier: LeagueTier, score: Int, submitted: Bool, ending: String?,
            gameDay: Int, lines: [String], grid: String?, finishedAt: Date,
            rank: Int = 0, fieldSize: Int = 0, outcome: LeagueOutcome = .unplaced
        ) {
            self.week = week
            self.tier = tier
            self.score = score
            self.submitted = submitted
            self.ending = ending
            self.gameDay = gameDay
            self.lines = lines
            self.grid = grid
            self.finishedAt = finishedAt
            self.rank = rank
            self.fieldSize = fieldSize
            self.outcome = outcome
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
                week: try container.decodeIfPresent(Int.self, forKey: .week) ?? 0,
                tier: try container.decodeIfPresent(LeagueTier.self, forKey: .tier) ?? .bronze,
                score: try container.decodeIfPresent(Int.self, forKey: .score) ?? 0,
                submitted: try container.decodeIfPresent(Bool.self, forKey: .submitted) ?? false,
                ending: try container.decodeIfPresent(String.self, forKey: .ending),
                gameDay: try container.decodeIfPresent(Int.self, forKey: .gameDay) ?? 0,
                lines: try container.decodeIfPresent([String].self, forKey: .lines) ?? [],
                grid: try container.decodeIfPresent(String.self, forKey: .grid),
                finishedAt: try container.decodeIfPresent(Date.self, forKey: .finishedAt) ?? Date(),
                rank: try container.decodeIfPresent(Int.self, forKey: .rank) ?? 0,
                fieldSize: try container.decodeIfPresent(Int.self, forKey: .fieldSize) ?? 0,
                outcome: try container.decodeIfPresent(LeagueOutcome.self, forKey: .outcome) ?? .unplaced
            )
        }
    }

    var entries: [Entry] = []

    static let empty = LeagueLedger()

    func entry(forWeek week: Int) -> Entry? {
        entries.first { $0.week == week }
    }

    /// The most recent finished week before `week`, whichever it was.
    func lastEntry(before week: Int) -> Entry? {
        entries.filter { $0.week < week }.max { $0.week < $1.week }
    }

    mutating func record(_ entry: Entry) {
        entries.removeAll { $0.week == entry.week }
        entries.append(entry)
        entries.sort { $0.week < $1.week }
        // Two years of weeks is more history than a card ever shows.
        if entries.count > 104 {
            entries.removeFirst(entries.count - 104)
        }
    }
}
