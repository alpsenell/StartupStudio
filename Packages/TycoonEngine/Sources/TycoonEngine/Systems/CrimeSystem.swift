import Foundation
import TycoonContent

/// Iteration 11 — N1. The six offences, the weekly chance of being found
/// out, the case, the courtroom and the sentence.
///
/// **Nothing in this file runs until the player presses a button.** `run`
/// returns on its first line while `state.crime == .empty`, and
/// `state.crime` only ever stops being empty because an offence action
/// was applied through the reducer. Every pacing bot, every byte-identical
/// fixture and every save written before this iteration therefore takes
/// exactly the path it always took.
///
/// **Draws.** `state.socialRNG` only: one uniform per open record entry on
/// the weekly sweep, one per exchange in the courtroom, one for the NDA
/// poach's yes-or-no, one for the planted story's trace, one for the
/// hearing date and one for the blurb a bribed review is rewritten with.
/// `rng` and `worldRNG` are never touched. UUIDs the lane mints (the
/// poached engineer) come from `socialRNG` for the same reason.
enum CrimeSystem {

    /// The flag every `crime_` event in the two catalogs is gated on, so a
    /// run that has never done anything wrong draws from exactly the pool
    /// it drew from before this lane existed.
    static let recordFlag = "crime_record"
    /// Set while a case is on the books; the courtroom's own beats read it.
    static let caseFlag = "crime_case_open"
    /// Set for the rest of the run once a court has convicted the founder.
    static let convictedFlag = "crime_convicted"

    // MARK: - The tick

    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        guard state.crime != .empty else { return [] }
        var events: [GameEvent] = []

