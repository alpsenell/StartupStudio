import Foundation
import TycoonEngine
import TycoonSave

// MARK: Iteration 7 — the legacy ledger (R2)

/// The session's side of the ledger: load it at launch (seeding the
/// endings from the slots the first time), write a run the moment
/// `gameOver` becomes non-nil, spend an heirloom when a company starts
/// with one, and hand the new-game flow what it may offer.
extension GameSession {
    /// Launch. The first launch that finds no ledger seeds `endingsReached`
    /// from every slot whose summary carries an ending, so nobody who
    /// already finished a company is told they have not.
    func bootstrapLegacy() {
        ledger = legacyStore.load()
        if !legacyStore.exists {
            for row in slots {
                if let ending = row.summary?.endingKind {
                    ledger.endingsReached.insert(ending)
                }
            }
            saveLedger(push: false)
        }
        observeEvents("legacy") { [weak self] events in
            guard events.contains(where: { if case .gameOver = $0 { return true } else { return false } })
            else { return }
            self?.recordEndingIfNeeded()
        }
        #if DEBUG
        // Iteration 8: `-sampleLedger` installs the sample on its own (for
        // the Dynasty and Hall rooms); `-autoNewGame` opens the flow on the
        // founder page, where the successors are.
        if DebugLaunch.opensHeirloomsPage || ProcessInfo.processInfo.arguments.contains("-sampleLedger") {
            ledger = .sample
        }
        if DebugLaunch.opensHeirloomsPage || ProcessInfo.processInfo.arguments.contains("-autoNewGame") {
            beginNewGame(inSlot: slots.first(where: \.isEmpty)?.slot ?? 0)
        }
        // MARK: K5 (hand over the keys)
        handOverOnLaunchIfAsked()
        // MARK: end K5
        #endif
    }

    // MARK: K5 (hand over the keys)

    /// Hands the live company to `successorID`, keeping `keptPercent` of
    /// the founder's holding. The outgoing founder's `LegacyRun` is written
    /// from the state *before* the send, under the id the new `lineage`
    /// points at, and only once the engine accepted — a refused hand-over
    /// writes nothing. No `gameOver`, so nothing posts to Game Center.
    @discardableResult
    func handOverKeys(successorID: UUID, keptPercent: Int) -> Bool {
        let before = engine.state
        let balance = engine.balance
        let runID = UUID()
        let events = engine.send(.handOverKeys(
            successorID: successorID, keptPercent: keptPercent, predecessorRunID: runID
        ))
        guard !events.isEmpty else { return false }
        ledger.recordHandOver(
            before, runID: runID, successorID: successorID, keptPercent: keptPercent, balance: balance
        )
        ledger.induct(AwardsJudge.hallEntries(state: before, content: engine.content))
        saveLedger()
        return true
    }

    #if DEBUG
    /// `-autoRoute k5after` / `-k5HandOver`: hand the fixture to its best
    /// successor at a quarter, a moment after launch (the slot is loaded
    /// by then). Once: a company that already has a lineage is left alone.
    private func handOverOnLaunchIfAsked() {
        guard DebugLaunch.handsOverOnLaunch else { return }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            guard let self else { return }
            let state = engine.state
            let balance = engine.balance
            guard state.lineage == nil,
                  let heir = state.handOverCandidates(balance: balance)
                      .first(where: { state.handOverSuccessorBlocker($0, balance: balance) == nil })
            else { return }
            handOverKeys(successorID: heir.id, keptPercent: HandOverKeep.standard)
        }
    }
    #endif

    // MARK: end K5

    /// The live engine's ending, if it has one.
    func recordEndingIfNeeded() {
        recordEnding(of: engine.state, balance: engine.balance)
    }

    /// Writes a finished company into the ledger, once. A state that is
    /// still running, or an ending already recorded (the same company on
    /// the same day), changes nothing.
    func recordEnding(of state: GameState, balance: BalanceConfig) {
        guard state.gameOver != nil else { return }
        let alreadyRecorded = ledger.runs.contains {
            $0.seed == state.seed && $0.day == state.day && $0.companyName == state.company.name
        }
        guard !alreadyRecorded else { return }
        ledger.record(state, balance: balance)
        // Iteration 8: the products good enough for the hall go in with it.
        ledger.induct(AwardsJudge.hallEntries(state: state, content: engine.content))
        saveLedger()
    }

    /// An heirloom carries once.
    func spendHeirloom(_ heirloom: Heirloom) {
        ledger.spend(heirloom)
        saveLedger()
    }

    /// Writes the ledger to its own directory and, by default, to iCloud.
    /// A write failure never stops the game; the ledger is a record, not
    /// the run.
    func saveLedger(push: Bool = true) {
        try? legacyStore.save(ledger, appVersion: Self.appVersion)
        if push { pushLedger() }
    }

    /// Whether the new-game flow should show the Heirlooms page: only when
    /// the ledger has something left to offer.
    var offersHeirlooms: Bool { !ledger.offers.isEmpty }

    /// `options` with the Heirlooms page turned on when the ledger offers
    /// something. The new-game flow's call site layers this over whatever
    /// options the other lanes built (R4's `newGameOptions`).
    func heirloomOptions(over options: NewGameOptions) -> NewGameOptions {
        var options = options
        options.ledger = ledger
        options.showsHeirloomsStep = offersHeirlooms
        #if DEBUG
        options.startsOnHeirlooms = DebugLaunch.opensHeirloomsPage && offersHeirlooms
        #endif
        return options
    }
}

extension DebugLaunch {
    /// `-autoHeirlooms`: open the new-game flow on the Heirlooms page over
    /// a sample ledger, for the screenshot pass (R2). Not a headless pass:
    /// the door stays, the flow opens over it.
    static var opensHeirloomsPage: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-autoHeirlooms")
        #else
        return false
        #endif
    }
}
