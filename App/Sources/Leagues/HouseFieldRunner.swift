import Foundation
import os
import TycoonBots
import TycoonContent
import TycoonEngine

// MARK: J4 (house field)

/// Plays the house field away from the main actor.
///
/// An actor so that two callers asking for the same field — the front
/// door's refresh and the League sheet opening a second later — share one
/// run, and so fields play one after another rather than all at once. The
/// bots themselves run on a utility dispatch queue across the cores: a
/// field is pure CPU, and has no business on the cooperative pool the
/// UI's own tasks wait on. Nothing here reads or writes `GameSession`; the
/// results go back to the main actor, which files them in the ghost cache.
actor HouseFieldRunner {
    static let shared = HouseFieldRunner()

    private var inFlight: [Int: Task<[HouseFieldResult], Never>] = [:]
    private var tail: Task<Void, Never>?

    /// What the last field cost: the lane's timing check, and the line the
    /// release build logs.
    private(set) var lastTiming: HouseFieldTiming?

    /// Plays `roster` through `setup`. A second call for the same key while
    /// the first is running waits for it instead of playing it twice.
    func play(key: Int, roster: [HouseFieldFounder], setup: HouseFieldSetup) async -> [HouseFieldResult] {
        if let running = inFlight[key] { return await running.value }
        let previous = tail
        let task = Task<[HouseFieldResult], Never>(priority: .utility) {
            await previous?.value
            let (results, timing) = await Self.compute(roster: roster, setup: setup, key: key)
            self.lastTiming = timing
            return results
        }
        inFlight[key] = task
        tail = Task { _ = await task.value }
        let results = await task.value
        inFlight[key] = nil
        return results
    }

    private static let log = Logger(subsystem: "com.alpsenel.startupstudio", category: "HouseField")

    /// The bundled balance and content, loaded once for every field.
    private static let bundled: HouseFieldConfiguration? = {
        guard let balance = try? BalanceConfig.loadBundled(),
              let content = try? ContentCatalog.loadBundled()
        else { return nil }
        return HouseFieldConfiguration(balance: balance, content: content)
    }()

    private nonisolated static func compute(
        roster: [HouseFieldFounder], setup: HouseFieldSetup, key: Int
    ) async -> ([HouseFieldResult], HouseFieldTiming) {
        guard let configuration = bundled, !roster.isEmpty else {
            return ([], HouseFieldTiming(key: key, runs: 0, wallSeconds: 0, sumOfRunsSeconds: 0, slowestRunSeconds: 0))
        }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let started = Date()
                let box = HouseFieldBox(count: roster.count)
                DispatchQueue.concurrentPerform(iterations: roster.count) { index in
                    let runStarted = Date()
                    let result = HouseFieldRun.play(
                        roster[index], setup: setup,
                        bundled: configuration.balance, content: configuration.content
                    )
                    box.set(index, result, seconds: Date().timeIntervalSince(runStarted))
                }
                let (results, seconds) = box.values
                let timing = HouseFieldTiming(
                    key: key, runs: results.count,
                    wallSeconds: Date().timeIntervalSince(started),
                    sumOfRunsSeconds: seconds.reduce(0, +),
                    slowestRunSeconds: seconds.max() ?? 0
                )
                log.notice("\(timing.line, privacy: .public)")
                continuation.resume(returning: (results, timing))
            }
        }
    }
}

/// What one field cost, in seconds.
struct HouseFieldTiming: Equatable, Sendable {
    var key: Int
    var runs: Int
    /// Start to finish, the runs spread across the cores.
    var wallSeconds: Double
    /// The runs one after another: what one core would have taken.
    var sumOfRunsSeconds: Double
    var slowestRunSeconds: Double

    var line: String {
        String(
            format: "house field %d: %d runs, %.2f s wall, %.2f s one after another, one bot-year %.3f s (slowest %.3f s)",
            key, runs, wallSeconds, sumOfRunsSeconds,
            runs > 0 ? sumOfRunsSeconds / Double(runs) : 0, slowestRunSeconds
        )
    }
}

private struct HouseFieldConfiguration: Sendable {
    let balance: BalanceConfig
    let content: ContentCatalog
}

/// The concurrent runs' results, one slot each, behind a lock.
private final class HouseFieldBox: @unchecked Sendable {
    private let lock = NSLock()
    private var results: [HouseFieldResult?]
    private var seconds: [Double]

    init(count: Int) {
        results = Array(repeating: nil, count: count)
        seconds = Array(repeating: 0, count: count)
    }

    func set(_ index: Int, _ result: HouseFieldResult, seconds elapsed: Double) {
        lock.lock()
        results[index] = result
        seconds[index] = elapsed
        lock.unlock()
    }

    var values: ([HouseFieldResult], [Double]) {
        lock.lock()
        defer { lock.unlock() }
        return (results.compactMap { $0 }, seconds)
    }
}

// MARK: end J4