        events.append(contentsOf: weeklySweep(&state, balance))
        events.append(contentsOf: hearingClock(&state, balance))
        spendBooks(&state, balance)
        events.append(contentsOf: spendBribes(&state, balance))
        events.append(contentsOf: spendFakedDemos(&state, balance))
        events.append(contentsOf: servingTime(&state, balance))
        return events
    }

    // MARK: The weekly sweep

    /// Notoriety cools by a point a week, and every open entry on the
    /// record gets one roll against being found.
    ///
    /// One `socialRNG` word per open entry, in record order, whatever the
    /// outcome — the stream advances by the same amount however the week
    /// goes. At most one case is raised: two hearings at once is a
    /// different game.
    private static func weeklySweep(
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) -> [GameEvent] {
        guard state.day % GameState.daysPerWeek == 0,
              state.crime.lastSweepDay != state.day
        else { return [] }
        state.crime.lastSweepDay = state.day

        let config = balance.crime
        state.crime.notoriety = max(0, state.crime.notoriety - config.notorietyDecayPerWeek)

        guard state.crime.pendingCase == nil, !state.crime.openRecord.isEmpty else { return [] }
        let hasLegal = state.knownDepartments.contains(.legal)

        var found: CrimeRecordEntry?
        for entry in state.crime.record where entry.isOpen {
            // MARK: J2 (record)
            // The same odds, plus the laundering key and fame's spotlight
            // (exactly 1 at fame zero). `hasLegal` is read inside.
            _ = hasLegal
            let chance = state.standingDiscoveryChance(entry, balance: balance)
            // MARK: end J2
            let roll = state.socialRNG.nextUniform()
            if roll < chance, found == nil { found = entry }
        }
        guard let entry = found else { return [] }
        return raiseCase(against: entry, state: &state, balance: balance)
    }

    /// A discovery becomes a case: a hearing four to eight weeks out, a
    /// settlement price, the newspaper's lead, and two people who read it
    /// before you told them.
    ///
    /// Internal rather than private since iteration 11's wave two: W3's
    /// espionage traces a fresh record entry the moment an operation is
    /// run and hands it straight to this, which is the one place a case is
    /// raised. (Marked because it is another lane that needed the door
    /// opened — nothing else about it moved.)
    // MARK: W3 (espionage) — visibility only
    static func raiseCase(
        against entry: CrimeRecordEntry,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        let config = balance.crime
        let hasLegal = state.knownDepartments.contains(.legal)
        let evidence = Crime.evidenceWeight(
            entry, notoriety: state.crime.notoriety,
            hasLegal: hasLegal, day: state.day, balance: config
        )
        let weeks = state.socialRNG.nextInt(in: config.hearingWeeksMin...max(
            config.hearingWeeksMin, config.hearingWeeksMax
        ))
        let hearingDay = state.day + weeks * GameState.daysPerWeek

        var legalCase = LegalCase(
            id: "case-\(entry.id)",
            kind: entry.offence.rawValue,
            raisedDay: state.day,
            hearingDay: hearingDay,
            entryID: entry.id,
            rivalID: nil,
            settlementPrice: Crime.settlementPrice(
                offence: entry.offence, gain: entry.gain,
                evidence: evidence, balance: config
            ),
            evidence: evidence
        )
        // The rival who was written about, or poached from, is the one who
        // brings it. Everything else is the state or an editor.
        if entry.offence == .plantStory || entry.offence == .ndaPoach {
            legalCase.rivalID = state.rivals.rivals.first?.id
        }

        if let index = state.crime.record.firstIndex(where: { $0.id == entry.id }) {
            state.crime.record[index].discoveredDay = state.day
        }
        state.crime.cases.append(legalCase)
        trimCases(&state)
        state.narrative.flags.insert(caseFlag)

        state.life.phone.post(
            "There are two people at reception who are not here about the coffee machine.",
            from: .office, day: state.day
        )
        state.life.phone.post(
            "I've just seen the news. Call me. Please call me.",
            from: .partner, day: state.day
        )

        return [.crimeCaseRaised(
            offence: entry.offence.rawValue,
            accuser: entry.offence.accuser,
            hearingDay: hearingDay,
            day: state.day
        )]
    }

    // MARK: The hearing clock

    /// The day arrives. If the founder never walked into the room, the
    /// court hears it without them — which is exactly as bad as it sounds.
    private static func hearingClock(
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) -> [GameEvent] {
        guard let pending = state.crime.pendingCase else { return [] }
        if state.day == pending.hearingDay, state.crime.hearing == nil {
            return [.crimeHearingDue(
                offence: pending.kind,
                isFounderSuing: pending.isFounderSuing,
                day: state.day
            )]
        }
        // A day late is a verdict in absentia: the standing is the opening
        // one, with nothing said in mitigation.
        if state.day > pending.hearingDay, state.crime.hearing == nil {
            let standing = Crime.openingStanding(
                defence: pending.defence ?? .itNeverHappened,
                evidence: pending.evidence, balance: balance.crime
            ) - 20
            return deliver(verdict: standing, caseID: pending.id, state: &state, balance: balance)
        }
        return []
    }

    // MARK: Cooked books

    /// While the accounts are warm, a term sheet that lands reads them.
    /// The offer is revised in place, once — the flag on the offer is that
    /// it has already been lifted, which is what `booksCookedUntilDay`
    /// being cleared at the end of the quarter means.
    private static func spendBooks(_ state: inout GameState, _ balance: BalanceConfig) {
        guard let until = state.crime.booksCookedUntilDay else { return }
        guard state.day < until else {
            state.crime.booksCookedUntilDay = nil
            return
        }
        guard var offer = state.investors.pendingOffer,
              offer.respondByDay >= state.day,
              // Only an offer that arrived *after* the books were cooked.
              offer.respondByDay > until - balance.crime.cookBooksWeeks * GameState.daysPerWeek
        else { return }
        let factor = balance.crime.cookBooksValuationFactor
        let lifted = Int((Double(offer.valuation) * factor).rounded())
        guard lifted != offer.valuation else { return }
        offer.valuation = lifted
        offer.amount = Int((Double(offer.amount) * factor).rounded())
        state.investors.pendingOffer = offer
    }

    // MARK: The envelope

    /// A bribed outlet's review on the next launch comes back a notch
    /// kinder. One word from `socialRNG` to rewrite the blurb, and only on
    /// a launch the founder paid for.
    private static func spendBribes(
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) -> [GameEvent] {
        guard !state.crime.bribedOutlets.isEmpty else { return [] }
        var events: [GameEvent] = []
        for index in state.products.indices {
            guard case .released(var info) = state.products[index].stage,
                  info.launchDay == state.day,
                  !info.reviews.isEmpty
            else { continue }
            for outlet in state.crime.bribedOutlets.sorted() {
                guard let reviewIndex = info.reviews.firstIndex(where: { $0.outlet == outlet })
                else { continue }
                var review = info.reviews[reviewIndex]
                let shifted = min(balance.reviewCeiling, max(
                    balance.reviewFloor, review.score + balance.crime.bribeNotchPoints
                ))
                guard shifted != review.score else { continue }
                review.score = shifted
                review.blurb = ReviewBlurbs.pick(
                    for: shifted, rng: &state.socialRNG, outlet: review.outlet
                )
                info.reviews[reviewIndex] = review
                events.append(.crimeFavourCalled(
                    what: "\(outlet) was kinder than \(state.products[index].name) deserved",
                    day: state.day
                ))
            }
            state.products[index].stage = .released(info)
            state.crime.bribedOutlets = []
        }
        return events
    }

    // MARK: The fake demo

    /// A build whose demo was faked and which ships inside the window
    /// comes apart in public: the live bug count is multiplied on launch
    /// day, and the players find out at the same time the founder does.
    private static func spendFakedDemos(
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) -> [GameEvent] {
        guard !state.crime.fakedDemos.isEmpty else { return [] }
        var events: [GameEvent] = []
        for (key, fakedDay) in state.crime.fakedDemos.sorted(by: { $0.key < $1.key }) {
            guard let id = UUID(uuidString: key),
                  let index = state.products.firstIndex(where: { $0.id == id })
            else {
                state.crime.fakedDemos[key] = nil
                continue
            }
            guard case .released(var info) = state.products[index].stage else { continue }
            state.crime.fakedDemos[key] = nil
            guard info.launchDay - fakedDay <= balance.crime.fakeDemoWindowDays else { continue }
            let before = info.liveBugs
            info.liveBugs = max(before + 3, Int(
                (Double(before) * balance.crime.fakeDemoBugMultiplier).rounded()
            ))
            state.products[index].stage = .released(info)
            state.life.phone.post(
                "Everyone is asking where the bit from the video is.",
                from: .office, day: state.day
            )
            events.append(.crimeDemoCollapsed(
                productID: id, liveBugs: info.liveBugs, day: state.day
            ))
        }
        return events
    }

    // MARK: Inside

    /// The days the founder is not there. The sabbatical's caretaker is
    /// already running the company (see `SabbaticalSystem`'s N1 region);
    /// what this adds is what the sentence costs at home and in the
    /// boardroom.
    private static func servingTime(
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) -> [GameEvent] {
        // MARK: Iteration 11, wave two — W4 (inside)
        // A sentence is a place now. `PrisonSystem.serve` opens it on the
        // first morning, runs the day the founder chose, and closes it on
        // release; what N1 wrote the sentence costs — the relationships
        // meter every day, the board's patience every week — is applied
        // inside that day rather than under it, so nothing is charged
        // twice. `serve` returns `nil` only when there is no sentence at
        // all, in which case the original body below runs unchanged.
        if let inside = PrisonSystem.serve(&state, balance) {
            if state.day % GameState.daysPerWeek == 0, state.investors.hasBoard {
                state.investors.boardPressure = min(100,
                    state.investors.boardPressure + balance.crime.insideBoardPressurePerWeek
                )
            }
            return inside
        }
        // MARK: end of Iteration 11, wave two — W4
        guard let until = state.crime.sentenceUntilDay else { return [] }
        guard state.day < until else {
            state.crime.sentenceUntilDay = nil
            state.life.phone.post(
                "You're out. Somebody left a cardboard box of your things at reception.",
                from: .office, day: state.day
            )
            return [.crimeReleased(day: state.day)]
        }
        let config = balance.crime
        // Affection slides faster than an absence: this one has a reason
        // attached to it.
        state.life.meters.apply(relationships: -config.insideAffectionPerDay)
        if state.day % GameState.daysPerWeek == 0, state.investors.hasBoard {
            state.investors.boardPressure = min(100,
                state.investors.boardPressure + config.insideBoardPressurePerWeek
            )
        }
        return []
    }

    // MARK: - Committing an offence

    /// The one gate the button and the engine share.
    static func refusal(
        for offence: CrimeOffence,
        rivalID: UUID?,
        productID: UUID?,
        state: GameState,
        balance: BalanceConfig
    ) -> CrimeRefusal? {
        if state.crime.pendingCase != nil { return .casePending }
        if state.life.isAway(day: state.day) { return .away }
        let config = balance.crime
        let cost = Crime.walletCost(offence, balance: config)
        if cost > 0, state.life.wallet < cost { return .noWallet }

        switch offence {
        case .cookBooks:
            if state.crime.booksCookedUntilDay.map({ state.day < $0 }) == true {
                return .alreadyRunning
            }
            // Something has to exist to be overstated: a product on the
            // market, or a term sheet with a number on it.
            let hasSomething = state.products.contains { product in
                if case .released = product.stage { return true } else { return false }
            } || state.investors.pendingOffer != nil || !state.investors.rounds.isEmpty
            if !hasSomething { return .nothingToDeclare }
        case .dodgeTaxes:
            if FinanceSystem.crimeQuarterlyTaxBill(state, balance) <= 0 { return .nothingToDeclare }
            if let last = state.crime.lastCommitted[offence.rawValue],
               state.day - last < config.taxQuarterWeeks * GameState.daysPerWeek {
                return .tooSoon
            }
        case .ndaPoach, .plantStory:
            if state.rivals.rivals.isEmpty { return .noRival }
            if offence == .ndaPoach, let last = state.crime.lastCommitted[offence.rawValue],
               state.day - last < GameState.daysPerWeek * 4 {
                return .tooSoon
            }
        case .bribeJournalist:
            if !state.crime.bribedOutlets.isEmpty { return .alreadyRunning }
            if balance.reviewOutlets.isEmpty { return .nothingToDeclare }
        case .fakeDemo:
            let target = productID ?? state.productsInDevelopment.first?.id
            guard let target, state.products.contains(where: { $0.id == target }) else {
                return .noBuild
            }
            if state.crime.fakedDemos[target.uuidString] != nil { return .alreadyRunning }
        // MARK: W1 — the seventh offence has no button here: it is
        // committed by paying a backer, and this gate refuses it always.
        case .launderMoney:
            return .alreadyRunning
        // MARK: end of W1
        // MARK: W3 (espionage)
        // The ledger lists it so the founder knows the court has a word
        // for it, and refuses it so the only way to do it is to stand on
        // somebody's page and pick them.
        case .corporateEspionage:
            return .elsewhere
        // MARK: end W3
        }
        return nil
    }

    /// Presses the button. The gain is applied here and only here, once.
    static func commit(
        offence: CrimeOffence,
        rivalID: UUID?,
        productID: UUID?,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard refusal(
            for: offence, rivalID: rivalID, productID: productID,
            state: state, balance: balance
        ) == nil else { return [] }

        let config = balance.crime
        var events: [GameEvent] = []
        let fee = Crime.walletCost(offence, balance: config)
        if fee > 0 { state.life.wallet -= fee }

        var gain = 0
        var note = ""

        switch offence {
        case .cookBooks:
            state.crime.booksCookedUntilDay = state.day
                + config.cookBooksWeeks * GameState.daysPerWeek
            let uplift = Int((Double(state.companyValuation(balance: balance))
                * (config.cookBooksValuationFactor - 1)).rounded())
            gain = uplift
            note = "The quarter reads \(uplift.crimeMoney) better than it was."

        case .dodgeTaxes:
            let bill = FinanceSystem.crimeQuarterlyTaxBill(state, balance)
            let kept = Int((Double(bill) * config.dodgeFraction).rounded())
            gain = kept
            note = "\(kept.crimeMoney) of the quarter's bill stayed in the account."
            FinanceSystem.crimePostDodgedTax(kept, state: &state)

        case .ndaPoach:
            let (landed, name) = poachUnderNDA(
                rivalID: rivalID, state: &state, balance: balance, content: content
            )
            gain = landed ? config.ndaPoachFee * 4 : 0
            note = landed
                ? "\(name) is in your candidate pool, and should not be."
                : "\(name) said no, and kept the email."
            events.append(.crimeNDAPoach(name: name, landed: landed, day: state.day))

        case .bribeJournalist:
            let outlet = balance.reviewOutlets.first ?? "The Trade"
            state.crime.bribedOutlets = [outlet]
            gain = config.bribeFee
            note = "\(outlet) owes you a good one."

        case .fakeDemo:
            guard let target = productID ?? state.productsInDevelopment.first?.id,
                  let index = state.products.firstIndex(where: { $0.id == target }),
                  case .development(var dev) = state.products[index].stage
            else { return [] }
            dev.hype += config.fakeDemoHype
            state.products[index].stage = .development(dev)
            state.crime.fakedDemos[target.uuidString] = state.day
            gain = Int(config.fakeDemoHype)
            note = "\(state.products[index].name) has \(Int(config.fakeDemoHype)) points of hype "
                + "and one feature that does not exist."

        case .plantStory:
            // The rival half lives in `RivalSystem`'s N1 region: it owns
            // what a studio's reputation and strength are.
            guard let placed = RivalSystem.crimePlantStory(
                against: rivalID, state: &state, balance: balance
            ) else { return [] }
            gain = Int(config.plantStoryReputationHit)
            note = placed.traced
                ? "\(placed.name) took the hit, and worked out who threw it."
                : "\(placed.name) took the hit and never looked up."

        // MARK: W1 — unreachable: `refusal` above refuses the seventh
        // offence for every caller, and `dirtyMoneyLaunder` is the only
        // thing that ever writes one.
        case .launderMoney:
            return []
        // MARK: end of W1
        // MARK: W3 (espionage)
        // Unreachable: `refusal` returns `.elsewhere` above, and
        // `EspionageSystem` writes its own record entry. The arm is here
        // so the switch stays exhaustive.
        case .corporateEspionage:
            return []
        // MARK: end W3
        }

        state.crime.notoriety = min(100,
            state.crime.notoriety + Crime.notorietyCost(offence, balance: config)
        )
        state.crime.lastCommitted[offence.rawValue] = state.day
        let entry = CrimeRecordEntry(
            id: "\(offence.rawValue)-\(state.day)",
            offence: offence,
            day: state.day,
            gain: gain,
            note: note
        )
        state.crime.record.append(entry)
        if state.crime.record.count > CrimeState.maxRecord {
            state.crime.record.removeFirst(state.crime.record.count - CrimeState.maxRecord)
        }
        state.narrative.flags.insert(recordFlag)

        events.insert(.crimeCommitted(
            offence: offence.rawValue,
            gain: gain,
            notoriety: state.crime.notoriety,
            day: state.day
        ), at: 0)
        return events
    }

    /// The founder walks into a police station. The case is raised today,
    /// the evidence is what it is, and the courtroom will notice that
    /// nobody had to find them.
    static func confess(
        entryID: String?,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard state.crime.pendingCase == nil,
              let entry = entryID.flatMap({ id in state.crime.record.first { $0.id == id } })
                ?? state.crime.openRecord.last
        else { return [] }
        var events = raiseCase(against: entry, state: &state, balance: balance)
        // Turning yourself in is worth a third of the paper against you.
        if let index = state.crime.cases.firstIndex(where: { $0.entryID == entry.id }) {
            state.crime.cases[index].evidence = max(0.1, state.crime.cases[index].evidence * 0.66)
            state.crime.cases[index].settlementPrice = Crime.settlementPrice(
                offence: entry.offence, gain: entry.gain,
                evidence: state.crime.cases[index].evidence, balance: balance.crime
            )
        }
        events.append(.crimeConfessed(offence: entry.offence.rawValue, day: state.day))
        return events
    }

    // MARK: Iteration 11, wave two — W1 (dirty money: the seventh offence)

    /// Writes a payment made through a backer onto the record as the
    /// seventh offence.
    ///
    /// This is the whole of W1's reach into N1: no button, no gate, no
    /// courtroom of its own. The entry is an ordinary `CrimeRecordEntry`,
    /// so the weekly sweep rolls for it exactly as it rolls for the other
    /// six, the case it raises is heard in the same room, and
    /// `CrimeSystem.confess` turns the founder witness on it. The
    /// notoriety comes in as a number because it is W1's balance block
    /// that owns it — `Crime.notorietyCost` returns zero for this offence
    /// so nothing is added twice.
    static func dirtyMoneyLaunder(
        amount: Int,
        note: String,
        notoriety: Double,
        state: inout GameState
    ) -> [GameEvent] {
        guard amount > 0 else { return [] }
        let entry = CrimeRecordEntry(
            id: "launderMoney-\(state.day)",
            offence: .launderMoney,
            day: state.day,
            gain: amount,
            note: note
        )
        guard !state.crime.record.contains(where: { $0.id == entry.id }) else { return [] }
        state.crime.record.append(entry)
        if state.crime.record.count > CrimeState.maxRecord {
            state.crime.record.removeFirst(state.crime.record.count - CrimeState.maxRecord)
        }
        state.crime.notoriety = min(100, state.crime.notoriety + notoriety)
        state.narrative.flags.insert(recordFlag)
        return [.crimeCommitted(
            offence: CrimeOffence.launderMoney.rawValue,
            gain: amount,
            notoriety: state.crime.notoriety,
            day: state.day
        )]
    }

    // MARK: end of Iteration 11, wave two — W1

    // MARK: The NDA poach

    /// One `socialRNG` word for the yes-or-no, and one candidate minted
    /// from `socialRNG` when it is yes. `HiringSystem`'s N1 region does
    /// the minting so the hiring desk owns the shape of a candidate.
    private static func poachUnderNDA(
        rivalID: UUID?,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> (landed: Bool, name: String) {
        let config = balance.crime
        let rival = rivalID.flatMap { id in state.rivals.rivals.first { $0.id == id } }
            ?? state.rivals.rivals.first
        let chance = min(0.95, config.ndaPoachBaseChance * config.ndaPoachNDAFactor)
        let landed = state.socialRNG.nextUniform() < chance
        let name = HiringSystem.crimeMintPoachedCandidate(
            from: rival, landed: landed, state: &state, balance: balance, content: content
        )
        if landed { RivalSystem.crimeLostAnEngineer(rival?.id, state: &state) }
        return (landed, name)
    }

    // MARK: - Before the hearing

    /// Pays the other side off. The wallet goes first, the company covers
    /// what the wallet cannot, and the record entry is answered for.
    static func settle(
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard let pending = state.crime.pendingCase,
              !pending.isFounderSuing,
              let index = state.crime.cases.firstIndex(where: { $0.id == pending.id })
        else { return [] }
        let price = pending.settlementPrice
        guard state.life.wallet + state.company.cash >= price else { return [] }

        let fromWallet = min(state.life.wallet, price)
        state.life.wallet -= fromWallet
        let fromCompany = price - fromWallet
        if fromCompany > 0 {
            state.company.cash -= fromCompany
            state.ledger.post(LedgerEntry(
                day: state.day, amount: -fromCompany, category: .other,
                label: "Settlement (no admission of liability)"
            ))
        }
        state.crime.cases[index].settledDay = state.day
        state.crime.cases[index].verdict = .settlement
        state.crime.cases[index].penalty = price
        closeEntry(for: pending, state: &state)
        state.narrative.flags.remove(caseFlag)
        state.life.phone.post(
            "It's gone away. It cost what it cost and nobody will say what.",
            from: .office, day: state.day
        )
        return [.crimeSettled(amount: price, day: state.day)]
    }

    /// Buys representation. Duty solicitor is free and is what you have.
    static func hire(
        lawyer: CrimeLawyer,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard let pending = state.crime.pendingCase,
              state.crime.hearing == nil,
              let index = state.crime.cases.firstIndex(where: { $0.id == pending.id })
        else { return [] }
        let fee = balance.crime.fee(for: lawyer)
        guard fee == 0 || state.life.wallet >= fee else { return [] }
        guard lawyer != pending.lawyer else { return [] }
        state.life.wallet -= fee
        state.crime.cases[index].lawyer = lawyer
        return [.crimeLawyerHired(tier: lawyer.rawValue, fee: fee, day: state.day)]
    }

    /// Picks the line the founder will run. Free, and changeable up to the
    /// moment they stand up.
    static func choose(
        defence: CrimeDefence,
        state: inout GameState
    ) -> [GameEvent] {
        guard let pending = state.crime.pendingCase,
              state.crime.hearing == nil,
              let index = state.crime.cases.firstIndex(where: { $0.id == pending.id })
        else { return [] }
        state.crime.cases[index].defence = defence
        return []
    }

    // MARK: - The courtroom

    /// Stands the founder up. The clock stops: this is a room, not a card.
    static func openHearing(
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard let pending = state.crime.pendingCase,
              state.crime.hearing == nil,
              state.day >= pending.hearingDay
        else { return [] }
        let config = balance.crime
        let defence = pending.defence ?? .everybodyDoesThis
        state.crime.hearing = CrimeHearing(
            caseID: pending.id,
            openedDay: state.day,
            exchangesLeft: config.exchanges,
            objectionsLeft: pending.lawyer.objections,
            standing: Crime.openingStanding(
                defence: defence, evidence: pending.evidence, balance: config
            ),
            lastLine: opener(for: pending)
        )
        // MARK: Iteration 11, wave two — W2 (family drama)
        // A custody hearing is the same room with a different first line.
        if pending.kind == FamilyDrama.custodyCaseKind {
            state.crime.hearing?.lastLine = FamilyDrama.custodyOpener(
                childCount: state.life.family.children.count
            )
        }
        // MARK: end of Iteration 11, wave two — W2
        state.speed = .paused
        return [.crimeHearingOpened(offence: pending.kind, day: state.day)]
    }

    private static func opener(for legalCase: LegalCase) -> String {
        if legalCase.isFounderSuing {
            return "\"You brought this. Show the court what you have.\""
        }
        let charge = legalCase.offence?.chargeName ?? "the matter before us"
        return "\"We are here on a charge of \(charge). Are we all quite comfortable?\""
    }

    /// One exchange. Costs an exchange and exactly one `socialRNG` word,
    /// whatever is said.
    static func say(
        _ exchange: CrimeExchange,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard var hearing = state.crime.hearing,
              hearing.exchangesLeft > 0,
              let legalCase = state.crime.cases.first(where: { $0.id == hearing.caseID })
        else { return [] }
        if exchange == .objection, hearing.objectionsLeft <= 0 { return [] }

        let config = balance.crime
        let defence = legalCase.defence ?? .everybodyDoesThis
        let offence = legalCase.offence ?? .cookBooks
        let skill = state.life.skills.value(for: exchange.gradedOn)
        let chance = Crime.landChance(
            exchange, defence: defence, lawyer: legalCase.lawyer,
            skill: skill, evidence: legalCase.evidence, balance: config
        )
        let roll = state.socialRNG.nextUniform()
        let landed = roll < chance

        var swing = exchange.reward * defence.swing
        if exchange == defence.favours { swing *= 1.2 }
        hearing.standing = min(Crime.standingLimit, max(-Crime.standingLimit,
            hearing.standing + (landed ? swing : -swing * exchange.missFactor)
        ))
        hearing.lastLanded = landed
        hearing.lastLine = Crime.reply(exchange, landed: landed, offence: offence, roll: roll)
        // MARK: Iteration 11, wave two — W2 (family drama)
        // The family court says its own things back.
        if legalCase.kind == FamilyDrama.custodyCaseKind {
            hearing.lastLine = FamilyDrama.custodyReply(exchange, landed: landed, roll: roll)
        }
        // MARK: end of Iteration 11, wave two — W2
        hearing.exchangesLeft -= 1
        hearing.exchangesTaken += 1
        if exchange == .objection { hearing.objectionsLeft -= 1 }
        state.crime.hearing = hearing

        // Standing in a box is not restful, and pointing downstairs is
        // heard downstairs.
        state.life.meters.apply(energy: -2, mood: landed ? 1 : -2)
        if exchange.moraleCost > 0 {
            for index in state.employees.indices where !state.employees[index].isFounder {
                state.employees[index].morale = max(0,
                    state.employees[index].morale - exchange.moraleCost
                )
            }
        }
        FounderSystem.practice(.conversation, state: &state, balance: balance)

        if hearing.exchangesLeft == 0 {
            return deliver(
                verdict: hearing.standing, caseID: hearing.caseID,
                state: &state, balance: balance
            )
        }
        return []
    }

    /// The founder stops talking early and takes what is coming.
    static func rest(state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        guard let hearing = state.crime.hearing else { return [] }
        return deliver(
            verdict: hearing.standing, caseID: hearing.caseID,
            state: &state, balance: balance
        )
    }

    // MARK: The verdict

    /// Writes the verdict into the world: money, reputation, a gag order,
    /// or a sentence and a caretaker.
    private static func deliver(
        verdict standing: Double,
        caseID: String,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard let index = state.crime.cases.firstIndex(where: { $0.id == caseID })
        else { return [] }
        let config = balance.crime
        let legalCase = state.crime.cases[index]
        let offence = legalCase.offence ?? .cookBooks
        let entry = legalCase.entryID.flatMap { id in state.crime.record.first { $0.id == id } }
        let gain = entry?.gain ?? 0

        state.crime.hearing = nil
        state.narrative.flags.remove(caseFlag)

        // MARK: Iteration 11, wave two — W2 (family drama)
        // A custody case is heard here and settled there: the bands are
        // the family court's, and no money changes hands in this room.
        if legalCase.kind == FamilyDrama.custodyCaseKind {
            return FamilyDramaSystem.deliverCustody(
                standing: standing, index: index, state: &state, balance: balance
            )
        }
        // MARK: end of Iteration 11, wave two — W2

        if legalCase.isFounderSuing {
            return deliverSuit(
                standing: standing, index: index, state: &state, balance: balance
            )
        }

        let verdict = Crime.verdict(standing, balance: config)
        let (money, weeks) = Crime.penalty(
            verdict: verdict, offence: offence, gain: gain,
            standing: standing, balance: config
        )
        state.crime.cases[index].verdict = verdict
        state.crime.cases[index].penalty = money
        state.crime.cases[index].sentenceWeeks = weeks
        closeEntry(for: legalCase, state: &state)

        var events: [GameEvent] = []
        switch verdict {
        case .acquitted:
            state.company.reputation = min(100,
                state.company.reputation + config.acquittalReputationGain
            )
            state.crime.notoriety = max(0, state.crime.notoriety - 6)
            state.life.phone.post(
                "You're clear. Nobody is going to say congratulations, but you're clear.",
                from: .office, day: state.day
            )
        case .fine, .settlement:
            let fromWallet = min(state.life.wallet, money)
            state.life.wallet -= fromWallet
            let fromCompany = money - fromWallet
            if fromCompany > 0 {
                state.company.cash -= fromCompany
                state.ledger.post(LedgerEntry(
                    day: state.day, amount: -fromCompany, category: .other,
                    label: verdict == .fine ? "Court fine" : "Settlement"
                ))
            }
            state.company.reputation = max(0,
                state.company.reputation - config.guiltyReputationHit
                    * (verdict == .settlement ? 0.5 : 1)
            )
            state.narrative.flags.insert(convictedFlag)
        case .sentence:
            state.company.reputation = max(0,
                state.company.reputation - config.guiltyReputationHit * 1.5
            )
            state.narrative.flags.insert(convictedFlag)
            state.crime.sentenceUntilDay = state.day + weeks * GameState.daysPerWeek
            events.append(contentsOf: SabbaticalSystem.crimeBeginSentence(
                weeks: weeks, state: &state, balance: balance
            ))
        }
        // MARK: J2 (record)
        // A conviction is news, and news costs a famous founder a rung.
        // Nothing to drop for a founder who never posted.
        if verdict != .acquitted,
           let level = state.fame.standingDropRung(balance: balance.fame) {
            events.append(.standingFameDropped(
                level: level.rawValue, reason: "conviction", day: state.day
            ))
        }
        // MARK: end J2

        events.insert(.crimeVerdict(
            offence: offence.rawValue,
            verdict: verdict.rawValue,
            penalty: money,
            weeks: weeks,
            day: state.day
        ), at: 0)
        trimCases(&state)
        return events
    }

    /// The other direction: the founder's own suit against a studio.
    private static func deliverSuit(
        standing: Double,
        index: Int,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        let config = balance.crime
        let won = standing >= config.fineStanding
        state.crime.cases[index].verdict = won ? .acquitted : .fine
        let rivalID = state.crime.cases[index].rivalID
        var damages = 0
        var tookProduct: String?

        if won, let rivalID,
           let name = state.rivals.rivals.first(where: { $0.id == rivalID })?.name {
            let award = RivalSystem.crimeAwardDamages(
                against: rivalID, state: &state, balance: balance
            )
            damages = award.damages
            tookProduct = award.productTaken
            if damages > 0 {
                state.company.cash += damages
                state.ledger.post(LedgerEntry(
                    day: state.day, amount: damages, category: .other,
                    label: "Damages: \(name)"
                ))
            }
        }
        state.crime.cases[index].penalty = damages
        trimCases(&state)
        return [.crimeSuitResolved(
            won: won,
            damages: damages,
            productTaken: tookProduct ?? "",
            day: state.day
        )]
    }

    // MARK: - Suing a rival

    /// Files against a studio. The filing fee is the company's; the case
    /// runs on exactly the machinery that runs against the founder, with
    /// the evidence being how much the rival actually did.
    static func sue(
        rivalID: UUID,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard state.crime.pendingCase == nil,
              let rival = state.rivals.rivals.first(where: { $0.id == rivalID }),
              state.company.cash >= balance.crime.suitFilingFee
        else { return [] }
        let config = balance.crime
        state.company.cash -= config.suitFilingFee
        state.ledger.post(LedgerEntry(
            day: state.day, amount: -config.suitFilingFee, category: .other,
            label: "Filing fee: \(rival.name)"
        ))
        let weeks = state.socialRNG.nextInt(in: config.hearingWeeksMin...max(
            config.hearingWeeksMin, config.hearingWeeksMax
        ))
        // What you have on them: how much they have copied, and how big
        // they are. A giant leaves more paper.
        let evidence = min(0.9, 0.25 + Double(rival.products.count) * 0.06)
        state.crime.cases.append(LegalCase(
            id: "suit-\(rival.id.uuidString.prefix(8))-\(state.day)",
            kind: "suit",
            raisedDay: state.day,
            hearingDay: state.day + weeks * GameState.daysPerWeek,
            rivalID: rival.id,
            isFounderSuing: true,
            settlementPrice: 0,
            evidence: evidence
        ))
        trimCases(&state)
        state.narrative.flags.insert(recordFlag)
        state.narrative.flags.insert(caseFlag)
        return [.crimeSuitFiled(
            rivalID: rival.id,
            hearingDay: state.day + weeks * GameState.daysPerWeek,
            day: state.day
        )]
    }

    // MARK: - Bookkeeping

    private static func closeEntry(for legalCase: LegalCase, state: inout GameState) {
        guard let entryID = legalCase.entryID,
              let index = state.crime.record.firstIndex(where: { $0.id == entryID })
        else { return }
        state.crime.record[index].settledDay = state.day
    }

    private static func trimCases(_ state: inout GameState) {
        if state.crime.cases.count > CrimeState.maxCases {
            state.crime.cases.removeFirst(state.crime.cases.count - CrimeState.maxCases)
        }
    }
}

