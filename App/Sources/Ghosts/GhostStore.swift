import CloudKit
import Foundation
import TycoonEngine
import TycoonSave

// MARK: Iteration 8 — rival ghosts

/// What a finished daily leaves behind for the players who come after:
/// a few hundred bytes of launches, a name, a face and a score.
struct GhostLog: Codable, Equatable, Sendable, Identifiable {
    /// The daily's day number the run was played on.
    var day: Int
    var player: String
    var companyName: String
    var appearanceSeed: UInt64
    var focusTopicIDs: [String]
    var launches: [GhostLaunch]
    var finalNetWorth: Int
    var recordedAt: Date

    var id: String { "\(day)-\(player)-\(companyName)" }

    /// The script the engine founds a rival from.
    var script: GhostScript {
        let quality = launches.map(\.quality).max() ?? 40
        return GhostScript(
            name: player, appearanceSeed: appearanceSeed,
            strength: quality / RivalDepthTuning.qualityPerStrength,
            focusTopicIDs: focusTopicIDs, launches: launches, finalNetWorth: finalNetWorth
        )
    }
}

/// Where ghosts live: this phone's cache, one file per day under
/// `Saves/Ghosts`. The field is your past selves until the cloud refresh
/// below has pulled other players' days into the same cache.
@MainActor
protocol GhostStore {
    /// The logs recorded on `day`, best score first.
    func logs(forDay day: Int) -> [GhostLog]
    func save(_ log: GhostLog)
}

/// The logs of one day, as one file.
struct GhostLogs: Codable, Equatable, Sendable {
    var logs: [GhostLog] = []
}

@MainActor
final class LocalGhostStore: GhostStore {
    let base: URL

    init(saveDirectory: URL?) {
        let root = saveDirectory ?? {
            let fileManager = FileManager.default
            let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            return base.appendingPathComponent("Saves", isDirectory: true)
        }()
        base = root.appendingPathComponent("Ghosts", isDirectory: true)
    }

    private func store(forDay day: Int) -> SaveStore<GhostLogs> {
        SaveStore(directory: base.appendingPathComponent("\(day)", isDirectory: true), currentFormatVersion: 1, slotCount: 1)
    }

    func logs(forDay day: Int) -> [GhostLog] {
        ((try? store(forDay: day).load())?.state.logs ?? []).sorted { $0.finalNetWorth > $1.finalNetWorth }
    }

    func save(_ log: GhostLog) {
        var logs = (try? store(forDay: log.day).load())?.state ?? GhostLogs()
        logs.logs.removeAll { $0.id == log.id }
        logs.logs.append(log)
        try? store(forDay: log.day).save(logs, appVersion: "1")
    }
}

/// Everyone's ghosts, in CloudKit's public database: one record per
/// finished daily, keyed by the day. A refresh pulls a day's records into
/// the local cache; a push sends this phone's ghost up.
///
/// Written against the CloudKit API and not yet exercised: the owner's
/// personal team cannot sign the iCloud entitlement, and a public
/// database needs the `iCloud.com.alpsenel.startupstudio` container on
/// the App ID. When the container exists, flip `isEnabled`; the front
/// door then refreshes yesterday's ghosts before today's company is
/// founded, and the local cache is the fallback whenever CloudKit is
/// unreachable. Nothing of the player is written beyond the display name
/// they chose and what their company shipped.
@MainActor
enum CloudGhostStore {
    /// Off until the container exists on the App ID.
    static let isEnabled = false
    static let recordType = "GhostLog"
    static let containerIdentifier = "iCloud.com.alpsenel.startupstudio"

    private static var database: CKDatabase {
        CKContainer(identifier: containerIdentifier).publicCloudDatabase
    }

    /// Pulls `day`'s records into `cache`. Silent on any failure.
    static func refresh(day: Int, into cache: any GhostStore) async {
        guard isEnabled else { return }
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(format: "day == %d", day))
        query.sortDescriptors = [NSSortDescriptor(key: "finalNetWorth", ascending: false)]
        guard let (matches, _) = try? await database.records(matching: query, resultsLimit: 25) else { return }
        for (_, result) in matches {
            guard case .success(let record) = result,
                  let data = record["payload"] as? Data,
                  let log = try? JSONDecoder().decode(GhostLog.self, from: data)
            else { continue }
            cache.save(log)
        }
    }

    /// Sends this phone's ghost up. Silent on any failure.
    static func push(_ log: GhostLog) async {
        guard isEnabled else { return }
        let record = CKRecord(recordType: recordType, recordID: CKRecord.ID(recordName: log.id))
        record["day"] = log.day as CKRecordValue
        record["finalNetWorth"] = log.finalNetWorth as CKRecordValue
        record["payload"] = (try? JSONEncoder().encode(log)) as CKRecordValue?
        _ = try? await database.save(record)
    }
}
