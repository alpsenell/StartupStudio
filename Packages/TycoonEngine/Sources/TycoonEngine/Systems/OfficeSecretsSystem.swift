import Foundation
import TycoonContent

/// The office has secrets (iteration 11, N5).
///
/// Six slow-burn threads — a mole, a romance across a reporting line, an
/// expense line that has been carrying somebody, a clique around the
/// newest hire, a union drive, and a co-founder counting votes. Each is a
/// small state machine: a start condition, three stages that each drop a
/// clue the founder can actually read (a journal beat, a message from a
/// third party, a change in the room, a line in the ledger), and an ending
/// if nobody does anything about it.
///
/// **The gate.** Everything below `state.secrets.watching` belongs to a
/// run the player is playing: the app sets it the first time the Team tab
/// is opened (`.watchTheOffice`), and nothing else does. A pacing bot, a
/// fixture replay and every headless pass never switch tabs, so they never
/// reach a read, a roll or a write here — `state.secrets` stays `.empty`
/// and is never encoded.
///
/// **Randomness.** No draw from `rng`, `worldRNG` or the shared
/// `socialRNG`: the weekly start roll and every pick inside a thread come
/// from a private stream derived from `state.seed` and the day, built and
/// discarded in place. Same seed, same office, same secrets.
public enum OfficeSecretsSystem {

    // MARK: - The daily pass

    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        // The gate. Nothing above this line reads anything but the flag.
        guard state.secrets.watching, state.gameOver == nil else { return [] }

