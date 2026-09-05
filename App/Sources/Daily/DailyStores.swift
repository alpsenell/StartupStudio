import Foundation
import TycoonEngine
import TycoonSave

// MARK: Iteration 7 — the daily (R3)

/// Where today's company lives: its own directory, never a slot.
///
/// Two stores, because `SaveStore` names its files `slot<N>.json` and two
/// stores in one directory would fight over `slot0.json`: the run sits in
/// `Saves/Daily`, the ledger one level down in `Saves/Daily/Ledger`. The
/// run cannot be copied into a slot and the slots cannot see it, which is
/// the whole point — a daily is one attempt, not a save.
struct DailyStores: Sendable {
    let run: SaveStore<GameState>
    let ledger: SaveStore<DailyLedger>

    /// - Parameter saveDirectory: the session's own directory, or `nil`
    ///   for the app's (Application Support/Saves).
    init(saveDirectory: URL?) {
        let base = (saveDirectory ?? Self.defaultSavesDirectory())
            .appendingPathComponent("Daily", isDirectory: true)
        run = SaveStore(directory: base, currentFormatVersion: 1, slotCount: 1)
        ledger = SaveStore(
            directory: base.appendingPathComponent("Ledger", isDirectory: true),
            currentFormatVersion: 1,
            slotCount: 1
        )
    }

    /// The same base `SaveStore` picks when it is handed no directory.
    private static func defaultSavesDirectory() -> URL {
        let fileManager = FileManager.default
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent("Saves", isDirectory: true)
    }
}
