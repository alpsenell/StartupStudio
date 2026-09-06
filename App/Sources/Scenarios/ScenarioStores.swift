import Foundation
import TycoonEngine
import TycoonSave

// MARK: Iteration 8 — scenarios

/// Where scenario runs live: one directory per scenario under
/// `Saves/Scenarios`, and the ledger of stars one level down, apart from
/// the slots for the same reason the daily is.
struct ScenarioStores: Sendable {
    let base: URL

    init(saveDirectory: URL?) {
        let root = saveDirectory ?? Self.defaultSavesDirectory()
        base = root.appendingPathComponent("Scenarios", isDirectory: true)
    }

    func run(for id: String) -> SaveStore<GameState> {
        SaveStore(directory: base.appendingPathComponent(id, isDirectory: true), currentFormatVersion: 1, slotCount: 1)
    }

    var ledger: SaveStore<ScenarioLedger> {
        SaveStore(directory: base.appendingPathComponent("Ledger", isDirectory: true), currentFormatVersion: 1, slotCount: 1)
    }

    private static func defaultSavesDirectory() -> URL {
        let fileManager = FileManager.default
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent("Saves", isDirectory: true)
    }
}

/// The stars earned per scenario, and the last result.
struct ScenarioLedger: Codable, Equatable, Sendable {
    struct Entry: Codable, Equatable, Sendable {
        var scenarioID: String
        var bestStars: Int
        var attempts: Int
        var lastOutcome: ScenarioOutcome
        var lastScore: Int
        var lastFinishedAt: Date
    }

    var entries: [Entry] = []

    func entry(for id: String) -> Entry? {
        entries.first { $0.scenarioID == id }
    }

    mutating func record(id: String, outcome: ScenarioOutcome, score: Int, at date: Date) {
        if let index = entries.firstIndex(where: { $0.scenarioID == id }) {
            entries[index].attempts += 1
            entries[index].bestStars = max(entries[index].bestStars, outcome.stars)
            entries[index].lastOutcome = outcome
            entries[index].lastScore = score
            entries[index].lastFinishedAt = date
        } else {
            entries.append(Entry(
                scenarioID: id, bestStars: outcome.stars, attempts: 1,
                lastOutcome: outcome, lastScore: score, lastFinishedAt: date
            ))
        }
    }

    var totalStars: Int { entries.reduce(0) { $0 + $1.bestStars } }
}
