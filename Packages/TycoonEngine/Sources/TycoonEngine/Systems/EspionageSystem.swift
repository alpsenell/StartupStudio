import Foundation
import TycoonContent

/// Iteration 11, wave two — W3. The five operations, what they buy, and
/// what a court does about the ones that come back.
///
/// **Nothing in this file runs until the player presses a button.** `run`
/// returns on its first line while `state.espionage == .empty`, and
/// `state.espionage` only ever stops being empty because an operation
/// action was applied through the reducer. Every pacing bot, every
/// byte-identical fixture and every save written before this iteration
/// therefore takes exactly the path it always took.
///
/// **Draws.** `state.socialRNG` only: one uniform for whether an operation
/// lands, one for whether it is traced, one for which facts a dossier
/// comes back with, and one for the codename the mole reports. `rng` and
/// `worldRNG` are never touched.
///
/// **The record.** Every operation, landed or botched, writes a
/// `CrimeRecordEntry` for N1's `corporateEspionage` offence. That means
/// the crime sweep rolls on it every week for the rest of the run, the
/// courtroom can hear it, and the founder can turn themselves in for it.
/// The trace roll here is the *first* roll, not the only one.
enum EspionageSystem {

    /// The flag every `spy_` event in the company catalog is gated on, so
    /// a run that has never had anything done to anybody draws from
    /// exactly the pool it drew from before this lane existed.
    static let recordFlag = "spy_record"
    /// Set for the rest of the run once an operation was traced back.
    static let tracedFlag = "spy_traced"
    /// The gate the `spy_` confrontation staff defs sit behind, so the
    /// weekly staff roll can never pick one. Nothing ever raises it.
    static let confrontationFlag = "spy_confrontation"

