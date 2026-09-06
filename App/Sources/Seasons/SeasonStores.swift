import Foundation
import TycoonEngine
import TycoonSave

// MARK: Iteration 8 — seasons

/// Where a season's run lives — one directory per season, never a slot —
/// and the ledger of finished seasons one level down.
struct SeasonStores: Sendable {
    let base: URL

    init(saveDirectory: URL?) {
        let root = saveDirectory ?? Self.defaultSavesDirectory()
        base = root.appendingPathComponent("Seasons", isDirectory: true)
    }

    func run(for number: Int) -> SaveStore<GameState> {
        SaveStore(directory: base.appendingPathComponent("\(number)", isDirectory: true), currentFormatVersion: 1, slotCount: 1)
    }

    var ledger: SaveStore<SeasonLedger> {
        SaveStore(directory: base.appendingPathComponent("Ledger", isDirectory: true), currentFormatVersion: 1, slotCount: 1)
    }

    private static func defaultSavesDirectory() -> URL {
        let fileManager = FileManager.default
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent("Saves", isDirectory: true)
    }
}

/// Every season finished: the score, whether the board took it, the year
/// as squares, and the look it earned.
struct SeasonLedger: Codable, Equatable, Sendable {
    struct Entry: Codable, Equatable, Sendable {
        var number: Int
        var score: Int
        var submitted: Bool
        var ending: String?
        var gameDay: Int
        var grid: String?
        var finishedAt: Date

        var endingKind: EndingKind? { ending.flatMap(EndingKind.init(rawValue:)) }
    }

    var entries: [Entry] = []

    func entry(for number: Int) -> Entry? {
        entries.first { $0.number == number }
    }

    mutating func record(_ entry: Entry) {
        entries.removeAll { $0.number == entry.number }
        entries.append(entry)
    }

    /// The seasons whose look is earned: every finished one.
    var finishedNumbers: [Int] { entries.map(\.number).sorted() }
}