        var events: [GameEvent] = []
        events.append(contentsOf: advance(&state, balance, content))
        events.append(contentsOf: startCheck(&state, balance, content))
        return events
    }

    /// A private stream: `state.seed`, the day, and a per-purpose salt.
    /// Built where it is used and thrown away, so nothing about it is
    /// persisted and no shared stream moves.
    private static func stream(_ state: GameState, _ salt: UInt64) -> SeededRNG {
        SeededRNG(
            seed: state.seed
                &* 0x9E37_79B9_7F4A_7C15
                &+ UInt64(bitPattern: Int64(state.day)) &* 0x0000_0100_0000_01B3
                &+ salt
        )
    }

    // MARK: - Starting one

    /// One weekly roll, and only when everything else already allows a
    /// thread: past `minDay`, past `minHeadcount`, nothing running, a gap
    /// since the last one, and at least one kind whose own condition is
    /// true today.
    private static func startCheck(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        let config = balance.officeSecrets
        guard state.day % GameState.daysPerWeek == 0,
              state.day >= config.minDay,
              state.headcount >= config.minHeadcount,
              state.secrets.open == nil,
              state.secrets.history.count < SecretKind.allCases.count
        else { return [] }
        if let last = state.secrets.lastClosedDay, state.day - last < config.gapDays { return [] }

        let eligible = SecretKind.allCases.filter { kind in
            !state.secrets.history.contains(kind.rawValue) && canStart(kind, state, balance)
        }
        guard !eligible.isEmpty else { return [] }

        var rng = stream(state, 0x5EC1_5EC1)
        guard rng.nextUniform() < config.startChance else { return [] }
        let kind = eligible[rng.nextInt(in: 0...(eligible.count - 1))]
        return start(kind, &state, balance, content, rng: &rng)
    }

    /// What has to be true of the company for each kind to be possible.
    /// Pure — no draws, no writes.
    static func canStart(_ kind: SecretKind, _ state: GameState, _ balance: BalanceConfig) -> Bool {
        let hired = state.employees.filter { !$0.isFounder }
        switch kind {
        case .mole:
            return !state.rivals.rivals.isEmpty && !hired.isEmpty && leakableTopic(state) != nil
        case .romance:
            return pair(in: state) != nil
        case .embezzlement:
            return hired.count >= 5
                && state.company.cash >= balance.officeSecrets.embezzledPerStage * 6
        case .clique:
            return hired.count >= 4 && newestHire(state) != nil
        case .unionDrive:
            guard hired.count >= 6 else { return false }
            let recentRound = state.investors.rounds.contains {
                state.day - $0.day <= GameState.daysPerWeek * 2
            }
            let averageMorale = hired.reduce(0) { $0 + $1.morale } / Double(hired.count)
            return recentRound && averageMorale < 65
        case .coup:
            guard state.origin == .cofounded, let cofounder = state.cofounder else {
                return false
            }
            return hired.count >= 5
                && (state.investors.boardPressure >= 30 || cofounder.founderBond <= 45)

        // MARK: W3 (espionage) — the three a rival runs against you
        //
        // None of them can start until a studio actually has a reason:
        // `Rival.grudge` past the balance's line, which only ever gets
        // there because the founder did something to them (N2's taunts,
        // W3's own operations). A run that has never touched a rival never
        // sees one.
        case .rivalMole:
            return angryRival(state, balance) != nil && !hired.isEmpty && leakableTopic(state) != nil
        case .rivalTail:
            // They are looking for something, so there has to be something
            // to find: a record, or an operation of the founder's own.
            return angryRival(state, balance) != nil
                && (!state.crime.record.isEmpty || state.espionage != .empty)
        case .rivalHack:
            return angryRival(state, balance) != nil && state.products.contains { product in
                if case .released(let info) = product.stage { return !info.offMarket }
                return false
            }
        // MARK: end W3
        }
    }

    // MARK: W3 (espionage)

    /// The studio angry enough to be running something here: the highest
    /// grudge past the line. Pure — no draws, no writes.
    static func angryRival(_ state: GameState, _ balance: BalanceConfig) -> Rival? {
        state.rivals.rivals
            .filter { $0.grudge >= balance.espionage.rivalGrudgeToAct }
            .sorted { ($0.grudge, $0.id.uuidString) > ($1.grudge, $1.id.uuidString) }
            .first
    }

    // MARK: end W3

    /// The topic a mole would have something worth selling in: the newest
    /// build in development, else the newest thing on the market.
    private static func leakableTopic(_ state: GameState) -> String? {
        if let inDevelopment = state.products.last(where: {
            if case .development = $0.stage { return true }
            return false
        }) {
            return inDevelopment.topicID
        }
        return state.products.last?.topicID
    }

    /// The strongest bond between two people still on payroll, where one of
    /// them out-ranks the other — the reporting line is the problem, not
    /// the romance.
    private static func pair(in state: GameState) -> (senior: UUID, junior: UUID)? {
        let byID = Dictionary(uniqueKeysWithValues: state.employees.map { ($0.id, $0) })
        let candidates = state.friendships
            .filter { $0.strength >= 55 }
            .compactMap { friendship -> (senior: UUID, junior: UUID, strength: Double)? in
                guard let a = byID[friendship.a], let b = byID[friendship.b],
                      !a.isFounder, !b.isFounder,
                      a.level.rank != b.level.rank
                else { return nil }
                let senior = a.level.rank > b.level.rank ? a : b
                let junior = a.level.rank > b.level.rank ? b : a
                return (senior.id, junior.id, friendship.strength)
            }
            .sorted {
                $0.strength != $1.strength
                    ? $0.strength > $1.strength
                    : $0.senior.uuidString < $1.senior.uuidString
            }
        guard let best = candidates.first else { return nil }
        return (best.senior, best.junior)
    }

    /// The newest hire, if they are new enough to still be new.
    private static func newestHire(_ state: GameState) -> Employee? {
        state.employees
            .filter { !$0.isFounder && state.day - $0.hiredDay <= 60 }
            .sorted { ($0.hiredDay, $0.id.uuidString) > ($1.hiredDay, $1.id.uuidString) }
            .first
    }

    /// Everyone who is not the founder, in a stable order.
    private static func roster(_ state: GameState) -> [Employee] {
        state.employees.filter { !$0.isFounder }.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    /// Opens the thread: the people in it, the first stage's clue, and the
    /// journal beat that says something is off without saying what.
    private static func start(
        _ kind: SecretKind,
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog,
        rng: inout SeededRNG
    ) -> [GameEvent] {
        let people = cast(for: kind, state, &rng)
        guard !people.isEmpty else { return [] }

        var thread = SecretThread(
            id: "\(kind.rawValue)-\(state.day)",
            kind: kind.rawValue,
            startedDay: state.day,
            stage: 0,
            employeeIDs: people,
            nextStageDay: state.day + balance.officeSecrets.stageDays
        )
        if kind == .mole { thread.topicID = leakableTopic(state) }
        // MARK: W3 (espionage) — their mole is selling the same roadmap
        if kind == .rivalMole { thread.topicID = leakableTopic(state) }
        // MARK: end W3

        state.secrets.threads.append(thread)
        trim(&state)
        var events: [GameEvent] = [.secretThreadStarted(kind: kind.rawValue, day: state.day)]
        events.append(contentsOf: landStage(kind, stage: 0, state: &state, balance: balance, content: content))
        return events
    }

    /// Who is in a thread. The order matters: index 0 is the person a
    /// confrontation is with.
    private static func cast(
        for kind: SecretKind,
        _ state: GameState,
        _ rng: inout SeededRNG
    ) -> [UUID] {
        let hired = roster(state)
        guard !hired.isEmpty else { return [] }
        switch kind {
        case .mole:
            // Somebody with the tenure to have something worth selling and
            // the loyalty to have thought about it.
            let plausible = hired.filter { state.day - $0.hiredDay >= 60 }
            let pool = plausible.isEmpty ? hired : plausible
            let lowest = pool.sorted { ($0.loyalty, $0.id.uuidString) < ($1.loyalty, $1.id.uuidString) }
            return [lowest[0].id]
        case .romance:
            guard let pair = pair(in: state) else { return [] }
            return [pair.senior, pair.junior]
        case .embezzlement:
            let pick = hired[rng.nextInt(in: 0...(hired.count - 1))]
            return [pick.id]
        case .clique:
            guard let newest = newestHire(state) else { return [] }
            let others = hired.filter { $0.id != newest.id }
                .sorted { ($0.hiredDay, $0.id.uuidString) < ($1.hiredDay, $1.id.uuidString) }
            // The ringleader first, then whoever else is at the table, then
            // the person outside it — last, so `employeeIDs.last` is always
            // the one being left out.
            return Array(others.prefix(3).map(\.id)) + [newest.id]
        case .unionDrive:
            let organiser = hired
                .sorted { ($0.morale, $0.id.uuidString) < ($1.morale, $1.id.uuidString) }[0]
            return [organiser.id]
        case .coup:
            guard let cofounder = state.cofounder else { return [] }
            return [cofounder.id]

        // MARK: W3 (espionage)
        case .rivalMole:
            // The one who would take the second salary.
            let lowest = hired.sorted {
                ($0.loyalty, $0.id.uuidString) < ($1.loyalty, $1.id.uuidString)
            }
            return [lowest[0].id]
        case .rivalTail:
            // Whoever is around late enough to notice the car.
            let longest = hired.sorted {
                ($0.hiredDay, $0.id.uuidString) < ($1.hiredDay, $1.id.uuidString)
            }
            return [longest[0].id]
        case .rivalHack:
            // Whoever's credentials it was.
            let senior = hired.sorted {
                ($0.level.rank, $0.id.uuidString) > ($1.level.rank, $1.id.uuidString)
            }
            return [senior[0].id]
        // MARK: end W3
        }
    }

    private static func trim(_ state: inout GameState) {
        let overflow = state.secrets.threads.count - OfficeSecretsState.maxThreads
        if overflow > 0 {
            // Oldest closed ones go first; a live thread is never dropped.
            for _ in 0..<overflow {
                guard let index = state.secrets.threads.firstIndex(where: { !$0.isOpen }) else { break }
                state.secrets.threads.remove(at: index)
            }
        }
    }

    // MARK: - Running one

    /// Moves the open thread on when its next stage is due. Stage 3 is the
    /// ending: the thread closes as `ignored`.
    private static func advance(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        guard let open = state.secrets.open,
              let kind = open.secretKind,
              state.day >= open.nextStageDay
        else { return [] }

        // A thread whose people have left the company dies with them.
        let present = Set(state.employees.map(\.id))
        guard open.employeeIDs.allSatisfy(present.contains) else {
            return close(kind, ending: .departed, state: &state, balance: balance, content: content)
        }

        let next = open.stage + 1
        if next >= 3 {
            return finish(kind, state: &state, balance: balance, content: content)
        }
        let today = state.day
        update(kind, in: &state) { thread in
            thread.stage = next
            thread.nextStageDay = today + balance.officeSecrets.stageDays
        }
        return landStage(kind, stage: next, state: &state, balance: balance, content: content)
    }

    /// Everything a stage does: the clue on the card, the phone message,
    /// the prop in the room, the ledger line, and the journal beat.
    private static func landStage(
        _ kind: SecretKind,
        stage: Int,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard let thread = state.secrets.open else { return [] }
        let beat = beat(kind, stage: stage, thread: thread, state: state, balance: balance)

        addClue(kind, text: beat.clue, source: beat.source, state: &state)
        if let prop = beat.prop {
            update(kind, in: &state) { thread in
                if !thread.props.contains(prop) { thread.props.append(prop) }
            }
        }
        if let message = beat.message, let speaker = beat.speaker {
            state.life.phone.post(message, from: .employee(speaker), day: state.day)
        } else if let message = beat.message {
            state.life.phone.post(message, from: .office, day: state.day)
        }
        if let line = beat.ledger {
            state.company.cash -= line.amount
            state.ledger.post(LedgerEntry(
                day: state.day, amount: -line.amount, category: .other, label: line.label
            ))
            update(kind, in: &state) { $0.taken += line.amount }
        }

        var events: [GameEvent] = [
            .secretClueFound(kind: kind.rawValue, text: beat.clue, day: state.day)
        ]
        if let def = content.event(kind.eventID("s\(stage + 1)")) {
            events.append(contentsOf: NarrativeSystem.fireCompany(def, state: &state, balance: balance))
        }
        return events
    }

    /// One stage's content, in the game's voice. Nothing here writes.
    private struct Beat {
        var clue: String
        var source: SecretClueSource
        var prop: SecretOfficeProp?
        var message: String?
        var speaker: UUID?
        var ledger: (amount: Int, label: String)?
    }

    private static func beat(
        _ kind: SecretKind,
        stage: Int,
        thread: SecretThread,
        state: GameState,
        balance: BalanceConfig
    ) -> Beat {
        let names = thread.employeeIDs.map { id in state.employee(id: id)?.name ?? "Somebody" }
        let first = names.first ?? "Somebody"
        let second = names.count > 1 ? names[1] : "somebody"
        let outsider = names.last ?? "the new hire"
        let witness = roster(state).first { !thread.employeeIDs.contains($0.id) }

        switch (kind, stage) {
        case (.mole, 0):
            return Beat(
                clue: "A rival's changelog used a build number that has never left this room.",
                source: .journal
            )
        case (.mole, 1):
            return Beat(
                clue: "The badge log has somebody in here on a Sunday, twice, with nothing shipped.",
                source: .office,
                prop: .shredder,
                message: "There is a shredder by the printer now. Nobody ordered a shredder.",
                speaker: witness?.id
            )
        case (.mole, _):
            return Beat(
                clue: "Two taxis home at 02:40, both booked to a project that finished in spring.",
                source: .ledger,
                ledger: (balance.officeSecrets.embezzledPerStage / 4, "Late taxi, unbudgeted")
            )

        case (.romance, 0):
            return Beat(
                clue: "\(first) has written \(second)'s last three reviews, and they read like fan mail.",
                source: .journal
            )
        case (.romance, 1):
            return Beat(
                clue: "\(second) has stopped using their own desk.",
                source: .office,
                prop: .sharedDesk,
                message: "Not my business, but the two of them arrive in the same car now.",
                speaker: witness?.id
            )
        case (.romance, _):
            return Beat(
                clue: "\(first) approved \(second)'s raise on a Friday and told nobody on the Monday.",
                source: .ledger,
                ledger: (0, "Off-cycle raise approved by \(first)")
            )

        case (.embezzlement, 0):
            return Beat(
                clue: "The expense line is up, and none of the receipts have a company name on them.",
                source: .ledger,
                ledger: (balance.officeSecrets.embezzledPerStage, "Team expenses, unitemised")
            )
        case (.embezzlement, 1):
            return Beat(
                clue: "Four hotel nights in a city the company has never sold anything in.",
                source: .ledger,
                prop: .shredder,
                message: "Finance asked me to ask you whether the offsite was approved. There was no offsite.",
                speaker: witness?.id,
                ledger: (balance.officeSecrets.embezzledPerStage, "Offsite accommodation")
            )
        case (.embezzlement, _):
            return Beat(
                clue: "A supplier nobody can find invoiced twice in one week and was paid both times.",
                source: .ledger,
                ledger: (balance.officeSecrets.embezzledPerStage, "Supplier invoice — Aldgate Logistics")
            )

        case (.clique, 0):
            return Beat(
                clue: "Lunch goes out at half past twelve, and \(outsider) is never asked.",
                source: .office,
                prop: .sharedDesk
            )
        case (.clique, 1):
            return Beat(
                clue: "\(outsider) has been left off the invite for a meeting about their own work.",
                source: .phone,
                message: "Is there a channel I should be in? People keep referring to decisions I have not seen.",
                speaker: thread.employeeIDs.last
            )
        case (.clique, _):
            return Beat(
                clue: "\(first) rewrote \(outsider)'s work over a weekend and did not tell them.",
                source: .journal
            )

        case (.unionDrive, 0):
            return Beat(
                clue: "The meeting room is booked every Thursday at six by somebody with no meetings.",
                source: .office,
                prop: .closedDoor
            )
        case (.unionDrive, 1):
            return Beat(
                clue: "A card-signing form was left in the printer tray, face down.",
                source: .office,
                prop: .shredder,
                message: "Half the floor was in that room and the door was shut. I thought you should hear it from me.",
                speaker: witness?.id
            )
        case (.unionDrive, _):
            return Beat(
                clue: "\(first) has hired an advisor, and the invoice came to the company by mistake.",
                source: .ledger,
                ledger: (balance.officeSecrets.embezzledPerStage / 2, "Advisory retainer — misaddressed")
            )

        case (.coup, 0):
            return Beat(
                clue: "\(first) has had two calls with a board member that you were not on.",
                source: .journal,
                prop: .closedDoor
            )
        case (.coup, 1):
            return Beat(
                clue: "A deck called *Leadership options* was left open on the meeting-room screen.",
                source: .office,
                prop: .closedDoor,
                message: "Your co-founder asked me what I would do if there were a vote. I said I would ask you.",
                speaker: witness?.id
            )
        case (.coup, _):
            return Beat(
                clue: "\(first) has counted the votes twice and started rounding up.",
                source: .journal
            )

        // MARK: W3 (espionage)

        case (.rivalMole, 0):
            return Beat(
                clue: "A competitor's job ad quotes a sentence from your own internal deck.",
                source: .journal
            )
        case (.rivalMole, 1):
            return Beat(
                clue: "\(first) has a second phone, and it only ever rings outside.",
                source: .office,
                prop: .sharedDesk,
                message: "This is probably nothing. \(first) took a call in the stairwell again.",
                speaker: witness?.id
            )
        case (.rivalMole, _):
            return Beat(
                clue: "Somebody exported the roadmap on a Sunday and it went to a personal address.",
                source: .ledger,
                prop: .shredder,
                ledger: (0, "Storage export, out of hours")
            )

        case (.rivalTail, 0):
            return Beat(
                clue: "The same estate car has been at the end of your street four evenings running.",
                source: .office
            )
        case (.rivalTail, 1):
            return Beat(
                clue: "Somebody rang your old landlord asking, politely, about the year you left.",
                source: .phone,
                message: "A researcher called about you. They knew which years to ask about.",
                speaker: witness?.id
            )
        case (.rivalTail, _):
            return Beat(
                clue: "A journalist you have never met has three dates from your calendar and one photograph.",
                source: .journal,
                prop: .closedDoor
            )

        case (.rivalHack, 0):
            return Beat(
                clue: "The storefront logged four thousand failed sign-ins from one address overnight.",
                source: .journal
            )
        case (.rivalHack, 1):
            return Beat(
                clue: "\(first)'s account signed in from a city nobody here has been to.",
                source: .office,
                prop: .closedDoor,
                message: "I did not log in at four in the morning. I would like that on the record.",
                speaker: thread.employeeIDs.first
            )
        case (.rivalHack, _):
            return Beat(
                clue: "Somebody has been in the payments dashboard, reading and changing nothing.",
                source: .ledger,
                prop: .shredder,
                ledger: (0, "Security review, unbudgeted")
            )

        // MARK: end W3
        }
    }

    private static func addClue(
        _ kind: SecretKind,
        text: String,
        source: SecretClueSource,
        state: inout GameState
    ) {
        let today = state.day
        update(kind, in: &state) { thread in
            guard !thread.clues.contains(where: { $0.text == text }) else { return }
            thread.clues.append(SecretClue(
                id: thread.clues.count, day: today, text: text, source: source
            ))
        }
    }

    /// Edits the open thread in place.
    private static func update(
        _ kind: SecretKind,
        in state: inout GameState,
        _ edit: (inout SecretThread) -> Void
    ) {
        guard let index = state.secrets.threads.firstIndex(where: {
            $0.kind == kind.rawValue && $0.isOpen
        }) else { return }
        edit(&state.secrets.threads[index])
    }

    // MARK: - Endings

    /// The ending nobody chose: what the thread was always going to do.
    private static func finish(
        _ kind: SecretKind,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard let thread = state.secrets.open else { return [] }
        let config = balance.officeSecrets
        var events: [GameEvent] = []

        switch kind {
        case .mole:
            events.append(contentsOf: leakRoadmap(thread, state: &state, balance: balance, content: content))
            if let id = thread.employeeIDs.first {
                events.append(contentsOf: walkOut(id, state: &state, balance: balance))
            }
        case .romance:
            // The couple splits, and the junior one is the one who goes.
            if let junior = thread.employeeIDs.last {
                events.append(contentsOf: walkOut(junior, state: &state, balance: balance))
            }
            moraleAll(config.badEndingMoraleAll, state: &state)
        case .embezzlement:
            let final = config.embezzledPerStage * 3
            state.company.cash -= final
            state.ledger.post(LedgerEntry(
                day: state.day, amount: -final, category: .other,
                label: "Unreconciled expenses, written off"
            ))
            if let id = thread.employeeIDs.first {
                events.append(contentsOf: walkOut(id, state: &state, balance: balance))
            }
            state.company.reputation = clamp(state.company.reputation + config.badEndingReputation)
        case .clique:
            if let outsider = thread.employeeIDs.last {
                events.append(contentsOf: walkOut(outsider, state: &state, balance: balance))
            }
            moraleAll(config.badEndingMoraleAll, state: &state)
        case .unionDrive:
            events.append(contentsOf: recogniseUnion(state: &state, balance: balance))
        case .coup:
            events.append(contentsOf: theVote(thread, state: &state, balance: balance))

        // MARK: W3 (espionage) — what somebody else's operation does when
        // nobody answers it.
        case .rivalMole:
            // Exactly what your own mole does to somebody else: the
            // roadmap ships, in somebody else's colours.
            events.append(contentsOf: leakRoadmap(
                thread, state: &state, balance: balance, content: content
            ))
            if let id = thread.employeeIDs.first {
                events.append(contentsOf: walkOut(id, state: &state, balance: balance))
            }
        case .rivalTail:
            // They found something, and gave it to somebody who prints.
            state.company.reputation = clamp(
                state.company.reputation - balance.espionage.rivalOperationReputationHit
            )
            if let entry = state.crime.openRecord.last, state.crime.pendingCase == nil {
                events.append(contentsOf: CrimeSystem.raiseCase(
                    against: entry, state: &state, balance: balance
                ))
            } else {
                state.life.phone.post(
                    "There is a piece about you. It is not wrong, which is the problem.",
                    from: .office, day: state.day
                )
            }
        case .rivalHack:
            // A week of error pages, on your side of it this time.
            state.company.reputation = clamp(
                state.company.reputation - balance.espionage.rivalOperationReputationHit
            )
            for index in state.products.indices {
                guard case .released(var info) = state.products[index].stage, !info.offMarket
                else { continue }
                info.liveHype = max(0, info.liveHype * (1 - balance.espionage.hackUnitsFraction))
                info.liveBugs += 2
                state.products[index].stage = .released(info)
            }
        // MARK: end W3
        }

        events.append(contentsOf: close(
            kind, ending: .ignored, state: &state, balance: balance, content: content
        ))
        return events
    }

    /// The mole's ending: a rival ships the topic the roadmap named. The
    /// clone is built here rather than in `RivalSystem.launchProduct`
    /// because that one draws from `worldRNG`, and nothing in this lane may.
    private static func leakRoadmap(
        _ thread: SecretThread,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard let topicID = thread.topicID ?? leakableTopic(state) else { return [] }
        let buyers = state.rivals.rivals.enumerated()
            .sorted { $0.element.strength > $1.element.strength }
        guard let buyer = buyers.first else { return [] }

        var rng = stream(state, 0x1EAC_1EAC)
        let words = content.names.productWords
        let first = words.isEmpty ? "Nimbus" : words[rng.nextInt(in: 0...(words.count - 1))]
        let second = words.isEmpty ? "Echo" : words[rng.nextInt(in: 0...(words.count - 1))]
        let name = first == second ? first : "\(first) \(second)"
        let quality = min(90, max(35, buyer.element.strength * 0.8 + 10))
        let clone = RivalProduct(
            id: UUID(from: &rng),
            name: name,
            topicID: topicID,
            typeID: content.productTypes.first?.id ?? "mobile_app",
            quality: quality,
            launchDay: state.day,
            weeklyUnits: Int((buyer.element.strength * 40 * (0.5 + quality / 200)).rounded())
        )
        RivalSystem.appendProduct(clone, to: buyer.offset, in: &state)
        state.rivals.rivals[buyer.offset].lastShippedDay = state.day
        if !state.rivals.rivals[buyer.offset].focusTopicIDs.contains(topicID) {
            state.rivals.rivals[buyer.offset].focusTopicIDs.append(topicID)
        }
        state.company.reputation = clamp(
            state.company.reputation + balance.officeSecrets.badEndingReputation
        )
        return [.rivalProductLaunched(
            rivalID: buyer.element.id,
            productName: clone.name,
            topicID: topicID,
            quality: Int(quality.rounded()),
            day: state.day
        )]
    }

    /// The union's ending: recognised the hard way. Everyone gets the
    /// floor, crunch stops being something the founder can pick, and the
    /// flag stays on the run.
    private static func recogniseUnion(
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        let percent = balance.officeSecrets.unionRaisePercent
        for index in state.employees.indices where !state.employees[index].isFounder {
            let salary = Double(state.employees[index].weeklySalary)
            state.employees[index].weeklySalary = Int((salary * (1 + percent / 100)).rounded())
            state.employees[index].morale = clamp(state.employees[index].morale + 6)
        }
        if state.economy.workPace == .crunch {
            state.economy.workPace = .normal
        }
        state.narrative.flags.insert(SecretFlag.unionRecognised)
        return []
    }

    /// The coup's ending. Only a co-founded run can be removed by one —
    /// anywhere else the vote is short and the co-founder leaves instead.
    private static func theVote(
        _ thread: SecretThread,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard state.origin == .cofounded, state.gameOver == nil else {
            if let id = thread.employeeIDs.first {
                return walkOut(id, state: &state, balance: balance)
            }
            return []
        }
        let name = state.cofounder?.name ?? "Your co-founder"
        state.gameOver = GameOverInfo(
            day: state.day,
            reason: "\(name) had the votes before you knew there was a count. "
                + "The board thanked you for your years and asked for your badge.",
            kind: .oustedByBoard
        )
        return [.founderOusted(day: state.day), .gameOver(day: state.day)]
    }

    /// Somebody walks, today, the way an unhappy employee always has.
    private static func walkOut(
        _ employeeID: UUID,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard let index = state.employees.firstIndex(where: { $0.id == employeeID }),
              !state.employees[index].isFounder
        else { return [] }
        let employee = state.employees.remove(at: index)
        state.economy.lastRecognitionDay[employee.id] = nil
        if state.economy.pendingResignation?.employeeID == employee.id {
            state.economy.pendingResignation = nil
        }
        var events: [GameEvent] = [
            .employeeQuit(employeeID: employee.id, name: employee.name, day: state.day)
        ]
        events.append(contentsOf: SocialSystem.friendDeparted(
            employee.id, state: &state, balance: balance
        ))
        events.append(contentsOf: NetworkingSystem.departed(
            employee, reason: .quit, state: &state, balance: balance
        ))
        return events
    }

    private static func moraleAll(_ delta: Double, state: inout GameState) {
        for index in state.employees.indices where !state.employees[index].isFounder {
            state.employees[index].morale = clamp(state.employees[index].morale + delta)
        }
    }

    /// Closes the open thread and files it.
    @discardableResult
    private static func close(
        _ kind: SecretKind,
        ending: SecretEnding,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        let today = state.day
        update(kind, in: &state) { thread in
            thread.closedDay = today
            thread.ending = ending.rawValue
        }
        if !state.secrets.history.contains(kind.rawValue) {
            state.secrets.history.append(kind.rawValue)
        }
        state.secrets.lastClosedDay = state.day
        var events: [GameEvent] = [
            .secretThreadEnded(kind: kind.rawValue, ending: ending.rawValue, day: state.day)
        ]
        let suffix: String
        switch ending {
        case .ignored: suffix = "end"
        case .handled: suffix = "hr"
        case .dealt: suffix = "deal"
        case .departed, .confronted: suffix = "faced"
        }
        if let def = content.event(kind.eventID(suffix)) {
            events.append(contentsOf: NarrativeSystem.fireCompany(def, state: &state, balance: balance))
        }
        return events
    }

    private static func clamp(_ value: Double) -> Double { min(100, max(0, value)) }

    // MARK: - The founder's answers

    /// Why a response is refused, or `nil` when it can be taken. The card
    /// shows the reason on the button, so nothing is ever greyed silently.
    public static func refusal(
        _ response: SecretResponse,
        state: GameState,
        balance: BalanceConfig
    ) -> SecretRefusal? {
        guard let thread = state.secrets.open else { return .noThread }
        if thread.hasUsed(response) { return .alreadyUsed }
        switch response {
        case .investigate:
            return state.hasEveningFree(balance) ? nil : .noEvening
        case .privateEye:
            return state.life.wallet >= balance.officeSecrets.privateEyeCost ? nil : .noWallet
        case .confront:
            return thread.named ? nil : .notNamed
        case .callHR:
            return state.hasDepartment(.hr) ? nil : .noHR
        case .makeDeal:
            let cost = dealCost(thread, balance)
            return state.company.cash >= cost ? nil : .noCompanyCash
        case .ignore:
            return nil

        // MARK: W3 (espionage) — counterintelligence
        //
        // Three answers that only exist for a thread somebody outside is
        // running, each refused in the founder's own words when it does
        // not apply.
        case .sweepOffice:
            guard thread.secretKind?.isRivalRun == true else { return .notRivalRun }
            return state.company.cash >= balance.espionage.sweepCost ? nil : .noCompanyCash
        case .auditRoster:
            guard thread.secretKind?.isRivalRun == true else { return .notRivalRun }
            return state.hasEveningFree(balance) ? nil : .noEvening
        case .feedFalsePlans:
            guard thread.secretKind?.isRivalRun == true else { return .notRivalRun }
            guard thread.secretKind == .rivalMole else { return .noMoleToFeed }
            return thread.named ? nil : .notNamed
        // MARK: end W3
        }
    }

    /// What a deal costs the company. The union's is the payroll it takes
    /// to agree the floor before somebody makes you; the rest is money.
    public static func dealCost(_ thread: SecretThread, _ balance: BalanceConfig) -> Int {
        switch thread.secretKind {
        case .embezzlement: return 0
        case .unionDrive: return balance.officeSecrets.dealCost / 2
        case .coup: return balance.officeSecrets.dealCost * 2
        default: return balance.officeSecrets.dealCost
        }
    }

    /// One answer. Refused answers return no events and change nothing.
    static func respond(
        _ response: SecretResponse,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard refusal(response, state: state, balance: balance) == nil,
              let thread = state.secrets.open,
              let kind = thread.secretKind
        else { return [] }

        update(kind, in: &state) { $0.usedResponses.append(response.rawValue) }

        switch response {
        case .investigate:
            state.spendEvening(balance)
            let today = state.day
            update(kind, in: &state) { thread in
                thread.named = true
                thread.nextStageDay = min(thread.nextStageDay, today + 2)
            }
            addClue(kind, text: namesLine(kind, thread, state), source: .journal, state: &state)
            return [.secretClueFound(
                kind: kind.rawValue, text: namesLine(kind, thread, state), day: state.day
            )]

        case .privateEye:
            let cost = balance.officeSecrets.privateEyeCost
            state.life.wallet -= cost
            update(kind, in: &state) { $0.named = true }
            addClue(kind, text: namesLine(kind, thread, state), source: .journal, state: &state)
            var events: [GameEvent] = []
            // Everything this thread had left to say, at once.
            for stage in (thread.stage + 1)..<3 {
                events.append(contentsOf: landStage(
                    kind, stage: stage, state: &state, balance: balance, content: content
                ))
            }
            let today = state.day
            update(kind, in: &state) { thread in
                thread.stage = 2
                thread.nextStageDay = today + balance.officeSecrets.stageDays
            }
            return events

        case .confront:
            return confront(kind, thread, state: &state, balance: balance, content: content)

        case .callHR:
            moraleAll(balance.officeSecrets.handledMoraleAll, state: &state)
            if kind == .clique || kind == .romance, let subject = thread.employeeIDs.last,
               let index = state.employees.firstIndex(where: { $0.id == subject }) {
                state.employees[index].assignment = .idle
                state.employees[index].morale = clamp(state.employees[index].morale + 10)
            }
            state.narrative.flags.insert(SecretFlag.handled)
            return close(kind, ending: .handled, state: &state, balance: balance, content: content)

        case .makeDeal:
            return makeDeal(kind, thread, state: &state, balance: balance, content: content)

        case .ignore:
            // The founder chose the ending. It comes at the end of the week
            // rather than the end of the season.
            let today = state.day
            update(kind, in: &state) { thread in
                thread.stage = 2
                thread.nextStageDay = today + 3
            }
            return []

        // MARK: W3 (espionage) — counterintelligence

        case .sweepOffice:
            // A van, two people and an afternoon. Whatever they left is
            // in a bag by five, and the studio that put it there has
            // something else to be annoyed about.
            let cost = balance.espionage.sweepCost
            state.company.cash -= cost
            state.ledger.post(LedgerEntry(
                day: state.day, amount: -cost, category: .other,
                label: "Counter-surveillance sweep"
            ))
            if let rival = angryRival(state, balance) {
                RivalSystem.espionageCoolGrudge(
                    rival.id, by: balance.espionage.sweepGrudgeRelief, state: &state
                )
            }
            var swept: [GameEvent] = [.counterEspionageAnswered(
                kind: kind.rawValue, response: response.rawValue, day: state.day
            )]
            swept.append(contentsOf: close(
                kind, ending: .handled, state: &state, balance: balance, content: content
            ))
            return swept

        case .auditRoster:
            // An evening with the badge log, the payroll and the roster.
            // It names them; on a mole it also ends them.
            state.spendEvening(balance)
            update(kind, in: &state) { $0.named = true }
            addClue(kind, text: namesLine(kind, thread, state), source: .ledger, state: &state)
            var audited: [GameEvent] = [
                .secretClueFound(
                    kind: kind.rawValue, text: namesLine(kind, thread, state), day: state.day
                ),
                .counterEspionageAnswered(
                    kind: kind.rawValue, response: response.rawValue, day: state.day
                ),
            ]
            if kind == .rivalMole, let id = thread.employeeIDs.first {
                audited.append(contentsOf: walkOut(id, state: &state, balance: balance))
                audited.append(contentsOf: close(
                    kind, ending: .departed, state: &state, balance: balance, content: content
                ))
            } else {
                let today = state.day
                update(kind, in: &state) { thread in
                    thread.nextStageDay = min(thread.nextStageDay, today + 2)
                }
            }
            return audited

        case .feedFalsePlans:
            // Leave the mole exactly where they are and give them a
            // quarter's work in a category that is on its way down.
            var fed: [GameEvent] = [.counterEspionageAnswered(
                kind: kind.rawValue, response: response.rawValue, day: state.day
            )]
            if let rival = angryRival(state, balance) {
                let topicID = RivalSystem.espionageFalsePlans(
                    rival.id, state: &state, balance: balance
                )
                state.life.phone.post(
                    topicID.map {
                        "They have gone all in on \($0). We wrote that page for them."
                    } ?? "They have gone all in on the wrong thing. We wrote it for them.",
                    from: .office, day: state.day
                )
            }
            fed.append(contentsOf: close(
                kind, ending: .dealt, state: &state, balance: balance, content: content
            ))
            return fed
        // MARK: end W3
        }
    }

    /// "It is Priya." — the line an investigation or a PI buys.
    private static func namesLine(_ kind: SecretKind, _ thread: SecretThread, _ state: GameState) -> String {
        let names = thread.employeeIDs.compactMap { state.employee(id: $0)?.name }
        switch kind {
        case .mole:
            return "It is \(names.first ?? "somebody"), and they have been paid twice."
        case .romance:
            return "\(names.first ?? "One of them") and \(names.count > 1 ? names[1] : "the other") "
                + "have been together since spring."
        case .embezzlement:
            return "Every unmatched receipt was filed by \(names.first ?? "one person")."
        case .clique:
            return "\(names.first ?? "The ringleader") sets the table, and "
                + "\(names.last ?? "the new hire") is the one left off it."
        case .unionDrive:
            return "\(names.first ?? "The organiser") is the one booking the room."
        case .coup:
            return "\(names.first ?? "Your co-founder") has three of the five votes."
        // MARK: W3 (espionage)
        case .rivalMole:
            return "It is \(names.first ?? "somebody"), and the second salary is bigger than yours."
        case .rivalTail:
            return "The car is hired, and the invoice goes to a studio you have annoyed."
        case .rivalHack:
            return "They came in on \(names.first ?? "somebody")'s credentials, from a coffee shop abroad."
        // MARK: end W3
        }
    }

    /// The confrontation: a staff moment for the person at the front of the
    /// thread, raised through exactly the machinery every other staff
    /// moment uses — the same sheet, the same two answers, the same
    /// deadline that answers for a founder who says nothing.
    private static func confront(
        _ kind: SecretKind,
        _ thread: SecretThread,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard let employeeID = thread.employeeIDs.first,
              state.employee(id: employeeID) != nil,
              state.pendingStaffEvent == nil
        else { return [] }

        let event = StaffEvent(
            employeeID: employeeID,
            kind: kind.staffEventKind,
            respondByDay: state.day + balance.social.staffEventResponseDays,
            defID: kind.confrontDefID
        )
        state.pendingStaffEvent = event
        PhoneMirror.staffRaised(event, state: &state, content: content)
        var events: [GameEvent] = [.staffEventOccurred(
            employeeID: employeeID,
            kind: kind.staffEventKind,
            respondByDay: event.respondByDay,
            day: state.day
        )]
        events.append(contentsOf: close(
            kind, ending: .confronted, state: &state, balance: balance, content: content
        ))
        return events
    }

    /// The deal: money, a policy, or a line moved. Each kind's is the thing
    /// that would actually make it stop.
    private static func makeDeal(
        _ kind: SecretKind,
        _ thread: SecretThread,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        let config = balance.officeSecrets
        let cost = dealCost(thread, balance)
        if cost > 0 {
            state.company.cash -= cost
            state.ledger.post(LedgerEntry(
                day: state.day, amount: -cost, category: .other,
                label: dealLabel(kind, thread, state)
            ))
        }
        switch kind {
        case .mole:
            // Counter-offer: they stay, they cost more, and they know you
            // know.
            if let id = thread.employeeIDs.first,
               let index = state.employees.firstIndex(where: { $0.id == id }) {
                state.employees[index].weeklySalary = Int(
                    (Double(state.employees[index].weeklySalary) * 1.15).rounded()
                )
                state.employees[index].loyalty = clamp(state.employees[index].loyalty + 20)
                state.employees[index].morale = clamp(state.employees[index].morale - 6)
            }
        case .romance:
            // The reporting line moves, not the people.
            if let junior = thread.employeeIDs.last,
               let index = state.employees.firstIndex(where: { $0.id == junior }) {
                state.employees[index].assignment = .idle
                state.employees[index].morale = clamp(state.employees[index].morale + 8)
            }
        case .embezzlement:
            // Quiet repayment: the money comes back over time, and nobody
            // outside the room hears about it.
            let recovered = thread.taken
            state.company.cash += recovered
            state.ledger.post(LedgerEntry(
                day: state.day, amount: recovered, category: .other,
                label: "Repayment agreed, no police"
            ))
            if let id = thread.employeeIDs.first,
               let index = state.employees.firstIndex(where: { $0.id == id }) {
                state.employees[index].loyalty = clamp(state.employees[index].loyalty - 30)
            }
        case .clique:
            // A table big enough for everybody, on the company.
            moraleAll(config.handledMoraleAll, state: &state)
            if let outsider = thread.employeeIDs.last,
               let index = state.employees.firstIndex(where: { $0.id == outsider }) {
                state.employees[index].morale = clamp(state.employees[index].morale + 14)
            }
        case .unionDrive:
            // Voluntary recognition, before it is taken from you.
            for index in state.employees.indices where !state.employees[index].isFounder {
                state.employees[index].morale = clamp(state.employees[index].morale + 8)
                state.employees[index].loyalty = clamp(state.employees[index].loyalty + 6)
            }
            state.narrative.flags.insert(SecretFlag.unionRecognised)
        case .coup:
            // Title and equity for the person who was going to take them.
            state.investors.boardPressure = min(
                100, state.investors.boardPressure + config.coupBoardPressure
            )
            if let id = thread.employeeIDs.first,
               let index = state.employees.firstIndex(where: { $0.id == id }) {
                state.employees[index].founderBond = clamp(state.employees[index].founderBond + 25)
                state.employees[index].loyalty = clamp(state.employees[index].loyalty + 20)
            }

        // MARK: W3 (espionage)
        case .rivalMole:
            // Pay the person more than the studio paying them is paying
            // them. It works, and everyone knows what it was.
            if let id = thread.employeeIDs.first,
               let index = state.employees.firstIndex(where: { $0.id == id }) {
                state.employees[index].weeklySalary = Int(
                    (Double(state.employees[index].weeklySalary) * 1.15).rounded()
                )
                state.employees[index].loyalty = clamp(state.employees[index].loyalty + 18)
                state.employees[index].morale = clamp(state.employees[index].morale - 4)
            }
        case .rivalTail:
            // Lawyers write to lawyers and the car stops coming.
            if let rival = angryRival(state, balance) {
                RivalSystem.espionageCoolGrudge(
                    rival.id, by: balance.espionage.sweepGrudgeRelief, state: &state
                )
            }
        case .rivalHack:
            // A retainer, a rotation of every key, and a fortnight of
            // everybody typing new passwords.
            moraleAll(-2, state: &state)
        // MARK: end W3
        }
        return close(kind, ending: .dealt, state: &state, balance: balance, content: content)
    }

    private static func dealLabel(_ kind: SecretKind, _ thread: SecretThread, _ state: GameState) -> String {
        let name = thread.employeeIDs.first.flatMap { state.employee(id: $0)?.name } ?? "one of yours"
        switch kind {
        case .mole: return "Retention counter-offer: \(name)"
        case .romance: return "Reporting line moved"
        case .embezzlement: return "Settlement agreed"
        case .clique: return "A table big enough for everyone"
        case .unionDrive: return "Voluntary recognition"
        case .coup: return "Equity settlement: \(name)"
        // MARK: W3 (espionage)
        case .rivalMole: return "Retention counter-offer: \(name)"
        case .rivalTail: return "A quiet word, through lawyers"
        case .rivalHack: return "Security retainer"
        // MARK: end W3
        }
    }

    /// Every `office_*` company event this system fires itself. They are
    /// all `followUpOnly`, so the company-event roll never draws one and a
    /// run that never watches its own office never sees one — this set is
    /// how the content suite knows they are reachable all the same, the
    /// way `ChildhoodSystem.stageBeatIDs` does for the childhood beats.
    static let scheduledEventIDs: Set<String> = Set(
        SecretKind.allCases.flatMap { kind in
            ["s1", "s2", "s3", "end", "hr", "deal", "faced"].map { kind.eventID($0) }
        }
    )

    // MARK: - The gate, and the screenshot flag

    /// The Team tab has been opened: threads may start from here. Idempotent.
    static func watch(_ state: inout GameState) -> [GameEvent] {
        guard !state.secrets.watching else { return [] }
        state.secrets.watching = true
        return []
    }

    /// `-autoSecret <kind>`: starts one now, for a screenshot. Debug only —
    /// the reducer applies it under `#if DEBUG` and nothing in the game
    /// sends it.
    static func seed(
        _ kind: SecretKind,
        stage: Int,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard state.secrets.open == nil else { return [] }
        state.secrets.watching = true
        var rng = stream(state, 0xDEB6_DEB6)
        var events = start(kind, &state, balance, content, rng: &rng)
        for next in 1...max(1, min(2, stage)) {
            let today = state.day
            update(kind, in: &state) { thread in
                thread.stage = next
                thread.nextStageDay = today + balance.officeSecrets.stageDays
            }
            events.append(contentsOf: landStage(
                kind, stage: next, state: &state, balance: balance, content: content
            ))
        }
        return events
    }
}

/// Narrative flags this lane raises, so content elsewhere can gate on them.
public enum SecretFlag {
    /// A union is recognised here, however it happened.
    public static let unionRecognised = "office_union_recognised"
    /// A thread was ended through People & HR.
    public static let handled = "office_secret_handled"
}