// MARK: - Gates the app reads

extension GameState {
    /// Why this offence would be refused today, or `nil` when it would
    /// land. The button and the reducer read the same function.
    public func crimeRefusal(
        for offence: CrimeOffence,
        rivalID: UUID? = nil,
        productID: UUID? = nil,
        balance: BalanceConfig
    ) -> CrimeRefusal? {
        CrimeSystem.refusal(
            for: offence, rivalID: rivalID, productID: productID,
            state: self, balance: balance
        )
    }

    /// What this offence would be worth today, as a sentence for the
    /// button. Pure — the same arithmetic `commit` uses.
    public func crimeGainLine(
        for offence: CrimeOffence,
        balance: BalanceConfig
    ) -> String {
        let config = balance.crime
        switch offence {
        case .cookBooks:
            let uplift = Int((Double(companyValuation(balance: balance))
                * (config.cookBooksValuationFactor - 1)).rounded())
            return "Valuation reads \(uplift.crimeMoney) higher for \(config.cookBooksWeeks) weeks"
        case .dodgeTaxes:
            let bill = FinanceSystem.crimeQuarterlyTaxBill(self, balance)
            let kept = Int((Double(bill) * config.dodgeFraction).rounded())
            return "Keeps \(kept.crimeMoney) of a \(bill.crimeMoney) bill"
        case .ndaPoach:
            let chance = Int((min(0.95, config.ndaPoachBaseChance * config.ndaPoachNDAFactor)
                * 100).rounded())
            return "\(config.ndaPoachFee.crimeMoney) of your money, \(chance)% they say yes"
        case .bribeJournalist:
            return "\(config.bribeFee.crimeMoney) for \(config.bribeNotchPoints) points "
                + "on one review of your next launch"
        case .fakeDemo:
            return "+\(Int(config.fakeDemoHype)) hype; ship inside "
                + "\(config.fakeDemoWindowDays) days and it comes apart"
        case .plantStory:
            return "\(config.plantStoryFee.crimeMoney) for "
                + "−\(Int(config.plantStoryReputationHit)) on their reputation"
        // MARK: W1 — never on a button of N1's; the ledger is where this
        // one is committed, and the sentence is there.
        case .launderMoney:
            return "Money through a backer. It is not offered here."
        // MARK: end of W1
        // MARK: W3 (espionage)
        case .corporateEspionage:
            return "Five operations, priced one at a time, on a studio's own page"
        // MARK: end W3
        }
    }
}