    // MARK: - The tick

    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        guard state.espionage != .empty, state.gameOver == nil else { return [] }
        return moleReportsDue(&state, balance)
    }

    /// The day the mole said they would ship arrives. If the founder has
    /// something of their own on that topic, being ready for it is worth
    /// something: the studio ships into a market that was waiting for
    /// them, and it lands smaller.
    private static func moleReportsDue(
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) -> [GameEvent] {
        var events: [GameEvent] = []
        for index in state.espionage.intel.indices
        where state.espionage.intel[index].isLive
            && state.day >= state.espionage.intel[index].expectedDay {
            let report = state.espionage.intel[index]
            state.espionage.intel[index].closedDay = state.day
            let ready = state.products.contains { product in
                guard case .released(let info) = product.stage else { return false }
                return product.topicID == report.topicID && !info.offMarket
            }
            if ready {
                RivalSystem.espionageIntercepted(
                    report.rivalID, state: &state, balance: balance
                )
            }
            state.life.phone.post(
                ready
                    ? "They shipped it today. We were already there, and the room noticed."
                    : "They shipped it today, exactly when I said. Nobody here was ready.",
                from: .office, day: state.day
            )
            events.append(.espionageIntelClosed(
                rival: report.rivalName,
                topicID: report.topicID,
                intercepted: ready,
                day: state.day
            ))
        }
        return events
    }

    // MARK: - Running an operation

    /// The one gate the button and the engine share.
    static func refusal(
        _ operation: EspionageOperation,
        against rivalID: UUID,
        state: GameState,
        balance: BalanceConfig
    ) -> EspionageRefusal? {
        guard let rival = state.rivals.rival(id: rivalID) else { return .noRival }
        if state.crime.pendingCase != nil { return .casePending }
        if state.life.isAway(day: state.day) { return .away }

        let config = balance.espionage
        if let last = state.espionage.lastOpDay, state.day - last < config.cooldownDays {
            return .tooSoon
        }
        if state.espionage.hasStanding(operation, against: rivalID) { return .alreadyDone }

        // What the operation needs before what it costs: a row that says
        // "put somebody on their founder first" teaches the chain, and a
        // row that says the wallet is empty only teaches arithmetic.
        switch operation {
        case .tailFounder, .placeMole:
            break
        case .poachWithDirt:
            if state.espionage.dossier(on: rivalID) == nil { return .needDossier }
        case .buyRoadmap:
            if state.productsInDevelopment.isEmpty { return .nothingToBuild }
        case .hackStorefront:
            if rival.competingProducts(on: state.day).isEmpty { return .nothingToHack }
        }

        let price = Espionage.cost(operation, balance: config)
        if price.wallet > 0, state.life.wallet < price.wallet { return .noWallet }
        if price.company > 0, state.company.cash < price.company { return .noCompanyCash }
        return nil
    }

    /// Presses the button. Costs are taken here and only here, once; the
    /// record entry is written whatever the outcome.
    static func operate(
        _ operation: EspionageOperation,
        against rivalID: UUID,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard refusal(operation, against: rivalID, state: state, balance: balance) == nil,
              let rival = state.rivals.rival(id: rivalID)
        else { return [] }

        let config = balance.espionage
        let price = Espionage.cost(operation, balance: config)
        if price.wallet > 0 { state.life.wallet -= price.wallet }
        if price.company > 0 {
            state.company.cash -= price.company
            state.ledger.post(LedgerEntry(
                day: state.day, amount: -price.company, category: .other,
                label: invoiceLabel(operation)
            ))
        }

        let chance = Espionage.successChance(
            operation,
            rival: rival,
            skill: state.life.skills.crimeValue(for: .marketKnowledge),
            dossier: state.espionage.dossier(on: rivalID),
            day: state.day,
            balance: config
        )
        let landed = state.socialRNG.nextUniform() < chance

        var events: [GameEvent] = []
        var note = ""
        if landed {
            let outcome = payOff(
                operation, rival: rival, state: &state, balance: balance, content: content
            )
            note = outcome.note
            events.append(contentsOf: outcome.events)
        } else {
            note = botchedNote(operation, rival: rival)
        }

        // N1's needle, and N1's record: this is a crime whether it worked
        // or not, and whether anybody noticed or not.
        state.crime.notoriety = min(100,
            state.crime.notoriety + Espionage.notorietyCost(operation, balance: config)
        )
        let entry = CrimeRecordEntry(
            id: "spy-\(operation.rawValue)-\(state.day)",
            offence: .corporateEspionage,
            day: state.day,
            gain: gainValue(operation, landed: landed, balance: config),
            note: "\(rival.name): \(note)"
        )
        state.crime.record.append(entry)
        if state.crime.record.count > CrimeState.maxRecord {
            state.crime.record.removeFirst(state.crime.record.count - CrimeState.maxRecord)
        }
        state.narrative.flags.insert(CrimeSystem.recordFlag)
        state.narrative.flags.insert(recordFlag)

        // Traced on the day, or left on the record for the weekly sweep.
        let traceChance = Espionage.traceChance(
            operation,
            landed: landed,
            notoriety: state.crime.notoriety,
            hasLegal: state.knownDepartments.contains(.legal),
            balance: config,
            crime: balance.crime,
            // MARK: J2 (record)
            spotlight: state.standingSpotlight(balance: balance)
            // MARK: end J2
        )
        let traced = state.socialRNG.nextUniform() < traceChance

        RivalSystem.espionageGrudge(
            rivalID, to: Espionage.grudge(traced: traced, balance: config), state: &state
        )

        let record = EspionageOpRecord(
            id: "\(operation.rawValue)-\(state.day)",
            operation: operation.rawValue,
            rivalID: rivalID,
            rivalName: rival.name,
            day: state.day,
            landed: landed,
            tracedDay: traced ? state.day : nil,
            note: note
        )
        state.espionage.ops.append(record)
        if state.espionage.ops.count > EspionageState.maxOps {
            state.espionage.ops.removeFirst(
                state.espionage.ops.count - EspionageState.maxOps
            )
        }
        state.espionage.lastOpDay = state.day

        events.insert(.espionageOperationRun(
            operation: operation.rawValue,
            rival: rival.name,
            landed: landed,
            day: state.day
        ), at: 0)

        if traced {
            events.append(contentsOf: tracedBack(
                operation, entry: entry, rival: rival, state: &state, balance: balance
            ))
        }
        // MARK: J2 (record)
        // A trace is news, and news costs a famous founder a rung.
        if traced, let level = state.fame.standingDropRung(balance: balance.fame) {
            events.append(.standingFameDropped(
                level: level.rawValue, reason: "trace", day: state.day
            ))
        }
        // MARK: end J2
        return events
    }

    /// Somebody worked out who did it. The studio holds the whole thing,
    /// and a case goes on the books through N1's own door.
    private static func tracedBack(
        _ operation: EspionageOperation,
        entry: CrimeRecordEntry,
        rival: Rival,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        state.narrative.flags.insert(tracedFlag)
        state.life.phone.post(
            "There is a letter here from \(rival.name)'s lawyers. It is not a nice letter.",
            from: .office, day: state.day
        )
        var events: [GameEvent] = [.espionageTraced(
            operation: operation.rawValue, rival: rival.name, day: state.day
        )]
        // The case is raised the way every other case is raised, so the
        // hearing, the settlement and the courtroom are N1's, unchanged.
        events.append(contentsOf: CrimeSystem.raiseCase(
            against: entry, state: &state, balance: balance
        ))
        // The studio that brought it is the one that was done to.
        if let index = state.crime.cases.indices.last {
            state.crime.cases[index].rivalID = rival.id
        }
        return events
    }

    // MARK: - What each one buys

    private static func payOff(
        _ operation: EspionageOperation,
        rival: Rival,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> (note: String, events: [GameEvent]) {
        let config = balance.espionage
        switch operation {
        case .tailFounder:
            let facts = dossierFacts(about: rival, state: &state)
            let dossier = EspionageDossier(
                rivalID: rival.id,
                rivalName: rival.name,
                day: state.day,
                facts: facts,
                leverage: config.dossierLeverage
            )
            state.espionage.dossiers.removeAll { $0.rivalID == rival.id }
            state.espionage.dossiers.append(dossier)
            return (
                "Three things about \(rival.name)'s founder, in a folder.",
                [.espionageDossierOpened(rival: rival.name, facts: facts.count, day: state.day)]
            )

        case .placeMole:
            let topicID = rival.focusTopicIDs.first
                ?? state.market.topics.keys.sorted().first
                ?? "productivity"
            let codename = moleCodename(&state, content)
            let report = EspionageIntel(
                rivalID: rival.id,
                rivalName: rival.name,
                topicID: topicID,
                codename: codename,
                expectedDay: state.day + config.intelLeadDays,
                day: state.day
            )
            state.espionage.intel.append(report)
            if state.espionage.intel.count > EspionageState.maxIntel {
                state.espionage.intel.removeFirst(
                    state.espionage.intel.count - EspionageState.maxIntel
                )
            }
            state.life.phone.post(
                "They call it \(codename) inside the building. \(config.intelLeadDays) days out, "
                    + "and nobody there thinks it is a secret.",
                from: .office, day: state.day
            )
            return (
                "They are shipping \(codename) into \(topicName(topicID, content)).",
                [.espionageIntelReceived(
                    rival: rival.name,
                    codename: codename,
                    topicID: topicID,
                    expectedDay: report.expectedDay,
                    day: state.day
                )]
            )

        case .poachWithDirt:
            // The candidate is minted by the hiring desk, exactly the way
            // N1's NDA poach mints one — the desk owns the shape of a
            // person.
            let name = HiringSystem.crimeMintPoachedCandidate(
                from: rival, landed: true, state: &state, balance: balance, content: content
            )
            RivalSystem.espionageLostTheirBest(rival.id, state: &state, balance: balance)
            return (
                "\(name) is in your pool, and did not need asking twice.",
                [.espionagePoachLanded(name: name, rival: rival.name, day: state.day)]
            )

        case .buyRoadmap:
            let topicID = rival.focusTopicIDs.first
                ?? state.productsInDevelopment.first?.topicID
                ?? "productivity"
            if !state.espionage.stolenTopicIDs.contains(topicID) {
                state.espionage.stolenTopicIDs.append(topicID)
            }
            // The plan lands on your own build the way a faked demo does:
            // hype, on the thing you are already making.
            var boosted = "your next build"
            if let index = state.products.firstIndex(where: { product in
                if case .development = product.stage { return true }
                return false
            }), case .development(var development) = state.products[index].stage {
                development.hype += config.roadmapHype
                state.products[index].stage = .development(development)
                boosted = state.products[index].name
            }
            RivalSystem.espionageRoadmapWalked(rival.id, state: &state, balance: balance)
            return (
                "Their whole plan, and \(boosted) is suddenly a fortnight ahead of it.",
                [.espionageRoadmapBought(
                    rival: rival.name, topicID: topicID, hype: Int(config.roadmapHype), day: state.day
                )]
            )

        case .hackStorefront:
            let lost = RivalSystem.espionageHackStorefront(
                rival.id, state: &state, balance: balance
            )
            return (
                "\(rival.name)'s shop showed an error page for a week.",
                [.espionageStorefrontHacked(
                    rival: rival.name, unitsLost: lost, day: state.day
                )]
            )
        }
    }

    /// The line the record keeps when it does not work. The money is gone
    /// either way, which is the point.
    private static func botchedNote(_ operation: EspionageOperation, rival: Rival) -> String {
        switch operation {
        case .tailFounder:
            "Four days of photographs of a man buying oat milk."
        case .placeMole:
            "\(rival.name)'s HR did not call your person back."
        case .poachWithDirt:
            "They listened to all of it and then said no, politely."
        case .buyRoadmap:
            "The document was six months old and half of it was a font test."
        case .hackStorefront:
            "Their shop stayed up. Somebody's did not."
        }
    }

    /// What the record says it was worth, which is what a settlement is
    /// priced off.
    private static func gainValue(
        _ operation: EspionageOperation,
        landed: Bool,
        balance: BalanceConfig.EspionageBalance
    ) -> Int {
        guard landed else { return 0 }
        let price = Espionage.cost(operation, balance: balance)
        return (price.wallet + price.company) * 2
    }

    private static func invoiceLabel(_ operation: EspionageOperation) -> String {
        switch operation {
        case .tailFounder: "Professional services"
        case .placeMole: "Recruitment consultancy, offsite"
        case .poachWithDirt: "Introduction fee"
        case .buyRoadmap: "Market research, commissioned"
        case .hackStorefront: "Infrastructure testing"
        }
    }

    /// Three things about somebody's founder. One draw picks the window
    /// into a fixed list, so the same seed reads the same folder.
    private static func dossierFacts(about rival: Rival, state: inout GameState) -> [String] {
        let pool = [
            "Two of their three angels are the same person, through two companies.",
            "The last round closed a month after they said it closed.",
            "They have a co-founder nobody has seen since the second office.",
            "Their headline number counts trials as customers, and has since spring.",
            "They fly economy and expense business, every time, to the same city.",
            "The lawsuit they settled in year one had a gag order and a very large number.",
            "Their best engineer has been interviewing since the summer.",
            "The office is on a lease they cannot get out of until the winter.",
            "They tell investors a story about a garage. It was their father's garage.",
            "Half the shelf is a white-label of somebody else's product.",
        ]
        let start = state.socialRNG.nextInt(in: 0...(pool.count - 3))
        return Array(pool[start..<(start + 3)])
    }

    /// What they call it inside the building.
    private static func moleCodename(
        _ state: inout GameState, _ content: ContentCatalog
    ) -> String {
        let words = content.names.productWords
        guard !words.isEmpty else { return "Project Blue" }
        let word = words[state.socialRNG.nextInt(in: 0...(words.count - 1))]
        return "Project \(word)"
    }

    private static func topicName(_ topicID: String, _ content: ContentCatalog) -> String {
        content.topics.first { $0.id == topicID }?.name ?? topicID
    }

}

extension GameState {
    /// The refusal the button shows, without the app having to know the
    /// engine's argument list.
    public func espionageRefusal(
        for operation: EspionageOperation,
        against rivalID: UUID,
        balance: BalanceConfig
    ) -> EspionageRefusal? {
        EspionageSystem.refusal(operation, against: rivalID, state: self, balance: balance)
    }

    /// The odds on the button, which are the odds the engine rolls.
    public func espionageOdds(
        for operation: EspionageOperation,
        against rivalID: UUID,
        balance: BalanceConfig
    ) -> (success: Double, trace: Double) {
        guard let rival = rivals.rival(id: rivalID) else { return (0, 0) }
        let success = Espionage.successChance(
            operation,
            rival: rival,
            skill: life.skills.crimeValue(for: .marketKnowledge),
            dossier: espionage.dossier(on: rivalID),
            day: day,
            balance: balance.espionage
        )
        let trace = Espionage.traceChance(
            operation,
            landed: true,
            notoriety: crime.notoriety,
            hasLegal: knownDepartments.contains(.legal),
            balance: balance.espionage,
            crime: balance.crime,
            // MARK: J2 (record)
            spotlight: standingSpotlight(balance: balance)
            // MARK: end J2
        )
        return (success, trace)
    }
}
